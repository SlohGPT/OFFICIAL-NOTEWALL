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
        print("📊 Analytics: Step shown - \(step)")
        #endif
        // TODO: Integrate with your analytics service (Mixpanel, Amplitude, etc.)
    }
    
    static func trackStepCompleted(_ step: String, timeSpent: TimeInterval) {
        #if DEBUG
        print("📊 Analytics: Step completed - \(step) (took \(String(format: "%.1f", timeSpent))s)")
        #endif
    }
    
    static func trackQuizAnswer(question: String, answer: String) {
        #if DEBUG
        print("📊 Analytics: Quiz answer - \(question): \(answer)")
        #endif
    }
    
    static func trackPaywallShown(totalSetupTime: TimeInterval) {
        #if DEBUG
        print("📊 Analytics: Paywall shown after \(String(format: "%.1f", totalSetupTime))s setup")
        #endif
    }
    
    static func trackPaywallConversion(success: Bool, product: String?) {
        #if DEBUG
        print("📊 Analytics: Paywall conversion - \(success ? "SUCCESS" : "DECLINED") - \(product ?? "none")")
        #endif
    }
    
    static func trackDropOff(step: String, reason: String?) {
        #if DEBUG
        print("📊 Analytics: Drop-off at \(step) - \(reason ?? "unknown")")
        #endif
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
    @State private var textOpacity1: Double = 0
    @State private var numberScale: CGFloat = 0.3
    @State private var numberOpacity: Double = 0
    @State private var numberValue: Int = 0
    @State private var textOpacity2: Double = 0
    @State private var textOpacity3: Double = 0
    @State private var buttonOpacity: Double = 0
    
    @ObservedObject private var quizState = OnboardingQuizState.shared
    
    // Adaptive layout values
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    private var numberFontSize: CGFloat { isCompact ? 64 : 96 }
    private var titleFontSize: CGFloat { isCompact ? 20 : 24 }
    private var subtitleFontSize: CGFloat { isCompact ? 15 : 18 }
    private var sectionSpacing: CGFloat { isCompact ? 28 : 48 }
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
                        Spacer(minLength: isCompact ? 40 : 60)
                    
                    VStack(spacing: sectionSpacing) {
                        // Opening text
                        VStack(spacing: isCompact ? 10 : 16) {
                            Text("Did you know?")
                                .font(.system(size: subtitleFontSize, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .opacity(textOpacity1)
                            
                            Text("People open their phones")
                                .font(.system(size: titleFontSize, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .opacity(textOpacity1)
                        }
                        
                        // Animated big number
                        VStack(spacing: isCompact ? 8 : 12) {
                            Text("\(numberValue)")
                            .font(.system(size: numberFontSize, weight: .heavy, design: .rounded))
                            .foregroundColor(.appAccent)
                            .scaleEffect(numberScale)
                            .opacity(numberOpacity)
                        
                        // "times per day" with underlined "per day"
                        HStack(spacing: 4) {
                            Text("times")
                                .font(.system(size: isCompact ? 18 : 22, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("per day")
                                .font(.system(size: isCompact ? 18 : 22, weight: .bold))
                                .foregroundColor(.white)
                                .underline(true, color: .appAccent)
                        }
                        .opacity(numberOpacity)
                    }
                    
                    // Question
                    VStack(spacing: isCompact ? 10 : 16) {
                        Text("How many times do you remember")
                            .font(.system(size: isCompact ? 17 : 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .opacity(textOpacity2)
                        
                        Text("why you wanted to unlock it?")
                            .font(.system(size: isCompact ? 17 : 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .opacity(textOpacity2)
                    }
                    .padding(.horizontal, isCompact ? 20 : 32)
                    
                    // Solution
                    HStack(spacing: isCompact ? 8 : 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: isCompact ? 17 : 20))
                            .foregroundColor(.appAccent)
                        
                        Text("NoteWall remembers this for you")
                            .font(.system(size: isCompact ? 16 : 19, weight: .semibold))
                            .foregroundColor(.appAccent)
                    }
                    .padding(.vertical, isCompact ? 12 : 16)
                    .padding(.horizontal, isCompact ? 18 : 24)
                    .background(
                        RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                            .fill(Color.appAccent.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                    .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 1.5)
                            )
                    )
                    .opacity(textOpacity3)
                }
                
                    Spacer(minLength: isCompact ? 30 : 50)
                }
            }
            
            // Continue button
            VStack(spacing: isCompact ? 8 : 12) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onContinue()
                }) {
                    Text("Show Me How")
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
            // Opening text
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                textOpacity1 = 1
            }
            
            // Animate number count-up from 1 to 400 with boom effect
            let countDuration: Double = 0.8
            let steps = 40
            let stepDuration = countDuration / Double(steps)
            
            for i in 0...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 + stepDuration * Double(i)) {
                    let progress = Double(i) / Double(steps)
                    let easeOut = 1 - pow(1 - progress, 2)
                    numberValue = Int(400.0 * easeOut)
                }
            }
            
            // Boom animation - scale up dramatically
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.8)) {
                numberOpacity = 1
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.8)) {
                numberScale = 1.0
            }
            
            // Question text
            withAnimation(.easeOut(duration: 0.6).delay(1.8)) {
                textOpacity2 = 1
            }
            
            // Solution
            withAnimation(.easeOut(duration: 0.5).delay(2.4)) {
                textOpacity3 = 1
            }
            
            // Button
            withAnimation(.easeOut(duration: 0.4).delay(2.9)) {
                buttonOpacity = 1
            }
            
            OnboardingAnalytics.trackStepShown("pain_point")
        }
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
    
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var cardOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var confettiTrigger: Int = 0
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    private var iconSize: CGFloat { isCompact ? 80 : 100 }
    private var ringBaseSize: CGFloat { isCompact ? 90 : 120 }
    private var ringSpacing: CGFloat { isCompact ? 30 : 40 }
    
    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ConfettiView(trigger: $confettiTrigger)
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                    Spacer(minLength: isCompact ? 30 : 50)
                
                    Spacer(minLength: isCompact ? 24 : 40)
                
                // Identity text with enhanced design
                    VStack(spacing: isCompact ? 14 : 20) {
                    // Badge/medal icon
                    ZStack {
                        Circle()
                            .fill(Color.appAccent.opacity(0.15))
                                .frame(width: isCompact ? 50 : 60, height: isCompact ? 50 : 60)
                        
                        Image(systemName: "medal.fill")
                                .font(.system(size: isCompact ? 24 : 30))
                            .foregroundColor(.appAccent)
                    }
                    
                    Text("You're one of the")
                            .font(.system(size: isCompact ? 18 : 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    Text("focused ones")
                            .font(.system(size: isCompact ? 26 : 32, weight: .bold, design: .rounded))
                        .foregroundColor(.appAccent)
                        .multilineTextAlignment(.center)
                    
                    Text("Only 3% of people take action\nto fix their focus. You just did.")
                            .font(.system(size: isCompact ? 14 : 16))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .opacity(textOpacity)
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                
                    Spacer(minLength: isCompact ? 20 : 32)
                
                // Preview card
                    VStack(spacing: isCompact ? 12 : 16) {
                        HStack(spacing: isCompact ? 10 : 12) {
                        Image(systemName: "iphone")
                                .font(.system(size: isCompact ? 20 : 24))
                            .foregroundColor(.appAccent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your personalized focus system")
                                    .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Based on your answers, we'll create the perfect setup")
                                    .font(.system(size: isCompact ? 12 : 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Focus on:")
                                    .font(.system(size: isCompact ? 10 : 12))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)
                            
                            Text(quizState.forgetMost.isEmpty ? "Your goals" : quizState.forgetMost)
                                    .font(.system(size: isCompact ? 13 : 15, weight: .medium))
                                .foregroundColor(.appAccent)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Daily reminders:")
                                    .font(.system(size: isCompact ? 10 : 12))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)
                            
                            Text("\(quizState.personalizedPhoneChecks)+")
                                    .font(.system(size: isCompact ? 13 : 15, weight: .medium))
                                .foregroundColor(.appAccent)
                        }
                    }
                }
                    .padding(isCompact ? 16 : 20)
                .background(
                        RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                                RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .opacity(cardOpacity)
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                
                    Spacer(minLength: isCompact ? 20 : 30)
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
                    HStack(spacing: isCompact ? 10 : 12) {
                        Text("Show Me How It Works")
                            .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: isCompact ? 18 : 20, weight: .semibold))
                    }
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
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                textOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
                cardOpacity = 1
            }
            
            // Trigger confetti when card appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                confettiTrigger += 1
            }
            
            withAnimation(.easeOut(duration: 0.4).delay(1.1)) {
                buttonOpacity = 1
            }
            
            OnboardingAnalytics.trackStepShown("results_preview")
        }
    }
}

// MARK: - Social Proof View

struct SocialProofView: View {
    let onContinue: () -> Void
    
    @State private var statsOpacity: Double = 0
    @State private var testimonialOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var countUp: Int = 0
    
    let targetCount = 57
    
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
                        Spacer(minLength: isCompact ? 30 : 50)
                
                // Stats section
                    VStack(spacing: isCompact ? 16 : 24) {
                    // User count with animation
                        VStack(spacing: isCompact ? 8 : 12) {
                        Text("\(countUp)")
                                .font(.system(size: isCompact ? 44 : 56, weight: .heavy, design: .rounded))
                            .foregroundColor(.appAccent)
                            .monospacedDigit()
                        
                        Text("focused people already use NoteWall")
                                .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                        
                        // Authenticity message
                        Text("We're new & growing — no fake numbers here")
                                .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    
                    // Rating
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                    .font(.system(size: isCompact ? 16 : 20))
                                .foregroundColor(.yellow)
                        }
                        
                        Text("4.8")
                                .font(.system(size: isCompact ? 15 : 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.leading, 8)
                    }
                }
                .opacity(statsOpacity)
                
                    Spacer(minLength: isCompact ? 28 : 48)
                
                // Testimonial
                    VStack(spacing: isCompact ? 14 : 20) {
                    Text("\"")
                            .font(.system(size: isCompact ? 44 : 60, weight: .bold))
                        .foregroundColor(.appAccent.opacity(0.5))
                            .frame(height: isCompact ? 30 : 40)
                    
                    Group {
                        if #available(iOS 16, *) {
                            Text("I think it's cool the way it is right now, it's different. Haven't seen one like this.")
                                    .font(.system(size: isCompact ? 17 : 20, weight: .medium))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .italic()
                        } else {
                            Text("I think it's cool the way it is right now, it's different. Haven't seen one like this.")
                                    .font(.system(size: isCompact ? 17 : 20, weight: .medium))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                        HStack(spacing: isCompact ? 10 : 12) {
                        Circle()
                            .fill(Color.appAccent.opacity(0.2))
                                .frame(width: isCompact ? 34 : 40, height: isCompact ? 34 : 40)
                            .overlay(
                                Text("D")
                                        .font(.system(size: isCompact ? 15 : 18, weight: .semibold))
                                    .foregroundColor(.appAccent)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("damagad")
                                    .font(.system(size: isCompact ? 12 : 14, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Verified User")
                                    .font(.system(size: isCompact ? 10 : 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                    .padding(isCompact ? 18 : 24)
                .background(
                        RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                                RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .opacity(testimonialOpacity)
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                
                    Spacer(minLength: isCompact ? 20 : 30)
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
                    Text("Let's Set It Up")
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
            // Animate count up
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                statsOpacity = 1
            }
            
            // Count animation
            let duration: Double = 1.5
            let steps = 30
            let stepDuration = duration / Double(steps)
            
            for i in 0...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + stepDuration * Double(i)) {
                    let progress = Double(i) / Double(steps)
                    let easeOut = 1 - pow(1 - progress, 3)
                    countUp = Int(Double(targetCount) * easeOut)
                }
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
                testimonialOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(1.5)) {
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
    @State private var confettiTrigger: Int = 0
    
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
            
            // Confetti
            ConfettiView(trigger: $confettiTrigger)
            
            VStack(spacing: 0) {
                Spacer()
                
                // Hero celebration
                ZStack {
                    // Animated rings
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.appAccent.opacity(0.3 - Double(i) * 0.07), Color.green.opacity(0.2 - Double(i) * 0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 140 + CGFloat(i) * 40, height: 140 + CGFloat(i) * 40)
                    }
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent, Color.green.opacity(0.8)],
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
            
            // Confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                confettiTrigger += 1
            }
            
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
    @State private var timer: Timer?
    
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
            TimelineView(.animation) { timeline in
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
        let colors: [Color] = [.red, .blue, .green, .yellow, .pink, .purple, .orange, .cyan]
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        for _ in 0..<200 {
            let angle = Double.random(in: 0...2 * .pi)
            let speed = Double.random(in: 15...40) // Even stronger explosion
            
            let particle = Particle(
                x: screenWidth / 2,
                y: screenHeight / 2,
                angle: Double.random(in: 0...360),
                spin: Double.random(in: 0...360),
                scale: Double.random(in: 0.6...1.4),
                color: colors.randomElement() ?? .blue,
                speedX: cos(angle) * speed,
                speedY: sin(angle) * speed,
                spinSpeed: Double.random(in: -15...15)
            )
            particles.append(particle)
        }
    }
    
    private func updateParticles(in size: CGSize) {
        for i in particles.indices {
            particles[i].x += particles[i].speedX
            particles[i].y += particles[i].speedY
            particles[i].spin += particles[i].spinSpeed
            
            // Physics: Gravity and Air Resistance
            particles[i].speedX *= 0.95 // Less air resistance (travel further)
            particles[i].speedY *= 0.95 // Less air resistance
            particles[i].speedY += 0.4  // Lower gravity (float more)
            
            // Fade out smoothly
            particles[i].opacity -= Double.random(in: 0.005...0.01)
        }
        
        particles.removeAll { $0.opacity <= 0 }
    }
}


