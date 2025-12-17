//
// Sharing snippet: AppIconAnimationView
// - Same animation math as the app's animated icon.
// - Uses generic gradient colors; swap in your own palette if you like.
// - Loads "AppIcon" from Assets; falls back to the gradient if missing.
// - Drop-in and re-usable code.
//
 
 
import SwiftUI
import Combine
import UIKit
 
struct AppIconAnimationView: View {
 
    /// The time interval for the animation.
    @State private var animationTime: TimeInterval = 0
 
    /// The size of the icon.
    let size: CGFloat
 
    /// The initializer for the view.
    /// - Parameters:
    ///   - size: The size of the icon. Defaults to 64.
    init(size: CGFloat = 64) {
        self.size = size
    }
 
    var body: some View {
        // 3-second loop; shorter cycle keeps motion lively.
        let cycle: Double = 3.0
        let t = animationTime
 
        // Phase offsets create non-uniform waves so the tilt feels organic.
        let phase1 = t * 2 * .pi / cycle
        let phase2 = t * 2 * .pi / cycle * 0.6
        let phase3 = t * 2 * .pi / cycle * 1.4
 
        // Combined sines/cosines drive a gentle wobble and subtle lift.
        let angleX = sin(phase1) * 14 + sin(phase3) * 4
        let angleY = cos(phase2) * 12 + sin(phase1 * 1.3) * 3
        let translateZ = sin(phase1 * 0.8) * 10
        let shadowIntensity = 0.12 + sin(phase1) * 0.04
 
        let appIcon = appIconImage
 
        ZStack {
            if let appIcon {
                Image(uiImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                // Fallback gradient if no icon is resolved.
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(Image(systemName: "video.fill").foregroundStyle(.white))
            }
        }
        .frame(width: size, height: size)
        // Two-axis tilt to mimic a gentle hover.
        .rotation3DEffect(.degrees(angleX), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
        .rotation3DEffect(.degrees(angleY), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
        // Small vertical drift to reinforce depth.
        .transformEffect(CGAffineTransform(translationX: 0, y: translateZ * 0.08))
        // Soft shadow that shifts with the tilt.
        .shadow(
            color: .black.opacity(shadowIntensity),
            radius: 7 + sin(phase1) * 2,
            x: sin(angleY * .pi / 180) * 2.5,
            y: 3 + sin(angleX * .pi / 180) * 1.5
        )
        .accessibilityHidden(true)
        // Drive the animation at 120 Hz; reset after a long run to avoid drift.
        .onReceive(Timer.publish(every: 1.0/120.0, on: .main, in: .common).autoconnect()) { _ in
            animationTime += 1.0/120.0
            if animationTime > cycle * 100 {
                animationTime = 0
            }
        }
    }
 
    // Tries to load the app icon from the asset catalog.
    // First tries "OnboardingLogo" (used in onboarding and paywall), then falls back to "AppIcon" (App Store icon)
    // Both now use the same new app icon design
    private var appIconImage: UIImage? {
        UIImage(named: "OnboardingLogo") ?? UIImage(named: "AppIcon")
    }
}
 
// MARK: - Preview
 
#Preview("Animated App Icon") {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()
 
        AppIconAnimationView(size: 96)
    }
    .padding(24)
}

