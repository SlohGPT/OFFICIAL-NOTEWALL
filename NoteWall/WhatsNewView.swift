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
    
    // Adaptive layout
    private var isCompact: Bool {
        let screenHeight = UIScreen.main.bounds.height
        return screenHeight < 750
    }
    
    // MARK: - Current Version Info
    
    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3"
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
    
    private var updateItems: [UpdateItem] {
        [
            UpdateItem(
                icon: "sparkles",
                iconColor: .appAccent,
                title: "Performance Boost",
                description: "Faster wallpaper generation and smoother animations."
            ),
            UpdateItem(
                icon: "wrench.and.screwdriver.fill",
                iconColor: .appAccent.opacity(0.8),
                title: "Bug Fixes",
                description: "Fixed issues reported by our users. Thank you!"
            ),
            UpdateItem(
                icon: "paintbrush.fill",
                iconColor: .appAccent.opacity(0.6),
                title: "UI Polish",
                description: "Refined design elements for a better experience."
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
                colors: [Color.appAccent.opacity(0.06), Color.clear],
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
                    .foregroundColor(.appAccent)
                
                Text("What's New")
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
            
            // Main icon
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.12))
                    .frame(width: isCompact ? 70 : 85, height: isCompact ? 70 : 85)
                
                Image(systemName: "party.popper.fill")
                    .font(.system(size: isCompact ? 32 : 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.appAccent, .appAccent.opacity(0.7)],
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
                    .fill(Color.appAccent.opacity(0.15))
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
                        .foregroundColor(.appAccent)
                    
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
                            .strokeBorder(Color.appAccent.opacity(0.15), lineWidth: 1)
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
            
            // Secondary: Maybe Later
            Button(action: { closePopup() }) {
                Text("Maybe Later")
                    .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.vertical, isCompact ? 10 : 12)
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
            isPresented = false
            dismiss()
        }
    }
}

// MARK: - What's New Manager
// Note: ConfettiView is defined in OnboardingEnhanced.swift and reused here

class WhatsNewManager: ObservableObject {
    static let shared = WhatsNewManager()
    
    @Published var shouldShowWhatsNew = false
    
    private let lastShownVersionKey = "WhatsNewLastShownVersion"
    private let hasCompletedSetupKey = "hasCompletedSetup"
    
    /// Runtime flag - resets every time app is launched (not persisted)
    /// This ensures DEBUG builds show the popup after each clean build + run
    private var hasShownThisSession = false
    
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
    
    /// Determines if What's New should be shown
    /// - Only shows to EXISTING users who update to a new version
    /// - Shows to existing v1.2 users when they update to v1.3 (first time migration)
    /// - Never shows to new users who just installed the app
    /// - Only shows once per version
    /// - In DEBUG mode with clean build, always shows (first time per app launch)
    func checkShouldShow() -> Bool {
        #if DEBUG
        // For testing: Show every time the app is freshly launched (clean build + run)
        // hasShownThisSession is a runtime flag that resets when app is killed
        // Show if user has completed setup (simulating existing user)
        if !hasShownThisSession && hasCompletedSetup {
            print("🎉 WhatsNewManager: DEBUG mode - showing What's New for testing")
            print("   Version: \(currentVersion), Setup complete: \(hasCompletedSetup)")
            print("   Last shown version: \(lastShownVersion ?? "none")")
            return true
        }
        #endif
        
        // Normal logic for production:
        // 1. User must have completed setup (existing user, not new install)
        guard hasCompletedSetup else {
            #if DEBUG
            print("🎉 WhatsNewManager: User hasn't completed setup - skipping What's New")
            #endif
            return false
        }
        
        // 2. Check if this is a migration from v1.2 (no lastShownVersion exists yet)
        // These are existing users who installed v1.2 before this feature existed
        guard let lastVersion = lastShownVersion else {
            #if DEBUG
            print("🎉 WhatsNewManager: Existing user from v1.2 updating to \(currentVersion) - showing What's New")
            #endif
            // This is an existing user from v1.2 - show them the What's New!
            return true
        }
        
        // 3. Haven't shown for this version yet (user updated from previous version)
        if lastVersion == currentVersion {
            #if DEBUG
            print("🎉 WhatsNewManager: Already shown for version \(currentVersion) - skipping")
            #endif
            return false
        }
        
        // 4. User is updating from an older version - show What's New!
        #if DEBUG
        print("🎉 WhatsNewManager: User updated from \(lastVersion) to \(currentVersion) - showing What's New")
        #endif
        return true
    }
    
    /// Mark the What's New as shown for current version
    func markAsShown() {
        UserDefaults.standard.set(currentVersion, forKey: lastShownVersionKey)
        shouldShowWhatsNew = false
        hasShownThisSession = true
        
        #if DEBUG
        print("🎉 WhatsNewManager: Marked as shown for version \(currentVersion)")
        #endif
    }
    
    /// Reset for testing (call this in DEBUG to see popup again next launch)
    func resetForTesting() {
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: lastShownVersionKey)
        hasShownThisSession = false
        print("🎉 WhatsNewManager: Reset for testing - popup will show on next launch")
        #endif
    }
}

// MARK: - Preview

#Preview {
    WhatsNewView(isPresented: .constant(true))
}
