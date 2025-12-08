import Foundation
import UIKit

/// Service for sending user feedback via multiple channels (email, webhook, Telegram/X bot)
final class FeedbackService {
    
    static let shared = FeedbackService()
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Your email address to receive feedback
    var feedbackEmail: String = "iosnotewall@gmail.com"
    
    /// EmailJS Configuration (automatic email sending)
    var emailJSPublicKey: String = "61naWpldC4Y0QxSEq"
    var emailJSServiceID: String? = "service_tfn0kub"
    var emailJSTemplateID: String? = "template_kome3pb"
    
    /// Email webhook URL (alternative - if not using EmailJS)
    /// Set this to your Vercel API URL: "https://your-project.vercel.app/api/send-feedback"
    var emailWebhookURL: String? = "https://vercel-email-api-rho.vercel.app/api/send-feedback"
    
    /// Webhook URL for database storage (optional)
    /// Example: "https://your-api.com/api/feedback"
    var webhookURL: String? = nil
    
    /// Telegram Bot Token (optional)
    /// Get from @BotFather on Telegram
    var telegramBotToken: String? = nil
    
    /// Telegram Chat ID (optional)
    /// Your personal chat ID or group ID
    var telegramChatID: String? = nil
    
    /// X (Twitter) Webhook URL (optional)
    /// If you have a bot/webhook set up
    var xWebhookURL: String? = nil
    
    // MARK: - Send Feedback
    
    /// Sends feedback automatically in background (no user interaction needed)
    func sendFeedback(
        reason: String,
        details: String,
        isPremium: Bool,
        completion: @escaping (Bool, String?) -> Void
    ) {
        var successCount = 0
        var errorMessages: [String] = []
        let group = DispatchGroup()
        
        // 1. Send via Email Webhook (Vercel API) - PRIMARY METHOD (EmailJS doesn't work from iOS)
        if let emailWebhook = emailWebhookURL, !emailWebhook.isEmpty {
            group.enter()
            sendFeedbackViaEmailWebhook(
                url: emailWebhook,
                reason: reason,
                details: details,
                isPremium: isPremium
            ) { success, error in
                if success {
                    successCount += 1
                    #if DEBUG
                    print("✅ FeedbackService: Email sent automatically via webhook")
                    #endif
                } else if let error = error {
                    errorMessages.append("Email: \(error)")
                    #if DEBUG
                    print("⚠️ FeedbackService: Failed to send email: \(error ?? "Unknown")")
                    #endif
                }
                group.leave()
            }
        }
        // 2. Fallback: Try EmailJS (usually fails from iOS, but try anyway)
        else if let serviceID = emailJSServiceID, let templateID = emailJSTemplateID {
            group.enter()
            sendFeedbackViaEmailJS(
                reason: reason,
                details: details,
                isPremium: isPremium
            ) { success, error in
                if success {
                    successCount += 1
                    #if DEBUG
                    print("✅ FeedbackService: Email sent automatically via EmailJS")
                    #endif
                } else if let error = error {
                    errorMessages.append("EmailJS: \(error)")
                    #if DEBUG
                    print("⚠️ FeedbackService: Failed to send email via EmailJS: \(error ?? "Unknown")")
                    #endif
                }
                group.leave()
            }
        }
        
        // 3. Send via Webhook (database)
        if let webhookURL = webhookURL, !webhookURL.isEmpty {
            group.enter()
            sendFeedbackViaWebhook(
                url: webhookURL,
                reason: reason,
                details: details,
                isPremium: isPremium
            ) { success, error in
                if success {
                    successCount += 1
                } else if let error = error {
                    errorMessages.append("Webhook: \(error)")
                }
                group.leave()
            }
        }
        
        // 3. Send via Telegram Bot
        if let botToken = telegramBotToken, let chatID = telegramChatID {
            group.enter()
            sendFeedbackViaTelegram(
                botToken: botToken,
                chatID: chatID,
                reason: reason,
                details: details,
                isPremium: isPremium
            ) { success, error in
                if success {
                    successCount += 1
                } else if let error = error {
                    errorMessages.append("Telegram: \(error)")
                }
                group.leave()
            }
        }
        
        // 4. Send via X (Twitter) Webhook
        if let xWebhook = xWebhookURL, !xWebhook.isEmpty {
            group.enter()
            sendFeedbackViaXWebhook(
                url: xWebhook,
                reason: reason,
                details: details,
                isPremium: isPremium
            ) { success, error in
                if success {
                    successCount += 1
                } else if let error = error {
                    errorMessages.append("X: \(error)")
                }
                group.leave()
            }
        }
        
        // Wait for all requests to complete
        group.notify(queue: .main) {
            let overallSuccess = successCount > 0
            let errorMessage = errorMessages.isEmpty ? nil : errorMessages.joined(separator: "; ")
            completion(overallSuccess, errorMessage)
        }
    }
    
    // MARK: - EmailJS (Automatic Email Sending)
    
    /// Sends feedback email automatically via EmailJS (invisible to user)
    private func sendFeedbackViaEmailJS(
        reason: String,
        details: String,
        isPremium: Bool,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard let serviceID = emailJSServiceID, let templateID = emailJSTemplateID else {
            completion(false, "EmailJS not configured (missing serviceID or templateID)")
            return
        }
        
        let emailContent = createEmailContent(reason: reason, details: details, isPremium: isPremium)
        
        let emailJSURL = "https://api.emailjs.com/api/v1.0/email/send"
        
        guard let url = URL(string: emailJSURL) else {
            completion(false, "Invalid EmailJS URL")
            return
        }
        
        // EmailJS expects this format
        // Template variables: {{email}}, {{subject}}, {{message}}, {{reason}}, {{is_premium}}, {{timestamp}}, {{details}}
        let templateParams: [String: Any] = [
            "email": feedbackEmail,  // This goes to "To Email" field
            "subject": emailContent.subject,
            "message": emailContent.body,
            "reason": reason,
            "details": details.isEmpty ? "No additional details provided." : details,
            "is_premium": isPremium ? "Premium User" : "Free User",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "app_name": "NoteWall"
        ]
        
        let requestBody: [String: Any] = [
            "service_id": serviceID,
            "template_id": templateID,
            "user_id": emailJSPublicKey,
            "template_params": templateParams
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(false, "Failed to encode EmailJS data: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    completion(true, nil)
                } else {
                    let errorMsg = String(data: data ?? Data(), encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                    completion(false, errorMsg)
                }
            } else {
                completion(false, "Invalid response")
            }
        }.resume()
    }
    
    // MARK: - Email (Automatic via Webhook - Fallback)
    
    /// Sends feedback email automatically via webhook (invisible to user)
    private func sendFeedbackViaEmailWebhook(
        url: String,
        reason: String,
        details: String,
        isPremium: Bool,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard let webhookURL = URL(string: url) else {
            completion(false, "Invalid email webhook URL")
            return
        }
        
        let emailContent = createEmailContent(reason: reason, details: details, isPremium: isPremium)
        
        let feedbackData: [String: Any] = [
            "to": feedbackEmail,
            "subject": emailContent.subject,
            "body": emailContent.body,
            "reason": reason,
            "details": details,
            "isPremium": isPremium,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "platform": "iOS",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "deviceModel": UIDevice.current.model,
            "osVersion": UIDevice.current.systemVersion
        ]
        
        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: feedbackData)
        } catch {
            completion(false, "Failed to encode email data: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    completion(true, nil)
                } else {
                    let errorMsg = String(data: data ?? Data(), encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                    completion(false, errorMsg)
                }
            } else {
                completion(false, "Invalid response")
            }
        }.resume()
    }
    
    /// Creates email content for feedback
    func createEmailContent(reason: String, details: String, isPremium: Bool) -> (subject: String, body: String) {
        let subject = "📱 NoteWall Exit Feedback - \(reason)"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let formattedDate = dateFormatter.string(from: Date())
        
        let body = """
        Hi,
        
        A NoteWall user submitted exit feedback:
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        📋 REASON:
        \(reason)
        
        👤 USER TYPE:
        \(isPremium ? "Premium User" : "Free User")
        
        📅 TIMESTAMP:
        \(formattedDate)
        
        💬 ADDITIONAL DETAILS:
        \(details.isEmpty ? "No additional details provided." : details)
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        This feedback was collected via the exit-intercept Quick Action.
        
        Best regards,
        NoteWall Feedback System
        """
        
        return (subject, body)
    }
    
    // MARK: - Webhook (Database)
    
    private func sendFeedbackViaWebhook(
        url: String,
        reason: String,
        details: String,
        isPremium: Bool,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard let webhookURL = URL(string: url) else {
            completion(false, "Invalid webhook URL")
            return
        }
        
        let feedbackData: [String: Any] = [
            "reason": reason,
            "details": details,
            "isPremium": isPremium,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "platform": "iOS",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "deviceModel": UIDevice.current.model,
            "osVersion": UIDevice.current.systemVersion
        ]
        
        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: feedbackData)
        } catch {
            completion(false, "Failed to encode feedback data: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    completion(true, nil)
                } else {
                    completion(false, "HTTP \(httpResponse.statusCode)")
                }
            } else {
                completion(false, "Invalid response")
            }
        }.resume()
    }
    
    // MARK: - Telegram Bot
    
    private func sendFeedbackViaTelegram(
        botToken: String,
        chatID: String,
        reason: String,
        details: String,
        isPremium: Bool,
        completion: @escaping (Bool, String?) -> Void
    ) {
        let telegramAPIURL = "https://api.telegram.org/bot\(botToken)/sendMessage"
        
        guard let url = URL(string: telegramAPIURL) else {
            completion(false, "Invalid Telegram API URL")
            return
        }
        
        let message = """
        📱 *NoteWall Exit Feedback*
        
        *Reason:* \(reason)
        *Premium:* \(isPremium ? "Yes" : "No")
        *Time:* \(ISO8601DateFormatter().string(from: Date()))
        
        *Details:*
        \(details.isEmpty ? "No additional details." : details)
        """
        
        let parameters: [String: Any] = [
            "chat_id": chatID,
            "text": message,
            "parse_mode": "Markdown"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(false, "Failed to encode Telegram message: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    completion(true, nil)
                } else {
                    let errorMsg = String(data: data ?? Data(), encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                    completion(false, errorMsg)
                }
            } else {
                completion(false, "Invalid response")
            }
        }.resume()
    }
    
    // MARK: - X (Twitter) Webhook
    
    private func sendFeedbackViaXWebhook(
        url: String,
        reason: String,
        details: String,
        isPremium: Bool,
        completion: @escaping (Bool, String?) -> Void
    ) {
        // Same as webhook, but you can customize the payload for X
        sendFeedbackViaWebhook(
            url: url,
            reason: reason,
            details: details,
            isPremium: isPremium,
            completion: completion
        )
    }
}

