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
    
    // Handle notification taps
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String, type == "abandoned_onboarding" {
            #if DEBUG
            print("🔔 User tapped abandoned onboarding notification")
            #endif
            // The app will automatically show onboarding (it checks hasCompletedSetup on launch)
            // and will resume from the saved page via onboarding_lastPageRawValue
            // Clear badge
            DispatchQueue.main.async {
                UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
            }
        }
        
        completionHandler()
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
            content.title = NSLocalizedString("Trial Ending Soon", comment: "")
            content.body = NSLocalizedString("Your 3-day free trial will end soon. We hope you're enjoying NoteWall!", comment: "")
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
    
    // MARK: - Abandoned Onboarding Notifications
    
    /// Schedules reminders for users who quit the onboarding flow without completing it.
    /// - 1 hour after quitting: First gentle nudge
    /// - 24 hours after quitting: Second reminder if still not completed
    /// Each call cancels previously scheduled abandoned onboarding notifications before rescheduling.
    func scheduleAbandonedOnboardingReminders() {
        // Don't schedule if user already completed onboarding
        guard !UserDefaults.standard.bool(forKey: "hasCompletedSetup") else {
            #if DEBUG
            print("🔔 Skipping abandoned onboarding reminders: User already completed setup")
            #endif
            return
        }
        
        // Check if we have permission
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                #if DEBUG
                print("⚠️ Cannot schedule abandoned onboarding reminders: Notifications not authorized")
                #endif
                return
            }
            
            // Cancel any existing abandoned onboarding notifications first
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["abandoned_onboarding_1hr", "abandoned_onboarding_24hr"]
            )
            
            // --- 1 Hour Reminder ---
            let userName = UserDefaults.standard.string(forKey: "onboarding_userName") ?? ""
            let hasName = !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            let content1hr = UNMutableNotificationContent()
            content1hr.title = hasName ? String(format: NSLocalizedString("🚨 %@, 3 things forgotten today", comment: ""), userName) : NSLocalizedString("🚨 3 things forgotten today", comment: "")
            content1hr.body = NSLocalizedString("Stop the cycle. Finish setup in 60 seconds and capture every idea before it vanishes.", comment: "")
            content1hr.sound = .default
            content1hr.badge = 1
            content1hr.userInfo = ["type": "abandoned_onboarding", "reminder": "1hr"]
            
            let trigger1hr = UNTimeIntervalNotificationTrigger(
                timeInterval: 3600, // 1 hour
                repeats: false
            )
            
            let request1hr = UNNotificationRequest(
                identifier: "abandoned_onboarding_1hr",
                content: content1hr,
                trigger: trigger1hr
            )
            
            // --- 24 Hour Reminder ---
            let content24hr = UNMutableNotificationContent()
            content24hr.title = hasName ? String(format: NSLocalizedString("🚨 %@, what did you forget?", comment: ""), userName) : NSLocalizedString("🚨 What did you forget?", comment: "")
            content24hr.body = NSLocalizedString("Yeah, exactly. Shower thoughts, brilliant ideas, tasks you swore you'd do—all gone. Finish setup while you still remember you wanted this.", comment: "")
            content24hr.sound = .default
            content24hr.badge = 1
            content24hr.userInfo = ["type": "abandoned_onboarding", "reminder": "24hr"]
            
            let trigger24hr = UNTimeIntervalNotificationTrigger(
                timeInterval: 86400, // 24 hours
                repeats: false
            )
            
            let request24hr = UNNotificationRequest(
                identifier: "abandoned_onboarding_24hr",
                content: content24hr,
                trigger: trigger24hr
            )
            
            // Add both requests
            UNUserNotificationCenter.current().add(request1hr) { error in
                #if DEBUG
                if let error = error {
                    print("❌ Failed to schedule 1hr abandoned onboarding reminder: \(error)")
                } else {
                    print("✅ 1hr abandoned onboarding reminder scheduled")
                }
                #endif
            }
            
            UNUserNotificationCenter.current().add(request24hr) { error in
                #if DEBUG
                if let error = error {
                    print("❌ Failed to schedule 24hr abandoned onboarding reminder: \(error)")
                } else {
                    print("✅ 24hr abandoned onboarding reminder scheduled")
                }
                #endif
            }
        }
    }
    
    /// Cancels all abandoned onboarding reminders (call when user completes onboarding)
    func cancelAbandonedOnboardingReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["abandoned_onboarding_1hr", "abandoned_onboarding_24hr"]
        )
        // Also clear badge
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        }
        #if DEBUG
        print("🔔 Cancelled abandoned onboarding reminders")
        #endif
    }
    
    // MARK: - Debug / Testing Methods
    
    #if DEBUG
    /// Schedules a test notification to fire in 5 seconds (DEBUG only)
    func scheduleTestNotification() {
        requestPermission { granted in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("Test Notification", comment: "")
            content.body = NSLocalizedString("This is how the trial reminder will look.", comment: "")
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
            print("🧪 Test notification scheduled for 5 seconds from now")
        }
    }
    #endif
}

