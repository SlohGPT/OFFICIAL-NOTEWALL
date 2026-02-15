import SwiftUI
import UIKit

// MARK: - Enhanced Onboarding State Management

/// Manages quiz answers and personalization data throughout onboarding
class OnboardingQuizState: ObservableObject {
    static let shared = OnboardingQuizState()
    
    // User's name for personalization (stored locally only)
    @AppStorage("onboarding_userName") var userName: String = ""
    
    /// Returns the user's first name for display, or nil if not set
    var displayName: String? {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    // Quiz answers stored in UserDefaults for persistence
    @AppStorage("quiz_forgetMost") var forgetMost: String = "" // Comma-separated for multi-select
    @AppStorage("quiz_phoneChecks") var phoneChecks: String = ""
    @AppStorage("quiz_biggestDistraction") var biggestDistraction: String = "" // Comma-separated for multi-select
    @AppStorage("quiz_firstNote") var firstNote: String = ""
    
    // Helper for multi-select answers
    var forgetMostList: [String] {
        get { forgetMost.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
        set { forgetMost = newValue.joined(separator: ", ") }
    }
    
    var biggestDistractionList: [String] {
        get { biggestDistraction.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
        set { biggestDistraction = newValue.joined(separator: ", ") }
    }
    
    // Tracking
    @AppStorage("onboarding_startTime") private var startTimeDouble: Double = 0
    @AppStorage("onboarding_paywallShown") var paywallShown: Bool = false
    @AppStorage("onboarding_setupCompleted") var setupCompleted: Bool = false
    
    var startTime: Date {
        get { Date(timeIntervalSince1970: startTimeDouble) }
        set { startTimeDouble = newValue.timeIntervalSince1970 }
    }
    
    var totalSetupTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    // Personalization based on answers
    var personalizedPhoneChecks: String {
        switch phoneChecks {
        case "50-100":
            return "50-100"
        case "100-200":
            return "150+"
        case "200+":
            return "200+"
        default:
            return "100+"
        }
    }
    
    var personalizedDistraction: String {
        biggestDistraction.isEmpty ? "social media" : biggestDistraction.lowercased()
    }
    
    func reset() {
        forgetMost = ""
        phoneChecks = ""
        biggestDistraction = ""
        firstNote = ""
        startTimeDouble = Date().timeIntervalSince1970
        paywallShown = false
        setupCompleted = false
    }
}

// MARK: - Analytics Tracking

struct OnboardingAnalytics {
    static func trackStepShown(_ step: String) {
        #if DEBUG
        print("📊 Legacy Analytics: Step shown - \(step)")
        #endif
        // Using Mixpanel Analytics via AnalyticsService
        AnalyticsService.shared.trackScreenView(screenName: "onboarding_legacy_\(step)")
    }
    
    static func trackStepCompleted(_ step: String, timeSpent: TimeInterval) {
        #if DEBUG
        print("📊 Legacy Analytics: Step completed - \(step) (took \(String(format: "%.1f", timeSpent))s)")
        #endif
        // Duration is tracked automatically by AnalyticsService
    }
    
    static func trackQuizAnswer(question: String, answer: String) {
        #if DEBUG
        print("📊 Legacy Analytics: Quiz answer - \(question): \(answer)")
        #endif
        // Forward to Mixpanel Analytics
        AnalyticsService.shared.trackQuizAnswer(
            question: question,
            answer: answer,
            stepId: "quiz",
            stepIndex: 0
        )
    }
    
    static func trackPaywallShown(totalSetupTime: TimeInterval) {
        #if DEBUG
        print("📊 Legacy Analytics: Paywall shown after \(String(format: "%.1f", totalSetupTime))s setup")
        #endif
        AnalyticsService.shared.trackPaywallImpression(
            paywallId: PaywallId.postOnboarding.rawValue,
            trigger: "onboarding_complete",
            placement: "post_onboarding"
        )
    }
    
    static func trackPaywallConversion(success: Bool, product: String?) {
        #if DEBUG
        print("📊 Legacy Analytics: Paywall conversion - \(success ? "SUCCESS" : "DECLINED") - \(product ?? "none")")
        #endif
        // Purchase tracking is handled in PaywallManager
    }
    
    static func trackDropOff(step: String, reason: String?) {
        #if DEBUG
        print("📊 Legacy Analytics: Drop-off at \(step) - \(reason ?? "unknown")")
        #endif
        // Abandonment is tracked automatically by OnboardingAnalyticsTracker
    }
}

// MARK: - Progress Indicator Component

struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    let phaseName: String
    let timeRemaining: String?
    
    var progress: CGFloat {
        CGFloat(currentStep) / CGFloat(totalSteps)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Phase name and step counter
            HStack {
                Text(phaseName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appAccent)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text("Step \(currentStep) of \(totalSteps)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
            
            // Time remaining (optional)
            if let time = timeRemaining {
                HStack {
                    Spacer()
                    Text(time)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
}

// MARK: - Notification Permission View (Pre-Onboarding)

/// Notification permission screen shown after the Trajectory view.
/// Shows mock notification cards to make users want notifications, not just allow them.
struct NotificationPermissionView: View {
    let onContinue: () -> Void
    
    // MARK: - Animation States
    @State private var backgroundGlowScale: CGFloat = 0.6
    @State private var backgroundGlowOpacity: Double = 0
    @State private var mockNotif1Offset: CGFloat = 60
    @State private var mockNotif1Opacity: Double = 0
    @State private var mockNotif2Offset: CGFloat = 60
    @State private var mockNotif2Opacity: Double = 0
    @State private var mockNotif3Offset: CGFloat = 60
    @State private var mockNotif3Opacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var subtitleOpacity: Double = 0
    @State private var subtitleOffset: CGFloat = 15
    @State private var buttonOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 20
    @State private var skipOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -200
    @State private var floatingY: CGFloat = 0
    @State private var particle1Opacity: Double = 0
    @State private var particle2Opacity: Double = 0
    @State private var particle3Opacity: Double = 0
    @State private var particle4Opacity: Double = 0
    @State private var particle1Y: CGFloat = 0
    @State private var particle2Y: CGFloat = 0
    @State private var particle3Y: CGFloat = 0
    @State private var particle4Y: CGFloat = 0
    @State private var hasRequestedPermission: Bool = false
    @State private var buttonPressed: Bool = false
    
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        ZStack {
            // MARK: - Background
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.03, blue: 0.07), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Ambient glow behind notifications
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.15), Color.appAccent.opacity(0.03), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: isCompact ? 200 : 260
                    )
                )
                .scaleEffect(backgroundGlowScale)
                .opacity(backgroundGlowOpacity)
                .offset(y: isCompact ? -80 : -100)
                .blur(radius: 30)
            
            // MARK: - Floating Particles
            notificationParticles
            
            // MARK: - Content
            VStack(spacing: 0) {
                Spacer()
                
                // Notification mock cards
                VStack(spacing: isCompact ? 10 : 14) {
                    notificationMockCard(
                        icon: "brain.head.profile.fill",
                        iconGradient: [Color.appAccent, Color.appAccent.opacity(0.6)],
                        title: "Time for a quick check-in",
                        subtitle: "Your notes are waiting on your lock screen",
                        time: "Now"
                    )
                    .offset(y: mockNotif1Offset + floatingY * 0.3)
                    .opacity(mockNotif1Opacity)
                    
                    notificationMockCard(
                        icon: "sparkles",
                        iconGradient: [Color.yellow, Color.orange],
                        title: "New: Smart Wallpaper Themes",
                        subtitle: "Try the new gradient styles",
                        time: "2m ago"
                    )
                    .offset(y: mockNotif2Offset + floatingY * 0.5)
                    .opacity(mockNotif2Opacity)
                    .scaleEffect(0.96)
                    
                    notificationMockCard(
                        icon: "flame.fill",
                        iconGradient: [Color.orange, Color.red.opacity(0.7)],
                        title: "3-day streak!",
                        subtitle: "You're building a great habit",
                        time: "Earlier"
                    )
                    .offset(y: mockNotif3Offset + floatingY * 0.7)
                    .opacity(mockNotif3Opacity)
                    .scaleEffect(0.92)
                }
                .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                
                Spacer()
                    .frame(height: isCompact ? 32 : 44)
                
                // MARK: - Title & Subtitle
                VStack(spacing: isCompact ? 10 : 14) {
                    Text("Don't miss a thing")
                        .font(.system(size: isCompact ? 30 : 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(titleOpacity)
                        .offset(y: titleOffset)
                    
                    Text("Get helpful nudges that keep\nyour momentum going.")
                        .font(.system(size: isCompact ? 15 : 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .opacity(subtitleOpacity)
                        .offset(y: subtitleOffset)
                }
                .padding(.horizontal, AdaptiveLayout.horizontalPadding + 8)
                
                Spacer()
                
                // MARK: - Buttons
                VStack(spacing: isCompact ? 12 : 16) {
                    // Primary button with shimmer
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            buttonPressed = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            requestNotificationPermission()
                        }
                    }) {
                        ZStack {
                            // Button background
                            RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            // Shimmer overlay
                            RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.15), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .offset(x: shimmerOffset)
                                .mask(
                                    RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                                )
                            
                            // Glass border
                            RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                            
                            // Label
                            HStack(spacing: 10) {
                                Text("Keep Me in the Loop")
                                    .font(.system(size: isCompact ? 16 : 18, weight: .bold))
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: isCompact ? 14 : 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                        }
                        .frame(height: isCompact ? 54 : 60)
                        .shadow(color: Color.appAccent.opacity(0.35), radius: 20, x: 0, y: 12)
                    }
                    .scaleEffect(buttonPressed ? 0.96 : 1.0)
                    .opacity(buttonOpacity)
                    .offset(y: buttonOffset)
                    
                    // Skip
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        onContinue()
                    }) {
                        Text("Not now")
                            .font(.system(size: isCompact ? 13 : 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .opacity(skipOpacity)
                }
                .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                .padding(.bottom, isCompact ? 20 : 32)
            }
        }
        .onAppear {
            startNotificationAnimations()
        }
    }
    
    // MARK: - Mock Notification Card
    
    private func notificationMockCard(
        icon: String,
        iconGradient: [Color],
        title: String,
        subtitle: String,
        time: String
    ) -> some View {
        HStack(spacing: isCompact ? 12 : 14) {
            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: isCompact ? 10 : 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: iconGradient.map { $0.opacity(0.15) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isCompact ? 40 : 46, height: isCompact ? 40 : 46)
                
                Image(systemName: icon)
                    .font(.system(size: isCompact ? 17 : 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("NoteWall")
                        .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                    
                    Spacer()
                    
                    Text(time)
                        .font(.system(size: isCompact ? 10 : 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.25))
                }
                
                Text(title)
                    .font(.system(size: isCompact ? 13 : 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.system(size: isCompact ? 12 : 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
            }
        }
        .padding(isCompact ? 14 : 16)
        .background(
            ZStack {
                // Glass background
                RoundedRectangle(cornerRadius: isCompact ? 18 : 22, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                
                // Subtle border
                RoundedRectangle(cornerRadius: isCompact ? 18 : 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.1), .white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
        )
    }
    
    // MARK: - Floating Particles
    
    private var notificationParticles: some View {
        ZStack {
            Circle()
                .fill(Color.appAccent.opacity(0.4))
                .frame(width: 4, height: 4)
                .blur(radius: 1)
                .offset(x: -80, y: particle1Y)
                .opacity(particle1Opacity)
            
            Circle()
                .fill(Color.appAccent.opacity(0.3))
                .frame(width: 3, height: 3)
                .blur(radius: 0.5)
                .offset(x: 100, y: particle2Y)
                .opacity(particle2Opacity)
            
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 2.5, height: 2.5)
                .blur(radius: 0.5)
                .offset(x: -40, y: particle3Y)
                .opacity(particle3Opacity)
            
            Circle()
                .fill(Color.appAccent.opacity(0.25))
                .frame(width: 3.5, height: 3.5)
                .blur(radius: 1)
                .offset(x: 60, y: particle4Y)
                .opacity(particle4Opacity)
        }
    }
    
    // MARK: - Permission Request
    
    private func requestNotificationPermission() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        NotificationManager.shared.requestPermission { granted in
            #if DEBUG
            print("🔔 Notification permission from onboarding: \(granted)")
            #endif
            hasRequestedPermission = true
            onContinue()
        }
    }
    
    // MARK: - Animations
    
    private func startNotificationAnimations() {
        // 1. Background glow breathes in
        withAnimation(.easeOut(duration: 1.2)) {
            backgroundGlowScale = 1.0
            backgroundGlowOpacity = 1
        }
        
        // 2. Notification cards slide up with spring, staggered
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.15)) {
            mockNotif1Offset = 0
            mockNotif1Opacity = 1
        }
        
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.3)) {
            mockNotif2Offset = 0
            mockNotif2Opacity = 1
        }
        
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.45)) {
            mockNotif3Offset = 0
            mockNotif3Opacity = 1
        }
        
        // Haptic when cards land
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        
        // 3. Title & subtitle slide up
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6)) {
            titleOpacity = 1
            titleOffset = 0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.75)) {
            subtitleOpacity = 1
            subtitleOffset = 0
        }
        
        // 4. Button appears
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.95)) {
            buttonOpacity = 1
            buttonOffset = 0
        }
        
        // 5. Skip fades in
        withAnimation(.easeOut(duration: 0.4).delay(1.3)) {
            skipOpacity = 1
        }
        
        // 6. Continuous floating effect for notification cards
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                floatingY = -6
            }
        }
        
        // 7. Button shimmer loop
        startNotificationShimmerLoop()
        
        // 8. Floating particles
        startNotificationParticleAnimations()
    }
    
    private func startNotificationShimmerLoop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.8)) {
                shimmerOffset = 400
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            shimmerOffset = -200
            withAnimation(.easeInOut(duration: 0.8)) {
                shimmerOffset = 400
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.5) {
            shimmerOffset = -200
            withAnimation(.easeInOut(duration: 0.8)) {
                shimmerOffset = 400
            }
        }
    }
    
    private func startNotificationParticleAnimations() {
        particle1Y = 50
        particle2Y = 80
        particle3Y = 30
        particle4Y = 70
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 4.0).repeatForever(autoreverses: false)) {
                particle1Y = -300
            }
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: true)) {
                particle1Opacity = 0.8
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 5.0).repeatForever(autoreverses: false)) {
                particle2Y = -350
            }
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: true)) {
                particle2Opacity = 0.6
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 4.5).repeatForever(autoreverses: false)) {
                particle3Y = -280
            }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: true)) {
                particle3Opacity = 0.7
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 3.5).repeatForever(autoreverses: false)) {
                particle4Y = -320
            }
            withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: true)) {
                particle4Opacity = 0.5
            }
        }
    }
}

// MARK: - Notification Benefit Row Component

struct NotificationBenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        HStack(spacing: isCompact ? 14 : 18) {
            // Icon container
            ZStack {
                RoundedRectangle(cornerRadius: isCompact ? 10 : 12, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: isCompact ? 42 : 48, height: isCompact ? 42 : 48)
                
                Image(systemName: icon)
                    .font(.system(size: isCompact ? 18 : 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: isCompact ? 12 : 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)
            }
            
            Spacer(minLength: 0)
        }
        .padding(isCompact ? 14 : 16)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 14 : 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: isCompact ? 14 : 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Name Input View (Personalization)

struct NameInputView: View {
    let onContinue: () -> Void
    
    @ObservedObject private var quizState = OnboardingQuizState.shared
    @State private var nameText: String = ""
    @FocusState private var isNameFieldFocused: Bool
    
    // Animation states — entrance
    @State private var emojiScale: CGFloat = 0.1
    @State private var emojiOpacity: Double = 0
    @State private var emojiRotation: Double = -30
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 18
    @State private var subtitleOpacity: Double = 0
    @State private var fieldOpacity: Double = 0
    @State private var fieldOffset: CGFloat = 24
    @State private var buttonOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 16
    
    // Animation states — greeting
    @State private var showGreeting: Bool = false
    @State private var greetingOpacity: Double = 0
    @State private var greetingScale: CGFloat = 0.85
    @State private var nameGradientPhase: CGFloat = 0
    @State private var confettiTriggered: Bool = false
    
    // Background animations
    @State private var glowScale: CGFloat = 0.8
    @State private var glowOpacity: Double = 0
    @State private var particle1Y: CGFloat = 0
    @State private var particle2Y: CGFloat = 0
    @State private var particle3Y: CGFloat = 0
    @State private var particle1Opacity: Double = 0
    @State private var particle2Opacity: Double = 0
    @State private var particle3Opacity: Double = 0
    
    // Field glow
    @State private var fieldGlowOpacity: Double = 0
    @State private var shimmerPhase: CGFloat = -1.5
    
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    private var isNameValid: Bool {
        !nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ZStack {
            // MARK: - Background
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.03, blue: 0.08),
                    Color(red: 0.01, green: 0.01, blue: 0.04),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Ambient glow behind content
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.appAccent.opacity(0.12),
                            Color.appAccent.opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: isCompact ? 200 : 280
                    )
                )
                .scaleEffect(glowScale)
                .opacity(glowOpacity)
                .offset(y: isCompact ? -100 : -120)
                .blur(radius: 40)
            
            // Floating particles
            floatingParticles
            
            // MARK: - Content
            VStack(spacing: 0) {
                Spacer()
                
                if showGreeting {
                    greetingContent
                } else {
                    inputContent
                }
                
                Spacer()
                
                // Continue button (only in input mode)
                if !showGreeting {
                    continueButton
                }
            }
        }
        .onAppear {
            animateEntrance()
        }
        .onTapGesture {
            isNameFieldFocused = false
        }
    }
    
    // MARK: - Floating Particles
    
    private var floatingParticles: some View {
        GeometryReader { geo in
            // Large slow particle
            Circle()
                .fill(Color.appAccent.opacity(0.08))
                .frame(width: 6, height: 6)
                .blur(radius: 2)
                .position(x: geo.size.width * 0.2, y: geo.size.height * 0.3)
                .offset(y: particle1Y)
                .opacity(particle1Opacity)
            
            // Medium particle
            Circle()
                .fill(Color.appAccent.opacity(0.12))
                .frame(width: 4, height: 4)
                .blur(radius: 1)
                .position(x: geo.size.width * 0.75, y: geo.size.height * 0.25)
                .offset(y: particle2Y)
                .opacity(particle2Opacity)
            
            // Small accent particle
            Circle()
                .fill(Color.appAccent.opacity(0.1))
                .frame(width: 5, height: 5)
                .blur(radius: 1.5)
                .position(x: geo.size.width * 0.6, y: geo.size.height * 0.65)
                .offset(y: particle3Y)
                .opacity(particle3Opacity)
        }
    }
    
    // MARK: - Greeting Content (post-submit)
    
    private var greetingContent: some View {
        VStack(spacing: isCompact ? 20 : 28) {
            // Big wave emoji with bounce
            Text("👋")
                .font(.system(size: isCompact ? 64 : 80))
                .scaleEffect(emojiScale)
                .rotationEffect(.degrees(emojiRotation))
                .opacity(emojiOpacity)
            
            VStack(spacing: isCompact ? 10 : 14) {
                Text("Nice to meet you,")
                    .font(.system(size: isCompact ? 20 : 24, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                // Name with animated gradient
                Text("\(nameText.trimmingCharacters(in: .whitespacesAndNewlines))!")
                    .font(.system(size: isCompact ? 34 : 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .appAccent,
                                .appAccent.opacity(0.7),
                                Color(red: 0.4, green: 0.7, blue: 1.0),
                                .appAccent
                            ],
                            startPoint: UnitPoint(x: nameGradientPhase, y: 0),
                            endPoint: UnitPoint(x: nameGradientPhase + 1, y: 1)
                        )
                    )
                    .shadow(color: .appAccent.opacity(0.3), radius: 12, x: 0, y: 4)
                
                Text("Let's make forgetting a thing of the past")
                    .font(.system(size: isCompact ? 15 : 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, isCompact ? 2 : 6)
            }
            .multilineTextAlignment(.center)
        }
        .scaleEffect(greetingScale)
        .opacity(greetingOpacity)
        .padding(.horizontal, 32)
    }
    
    // MARK: - Input Content
    
    private var inputContent: some View {
        VStack(spacing: isCompact ? 20 : 28) {
            // Animated hand wave
            Text("👋")
                .font(.system(size: isCompact ? 48 : 60))
                .scaleEffect(emojiScale)
                .rotationEffect(.degrees(emojiRotation))
                .opacity(emojiOpacity)
                .padding(.bottom, isCompact ? 4 : 8)
            
            // Title with subtitle
            VStack(spacing: isCompact ? 6 : 10) {
                Text("First things first")
                    .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .opacity(subtitleOpacity)
                
                Text("What should we\ncall you?")
                    .font(.system(size: isCompact ? 28 : 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            
            // Name input field with glow
            nameInputField
                .opacity(fieldOpacity)
                .offset(y: fieldOffset)
        }
    }
    
    // MARK: - Name Input Field
    
    private var nameInputField: some View {
        VStack(spacing: 0) {
            ZStack {
                // Glow behind field when focused
                RoundedRectangle(cornerRadius: isCompact ? 16 : 18, style: .continuous)
                    .fill(Color.appAccent.opacity(0.06))
                    .blur(radius: 20)
                    .scaleEffect(1.1)
                    .opacity(1.0)
                
                HStack(spacing: 14) {
                    // Icon with animated color
                    ZStack {
                        Circle()
                            .fill(isNameValid ? Color.appAccent.opacity(0.15) : Color.white.opacity(0.04))
                            .frame(width: isCompact ? 36 : 40, height: isCompact ? 36 : 40)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: isCompact ? 15 : 17, weight: .medium))
                            .foregroundColor(isNameValid ? .appAccent : .white.opacity(0.25))
                    }
                    .animation(.easeInOut(duration: 0.3), value: isNameValid)
                    
                    TextField("", text: $nameText)
                        .placeholder(when: nameText.isEmpty) {
                            Text("Enter your name")
                                .foregroundColor(.white.opacity(0.25))
                                .font(.system(size: isCompact ? 18 : 20, weight: .medium))
                        }
                        .font(.system(size: isCompact ? 18 : 20, weight: .medium))
                        .foregroundColor(.white)
                        .focused($isNameFieldFocused)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit {
                            if isNameValid { submitName() }
                        }
                    
                    // Checkmark with spring
                    if isNameValid {
                        ZStack {
                            Circle()
                                .fill(Color.appAccent.opacity(0.15))
                                .frame(width: isCompact ? 30 : 34, height: isCompact ? 30 : 34)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: isCompact ? 12 : 14, weight: .bold))
                                .foregroundColor(.appAccent)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, isCompact ? 16 : 20)
                .padding(.vertical, isCompact ? 14 : 18)
                .background(
                    RoundedRectangle(cornerRadius: isCompact ? 16 : 18, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: isCompact ? 16 : 18, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.appAccent.opacity(0.6), Color.appAccent.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: isNameFieldFocused ? 1.5 : 1
                                )
                        )
                )
                .animation(.easeInOut(duration: 0.25), value: isNameFieldFocused)
                .animation(.easeInOut(duration: 0.25), value: isNameValid)
            }
        }
        .padding(.horizontal, isCompact ? 28 : 40)
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        Button(action: {
            if isNameValid { submitName() }
        }) {
            HStack(spacing: 10) {
                Text("Continue")
                    .font(.system(size: isCompact ? 16 : 18, weight: .semibold))
                
                Image(systemName: "arrow.right")
                    .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
            }
            .foregroundColor(isNameValid ? .white : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? 52 : 58)
            .background(
                ZStack {
                    // Base gradient
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            isNameValid
                                ? LinearGradient(
                                    colors: [Color.appAccent, Color.appAccent.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  )
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.06), Color.white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  )
                        )
                    
                    // Shimmer overlay
                    if isNameValid {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.2), .clear],
                                    startPoint: UnitPoint(x: shimmerPhase, y: 0.5),
                                    endPoint: UnitPoint(x: shimmerPhase + 0.5, y: 0.5)
                                )
                            )
                    }
                }
            )
            .shadow(color: isNameValid ? Color.appAccent.opacity(0.25) : .clear, radius: 16, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isNameValid
                            ? Color.white.opacity(0.15)
                            : Color.white.opacity(0.06),
                        lineWidth: 0.5
                    )
            )
        }
        .disabled(!isNameValid)
        .opacity(buttonOpacity)
        .offset(y: buttonOffset)
        .padding(.horizontal, isCompact ? 24 : 32)
        .padding(.bottom, isCompact ? 20 : 28)
        .animation(.easeInOut(duration: 0.35), value: isNameValid)
    }
    
    // MARK: - Actions
    
    private func submitName() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Save name
        quizState.userName = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Dismiss keyboard
        isNameFieldFocused = false
        
        // Transition to greeting
        withAnimation(.easeOut(duration: 0.35)) {
            showGreeting = true
        }
        
        // Reset emoji for greeting re-animation
        emojiScale = 0.1
        emojiOpacity = 0
        emojiRotation = -30
        
        // Animate greeting elements
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // Wave emoji bounces in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                emojiScale = 1.0
                emojiOpacity = 1.0
                emojiRotation = 0
            }
            
            // Wave wiggle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.15).repeatCount(3, autoreverses: true)) {
                    emojiRotation = 15
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        emojiRotation = 0
                    }
                }
            }
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.25)) {
            greetingScale = 1.0
            greetingOpacity = 1.0
        }
        
        // Boost glow for greeting
        withAnimation(.easeInOut(duration: 0.6).delay(0.2)) {
            glowOpacity = 0.8
            glowScale = 1.3
        }
        
        // Animate name gradient shimmer
        startNameGradientAnimation()
        
        // Auto-advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            onContinue()
        }
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        // Background glow breathe-in
        withAnimation(.easeOut(duration: 0.6)) {
            glowOpacity = 0.5
            glowScale = 1.0
        }
        
        // Start gentle glow pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowScale = 1.1
                glowOpacity = 0.6
            }
        }
        
        // Floating particles drift
        startParticleAnimations()
        
        // Wave emoji — bouncy spring (appears immediately)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.05)) {
            emojiScale = 1.0
            emojiOpacity = 1.0
            emojiRotation = 0
        }
        
        // Quick wave wiggle after landing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.15).repeatCount(3, autoreverses: true)) {
                emojiRotation = 12
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    emojiRotation = 0
                }
            }
        }
        
        // Subtitle ("First things first")
        withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
            subtitleOpacity = 1.0
        }
        
        // Title
        withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
            titleOpacity = 1.0
            titleOffset = 0
        }
        
        // Input field slides up
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.25)) {
            fieldOpacity = 1.0
            fieldOffset = 0
        }
        
        // Auto-focus keyboard immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isNameFieldFocused = true
            withAnimation(.easeOut(duration: 0.3)) {
                fieldGlowOpacity = 1.0
            }
        }
        
        // Button
        withAnimation(.easeOut(duration: 0.4).delay(0.35)) {
            buttonOpacity = 1.0
            buttonOffset = 0
        }
        
        // Start shimmer loop
        startShimmerLoop()
    }
    
    private func startParticleAnimations() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true).delay(0.5)) {
            particle1Y = -20
            particle1Opacity = 0.8
        }
        withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true).delay(1.0)) {
            particle2Y = -15
            particle2Opacity = 0.6
        }
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true).delay(0.8)) {
            particle3Y = -18
            particle3Opacity = 0.7
        }
    }
    
    private func startShimmerLoop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            guard !showGreeting else { return }
            withAnimation(.easeInOut(duration: 1.2)) {
                shimmerPhase = 2.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                shimmerPhase = -1.5
                startShimmerLoop()
            }
        }
    }
    
    private func startNameGradientAnimation() {
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            nameGradientPhase = 2.0
        }
    }
}

// Helper for placeholder text in TextField
private extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Pain Point View (Emotional Hook)

struct PainPointView: View {
    let onContinue: () -> Void
    
    // Internal state for the two-step flow
    // 0: Stats (Did you know...)
    // 1: Question (How many times...)
    @State private var internalStep: Int = 0
    @ObservedObject private var quizState = OnboardingQuizState.shared
    
    // Animation states for step 0
    @State private var headerOpacity: Double = 0
    @State private var text1Opacity: Double = 0
    @State private var text2Opacity: Double = 0
    @State private var numberScale: CGFloat = 0.3
    @State private var numberOpacity: Double = 0
    @State private var numberValue: Double = 0 // Changed to Double for smooth animation
    @State private var card1Opacity: Double = 0
    @State private var card2Opacity: Double = 0
    @State private var card3Opacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    // Animation states for step 1 - redesigned
    @State private var introText: String = ""
    private let fullIntroText = "But here's the real question..."
    @State private var line1Opacity: Double = 0
    @State private var line2Opacity: Double = 0
    @State private var line3Opacity: Double = 0
    
    // Adaptive layout values
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        ZStack {
            // Dark gradient background with subtle depth
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.04, blue: 0.08), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Subtle radial glow behind number (only for step 0)
                if internalStep == 0 {
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.08), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                    .offset(y: isCompact ? -60 : -80)
                    .transition(.opacity)
                }
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: isCompact ? 24 : 36) {
                        Spacer(minLength: isCompact ? 30 : 50)
                        
                        if internalStep == 0 {
                            // MARK: - STEP 0: Stats
                            
                            // Header badge
                            HStack(spacing: 6) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: isCompact ? 12 : 14))
                                    .foregroundColor(.appAccent)
                                
                                Text("Research Insight")
                                    .font(.system(size: isCompact ? 12 : 13, weight: .medium))
                                    .foregroundColor(.appAccent)
                            }
                            .padding(.horizontal, isCompact ? 12 : 16)
                            .padding(.vertical, isCompact ? 6 : 8)
                            .background(
                                Capsule()
                                    .fill(Color.appAccent.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .opacity(headerOpacity)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            
                            // Main stat section
                            VStack(spacing: isCompact ? 16 : 24) {
                                Text(quizState.displayName != nil ? String(format: NSLocalizedString("Hey %@, did you know that", comment: ""), quizState.displayName!) : NSLocalizedString("Did you know that", comment: ""))
                                    .font(.system(size: isCompact ? 16 : 19, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .opacity(text1Opacity)
                                
                                Text("the average person unlocks their phone up to")
                                    .font(.system(size: isCompact ? 16 : 19, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .opacity(text2Opacity)
                                
                                // Big animated number with CountingText modifier
                                VStack(spacing: isCompact ? 4 : 6) {
                                    Text("0") // Placeholder, modification happens below
                                        .modifier(CountingText(value: numberValue))
                                        .font(.system(size: isCompact ? 72 : 96, weight: .black, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.appAccent, .appAccent.opacity(0.7)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: .appAccent.opacity(0.4), radius: 20, x: 0, y: 10)
                                    
                                    Text("times per day ?")
                                        .font(.system(size: isCompact ? 14 : 17, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.6))
                                        .modifier(LetterSpacingModifier(spacing: 0.5))
                                }
                                .scaleEffect(numberScale)
                                .opacity(numberOpacity)
                            }
                            .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                            .transition(.opacity.combined(with: .scale))
                            
                            // Context cards
                            VStack(spacing: isCompact ? 10 : 14) {
                                HStack(spacing: isCompact ? 14 : 18) {
                                    StatMiniCard(
                                        value: "4hrs",
                                        label: "screen time",
                                        icon: "clock.fill",
                                        isCompact: isCompact
                                    )
                                    .opacity(card1Opacity)
                                    
                                    StatMiniCard(
                                        value: "96%",
                                        label: "forgotten",
                                        icon: "brain.head.profile",
                                        isCompact: isCompact
                                    )
                                    .opacity(card2Opacity)
                                    
                                    StatMiniCard(
                                        value: "2.5s",
                                        label: "avg glance",
                                        icon: "eye.fill",
                                        isCompact: isCompact
                                    )
                                    .opacity(card3Opacity)
                                }
                            }
                            .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            
                        } else {
                            // MARK: - STEP 1: The Question (Redesigned)
                            
                            Spacer(minLength: isCompact ? 40 : 60)
                            
                            VStack(spacing: isCompact ? 16 : 20) {
                                // Typewriter intro text
                                Text(introText)
                                    .font(.system(size: isCompact ? 16 : 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                
                                VStack(spacing: isCompact ? 4 : 6) {
                                    // Line 1: "How many times"
                                    Text("How many times")
                                        .font(.system(size: isCompact ? 28 : 36, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .opacity(line1Opacity)
                                    
                                    // Line 2: "did you actually"
                                    Text("did you actually")
                                        .font(.system(size: isCompact ? 28 : 36, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .opacity(line2Opacity)
                                    
                                    // Line 3: "remember why?" with "why?" in accent color
                                    HStack(spacing: isCompact ? 6 : 8) {
                                        Text("remember")
                                            .font(.system(size: isCompact ? 28 : 36, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        
                                        Text("why?")
                                            .font(.system(size: isCompact ? 28 : 36, weight: .bold, design: .rounded))
                                            .foregroundColor(.appAccent)
                                    }
                                    .opacity(line3Opacity)
                                }
                            }
                            .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                            .frame(maxWidth: .infinity)
                            
                            Spacer(minLength: isCompact ? 40 : 60)
                        }
                        
                        // Spacer to push content up
                        Spacer(minLength: isCompact ? 80 : 100)
                    }
                }
                
                // Continue button
                VStack(spacing: 0) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        if internalStep == 0 {
                            // Track "Tell Me More" tap
                            OnboardingAnalyticsTracker.shared.trackAction(.next, on: .painPoint, additionalParams: ["button": "tell_me_more"])
                            
                            // Move to next step
                            withAnimation(.easeInOut(duration: 0.4)) {
                                internalStep = 1
                            }
                            // Reset states for Step 1
                            buttonOpacity = 0
                            introText = ""
                            
                            // Trigger animations for step 1
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                // Typewriter effect for intro
                                var charIndex = 0
                                let typingSpeed = 0.06 // seconds per character
                                
                                Timer.scheduledTimer(withTimeInterval: typingSpeed, repeats: true) { timer in
                                    if charIndex < fullIntroText.count {
                                        let index = fullIntroText.index(fullIntroText.startIndex, offsetBy: charIndex)
                                        introText.append(fullIntroText[index])
                                        charIndex += 1
                                        
                                        // Light feedback for typing
                                        if charIndex % 4 == 0 {
                                            let feedback = UIImpactFeedbackGenerator(style: .light)
                                            feedback.impactOccurred(intensity: 0.2)
                                        }
                                    } else {
                                        timer.invalidate()
                                        
                                        // After typewriter finishes, show lines sequentially
                                        // Line 1: "How many times"
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                            withAnimation(.easeOut(duration: 0.8)) {
                                                line1Opacity = 1
                                            }
                                        }
                                        
                                        // Line 2: "did you actually" (1 second after line 1)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                            withAnimation(.easeOut(duration: 0.8)) {
                                                line2Opacity = 1
                                            }
                                        }
                                        
                                        // Line 3: "remember why?" (1 second after line 2)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                                            withAnimation(.easeOut(duration: 0.8)) {
                                                line3Opacity = 1
                                            }
                                        }
                                        
                                        // CTA button (1 second after line 3)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
                                            withAnimation(.easeOut(duration: 0.6)) {
                                                buttonOpacity = 1
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            // Track "Continue" tap
                            OnboardingAnalyticsTracker.shared.trackAction(.next, on: .painPoint, additionalParams: ["button": "continue"])
                            
                            // Complete
                            onContinue()
                        }
                    }) {
                        HStack(spacing: isCompact ? 8 : 10) {
                            Text(internalStep == 0 ? NSLocalizedString("Tell Me More", comment: "") : NSLocalizedString("Continue", comment: ""))
                                .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                        }
                        .frame(height: isCompact ? 50 : 56)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
                }
                .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                .padding(.vertical, isCompact ? 16 : 20)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                    .offset(y: -40)
                    , alignment: .top
                )
                .opacity(buttonOpacity)
            }
        }
        .onAppear {
            if internalStep == 0 {
                // SLOWED DOWN Animation Sequence for Step 0
                // EDITED: Speeding up significantly to reduce drop-off (was 8.5s delay)
                
                // 1. Header (0.1s delay)
                withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                    headerOpacity = 1
                }
                
                // 2. Text 1 (0.3s delay)
                withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                    text1Opacity = 1
                }
                
                // 3. Text 2 (0.3s delay - appearing with Text 1)
                withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                    text2Opacity = 1
                }
                
                // 4. Number Reveal (0.5s delay, faster spring)
                let startDelay = 0.5
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(startDelay)) {
                    numberOpacity = 1
                    numberScale = 1.0
                }
                
                // Animate number value smoothly (faster count)
                withAnimation(.easeOut(duration: 1.5).delay(startDelay)) {
                    numberValue = 498
                }
                
                // 5. Context cards (Rapid sequence starting at 1.2s)
                withAnimation(.easeOut(duration: 0.5).delay(1.2)) {
                    card1Opacity = 1
                }
                
                withAnimation(.easeOut(duration: 0.5).delay(1.4)) {
                    card2Opacity = 1
                }
                
                withAnimation(.easeOut(duration: 0.5).delay(1.6)) {
                    card3Opacity = 1
                }
                
                // 6. Button (2.0s delay - Visible almost immediately)
                withAnimation(.easeOut(duration: 0.5).delay(2.0)) {
                    buttonOpacity = 1
                }
                
                // Success haptic
                DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + 1.5) {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                }
                
                OnboardingAnalytics.trackStepShown("pain_point_stats")
            }
        }
        .onChange(of: internalStep) { _, newValue in
            if newValue == 1 {
                OnboardingAnalytics.trackStepShown("pain_point_question")
            }
        }
    }
}

// Helper modifier for smooth number counting animation
struct CountingText: AnimatableModifier {
    var value: Double
    
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    
    func body(content: Content) -> some View {
        Text("\(Int(value))")
    }
}

// MARK: - Stat Mini Card

private struct StatMiniCard: View {
    let value: String
    let label: String
    let icon: String
    let isCompact: Bool
    
    var body: some View {
        VStack(spacing: isCompact ? 6 : 8) {
            Image(systemName: icon)
                .font(.system(size: isCompact ? 14 : 16))
                .foregroundColor(.white.opacity(0.4))
            
            Text(value)
                .font(.system(size: isCompact ? 18 : 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: isCompact ? 10 : 11))
                .foregroundColor(.white.opacity(0.4))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isCompact ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 12 : 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}

// MARK: - Quiz Transition View (Connection between Pain Point and Quiz)

struct QuizTransitionView: View {
    let onContinue: () -> Void
    
    @State private var headerOpacity: Double = 0
    @State private var questionOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        ZStack {
            // Dark gradient background with subtle depth
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.04, blue: 0.08), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Subtle radial glow
                RadialGradient(
                    colors: [Color.appAccent.opacity(0.06), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 350
                )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: isCompact ? 28 : 40) {
                        Spacer(minLength: isCompact ? 50 : 80)
                        
                        // Header badge
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: isCompact ? 12 : 14))
                                .foregroundColor(.appAccent)
                            
                            Text("Quick Check")
                                .font(.system(size: isCompact ? 12 : 13, weight: .medium))
                                .foregroundColor(.appAccent)
                        }
                        .padding(.horizontal, isCompact ? 12 : 16)
                        .padding(.vertical, isCompact ? 6 : 8)
                        .background(
                            Capsule()
                                .fill(Color.appAccent.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .opacity(headerOpacity)
                        
                        // Brain icon with animation
                        ZStack {
                            // Outer glow rings
                            ForEach(0..<3, id: \.self) { i in
                                Circle()
                                    .stroke(Color.appAccent.opacity(0.15 - Double(i) * 0.04), lineWidth: 1.5)
                                    .frame(
                                        width: (isCompact ? 80 : 100) + CGFloat(i) * (isCompact ? 24 : 30),
                                        height: (isCompact ? 80 : 100) + CGFloat(i) * (isCompact ? 24 : 30)
                                    )
                            }
                            
                            Circle()
                                .fill(Color.appAccent.opacity(0.12))
                                .frame(width: isCompact ? 80 : 100, height: isCompact ? 80 : 100)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: isCompact ? 36 : 44, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.appAccent, .appAccent.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)
                        
                        // Main question section
                        VStack(spacing: isCompact ? 14 : 20) {
                            Text("But, before we start...")
                                .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                                .opacity(subtitleOpacity)
                            
                            Text("What do you forget\nthe most?")
                                .font(.system(size: isCompact ? 26 : 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .opacity(questionOpacity)
                            
                            Text("A few quick questions will help us\npersonalize your experience")
                                .font(.system(size: isCompact ? 14 : 16))
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .opacity(subtitleOpacity)
                        }
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        // Time estimate
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: isCompact ? 12 : 14))
                                .foregroundColor(.white.opacity(0.4))
                            
                            Text("Takes less than 30 seconds")
                                .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .opacity(subtitleOpacity)
                        
                        Spacer(minLength: isCompact ? 80 : 100)
                    }
                }
                
                // Continue button
                VStack(spacing: 0) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        // Track action
                        OnboardingAnalyticsTracker.shared.trackAction(.next, on: .painPoint, additionalParams: ["subtype": "quiz_transition"])
                        
                        onContinue()
                    }) {
                        HStack(spacing: isCompact ? 8 : 10) {
                            Text("Let's Find Out")
                                .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                        }
                        .frame(height: isCompact ? 50 : 56)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
                }
                .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                .padding(.vertical, isCompact ? 16 : 20)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                    .offset(y: -40)
                    , alignment: .top
                )
                .opacity(buttonOpacity)
            }
        }
        .onAppear {
            // Header badge
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                headerOpacity = 1
            }
            
            // Icon with spring
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.3)) {
                iconOpacity = 1
                iconScale = 1.0
            }
            
            // Subtitle
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                subtitleOpacity = 1
            }
            
            // Main question
            withAnimation(.easeOut(duration: 0.5).delay(0.7)) {
                questionOpacity = 1
            }
            
            // Button
            withAnimation(.easeOut(duration: 0.4).delay(1.0)) {
                buttonOpacity = 1
            }
            
            OnboardingAnalytics.trackStepShown("quiz_transition")
        }
    }
}

// MARK: - Personalization Loading View (After Quiz, Before Results)

struct PersonalizationLoadingView: View {
    let onComplete: () -> Void
    
    @State private var progress: CGFloat = 0
    @State private var displayedPercentage: Int = 0
    @State private var headerOpacity: Double = 0
    @State private var loadingOpacity: Double = 0
    @State private var messageIndex: Int = 0
    @State private var messageOpacity: Double = 1
    @State private var particleOpacity: Double = 0
    @State private var glowPulse: Bool = false
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    private let messages = [
        "Analyzing your habits...",
        "Customizing your experience...",
        "Preparing your focus plan...",
        "Almost ready..."
    ]
    
    private let totalDuration: Double = 3.5 // Total loading time in seconds
    
    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.08), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated particles background
            GeometryReader { geometry in
                ForEach(0..<12, id: \.self) { i in
                    Circle()
                        .fill(Color.appAccent.opacity(0.15))
                        .frame(width: CGFloat.random(in: 4...12), height: CGFloat.random(in: 4...12))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .blur(radius: 2)
                        .opacity(particleOpacity * Double.random(in: 0.3...1.0))
                }
            }
            .opacity(particleOpacity)
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main content
                VStack(spacing: isCompact ? 32 : 48) {
                    // Animated icon with glow
                    ZStack {
                        // Pulsing glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.appAccent.opacity(0.3), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: isCompact ? 80 : 100
                                )
                            )
                            .frame(width: isCompact ? 160 : 200, height: isCompact ? 160 : 200)
                            .scaleEffect(glowPulse ? 1.1 : 0.9)
                            .animation(
                                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                                value: glowPulse
                            )
                        
                        // Rotating ring
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.appAccent.opacity(0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: isCompact ? 90 : 110, height: isCompact ? 90 : 110)
                            .rotationEffect(.degrees(Double(progress) * 360.0 * 2.0))
                        
                        // Center icon
                        ZStack {
                            Circle()
                                .fill(Color.appAccent.opacity(0.15))
                                .frame(width: isCompact ? 72 : 88, height: isCompact ? 72 : 88)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: isCompact ? 32 : 40, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.appAccent, .appAccent.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                    .opacity(loadingOpacity)
                    
                    // Header text
                    VStack(spacing: isCompact ? 8 : 12) {
                        Text("Curating Your Experience")
                            .font(.system(size: isCompact ? 22 : 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Just for you")
                            .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                            .foregroundColor(.appAccent)
                    }
                    .opacity(headerOpacity)
                    
                    // Animated message
                    Text(messages[messageIndex])
                        .font(.system(size: isCompact ? 15 : 17))
                        .foregroundColor(.white.opacity(0.6))
                        .opacity(messageOpacity)
                        .animation(.easeInOut(duration: 0.3), value: messageOpacity)
                    
                    // Progress bar
                    VStack(spacing: isCompact ? 10 : 14) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: isCompact ? 8 : 10)
                                
                                // Progress fill
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.appAccent, Color.appAccent.opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * progress, height: isCompact ? 8 : 10)
                                    .shadow(color: Color.appAccent.opacity(0.5), radius: 8, x: 0, y: 0)
                            }
                        }
                        .frame(height: isCompact ? 8 : 10)
                        
                        // Percentage
                        if #available(iOS 17.0, *) {
                            Text("\(displayedPercentage)%")
                                .font(.system(size: isCompact ? 12 : 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                                .contentTransition(.numericText(value: Double(displayedPercentage)))
                        } else {
                            Text("\(displayedPercentage)%")
                                .font(.system(size: isCompact ? 12 : 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .frame(maxWidth: isCompact ? 240 : 280)
                    .opacity(loadingOpacity)
                }
                .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                
                Spacer()
                Spacer()
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Initial fade in
        withAnimation(.easeOut(duration: 0.4)) {
            headerOpacity = 1
            loadingOpacity = 1
            particleOpacity = 1
        }
        
        // Start glow pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            glowPulse = true
        }
        
        // Progress animation - visual bar
        withAnimation(.easeInOut(duration: totalDuration)) {
            progress = 1.0
        }
        
        // Animate percentage number - increment by 1 each time with variable delays
        var accumulatedDelay: Double = 0
        
        for i in 0...100 {
            // Calculate delay for this step
            var stepDelay: Double
            
            if i < 90 {
                // 0-89%: Quick with random tempo variations
                stepDelay = Double.random(in: 0.015...0.035)
            } else if i < 95 {
                // 90-94%: Normal speed
                stepDelay = 0.04
            } else {
                // 95-100%: Slower
                stepDelay = Double.random(in: 0.08...0.12)
            }
            
            accumulatedDelay += stepDelay
            
            DispatchQueue.main.asyncAfter(deadline: .now() + accumulatedDelay) {
                displayedPercentage = i
            }
        }
        
        // Cycle through messages
        let messageInterval = totalDuration / Double(messages.count)
        for i in 1..<messages.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + messageInterval * Double(i)) {
                // Fade out current message
                withAnimation(.easeOut(duration: 0.15)) {
                    messageOpacity = 0
                }
                
                // Change message and fade in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    messageIndex = i
                    withAnimation(.easeIn(duration: 0.15)) {
                        messageOpacity = 1
                    }
                }
            }
        }
        
        // Complete after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.3) {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            onComplete()
        }
        
        OnboardingAnalytics.trackStepShown("personalization_loading")
    }
}

// MARK: - Quiz Question View

struct QuizQuestionView: View {
    let question: String
    let subtitle: String?
    let options: [QuizOption]
    let onSelect: (String) -> Void
    
    @State private var selectedOption: String?
    @State private var contentOpacity: Double = 0
    @State private var optionsOpacity: Double = 0
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    private var questionFontSize: CGFloat { isCompact ? 22 : 28 }
    private var topSpacing: CGFloat { isCompact ? 30 : 60 }
    private var optionSpacing: CGFloat { isCompact ? 8 : 12 }
    
    struct QuizOption: Identifiable {
        let id = UUID()
        let emoji: String
        let title: String
        let value: String
    }
    
    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: topSpacing)
                
                // Question
                    VStack(spacing: isCompact ? 8 : 12) {
                    Text(question)
                            .font(.system(size: questionFontSize, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.85)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                                .font(.system(size: isCompact ? 14 : 16))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                    .frame(maxWidth: .infinity)
                .opacity(contentOpacity)
                
                    Spacer(minLength: isCompact ? 24 : 40)
                
                // Options
                    VStack(spacing: optionSpacing) {
                    ForEach(options) { option in
                        QuizOptionButton(
                            emoji: option.emoji,
                            title: option.title,
                            isSelected: selectedOption == option.value
                        ) {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedOption = option.value
                            }
                            
                            OnboardingAnalytics.trackQuizAnswer(question: question, answer: option.value)
                            
                            // Delay before advancing to show selection
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                onSelect(option.value)
                            }
                        }
                    }
                }
                .opacity(optionsOpacity)
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                
                    Spacer(minLength: isCompact ? 30 : 50)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                contentOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                optionsOpacity = 1
            }
            
            // Track as generic quiz step - proper tracking happens via OnboardingAnalyticsTracker
            // OnboardingAnalytics.trackStepShown("quiz")
        }
    }
}

struct QuizOptionButton: View {
    let emoji: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: isCompact ? 12 : 16) {
                Text(emoji)
                    .font(.system(size: isCompact ? 24 : 28))
                
                Text(title)
                    .font(.system(size: isCompact ? 15 : 17, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.85)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: isCompact ? 20 : 24))
                        .foregroundColor(.appAccent)
                }
            }
            .padding(.horizontal, isCompact ? 16 : 20)
            .padding(.vertical, isCompact ? 12 : 16)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 14 : 16, style: .continuous)
                    .fill(isSelected ? Color.appAccent.opacity(0.2) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: isCompact ? 14 : 16, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.appAccent : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
    }
}

// MARK: - Multi-Select Quiz Question View

struct MultiSelectQuizQuestionView: View {
    let question: String
    let subtitle: String?
    let options: [QuizQuestionView.QuizOption]
    let onContinue: ([String]) -> Void
    
    @State private var selectedOptions: Set<String> = []
    @State private var contentOpacity: Double = 0
    @State private var optionsOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    private var questionFontSize: CGFloat { isCompact ? 22 : 28 }
    private var topSpacing: CGFloat { isCompact ? 30 : 60 }
    private var optionSpacing: CGFloat { isCompact ? 8 : 12 }
    private var buttonBottomPadding: CGFloat { isCompact ? 24 : 40 }
    
    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                    Spacer(minLength: topSpacing)
                
                // Question
                    VStack(spacing: isCompact ? 8 : 12) {
                    Text(question)
                            .font(.system(size: questionFontSize, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.85)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                                .font(.system(size: isCompact ? 14 : 16))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                    .frame(maxWidth: .infinity)
                .opacity(contentOpacity)
                
                    Spacer(minLength: isCompact ? 24 : 40)
                
                // Options
                    VStack(spacing: optionSpacing) {
                    ForEach(options) { option in
                        QuizOptionButton(
                            emoji: option.emoji,
                            title: option.title,
                            isSelected: selectedOptions.contains(option.value)
                        ) {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedOptions.contains(option.value) {
                                    selectedOptions.remove(option.value)
                                } else {
                                    selectedOptions.insert(option.value)
                                }
                            }
                            
                            OnboardingAnalytics.trackQuizAnswer(question: question, answer: option.value)
                        }
                    }
                }
                .opacity(optionsOpacity)
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                
                    Spacer(minLength: isCompact ? 20 : 30)
                }
                .padding(.bottom, isCompact ? 80 : 100) // Add padding for fixed button
            }
            
            // Continue button (only shown when at least one option selected)
            VStack(spacing: isCompact ? 8 : 12) {
                if !selectedOptions.isEmpty {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        // Track action
                        OnboardingAnalyticsTracker.shared.trackAction(.next, on: .quizForgetMost, additionalParams: ["subtype": "multiselect_continue"])
                        
                        onContinue(Array(selectedOptions))
                    }) {
                        Text("Continue")
                            .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                            .frame(height: isCompact ? 48 : 56)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, isCompact ? 16 : 24)
            .padding(.top, isCompact ? 12 : 18)
            .padding(.bottom, isCompact ? 16 : 22)
            .background(Color.clear)
            .opacity(buttonOpacity)
        }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                contentOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                optionsOpacity = 1
            }
            
            // Track as generic multi-select quiz - proper tracking happens via OnboardingAnalyticsTracker
            // OnboardingAnalytics.trackStepShown("multi_quiz")
        }
        .onChange(of: selectedOptions) { _, _ in
            // Animate button when selections change
            withAnimation(.easeOut(duration: 0.3)) {
                buttonOpacity = selectedOptions.isEmpty ? 0 : 1
            }
        }
    }
}

// MARK: - Results Preview View

struct ResultsPreviewView: View {
    let onContinue: () -> Void
    @ObservedObject private var quizState = OnboardingQuizState.shared
    
    @State private var headerOpacity: Double = 0
    @State private var profileOpacity: Double = 0
    @State private var profileOffset: CGFloat = 40
    @State private var buttonOpacity: Double = 0
    @State private var checkmarkScale: CGFloat = 0.5
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    // Personalized insights based on quiz answers
    private var focusAreas: [String] {
        let areas = quizState.forgetMostList
        return areas.isEmpty ? ["Your priorities"] : Array(areas.prefix(2))
    }
    
    private var distractionText: String {
        let distractions = quizState.biggestDistractionList
        if distractions.isEmpty { return "distractions" }
        return distractions.first ?? "distractions"
    }
    
    private var phoneCheckCount: String {
        switch quizState.phoneChecks {
        case "50-100": return "50-100"
        case "100-200": return "100-200"
        case "200+": return "200+"
        default: return "100+"
        }
    }
    
    // Intensity level based on phone checks
    private var intensityLevel: Int {
        switch quizState.phoneChecks {
        case "50-100": return 2
        case "100-200": return 4
        case "200+": return 5
        default: return 3
        }
    }
    
    var body: some View {
        ZStack {
            // Dark gradient background
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Subtle accent glow at top
                RadialGradient(
                    colors: [Color.appAccent.opacity(0.08), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: isCompact ? 24 : 32) {
                        Spacer(minLength: isCompact ? 30 : 50)
                        
                        // MARK: - Header with completion indicator
                        VStack(spacing: isCompact ? 10 : 14) {
                            // Connecting badge
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: isCompact ? 16 : 18))
                                    .foregroundColor(.appAccent)
                                
                                Text("Analysis Complete")
                                    .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                    .foregroundColor(.appAccent)
                            }
                            .padding(.horizontal, isCompact ? 16 : 20)
                            .padding(.vertical, isCompact ? 8 : 10)
                            .background(
                                Capsule()
                                    .fill(Color.appAccent.opacity(0.12))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .scaleEffect(checkmarkScale)
                            
                            Text(quizState.displayName != nil ? String(format: NSLocalizedString("Your Focus Profile, %@", comment: ""), quizState.displayName!) : NSLocalizedString("Your Focus Profile", comment: ""))
                                .font(.system(size: isCompact ? 28 : 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.top, isCompact ? 8 : 12)
                        }
                        .opacity(headerOpacity)
                        
                        // MARK: - Personalized Profile Card (Enhanced Single Card)
                        VStack(spacing: 0) {
                            // Profile header
                            HStack(spacing: isCompact ? 12 : 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.appAccent.opacity(0.15))
                                        .frame(width: isCompact ? 48 : 56, height: isCompact ? 48 : 56)
                                    
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: isCompact ? 22 : 26))
                                        .foregroundColor(.appAccent)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Based on your answers")
                                        .font(.system(size: isCompact ? 13 : 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    Text("Here's what we learned")
                                        .font(.system(size: isCompact ? 18 : 20, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                            }
                            .padding(isCompact ? 20 : 24)
                            .background(Color.white.opacity(0.03))
                            
                            // Profile insights
                            VStack(spacing: isCompact ? 20 : 24) {
                                // Focus areas
                                ProfileInsightRow(
                                    icon: "target",
                                    label: "YOU WANT TO REMEMBER",
                                    values: focusAreas,
                                    isCompact: isCompact,
                                    isEnhanced: true
                                )
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                // Distraction
                                ProfileInsightRow(
                                    icon: "xmark.circle",
                                    label: "YOUR BIGGEST CHALLENGE",
                                    values: [distractionText],
                                    isCompact: isCompact,
                                    isEnhanced: true
                                )
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                // Phone usage
                                HStack {
                                    Image(systemName: "iphone")
                                        .font(.system(size: isCompact ? 18 : 22))
                                        .foregroundColor(.white.opacity(0.5))
                                        .frame(width: isCompact ? 24 : 28)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("DAILY PHONE CHECKS")
                                            .font(.system(size: isCompact ? 11 : 12, weight: .bold))
                                            .foregroundColor(.white.opacity(0.5))
                                            .tracking(1.0)
                                        
                                        Text("\(phoneCheckCount) times")
                                            .font(.system(size: isCompact ? 18 : 22, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    // Visual indicator
                                    HStack(spacing: 4) {
                                        ForEach(0..<5, id: \.self) { i in
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(i < intensityLevel ? Color.appAccent : Color.white.opacity(0.15))
                                                .frame(width: isCompact ? 6 : 7, height: isCompact ? 20 : 24)
                                        }
                                    }
                                }
                            }
                            .padding(isCompact ? 20 : 24)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: isCompact ? 20 : 24, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: isCompact ? 20 : 24, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                        .opacity(profileOpacity)
                        .offset(y: profileOffset)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        Spacer(minLength: isCompact ? 40 : 60)
                        
                        // Extra bottom spacer
                        Spacer(minLength: isCompact ? 80 : 100)
                    }
                }
                
                // Continue button
                VStack(spacing: 0) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onContinue()
                    }) {
                        HStack(spacing: isCompact ? 8 : 10) {
                            Text("See Insights")
                                .font(.system(size: isCompact ? 16 : 18, weight: .semibold))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                        }
                        .frame(height: isCompact ? 54 : 60)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
                }
                .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                .padding(.vertical, isCompact ? 16 : 20)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .offset(y: -60)
                    , alignment: .top
                )
                .opacity(buttonOpacity)
            }
        }
        .onAppear {
            // Enhanced Staggered Animation Sequence
            
            // 1. Badge scales up with spring
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                checkmarkScale = 1.0
            }
            
            // 2. Header fades in
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                headerOpacity = 1.0
            }
            
            // 3. Main profile card slides up and fades in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.6)) {
                profileOpacity = 1.0
                profileOffset = 0
            }
            
            // 4. Button appears last
            withAnimation(.easeOut(duration: 0.6).delay(1.0)) {
                buttonOpacity = 1.0
            }
            
            // Success haptic
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            
            OnboardingAnalytics.trackStepShown("results_preview")
        }
    }
}

// Updated ProfileInsightRow to support enhanced visuals
private struct ProfileInsightRow: View {
    let icon: String
    let label: String
    let values: [String]
    let isCompact: Bool
    var isEnhanced: Bool = false // Toggle for bigger text version
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: isCompact ? 18 : 22))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: isCompact ? 24 : 28)
            
            VStack(alignment: .leading, spacing: isEnhanced ? 6 : 2) {
                Text(label)
                    .font(.system(size: isCompact ? 11 : 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.0)
                
                HStack(spacing: isCompact ? 8 : 10) {
                    ForEach(values, id: \.self) { value in
                        Text(value)
                            .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                            .foregroundColor(.appAccent)
                            .padding(.horizontal, isCompact ? 10 : 12)
                            .padding(.vertical, isCompact ? 6 : 8)
                            .background(
                                Capsule()
                                    .fill(Color.appAccent.opacity(0.15))
                            )
                    }
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Results Insight View (Lightbulb Moment)

struct ResultsInsightView: View {
    let onContinue: () -> Void
    @ObservedObject private var quizState = OnboardingQuizState.shared
    
    @State private var lightbulbLit = false
    @State private var lightbulbScale: CGFloat = 0.5
    @State private var titleOpacity: Double = 0
    @State private var row1Opacity: Double = 0
    @State private var row2Opacity: Double = 0
    @State private var row3Opacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    // Typewriter effect
    @State private var titleText = ""
    private let fullTitle = "What this means"
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    // Personalized insights
    private var reminderFrequency: String {
        switch quizState.phoneChecks {
        case "50-100": return "Every 15 min"
        case "100-200": return "Every 8 min"
        case "200+": return "Every 5 min"
        default: return "Every 10 min"
        }
    }
    
    private var phoneCheckCount: String {
        switch quizState.phoneChecks {
        case "50-100": return "50-100"
        case "100-200": return "100-200"
        case "200+": return "200+"
        default: return "100+"
        }
    }
    
    private var distractionText: String {
        let distractions = quizState.biggestDistractionList
        if distractions.isEmpty { return "distractions" }
        return distractions.first ?? "distractions"
    }

    var body: some View {
        ZStack {
            // Dark gradient background (matching ResultsPreview)
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top spacing (reduced to move content higher)
                Spacer()
                    .frame(height: isCompact ? 10 : 20)
                
                // Lightbulb Animation
                ZStack {
                     // Glow
                     Circle()
                        .fill(Color.yellow.opacity(lightbulbLit ? 0.3 : 0))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)
                     
                     Image(systemName: lightbulbLit ? "lightbulb.fill" : "lightbulb")
                        .font(.system(size: isCompact ? 60 : 72))
                        .foregroundColor(lightbulbLit ? .yellow : .gray.opacity(0.5))
                        .shadow(color: lightbulbLit ? .yellow.opacity(0.8) : .clear, radius: 10)
                }
                .scaleEffect(lightbulbScale)
                .padding(.bottom, 30)
                
                // Typewriter Title
                Text(titleText)
                    .font(.system(size: isCompact ? 18 : 22, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6)) // Grayish
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                
                // Big Text Rows
                VStack(alignment: .leading, spacing: 32) { // Bigger spacing
                    Group {
                        if #available(iOS 15.0, *) {
                            Text("You check your phone\n\(Text(reminderFrequency.lowercased()).foregroundColor(.appAccent))")
                        } else {
                            Text("You check your phone\n") +
                            Text(reminderFrequency.lowercased())
                                .foregroundColor(.appAccent)
                        }
                    }
                    .font(.system(size: isCompact ? 22 : 26, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .opacity(row1Opacity)
                    
                    Group {
                        if #available(iOS 15.0, *) {
                            Text("That's \(Text(phoneCheckCount).foregroundColor(.appAccent)) daily chances to remember what matters.")
                        } else {
                            Text("That's ") +
                            Text(phoneCheckCount)
                                .foregroundColor(.appAccent) +
                            Text(" daily chances to remember what matters.")
                        }
                    }
                    .font(.system(size: isCompact ? 22 : 26, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .opacity(row2Opacity)
                        
                    Text("...instead of losing time to \(distractionText.lowercased()).")
                        .font(.system(size: isCompact ? 22 : 26, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .opacity(row3Opacity)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: isCompact ? 280 : 320, alignment: .top)
                
                Spacer()
                
                // CTA Button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // Track action
                    OnboardingAnalyticsTracker.shared.trackAction(.next, on: .resultsPreview)
                    
                    onContinue()
                }) {
                    HStack {
                        Text("Let's Set It Up")
                            .font(.system(size: 18, weight: .semibold))
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.white) // White text
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appAccent)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, isCompact ? 20 : 40)
                .opacity(buttonOpacity)
            }
        }
        .onAppear {
            animateEntrance()
        }
    }
    
    private func animateEntrance() {
        // 1. Lightbulb appears and lights up (Slower)
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            lightbulbScale = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.6)) {
                lightbulbLit = true
            }
            // Haptic
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
        
        // 2. Typewriter Title (starts at 1.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            typewriterEffect(text: fullTitle)
        }
        
        // 3. Rows fade in logic (Slow fade in, simulating reading time)
        let rowDelay = 2.5
        
        // Row 1
        withAnimation(.easeIn(duration: 1.5).delay(rowDelay)) {
            row1Opacity = 1
        }
        
        // Row 2 (Wait for read time ~2.5s)
        withAnimation(.easeIn(duration: 1.5).delay(rowDelay + 2.5)) {
            row2Opacity = 1
        }
        
        // Row 3 (Wait for read time ~2.5s)
        withAnimation(.easeIn(duration: 1.5).delay(rowDelay + 5.0)) {
            row3Opacity = 1
        }
        
        // 4. Button
        withAnimation(.easeOut(duration: 1.0).delay(rowDelay + 6.5)) {
             buttonOpacity = 1
        }
        
        OnboardingAnalytics.trackStepShown("results_insight")
    }
    
    private func typewriterEffect(text: String) {
        titleText = ""
        let characters = Array(text)
        for (index, char) in characters.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                titleText.append(char)
            }
        }
    }
}



// MARK: - Trajectory View (Your New Path)

struct TrajectoryView: View {
    let onContinue: () -> Void
    
    // MARK: - Animation States
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var graphOpacity: Double = 0
    @State private var upwardCurveTrim: CGFloat = 0
    @State private var downwardCurveTrim: CGFloat = 0
    @State private var labelsOpacity: Double = 0
    @State private var bottomTextOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        ZStack {
            // Dark gradient background matching brand
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Subtle accent glow at top
                RadialGradient(
                    colors: [Color.appAccent.opacity(0.08), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: isCompact ? 30 : 50)
                        
                        // MARK: - Title
                        Text(OnboardingQuizState.shared.displayName != nil ? String(format: NSLocalizedString("Your New Trajectory,\n%@", comment: ""), OnboardingQuizState.shared.displayName!) : NSLocalizedString("Your New Trajectory", comment: ""))
                            .font(.system(size: isCompact ? 28 : 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .opacity(titleOpacity)
                            .padding(.horizontal, 24)
                        
                        Spacer(minLength: isCompact ? 12 : 16)
                        
                        // MARK: - Subtitle
                        Group {
                            if #available(iOS 15.0, *) {
                                Text("Never forget \(Text("what matters").foregroundColor(.appAccent))")
                            } else {
                                Text("Never forget ") +
                                Text("what matters")
                                    .foregroundColor(.appAccent)
                            }
                        }
                        .font(.system(size: isCompact ? 16 : 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .opacity(subtitleOpacity)
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: isCompact ? 24 : 36)
                        
                        // MARK: - Graph Container
                        VStack(spacing: 0) {
                            ZStack {
                                // Graph background
                                RoundedRectangle(cornerRadius: isCompact ? 20 : 24, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: isCompact ? 20 : 24, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                                
                                VStack(spacing: 0) {
                                    // Graph area
                                    GeometryReader { geometry in
                                        ZStack {
                                            // Downward curve (Forgetting)
                                            DownwardCurveShape()
                                                .trim(from: 0, to: downwardCurveTrim)
                                                .stroke(
                                                    Color(red: 1.0, green: 0.2, blue: 0.2),
                                                    style: StrokeStyle(lineWidth: isCompact ? 3 : 4, lineCap: .round)
                                                )
                                                .shadow(color: Color(red: 1.0, green: 0.2, blue: 0.2).opacity(0.6), radius: 12, x: 0, y: 0)
                                            
                                            // Upward curve (NoteWall Path)
                                            UpwardCurveShape()
                                                .trim(from: 0, to: upwardCurveTrim)
                                                .stroke(
                                                    Color.appAccent,
                                                    style: StrokeStyle(lineWidth: isCompact ? 3 : 4, lineCap: .round)
                                                )
                                                .shadow(color: Color.appAccent.opacity(0.6), radius: 12, x: 0, y: 0)
                                                .shadow(color: Color.appAccent.opacity(0.3), radius: 20, x: 0, y: 0)
                                            
                                            // Labels with dots
                                            VStack {
                                                HStack {
                                                    // NoteWall label (top left - above curve)
                                                    HStack(spacing: 6) {
                                                        Circle()
                                                            .fill(Color.appAccent)
                                                            .frame(width: isCompact ? 8 : 10, height: isCompact ? 8 : 10)
                                                            .shadow(color: Color.appAccent.opacity(0.8), radius: 4, x: 0, y: 0)
                                                        
                                                        Text("NoteWall")
                                                            .font(.system(size: isCompact ? 12 : 14, weight: .semibold))
                                                            .foregroundColor(.appAccent)
                                                    }
                                                    .padding(.horizontal, isCompact ? 10 : 12)
                                                    .padding(.vertical, isCompact ? 5 : 6)
                                                    .background(
                                                        Capsule()
                                                            .fill(Color.appAccent.opacity(0.15))
                                                    )
                                                    .opacity(labelsOpacity)
                                                    
                                                    Spacer()
                                                }
                                                .padding(.top, isCompact ? 12 : 16)
                                                .padding(.leading, isCompact ? 16 : 20)
                                                
                                                Spacer()
                                                
                                                // Forgetting label (bottom right)
                                                HStack {
                                                    Spacer()
                                                    
                                                    HStack(spacing: 6) {
                                                        Circle()
                                                            .fill(Color(red: 1.0, green: 0.2, blue: 0.2))
                                                            .frame(width: isCompact ? 8 : 10, height: isCompact ? 8 : 10)
                                                            .shadow(color: Color(red: 1.0, green: 0.2, blue: 0.2).opacity(0.8), radius: 4, x: 0, y: 0)
                                                        
                                                        Text("Forgetting")
                                                            .font(.system(size: isCompact ? 12 : 14, weight: .semibold))
                                                            .foregroundColor(Color(red: 1.0, green: 0.2, blue: 0.2))
                                                    }
                                                    .padding(.horizontal, isCompact ? 10 : 12)
                                                    .padding(.vertical, isCompact ? 5 : 6)
                                                    .background(
                                                        Capsule()
                                                            .fill(Color(red: 1.0, green: 0.2, blue: 0.2).opacity(0.15))
                                                    )
                                                    .opacity(labelsOpacity)
                                                }
                                                .padding(.bottom, isCompact ? 30 : 40)
                                                .padding(.trailing, isCompact ? 16 : 20)
                                            }
                                        }
                                    }
                                    .frame(height: isCompact ? 180 : 220)
                                    .padding(.horizontal, isCompact ? 12 : 16)
                                    .padding(.top, isCompact ? 16 : 20)
                                    
                                    // X-axis labels
                                    HStack {
                                        Text("Now")
                                            .font(.system(size: isCompact ? 11 : 13, weight: .medium))
                                            .foregroundColor(.white.opacity(0.5))
                                        
                                        Spacer()
                                        
                                        Text("Daily")
                                            .font(.system(size: isCompact ? 11 : 13, weight: .medium))
                                            .foregroundColor(.white.opacity(0.5))
                                        
                                        Spacer()
                                        
                                        Text("Always")
                                            .font(.system(size: isCompact ? 11 : 13, weight: .medium))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .padding(.horizontal, isCompact ? 24 : 32)
                                    .padding(.bottom, isCompact ? 16 : 20)
                                    .opacity(labelsOpacity)
                                }
                            }
                            .frame(height: isCompact ? 240 : 300)
                        }
                        .opacity(graphOpacity)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        Spacer(minLength: isCompact ? 24 : 36)
                        
                        // MARK: - Bottom Message
                        VStack(spacing: isCompact ? 8 : 12) {
                            Text("Never forget what matters.")
                                .font(.system(size: isCompact ? 20 : 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("NoteWall puts your most important things on your wallpaper, so you see them every time you unlock your phone.")
                                .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        .opacity(bottomTextOpacity)
                        
                        Spacer(minLength: isCompact ? 20 : 30)
                    }
                    .padding(.bottom, isCompact ? 90 : 110)
                }
                
                // MARK: - Continue Button
                VStack(spacing: isCompact ? 6 : 10) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        // Track action
                        OnboardingAnalyticsTracker.shared.trackAction(.next, on: .resultsInsight)
                        
                        onContinue()
                    }) {
                        HStack(spacing: isCompact ? 8 : 10) {
                            Text("Let's Set It Up")
                                .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                        }
                        .frame(height: isCompact ? 48 : 56)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
                    
                    // Reassurance text
                    Text("Takes about 4 minutes")
                        .font(.system(size: isCompact ? 11 : 12))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, isCompact ? 16 : 24)
                .padding(.top, isCompact ? 10 : 14)
                .padding(.bottom, isCompact ? 16 : 22)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: isCompact ? 100 : 120)
                    .offset(y: isCompact ? -30 : -40)
                    .allowsHitTesting(false)
                )
                .opacity(buttonOpacity)
            }
        }
        .onAppear {
            // MARK: - Animation Sequence
            
            // 1. Title fades in
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                titleOpacity = 1
            }
            
            // 2. Subtitle fades in
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                subtitleOpacity = 1
            }
            
            // 3. Graph container fades in
            withAnimation(.easeOut(duration: 0.5).delay(0.9)) {
                graphOpacity = 1
            }
            
            // 4. Curves animate drawing (staggered)
            withAnimation(.easeInOut(duration: 1.5).delay(1.2)) {
                upwardCurveTrim = 1.0
            }
            
            withAnimation(.easeInOut(duration: 1.5).delay(1.4)) {
                downwardCurveTrim = 1.0
            }
            
            // 5. Labels appear after curves
            withAnimation(.easeOut(duration: 0.5).delay(2.5)) {
                labelsOpacity = 1
            }
            
            // 6. Bottom text fades in
            withAnimation(.easeOut(duration: 0.6).delay(2.8)) {
                bottomTextOpacity = 1
            }
            
            // 7. Button appears last
            withAnimation(.easeOut(duration: 0.5).delay(3.2)) {
                buttonOpacity = 1
            }
            
            OnboardingAnalytics.trackStepShown("trajectory")
        }
    }
}

// MARK: - Curve Shapes

private struct UpwardCurveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let startPoint = CGPoint(x: rect.minX + 20, y: rect.maxY - 30)
        let endPoint = CGPoint(x: rect.maxX - 20, y: rect.minY + 30)
        
        // Control points for smooth upward curve
        let control1 = CGPoint(x: rect.width * 0.3, y: rect.maxY - 20)
        let control2 = CGPoint(x: rect.width * 0.6, y: rect.minY + 50)
        
        path.move(to: startPoint)
        path.addCurve(to: endPoint, control1: control1, control2: control2)
        
        return path
    }
}

private struct DownwardCurveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let startPoint = CGPoint(x: rect.minX + 20, y: rect.maxY - 30)
        let endPoint = CGPoint(x: rect.maxX - 20, y: rect.maxY - 10)
        
        // Control points for smooth downward curve
        let control1 = CGPoint(x: rect.width * 0.35, y: rect.height * 0.4)
        let control2 = CGPoint(x: rect.width * 0.65, y: rect.maxY - 5)
        
        path.move(to: startPoint)
        path.addCurve(to: endPoint, control1: control1, control2: control2)
        
        return path
    }
}

// Legacy alias for compatibility
typealias SocialProofView = TrajectoryView

// MARK: - Setup Intro View (Before Technical Steps)

struct SetupIntroView: View {
    let title: String
    let subtitle: String
    let icon: String
    let steps: [SetupStep]
    let timeEstimate: String
    let ctaText: String
    let onContinue: () -> Void
    
    struct SetupStep: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
        let time: String
    }
    
    @State private var contentOpacity: Double = 0
    @State private var stepsOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: isCompact ? 30 : 60)
                
                // Icon and title
                    VStack(spacing: isCompact ? 16 : 24) {
                    ZStack {
                        Circle()
                            .fill(Color.appAccent.opacity(0.15))
                                .frame(width: isCompact ? 64 : 80, height: isCompact ? 64 : 80)
                        
                        Image(systemName: icon)
                                .font(.system(size: isCompact ? 28 : 36, weight: .medium))
                            .foregroundColor(.appAccent)
                    }
                    
                        VStack(spacing: isCompact ? 8 : 12) {
                        Text(title)
                                .font(.system(size: isCompact ? 22 : 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text(subtitle)
                                .font(.system(size: isCompact ? 14 : 16))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
                .opacity(contentOpacity)
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                
                    Spacer(minLength: isCompact ? 24 : 40)
                
                // Steps preview
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            HStack(spacing: isCompact ? 12 : 16) {
                            // Step number
                            ZStack {
                                Circle()
                                    .fill(Color.appAccent.opacity(0.2))
                                        .frame(width: isCompact ? 30 : 36, height: isCompact ? 30 : 36)
                                
                                Text("\(index + 1)")
                                        .font(.system(size: isCompact ? 14 : 16, weight: .bold))
                                    .foregroundColor(.appAccent)
                            }
                            
                            // Step info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.text)
                                        .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text(step.time)
                                        .font(.system(size: isCompact ? 11 : 13))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            Image(systemName: step.icon)
                                    .font(.system(size: isCompact ? 15 : 18))
                                .foregroundColor(.white.opacity(0.3))
                        }
                            .padding(.vertical, isCompact ? 12 : 16)
                        
                        if index < steps.count - 1 {
                            // Connector line
                            HStack {
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                        .frame(width: 2, height: isCompact ? 14 : 20)
                                        .padding(.leading, isCompact ? 14 : 17)
                                
                                Spacer()
                            }
                        }
                    }
                }
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                .opacity(stepsOpacity)
                
                    Spacer(minLength: isCompact ? 16 : 24)
                
                // Time estimate badge
                    HStack(spacing: isCompact ? 6 : 8) {
                    Image(systemName: "clock")
                            .font(.system(size: isCompact ? 12 : 14))
                    
                    Text(timeEstimate)
                            .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, isCompact ? 12 : 16)
                    .padding(.vertical, isCompact ? 6 : 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                )
                .opacity(stepsOpacity)
                
                    Spacer(minLength: isCompact ? 16 : 24)
                }
                .padding(.bottom, isCompact ? 80 : 100)
            }
            
            // Continue button
            VStack(spacing: isCompact ? 8 : 12) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // Track action
                    OnboardingAnalyticsTracker.shared.trackAction(.next, on: .setupIntro)
                    
                    onContinue()
                }) {
                    Text(ctaText)
                        .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                        .frame(height: isCompact ? 48 : 56)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
            }
            .padding(.horizontal, isCompact ? 16 : 24)
            .padding(.top, isCompact ? 12 : 18)
            .padding(.bottom, isCompact ? 16 : 22)
            .background(Color.clear)
            .opacity(buttonOpacity)
        }
    }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                contentOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                stepsOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
                buttonOpacity = 1
            }
            
            OnboardingAnalytics.trackStepShown("setup_intro")
        }
    }
}

// MARK: - Celebration View (After Major Steps)

struct CelebrationView: View {
    let title: String
    let subtitle: String
    let encouragement: String
    let nextStepPreview: String?
    let onContinue: () -> Void
    
    @State private var checkmarkScale: CGFloat = 0
    @State private var checkmarkOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var confettiTrigger: Int = 0
    @State private var buttonOpacity: Double = 0
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Confetti overlay
            ConfettiView(trigger: $confettiTrigger)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: isCompact ? 40 : 60)
                
                // Checkmark with animation
                ZStack {
                    // Pulse rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.appAccent.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                                .frame(width: (isCompact ? 90 : 120) + CGFloat(i) * (isCompact ? 22 : 30), height: (isCompact ? 90 : 120) + CGFloat(i) * (isCompact ? 22 : 30))
                            .scaleEffect(checkmarkScale)
                    }
                    
                    // Main checkmark circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                            .frame(width: isCompact ? 76 : 100, height: isCompact ? 76 : 100)
                        .shadow(color: Color.appAccent.opacity(0.4), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "checkmark")
                            .font(.system(size: isCompact ? 36 : 48, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(checkmarkScale)
                .opacity(checkmarkOpacity)
                
                    Spacer(minLength: isCompact ? 24 : 40)
                
                // Text content
                    VStack(spacing: isCompact ? 10 : 16) {
                    Text(title)
                            .font(.system(size: isCompact ? 26 : 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                            .font(.system(size: isCompact ? 15 : 18))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    
                    Text(encouragement)
                            .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                        .foregroundColor(.appAccent)
                        .padding(.top, 8)
                }
                .opacity(textOpacity)
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                
                if let nextStep = nextStepPreview {
                        Spacer(minLength: isCompact ? 20 : 32)
                    
                    // Next step preview
                        HStack(spacing: isCompact ? 10 : 12) {
                        Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: isCompact ? 17 : 20))
                            .foregroundColor(.appAccent)
                        
                        Text("Next: \(nextStep)")
                                .font(.system(size: isCompact ? 13 : 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .opacity(textOpacity)
                }
                
                    Spacer(minLength: isCompact ? 24 : 40)
                
                // Continue button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onContinue()
                }) {
                    Text("Continue")
                            .font(.system(size: isCompact ? 16 : 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                            .padding(.vertical, isCompact ? 14 : 18)
                        .background(
                                RoundedRectangle(cornerRadius: isCompact ? 14 : 16, style: .continuous)
                                .fill(Color.appAccent)
                        )
                        .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .opacity(buttonOpacity)
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                    .padding(.bottom, isCompact ? 24 : 40)
                }
            }
        }
        .onAppear {
            // Trigger celebration
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                confettiTrigger += 1
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                textOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.8)) {
                buttonOpacity = 1
            }
        }
    }
}

// MARK: - Motivational Micro-Copy Component

struct MotivationalBanner: View {
    let message: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appAccent)
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.appAccent.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Final Success View

struct SetupCompleteView: View {
    let onContinue: () -> Void
    @ObservedObject private var quizState = OnboardingQuizState.shared
    
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var statsOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Dark gradient background with celebratory tint
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Hero celebration
                ZStack {
                    // Animated rings
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .stroke(
                                Color.appAccent.opacity(0.3 - Double(i) * 0.07),
                                lineWidth: 2
                            )
                            .frame(width: 140 + CGFloat(i) * 40, height: 140 + CGFloat(i) * 40)
                    }
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.appAccent.opacity(0.5), radius: 30, x: 0, y: 15)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                
                Spacer()
                    .frame(height: 40)
                
                // Success message
                VStack(spacing: 16) {
                    Text(quizState.displayName != nil ? String(format: NSLocalizedString("%@, Your Focus System Is Ready! 🎉", comment: ""), quizState.displayName!) : NSLocalizedString("Your Focus System Is Ready! 🎉", comment: ""))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("You just did what 97% of people never do:\nbuilt a system that actually works.")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .opacity(textOpacity)
                .padding(.horizontal, 24)
                
                Spacer()
                    .frame(height: 32)
                
                // Stats card - perfectly symmetrical
                HStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Text("\(Int(quizState.totalSetupTime / 60)):\(String(format: "%02d", Int(quizState.totalSetupTime) % 60))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.appAccent)
                        
                        Text("Setup Time")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            
                    }
                    .frame(maxWidth: .infinity)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1, height: 50)
                    
                    VStack(spacing: 6) {
                        Text("∞")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.appAccent)
                        
                        Text("Daily Reminders")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            
                    }
                    .frame(maxWidth: .infinity)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1, height: 50)
                    
                    VStack(spacing: 6) {
                        Text("Top 3%")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.appAccent)
                        
                        Text("Focus Elite")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .opacity(statsOpacity)
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Continue button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // Track action
                    OnboardingAnalyticsTracker.shared.trackAction(.next, on: .setupComplete)
                    
                    quizState.setupCompleted = true
                    onContinue()
                }) {
                    Text("Unlock Full Potential →")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.appAccent)
                        )
                        .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .opacity(buttonOpacity)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Celebration animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            
            // Haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                textOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
                statsOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(1.1)) {
                buttonOpacity = 1
            }
            
            OnboardingAnalytics.trackStepShown("setup_complete")
            OnboardingAnalytics.trackPaywallShown(totalSetupTime: quizState.totalSetupTime)
        }
    }
}

// MARK: - Reassurance View (For Troubleshooting Friction)

struct ReassuranceView: View {
    let title: String
    let message: String
    let stat: String
    let statLabel: String
    let ctaText: String
    let onContinue: () -> Void
    
    @State private var contentOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 32) {
                    // Reassurance icon
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.orange)
                    }
                    
                    // Title and message
                    VStack(spacing: 16) {
                        Text(title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text(message)
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    
                    // Stat badge
                    VStack(spacing: 8) {
                        Text(stat)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.appAccent)
                        
                        Text(statLabel)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .opacity(contentOpacity)
                
                Spacer()
                
                // Continue button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // Track action
                    OnboardingAnalyticsTracker.shared.trackAction(.next, on: .installShortcut, additionalParams: ["subtype": "reassurance_continue"])
                    
                    onContinue()
                }) {
                    Text(ctaText)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.appAccent)
                        )
                        .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .opacity(buttonOpacity)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                contentOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                buttonOpacity = 1
            }
        }
    }
}

// MARK: - Quiz Data

struct QuizData {
    static let forgetMostOptions = [
        QuizQuestionView.QuizOption(emoji: "💼", title: "Work tasks & deadlines", value: "Work tasks"),
        QuizQuestionView.QuizOption(emoji: "🎯", title: "Personal goals & habits", value: "Personal goals"),
        QuizQuestionView.QuizOption(emoji: "🛒", title: "Shopping & errands", value: "Shopping lists"),
        QuizQuestionView.QuizOption(emoji: "🔄", title: "Daily habits & routines", value: "Habits"),
        QuizQuestionView.QuizOption(emoji: "✨", title: "A little bit of everything", value: "Everything")
    ]
    
    static let phoneChecksOptions = [
        QuizQuestionView.QuizOption(emoji: "📱", title: "50-100 times", value: "50-100"),
        QuizQuestionView.QuizOption(emoji: "📲", title: "100-200 times", value: "100-200"),
        QuizQuestionView.QuizOption(emoji: "🔥", title: "200+ times (power user!)", value: "200+")
    ]
    
    static let distractionOptions = [
        QuizQuestionView.QuizOption(emoji: "🎵", title: "TikTok", value: "TikTok"),
        QuizQuestionView.QuizOption(emoji: "📸", title: "Instagram", value: "Instagram"),
        QuizQuestionView.QuizOption(emoji: "▶️", title: "YouTube", value: "YouTube"),
        QuizQuestionView.QuizOption(emoji: "🐦", title: "Twitter/X", value: "Twitter"),
        QuizQuestionView.QuizOption(emoji: "💬", title: "Messages & notifications", value: "Messages")
    ]
    
    static let setupSteps = [
        SetupIntroView.SetupStep(icon: "link", text: "Connect the shortcut", time: "~3 minutes"),
        SetupIntroView.SetupStep(icon: "note.text", text: "Add your first notes", time: "~30 seconds"),
        SetupIntroView.SetupStep(icon: "photo", text: "Choose your wallpaper style", time: "~30 seconds")
    ]
}

// MARK: - Confetti View

struct ConfettiView: View {
    @Binding var trigger: Int
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: Double
        var y: Double
        var angle: Double
        var spin: Double
        var scale: Double
        var color: Color
        var speedX: Double
        var speedY: Double
        var spinSpeed: Double
        var opacity: Double = 1.0
    }
    
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0/60.0)) { timeline in
                Canvas { context, size in
                    for particle in particles {
                        let rect = CGRect(x: particle.x, y: particle.y, width: 10 * particle.scale, height: 10 * particle.scale)
                        var shape = context.transform
                        shape = shape.translatedBy(x: rect.midX, y: rect.midY)
                        shape = shape.rotated(by: CGFloat(particle.spin * .pi / 180))
                        shape = shape.translatedBy(x: -rect.midX, y: -rect.midY)
                        
                        context.drawLayer { ctx in
                            ctx.transform = shape
                            ctx.opacity = particle.opacity
                            ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(particle.color))
                        }
                    }
                }
                .onChange(of: timeline.date) { _ in
                    updateParticles(in: geometry.size)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onChange(of: trigger) { _ in
            emitConfetti()
        }
    }
    
    private func emitConfetti() {
        // Clear any existing particles first to prevent accumulation
        particles.removeAll()
        
        let colors: [Color] = [.red, .blue, .yellow, .pink, .purple, .orange]
        let screenWidth = ScreenDimensions.width
        let screenHeight = ScreenDimensions.height
        
        // Reduced from 200 to 100 particles for better performance
        for _ in 0..<100 {
            let angle = Double.random(in: 0...2 * .pi)
            let speed = Double.random(in: 18...35)
            
            let particle = Particle(
                x: screenWidth / 2,
                y: screenHeight / 2,
                angle: Double.random(in: 0...360),
                spin: Double.random(in: 0...360),
                scale: Double.random(in: 0.7...1.2),
                color: colors.randomElement() ?? .blue,
                speedX: cos(angle) * speed,
                speedY: sin(angle) * speed,
                spinSpeed: Double.random(in: -12...12)
            )
            particles.append(particle)
        }
    }
    
    private func updateParticles(in size: CGSize) {
        var indicesToRemove: [Int] = []
        
        for i in particles.indices {
            particles[i].x += particles[i].speedX
            particles[i].y += particles[i].speedY
            particles[i].spin += particles[i].spinSpeed
            
            // Physics: Gravity and Air Resistance
            particles[i].speedX *= 0.96
            particles[i].speedY *= 0.96
            particles[i].speedY += 0.5
            
            // Fade out smoothly
            particles[i].opacity -= 0.008
            
            // Mark for removal if off-screen or invisible
            if particles[i].opacity <= 0 || 
               particles[i].y > size.height + 50 ||
               particles[i].x < -50 || 
               particles[i].x > size.width + 50 {
                indicesToRemove.append(i)
            }
        }
        
        // Remove in reverse order to maintain indices
        for index in indicesToRemove.reversed() {
            particles.remove(at: index)
        }
    }
}

// MARK: - Letter Spacing Modifier (iOS 15+ Compatible)

struct LetterSpacingModifier: ViewModifier {
    let spacing: CGFloat
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.kerning(spacing)
        } else {
            content
        }
    }
}

