import Foundation
import UIKit

/// Simple crash reporting manager
/// Currently uses Apple's built-in crash reporting
/// Can be extended to use Firebase Crashlytics or Sentry
enum CrashReporter {
    
    // MARK: - Configuration
    
    /// Enable or disable crash reporting
    static var isEnabled: Bool = true
    
    // MARK: - Logging
    
    /// Log a non-fatal error
    static func logError(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil) {
        guard isEnabled else { return }
        
        #if DEBUG
        print("🚨 CrashReporter Error: \(message)")
        if let error = error {
            print("   Error: \(error.localizedDescription)")
        }
        if let userInfo = userInfo {
            print("   UserInfo: \(userInfo)")
        }
        #else
        // In production, this would send to your crash reporting service
        // For now, we rely on Apple's built-in crash reporting
        // To add Firebase Crashlytics, uncomment below:
        /*
        Crashlytics.crashlytics().log("\(message)")
        if let error = error {
            Crashlytics.crashlytics().record(error: error)
        }
        if let userInfo = userInfo {
            for (key, value) in userInfo {
                Crashlytics.crashlytics().setCustomValue(value, forKey: key)
            }
        }
        */
        #endif
    }
    
    /// Log a custom message
    static func logMessage(_ message: String, level: LogLevel = .info) {
        guard isEnabled else { return }
        
        #if DEBUG
        print("📝 CrashReporter [\(level.rawValue)]: \(message)")
        #else
        // In production, send to crash reporting service
        // For Firebase Crashlytics:
        // Crashlytics.crashlytics().log("\(level.rawValue): \(message)")
        #endif
    }
    
    // MARK: - User Properties
    
    /// Set a user property for crash reports
    static func setUserProperty(_ key: String, value: String?) {
        guard isEnabled else { return }
        
        #if DEBUG
        print("👤 CrashReporter User Property: \(key) = \(value ?? "nil")")
        #else
        // For Firebase Crashlytics:
        // Crashlytics.crashlytics().setCustomValue(value ?? "", forKey: key)
        #endif
    }
    
    /// Set user identifier for crash reports
    static func setUserID(_ userID: String?) {
        guard isEnabled else { return }
        
        #if DEBUG
        print("🆔 CrashReporter User ID: \(userID ?? "nil")")
        #else
        // For Firebase Crashlytics:
        // Crashlytics.crashlytics().setUserID(userID)
        #endif
    }
    
    // MARK: - Custom Keys
    
    /// Set a custom key-value pair for crash reports
    static func setCustomKey(_ key: String, value: Any) {
        guard isEnabled else { return }
        
        #if DEBUG
        print("🔑 CrashReporter Custom Key: \(key) = \(value)")
        #else
        // For Firebase Crashlytics:
        // Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        #endif
    }
    
    // MARK: - Breadcrumbs
    
    /// Add a breadcrumb for debugging
    static func addBreadcrumb(_ message: String, category: String = "general") {
        guard isEnabled else { return }
        
        #if DEBUG
        print("🍞 CrashReporter Breadcrumb [\(category)]: \(message)")
        #else
        // For Firebase Crashlytics:
        // Crashlytics.crashlytics().log("\(category): \(message)")
        #endif
    }
    
    // MARK: - Log Levels
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
}

// MARK: - Convenience Extensions

extension CrashReporter {
    /// Log a wallpaper generation error
    static func logWallpaperError(_ error: Error, context: String = "") {
        logError("Wallpaper generation failed\(context.isEmpty ? "" : ": \(context)")", 
                error: error,
                userInfo: ["context": context])
    }
    
    /// Log a StoreKit error
    static func logStoreKitError(_ error: Error, productID: String? = nil) {
        var userInfo: [String: Any] = [:]
        if let productID = productID {
            userInfo["productID"] = productID
        }
        logError("StoreKit error", error: error, userInfo: userInfo)
    }
    
    /// Log a photo save error
    static func logPhotoSaveError(_ error: Error) {
        logError("Photo save failed", error: error)
    }
}


