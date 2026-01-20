import SwiftUI
import RevenueCat
import TelemetryDeck
import SuperwallKit
import FirebaseCore

@main
struct NoteWallApp: App {
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @State private var showOnboarding = false
    
    private let onboardingVersion = 3
    
    // Quick Actions integration
    @StateObject private var quickActionsManager = QuickActionsManager.shared
    
    // AppDelegate for handling Quick Actions
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        #if DEBUG
        // DEBUG: Always show onboarding when running from Xcode
        UserDefaults.standard.set(false, forKey: "hasCompletedSetup")
        #endif

        // IMPORTANT: Configure Firebase FIRST before any other Firebase services
        // This must be called before RevenueCat, Superwall, etc.
        FirebaseSetup.shared.configure()
        
        // Initialize crash reporting
        setupCrashReporting()
        HomeScreenImageManager.prepareStorageStructure()
        configureRevenueCat()
        configureSuperwall()
        
        // Initialize TelemetryDeck for analytics
        let telemetryConfig = TelemetryDeck.Config(appID: "F406962D-0C75-41A0-82DB-01AC06B8E21A")
        TelemetryDeck.initialize(config: telemetryConfig)
        
        // Check onboarding status on init (only show for first launch)
        var shouldShow = !hasCompletedSetup
        
        #if DEBUG
        // Force show onboarding in debug mode even if AppStorage is stale
        shouldShow = true
        #endif
        
        _showOnboarding = State(initialValue: shouldShow)
        
        // Reset paywall data if this is a fresh install
        var isFreshInstall = !hasCompletedSetup
        
        #if DEBUG
        isFreshInstall = true
        #endif
        
        if isFreshInstall {
            PaywallManager.shared.resetForFreshInstall()
        }
        
        // Register Quick Actions for exit-intercept strategy
        QuickActionsManager.shared.registerQuickActions()
    }

    private func configureRevenueCat() {
        let configuration = Configuration
            .builder(withAPIKey: "appl_VuulGamLrpZVzgEymEJnflZNEzs")
            .with(entitlementVerificationMode: .informational)
            .with(storeKitVersion: .storeKit1)
            .build()

        Purchases.configure(with: configuration)
        PaywallManager.shared.connectRevenueCat()
    }
    
    private func configureSuperwall() {
        let apiKey = "pk_IeL87ZJ24CWF5_aPvRJE_"
        Superwall.configure(apiKey: apiKey)
        
        // Initialize user attributes tracking
        // Superwall automatically uses anonymous IDs since there's no user management system
        SuperwallUserAttributesManager.shared.updateAllAttributes()
    }
    
    private func setupCrashReporting() {
        // Enable crash reporting in production
        CrashReporter.isEnabled = true
        
        // Set app version for crash reports
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            CrashReporter.setCustomKey("app_version", value: "\(version) (\(build))")
        }
        
        // Set device info
        CrashReporter.setCustomKey("device_model", value: UIDevice.current.model)
        CrashReporter.setCustomKey("ios_version", value: UIDevice.current.systemVersion)
        
        CrashReporter.logMessage("App launched", level: .info)
        
        // To enable Firebase Crashlytics, uncomment below and add Firebase SDK:
        /*
        import FirebaseCore
        import FirebaseCrashlytics
        
        FirebaseApp.configure()
        
        // Enable Crashlytics collection
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        */
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    // Show onboarding directly for first-time users (no flash of empty homepage)
                    OnboardingView(
                        isPresented: $showOnboarding,
                        onboardingVersion: onboardingVersion
                    )
                } else {
                    // Show main app for users who have completed setup
                    MainTabView()
                        .onAppear {
                            // Handle Quick Action if app was launched via one
                            if let triggeredAction = quickActionsManager.triggeredAction {
                                print("🎬 NoteWallApp: App launched with Quick Action - \(triggeredAction.title)")
                                
                                // Post notification after a longer delay to ensure MainTabView is ready
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    print("📤 NoteWallApp: Posting quick action notification")
                                    NotificationCenter.default.post(
                                        name: .quickActionTriggered,
                                        object: triggeredAction
                                    )
                                }
                            }
                        }
                        .onOpenURL { url in
                            // Handle Superwall deep links first
                            let handledBySuperwall = Superwall.handleDeepLink(url)
                            if handledBySuperwall {
                                print("🔗 NoteWallApp: URL handled by Superwall")
                                return
                            }
                            
                            // Handle URL scheme when app is opened via notewall://
                            // This allows the shortcut to redirect back to the app
                            print("🔗 NoteWallApp: Opened via URL: \(url)")
                            print("🔗 Scheme: \(url.scheme ?? "nil"), Host: \(url.host ?? "nil"), Path: \(url.path)")
                            
                            if url.scheme?.lowercased() == "notewall" {
                                let lowerHost = url.host?.lowercased()
                                let lowerPath = url.path.lowercased()
                                if lowerHost == "wallpaper-updated" || lowerPath.contains("wallpaper-updated") {
                                    print("✅ NoteWallApp: Posting .shortcutWallpaperApplied notification")
                                    NotificationCenter.default.post(name: .shortcutWallpaperApplied, object: nil)
                                } else {
                                    print("⚠️ NoteWallApp: URL doesn't match wallpaper-updated pattern")
                                }
                            }
                        }
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                // Lock orientation to portrait on app launch
                // Note: Orientation locking is primarily handled by Info.plist and AppDelegate
                // This onAppear is a backup attempt, but the main control is in AppDelegate.supportedInterfaceOrientationsFor
                if #available(iOS 16.0, *) {
                    // iOS 16+ - orientation is controlled by Info.plist, AppDelegate, and SceneDelegate
                    // The requestGeometryUpdate API may not be available or may have different signature
                    // Rely on AppDelegate and SceneDelegate methods instead
                } else {
                    // iOS 15 and below - orientation is controlled by Info.plist and AppDelegate
                    UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                }
            }
            .onChange(of: hasCompletedSetup) { newValue in
                // Update onboarding state when setup completion changes
                showOnboarding = !newValue
                // Update Superwall attributes when setup status changes
                SuperwallUserAttributesManager.shared.updateOnboardingAttributes()
            }
            .onChange(of: PaywallManager.shared.isPremium) { _ in
                // Update Quick Actions when premium status changes
                QuickActionsManager.shared.refreshQuickActions()
            }
            .onReceive(NotificationCenter.default.publisher(for: .onboardingReplayRequested)) { _ in
                // Allow replaying onboarding from settings
                showOnboarding = true
            }
        }
    }
}
