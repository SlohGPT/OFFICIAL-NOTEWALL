import SwiftUI
import UIKit

@MainActor
final class DiscountFallbackWindowPresenter {
    static let shared = DiscountFallbackWindowPresenter()

    private var window: UIWindow?

    private init() {}

    func presentIfNeeded() {
        guard window == nil else { return }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) else {
            print("⚠️ DiscountFallbackWindowPresenter: No active window scene available")
            return
        }

        let hostingController = UIHostingController(rootView: DiscountFallbackWindowRootView())
        hostingController.view.backgroundColor = .clear

        let overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow.rootViewController = hostingController
        overlayWindow.windowLevel = .alert + 1
        overlayWindow.backgroundColor = .clear
        overlayWindow.isHidden = false

        window = overlayWindow
        print("✅ DiscountFallbackWindowPresenter: Presented overlay window")
    }

    func dismissIfNeeded() {
        guard let window else { return }
        window.isHidden = true
        self.window = nil
        print("ℹ️ DiscountFallbackWindowPresenter: Dismissed overlay window")
    }
}

@available(iOS 15.0, *)
private struct DiscountFallbackWindowRootView: View {
    @StateObject private var paywallManager = PaywallManager.shared

    private var isPresentedBinding: Binding<Bool> {
        Binding(
            get: { paywallManager.shouldShowSwiftUIDiscountFallback },
            set: { newValue in
                paywallManager.shouldShowSwiftUIDiscountFallback = newValue
                if !newValue {
                    Task { @MainActor in
                        DiscountFallbackWindowPresenter.shared.dismissIfNeeded()
                    }
                }
            }
        )
    }

    var body: some View {
        Group {
            if paywallManager.shouldShowSwiftUIDiscountFallback {
                DismissedPaywallDiscountView(isPresented: isPresentedBinding)
                    .ignoresSafeArea()
            } else {
                Color.clear
                    .ignoresSafeArea()
            }
        }
    }
}
