import UIKit
import SwiftUI
import SuperwallKit

/// SceneDelegate for handling Quick Actions in multi-scene apps
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    // MARK: - Orientation Lock
    
    /// Return only portrait orientation mask
    func windowScene(_ windowScene: UIWindowScene, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
    
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        print("🎬 SceneDelegate: Scene will connect")
        
        // Handle deep links on cold launch
        if let url = connectionOptions.urlContexts.first?.url {
            let handled = Superwall.handleDeepLink(url)
            if handled {
                print("🔗 SceneDelegate: Deep link handled by Superwall")
            }
        } else if let userActivity = connectionOptions.userActivities.first(where: { $0.activityType == NSUserActivityTypeBrowsingWeb }),
                  let url = userActivity.webpageURL {
            let handled = Superwall.handleDeepLink(url)
            if handled {
                print("🔗 SceneDelegate: Universal link handled by Superwall")
            }
        }
        
        // Handle Quick Action if present
        if let shortcutItem = connectionOptions.shortcutItem {
            print("🎬 SceneDelegate: Scene connecting with Quick Action - \(shortcutItem.localizedTitle)")
            QuickActionsManager.shared.handleQuickAction(shortcutItem)
        }
    }
    
    // Handle deep links when app is already running
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        
        // Handle notewall:// URL scheme (shortcut callback)
        if url.scheme?.lowercased() == "notewall" {
            let lowerHost = url.host?.lowercased()
            let lowerPath = url.path.lowercased()
            if lowerHost == "wallpaper-updated" || lowerPath.contains("wallpaper-updated") {
                print("✅ SceneDelegate: Received wallpaper-updated callback")
                // Set persistent flag so allowPermissions step can detect it
                UserDefaults.standard.set(true, forKey: "shortcut_wallpaper_applied")
                NotificationCenter.default.post(name: .shortcutWallpaperApplied, object: nil)
                return
            }
        }
        
        let handled = Superwall.handleDeepLink(url)
        if handled {
            print("🔗 SceneDelegate: Deep link handled by Superwall (app running)")
        }
    }
    
    // Handle universal links
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            let handled = Superwall.handleDeepLink(url)
            if handled {
                print("🔗 SceneDelegate: Universal link handled by Superwall")
            }
        }
    }
    
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        print("🎬 SceneDelegate: Performing Quick Action - \(shortcutItem.type)")
        print("🎬 SceneDelegate: Title - \(shortcutItem.localizedTitle)")
        
        // Handle the quick action
        let handled = QuickActionsManager.shared.handleQuickAction(shortcutItem)
        
        print("✅ SceneDelegate: Quick Action handled: \(handled)")
        
        // Call completion handler
        completionHandler(handled)
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        print("🎬 SceneDelegate: Scene did become active")
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        print("🎬 SceneDelegate: Scene will enter foreground")
        // Re-sync subscription status from StoreKit when app returns to foreground.
        // This catches any renewals, new purchases, or expirations that happened
        // while the app was in the background or terminated.
        Task { @MainActor in
            await PaywallManager.shared.syncSubscriptionStatusFromStoreKit()
        }
    }
}

