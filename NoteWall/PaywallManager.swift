import Foundation
import SwiftUI
import RevenueCat
import SuperwallKit

/// Manages paywall state, RevenueCat configuration, and premium status
final class PaywallManager: NSObject, ObservableObject {
    // MARK: - Singleton
    static let shared = PaywallManager()
    
    // MARK: - AppStorage Keys
    @AppStorage("wallpaperExportCount") var wallpaperExportCount: Int = 0
    @AppStorage("hasPremiumAccess") var hasPremiumAccess: Bool = false
    @AppStorage("hasLifetimeAccess") var hasLifetimeAccess: Bool = false
    @AppStorage("subscriptionExpiryDate") var subscriptionExpiryTimestamp: Double = 0
    @AppStorage("hasSeenPaywall") var hasSeenPaywall: Bool = false
    @AppStorage("paywallDismissCount") var paywallDismissCount: Int = 0
    @AppStorage("trialStartDate") var trialStartDateTimestamp: Double = 0
    
    // MARK: - Published Properties
    @Published var shouldShowPaywall: Bool = false
    @Published var paywallTriggerReason: PaywallTriggerReason = .limitReached
    @Published var shouldShowSuperwallPaywall: Bool = false
    @Published var superwallPlacement: String = ""
    @Published var offerings: Offerings?
    @Published var availablePackages: [Package] = []
    @Published var customerInfo: RevenueCat.CustomerInfo?
    @Published var isLoadingOfferings: Bool = false
    @Published var isProcessingPurchase: Bool = false
    @Published var lastErrorMessage: String?
    
    // MARK: - Constants
    // Hard paywall: No free exports allowed - users must subscribe after onboarding
    private let freeExportLimit = 0
    private let entitlementID = "Notewall+"
    private let lifetimeProductID = "lifetime"
    private var paywallDelayWorkItem: DispatchWorkItem?
    private var hasConnectedToRevenueCat = false
    
    // MARK: - Computed Properties
    var isPremium: Bool {
        return hasActiveRevenueCatEntitlement || hasLifetimeAccess || hasActiveSubscription
    }
    
    var trialStartDate: Date? {
        guard trialStartDateTimestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: trialStartDateTimestamp)
    }
    
    /// Whether to show the "Trial Ending Soon" banner
    /// Logic: Show between 24h and 72h after trial start
    var shouldShowTrialReminder: Bool {
        guard let start = trialStartDate else { return false }
        let now = Date()
        let hoursElapsed = now.timeIntervalSince(start) / 3600
        return hoursElapsed >= 24 && hoursElapsed < 72 && isPremium // Only show if still premium (trial active)
    }
    
    var hasActiveSubscription: Bool {
        if hasActiveRevenueCatEntitlement { return true }
        guard subscriptionExpiryTimestamp > 0 else { return false }
        let expiryDate = Date(timeIntervalSince1970: subscriptionExpiryTimestamp)
        return Date() < expiryDate
    }

    var hasActiveRevenueCatEntitlement: Bool {
        customerInfo?.entitlements[entitlementID]?.isActive == true
    }
    
    var remainingFreeExports: Int {
        max(0, freeExportLimit - wallpaperExportCount)
    }
    
    var hasReachedFreeLimit: Bool {
        wallpaperExportCount >= freeExportLimit
    }

    var currentOfferingIdentifier: String? {
        offerings?.current?.identifier ?? offerings?.all.first?.key
    }
    
    // MARK: - Initialization
    private override init() {
        super.init()
        // NOTE: checkPaywallOnLaunch() moved to refreshCustomerInfo() to avoid showing
        // paywall to premium users before RevenueCat loads their entitlements
        restoreLegacyAccessIfNeeded()
    }

    // MARK: - RevenueCat Configuration

    func connectRevenueCat() {
        guard !hasConnectedToRevenueCat else { return }
        hasConnectedToRevenueCat = true
        Purchases.shared.delegate = self

        Task {
            await refreshCustomerInfo()
            await loadOfferings()
        }
    }

    @MainActor
    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            handle(customerInfo: info)
            
            // Check paywall AFTER loading customer info to prevent false positives for premium users
            checkPaywallOnLaunch()
        } catch {
            lastErrorMessage = "Unable to refresh customer info: \(error.localizedDescription)"
            #if DEBUG
            print("❌ RevenueCat: \(error)")
            #endif
            
            // Track refresh error
            AnalyticsService.shared.logEvent(
                .error(
                    errorType: "revenuecat_refresh_error",
                    errorMessage: error.localizedDescription,
                    screen: nil
                ),
                additionalParams: [
                    "error_code": (error as NSError).code
                ]
            )
        }
    }

    @MainActor
    func loadOfferings(force: Bool = false) async {
        if offerings != nil && !force { return }

        isLoadingOfferings = true
        do {
            let newOfferings = try await Purchases.shared.offerings()
            offerings = newOfferings
            availablePackages = Self.sortPackages(newOfferings.current?.availablePackages ?? [])
            isLoadingOfferings = false
        } catch {
            isLoadingOfferings = false
            lastErrorMessage = "Unable to load offerings: \(error.localizedDescription)"
            #if DEBUG
            print("❌ RevenueCat: \(error)")
            #endif
            
            // Track offerings error
            AnalyticsService.shared.logEvent(
                .error(
                    errorType: "revenuecat_offerings_error",
                    errorMessage: error.localizedDescription,
                    screen: nil
                )
            )
        }
    }

    func purchase(package: Package) async throws {
        await MainActor.run {
            isProcessingPurchase = true
            lastErrorMessage = nil
        }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            await MainActor.run {
                handle(customerInfo: result.customerInfo)
                
                // Track successful purchase
                AnalyticsService.shared.logEvent(
                    .purchaseSuccess(
                        productId: package.storeProduct.productIdentifier,
                        transactionId: nil,
                        revenue: Double(truncating: package.storeProduct.price as NSDecimalNumber),
                        currency: package.storeProduct.currencyCode ?? "USD"
                    )
                )
                
                // Check if this was a trial purchase
                if package.storeProduct.introductoryDiscount != nil {
                    #if DEBUG
                    print("✅ Trial started! Saving date and scheduling reminder.")
                    #endif
                    self.trialStartDateTimestamp = Date().timeIntervalSince1970
                    NotificationManager.shared.scheduleTrialReminder()
                }
                
                // Update Superwall attributes after purchase
                SuperwallUserAttributesManager.shared.updateSubscriptionAttributes()
                
                isProcessingPurchase = false
                shouldShowPaywall = false
            }
        } catch {
            await MainActor.run {
                isProcessingPurchase = false
                lastErrorMessage = purchaseErrorMessage(error)
                
                // Track purchase failure
                let userCancelled = (error as? ErrorCode) == .purchaseCancelledError
                
                if userCancelled {
                    AnalyticsService.shared.logEvent(
                        .purchaseCancel(productId: package.storeProduct.productIdentifier)
                    )
                } else {
                    AnalyticsService.shared.logEvent(
                        .purchaseFail(
                            productId: package.storeProduct.productIdentifier,
                            errorCode: String((error as NSError).code)
                        ),
                        additionalParams: [
                            "error_message": error.localizedDescription
                        ]
                    )
                }
            }
            throw error
        }
    }

    func restoreRevenueCatPurchases() async {
        await MainActor.run {
            isProcessingPurchase = true
            lastErrorMessage = nil
        }

        do {
            let info = try await Purchases.shared.restorePurchases()
            await MainActor.run {
                handle(customerInfo: info)
                isProcessingPurchase = false
                
                // Track restore result
                let hasEntitlement = info.entitlements[entitlementID]?.isActive == true
                if hasEntitlement {
                     AnalyticsService.shared.logEvent(.restoreSuccess())
                }
                
                AnalyticsService.shared.logEvent(
                    .custom(
                        name: "restore_completed",
                        parameters: [
                            "success": true,
                            "has_entitlement": hasEntitlement,
                            "active_entitlements": info.entitlements.active.keys.joined(separator: ",")
                        ]
                    )
                )
            }
        } catch {
            await MainActor.run {
                isProcessingPurchase = false
                lastErrorMessage = "Restore failed: \(error.localizedDescription)"
                
                // Track restore failure
                AnalyticsService.shared.logEvent(
                    .restoreFail(errorCode: String((error as NSError).code))
                )
            }
        }
    }

    private func handle(customerInfo: RevenueCat.CustomerInfo) {
        self.customerInfo = customerInfo
        hasPremiumAccess = customerInfo.entitlements[entitlementID]?.isActive == true
        if let entitlement = customerInfo.entitlements[entitlementID] {
            hasPremiumAccess = entitlement.isActive
            if entitlement.productIdentifier == lifetimeProductID {
                hasLifetimeAccess = true
            }
        } else {
            hasPremiumAccess = false
        }
        
        // Update Superwall attributes when subscription status changes
        SuperwallUserAttributesManager.shared.updateSubscriptionAttributes()
    }

    private func restoreLegacyAccessIfNeeded() {
        guard !hasActiveRevenueCatEntitlement else { return }
        if hasActiveSubscription || hasLifetimeAccess {
            hasPremiumAccess = true
        }
    }

    private static func sortPackages(_ packages: [Package]) -> [Package] {
        packages.sorted { first, second in
            priority(for: first) < priority(for: second)
        }
    }

    private static func priority(for package: Package) -> Int {
        switch package.packageType {
        case .monthly: return 0
        case .annual: return 1
        case .lifetime: return 2
        default:
            let identifier = package.storeProduct.productIdentifier.lowercased()
            if identifier.contains("monthly") { return 0 }
            if identifier.contains("year") { return 1 }
            if identifier.contains("life") { return 2 }
            return 3
        }
    }

    private func purchaseErrorMessage(_ error: Error) -> String {
        if let purchasesError = error as? ErrorCode,
           purchasesError == .purchaseCancelledError {
            return "Purchase cancelled."
        }
        return "Purchase failed: \(error.localizedDescription)"
    }

    // MARK: - Usage Tracking

    func checkPaywallOnLaunch() {
        guard !isPremium else { 
            #if DEBUG
            print("✅ PaywallManager: User is premium, skipping paywall on launch")
            #endif
            return 
        }
        
        let hasCompletedSetup = UserDefaults.standard.bool(forKey: "hasCompletedSetup")
        if hasCompletedSetup && hasReachedFreeLimit {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                guard !self.isPremium else { return }
                self.paywallTriggerReason = .limitReached
                self.shouldShowPaywall = true
            }
        }
    }
    
    func trackWallpaperExport() {
        guard !isPremium else { return }
        
        wallpaperExportCount += 1
        
        // Track wallpaper export for conversion analytics
        AnalyticsService.shared.logEvent(
            .wallpaperExport(count: wallpaperExportCount, isPremium: isPremium),
            additionalParams: [
                "free_limit": freeExportLimit,
                "remaining": max(0, freeExportLimit - wallpaperExportCount),
                "reached_limit": hasReachedFreeLimit
            ]
        )
        
        // Update Superwall attributes when usage changes
        SuperwallUserAttributesManager.shared.updateUsageAttributes()
        
        if hasReachedFreeLimit {
            showPaywallAfterDelay()
        }
    }
    
    private func showPaywallAfterDelay() {
        guard !isPremium else { return }
        
        paywallDelayWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.isPremium else { return }
            
            DispatchQueue.main.async {
                self.paywallTriggerReason = .limitReached
                self.shouldShowPaywall = true
                self.hasSeenPaywall = true
            }
        }
        
        paywallDelayWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }
    
    func canExportWallpaper() -> Bool {
        // Hard paywall: Only premium users can export wallpapers
        isPremium
    }
    
    func showPaywall(reason: PaywallTriggerReason = .manual) {
        paywallTriggerReason = reason
        shouldShowPaywall = true
    }
    
    // MARK: - Superwall Paywall Presentation
    
    /// Present a Superwall paywall for the given placement
    /// - Parameter placement: The placement identifier configured in Superwall dashboard
    func presentSuperwallPaywall(placement: String) {
        superwallPlacement = placement
        shouldShowSuperwallPaywall = true
    }
    
    /// Register a feature with Superwall (feature gating)
    /// This will automatically show a paywall if needed, otherwise execute the feature
    /// - Parameters:
    ///   - placement: The placement identifier
    ///   - feature: The feature to execute if user has access
    func registerSuperwallFeature(placement: String, feature: @escaping () -> Void) {
        Superwall.shared.register(placement: placement, params: nil) {
            feature()
        }
    }
    
    // MARK: - Local Overrides
    
    func grantLifetimeAccess() {
        hasLifetimeAccess = true
        hasPremiumAccess = true
        shouldShowPaywall = false
        
        // Verify integrity after setting (security check)
        verifyAccessIntegrity()
    }
    
    func grantSubscription(expiryDate: Date) {
        subscriptionExpiryTimestamp = expiryDate.timeIntervalSince1970
        hasPremiumAccess = true
        shouldShowPaywall = false
        
        // Verify integrity after setting (security check)
        verifyAccessIntegrity()
    }
    
    /// Verifies integrity of access flags to detect tampering
    private func verifyAccessIntegrity() {
        guard let storedHash = UserDefaults.standard.string(forKey: "promo_access_integrity") else {
            // No integrity hash stored (legacy or first-time)
            return
        }
        
        let computedHash = PromoSecurityManager.shared.createIntegrityHash(
            hasLifetime: hasLifetimeAccess,
            hasPremium: hasPremiumAccess,
            expiryTimestamp: subscriptionExpiryTimestamp
        )
        
        // If hash doesn't match, access may have been tampered with
        if storedHash != computedHash {
            #if DEBUG
            print("⚠️ PaywallManager: Access integrity check failed - possible tampering detected")
            #endif
            
            // Track integrity failure
            AnalyticsService.shared.logEvent(
                .custom(
                    name: "integrity_check_failed",
                    parameters: [
                        "stored_hash": storedHash,
                        "computed_hash": computedHash
                    ]
                )
            )
        }
    }

    func resetPaywallData() {
        paywallDelayWorkItem?.cancel()
        paywallDelayWorkItem = nil
        wallpaperExportCount = 0
        hasPremiumAccess = false
        hasLifetimeAccess = false
        subscriptionExpiryTimestamp = 0
        hasSeenPaywall = false
        paywallDismissCount = 0
        shouldShowPaywall = false
        lastErrorMessage = nil
        
        // NOTE: Promo codes are NOT deleted here - they persist across paywall resets
        // This allows users to reset and test, but keeps admin-generated codes safe
    }
    
    func trackPaywallDismiss() {
        paywallDismissCount += 1
    }
    
    func trackPaywallView() {
        #if DEBUG
        print("📊 PaywallManager: Paywall viewed. Reason: \(paywallTriggerReason)")
        #endif
    }
    
    func resetForFreshInstall() {
        resetPaywallData()
    }
}

// MARK: - PurchasesDelegate
extension PaywallManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: RevenueCat.CustomerInfo) {
        DispatchQueue.main.async {
            self.handle(customerInfo: customerInfo)
        }
    }
}

// MARK: - Paywall Trigger Reason
enum PaywallTriggerReason: String {
    case firstWallpaperCreated = "first_wallpaper"
    case limitReached = "limit_reached"
    case manual = "manual"
    case settings = "settings"
    case exitIntercept = "exit_intercept"
    
    var title: String {
        switch self {
        case .firstWallpaperCreated:
            return "Your Wallpaper is Ready! 🎉"
        case .limitReached:
            return "Free Limit Reached"
        case .manual, .settings:
            return "Upgrade to NoteWall+"
        case .exitIntercept:
            return "Special Offer - 30% Off!"
        }
    }
    
    var message: String {
        switch self {
        case .firstWallpaperCreated:
            return "Love it? Unlock unlimited wallpapers and keep your lock screen fresh every day."
        case .limitReached:
            return "You've created your free wallpapers. Upgrade to keep creating unlimited wallpapers."
        case .manual, .settings:
            return "Get unlimited wallpapers, premium features, and support future development."
        case .exitIntercept:
            return "We'd love to keep you! Here's a special one-time discount just for you."
        }
    }
}
