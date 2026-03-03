import Foundation
import SwiftUI
import SuperwallKit
import StoreKit

/// Manages paywall state and premium status
final class PaywallManager: NSObject, ObservableObject {
    static let shared = PaywallManager()
    static let defaultPlacement = "campaign_trigger"
    static let discountPlacement = "yearly_discount"
    static let discountProductID = "yearly_discount"

    @AppStorage("wallpaperExportCount") var wallpaperExportCount: Int = 0
    @AppStorage("hasPremiumAccess") var hasPremiumAccess: Bool = false
    @AppStorage("hasLifetimeAccess") var hasLifetimeAccess: Bool = false
    @AppStorage("subscriptionExpiryDate") var subscriptionExpiryTimestamp: Double = 0
    @AppStorage("hasSeenPaywall") var hasSeenPaywall: Bool = false
    @AppStorage("paywallDismissCount") var paywallDismissCount: Int = 0
    @AppStorage("trialStartDate") var trialStartDateTimestamp: Double = 0
    @AppStorage("superwallPurchaseAttemptTimestamp") private var superwallPurchaseAttemptTimestamp: Double = 0
    @AppStorage("superwallLastDiscountFallbackTriggerTimestamp") private var superwallLastDiscountFallbackTriggerTimestamp: Double = 0

    @Published var shouldShowPaywall: Bool = false
    @Published var paywallTriggerReason: PaywallTriggerReason = .limitReached
    @Published var shouldShowSuperwallPaywall: Bool = false
    @Published var superwallPlacement: String = ""
    @Published var shouldShowSwiftUIDiscountFallback: Bool = false
    @Published var isLoadingOfferings: Bool = false
    @Published var isProcessingPurchase: Bool = false
    @Published var isProcessingDiscountPurchase: Bool = false
    @Published var lastErrorMessage: String?

    private let freeExportLimit = 0
    private let defaultSuperwallPlacement = PaywallManager.defaultPlacement
    private var paywallDelayWorkItem: DispatchWorkItem?

    var isPremium: Bool {
        hasActiveSuperwallEntitlement || hasLifetimeAccess || hasActiveSubscription || hasPremiumAccess
    }

    var hasActiveSuperwallEntitlement: Bool {
        Superwall.shared.subscriptionStatus.isActive
    }

    var trialStartDate: Date? {
        guard trialStartDateTimestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: trialStartDateTimestamp)
    }

    var shouldShowTrialReminder: Bool {
        guard let start = trialStartDate else { return false }
        let now = Date()
        let hoursElapsed = now.timeIntervalSince(start) / 3600
        return hoursElapsed >= 24 && hoursElapsed < 72 && isPremium
    }

    var hasActiveSubscription: Bool {
        guard subscriptionExpiryTimestamp > 0 else { return false }
        let expiryDate = Date(timeIntervalSince1970: subscriptionExpiryTimestamp)
        return Date() < expiryDate
    }

    var remainingFreeExports: Int {
        max(0, freeExportLimit - wallpaperExportCount)
    }

    var hasReachedFreeLimit: Bool {
        wallpaperExportCount >= freeExportLimit
    }

    private override init() {
        super.init()
        restoreLegacyAccessIfNeeded()
    }

    @MainActor
    func refreshCustomerInfo() async {
        hasPremiumAccess = hasActiveSuperwallEntitlement || hasLifetimeAccess || hasActiveSubscription
        SuperwallUserAttributesManager.shared.updateSubscriptionAttributes()
        checkPaywallOnLaunch()
    }

    @MainActor
    func loadOfferings(force: Bool = false) async {
        isLoadingOfferings = false
    }

    @MainActor
    func restorePurchases() async {
        await refreshCustomerInfo()

        if isPremium {
            AnalyticsService.shared.logEvent(.restoreSuccess())
        } else {
            AnalyticsService.shared.logEvent(.restoreFail(errorCode: "no_active_entitlement"))
        }
    }

    @MainActor
    func restoreRevenueCatPurchases() async {
        await restorePurchases()
    }

    func checkPaywallOnLaunch() {
        guard !isPremium else { return }

        let hasCompletedSetup = UserDefaults.standard.bool(forKey: "hasCompletedSetup")
        if hasCompletedSetup && hasReachedFreeLimit {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                guard !self.isPremium else { return }
                self.presentSuperwallPaywall(placement: self.defaultSuperwallPlacement)
            }
        }
    }

    func trackWallpaperExport() {
        guard !isPremium else { return }

        wallpaperExportCount += 1

        AnalyticsService.shared.logEvent(
            .wallpaperExport(count: wallpaperExportCount, isPremium: isPremium),
            additionalParams: [
                "free_limit": freeExportLimit,
                "remaining": max(0, freeExportLimit - wallpaperExportCount),
                "reached_limit": hasReachedFreeLimit
            ]
        )

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
                self.presentSuperwallPaywall(placement: self.defaultSuperwallPlacement)
                self.hasSeenPaywall = true
            }
        }

        paywallDelayWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }

    func canExportWallpaper() -> Bool {
        isPremium
    }

    func showPaywall(reason: PaywallTriggerReason = .manual) {
        paywallTriggerReason = reason
        presentSuperwallPaywall(placement: defaultSuperwallPlacement)
    }

    func presentSuperwallPaywall(placement: String) {
        superwallPlacement = placement
        shouldShowSuperwallPaywall = true
    }

    func markPurchaseAttemptFromPaywall() {
        superwallPurchaseAttemptTimestamp = Date().timeIntervalSince1970
    }

    func consumeRecentPurchaseAttempt(maxAge: TimeInterval = 120) -> Bool {
        guard superwallPurchaseAttemptTimestamp > 0 else { return false }
        let age = Date().timeIntervalSince1970 - superwallPurchaseAttemptTimestamp
        superwallPurchaseAttemptTimestamp = 0
        return age >= 0 && age <= maxAge
    }

    func hasRecentPurchaseAttempt(maxAge: TimeInterval = 120) -> Bool {
        guard superwallPurchaseAttemptTimestamp > 0 else { return false }
        let age = Date().timeIntervalSince1970 - superwallPurchaseAttemptTimestamp
        return age >= 0 && age <= maxAge
    }

    func clearPurchaseAttemptFlag() {
        superwallPurchaseAttemptTimestamp = 0
    }

    func canTriggerDiscountFallback(minInterval: TimeInterval = 4) -> Bool {
        let now = Date().timeIntervalSince1970
        let elapsed = now - superwallLastDiscountFallbackTriggerTimestamp
        guard elapsed >= minInterval else { return false }
        superwallLastDiscountFallbackTriggerTimestamp = now
        return true
    }

    func registerSuperwallFeature(placement: String, feature: @escaping () -> Void) {
        Superwall.shared.register(placement: placement, params: nil) {
            feature()
        }
    }

    @MainActor
    func purchaseDiscountProduct() async {
        guard !isProcessingDiscountPurchase else { return }
        isProcessingDiscountPurchase = true
        lastErrorMessage = nil
        defer { isProcessingDiscountPurchase = false }

        do {
            let products = try await Product.products(for: [PaywallManager.discountProductID])
            guard let product = products.first else {
                print("⚠️ PaywallManager: discount product '\(PaywallManager.discountProductID)' not found in StoreKit")
                lastErrorMessage = "Product not found. Please try again."
                return
            }
            print("✅ PaywallManager: Initiating direct purchase for \(product.displayName) (\(product.id))")
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    print("✅ PaywallManager: discount purchase succeeded — \(transaction.productID)")
                    if let expirationDate = transaction.expirationDate {
                        subscriptionExpiryTimestamp = expirationDate.timeIntervalSince1970
                    }
                    hasPremiumAccess = true
                    shouldShowSuperwallPaywall = false
                    superwallPlacement = ""
                    shouldShowSwiftUIDiscountFallback = false
                    SuperwallUserAttributesManager.shared.updateSubscriptionAttributes()
                case .unverified(_, let error):
                    print("⚠️ PaywallManager: discount purchase unverified — \(error)")
                }
            case .pending:
                print("ℹ️ PaywallManager: discount purchase pending")
            case .userCancelled:
                print("ℹ️ PaywallManager: discount purchase cancelled by user")
            @unknown default:
                break
            }
        } catch {
            print("❌ PaywallManager: discount purchase error — \(error)")
            lastErrorMessage = error.localizedDescription
        }
    }

    func grantLifetimeAccess() {
        hasLifetimeAccess = true
        hasPremiumAccess = true
        shouldShowPaywall = false
        SuperwallUserAttributesManager.shared.updateSubscriptionAttributes()
        verifyAccessIntegrity()
    }

    func grantSubscription(expiryDate: Date) {
        subscriptionExpiryTimestamp = expiryDate.timeIntervalSince1970
        hasPremiumAccess = true
        shouldShowPaywall = false
        SuperwallUserAttributesManager.shared.updateSubscriptionAttributes()
        verifyAccessIntegrity()
    }

    private func verifyAccessIntegrity() {
        guard let storedHash = UserDefaults.standard.string(forKey: "promo_access_integrity") else {
            return
        }

        let computedHash = PromoSecurityManager.shared.createIntegrityHash(
            hasLifetime: hasLifetimeAccess,
            hasPremium: hasPremiumAccess,
            expiryTimestamp: subscriptionExpiryTimestamp
        )

        if storedHash != computedHash {
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

    private func restoreLegacyAccessIfNeeded() {
        if hasActiveSubscription || hasLifetimeAccess {
            hasPremiumAccess = true
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
        shouldShowSuperwallPaywall = false
        superwallPlacement = ""
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
            return "Special Offer"
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
            return "We'd love to keep you! Here's a special offer just for you."
        }
    }
}