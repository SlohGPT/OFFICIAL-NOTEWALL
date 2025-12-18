import UIKit
import SwiftUI

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
        
        // Handle Quick Action if present
        if let shortcutItem = connectionOptions.shortcutItem {
            print("🎬 SceneDelegate: Scene connecting with Quick Action - \(shortcutItem.localizedTitle)")
            QuickActionsManager.shared.handleQuickAction(shortcutItem)
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
    }
}

