import Foundation
import UserNotifications
import UIKit

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Show notifications even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Requests notification permissions
    func requestPermission(completion: @escaping (Bool) -> Void) {
        // Track permission prompt shown
        AnalyticsService.shared.trackPermissionPrompt(
            permissionType: PermissionType.notifications.rawValue,
            action: .shown,
            stepId: "notification_permission"
        )
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                #if DEBUG
                if let error = error {
                    print("❌ Notification permission error: \(error)")
                }
                print("🔔 Notification permission granted: \(granted)")
                #endif
                
                // Track permission result
                AnalyticsService.shared.trackPermissionPrompt(
                    permissionType: PermissionType.notifications.rawValue,
                    action: granted ? .accepted : .denied,
                    stepId: "notification_permission"
                )
                
                completion(granted)
            }
        }
    }
    
    /// Schedules the trial ending reminder (24 hours after start)
    func scheduleTrialReminder() {
        // 1. Check if we have permission
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                #if DEBUG
                print("⚠️ Cannot schedule trial reminder: Notifications not authorized")
                #endif
                return
            }
            
            // 2. Create content
            let content = UNMutableNotificationContent()
            content.title = "Trial Ending Soon"
            content.body = "Your 3-day free trial will end soon. We hope you're enjoying NoteWall!"
            content.sound = .default
            
            // 3. Create trigger (24 hours from now)
            // For production: 24 * 60 * 60 = 86400 seconds
            let timeInterval: TimeInterval = 86400 
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
            
            // 4. Create request
            let request = UNNotificationRequest(
                identifier: "trial_reminder",
                content: content,
                trigger: trigger
            )
            
            // 5. Add request
            UNUserNotificationCenter.current().add(request) { error in
                #if DEBUG
                if let error = error {
                    print("❌ Failed to schedule trial reminder: \(error)")
                } else {
                    print("✅ Trial reminder scheduled for 24 hours from now")
                }
                #endif
            }
        }
    }
    
    // MARK: - Debug / Testing Methods
    
    #if DEBUG
    /// Schedules a test notification to fire in 5 seconds (DEBUG only)
    func scheduleTestNotification() {
        requestPermission { granted in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "Test Notification"
            content.body = "This is how the trial reminder will look."
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
            print("🧪 Test notification scheduled for 5 seconds from now")
        }
    }
    #endif
}

