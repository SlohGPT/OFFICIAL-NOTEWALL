import SwiftUI

/// Full-screen feedback view shown when a subscriber taps "Manage Subscription" in Settings.
/// Collects valuable satisfaction insights before allowing the user to proceed to their account.
/// Uses the same branded dark UI style as ExitFeedbackView.
struct SubscriptionFeedbackView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.dismiss) private var dismiss
    @State private var animateIn = false
    @State private var pulseGlow = false
    @State private var selectedSatisfaction: SatisfactionLevel? = nil
    @State private var selectedIssues: Set<SubscriptionIssue> = []
    @State private var additionalFeedback: String = ""
    @State private var currentStep: FeedbackStep = .satisfaction
    @State private var isSendingFeedback = false
    @State private var showThankYou = false
    @FocusState private var isTextFieldFocused: Bool
    
    // MARK: - Feedback Step
    
    enum FeedbackStep {
        case satisfaction
        case issues
        case thankYou
    }
    
    // MARK: - Satisfaction Levels
    
    enum SatisfactionLevel: String, CaseIterable, Identifiable {
        case lovingIt = "Loving it!"
        case itsOkay = "It's okay"
        case notGreat = "Not great"
        case frustrated = "Frustrated"
        
        var id: String { rawValue }
        
        var emoji: String {
            switch self {
            case .lovingIt: return "😍"
            case .itsOkay: return "🤔"
            case .notGreat: return "😕"
            case .frustrated: return "😤"
            }
        }
        
        var localizedTitle: String {
            NSLocalizedString(rawValue, comment: "")
        }
        
        var isPositive: Bool {
            self == .lovingIt
        }
    }
    
    // MARK: - Subscription Issues
    
    enum SubscriptionIssue: String, CaseIterable, Identifiable {
        case tooExpensive = "It's too expensive for me"
        case dontUseEnough = "I don't use it enough"
        case wallpapersBoring = "Wallpapers got boring"
        case notesHardToRead = "Notes are hard to read"
        case shortcutAnnoying = "Shortcut is annoying"
        case missingFeatures = "Missing features I need"
        case justTesting = "Just wanted to try it"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .tooExpensive: return "dollarsign.circle.fill"
            case .dontUseEnough: return "clock.badge.xmark.fill"
            case .wallpapersBoring: return "photo.stack.fill"
            case .notesHardToRead: return "text.magnifyingglass"
            case .shortcutAnnoying: return "link.badge.plus"
            case .missingFeatures: return "puzzlepiece.extension.fill"
            case .justTesting: return "hand.raised.fill"
            }
        }
        
        var iconColor: Color {
            switch self {
            case .tooExpensive: return .pink
            case .dontUseEnough: return .orange
            case .wallpapersBoring: return .purple
            case .notesHardToRead: return .cyan
            case .shortcutAnnoying: return .orange
            case .missingFeatures: return .blue
            case .justTesting: return .green
            }
        }
        
        var localizedTitle: String {
            NSLocalizedString(rawValue, comment: "")
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            feedbackBackground
                .ignoresSafeArea()
                .onTapGesture {
                    if isTextFieldFocused {
                        isTextFieldFocused = false
                    }
                }
            
            if showThankYou {
                thankYouView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity
                    ))
            } else {
                mainContentView
                    .transition(.opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateIn = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
    }
    
    // MARK: - Background
    
    private var feedbackBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.08),
                    Color(red: 0.01, green: 0.01, blue: 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: -120, y: -200)
                .blur(radius: 50)
                .opacity(pulseGlow ? 0.8 : 0.5)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.1), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .offset(x: 140, y: 350)
                .blur(radius: 40)
                .opacity(pulseGlow ? 0.6 : 0.4)
        }
    }
    
    // MARK: - Main Content
    
    private var mainContentView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                if currentStep == .satisfaction {
                    satisfactionStepView
                } else if currentStep == .issues {
                    issuesStepView
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isTextFieldFocused {
                    isTextFieldFocused = false
                }
            }
        }
    }
    
    // MARK: - Step 1: Satisfaction
    
    private var satisfactionStepView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)
            
            // Header icon
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "face.smiling.inverse")
                    .font(.system(size: 36))
                    .foregroundColor(.appAccent)
            }
            .opacity(animateIn ? 1 : 0)
            .scaleEffect(animateIn ? 1 : 0.8)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateIn)
            .padding(.bottom, 24)
            
            // Title
            VStack(spacing: 12) {
                Text(NSLocalizedString("Quick check-in", comment: ""))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(NSLocalizedString("How's NoteWall working for you so far?", comment: ""))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 28)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateIn)
            
            Spacer().frame(height: 40)
            
            // Satisfaction options - big tappable cards
            VStack(spacing: 14) {
                ForEach(Array(SatisfactionLevel.allCases.enumerated()), id: \.element.id) { index, level in
                    satisfactionCard(level: level)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8)
                                .delay(0.3 + Double(index) * 0.06),
                            value: animateIn
                        )
                }
            }
            .padding(.horizontal, 20)
            
            Spacer().frame(height: 32)
            
            // "Just browsing" skip link
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                openSubscriptionManagement()
                dismiss()
            }) {
                Text(NSLocalizedString("Just browsing my account", comment: ""))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.bottom, 40)
            .opacity(animateIn ? 1 : 0)
            .animation(.easeIn.delay(0.6), value: animateIn)
        }
    }
    
    // MARK: - Satisfaction Card
    
    private func satisfactionCard(level: SatisfactionLevel) -> some View {
        let isSelected = selectedSatisfaction == level
        
        return Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedSatisfaction = level
            }
            
            // Auto-advance after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if level.isPositive {
                    // Happy user → send feedback, show thank you, and suggest review
                    submitSatisfactionFeedback()
                } else {
                    // Not happy → show issues step for more details
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = .issues
                        animateIn = false
                    }
                    // Re-trigger animation for issues step
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            animateIn = true
                        }
                    }
                }
            }
        }) {
            HStack(spacing: 16) {
                Text(level.emoji)
                    .font(.system(size: 32))
                
                Text(level.localizedTitle)
                    .font(.system(size: 18, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.appAccent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.appAccent.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.appAccent.opacity(0.6) : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .shadow(
                color: isSelected ? Color.appAccent.opacity(0.3) : .clear,
                radius: isSelected ? 8 : 0,
                y: isSelected ? 4 : 0
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Step 2: Issues (for non-positive users)
    
    private var issuesStepView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)
            
            // Header
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.appAccent)
            }
            .opacity(animateIn ? 1 : 0)
            .scaleEffect(animateIn ? 1 : 0.8)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateIn)
            .padding(.bottom, 24)
            
            VStack(spacing: 12) {
                Text(NSLocalizedString("Help me make it better", comment: ""))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(NSLocalizedString("I build NoteWall solo — your honest feedback actually decides what I work on next.", comment: ""))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 28)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateIn)
            
            Spacer().frame(height: 28)
            
            // Issue selection
            VStack(alignment: .leading, spacing: 14) {
                Text(NSLocalizedString("What's not working? (pick any)", comment: ""))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 4)
                
                ForEach(Array(SubscriptionIssue.allCases.enumerated()), id: \.element.id) { index, issue in
                    issueButton(issue: issue)
                        .opacity(animateIn ? 1 : 0)
                        .offset(x: animateIn ? 0 : -20)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8)
                                .delay(0.3 + Double(index) * 0.04),
                            value: animateIn
                        )
                }
            }
            .padding(.horizontal, 20)
            
            Spacer().frame(height: 24)
            
            // Additional feedback text field
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("Anything else? (optional)", comment: ""))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 24)
                
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isTextFieldFocused ? Color.appAccent.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    if additionalFeedback.isEmpty && !isTextFieldFocused {
                        Text(NSLocalizedString("What would make you stay? Be brutally honest...", comment: ""))
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.25))
                            .padding(16)
                    }
                    
                    TextEditor(text: $additionalFeedback)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .background(Color.clear)
                        .padding(12)
                        .frame(minHeight: 90)
                        .focused($isTextFieldFocused)
                        .onAppear {
                            UITextView.appearance().backgroundColor = .clear
                        }
                }
                .frame(height: 110)
                .padding(.horizontal, 20)
            }
            .opacity(animateIn ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.4), value: animateIn)
            
            Spacer().frame(height: 32)
            
            // Submit button
            Button(action: submitDetailedFeedback) {
                HStack(spacing: 10) {
                    if isSendingFeedback {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text(isSendingFeedback
                         ? NSLocalizedString("Sending...", comment: "")
                         : NSLocalizedString("Send & Continue", comment: ""))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(!selectedIssues.isEmpty && !isSendingFeedback ? Color.appAccent : Color.gray.opacity(0.3))
                            .blur(radius: !selectedIssues.isEmpty && !isSendingFeedback ? 12 : 0)
                            .opacity(0.4)
                            .offset(y: 4)
                        
                        RoundedRectangle(cornerRadius: 16)
                            .fill(!selectedIssues.isEmpty && !isSendingFeedback ? Color.appAccent : Color.gray.opacity(0.3))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .disabled(selectedIssues.isEmpty || isSendingFeedback)
            .padding(.horizontal, 24)
            .opacity(animateIn ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: animateIn)
            
            // Skip
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                openSubscriptionManagement()
                dismiss()
            }) {
                Text(NSLocalizedString("Skip", comment: ""))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
            .opacity(animateIn ? 1 : 0)
            .animation(.easeIn.delay(0.6), value: animateIn)
        }
    }
    
    // MARK: - Issue Button
    
    private func issueButton(issue: SubscriptionIssue) -> some View {
        let isSelected = selectedIssues.contains(issue)
        
        return Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected {
                    selectedIssues.remove(issue)
                } else {
                    selectedIssues.insert(issue)
                }
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? issue.iconColor : issue.iconColor.opacity(0.2))
                        .frame(width: 46, height: 46)
                    
                    Image(systemName: issue.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? .white : issue.iconColor)
                }
                
                Text(issue.localizedTitle)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.appAccent : Color.clear)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.appAccent : Color.white.opacity(0.3), lineWidth: 2)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? issue.iconColor.opacity(0.5) : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .shadow(
                color: isSelected ? issue.iconColor.opacity(0.3) : Color.clear,
                radius: isSelected ? 8 : 0,
                y: isSelected ? 4 : 0
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Thank You View
    
    private var thankYouView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Success animation rings
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.appAccent.opacity(0.3), lineWidth: 2)
                        .frame(width: 100 + CGFloat(i) * 30, height: 100 + CGFloat(i) * 30)
                        .scaleEffect(showThankYou ? 1.2 : 1.0)
                        .opacity(showThankYou ? 0.2 : 0.6)
                        .animation(
                            Animation.easeOut(duration: 1.5).delay(Double(i) * 0.15),
                            value: showThankYou
                        )
                }
                
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.appAccent)
                }
                .scaleEffect(showThankYou ? 1 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showThankYou)
            }
            .padding(.bottom, 32)
            
            VStack(spacing: 16) {
                Text(NSLocalizedString("Thanks, that really helps!", comment: ""))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(NSLocalizedString("Every piece of feedback makes NoteWall better for everyone.", comment: ""))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.appAccent)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                
                if selectedSatisfaction?.isPositive == true {
                    Text(NSLocalizedString("If you're enjoying it, a review on the App Store would mean the world to me.", comment: ""))
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 32)
            .opacity(showThankYou ? 1 : 0)
            .offset(y: showThankYou ? 0 : 20)
            .animation(.easeOut(duration: 0.5).delay(0.3), value: showThankYou)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                if selectedSatisfaction?.isPositive == true {
                    // Happy user → suggest review
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        openAppStoreReview()
                        dismiss()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(NSLocalizedString("Leave a Review", comment: ""))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.appAccent)
                                    .blur(radius: 12)
                                    .opacity(0.4)
                                    .offset(y: 4)
                                
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.appAccent)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text(NSLocalizedString("Back to NoteWall", comment: ""))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                } else {
                    // Unhappy user → let them manage subscription
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        openSubscriptionManagement()
                        dismiss()
                    }) {
                        Text(NSLocalizedString("Manage My Account", comment: ""))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.appAccent)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text(NSLocalizedString("Actually, I'll stay", comment: ""))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.appAccent)
                    }
                }
            }
            .padding(.bottom, 40)
            .opacity(showThankYou ? 1 : 0)
            .animation(.easeIn.delay(0.5), value: showThankYou)
        }
    }
    
    // MARK: - Actions
    
    private func submitSatisfactionFeedback() {
        guard let satisfaction = selectedSatisfaction else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Log analytics
        CrashReporter.logMessage("Subscription Feedback: \(satisfaction.rawValue)", level: .info)
        CrashReporter.setCustomKey("subscription_satisfaction", value: satisfaction.rawValue)
        
        // Save locally
        saveFeedbackLocally(satisfaction: satisfaction.rawValue, issues: [], details: "")
        
        // Send via FeedbackService
        FeedbackService.shared.sendFeedback(
            reason: "[Subscription Check-in] \(satisfaction.rawValue)",
            details: "User rated their experience as: \(satisfaction.rawValue)",
            isPremium: PaywallManager.shared.isPremium
        ) { success, error in
            #if DEBUG
            if success {
                print("✅ SubscriptionFeedback: Satisfaction sent")
            } else {
                print("⚠️ SubscriptionFeedback: Failed - \(error ?? "Unknown")")
            }
            #endif
        }
        
        // Show thank you
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showThankYou = true
        }
    }
    
    private func submitDetailedFeedback() {
        guard !selectedIssues.isEmpty else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        isSendingFeedback = true
        
        let issuesText = selectedIssues.map { $0.rawValue }.joined(separator: ", ")
        let satisfactionText = selectedSatisfaction?.rawValue ?? "Unknown"
        
        // Log analytics
        CrashReporter.logMessage("Subscription Feedback: \(satisfactionText) - Issues: \(issuesText)", level: .info)
        CrashReporter.setCustomKey("subscription_satisfaction", value: satisfactionText)
        CrashReporter.setCustomKey("subscription_issues", value: issuesText)
        if !additionalFeedback.isEmpty {
            CrashReporter.setCustomKey("subscription_feedback_details", value: additionalFeedback)
        }
        
        // Save locally
        saveFeedbackLocally(
            satisfaction: satisfactionText,
            issues: Array(selectedIssues.map { $0.rawValue }),
            details: additionalFeedback
        )
        
        // Build detailed feedback message
        var detailsMessage = "Satisfaction: \(satisfactionText)\nIssues: \(issuesText)"
        if !additionalFeedback.isEmpty {
            detailsMessage += "\nAdditional: \(additionalFeedback)"
        }
        
        FeedbackService.shared.sendFeedback(
            reason: "[Subscription Check-in] \(satisfactionText) — \(issuesText)",
            details: detailsMessage,
            isPremium: PaywallManager.shared.isPremium
        ) { success, error in
            DispatchQueue.main.async {
                #if DEBUG
                if success {
                    print("✅ SubscriptionFeedback: Detailed feedback sent")
                } else {
                    print("⚠️ SubscriptionFeedback: Failed - \(error ?? "Unknown")")
                }
                #endif
                isSendingFeedback = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showThankYou = true
                }
            }
        }
    }
    
    private func saveFeedbackLocally(satisfaction: String, issues: [String], details: String) {
        let feedback: [String: Any] = [
            "type": "subscription_checkin",
            "satisfaction": satisfaction,
            "issues": issues,
            "details": details,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "isPremium": PaywallManager.shared.isPremium
        ]
        
        var history = UserDefaults.standard.array(forKey: "subscription_feedback_history") as? [[String: Any]] ?? []
        history.append(feedback)
        UserDefaults.standard.set(history, forKey: "subscription_feedback_history")
        
        #if DEBUG
        print("💾 SubscriptionFeedback: Saved locally — \(satisfaction)")
        #endif
    }
    
    private func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openAppStoreReview() {
        let appID = "6755601996"
        let appStoreURLString = "itms-apps://itunes.apple.com/app/id\(appID)?action=write-review"
        if let url = URL(string: appStoreURLString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return
        }
        if let webURL = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") {
            UIApplication.shared.open(webURL)
        }
    }
}

// MARK: - Preview

#Preview {
    SubscriptionFeedbackView()
        .preferredColorScheme(.dark)
}
