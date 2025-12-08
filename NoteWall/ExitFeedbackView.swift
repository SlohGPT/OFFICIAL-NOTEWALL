import SwiftUI

/// Modal view for collecting user feedback before app deletion (exit-intercept strategy).
/// Uses personal, authentic, founder-driven tone to build trust and gather insights.
struct ExitFeedbackView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReasons: Set<FeedbackReason> = []
    @State private var additionalDetails: String = ""
    @State private var animateIn = false
    @State private var showThankYou = false
    @State private var showTroubleshooting = false
    @State private var shouldRestartOnboarding = false
    @State private var pulseGlow = false
    @State private var isSendingFeedback = false
    @FocusState private var isTextFieldFocused: Bool
    
    // MARK: - Feedback Reasons
    
    enum FeedbackReason: String, CaseIterable, Identifiable {
        // Orange group - Technical issues
        case shortcutConfusing = "Shortcut setup was confusing"
        case wallpaperDidntGenerate = "Wallpaper didn't generate properly"
        
        // Purple group - UX/Usability issues
        case tooComplicated = "This seemed too complicated"
        case notesTooSmall = "Notes were too small to read"
        
        // Pink group - Pricing issues
        case paywallTooSoon = "Paywall after 3 uses felt too early"
        case tooExpensive = "Too expensive for what it does"
        
        // Blue group - Other
        case justTesting = "Just testing it out"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .shortcutConfusing:
                return "link.badge.plus"
            case .wallpaperDidntGenerate:
                return "photo.badge.plus"
            case .tooComplicated:
                return "gearshape.2.fill"
            case .paywallTooSoon:
                return "creditcard.fill"
            case .notesTooSmall:
                return "text.magnifyingglass"
            case .justTesting:
                return "hand.raised.fill"
            case .tooExpensive:
                return "dollarsign.circle.fill"
            }
        }
        
        var iconColor: Color {
            switch self {
            case .shortcutConfusing, .wallpaperDidntGenerate:
                return Color.orange
            case .tooComplicated, .notesTooSmall:
                return Color.purple
            case .paywallTooSoon, .tooExpensive:
                return Color.pink
            case .justTesting:
                return Color.blue
            }
        }
        
        /// Returns true if this reason should trigger the auto-fix offer
        var shouldShowAutoFix: Bool {
            switch self {
            case .shortcutConfusing, .wallpaperDidntGenerate:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            feedbackBackground
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss keyboard when tapping on background
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
                feedbackFormView
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showTroubleshooting) {
            TroubleshootingView(
                isPresented: $showTroubleshooting,
                shouldRestartOnboarding: $shouldRestartOnboarding
            )
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
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.08),
                    Color(red: 0.01, green: 0.01, blue: 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Accent glow orbs
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
    
    // MARK: - Feedback Form View
    
    private var feedbackFormView: some View {
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
                
                Spacer().frame(height: 20)
                
                // Header icon
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
                
                // Title and personal message
                VStack(spacing: 12) {
                    Text("Before You Go...")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 8) {
                        Text("Hey! I built NoteWall myself and I'm genuinely trying to make it better every day.")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.appAccent)
                        
                        Text("If something didn't work or felt off, I really want to know. Your feedback directly shapes what I fix next.")
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("What went wrong?")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.top, 4)
                    }
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                }
                .padding(.horizontal, 28)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateIn)
                
                Spacer().frame(height: 36)
                
                // Feedback reasons
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select all that apply:")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                    
                    ForEach(Array(FeedbackReason.allCases.enumerated()), id: \.element) { index, reason in
                        feedbackReasonButton(reason: reason)
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
                
                // Additional details text field (always visible)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Want to explain more? (optional)")
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
                        
                        TextEditor(text: $additionalDetails)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .background(Color.clear)
                            .padding(12)
                            .frame(minHeight: 100)
                            .focused($isTextFieldFocused)
                            .onAppear {
                                // Hide TextEditor background for iOS 15+ compatibility
                                UITextView.appearance().backgroundColor = .clear
                            }
                    }
                    .frame(height: 120)
                    .padding(.horizontal, 20)
                }
                .opacity(animateIn ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.4), value: animateIn)
                
                // Auto-fix offer (shown when technical issues are selected)
                if shouldShowAutoFixOffer {
                    Spacer().frame(height: 24)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 20))
                                .foregroundColor(.appAccent)
                            
                            Text("Want me to help fix this in 30 seconds?")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            showTroubleshooting = true
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Try Auto-Fix")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.appAccent)
                                        .blur(radius: 8)
                                        .opacity(0.4)
                                        .offset(y: 3)
                                    
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.appAccent)
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appAccent.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.appAccent.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: shouldShowAutoFixOffer)
                }
                
                Spacer().frame(height: 32)
                
                // Submit button (only enabled when at least one reason is selected)
                Button(action: submitFeedback) {
                    HStack(spacing: 10) {
                        if isSendingFeedback {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .bold))
                        }
                        Text(isSendingFeedback ? "Sending..." : "Send Feedback")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(!selectedReasons.isEmpty && !isSendingFeedback ? Color.appAccent : Color.gray.opacity(0.3))
                                .blur(radius: !selectedReasons.isEmpty && !isSendingFeedback ? 12 : 0)
                                .opacity(0.4)
                                .offset(y: 4)
                            
                            RoundedRectangle(cornerRadius: 16)
                                .fill(!selectedReasons.isEmpty && !isSendingFeedback ? Color.appAccent : Color.gray.opacity(0.3))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .disabled(selectedReasons.isEmpty || isSendingFeedback)
                .padding(.horizontal, 24)
                .opacity(animateIn ? 1 : 0)
                .scaleEffect(animateIn ? 1 : 0.95)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: animateIn)
                
                // Skip button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    dismiss()
                }) {
                    Text("Skip for now")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeIn.delay(0.6), value: animateIn)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Dismiss keyboard when tapping anywhere in the content
                // Buttons will still work because they have higher gesture priority
                if isTextFieldFocused {
                    isTextFieldFocused = false
                }
            }
        }
    }
    
    // MARK: - Feedback Reason Button
    
    private func feedbackReasonButton(reason: FeedbackReason) -> some View {
        let isSelected = selectedReasons.contains(reason)
        
        return Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected {
                    selectedReasons.remove(reason)
                } else {
                    selectedReasons.insert(reason)
                }
            }
        }) {
            HStack(spacing: 16) {
                // Icon with colored background
                ZStack {
                    Circle()
                        .fill(isSelected ? reason.iconColor : reason.iconColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: reason.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? .white : reason.iconColor)
                }
                
                // Text
                Text(reason.rawValue)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Checkmark indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.appAccent : Color.clear)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.appAccent : Color.white.opacity(0.3), lineWidth: 2)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? reason.iconColor.opacity(0.5) : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .shadow(
                color: isSelected ? reason.iconColor.opacity(0.3) : Color.clear,
                radius: isSelected ? 8 : 0,
                x: 0,
                y: isSelected ? 4 : 0
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Computed Properties
    
    private var shouldShowAutoFixOffer: Bool {
        selectedReasons.contains { $0.shouldShowAutoFix }
    }
    
    // MARK: - Thank You View
    
    private var thankYouView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Success icon with animation
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.appAccent.opacity(0.3), lineWidth: 2)
                        .frame(width: 100 + CGFloat(i) * 30, height: 100 + CGFloat(i) * 30)
                        .scaleEffect(animateIn ? 1.2 : 1.0)
                        .opacity(animateIn ? 0.2 : 0.6)
                        .animation(
                            Animation.easeOut(duration: 1.5)
                                .delay(Double(i) * 0.15),
                            value: animateIn
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
                .scaleEffect(animateIn ? 1 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: animateIn)
            }
            .padding(.bottom, 32)
            
            // Thank you message
            VStack(spacing: 16) {
                Text("Thank You! 🙏")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("This helps more than you know.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.appAccent)
                
                Text("If you change your mind, we'd love to have you back.")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 20)
            .animation(.easeOut(duration: 0.5).delay(0.3), value: animateIn)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                // Auto-fix button (if technical issues were selected)
                if shouldShowAutoFixOffer {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        showTroubleshooting = true
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 16, weight: .bold))
                            Text("Try Auto-Fix Now")
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
                }
                
                // Done button
                Button(action: {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    dismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appAccent)
                        )
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
            .opacity(animateIn ? 1 : 0)
            .animation(.easeIn.delay(0.5), value: animateIn)
        }
    }
    
    // MARK: - Actions
    
    private func submitFeedback() {
        guard !selectedReasons.isEmpty else { return }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Set sending state
        isSendingFeedback = true
        
        // Combine all selected reasons into a single string
        let reasonsText = selectedReasons.map { $0.rawValue }.joined(separator: ", ")
        
        // Log feedback to crash reporter for analytics
        CrashReporter.logMessage("Exit Feedback: \(reasonsText)", level: .info)
        CrashReporter.setCustomKey("exit_feedback_reasons", value: reasonsText)
        CrashReporter.setCustomKey("exit_feedback_count", value: String(selectedReasons.count))
        
        if !additionalDetails.isEmpty {
            CrashReporter.setCustomKey("exit_feedback_details", value: additionalDetails)
        }
        
        // Save locally as backup (always)
        saveFeedbackLocally(reasons: selectedReasons, details: additionalDetails)
        
        // Send feedback automatically in background (invisible to user)
        FeedbackService.shared.sendFeedback(
            reason: reasonsText,
            details: additionalDetails,
            isPremium: PaywallManager.shared.isPremium
        ) { [self] success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ ExitFeedbackView: Feedback sent automatically")
                } else {
                    print("⚠️ ExitFeedbackView: Failed to send feedback: \(error ?? "Unknown error")")
                    // Still show thank you (feedback is saved locally as backup)
                }
                // Always show thank you screen, whether sending succeeded or not
                completeFeedbackSubmission()
            }
        }
    }
    
    private func completeFeedbackSubmission() {
        isSendingFeedback = false
        
        // Show thank you view
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showThankYou = true
        }
    }
    
    private func saveFeedbackLocally(reasons: Set<FeedbackReason>, details: String) {
        // Create feedback entry (backup storage)
        let reasonsText = reasons.map { $0.rawValue }.joined(separator: ", ")
        let feedback: [String: Any] = [
            "reasons": reasonsText,
            "reasons_array": Array(reasons.map { $0.rawValue }),
            "details": details,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "isPremium": PaywallManager.shared.isPremium
        ]
        
        // Get existing feedback array
        var feedbackHistory = UserDefaults.standard.array(forKey: "exit_feedback_history") as? [[String: Any]] ?? []
        
        // Append new feedback
        feedbackHistory.append(feedback)
        
        // Save back to UserDefaults
        UserDefaults.standard.set(feedbackHistory, forKey: "exit_feedback_history")
        UserDefaults.standard.synchronize()
        
        print("💾 ExitFeedbackView: Saved feedback locally (backup) - \(reasonsText)")
    }
}

// MARK: - Preview

#Preview {
    ExitFeedbackView()
        .preferredColorScheme(.dark)
}

