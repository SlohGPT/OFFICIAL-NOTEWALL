import Foundation
import SuperwallKit

final class NoteWallSuperwallDelegate: NSObject, SuperwallDelegate {
    static let shared = NoteWallSuperwallDelegate()

    private override init() {
        super.init()
    }

    func handleCustomPaywallAction(withName name: String) {
        if name == "purchase_attempt" {
            PaywallManager.shared.markPurchaseAttemptFromPaywall()
        }
    }

    func subscriptionStatusDidChange(from oldValue: SubscriptionStatus, to newValue: SubscriptionStatus) {
        print("🔔 Superwall subscriptionStatus changed: \(oldValue) → \(newValue)")
        Task { @MainActor in
            // Sync local premium state with both Superwall and StoreKit
            await PaywallManager.shared.refreshCustomerInfo()
            print("ℹ️ PaywallManager: After sync — isPremium=\(PaywallManager.shared.isPremium), hasPremiumAccess=\(PaywallManager.shared.hasPremiumAccess), superwallActive=\(PaywallManager.shared.hasActiveSuperwallEntitlement)")
        }
    }

    func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
        // Forward key Superwall events to Mixpanel for analytics
        // (per Superwall 3rd Party Analytics docs)
        forwardEventToAnalytics(eventInfo)

        switch eventInfo.event {
        case .transactionAbandon:
            let consumedRecentAttempt = PaywallManager.shared.consumeRecentPurchaseAttempt(maxAge: 300)
            guard consumedRecentAttempt else {
                print("Superwall: transactionAbandon detected without recent purchase_attempt; ignoring")
                return
            }
            guard PaywallManager.shared.canTriggerDiscountFallback(minInterval: 4) else {
                print("Superwall: transactionAbandon duplicate within cooldown; ignoring")
                return
            }
            guard !PaywallManager.shared.shouldShowSwiftUIDiscountFallback else {
                print("Superwall: transactionAbandon detected but fallback already active; ignoring duplicate")
                return
            }
            print("Superwall: transactionAbandon detected after purchase_attempt - opening SwiftUI discount fallback")
            PaywallManager.shared.shouldShowSuperwallPaywall = false
            PaywallManager.shared.superwallPlacement = ""
            PaywallManager.shared.shouldShowSwiftUIDiscountFallback = true
        default:
            break
        }
    }

    // MARK: - 3rd Party Analytics Forwarding

    /// Forwards important Superwall events to Mixpanel so you get paywall
    /// funnel analytics (open → start purchase → complete/abandon/fail)
    /// alongside your existing app analytics.
    private func forwardEventToAnalytics(_ eventInfo: SuperwallEventInfo) {
        let event = eventInfo.event
        switch event {
        case .paywallOpen(let paywallInfo):
            AnalyticsService.shared.logEvent(
                .custom(name: "superwall_paywall_open", parameters: [
                    "paywall_id": paywallInfo.identifier
                ])
            )
        case .paywallClose(let paywallInfo):
            AnalyticsService.shared.logEvent(
                .custom(name: "superwall_paywall_close", parameters: [
                    "paywall_id": paywallInfo.identifier
                ])
            )
        case .transactionStart(let product, let paywallInfo):
            AnalyticsService.shared.logEvent(
                .custom(name: "superwall_transaction_start", parameters: [
                    "product_id": product.productIdentifier,
                    "paywall_id": paywallInfo.identifier
                ])
            )
        case .transactionComplete(let transaction, let product, _, let paywallInfo):
            AnalyticsService.shared.logEvent(
                .custom(name: "superwall_transaction_complete", parameters: [
                    "product_id": product.productIdentifier,
                    "paywall_id": paywallInfo.identifier,
                    "transaction_id": transaction?.storeTransactionId ?? "unknown"
                ])
            )
        case .transactionFail(let error, let paywallInfo):
            AnalyticsService.shared.logEvent(
                .custom(name: "superwall_transaction_fail", parameters: [
                    "error": error.localizedDescription,
                    "paywall_id": paywallInfo.identifier
                ])
            )
        case .transactionAbandon(let product, let paywallInfo):
            AnalyticsService.shared.logEvent(
                .custom(name: "superwall_transaction_abandon", parameters: [
                    "product_id": product.productIdentifier,
                    "paywall_id": paywallInfo.identifier
                ])
            )
        case .subscriptionStart(let product, let paywallInfo):
            AnalyticsService.shared.logEvent(
                .custom(name: "superwall_subscription_start", parameters: [
                    "product_id": product.productIdentifier,
                    "paywall_id": paywallInfo.identifier
                ])
            )
        case .freeTrialStart(let product, let paywallInfo):
            AnalyticsService.shared.logEvent(
                .custom(name: "superwall_free_trial_start", parameters: [
                    "product_id": product.productIdentifier,
                    "paywall_id": paywallInfo.identifier
                ])
            )
        case .transactionRestore(let restoreType, let paywallInfo):
            AnalyticsService.shared.logEvent(
                .custom(name: "superwall_transaction_restore", parameters: [
                    "restore_type": "\(restoreType)",
                    "paywall_id": paywallInfo.identifier
                ])
            )
        default:
            break
        }
    }
}
