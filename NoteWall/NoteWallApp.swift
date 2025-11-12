import SwiftUI

@main
struct NoteWallApp: App {
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @AppStorage("completedOnboardingVersion") private var completedOnboardingVersion = 0
    @State private var showOnboarding = false
    
    private let onboardingVersion = 3

    init() {
        // DEVELOPMENT: Clear all UserDefaults on every launch for testing
        // Comment this out for production builds
        #if DEBUG
        clearAllUserDefaults()
        #endif
        
        // Check onboarding status on init
        let shouldShow = !hasCompletedSetup || completedOnboardingVersion < onboardingVersion
        _showOnboarding = State(initialValue: shouldShow)
        
        // Reset paywall data if this is a fresh install
        if !hasCompletedSetup {
            PaywallManager.shared.resetForFreshInstall()
        }
    }
    
    private func clearAllUserDefaults() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
            print("🧹 Cleared all UserDefaults for fresh testing")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(
                        isPresented: $showOnboarding,
                        onboardingVersion: onboardingVersion
                    )
                }
                .onAppear {
                    // Show onboarding if not completed or needs to be refreshed for this version
                    showOnboarding = !hasCompletedSetup || completedOnboardingVersion < onboardingVersion
                }
                .onChange(of: hasCompletedSetup) { _ in
                    showOnboarding = !hasCompletedSetup || completedOnboardingVersion < onboardingVersion
                }
                .onChange(of: completedOnboardingVersion) { _ in
                    showOnboarding = !hasCompletedSetup || completedOnboardingVersion < onboardingVersion
                }
                .onOpenURL { url in
                    // Handle URL scheme when app is opened via notewall://
                    // This allows the shortcut to redirect back to the app
                    print("Opened via URL: \(url)")
                    if url.scheme?.lowercased() == "notewall" {
                        let lowerHost = url.host?.lowercased()
                        let lowerPath = url.path.lowercased()
                        if lowerHost == "wallpaper-updated" || lowerPath.contains("wallpaper-updated") {
                            NotificationCenter.default.post(name: .shortcutWallpaperApplied, object: nil)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .onboardingReplayRequested)) { _ in
                    showOnboarding = true
                }
        }
    }
}
