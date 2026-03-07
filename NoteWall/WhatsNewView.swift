import SwiftUI
import StoreKit

/// Pop-up view shown to existing users (installed before Feb 9th, 2026) after an app update.
/// Offers the option to migrate from the old shortcut (home + lock screen) to the new one (lock screen only).
/// Also highlights what's new and encourages feedback/ratings.
/// Design matches the onboarding flow brand identity with rich animations.
struct WhatsNewView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    /// Callback when user chooses to migrate to the new pipeline
    var onStartMigration: (() -> Void)? = nil
    @State private var headerOpacity: Double = 0
    @State private var cardsOpacity: Double = 0
    @State private var feedbackOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var confettiTrigger = 0
    @State private var showFeatureRequestAlert = false
    @State private var featureRequestText = ""
    
    // Enhanced animation states
    @State private var iconPulse: Bool = false
    @State private var iconRotation: Double = 0
    @State private var shimmerOffset: CGFloat = -200
    @State private var cardSlideOffsets: [CGFloat] = [0, 0, 0]
    @State private var glowOpacity: Double = 0.3
    @State private var buttonShimmerX: CGFloat = -200
    @State private var badgeScale: CGFloat = 0.5
    @State private var shieldPulse: Bool = false
    
    // Adaptive layout
    private var isCompact: Bool {
        return ScreenDimensions.height < 750
    }
    
    // MARK: - Current Version Info
    
    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.5.3"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // MARK: - What's New Content
    
    struct UpdateItem: Identifiable {
        let id = UUID()
        let icon: String
        let iconColor: Color
        let title: String
        let description: String
    }
    
    // MARK: - Update Items
    
    private var updateItems: [UpdateItem] {
        [
            UpdateItem(
                icon: "text.badge.checkmark",
                iconColor: Color("AppAccent"),
                title: NSLocalizedString("Individual Note Highlights", comment: ""),
                description: NSLocalizedString("Highlight backgrounds now wrap each note separately instead of one big block. Looks way cleaner.", comment: "")
            ),
            UpdateItem(
                icon: "paintbrush.fill",
                iconColor: Color("AppAccent").opacity(0.8),
                title: NSLocalizedString("Better Text Styling", comment: ""),
                description: NSLocalizedString("White and black box styles sit neatly behind each note with proper spacing and rounded corners.", comment: "")
            ),
            UpdateItem(
                icon: "bolt.circle.fill",
                iconColor: Color("AppAccent").opacity(0.6),
                title: NSLocalizedString("Smoother Experience", comment: ""),
                description: NSLocalizedString("Small fixes and polish across the app for a more reliable daily workflow.", comment: "")
            )
        ]
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background matching onboarding style
            backgroundView
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: { closePopup() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                }
                .padding(.horizontal, isCompact ? 20 : 24)
                .padding(.top, isCompact ? 12 : 16)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: isCompact ? 28 : 36) {
                        Spacer(minLength: isCompact ? 4 : 8)
                        
                        // Header section
                        headerView
                            .opacity(headerOpacity)
                        
                        // Update items
                        updateItemsView
                            .opacity(cardsOpacity)
                        
                        // Subscription reassurance banner
                        subscriptionReassuranceView
                            .opacity(feedbackOpacity)
                        
                        Spacer(minLength: isCompact ? 60 : 80)
                    }
                }
                
                // Action buttons
                actionButtonsView
                    .opacity(buttonOpacity)
            }
            
            // Confetti overlay
            ConfettiView(trigger: $confettiTrigger)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear {
            // Track screen view
            AnalyticsService.shared.trackScreenView(
                screenName: "migration_2_whats_new",
                screenClass: "WhatsNewView"
            )
            
            // Staggered animations matching onboarding style
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                headerOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                cardsOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                feedbackOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
                buttonOpacity = 1
            }
            
            // Trigger confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                confettiTrigger += 1
            }
        }
        .alert("Want a new feature? 💡", isPresented: $showFeatureRequestAlert) {
            TextField("Describe your feature idea...", text: $featureRequestText)
            Button("Send") {
                sendFeatureRequest()
            }
            Button("No Thanks", role: .cancel) {
                finalDismiss()
            }
        } message: {
            Text("Let us know what feature you'd like and we'll build it!")
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            // Dark gradient background (matching onboarding)
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.08), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Animated radial glow that pulses
            RadialGradient(
                colors: [Color("AppAccent").opacity(glowOpacity * 0.15), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.8
                }
            }
            
            // Floating ambient particles (brand-colored)
            WhatsNewParticlesView()
                .opacity(0.5)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: isCompact ? 16 : 20) {
            // Badge (matching onboarding style) with spring-in animation
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: isCompact ? 12 : 14))
                    .foregroundColor(Color("AppAccent"))
                    .symbolEffect(.pulse, options: .repeating, value: headerOpacity)
                
                Text("What's New")
                    .font(.system(size: isCompact ? 12 : 13, weight: .medium))
                    .foregroundColor(Color("AppAccent"))
            }
            .padding(.horizontal, isCompact ? 12 : 16)
            .padding(.vertical, isCompact ? 6 : 8)
            .background(
                Capsule()
                    .fill(Color("AppAccent").opacity(0.1))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color("AppAccent").opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(badgeScale)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.15)) {
                    badgeScale = 1.0
                }
            }
            
            // Main icon with pulsing glow ring and rotation
            ZStack {
                // Outer pulsing glow ring
                Circle()
                    .fill(Color("AppAccent").opacity(0.08))
                    .frame(width: isCompact ? 100 : 120, height: isCompact ? 100 : 120)
                    .scaleEffect(iconPulse ? 1.15 : 0.95)
                    .opacity(iconPulse ? 0.0 : 0.6)
                
                Circle()
                    .fill(Color("AppAccent").opacity(0.12))
                    .frame(width: isCompact ? 70 : 85, height: isCompact ? 70 : 85)
                
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: isCompact ? 32 : 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color("AppAccent"), Color("AppAccent").opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(iconRotation))
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    iconPulse = true
                }
                withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                    iconRotation = 360
                }
            }
            
            // Title and version
            VStack(spacing: isCompact ? 8 : 10) {
                Text(NSLocalizedString("What’s New in NoteWall", comment: ""))
                    .font(.system(size: isCompact ? 24 : 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(String(format: NSLocalizedString("Version %@", comment: ""), currentVersion))
                    .font(.system(size: isCompact ? 14 : 16))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, isCompact ? 20 : 24)
    }
    
    // MARK: - Update Items
    
    private var updateItemsView: some View {
        VStack(spacing: isCompact ? 12 : 14) {
            ForEach(Array(updateItems.enumerated()), id: \.element.id) { index, item in
                updateItemCard(item, index: index)
                    .offset(x: cardSlideOffsets.indices.contains(index) ? cardSlideOffsets[index] : 0)
            }
        }
        .padding(.horizontal, isCompact ? 20 : 24)
        .onAppear {
            // Staggered slide-in from right for each card
            for i in 0..<cardSlideOffsets.count {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.35 + Double(i) * 0.12)) {
                    cardSlideOffsets[i] = 0
                }
            }
        }
    }
    
    private func updateItemCard(_ item: UpdateItem, index: Int) -> some View {
        HStack(spacing: isCompact ? 12 : 14) {
            // Icon with subtle accent glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [item.iconColor.opacity(0.25), item.iconColor.opacity(0.05)],
                            center: .center,
                            startRadius: 0,
                            endRadius: isCompact ? 22 : 26
                        )
                    )
                    .frame(width: isCompact ? 44 : 50, height: isCompact ? 44 : 50)
                
                Image(systemName: item.icon)
                    .font(.system(size: isCompact ? 18 : 20, weight: .medium))
                    .foregroundColor(item.iconColor)
                    .shadow(color: item.iconColor.opacity(0.4), radius: 6, x: 0, y: 2)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: isCompact ? 15 : 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(item.description)
                    .font(.system(size: isCompact ? 13 : 14))
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(isCompact ? 14 : 16)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 14 : 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: isCompact ? 14 : 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color("AppAccent").opacity(0.15), Color.clear, Color("AppAccent").opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        )
    }
    
    // MARK: - Subscription Reassurance
    
    private var subscriptionReassuranceView: some View {
        VStack(spacing: isCompact ? 16 : 20) {
            // Animated gradient divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color("AppAccent").opacity(0.3), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal, isCompact ? 40 : 60)
            
            // Reassurance card with pulsing shield
            VStack(spacing: isCompact ? 12 : 14) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: isCompact ? 16 : 18))
                        .foregroundColor(.green)
                        .shadow(color: .green.opacity(0.4), radius: shieldPulse ? 8 : 3, x: 0, y: 0)
                        .scaleEffect(shieldPulse ? 1.1 : 1.0)
                    
                    Text(NSLocalizedString("Thanks for Supporting NoteWall+", comment: ""))
                        .font(.system(size: isCompact ? 17 : 19, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Text(NSLocalizedString("You’re getting improvements first. Keep sharing feedback so we can make every update even better.", comment: ""))
                    .font(.system(size: isCompact ? 14 : 15))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(isCompact ? 16 : 20)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 16 : 18, style: .continuous)
                    .fill(Color.green.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: isCompact ? 16 : 18, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.25), Color.green.opacity(0.1), Color.green.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    shieldPulse = true
                }
            }
        }
        .padding(.horizontal, isCompact ? 20 : 24)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsView: some View {
        VStack(spacing: isCompact ? 12 : 14) {
            // Primary: Continue
            Button(action: { continueToApp() }) {
                ZStack {
                    HStack(spacing: isCompact ? 8 : 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: isCompact ? 16 : 18, weight: .semibold))
                        Text("Continue")
                            .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                    }
                    
                    // Shimmer sweep overlay
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.15), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 80)
                    .offset(x: buttonShimmerX)
                    .mask(
                        RoundedRectangle(cornerRadius: isCompact ? 14 : 20, style: .continuous)
                    )
                }
                .frame(height: isCompact ? 50 : 56)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
            .onAppear {
                // Repeating shimmer sweep across the button
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false).delay(1.0)) {
                    buttonShimmerX = 200
                }
            }
            
            HStack(spacing: 12) {
                // Secondary: Rate App
                Button(action: { requestReview() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                        Text("Rate App")
                            .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                    }
                    .foregroundColor(Color("AppAccent"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isCompact ? 10 : 12)
                    .background(Color("AppAccent").opacity(0.1))
                    .cornerRadius(12)
                }

                Button(action: {
                    showFeatureRequestAlert = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 14))
                        Text(NSLocalizedString("Feedback", comment: ""))
                            .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                    }
                    .foregroundColor(Color("AppAccent"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isCompact ? 10 : 12)
                    .background(Color("AppAccent").opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, isCompact ? 20 : 24)
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
    }
    
    // MARK: - Actions
    
    private func continueToApp() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Track continue action
        AnalyticsService.shared.logEvent(
            .custom(
                name: "whats_new_continue_tapped",
                parameters: [
                    "source": "whats_new_modal",
                    "version": currentVersion
                ]
            )
        )
        
        // Mark What's New as shown
        WhatsNewManager.shared.markAsShown()

        // Dismiss
        withAnimation(.easeInOut(duration: 0.3)) {
            headerOpacity = 0
            cardsOpacity = 0
            feedbackOpacity = 0
            buttonOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
            dismiss()
        }
    }
    
    private func keepCurrentPipeline() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Track user's choice to keep old pipeline
        AnalyticsService.shared.logEvent(
            .custom(
                name: "pipeline_migration_declined",
                parameters: [
                    "source": "whats_new_popup",
                    "version": currentVersion
                ]
            )
        )
        
        // Mark as shown so they won't see this again
        WhatsNewManager.shared.markAsShown()
        
        closePopup()
    }
    
    private func requestReview() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Open App Store review page directly
        let appID = "6755601996"
        
        if let appStoreURL = URL(string: "itms-apps://itunes.apple.com/app/id\(appID)?action=write-review"),
           UIApplication.shared.canOpenURL(appStoreURL) {
            UIApplication.shared.open(appStoreURL, options: [:], completionHandler: nil)
        } 
        else if let webURL = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") {
            UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
        }
        
        // Mark as shown and close
        WhatsNewManager.shared.markAsShown()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            closePopup()
        }
    }
    
    private func closePopup() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Track that user dismissed without migrating
        AnalyticsService.shared.logEvent(
            .custom(
                name: "pipeline_migration_declined",
                parameters: [
                    "source": "whats_new_x_button",
                    "version": currentVersion
                ]
            )
        )
        
        // Mark as shown
        WhatsNewManager.shared.markAsShown()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            headerOpacity = 0
            cardsOpacity = 0
            feedbackOpacity = 0
            buttonOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            finalDismiss()
        }
    }
    
    private func sendFeatureRequest() {
        guard !featureRequestText.isEmpty else {
            finalDismiss()
            return
        }
        
        FeedbackService.shared.sendFeedback(
            reason: "Feature Request",
            details: featureRequestText,
            isPremium: PaywallManager.shared.isPremium
        ) { success, error in
            #if DEBUG
            if success {
                print("✅ Feature request sent successfully")
            } else {
                print("❌ Feature request failed: \(error ?? "Unknown")")
            }
            #endif
        }
        
        finalDismiss()
    }
    
    private func finalDismiss() {
        isPresented = false
        dismiss()
    }
}

// MARK: - What's New Manager
// Note: ConfettiView is defined in OnboardingEnhanced.swift and reused here

class WhatsNewManager: ObservableObject {
    static let shared = WhatsNewManager()
    
    @Published var shouldShowWhatsNew = false
    
    private let lastShownVersionKey = "WhatsNewLastShownVersion"
    private let hasCompletedSetupKey = "hasCompletedSetup"
    /// Key for the premium What's New popup (v1.5.4)
    private let whatsNewHasBeenShownKey = "WhatsNewShown_Premium_v1.5.4"
    
    // 🚨 DEBUG MODE: Set to true to FORCE show the popup for testing
    // ⚠️ MUST be set to false before production release!
    private let debugForceShow = false
    
    private init() {}
    
    /// Current app version
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// Last version the What's New was shown for
    var lastShownVersion: String? {
        UserDefaults.standard.string(forKey: lastShownVersionKey)
    }
    
    /// Check if user has completed initial setup (existing user)
    var hasCompletedSetup: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedSetupKey)
    }
    
    /// Check if What's New popup has EVER been shown to this user
    /// Once true, popup NEVER shows again
    var hasBeenShownOnce: Bool {
        UserDefaults.standard.bool(forKey: whatsNewHasBeenShownKey)
    }
    
    /// Whether the user is premium
    var isPremiumUser: Bool {
        PaywallManager.shared.isPremium
    }
    
    /// Determines if What's New should be shown
    /// - Only shows ONCE EVER
    /// - Only shows to users who have completed setup
    /// - Only shows to premium users
    func checkShouldShow() -> Bool {
        #if DEBUG
        // In debug mode, force show if flag is enabled
        if debugForceShow {
            print("🚨 WhatsNewManager: DEBUG MODE - Forcing popup to show for testing")
            return true
        }
        #endif
        
        // CRITICAL: If already shown once, NEVER show again
        if hasBeenShownOnce {
            #if DEBUG
            print("🎉 WhatsNewManager: Already shown once before - NEVER showing again")
            #endif
            return false
        }
        
        // User must have completed setup
        guard hasCompletedSetup else {
            #if DEBUG
            print("🎉 WhatsNewManager: User hasn't completed setup - skipping What's New")
            #endif
            return false
        }

        // Only show to premium users
        guard isPremiumUser else {
            #if DEBUG
            print("🎉 WhatsNewManager: User is not premium - skipping What's New")
            #endif
            return false
        }

        #if DEBUG
        print("🎉 WhatsNewManager: Premium user eligible - showing What's New")
        print("   Version: \(currentVersion), Setup complete: \(hasCompletedSetup), Premium: true")
        #endif
        return true
    }
    
    /// Mark the What's New as shown - this permanently prevents it from showing again
    func markAsShown() {
        // Set the permanent flag - popup will NEVER show again after this
        UserDefaults.standard.set(true, forKey: whatsNewHasBeenShownKey)
        UserDefaults.standard.set(currentVersion, forKey: lastShownVersionKey)
        shouldShowWhatsNew = false
        
        #if DEBUG
        print("🎉 WhatsNewManager: Marked as shown PERMANENTLY - will never show again")
        #endif
    }
    
    /// Reset for testing (call this in DEBUG to see popup again next launch)
    func resetForTesting() {
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: lastShownVersionKey)
        UserDefaults.standard.removeObject(forKey: whatsNewHasBeenShownKey)
        print("🎉 WhatsNewManager: Reset for testing - popup will show on next launch")
        #endif
    }
}

// MARK: - Preview

#Preview {
    WhatsNewView(isPresented: .constant(true))
}

// MARK: - Floating Ambient Particles for WhatsNew

private struct WhatsNewParticleData: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var speed: Double
    var drift: CGFloat
}

struct WhatsNewParticlesView: View {
    @State private var particles: [WhatsNewParticleData] = []
    @State private var animationPhase: Double = 0
    
    private let particleCount = 18
    
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0/30.0)) { timeline in
                Canvas { context, size in
                    for particle in particles {
                        let adjustedY = particle.y + CGFloat(animationPhase * particle.speed * 30)
                        let loopedY = adjustedY.truncatingRemainder(dividingBy: size.height + 40) - 20
                        let phaseFloat = CGFloat(animationPhase * 0.5)
                        let sineVal: CGFloat = CoreGraphics.sin(phaseFloat + particle.drift)
                        let adjustedX = particle.x + sineVal * 20
                        
                        let rect = CGRect(
                            x: adjustedX - particle.size / 2,
                            y: loopedY,
                            width: particle.size,
                            height: particle.size
                        )
                        
                        let opacityPhase: CGFloat = CoreGraphics.sin(CGFloat(animationPhase) + particle.drift)
                        context.opacity = particle.opacity * (0.6 + 0.4 * Double(opacityPhase))
                        context.fill(Circle().path(in: rect), with: .color(Color("AppAccent")))
                    }
                }
                .onChange(of: timeline.date) { _ in
                    animationPhase += 0.016
                }
            }
            .onAppear {
                particles = (0..<particleCount).map { _ in
                    WhatsNewParticleData(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height),
                        size: CGFloat.random(in: 2...5),
                        opacity: Double.random(in: 0.1...0.35),
                        speed: Double.random(in: 0.2...0.8),
                        drift: CGFloat.random(in: 0...(.pi * 2))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
