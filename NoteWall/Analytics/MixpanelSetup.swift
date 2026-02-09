//
//  MixpanelSetup.swift
//  NoteWall
//
//  Mixpanel configuration and setup
//

import Foundation
import Mixpanel
import UIKit

// MARK: - Mixpanel Configuration

/// Handles Mixpanel initialization and configuration
final class MixpanelSetup {
    
    // MARK: - Singleton
    static let shared = MixpanelSetup()
    
    // MARK: - State
    private var isConfigured = false
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Configure Mixpanel - call this in app initialization
    /// Should be called before any analytics events are tracked
    func configure() {
        guard !isConfigured else {
            #if DEBUG
            print("⚠️ Mixpanel: Already configured, skipping")
            #endif
            return
        }
        
        // Initialize Mixpanel with token from Config
        Mixpanel.initialize(
            token: Config.mixpanelToken,
            trackAutomaticEvents: false
        )
        
        #if DEBUG
        // Enable debug logging in debug builds
        Mixpanel.mainInstance().loggingEnabled = true
        print("📊 Mixpanel: Configuring in DEBUG mode")
        #endif
        
        isConfigured = true
        
        // Set default user properties (super properties + people)
        setDefaultUserProperties()
        
        #if DEBUG
        print("✅ Mixpanel: Configuration complete")
        #endif
    }
    
    /// Set default user properties on first launch
    private func setDefaultUserProperties() {
        let defaults = UserDefaults.standard
        
        // Set install date if not already set
        if defaults.object(forKey: "mixpanel_install_date") == nil {
            let installDate = ISO8601DateFormatter().string(from: Date())
            defaults.set(installDate, forKey: "mixpanel_install_date")
            
            Mixpanel.mainInstance().people.set(properties: [
                AnalyticsProperty.installDate: installDate
            ])
            Mixpanel.mainInstance().registerSuperProperties([
                AnalyticsProperty.installDate: installDate
            ])
        }
        
        // Set app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            Mixpanel.mainInstance().people.set(properties: ["app_version": version])
            Mixpanel.mainInstance().registerSuperProperties(["app_version": version])
        }
        
        // Set device info as super properties (sent with every event)
        Mixpanel.mainInstance().registerSuperProperties([
            "device_model": UIDevice.current.model,
            "ios_version": UIDevice.current.systemVersion
        ])
        
        // Also set on user profile
        Mixpanel.mainInstance().people.set(properties: [
            "device_model": UIDevice.current.model,
            "ios_version": UIDevice.current.systemVersion
        ])
    }
    
    // MARK: - Debug Helpers
    
    /// Enable or disable analytics collection
    /// Useful for user privacy settings or debug purposes
    func setAnalyticsCollectionEnabled(_ enabled: Bool) {
        if enabled {
            Mixpanel.mainInstance().optInTracking()
        } else {
            Mixpanel.mainInstance().optOutTracking()
        }
        #if DEBUG
        print("📊 Mixpanel: Analytics collection \(enabled ? "enabled" : "disabled")")
        #endif
    }
    
    /// Force upload pending analytics events (useful for debugging)
    func flushAnalytics() {
        #if DEBUG
        print("📊 Mixpanel: Flushing analytics events")
        #endif
        Mixpanel.mainInstance().flush()
    }
}
