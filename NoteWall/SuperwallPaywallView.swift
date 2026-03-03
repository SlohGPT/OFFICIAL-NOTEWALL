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
                dismiss()
            case .purchased(let product):
                print("Superwall: User purchased \(product.productIdentifier)")
                paywallManager.clearPurchaseAttemptFlag()
                // Update premium status if needed
                Task {
                    await paywallManager.refreshCustomerInfo()
                }
            case .restored:
                print("Superwall: User restored purchases")
                paywallManager.clearPurchaseAttemptFlag()
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

@available(iOS 15.0, *)
struct DismissedPaywallDiscountView: View {
    @Binding var isPresented: Bool
    @StateObject private var paywallManager = PaywallManager.shared
    @State private var giftOfferRemainingSeconds: Int = 120
    @State private var giftOfferEndDate: Date? = Date().addingTimeInterval(120)
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 28
    @State private var contentScale: CGFloat = 0.96
    @State private var isAnimatingDismiss = false

    private let giftOfferCountdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var giftOfferTimerText: String {
        let minutes = max(0, giftOfferRemainingSeconds) / 60
        let seconds = max(0, giftOfferRemainingSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.12),
                    Color(red: 0.02, green: 0.02, blue: 0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: {
                        dismissAnimated()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 58)

                Spacer(minLength: 8)

                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("One Time Offer")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)

                        Text("30% OFF")
                            .font(.system(size: 56, weight: .heavy, design: .rounded))
                            .foregroundColor(.appAccent)
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)
                            .shadow(color: Color.appAccent.opacity(0.3), radius: 8, x: 0, y: 4)

                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 18, weight: .semibold))
                            Text("You will not see this offer again")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 6) {
                        Text("BEFORE YOU GO")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                            .kerning(2.5)
                        Text("Lock in 30% off — today only")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("This deal disappears when you leave")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.appAccent.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .stroke(Color.appAccent.opacity(0.25), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)

                    VStack(spacing: 14) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 90, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.appAccent.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.appAccent.opacity(0.4), radius: 20, x: 0, y: 10)

                        HStack(spacing: 10) {
                            Image(systemName: "alarm.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text(giftOfferTimerText)
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                                .overlay(
                                    Capsule().stroke(Color.appAccent.opacity(0.4), lineWidth: 1)
                                )
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.bottom, 4)
                }
                .padding(.horizontal, 12)

                Spacer(minLength: 16)

                Button(action: {
                    guard giftOfferRemainingSeconds > 0 else { return }
                    guard !paywallManager.isProcessingDiscountPurchase else { return }
                    Task {
                        await paywallManager.purchaseDiscountProduct()
                    }
                }) {
                    HStack(spacing: 10) {
                        if paywallManager.isProcessingDiscountPurchase {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                        }
                        Text(giftOfferRemainingSeconds > 0 ? "Claim your one time offer" : "Offer expired")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                    }
                    .frame(height: 64)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.appAccent.opacity(0.95), Color.appAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.black.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: Color.appAccent.opacity(0.35), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 24)
                .disabled(giftOfferRemainingSeconds <= 0 || paywallManager.isProcessingDiscountPurchase)

                HStack(spacing: 28) {
                    Button("Privacy") {
                        if let url = URL(string: "https://peat-appendix-c3c.notion.site/PRIVACY-POLICY-2b7f6a63758f804cab16f58998d7787e?source=copy_link") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                    Button("Terms") {
                        if let url = URL(string: "https://peat-appendix-c3c.notion.site/TERMS-OF-USE-2b7f6a63758f8067a318e16486b16f47?source=copy_link") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                    Button("Restore") {
                        Task {
                            await paywallManager.restorePurchases()
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                }
                .padding(.top, 16)
                .padding(.bottom, 18)
            }
            .opacity(contentOpacity)
            .offset(y: contentOffset)
            .scaleEffect(contentScale)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .interactiveDismissDisabled(true)
        .onReceive(giftOfferCountdownTimer) { _ in
            updateGiftOfferCountdownIfNeeded()
        }
        .onAppear {
            print("✅ DismissedPaywallDiscountView: appeared")
            giftOfferEndDate = Date().addingTimeInterval(120)
            giftOfferRemainingSeconds = 120
            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                contentOpacity = 1
                contentOffset = 0
                contentScale = 1
            }
        }
        .onDisappear {
            print("ℹ️ DismissedPaywallDiscountView: disappeared")
        }
    }

    private func dismissAnimated(onCompletion: (() -> Void)? = nil) {
        guard !isAnimatingDismiss else { return }
        isAnimatingDismiss = true

        withAnimation(.easeInOut(duration: 0.26)) {
            contentOpacity = 0
            contentOffset = 22
            contentScale = 0.97
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            isPresented = false
            onCompletion?()
        }
    }

    private func updateGiftOfferCountdownIfNeeded() {
        guard let endDate = giftOfferEndDate else { return }
        let remaining = Int(endDate.timeIntervalSinceNow.rounded(.down))
        giftOfferRemainingSeconds = max(0, remaining)
    }
}

