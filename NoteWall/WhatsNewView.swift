import SwiftUI
import StoreKit

/// Pop-up view shown to existing users after an app update.
/// Highlights what's new and encourages feedback/ratings.
/// Design matches the onboarding flow brand identity.
struct WhatsNewView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    @State private var headerOpacity: Double = 0
    @State private var cardsOpacity: Double = 0
    @State private var feedbackOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var confettiTrigger = 0
    @State private var showFeatureRequestAlert = false
    @State private var featureRequestText = ""
    
    // Adaptive layout
    private var isCompact: Bool {
        return ScreenDimensions.height < 750
    }
    
    // MARK: - Current Version Info
    
    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.1"
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
                icon: "textformat.size",
                iconColor: Color("AppAccent"),
                title: "Custom Text Styling",
                description: "You can now change the font, color, size, and alignment of your notes directly in Settings!"
            ),
            UpdateItem(
                icon: "paintbrush.fill",
                iconColor: Color("AppAccent").opacity(0.8),
                title: "Highlight Modes",
                description: "Add emphasis with outline, white, or black highlight backgrounds to make your notes pop."
            ),
            UpdateItem(
                icon: "heart.fill",
                iconColor: Color("AppAccent").opacity(0.6),
                title: "Thank You!",
                description: "Thanks for supporting independent development. More features coming soon!"
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
                        
                        // Feedback request
                        feedbackRequestView
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
                screenName: "whats_new_popup",
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
            
            // Subtle radial glow
            RadialGradient(
                colors: [Color("AppAccent").opacity(0.06), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 350
            )
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: isCompact ? 16 : 20) {
            // Badge (matching onboarding style)
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: isCompact ? 12 : 14))
                    .foregroundColor(Color("AppAccent"))
                
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
            
            // Main icon
            ZStack {
                Circle()
                    .fill(Color("AppAccent").opacity(0.12))
                    .frame(width: isCompact ? 70 : 85, height: isCompact ? 70 : 85)
                
                Image(systemName: "party.popper.fill")
                    .font(.system(size: isCompact ? 32 : 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color("AppAccent"), Color("AppAccent").opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Title and version
            VStack(spacing: isCompact ? 8 : 10) {
                Text("We Just Updated!")
                    .font(.system(size: isCompact ? 24 : 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Version \(currentVersion)")
                    .font(.system(size: isCompact ? 14 : 16))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, isCompact ? 20 : 24)
    }
    
    // MARK: - Update Items
    
    private var updateItemsView: some View {
        VStack(spacing: isCompact ? 12 : 14) {
            ForEach(updateItems) { item in
                updateItemCard(item)
            }
        }
        .padding(.horizontal, isCompact ? 20 : 24)
    }
    
    private func updateItemCard(_ item: UpdateItem) -> some View {
        HStack(spacing: isCompact ? 12 : 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color("AppAccent").opacity(0.15))
                    .frame(width: isCompact ? 40 : 46, height: isCompact ? 40 : 46)
                
                Image(systemName: item.icon)
                    .font(.system(size: isCompact ? 18 : 20, weight: .medium))
                    .foregroundColor(item.iconColor)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: isCompact ? 15 : 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(item.description)
                    .font(.system(size: isCompact ? 13 : 14))
                    .foregroundColor(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(isCompact ? 14 : 16)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 14 : 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
    
    // MARK: - Feedback Request
    
    private var feedbackRequestView: some View {
        VStack(spacing: isCompact ? 16 : 20) {
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, isCompact ? 40 : 60)
            
            // Message card
            VStack(spacing: isCompact ? 12 : 14) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: isCompact ? 16 : 18))
                        .foregroundColor(Color("AppAccent"))
                    
                    Text("Love NoteWall?")
                        .font(.system(size: isCompact ? 17 : 19, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Text("It's just me - Karchi, working hard to make NoteWall the best it can be. Your feedback means everything to me!")
                    .font(.system(size: isCompact ? 14 : 15))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(isCompact ? 16 : 20)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 16 : 18, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: isCompact ? 16 : 18, style: .continuous)
                            .strokeBorder(Color("AppAccent").opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, isCompact ? 20 : 24)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsView: some View {
        VStack(spacing: isCompact ? 12 : 14) {
            // Primary: Rate on App Store
            Button(action: { requestReview() }) {
                HStack(spacing: isCompact ? 8 : 10) {
                    Image(systemName: "star.fill")
                        .font(.system(size: isCompact ? 16 : 18, weight: .semibold))
                    Text("Rate on App Store")
                        .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                }
                .frame(height: isCompact ? 50 : 56)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
            
            HStack(spacing: 12) {
                // Secondary: Close
                Button(action: { closePopup() }) {
                    Text("Close")
                        .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isCompact ? 10 : 12)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                }
                
                // Secondary: Contact Us
                Button(action: { contactSupport() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 14))
                        Text("Write Us")
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
    
    private func contactSupport() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Direct email link
        let email = "iosnotewall@gmail.com"
        let subject = "NoteWall Feedback (v\(currentVersion))"
        let body = "\n\n\n---\nApp Version: \(currentVersion)\nBuild: \(buildNumber)"
        
        let urlString = "mailto:\(email)?subject=\(subject)&body=\(body)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: urlString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                // Feature request fallback alert if mail app not configured
                showFeatureRequestAlert = true
            }
        }
    }
    
    private func requestReview() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Open App Store review page directly
        let appID = "6755601996"
        
        // Try to open the App Store app with write-review action
        if let appStoreURL = URL(string: "itms-apps://itunes.apple.com/app/id\(appID)?action=write-review"),
           UIApplication.shared.canOpenURL(appStoreURL) {
            UIApplication.shared.open(appStoreURL, options: [:], completionHandler: nil)
        } 
        // Fallback to web URL if App Store app is not available
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
        
        // Mark as shown
        WhatsNewManager.shared.markAsShown()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            headerOpacity = 0
            cardsOpacity = 0
            feedbackOpacity = 0
            buttonOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Show feature request popup after What's New is dismissed - optional
            // showFeatureRequestAlert = true
            finalDismiss()
        }
    }
    
    private func sendFeatureRequest() {
        guard !featureRequestText.isEmpty else {
            finalDismiss()
            return
        }
        
        // Send feature request via FeedbackService
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
    // Using feature-specific key so new What's New shows for returning users
    private let whatsNewHasBeenShownKey = "WhatsNewShown_TextStyling_Feb2026"
    
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
    /// This is the - once true, popup NEVER shows again
    var hasBeenShownOnce: Bool {
        UserDefaults.standard.bool(forKey: whatsNewHasBeenShownKey)
    }
    
    /// Start date for showing the What's New popup
    /// February 3, 2026 at 00:00:00
    private var startDate: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 3
        components.hour = 0
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }
    
    /// End date for showing the What's New popup
    /// February 10, 2026 at 23:59:59
    private var endDate: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 10
        components.hour = 23
        components.minute = 59
        components.second = 59
        return Calendar.current.date(from: components) ?? Date()
    }
    
    /// Determines if What's New should be shown
    /// - Only shows ONCE EVER to paid users who update
    /// - Only shows between Jan 23-27, 2026
    /// - Only shows to users with active premium subscription
    /// - Once shown and dismissed, NEVER shows again
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
        
        // Check if we're within the date window (Jan 23-27, 2026)
        let now = Date()
        if now < startDate || now > endDate {
            #if DEBUG
            print("🎉 WhatsNewManager: Outside date window (Jan 23-27, 2026) - not showing")
            print("   Current: \(now), Start: \(startDate), End: \(endDate)")
            #endif
            return false
        }
        
        // User must have completed setup (existing user, not new install)
        guard hasCompletedSetup else {
            #if DEBUG
            print("🎉 WhatsNewManager: User hasn't completed setup - skipping What's New")
            #endif
            return false
        }
        
        // User must have active premium subscription
        guard PaywallManager.shared.isPremium else {
            #if DEBUG
            print("🎉 WhatsNewManager: User is not premium - skipping What's New")
            #endif
            return false
        }
        
        // This is a paid user who hasn't seen the What's New yet - show it!
        #if DEBUG
        print("🎉 WhatsNewManager: Paid user, first time seeing What's New - showing popup")
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
