import Foundation
import SwiftUI
import RevenueCat

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
    
    // MARK: - Published Properties
    @Published var shouldShowPaywall: Bool = false
    @Published var paywallTriggerReason: PaywallTriggerReason = .limitReached
    @Published var offerings: Offerings?
    @Published var availablePackages: [Package] = []
    @Published var customerInfo: CustomerInfo?
    @Published var isLoadingOfferings: Bool = false
    @Published var isProcessingPurchase: Bool = false
    @Published var lastErrorMessage: String?
    
    // MARK: - Constants
    private let freeExportLimit = 3
    private let entitlementID = "Notewall+"
    private let lifetimeProductID = "lifetime"
    private var paywallDelayWorkItem: DispatchWorkItem?
    private var hasConnectedToRevenueCat = false
    
    // MARK: - Computed Properties
    var isPremium: Bool {
        return hasActiveRevenueCatEntitlement || hasLifetimeAccess || hasActiveSubscription
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
        checkPaywallOnLaunch()
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
        } catch {
            lastErrorMessage = "Unable to refresh customer info: \(error.localizedDescription)"
            #if DEBUG
            print("❌ RevenueCat: \(error)")
            #endif
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
                isProcessingPurchase = false
                shouldShowPaywall = false
            }
        } catch {
            await MainActor.run {
                isProcessingPurchase = false
                lastErrorMessage = purchaseErrorMessage(error)
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
            }
        } catch {
            await MainActor.run {
                isProcessingPurchase = false
                lastErrorMessage = "Restore failed: \(error.localizedDescription)"
            }
        }
    }

    private func handle(customerInfo: CustomerInfo) {
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
        guard !isPremium else { return }
        
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
        isPremium || !hasReachedFreeLimit
    }
    
    func showPaywall(reason: PaywallTriggerReason = .manual) {
        paywallTriggerReason = reason
        shouldShowPaywall = true
    }
    
    // MARK: - Local Overrides
    
    func grantLifetimeAccess() {
        hasLifetimeAccess = true
        hasPremiumAccess = true
        shouldShowPaywall = false
    }
    
    func grantSubscription(expiryDate: Date) {
        subscriptionExpiryTimestamp = expiryDate.timeIntervalSince1970
        hasPremiumAccess = true
        shouldShowPaywall = false
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
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
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
