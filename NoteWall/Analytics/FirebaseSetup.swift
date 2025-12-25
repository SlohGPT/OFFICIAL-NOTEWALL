//
//  FirebaseSetup.swift
//  NoteWall
//
//  Firebase configuration and setup
//

import Foundation
import FirebaseCore
import FirebaseAnalytics

// MARK: - Firebase Configuration

/// Handles Firebase initialization and configuration
final class FirebaseSetup {
    
    // MARK: - Singleton
    static let shared = FirebaseSetup()
    
    // MARK: - State
    private var isConfigured = false
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Configure Firebase - call this in app initialization
    /// Should be called before any Firebase services are used
    func configure() {
        guard !isConfigured else {
            #if DEBUG
            print("⚠️ Firebase: Already configured, skipping")
            #endif
            return
        }
        
        #if DEBUG
        // In DEBUG builds, optionally disable automatic screen tracking
        // to have more control over what's tracked
        Analytics.setAnalyticsCollectionEnabled(true)
        
        // Enable debug logging for Firebase Analytics
        // Note: Also add -FIRAnalyticsDebugEnabled to scheme arguments for real-time debug view
        print("🔥 Firebase: Configuring in DEBUG mode")
        print("🔥 Firebase: For real-time debug view, add '-FIRAnalyticsDebugEnabled' to scheme arguments")
        #endif
        
        // Configure Firebase
        FirebaseApp.configure()
        isConfigured = true
        
        // Disable automatic screen view tracking (we'll handle it manually)
        Analytics.setAnalyticsCollectionEnabled(true)
        
        // Set default user properties
        setDefaultUserProperties()
        
        #if DEBUG
        print("✅ Firebase: Configuration complete")
        #endif
    }
    
    /// Set default user properties on first launch
    private func setDefaultUserProperties() {
        let defaults = UserDefaults.standard
        
        // Set install date if not already set
        if defaults.object(forKey: "firebase_install_date") == nil {
            let installDate = ISO8601DateFormatter().string(from: Date())
            defaults.set(installDate, forKey: "firebase_install_date")
            Analytics.setUserProperty(installDate, forName: AnalyticsProperty.installDate)
        }
        
        // Set app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            Analytics.setUserProperty(version, forName: "app_version")
        }
        
        // Set device info
        Analytics.setUserProperty(UIDevice.current.model, forName: "device_model")
        Analytics.setUserProperty(UIDevice.current.systemVersion, forName: "ios_version")
    }
    
    // MARK: - Debug Helpers
    
    /// Enable or disable analytics collection
    /// Useful for user privacy settings or debug purposes
    func setAnalyticsCollectionEnabled(_ enabled: Bool) {
        Analytics.setAnalyticsCollectionEnabled(enabled)
        #if DEBUG
        print("🔥 Firebase: Analytics collection \(enabled ? "enabled" : "disabled")")
        #endif
    }
    
    /// Force upload pending analytics events (useful for debugging)
    func flushAnalytics() {
        #if DEBUG
        print("🔥 Firebase: Flushing analytics events")
        #endif
        // Note: Firebase automatically batches and sends events
        // There's no public API to force flush, but events are sent:
        // - Every hour
        // - When app goes to background
        // - When there are 500 pending events
        // For debugging, use -FIRAnalyticsDebugEnabled flag instead
    }
}

// MARK: - Setup Instructions
/*
 ====================================================================
 FIREBASE SETUP INSTRUCTIONS
 ====================================================================
 
 1. ADD FIREBASE SDK VIA SWIFT PACKAGE MANAGER:
    - In Xcode: File > Add Package Dependencies
    - Enter URL: https://github.com/firebase/firebase-ios-sdk
    - Select version: 10.0.0 or later
    - Choose products: FirebaseAnalytics, FirebaseCore
    - Click "Add Package"
 
 2. ADD GoogleService-Info.plist:
    - Go to Firebase Console (https://console.firebase.google.com)
    - Create a new project or select existing
    - Add iOS app with your bundle ID
    - Download GoogleService-Info.plist
    - Drag it into your Xcode project (NoteWall folder)
    - Make sure "Copy items if needed" is checked
    - Make sure it's added to the NoteWall target
 
 3. CONFIGURE IN APP:
    - Firebase is configured in NoteWallApp.swift init()
    - FirebaseSetup.shared.configure() is called before other setup
 
 4. ENABLE DEBUG VIEW (for real-time event verification):
    - Edit Scheme > Run > Arguments > Arguments Passed On Launch
    - Add: -FIRAnalyticsDebugEnabled
    - Events will appear in Firebase Console > DebugView within seconds
 
 5. DISABLE FOR SPECIFIC BUILDS (optional):
    - For TestFlight/internal builds where you don't want analytics:
    - Add a build configuration check in FirebaseSetup.configure()
    - Or use Analytics.setAnalyticsCollectionEnabled(false)
 
 ====================================================================
 VERIFICATION CHECKLIST
 ====================================================================
 
 □ GoogleService-Info.plist is in the project and target
 □ Firebase packages added: FirebaseCore, FirebaseAnalytics
 □ FirebaseSetup.configure() called in app init (before other Firebase calls)
 □ -FIRAnalyticsDebugEnabled added to scheme for debugging
 
 TO VERIFY EVENTS ARE FIRING:
 1. Build and run with -FIRAnalyticsDebugEnabled flag
 2. Open Firebase Console > Analytics > DebugView
 3. Select your test device
 4. Perform actions in app and watch events appear in real-time
 
 KEY FUNNELS TO BUILD IN FIREBASE CONSOLE:
 
 1. ONBOARDING FUNNEL:
    onboarding_start → onboarding_step_view (step_index=0..N) → onboarding_complete
    - Filter by flow_id/variant_id for A/B testing
 
 2. PAYWALL CONVERSION FUNNEL:
    paywall_impression → plan_selected → purchase_start → purchase_success
    - Filter by paywall_id, trigger
 
 3. ONBOARDING DROP-OFF:
    onboarding_start → onboarding_abandon (group by step_id)
    - Identify where users drop off
 
 4. QUIZ COMPLETION:
    quiz_answer events by step_id to see completion rates
 
 5. PERMISSION ACCEPTANCE:
    permission_prompt with action=accepted vs action=denied
 
 ====================================================================
*/
