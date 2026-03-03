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
        Task {
            await PaywallManager.shared.refreshCustomerInfo()
        }
    }

    func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
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
}
