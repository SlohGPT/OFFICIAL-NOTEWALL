import UIKit
import SwiftUI
import SuperwallKit

/// AppDelegate for handling Quick Actions and other UIApplication-level events
class AppDelegate: NSObject, UIApplicationDelegate {
    
    // MARK: - Orientation Lock
    
    /// Lock app to portrait orientation only
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
    
    // MARK: - Application Lifecycle
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("📱 AppDelegate: Application did finish launching")
        
        // Register Quick Actions on app launch
        QuickActionsManager.shared.registerQuickActions()
        
        // Check if app was launched via a Quick Action
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            print("🎬 AppDelegate: App launched via Quick Action")
            QuickActionsManager.shared.handleQuickAction(shortcutItem)
            // Return false to indicate we handled the shortcut (prevents performActionFor from being called)
            return false
        }
        
        return true
    }
    
    // MARK: - Quick Actions Handling
    
    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        print("🎬 AppDelegate: Performing Quick Action - \(shortcutItem.type)")
        print("🎬 AppDelegate: Title - \(shortcutItem.localizedTitle)")
        
        // Handle the quick action
        let handled = QuickActionsManager.shared.handleQuickAction(shortcutItem)
        
        print("✅ AppDelegate: Quick Action handled: \(handled)")
        
        // Call completion handler
        completionHandler(handled)
    }
    
    // MARK: - Scene Configuration
    
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Handle Quick Action if present in connection options
        if let shortcutItem = options.shortcutItem {
            print("🎬 AppDelegate: Scene connecting with Quick Action")
            QuickActionsManager.shared.handleQuickAction(shortcutItem)
        }
        
        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }
    
    // MARK: - Deep Link Handling
    
    // Handle URL schemes (for apps without SceneDelegate)
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // Handle Superwall deep links
        let handled = Superwall.handleDeepLink(url)
        if handled {
            print("🔗 AppDelegate: Deep link handled by Superwall")
            return true
        }
        return false
    }
    
    // Handle universal links
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            let handled = Superwall.handleDeepLink(url)
            if handled {
                print("🔗 AppDelegate: Universal link handled by Superwall")
                return true
            }
        }
        return false
    }
}

