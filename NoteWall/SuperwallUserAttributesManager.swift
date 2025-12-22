import Foundation
import SuperwallKit
import UIKit

/// Manages Superwall user attributes and identification
/// Tracks comprehensive user data for paywall personalization and analytics
final class SuperwallUserAttributesManager {
    // MARK: - Singleton
    static let shared = SuperwallUserAttributesManager()
    
    private init() {
        // Initialize on first access
        updateAllAttributes()
    }
    
    // MARK: - User Identification
    
    /// Since there's no user management system, Superwall automatically uses anonymous IDs
    /// This method can be called if you add user management later
    func identifyUser(userId: String) {
        Superwall.shared.identify(userId: userId)
        updateAllAttributes()
    }
    
    /// Reset user identity (for logout scenarios)
    func resetUser() {
        Superwall.shared.reset()
        updateAllAttributes()
    }
    
    // MARK: - Attribute Updates
    
    /// Update all user attributes at once
    func updateAllAttributes() {
        var attributes: [String: Any?] = [:]
        
        // MARK: - Subscription & Premium Status
        let paywallManager = PaywallManager.shared
        attributes["subscriptionStatus"] = paywallManager.isPremium ? "premium" : "free"
        attributes["hasPremiumAccess"] = paywallManager.isPremium
        attributes["hasLifetimeAccess"] = paywallManager.hasLifetimeAccess
        attributes["hasActiveSubscription"] = paywallManager.hasActiveSubscription
        attributes["hasActiveRevenueCatEntitlement"] = paywallManager.hasActiveRevenueCatEntitlement
        
        if paywallManager.subscriptionExpiryTimestamp > 0 {
            attributes["subscriptionExpiryDate"] = Date(timeIntervalSince1970: paywallManager.subscriptionExpiryTimestamp)
        }
        
        if let trialStart = paywallManager.trialStartDate {
            attributes["trialStartDate"] = trialStart
            attributes["isInTrial"] = paywallManager.shouldShowTrialReminder
        }
        
        // MARK: - Usage Statistics
        attributes["wallpaperExportCount"] = paywallManager.wallpaperExportCount
        attributes["remainingFreeExports"] = paywallManager.remainingFreeExports
        attributes["hasReachedFreeLimit"] = paywallManager.hasReachedFreeLimit
        attributes["hasSeenPaywall"] = paywallManager.hasSeenPaywall
        attributes["paywallDismissCount"] = paywallManager.paywallDismissCount
        
        // MARK: - Onboarding & Setup
        let hasCompletedSetup = UserDefaults.standard.bool(forKey: "hasCompletedSetup")
        attributes["hasCompletedSetup"] = hasCompletedSetup
        attributes["completedOnboardingVersion"] = UserDefaults.standard.integer(forKey: "completedOnboardingVersion")
        attributes["hasCompletedInitialWallpaperSetup"] = UserDefaults.standard.bool(forKey: "hasCompletedInitialWallpaperSetup")
        
        // Calculate days since first install (approximate)
        if let installDate = getInstallDate() {
            let daysSinceInstall = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
            attributes["daysSinceInstall"] = daysSinceInstall
            attributes["appInstallDate"] = installDate
        }
        
        // MARK: - Notes & Content
        if let notesData = UserDefaults.standard.data(forKey: "savedNotes"),
           let notes = try? JSONDecoder().decode([Note].self, from: notesData) {
            attributes["noteCount"] = notes.count
            attributes["completedNoteCount"] = notes.filter { $0.isCompleted }.count
            attributes["hasNotes"] = !notes.isEmpty
        } else {
            attributes["noteCount"] = 0
            attributes["completedNoteCount"] = 0
            attributes["hasNotes"] = false
        }
        
        // MARK: - Settings & Preferences
        attributes["saveWallpapersToPhotos"] = UserDefaults.standard.bool(forKey: "saveWallpapersToPhotos")
        attributes["skipDeletingOldWallpaper"] = UserDefaults.standard.bool(forKey: "skipDeletingOldWallpaper")
        attributes["hasLockScreenWidgets"] = UserDefaults.standard.bool(forKey: "hasLockScreenWidgets")
        attributes["homeScreenUsesCustomPhoto"] = UserDefaults.standard.bool(forKey: "homeScreenUsesCustomPhoto")
        attributes["hasShownAutoUpdatePrompt"] = UserDefaults.standard.bool(forKey: "hasShownAutoUpdatePrompt")
        attributes["hasShownFirstNoteHint"] = UserDefaults.standard.bool(forKey: "hasShownFirstNoteHint")
        attributes["shouldShowTroubleshootingBanner"] = UserDefaults.standard.bool(forKey: "shouldShowTroubleshootingBanner")
        attributes["hasRequestedAppReview"] = UserDefaults.standard.bool(forKey: "hasRequestedAppReview")
        
        // Lock screen background preferences
        if let backgroundRaw = UserDefaults.standard.string(forKey: "lockScreenBackground"),
           !backgroundRaw.isEmpty {
            attributes["lockScreenBackground"] = backgroundRaw
        }
        
        if let backgroundModeRaw = UserDefaults.standard.string(forKey: "lockScreenBackgroundMode"),
           !backgroundModeRaw.isEmpty {
            attributes["lockScreenBackgroundMode"] = backgroundModeRaw
        }
        
        if let autoUpdateRaw = UserDefaults.standard.string(forKey: "autoUpdateWallpaperAfterDeletion"),
           !autoUpdateRaw.isEmpty {
            attributes["autoUpdateWallpaperAfterDeletion"] = autoUpdateRaw
        }
        
        if let homePresetRaw = UserDefaults.standard.string(forKey: "homeScreenPresetSelection"),
           !homePresetRaw.isEmpty {
            attributes["homeScreenPresetSelection"] = homePresetRaw
        }
        
        // MARK: - Onboarding Quiz Data (if available)
        if let forgetMost = UserDefaults.standard.string(forKey: "quiz_forgetMost"), !forgetMost.isEmpty {
            attributes["quiz_forgetMost"] = forgetMost
        }
        if let phoneChecks = UserDefaults.standard.string(forKey: "quiz_phoneChecks"), !phoneChecks.isEmpty {
            attributes["quiz_phoneChecks"] = phoneChecks
        }
        if let biggestDistraction = UserDefaults.standard.string(forKey: "quiz_biggestDistraction"), !biggestDistraction.isEmpty {
            attributes["quiz_biggestDistraction"] = biggestDistraction
        }
        if let firstNote = UserDefaults.standard.string(forKey: "quiz_firstNote"), !firstNote.isEmpty {
            attributes["quiz_firstNote"] = firstNote
        }
        
        // MARK: - Device & App Info
        attributes["deviceModel"] = UIDevice.current.model
        attributes["systemVersion"] = UIDevice.current.systemVersion
        attributes["deviceName"] = UIDevice.current.name
        
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            attributes["appVersion"] = appVersion
        }
        if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            attributes["buildNumber"] = buildNumber
        }
        
        // MARK: - Promo Code Usage
        if let promoManager = try? PromoCodeManager.shared {
            // Check if user has used promo codes
            let hasUsedLifetimeCode = (UserDefaults.standard.array(forKey: "promo_codes_used_lifetime") as? [String])?.isEmpty == false
            let hasUsedMonthlyCode = (UserDefaults.standard.array(forKey: "promo_codes_used_monthly") as? [String])?.isEmpty == false
            attributes["hasUsedPromoCode"] = hasUsedLifetimeCode || hasUsedMonthlyCode
            attributes["hasUsedLifetimePromoCode"] = hasUsedLifetimeCode
            attributes["hasUsedMonthlyPromoCode"] = hasUsedMonthlyCode
        }
        
        // MARK: - Timestamps
        attributes["lastAttributeUpdate"] = Date()
        
        // Set all attributes
        Superwall.shared.setUserAttributes(attributes)
        
        #if DEBUG
        print("📊 SuperwallUserAttributesManager: Updated \(attributes.count) user attributes")
        #endif
    }
    
    /// Update subscription-related attributes
    func updateSubscriptionAttributes() {
        let paywallManager = PaywallManager.shared
        var attributes: [String: Any?] = [:]
        
        attributes["subscriptionStatus"] = paywallManager.isPremium ? "premium" : "free"
        attributes["hasPremiumAccess"] = paywallManager.isPremium
        attributes["hasLifetimeAccess"] = paywallManager.hasLifetimeAccess
        attributes["hasActiveSubscription"] = paywallManager.hasActiveSubscription
        attributes["hasActiveRevenueCatEntitlement"] = paywallManager.hasActiveRevenueCatEntitlement
        
        if paywallManager.subscriptionExpiryTimestamp > 0 {
            attributes["subscriptionExpiryDate"] = Date(timeIntervalSince1970: paywallManager.subscriptionExpiryTimestamp)
        }
        
        if let trialStart = paywallManager.trialStartDate {
            attributes["trialStartDate"] = trialStart
            attributes["isInTrial"] = paywallManager.shouldShowTrialReminder
        }
        
        Superwall.shared.setUserAttributes(attributes)
    }
    
    /// Update usage statistics
    func updateUsageAttributes() {
        let paywallManager = PaywallManager.shared
        var attributes: [String: Any?] = [:]
        
        attributes["wallpaperExportCount"] = paywallManager.wallpaperExportCount
        attributes["remainingFreeExports"] = paywallManager.remainingFreeExports
        attributes["hasReachedFreeLimit"] = paywallManager.hasReachedFreeLimit
        attributes["hasSeenPaywall"] = paywallManager.hasSeenPaywall
        attributes["paywallDismissCount"] = paywallManager.paywallDismissCount
        
        Superwall.shared.setUserAttributes(attributes)
    }
    
    /// Update onboarding status
    func updateOnboardingAttributes() {
        var attributes: [String: Any?] = [:]
        
        attributes["hasCompletedSetup"] = UserDefaults.standard.bool(forKey: "hasCompletedSetup")
        attributes["completedOnboardingVersion"] = UserDefaults.standard.integer(forKey: "completedOnboardingVersion")
        attributes["hasCompletedInitialWallpaperSetup"] = UserDefaults.standard.bool(forKey: "hasCompletedInitialWallpaperSetup")
        
        Superwall.shared.setUserAttributes(attributes)
    }
    
    /// Update notes count
    func updateNotesAttributes() {
        var attributes: [String: Any?] = [:]
        
        if let notesData = UserDefaults.standard.data(forKey: "savedNotes"),
           let notes = try? JSONDecoder().decode([Note].self, from: notesData) {
            attributes["noteCount"] = notes.count
            attributes["completedNoteCount"] = notes.filter { $0.isCompleted }.count
            attributes["hasNotes"] = !notes.isEmpty
        } else {
            attributes["noteCount"] = 0
            attributes["completedNoteCount"] = 0
            attributes["hasNotes"] = false
        }
        
        Superwall.shared.setUserAttributes(attributes)
    }
    
    // MARK: - Helper Methods
    
    /// Get approximate app install date
    private func getInstallDate() -> Date? {
        // Try to get from file system (first launch date)
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: documentsPath.path)
                if let creationDate = attributes[.creationDate] as? Date {
                    return creationDate
                }
            } catch {
                // Fallback to a default date if we can't determine
            }
        }
        
        // Fallback: use a timestamp from UserDefaults if available
        if let installTimestamp = UserDefaults.standard.object(forKey: "app_install_timestamp") as? Date {
            return installTimestamp
        }
        
        // If this is the first time, store current date
        let now = Date()
        UserDefaults.standard.set(now, forKey: "app_install_timestamp")
        return now
    }
}

