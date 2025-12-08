import SwiftUI
import UIKit

/// Manages iOS Quick Actions (UIApplicationShortcutItems) for exit-intercept strategy.
/// Dynamically registers different actions based on user's premium status to reduce churn.
final class QuickActionsManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = QuickActionsManager()
    
    // MARK: - Quick Action Types
    
    /// Unique identifiers for each quick action
    enum QuickActionType: String {
        case claimDiscount = "com.notewall.action.claimDiscount"
        case giveFeedback = "com.notewall.action.giveFeedback"
        case autoFix = "com.notewall.action.autoFix"
        
        var title: String {
            switch self {
            case .claimDiscount:
                return "Claim 30% Special Offer"
            case .giveFeedback:
                return "Before you delete… Can we ask why?"
            case .autoFix:
                return "Having issues? We'll fix it in 30 seconds"
            }
        }
        
        var subtitle: String? {
            // No subtitles to keep Quick Actions menu compact
            return nil
        }
        
        var icon: UIApplicationShortcutIcon {
            switch self {
            case .claimDiscount:
                return UIApplicationShortcutIcon(systemImageName: "tag.fill")
            case .giveFeedback:
                return UIApplicationShortcutIcon(systemImageName: "message.fill")
            case .autoFix:
                return UIApplicationShortcutIcon(systemImageName: "wrench.and.screwdriver.fill")
            }
        }
    }
    
    // MARK: - Published Properties
    
    /// The quick action that was triggered (for deep-linking)
    @Published var triggeredAction: QuickActionType?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    // MARK: - Quick Actions Registration
    
    /// Registers quick actions dynamically based on user's premium status.
    /// Call this on app launch and whenever premium status changes.
    func registerQuickActions() {
        let isPremium = PaywallManager.shared.isPremium
        
        // Track registration for analytics
        print("🎬 QuickActionsManager: Registering quick actions (Premium: \(isPremium))")
        CrashReporter.logMessage("QuickActions registered - Premium: \(isPremium)", level: .info)
        
        var shortcutItems: [UIApplicationShortcutItem] = []
        
        if isPremium {
            // Premium users: Show troubleshooting and feedback only (NO discount)
            shortcutItems = [
                createShortcutItem(type: .autoFix),
                createShortcutItem(type: .giveFeedback)
            ]
        } else {
            // Free users: Show discount offer, feedback, and troubleshooting
            shortcutItems = [
                createShortcutItem(type: .claimDiscount),
                createShortcutItem(type: .giveFeedback),
                createShortcutItem(type: .autoFix)
            ]
        }
        
        // Set the shortcut items on the application (must be on main thread)
        DispatchQueue.main.async {
            UIApplication.shared.shortcutItems = shortcutItems
            
            // Verify they were set
            let actualItems = UIApplication.shared.shortcutItems ?? []
            print("✅ QuickActionsManager: Registered \(shortcutItems.count) quick actions")
            print("✅ QuickActionsManager: System has \(actualItems.count) shortcut items")
            shortcutItems.forEach { item in
                print("   - \(item.localizedTitle)")
            }
            
            // Double-check by reading back
            if actualItems.count != shortcutItems.count {
                print("⚠️ QuickActionsManager: Warning - Item count mismatch! Expected \(shortcutItems.count), got \(actualItems.count)")
            }
        }
    }
    
    /// Creates a UIApplicationShortcutItem for a given action type
    private func createShortcutItem(type: QuickActionType) -> UIApplicationShortcutItem {
        return UIApplicationShortcutItem(
            type: type.rawValue,
            localizedTitle: type.title,
            localizedSubtitle: type.subtitle,
            icon: type.icon,
            userInfo: [
                "actionType": type.rawValue as NSSecureCoding
            ]
        )
    }
    
    // MARK: - Quick Action Handling
    
    /// Handles a quick action when the app is launched or brought to foreground.
    /// Call this from application(_:performActionFor:) or scene(_:willConnectTo:options:)
    /// - Parameter shortcutItem: The shortcut item that was triggered
    /// - Returns: true if the action was handled, false otherwise
    @discardableResult
    func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        // Parse the action type
        guard let actionType = QuickActionType(rawValue: shortcutItem.type) else {
            print("⚠️ QuickActionsManager: Unknown quick action type: \(shortcutItem.type)")
            return false
        }
        
        print("🚀 QuickActionsManager: Handling quick action: \(actionType.title)")
        print("🚀 QuickActionsManager: Action type raw value: \(actionType.rawValue)")
        CrashReporter.logMessage("QuickAction triggered: \(actionType.rawValue)", level: .info)
        
        // Track analytics
        trackQuickActionUsage(actionType)
        
        // Safety check: Prevent showing discount to premium users
        if actionType == .claimDiscount && PaywallManager.shared.isPremium {
            print("⚠️ QuickActionsManager: Attempted to show discount to premium user - blocking")
            CrashReporter.logMessage("QuickAction: Blocked discount for premium user", level: .warning)
            return false
        }
        
        // Set the triggered action for deep-linking
        print("📤 QuickActionsManager: Setting triggered action and posting notification")
        
        // Set on main thread immediately
        DispatchQueue.main.async { [weak self] in
            self?.triggeredAction = actionType
            print("📤 QuickActionsManager: Triggered action set to: \(actionType.title)")
        }
        
        // Post notification immediately (multiple times to ensure it's received)
        DispatchQueue.main.async {
            print("📤 QuickActionsManager: Posting notification #1 with action type: \(actionType.title)")
            NotificationCenter.default.post(
                name: .quickActionTriggered,
                object: actionType,
                userInfo: ["actionType": actionType.rawValue]
            )
        }
        
        // Post again after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("📤 QuickActionsManager: Posting notification #2 (delayed)")
            NotificationCenter.default.post(
                name: .quickActionTriggered,
                object: actionType,
                userInfo: ["actionType": actionType.rawValue]
            )
        }
        
        // Post one more time after longer delay (for app launch scenarios)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("📤 QuickActionsManager: Posting notification #3 (long delay)")
            NotificationCenter.default.post(
                name: .quickActionTriggered,
                object: actionType,
                userInfo: ["actionType": actionType.rawValue]
            )
        }
        
        return true
    }
    
    /// Clears the triggered action after it has been handled
    func clearTriggeredAction() {
        triggeredAction = nil
    }
    
    // MARK: - Analytics
    
    /// Tracks quick action usage for analytics
    private func trackQuickActionUsage(_ actionType: QuickActionType) {
        // Log to crash reporter for analytics
        CrashReporter.setCustomKey("last_quick_action", value: actionType.rawValue)
        CrashReporter.setCustomKey("quick_action_timestamp", value: ISO8601DateFormatter().string(from: Date()))
        
        // You can add additional analytics here (e.g., Firebase, Mixpanel, etc.)
        print("📊 QuickActionsManager: Tracked usage - \(actionType.rawValue)")
    }
    
    // MARK: - Premium Status Updates
    
    /// Call this method whenever the user's premium status changes
    /// to update the quick actions accordingly
    func refreshQuickActions() {
        registerQuickActions()
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    /// Posted when a quick action is triggered
    static let quickActionTriggered = Notification.Name("quickActionTriggered")
}

