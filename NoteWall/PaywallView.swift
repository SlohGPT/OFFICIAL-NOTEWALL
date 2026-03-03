import SwiftUI

@available(iOS 15.0, *)
struct PaywallView: View {
    let triggerReason: PaywallTriggerReason
    let allowDismiss: Bool
    private let initialExitInterceptDiscount: Bool

    init(triggerReason: PaywallTriggerReason = .manual, allowDismiss: Bool = true, applyExitInterceptDiscount: Bool = false) {
        self.triggerReason = triggerReason
        self.allowDismiss = allowDismiss
        self.initialExitInterceptDiscount = applyExitInterceptDiscount
    }

    private var placement: String {
        if initialExitInterceptDiscount || triggerReason == .exitIntercept {
            return PaywallManager.discountPlacement
        }
        return PaywallManager.defaultPlacement
    }

    var body: some View {
        SuperwallPaywallView(placement: placement)
            .interactiveDismissDisabled(!allowDismiss)
            .onAppear {
                AnalyticsService.shared.trackPaywallImpression(
                    paywallId: triggerReason.rawValue,
                    trigger: triggerReason.rawValue,
                    placement: placement
                )
            }
    }
}

#Preview {
    if #available(iOS 15.0, *) {
        PaywallView(triggerReason: .manual)
    }
}