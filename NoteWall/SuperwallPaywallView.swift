import SwiftUI
import SuperwallKit

/// SwiftUI wrapper for Superwall's PaywallView
struct SuperwallPaywallView: View {
    let placement: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var paywallManager = PaywallManager.shared
    
    var body: some View {
        SuperwallKit.PaywallView(placement: placement, params: nil, paywallOverrides: nil) { info, result in
            // Handle paywall result
            switch result {
            case .declined:
                print("Superwall: User declined paywall")
            case .purchased(let product):
                print("Superwall: User purchased \(product.productIdentifier)")
                // Update premium status if needed
                Task {
                    await paywallManager.refreshCustomerInfo()
                }
            case .restored:
                print("Superwall: User restored purchases")
                // Update premium status if needed
                Task {
                    await paywallManager.refreshCustomerInfo()
                }
            }
        } feature: {
            // This closure is called when the user has access (either purchased or already subscribed)
            print("Superwall: User has access to feature")
            dismiss()
        }
    }
}

