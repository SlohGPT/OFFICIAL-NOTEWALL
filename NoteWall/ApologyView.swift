import SwiftUI

// MARK: - Apology View
/// Empathetic apology screen shown to pre-Feb 9th premium users
/// who experienced the bug that caused the app not to work properly.
/// Shown only ONCE, before the What's New migration prompt.

struct ApologyView: View {
    
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)? = nil
    
    // MARK: - Animation States
    
    @State private var backgroundGlow: Double = 0.3
    @State private var heartScale: CGFloat = 0.5
    @State private var heartOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var messageOpacity: Double = 0
    @State private var promiseOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var heartBeat: Bool = false
    @State private var floatingY: CGFloat = 0
    @State private var shimmerX: CGFloat = -200
    @State private var sparkleRotation: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0
    
    private var isCompact: Bool {
        ScreenDimensions.height < 750
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
                .ignoresSafeArea()
            
            // Floating particles
            ApologyParticlesView()
                .ignoresSafeArea()
                .opacity(0.6)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: isCompact ? 20 : 28) {
                    
                    Spacer()
                        .frame(height: isCompact ? 40 : 60)
                    
                    // MARK: - Heart Icon with Glow
                    heartSection
                    
                    // MARK: - Title
                    titleSection
                    
                    // MARK: - Apology Message
                    messageSection
                    
                    // MARK: - Our Promise
                    promiseSection
                    
                    Spacer()
                        .frame(height: isCompact ? 8 : 16)
                    
                    // MARK: - Accept Button
                    acceptButton
                    
                    Spacer()
                        .frame(height: isCompact ? 20 : 40)
                }
                .padding(.horizontal, 28)
            }
        }
        .onAppear {
            startAnimations()
            
            // Analytics
            AnalyticsService.shared.trackScreenView(screenName: "apology_screen")
            AnalyticsService.shared.logEvent("apology_screen_shown", properties: [
                "is_premium": PaywallManager.shared.isPremium
            ])
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color.black
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Warm radial glow from the heart
            RadialGradient(
                gradient: Gradient(colors: [
                    Color("AppAccent").opacity(backgroundGlow * 0.15),
                    Color("AppAccent").opacity(backgroundGlow * 0.05),
                    Color.clear
                ]),
                center: .center,
                startRadius: 20,
                endRadius: 350
            )
            .offset(y: -80)
        }
    }
    
    // MARK: - Heart Section
    
    private var heartSection: some View {
        ZStack {
            // Animated rings behind heart
            Circle()
                .stroke(
                    Color("AppAccent").opacity(ringOpacity * 0.3),
                    lineWidth: 1.5
                )
                .frame(width: 120, height: 120)
                .scaleEffect(ringScale)
            
            Circle()
                .stroke(
                    Color("AppAccent").opacity(ringOpacity * 0.15),
                    lineWidth: 1
                )
                .frame(width: 150, height: 150)
                .scaleEffect(ringScale * 1.1)
            
            // Glow behind heart
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color("AppAccent").opacity(0.3),
                            Color("AppAccent").opacity(0.05),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 10,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(heartBeat ? 1.15 : 1.0)
            
            // Heart icon
            Image(systemName: "heart.fill")
                .font(.system(size: isCompact ? 52 : 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color("AppAccent"),
                            Color("AppAccent").opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color("AppAccent").opacity(0.5), radius: 20, x: 0, y: 8)
                .scaleEffect(heartScale)
                .scaleEffect(heartBeat ? 1.08 : 1.0)
                .offset(y: floatingY)
            
            // Small sparkle accents
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 10))
                    .foregroundColor(Color("AppAccent").opacity(0.6))
                    .offset(
                        x: CGFloat(cos(sparkleRotation + Double(i) * 2.094)) * 55,
                        y: CGFloat(sin(sparkleRotation + Double(i) * 2.094)) * 55
                    )
                    .opacity(heartOpacity * 0.7)
            }
        }
        .opacity(heartOpacity)
        .padding(.bottom, isCompact ? 4 : 8)
    }
    
    // MARK: - Title
    
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("We Owe You an Apology")
                .font(.system(size: isCompact ? 26 : 30, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Subtle accent line
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [
                            Color("AppAccent").opacity(0.0),
                            Color("AppAccent").opacity(0.6),
                            Color("AppAccent").opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 80, height: 3)
        }
        .opacity(titleOpacity)
    }
    
    // MARK: - Message
    
    private var messageSection: some View {
        VStack(spacing: isCompact ? 14 : 18) {
            Text("We're truly sorry for the experience you had. A bug in a recent update caused the app to not work as expected, and we know how frustrating that must have been.")
                .font(.system(size: isCompact ? 15 : 16))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            Text("You trusted us with something personal — your notes, your wallpapers, your daily routine — and we let you down. That's on us.")
                .font(.system(size: isCompact ? 15 : 16))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 4)
        .opacity(messageOpacity)
    }
    
    // MARK: - Promise Section
    
    private var promiseSection: some View {
        VStack(spacing: isCompact ? 14 : 18) {
            // Divider
            HStack(spacing: 12) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color("AppAccent").opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                
                Image(systemName: "shield.checkered")
                    .font(.system(size: 14))
                    .foregroundColor(Color("AppAccent").opacity(0.7))
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color("AppAccent").opacity(0.3), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 10) {
                Text("Here's What We've Done")
                    .font(.system(size: isCompact ? 16 : 17, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("We've completely rebuilt the update system from scratch. It's now faster, more reliable, and specifically designed to just work — every single time.")
                    .font(.system(size: isCompact ? 14 : 15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            
            // Promise card
            HStack(spacing: 14) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color("AppAccent"))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Our Promise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("Your subscription stays exactly the same. No extra charges, no hoops to jump through. Just a better experience.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.65))
                        .lineSpacing(2)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color("AppAccent").opacity(0.3),
                                        Color("AppAccent").opacity(0.1),
                                        Color("AppAccent").opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .opacity(promiseOpacity)
    }
    
    // MARK: - Accept Button
    
    private var acceptButton: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            AnalyticsService.shared.logEvent("apology_screen_accepted")
            ApologyManager.shared.markAsShown()
            
            withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onDismiss?()
            }
        }) {
            ZStack {
                Text("Thank You — Let's Move Forward")
                    .font(.system(size: isCompact ? 16 : 17, weight: .semibold))
                    .foregroundColor(.white)
                
                // Shimmer sweep
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.15),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 60)
                    .offset(x: shimmerX)
                    .mask(
                        RoundedRectangle(cornerRadius: 16)
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? 52 : 56)
            .background(
                LinearGradient(
                    colors: [
                        Color("AppAccent"),
                        Color("AppAccent").opacity(0.8)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color("AppAccent").opacity(0.4), radius: 16, x: 0, y: 8)
        }
        .opacity(buttonOpacity)
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        // Background glow pulse
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            backgroundGlow = 0.6
        }
        
        // Heart entrance
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
            heartScale = 1.0
            heartOpacity = 1.0
        }
        
        // Ring expansion
        withAnimation(.easeOut(duration: 1.2).delay(0.5)) {
            ringScale = 1.2
            ringOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true).delay(1.7)) {
            ringScale = 1.35
            ringOpacity = 0.0
        }
        
        // Heartbeat
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(1.2)) {
            heartBeat = true
        }
        
        // Floating motion
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(1.0)) {
            floatingY = -6
        }
        
        // Sparkle rotation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false).delay(0.8)) {
            sparkleRotation = .pi * 2
        }
        
        // Title fade in
        withAnimation(.easeOut(duration: 0.8).delay(0.8)) {
            titleOpacity = 1.0
        }
        
        // Message fade in
        withAnimation(.easeOut(duration: 0.8).delay(1.3)) {
            messageOpacity = 1.0
        }
        
        // Promise fade in
        withAnimation(.easeOut(duration: 0.8).delay(1.8)) {
            promiseOpacity = 1.0
        }
        
        // Button fade in
        withAnimation(.easeOut(duration: 0.8).delay(2.3)) {
            buttonOpacity = 1.0
        }
        
        // Button shimmer sweep (repeating)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerX = 200
            }
        }
    }
}

// MARK: - Apology Particles View

struct ApologyParticlesView: View {
    
    @State private var animationPhase: CGFloat = 0
    
    private let particleCount = 15
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                for i in 0..<particleCount {
                    let seed = Double(i) * 137.508 // Golden angle
                    let x = (seed.truncatingRemainder(dividingBy: 1.0) + CoreGraphics.sin(time * 0.3 + seed) * 0.05)
                    let normalizedX = (Double(i) / Double(particleCount)) + CoreGraphics.sin(time * 0.2 + seed) * 0.08
                    let baseY = (time * 0.015 + seed * 0.1).truncatingRemainder(dividingBy: 1.2)
                    let y = baseY - 0.1
                    
                    let posX: CGFloat = CGFloat(normalizedX) * size.width
                    let posY: CGFloat = CGFloat(y) * size.height
                    
                    let alpha: CGFloat = CGFloat(0.15 + CoreGraphics.sin(time + seed) * 0.1)
                    let radius: CGFloat = CGFloat(1.5 + CoreGraphics.sin(time * 0.5 + seed) * 0.8)
                    
                    let rect = CGRect(
                        x: posX - radius,
                        y: posY - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    
                    let color = i % 3 == 0
                        ? Color("AppAccent").opacity(Double(alpha))
                        : Color.white.opacity(Double(alpha) * 0.5)
                    
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(color)
                    )
                }
            }
        }
    }
}

// MARK: - Apology Manager

class ApologyManager: ObservableObject {
    static let shared = ApologyManager()
    
    @Published var shouldShowApology = false
    
    private let apologyShownKey = "ApologyShown_BugFix_v1.5.0"
    private let hasCompletedSetupKey = "hasCompletedSetup"
    
    // 🚨 DEBUG MODE: Set to true to FORCE show the apology for testing
    // ⚠️ MUST be set to false before production release!
    private let debugForceShow = true
    
    private init() {}
    
    /// Whether the apology has already been shown
    var hasBeenShownOnce: Bool {
        UserDefaults.standard.bool(forKey: apologyShownKey)
    }
    
    /// Check if user has completed initial setup (existing user)
    var hasCompletedSetup: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedSetupKey)
    }
    
    /// Cutoff date: February 9th, 2026 at 00:00:00
    private var pipelineCutoffDate: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 9
        components.hour = 0
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }
    
    /// Whether the user installed before the pipeline cutoff
    var isPreCutoffUser: Bool {
        let installDate = UserDefaults.standard.object(forKey: "analytics_install_date") as? Date ?? Date()
        return installDate < pipelineCutoffDate
    }
    
    /// Whether the user is a premium subscriber
    var isPremium: Bool {
        PaywallManager.shared.isPremium
    }
    
    /// Determines if the apology screen should be shown
    /// - Only shows to users who installed BEFORE February 9th, 2026
    /// - Only shows to PREMIUM users (they paid and the bug affected them)
    /// - Only shows to users who have completed setup
    /// - Only shows ONCE EVER
    func checkShouldShow() -> Bool {
        #if DEBUG
        if debugForceShow {
            print("🚨 ApologyManager: DEBUG MODE - Forcing apology to show for testing")
            return true
        }
        #endif
        
        // Already shown once → never show again
        if hasBeenShownOnce {
            #if DEBUG
            print("💝 ApologyManager: Already shown once - never showing again")
            #endif
            return false
        }
        
        // Must have completed setup (existing user)
        guard hasCompletedSetup else {
            #if DEBUG
            print("💝 ApologyManager: User hasn't completed setup - skipping apology")
            #endif
            return false
        }
        
        // Must be pre-cutoff user (experienced the old pipeline bug)
        guard isPreCutoffUser else {
            #if DEBUG
            print("💝 ApologyManager: Post-cutoff user - no apology needed")
            #endif
            return false
        }
        
        // Must be premium (they paid and were affected)
        guard isPremium else {
            #if DEBUG
            print("💝 ApologyManager: Not premium - skipping apology")
            #endif
            return false
        }
        
        #if DEBUG
        print("💝 ApologyManager: Showing apology to pre-cutoff premium user")
        #endif
        return true
    }
    
    /// Mark the apology as shown - permanently prevents it from showing again
    func markAsShown() {
        UserDefaults.standard.set(true, forKey: apologyShownKey)
        shouldShowApology = false
        
        #if DEBUG
        print("💝 ApologyManager: Marked as shown PERMANENTLY")
        #endif
    }
    
    /// Reset for testing
    func resetForTesting() {
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: apologyShownKey)
        print("💝 ApologyManager: Reset for testing")
        #endif
    }
}

// MARK: - Preview

#Preview {
    ApologyView(isPresented: .constant(true))
}
