import SwiftUI
import UIKit

// MARK: - Enhanced Onboarding State Management

/// Manages quiz answers and personalization data throughout onboarding
class OnboardingQuizState: ObservableObject {
    static let shared = OnboardingQuizState()
    
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
        // Using Firebase Analytics via AnalyticsService
        AnalyticsService.shared.trackScreenView(screenName: "onboarding_\(step)")
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
        // Forward to Firebase Analytics
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

// MARK: - Pain Point View (Emotional Hook)

struct PainPointView: View {
    let onContinue: () -> Void
    @State private var headerOpacity: Double = 0
    @State private var numberScale: CGFloat = 0.3
    @State private var numberOpacity: Double = 0
    @State private var numberValue: Int = 0
    @State private var contextOpacity: Double = 0
    @State private var questionOpacity: Double = 0
    @State private var solutionOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    @ObservedObject private var quizState = OnboardingQuizState.shared
    
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
                
                // Subtle radial glow behind number
                RadialGradient(
                    colors: [Color.appAccent.opacity(0.08), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 300
                )
                .offset(y: isCompact ? -60 : -80)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: isCompact ? 24 : 36) {
                        Spacer(minLength: isCompact ? 30 : 50)
                        
                        // MARK: - Header badge
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
                        
                        // MARK: - Main stat section
                        VStack(spacing: isCompact ? 16 : 24) {
                            Text("Did you know that the average person")
                                .font(.system(size: isCompact ? 16 : 19, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .opacity(headerOpacity)
                            
                            Text("unlocks their phone up to")
                                .font(.system(size: isCompact ? 16 : 19, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .opacity(headerOpacity)
                            
                            // Big animated number without pulse ring
                            VStack(spacing: isCompact ? 4 : 6) {
                                Text("\(numberValue)")
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
                        
                        // MARK: - Context cards
                        VStack(spacing: isCompact ? 10 : 14) {
                            // Stat breakdown card
                            HStack(spacing: isCompact ? 14 : 18) {
                                StatMiniCard(
                                    value: "4hrs",
                                    label: "screen time",
                                    icon: "clock.fill",
                                    isCompact: isCompact
                                )
                                
                                StatMiniCard(
                                    value: "96%",
                                    label: "forgotten",
                                    icon: "brain.head.profile",
                                    isCompact: isCompact
                                )
                                
                                StatMiniCard(
                                    value: "2.5s",
                                    label: "avg glance",
                                    icon: "eye.fill",
                                    isCompact: isCompact
                                )
                            }
                            .opacity(contextOpacity)
                        }
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        // MARK: - The question
                        VStack(spacing: isCompact ? 12 : 16) {
                            Text("But here's the real question...")
                                .font(.system(size: isCompact ? 13 : 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text("How many times did you\nactually remember why?")
                                .font(.system(size: isCompact ? 20 : 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .opacity(questionOpacity)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        // MARK: - Solution teaser
                        VStack(spacing: isCompact ? 10 : 14) {
                            HStack(spacing: isCompact ? 10 : 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.appAccent.opacity(0.15))
                                        .frame(width: isCompact ? 36 : 44, height: isCompact ? 36 : 44)
                                    
                                    Image(systemName: "iphone.gen3")
                                        .font(.system(size: isCompact ? 16 : 20))
                                        .foregroundColor(.appAccent)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("What if your lock screen reminded you?")
                                        .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("Every unlock becomes intentional")
                                        .font(.system(size: isCompact ? 12 : 14))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                                    .foregroundColor(.appAccent.opacity(0.6))
                            }
                            .padding(isCompact ? 14 : 18)
                            .background(
                                RoundedRectangle(cornerRadius: isCompact ? 14 : 18, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: isCompact ? 14 : 18, style: .continuous)
                                            .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .opacity(solutionOpacity)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
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
                            Text("Tell Me More")
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
            
            // Animate number count-up with easing
            let countDuration: Double = 1.0
            let steps = 50
            let stepDuration = countDuration / Double(steps)
            
            for i in 0...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + stepDuration * Double(i)) {
                    let progress = Double(i) / Double(steps)
                    // Ease out cubic for satisfying slow-down
                    let easeOut = 1 - pow(1 - progress, 3)
                    numberValue = Int(498.0 * easeOut)
                }
            }
            
            // Number reveal with spring
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.5)) {
                numberOpacity = 1
                numberScale = 1.0
            }
            
            // Context cards
            withAnimation(.easeOut(duration: 0.5).delay(1.6)) {
                contextOpacity = 1
            }
            
            // Question
            withAnimation(.easeOut(duration: 0.5).delay(2.0)) {
                questionOpacity = 1
            }
            
            // Solution teaser
            withAnimation(.easeOut(duration: 0.5).delay(2.4)) {
                solutionOpacity = 1
            }
            
            // Button
            withAnimation(.easeOut(duration: 0.4).delay(2.7)) {
                buttonOpacity = 1
            }
            
            // Success haptic when number finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
            }
            
            OnboardingAnalytics.trackStepShown("pain_point")
        }
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
        
        // Progress animation
        withAnimation(.easeInOut(duration: totalDuration)) {
            progress = 1.0
        }
        
        // Animate percentage number
        let steps = 100
        let stepDuration = totalDuration / Double(steps)
        
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                // Use ease-out curve for more realistic loading feel
                let progress = Double(i) / Double(steps)
                // Ease out cubic: 1 - (1 - x)^3
                let easedProgress = 1 - pow(1 - progress, 3)
                
                // Add some randomness to make it feel like real processing
                let randomVariation = Double.random(in: -0.02...0.02)
                let finalValue = min(100, max(0, Int((easedProgress + randomVariation) * 100)))
                
                // Ensure we always reach 100 at the end
                if i == steps {
                    withAnimation {
                        displayedPercentage = 100
                    }
                } else {
                    withAnimation {
                        displayedPercentage = finalValue
                    }
                }
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
            
            OnboardingAnalytics.trackStepShown("quiz_\(question.prefix(20))")
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
            
            OnboardingAnalytics.trackStepShown("multi_quiz_\(question.prefix(20))")
        }
        .onChange(of: selectedOptions) { _ in
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
    @State private var insightOpacity: Double = 0
    @State private var planOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var progressValue: CGFloat = 0
    
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
    
    var body: some View {
        ZStack {
            // Dark gradient background with subtle glow
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
                    VStack(spacing: isCompact ? 20 : 28) {
                        Spacer(minLength: isCompact ? 20 : 32)
                        
                        // MARK: - Header with completion indicator
                        VStack(spacing: isCompact ? 6 : 10) {
                            // Connecting badge
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: isCompact ? 12 : 14))
                                    .foregroundColor(.appAccent)
                                
                                Text("Analysis Complete")
                                    .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                                    .foregroundColor(.appAccent)
                            }
                            .padding(.horizontal, isCompact ? 12 : 16)
                            .padding(.vertical, isCompact ? 6 : 8)
                            .background(
                                Capsule()
                                    .fill(Color.appAccent.opacity(0.12))
                            )
                            .scaleEffect(checkmarkScale)
                            
                            Text("Your Focus Profile")
                                .font(.system(size: isCompact ? 22 : 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.top, isCompact ? 8 : 12)
                        }
                        .opacity(headerOpacity)
                        
                        // MARK: - Personalized Profile Card
                        VStack(spacing: 0) {
                            // Profile header
                            HStack(spacing: isCompact ? 10 : 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.appAccent.opacity(0.15))
                                        .frame(width: isCompact ? 40 : 48, height: isCompact ? 40 : 48)
                                    
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: isCompact ? 18 : 22))
                                        .foregroundColor(.appAccent)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Based on your answers")
                                        .font(.system(size: isCompact ? 11 : 12))
                                        .foregroundColor(.white.opacity(0.5))
                                    
                                    Text("Here's what we learned")
                                        .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                            }
                            .padding(isCompact ? 14 : 18)
                            .background(Color.white.opacity(0.03))
                            
                            // Profile insights
                            VStack(spacing: isCompact ? 14 : 18) {
                                // Focus areas
                                ProfileInsightRow(
                                    icon: "target",
                                    label: "YOU WANT TO REMEMBER",
                                    values: focusAreas,
                                    isCompact: isCompact
                                )
                                
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                
                                // Distraction
                                ProfileInsightRow(
                                    icon: "xmark.circle",
                                    label: "YOUR BIGGEST CHALLENGE",
                                    values: [distractionText],
                                    isCompact: isCompact
                                )
                                
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                
                                // Phone usage
                                HStack {
                                    Image(systemName: "iphone")
                                        .font(.system(size: isCompact ? 14 : 16))
                                        .foregroundColor(.white.opacity(0.4))
                                        .frame(width: isCompact ? 20 : 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("DAILY PHONE CHECKS")
                                            .font(.system(size: isCompact ? 9 : 10, weight: .medium))
                                            .foregroundColor(.white.opacity(0.4))
                                            .tracking(0.5)
                                        
                                        Text("\(phoneCheckCount) times")
                                            .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    // Visual indicator
                                    HStack(spacing: 3) {
                                        ForEach(0..<5, id: \.self) { i in
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(i < intensityLevel ? Color.appAccent : Color.white.opacity(0.15))
                                                .frame(width: isCompact ? 4 : 5, height: isCompact ? 16 : 20)
                                        }
                                    }
                                }
                            }
                            .padding(isCompact ? 14 : 18)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                        .opacity(profileOpacity)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        // MARK: - What This Means insight
                        VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: isCompact ? 14 : 16))
                                    .foregroundColor(.yellow.opacity(0.8))
                                
                                Text("What this means")
                                    .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            Text("You check your phone \(reminderFrequency.lowercased()) on average. That's \(phoneCheckCount) opportunities daily to see what matters most — instead of getting lost in \(distractionText.lowercased()).")
                                .font(.system(size: isCompact ? 13 : 15))
                                .foregroundColor(.white.opacity(0.7))
                                .lineSpacing(4)
                        }
                        .padding(isCompact ? 14 : 18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                .fill(Color.yellow.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                        .strokeBorder(Color.yellow.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .opacity(insightOpacity)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        // MARK: - Your Plan preview
                        VStack(spacing: isCompact ? 12 : 16) {
                            HStack {
                                Text("Your personalized plan")
                                    .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("3 steps")
                                    .font(.system(size: isCompact ? 11 : 13))
                                    .foregroundColor(.appAccent)
                            }
                            
                            // Progress steps preview
                            HStack(spacing: isCompact ? 8 : 12) {
                                PlanStepPreview(number: "1", title: "Lock screen setup", isCompleted: false, isCompact: isCompact)
                                PlanStepPreview(number: "2", title: "First note", isCompleted: false, isCompact: isCompact)
                                PlanStepPreview(number: "3", title: "Shortcut install", isCompleted: false, isCompact: isCompact)
                            }
                        }
                        .padding(isCompact ? 14 : 18)
                        .background(
                            RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                        )
                        .opacity(planOpacity)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
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
                            Text("Let's Set It Up")
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
            // Staggered animations for smooth flow
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                checkmarkScale = 1.0
                headerOpacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                profileOpacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                insightOpacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(0.7)) {
                planOpacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.4).delay(0.9)) {
                buttonOpacity = 1.0
            }
            
            // Success haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            OnboardingAnalytics.trackStepShown("results_preview")
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
}

// MARK: - Profile Insight Row

private struct ProfileInsightRow: View {
    let icon: String
    let label: String
    let values: [String]
    let isCompact: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: isCompact ? 14 : 16))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: isCompact ? 20 : 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: isCompact ? 9 : 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .modifier(LetterSpacingModifier(spacing: 0.5))
                
                HStack(spacing: isCompact ? 6 : 8) {
                    ForEach(values, id: \.self) { value in
                        Text(value)
                            .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                            .foregroundColor(.appAccent)
                            .padding(.horizontal, isCompact ? 8 : 10)
                            .padding(.vertical, isCompact ? 4 : 6)
                            .background(
                                Capsule()
                                    .fill(Color.appAccent.opacity(0.12))
                            )
                    }
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Plan Step Preview

private struct PlanStepPreview: View {
    let number: String
    let title: String
    let isCompleted: Bool
    let isCompact: Bool
    
    var body: some View {
        VStack(spacing: isCompact ? 6 : 8) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.appAccent : Color.white.opacity(0.08))
                    .frame(width: isCompact ? 28 : 34, height: isCompact ? 28 : 34)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: isCompact ? 12 : 14, weight: .bold))
                        .foregroundColor(.black)
                } else {
                    Text(number)
                        .font(.system(size: isCompact ? 12 : 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Text(title)
                .font(.system(size: isCompact ? 10 : 11))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Social Proof View (Redesigned)

struct SocialProofView: View {
    let onContinue: () -> Void
    
    // MARK: - Animation States
    @State private var headerOpacity: Double = 0
    @State private var statsOpacity: Double = 0
    @State private var ratingOpacity: Double = 0
    @State private var testimonialOpacity: Double = 0
    @State private var setupPreviewOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var countUp: Int = 0
    @State private var numberScale: CGFloat = 0.8
    @State private var pulseScale: CGFloat = 1.0
    
    // Fixed target count: 2,855 (synced with review page)
    private var targetCount: Int {
        2855
    }
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        ZStack {
            // Dark gradient background with subtle glow
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
                        Spacer(minLength: isCompact ? 20 : 32)
                        
                        // MARK: - Header Section (Connection from previous step)
                        VStack(spacing: isCompact ? 6 : 10) {
                            // Connecting badge
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: isCompact ? 12 : 14))
                                    .foregroundColor(.appAccent)
                                
                                Text("Welcome to the club")
                                    .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                                    .foregroundColor(.appAccent)
                            }
                            .padding(.horizontal, isCompact ? 12 : 16)
                            .padding(.vertical, isCompact ? 6 : 8)
                            .background(
                                Capsule()
                                    .fill(Color.appAccent.opacity(0.12))
                            )
                            
                            Text("Join the Focused Ones")
                                .font(.system(size: isCompact ? 22 : 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.top, isCompact ? 8 : 12)
                        }
                        .opacity(headerOpacity)
                        
                        Spacer(minLength: isCompact ? 20 : 32)
                        
                        // MARK: - Stats Section (User Count)
                        VStack(spacing: isCompact ? 16 : 22) {
                            // Centered number display with subtle glow
                            Text("\(countUp)")
                                .font(.system(size: isCompact ? 56 : 72, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.appAccent, .appAccent.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .monospacedDigit()
                                .scaleEffect(numberScale)
                                .shadow(color: .appAccent.opacity(0.3), radius: 20, x: 0, y: 10)
                            
                            // Horizontal accent line
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .appAccent.opacity(0.5), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: isCompact ? 120 : 160, height: 2)
                            
                            VStack(spacing: isCompact ? 6 : 8) {
                                Text("people already using NoteWall")
                                    .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                
                                // Authenticity message with subtle icon
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: isCompact ? 10 : 12))
                                        .foregroundColor(.green.opacity(0.7))
                                    
                                    Text("We're just new and growing, no fake numbers here")
                                        .font(.system(size: isCompact ? 11 : 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                        .opacity(statsOpacity)
                        
                        Spacer(minLength: isCompact ? 16 : 24)
                        
                        // MARK: - Rating Section
                        HStack(spacing: isCompact ? 3 : 4) {
                            ForEach(0..<5, id: \.self) { index in
                                Image(systemName: "star.fill")
                                    .font(.system(size: isCompact ? 18 : 22))
                                    .foregroundColor(.yellow)
                                    .shadow(color: .yellow.opacity(0.3), radius: 2, x: 0, y: 1)
                            }
                            
                            Text("4.8")
                                .font(.system(size: isCompact ? 16 : 19, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.leading, isCompact ? 8 : 10)
                        }
                        .opacity(ratingOpacity)
                        
                        Spacer(minLength: isCompact ? 20 : 32)
                        
                        // MARK: - Testimonial Card
                        VStack(spacing: 0) {
                            // Quote icon
                            Image(systemName: "quote.opening")
                                .font(.system(size: isCompact ? 24 : 32, weight: .bold))
                                .foregroundColor(.appAccent.opacity(0.6))
                                .padding(.bottom, isCompact ? 10 : 14)
                            
                            // Quote text
                            Group {
                                if #available(iOS 16, *) {
                                    Text("I think it's cool the way it is right now, it's different. Haven't seen one like this.")
                                        .font(.system(size: isCompact ? 16 : 18, weight: .medium))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .italic()
                                        .lineSpacing(4)
                                } else {
                                    Text("I think it's cool the way it is right now, it's different. Haven't seen one like this.")
                                        .font(.system(size: isCompact ? 16 : 18, weight: .medium))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(4)
                                }
                            }
                            .padding(.bottom, isCompact ? 14 : 18)
                            
                            // User info with verification badge
                            HStack(spacing: isCompact ? 10 : 12) {
                                // Avatar
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.appAccent.opacity(0.3), Color.appAccent.opacity(0.15)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: isCompact ? 36 : 42, height: isCompact ? 36 : 42)
                                    
                                    Text("D")
                                        .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                                        .foregroundColor(.appAccent)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text("damagad")
                                            .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: isCompact ? 10 : 12))
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Text("Verified User")
                                        .font(.system(size: isCompact ? 11 : 12))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(isCompact ? 18 : 24)
                        .background(
                            RoundedRectangle(cornerRadius: isCompact ? 18 : 22, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: isCompact ? 18 : 22, style: .continuous)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        )
                        .opacity(testimonialOpacity)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        Spacer(minLength: isCompact ? 16 : 24)
                        
                        // MARK: - Setup Preview Card (What's Next)
                        VStack(spacing: isCompact ? 10 : 14) {
                            HStack(spacing: isCompact ? 8 : 10) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: isCompact ? 14 : 16))
                                    .foregroundColor(.appAccent)
                                
                                Text("Next: Quick 4-minute setup")
                                    .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                Spacer()
                            }
                            
                            // Mini steps preview
                            HStack(spacing: isCompact ? 6 : 8) {
                                ForEach(["link", "note.text", "photo"], id: \.self) { icon in
                                    HStack(spacing: 4) {
                                        Image(systemName: icon)
                                            .font(.system(size: isCompact ? 10 : 12))
                                            .foregroundColor(.appAccent.opacity(0.8))
                                    }
                                    .padding(.horizontal, isCompact ? 8 : 10)
                                    .padding(.vertical, isCompact ? 5 : 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.05))
                                    )
                                }
                                
                                Spacer()
                                
                                Text("~4 min")
                                    .font(.system(size: isCompact ? 11 : 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .padding(isCompact ? 14 : 18)
                        .background(
                            RoundedRectangle(cornerRadius: isCompact ? 14 : 16, style: .continuous)
                                .fill(Color.appAccent.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: isCompact ? 14 : 16, style: .continuous)
                                        .strokeBorder(Color.appAccent.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .opacity(setupPreviewOpacity)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        Spacer(minLength: isCompact ? 20 : 30)
                    }
                    .padding(.bottom, isCompact ? 90 : 110)
                }
                
                // MARK: - Continue Button
                VStack(spacing: isCompact ? 6 : 10) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
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
            
            // 1. Header appears first (connection from previous step)
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                headerOpacity = 1
            }
            
            // 2. Stats section with count animation
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                statsOpacity = 1
            }
            
            // Number scale animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4)) {
                numberScale = 1.0
            }
            
            // Count-up animation
            let duration: Double = 1.2
            let steps = 25
            let stepDuration = duration / Double(steps)
            
            for i in 0...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + stepDuration * Double(i)) {
                    let progress = Double(i) / Double(steps)
                    // Ease-out cubic for smooth deceleration
                    let easeOut = 1 - pow(1 - progress, 3)
                    countUp = Int(Double(targetCount) * easeOut)
                }
            }
            
            // Continuous subtle pulse animation for the ring
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.5)) {
                pulseScale = 1.08
            }
            
            // 3. Rating appears
            withAnimation(.easeOut(duration: 0.4).delay(0.9)) {
                ratingOpacity = 1
            }
            
            // 4. Testimonial slides in
            withAnimation(.easeOut(duration: 0.5).delay(1.2)) {
                testimonialOpacity = 1
            }
            
            // 5. Setup preview appears
            withAnimation(.easeOut(duration: 0.4).delay(1.6)) {
                setupPreviewOpacity = 1
            }
            
            // 6. Button appears last
            withAnimation(.easeOut(duration: 0.4).delay(1.9)) {
                buttonOpacity = 1
            }
            
            OnboardingAnalytics.trackStepShown("social_proof")
        }
    }
}

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
                    Text("Your Focus System Is Ready! 🎉")
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
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
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

