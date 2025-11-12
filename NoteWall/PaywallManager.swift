import Foundation
import SwiftUI

/// Manages paywall state, usage tracking, and premium status
class PaywallManager: ObservableObject {
    // MARK: - Singleton
    static let shared = PaywallManager()
    
    // MARK: - AppStorage Keys
    @AppStorage("wallpaperExportCount") var wallpaperExportCount: Int = 0
    @AppStorage("hasPremiumAccess") var hasPremiumAccess: Bool = false
    @AppStorage("hasLifetimeAccess") var hasLifetimeAccess: Bool = false
    @AppStorage("subscriptionExpiryDate") var subscriptionExpiryTimestamp: Double = 0
    @AppStorage("hasSeenPaywall") var hasSeenPaywall: Bool = false
    @AppStorage("paywallDismissCount") var paywallDismissCount: Int = 0
    
    // MARK: - Published Properties
    @Published var shouldShowPaywall: Bool = false
    @Published var paywallTriggerReason: PaywallTriggerReason = .limitReached
    
    // MARK: - Constants
    private let freeExportLimit = 3 // User can export 3 wallpapers for free
    private var paywallDelayWorkItem: DispatchWorkItem?
    
    // MARK: - Computed Properties
    var isPremium: Bool {
        return hasLifetimeAccess || hasActiveSubscription
    }
    
    var hasActiveSubscription: Bool {
        guard subscriptionExpiryTimestamp > 0 else { return false }
        let expiryDate = Date(timeIntervalSince1970: subscriptionExpiryTimestamp)
        return Date() < expiryDate
    }
    
    var remainingFreeExports: Int {
        return max(0, freeExportLimit - wallpaperExportCount)
    }
    
    var hasReachedFreeLimit: Bool {
        return wallpaperExportCount >= freeExportLimit
    }
    
    // MARK: - Initialization
    private init() {
        // Restore premium status on app launch
        restorePurchases()
        
        // Check if we should show paywall on app launch
        checkPaywallOnLaunch()
    }
    
    /// Check if paywall should be shown on app launch
    func checkPaywallOnLaunch() {
        guard !isPremium else { return }
        
        // Check if user has completed onboarding
        let hasCompletedSetup = UserDefaults.standard.bool(forKey: "hasCompletedSetup")
        
        // Only show paywall on launch if:
        // 1. User has completed onboarding
        // 2. User has reached the free limit (used all 3 free wallpapers)
        // 3. This is a subsequent app open (not during onboarding)
        if hasCompletedSetup && hasReachedFreeLimit {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, !self.isPremium else { return }
                self.paywallTriggerReason = .limitReached
                self.shouldShowPaywall = true
                print("🚫 PaywallManager: Showing paywall on app launch (limit already reached)")
            }
        } else if !hasCompletedSetup {
            print("ℹ️ PaywallManager: Skipping paywall on launch - onboarding not completed")
        } else {
            print("ℹ️ PaywallManager: User has \(self.remainingFreeExports) free wallpapers remaining")
        }
    }
    
    // MARK: - Usage Tracking
    
    /// Call this when a wallpaper is successfully generated
    func trackWallpaperExport() {
        guard !isPremium else { return }
        
        wallpaperExportCount += 1
        print("📊 PaywallManager: Wallpaper export tracked. Count: \(wallpaperExportCount)/\(freeExportLimit)")
        
        // Check if we should show paywall after reaching free limit with delay
        if wallpaperExportCount >= freeExportLimit {
            showPaywallAfterDelay()
        }
    }
    
    /// Show paywall after 5-second delay when limit is reached
    private func showPaywallAfterDelay() {
        guard !isPremium else { return }
        
        // Cancel any existing delayed paywall
        paywallDelayWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isPremium else { return }
            
            DispatchQueue.main.async {
                self.paywallTriggerReason = .limitReached
                self.shouldShowPaywall = true
                self.hasSeenPaywall = true
                print("🚫 PaywallManager: Free limit reached, showing paywall after delay")
            }
        }
        
        paywallDelayWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
        print("⏰ PaywallManager: Paywall scheduled to show in 5 seconds")
    }
    
    /// Check if user can export wallpaper (for blocking UI)
    func canExportWallpaper() -> Bool {
        return isPremium || !hasReachedFreeLimit
    }
    
    /// Show paywall manually (e.g., from settings)
    func showPaywall(reason: PaywallTriggerReason = .manual) {
        paywallTriggerReason = reason
        shouldShowPaywall = true
    }
    
    // MARK: - Purchase Management
    
    /// Grant lifetime access (one-time purchase)
    func grantLifetimeAccess() {
        hasLifetimeAccess = true
        hasPremiumAccess = true
        shouldShowPaywall = false
        print("✅ PaywallManager: Lifetime access granted")
    }
    
    /// Grant subscription access
    func grantSubscription(expiryDate: Date) {
        subscriptionExpiryTimestamp = expiryDate.timeIntervalSince1970
        hasPremiumAccess = true
        shouldShowPaywall = false
        print("✅ PaywallManager: Subscription granted until \(expiryDate)")
    }
    
    /// Restore previous purchases
    func restorePurchases() {
        // This will be implemented with StoreKit
        // For now, just check if we have stored premium status
        print("🔄 PaywallManager: Restoring purchases...")
        
        // Check subscription expiry
        if hasActiveSubscription {
            hasPremiumAccess = true
            print("   ✅ Active subscription found")
        } else if hasLifetimeAccess {
            hasPremiumAccess = true
            print("   ✅ Lifetime access found")
        } else {
            hasPremiumAccess = false
            print("   ℹ️ No active premium access")
        }
    }
    
    /// Reset all paywall data (for testing)
    func resetPaywallData() {
        paywallDelayWorkItem?.cancel()
        paywallDelayWorkItem = nil
        wallpaperExportCount = 0
        hasPremiumAccess = false
        hasLifetimeAccess = false
        subscriptionExpiryTimestamp = 0
        hasSeenPaywall = false
        paywallDismissCount = 0
        shouldShowPaywall = false
        print("🔄 PaywallManager: All data reset")
    }
    
    // MARK: - Analytics Helpers
    
    func trackPaywallDismiss() {
        paywallDismissCount += 1
        print("📊 PaywallManager: Paywall dismissed. Total dismissals: \(paywallDismissCount)")
    }
    
    func trackPaywallView() {
        print("📊 PaywallManager: Paywall viewed. Reason: \(paywallTriggerReason)")
    }
    
    // MARK: - Reset for Fresh Install
    
    /// Reset paywall data for fresh install (called when hasCompletedSetup is false)
    func resetForFreshInstall() {
        paywallDelayWorkItem?.cancel()
        paywallDelayWorkItem = nil
        wallpaperExportCount = 0
        hasPremiumAccess = false
        hasLifetimeAccess = false
        subscriptionExpiryTimestamp = 0
        hasSeenPaywall = false
        paywallDismissCount = 0
        shouldShowPaywall = false
        print("🔄 PaywallManager: Reset for fresh install")
    }
}

// MARK: - Paywall Trigger Reason

enum PaywallTriggerReason: String {
    case firstWallpaperCreated = "first_wallpaper"
    case limitReached = "limit_reached"
    case manual = "manual"
    case settings = "settings"
    
    var title: String {
        switch self {
        case .firstWallpaperCreated:
            return "Your Wallpaper is Ready! 🎉"
        case .limitReached:
            return "Free Limit Reached"
        case .manual, .settings:
            return "Upgrade to NoteWall+"
        }
    }
    
    var message: String {
        switch self {
        case .firstWallpaperCreated:
            return "Love it? Unlock unlimited wallpapers and keep your lock screen fresh every day."
        case .limitReached:
            return "You've created your free wallpapers. Upgrade to keep creating unlimited wallpapers."
        case .manual, .settings:
            return "Get unlimited wallpapers, premium features, and support future development."
        }
    }
}
