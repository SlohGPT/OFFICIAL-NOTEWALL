//
//  AnalyticsService.swift
//  NoteWall
//
//  Firebase Analytics wrapper with type-safe events and properties
//

import Foundation
import FirebaseAnalytics

// MARK: - Analytics Service (Singleton)

/// Central analytics service wrapping Firebase Analytics
/// Use this as the single entry point for all analytics tracking
final class AnalyticsService {
    
    // MARK: - Singleton
    static let shared = AnalyticsService()
    
    // MARK: - Configuration
    
    /// Controls whether analytics are actually sent to Firebase
    /// In DEBUG builds, events are logged locally but optionally not sent
    private var isEnabled: Bool = true
    
    /// Controls verbose console logging of events (useful for debugging)
    private var isVerboseLoggingEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    // MARK: - Session State
    
    /// Tracks onboarding start time for duration calculations
    private var onboardingStartTime: Date?
    
    /// Tracks current step start time for time-on-step calculations
    private var stepStartTimes: [String: Date] = [:]
    
    /// Tracks if onboarding_start has been fired this session
    private var hasFiredOnboardingStart: Bool = false
    
    /// Tracks screen views to prevent duplicate firing
    private var firedScreenViews: Set<String> = []
    
    /// Current onboarding flow variant (if A/B testing)
    private var currentFlowId: String = "default"
    private var currentVariantId: String = "v1"
    
    // MARK: - Initialization
    
    private init() {
        // Configure analytics based on build configuration
        #if DEBUG
        // In DEBUG, we can optionally disable sending to Firebase
        // Set to false to only log locally during development
        isEnabled = true
        
        // Enable verbose logging in debug
        isVerboseLoggingEnabled = true
        #else
        isEnabled = true
        isVerboseLoggingEnabled = false
        #endif
    }
    
    // MARK: - Configuration Methods
    
    /// Enable or disable analytics sending (useful for user privacy preferences)
    func setAnalyticsEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Analytics.setAnalyticsCollectionEnabled(enabled)
        logDebug("Analytics collection \(enabled ? "enabled" : "disabled")")
    }
    
    /// Set the current onboarding flow/variant for A/B testing
    func setOnboardingVariant(flowId: String, variantId: String) {
        currentFlowId = flowId
        currentVariantId = variantId
    }
    
    /// Reset session state (call when user restarts onboarding)
    func resetOnboardingSession() {
        onboardingStartTime = nil
        stepStartTimes.removeAll()
        hasFiredOnboardingStart = false
        firedScreenViews.removeAll()
    }
    
    // MARK: - Core Logging
    
    /// Log an analytics event to Firebase
    /// - Parameters:
    ///   - event: The event to log
    ///   - additionalParams: Any extra parameters to merge
    func logEvent(_ event: AnalyticsEvent, additionalParams: [String: Any]? = nil) {
        var params = event.parameters
        
        // Merge additional params if provided
        if let additionalParams = additionalParams {
            for (key, value) in additionalParams {
                params[key] = value
            }
        }
        
        // Validate and sanitize parameters
        let sanitizedParams = sanitizeParameters(params)
        
        // Log to console in debug mode
        logDebug("📊 Event: \(event.name) | Params: \(sanitizedParams)")
        
        // Send to Firebase if enabled
        guard isEnabled else { return }
        Analytics.logEvent(event.name, parameters: sanitizedParams.isEmpty ? nil : sanitizedParams)
    }
    
    /// Log a screen view event
    /// - Parameters:
    ///   - screenName: The screen name
    ///   - screenClass: The screen class (optional, defaults to screen name)
    func trackScreenView(screenName: String, screenClass: String? = nil) {
        let event = AnalyticsEvent.screenView(
            screenName: screenName,
            screenClass: screenClass ?? screenName
        )
        logEvent(event)
    }
    
    /// Log a user property
    func setUserProperty(_ value: String?, forName name: String) {
        let sanitizedName = sanitizePropertyName(name)
        let sanitizedValue = value.flatMap { sanitizePropertyValue($0) }
        
        logDebug("📊 User Property: \(sanitizedName) = \(sanitizedValue ?? "nil")")
        
        guard isEnabled else { return }
        Analytics.setUserProperty(sanitizedValue, forName: sanitizedName)
    }
    
    /// Set the user ID for analytics
    func setUserId(_ userId: String?) {
        logDebug("📊 User ID: \(userId ?? "nil")")
        
        guard isEnabled else { return }
        Analytics.setUserID(userId)
    }
    
    // MARK: - Screen View Tracking (Fire-Once Mechanism)
    
    /// Track a screen view only once per session (prevents duplicate firing due to SwiftUI re-renders)
    /// - Parameters:
    ///   - screenName: The screen name
    ///   - screenClass: The screen class
    ///   - identifier: Unique identifier for this screen instance
    func trackScreenViewOnce(screenName: String, screenClass: String? = nil, identifier: String? = nil) {
        let key = identifier ?? screenName
        
        guard !firedScreenViews.contains(key) else {
            logDebug("📊 Screen view already fired: \(screenName) (skipping)")
            return
        }
        
        firedScreenViews.insert(key)
        trackScreenView(screenName: screenName, screenClass: screenClass)
    }
    
    /// Reset the fire-once tracking for a specific screen
    func resetScreenViewTracking(for identifier: String) {
        firedScreenViews.remove(identifier)
    }
    
    // MARK: - Tap/Action Tracking
    
    /// Track a user tap or action
    func trackTap(action: String, screen: String, element: String? = nil, additionalParams: [String: Any]? = nil) {
        let event = AnalyticsEvent.tap(action: action, screen: screen, element: element)
        logEvent(event, additionalParams: additionalParams)
    }
    
    // MARK: - Onboarding Tracking
    
    /// Track onboarding start (fires only once per session)
    func trackOnboardingStart() {
        guard !hasFiredOnboardingStart else {
            logDebug("📊 onboarding_start already fired (skipping)")
            return
        }
        
        hasFiredOnboardingStart = true
        onboardingStartTime = Date()
        
        let event = AnalyticsEvent.onboardingStart(flowId: currentFlowId, variantId: currentVariantId)
        logEvent(event)
    }
    
    /// Track an onboarding step view
    func trackOnboardingStep(stepId: String, stepIndex: Int, stepName: String? = nil) {
        // Record step start time
        stepStartTimes[stepId] = Date()
        
        let event = AnalyticsEvent.onboardingStepView(
            stepId: stepId,
            stepIndex: stepIndex,
            stepName: stepName,
            flowId: currentFlowId,
            variantId: currentVariantId
        )
        logEvent(event)
    }
    
    /// Track an onboarding step completion with duration
    func trackOnboardingStepComplete(stepId: String, stepIndex: Int, stepName: String? = nil) {
        let durationMs = calculateStepDuration(stepId: stepId)
        
        let event = AnalyticsEvent.onboardingStepComplete(
            stepId: stepId,
            stepIndex: stepIndex,
            stepName: stepName,
            durationMs: durationMs,
            flowId: currentFlowId,
            variantId: currentVariantId
        )
        logEvent(event)
    }
    
    /// Track an onboarding action (next, back, skip, etc.)
    func trackOnboardingAction(action: OnboardingAction, stepId: String, stepIndex: Int, additionalParams: [String: Any]? = nil) {
        let event = AnalyticsEvent.onboardingAction(
            action: action,
            stepId: stepId,
            stepIndex: stepIndex,
            flowId: currentFlowId,
            variantId: currentVariantId
        )
        logEvent(event, additionalParams: additionalParams)
    }
    
    /// Track a quiz answer in onboarding
    func trackQuizAnswer(question: String, answer: String, stepId: String, stepIndex: Int) {
        let event = AnalyticsEvent.quizAnswer(
            question: question,
            answer: answer,
            stepId: stepId,
            stepIndex: stepIndex,
            flowId: currentFlowId,
            variantId: currentVariantId
        )
        logEvent(event)
    }
    
    /// Track a permission prompt (notification, photo library, etc.)
    func trackPermissionPrompt(permissionType: String, action: PermissionAction, stepId: String) {
        let event = AnalyticsEvent.permissionPrompt(
            permissionType: permissionType,
            action: action,
            stepId: stepId,
            flowId: currentFlowId,
            variantId: currentVariantId
        )
        logEvent(event)
    }
    
    /// Track onboarding abandonment
    func trackOnboardingAbandon(stepId: String, stepIndex: Int, reason: AbandonReason) {
        let totalDurationMs = calculateOnboardingDuration()
        
        let event = AnalyticsEvent.onboardingAbandon(
            stepId: stepId,
            stepIndex: stepIndex,
            reason: reason,
            totalDurationMs: totalDurationMs,
            flowId: currentFlowId,
            variantId: currentVariantId
        )
        logEvent(event)
    }
    
    /// Track onboarding completion
    func trackOnboardingComplete() {
        let totalDurationMs = calculateOnboardingDuration()
        
        let event = AnalyticsEvent.onboardingComplete(
            totalDurationMs: totalDurationMs,
            flowId: currentFlowId,
            variantId: currentVariantId
        )
        logEvent(event)
        
        // Set user property
        setUserProperty("true", forName: AnalyticsProperty.hasCompletedOnboarding)
    }
    
    // MARK: - Paywall Tracking
    
    /// Track paywall impression
    func trackPaywallImpression(paywallId: String, trigger: String, placement: String? = nil) {
        let event = AnalyticsEvent.paywallImpression(
            paywallId: paywallId,
            trigger: trigger,
            placement: placement,
            flowId: currentFlowId,
            variantId: currentVariantId
        )
        logEvent(event)
    }
    
    /// Track plan selection on paywall
    func trackPlanSelected(productId: String, price: Double?, period: String?, currency: String?) {
        let event = AnalyticsEvent.planSelected(
            productId: productId,
            price: price,
            period: period,
            currency: currency
        )
        logEvent(event)
    }
    
    /// Track purchase start
    func trackPurchaseStart(productId: String) {
        let event = AnalyticsEvent.purchaseStart(productId: productId)
        logEvent(event)
    }
    
    /// Track successful purchase
    func trackPurchaseSuccess(productId: String, transactionId: String?, revenue: Double?, currency: String?) {
        let event = AnalyticsEvent.purchaseSuccess(
            productId: productId,
            transactionId: transactionId,
            revenue: revenue,
            currency: currency
        )
        logEvent(event)
        
        // Set user property
        setUserProperty("true", forName: AnalyticsProperty.isPremium)
    }
    
    /// Track purchase cancellation
    func trackPurchaseCancel(productId: String) {
        let event = AnalyticsEvent.purchaseCancel(productId: productId)
        logEvent(event)
    }
    
    /// Track purchase failure
    func trackPurchaseFail(productId: String, errorCode: String) {
        // Bucket error codes to prevent cardinality explosion
        let bucketedError = bucketErrorCode(errorCode)
        
        let event = AnalyticsEvent.purchaseFail(productId: productId, errorCode: bucketedError)
        logEvent(event)
    }
    
    /// Track restore tap
    func trackRestoreTap() {
        let event = AnalyticsEvent.restoreTap()
        logEvent(event)
    }
    
    /// Track restore success
    func trackRestoreSuccess() {
        let event = AnalyticsEvent.restoreSuccess()
        logEvent(event)
    }
    
    /// Track restore failure
    func trackRestoreFail(errorCode: String) {
        let bucketedError = bucketErrorCode(errorCode)
        let event = AnalyticsEvent.restoreFail(errorCode: bucketedError)
        logEvent(event)
    }
    
    /// Track paywall close
    func trackPaywallClose(paywallId: String, converted: Bool) {
        let event = AnalyticsEvent.paywallClose(paywallId: paywallId, converted: converted)
        logEvent(event)
    }
    
    // MARK: - Error Tracking
    
    /// Track an error event
    func trackError(errorType: String, errorMessage: String, screen: String? = nil) {
        // Sanitize error message to prevent PII leakage and cardinality issues
        let sanitizedMessage = sanitizeErrorMessage(errorMessage)
        
        let event = AnalyticsEvent.error(
            errorType: errorType,
            errorMessage: sanitizedMessage,
            screen: screen
        )
        logEvent(event)
    }
    
    // MARK: - Feature Usage Tracking
    
    /// Track feature usage (wallpaper export, etc.)
    func trackFeatureUsage(feature: String, additionalParams: [String: Any]? = nil) {
        let event = AnalyticsEvent.featureUsage(feature: feature)
        logEvent(event, additionalParams: additionalParams)
    }
    
    // MARK: - Retention & Session Tracking
    
    private var sessionId: String = UUID().uuidString
    private var sessionStartTimestamp: Date?
    private var installDate: Date {
        get {
            if let date = UserDefaults.standard.object(forKey: "analytics_install_date") as? Date {
                return date
            }
            let now = Date()
            UserDefaults.standard.set(now, forKey: "analytics_install_date")
            return now
        }
    }
    
    private var lastActiveDate: Date? {
        get { UserDefaults.standard.object(forKey: "analytics_last_active_date") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "analytics_last_active_date") }
    }
    
    private var totalSessionCount: Int {
        get { UserDefaults.standard.integer(forKey: "analytics_total_session_count") }
        set { UserDefaults.standard.set(newValue, forKey: "analytics_total_session_count") }
    }
    
    private var daysSinceInstall: Int {
        Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
    }
    
    private var daysSinceLastActive: Int {
        guard let lastActive = lastActiveDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: lastActive, to: Date()).day ?? 0
    }
    
    /// Track app open event with retention context
    func trackAppOpen(source: String = "direct") {
        let isFirstLaunch = totalSessionCount == 0
        let event = AnalyticsEvent.appOpen(
            isFirstLaunch: isFirstLaunch,
            daysSinceInstall: daysSinceInstall,
            sessionCount: totalSessionCount
        )
        logEvent(event)
        
        // Check if this is a returning user
        if daysSinceLastActive > 0 {
            trackUserReturned(daysInactive: daysSinceLastActive)
        }
        
        lastActiveDate = Date()
    }
    
    /// Start a new session
    func trackSessionStart() {
        sessionId = UUID().uuidString
        let lastSession = sessionStartTimestamp
        sessionStartTimestamp = Date()
        totalSessionCount += 1
        
        let daysSinceLast = lastSession.map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0 } ?? 0
        
        let event = AnalyticsEvent.sessionStart(
            sessionId: sessionId,
            sessionNumber: totalSessionCount,
            daysSinceLastSession: daysSinceLast
        )
        logEvent(event)
        
        // Track daily/weekly active
        trackDailyActive()
        trackWeeklyActive()
    }
    
    /// End the current session
    func trackSessionEnd() {
        let duration = sessionStartTimestamp.map { Int(Date().timeIntervalSince($0)) } ?? 0
        let screenViewCount = 0 // Could be tracked separately
        
        let event = AnalyticsEvent.sessionEnd(
            sessionId: sessionId,
            durationSeconds: duration,
            screensViewed: screenViewCount,
            actionsPerformed: 0
        )
        logEvent(event)
    }
    
    /// Track daily active user
    private func trackDailyActive() {
        let lastDailyKey = "analytics_last_daily_active"
        let calendar = Calendar.current
        
        if let lastDaily = UserDefaults.standard.object(forKey: lastDailyKey) as? Date,
           calendar.isDate(lastDaily, inSameDayAs: Date()) {
            return // Already tracked today
        }
        
        UserDefaults.standard.set(Date(), forKey: lastDailyKey)
        
        let event = AnalyticsEvent.dailyActive(
            daysSinceInstall: daysSinceInstall,
            isPremium: isPremiumUser,
            totalSessions: totalSessionCount
        )
        logEvent(event)
    }
    
    /// Track weekly active user
    private func trackWeeklyActive() {
        let lastWeeklyKey = "analytics_last_weekly_active"
        let calendar = Calendar.current
        
        if let lastWeekly = UserDefaults.standard.object(forKey: lastWeeklyKey) as? Date {
            let weekOfLastActive = calendar.component(.weekOfYear, from: lastWeekly)
            let currentWeek = calendar.component(.weekOfYear, from: Date())
            if weekOfLastActive == currentWeek {
                return // Already tracked this week
            }
        }
        
        UserDefaults.standard.set(Date(), forKey: lastWeeklyKey)
        
        // Estimate sessions this week (simplified)
        let sessionsThisWeek = 1
        
        let event = AnalyticsEvent.weeklyActive(
            weekNumber: calendar.component(.weekOfYear, from: Date()),
            isPremium: isPremiumUser,
            sessionsThisWeek: sessionsThisWeek
        )
        logEvent(event)
    }
    
    /// Track when a user returns after absence
    private func trackUserReturned(daysInactive: Int) {
        let event = AnalyticsEvent.userReturned(
            daysInactive: daysInactive,
            isPremium: isPremiumUser
        )
        logEvent(event)
    }
    
    // MARK: - Feature Usage Tracking
    
    private var totalNotesCreated: Int {
        get { UserDefaults.standard.integer(forKey: "analytics_total_notes_created") }
        set { UserDefaults.standard.set(newValue, forKey: "analytics_total_notes_created") }
    }
    
    private var totalWallpaperUpdates: Int {
        get { UserDefaults.standard.integer(forKey: "analytics_total_wallpaper_updates") }
        set { UserDefaults.standard.set(newValue, forKey: "analytics_total_wallpaper_updates") }
    }
    
    /// Track note creation
    func trackNoteCreated(noteLength: Int, hasEmoji: Bool, notePosition: Int) {
        totalNotesCreated += 1
        
        let event = AnalyticsEvent.noteCreated(
            noteCount: totalNotesCreated,
            characterCount: noteLength,
            hasEmoji: hasEmoji
        )
        logEvent(event)
        
        // Check for milestones
        checkNoteMilestone(totalNotesCreated)
    }
    
    /// Track note deletion
    func trackNoteDeleted(remainingNotes: Int, reason: String? = nil) {
        let event = AnalyticsEvent.noteDeleted(
            remainingNotes: remainingNotes,
            reason: reason
        )
        logEvent(event)
    }
    
    /// Track wallpaper update
    func trackWallpaperUpdated(noteCount: Int, hasBackground: Bool, backgroundType: String) {
        totalWallpaperUpdates += 1
        
        let event = AnalyticsEvent.wallpaperUpdated(
            wallpaperType: backgroundType,
            noteCount: noteCount,
            isPremium: isPremiumUser,
            updateMethod: "manual"
        )
        logEvent(event)
        
        // Check for milestones
        checkWallpaperMilestone(totalWallpaperUpdates)
    }
    
    /// Track background change
    func trackBackgroundChanged(imageSource: String, forScreen: String) {
        let event = AnalyticsEvent.backgroundChanged(
            imageSource: imageSource,
            forScreen: forScreen
        )
        logEvent(event)
    }
    
    /// Track setting change
    func trackSettingChanged(setting: String, from previousValue: String, to newValue: String) {
        let event = AnalyticsEvent.settingChanged(
            settingName: setting,
            oldValue: previousValue,
            newValue: newValue
        )
        logEvent(event)
    }
    
    /// Track share action
    func trackShareAction(contentType: String, shareDestination: String?, success: Bool) {
        let event = AnalyticsEvent.shareAction(
            contentType: contentType,
            shareDestination: shareDestination,
            success: success
        )
        logEvent(event)
    }
    
    /// Track settings opened
    func trackSettingsOpened(fromScreen: String) {
        let event = AnalyticsEvent.settingsOpened(
            fromScreen: fromScreen
        )
        logEvent(event)
    }
    
    /// Track troubleshooting accessed
    func trackTroubleshootingAccessed(issue: String?) {
        let event = AnalyticsEvent.troubleshootingAccessed(
            issue: issue
        )
        logEvent(event)
    }
    
    // MARK: - User Journey & Milestone Tracking
    
    private var isPremiumUser: Bool {
        UserDefaults.standard.bool(forKey: "analytics_is_premium_user")
    }
    
    private var conversionDate: Date? {
        UserDefaults.standard.object(forKey: "analytics_conversion_date") as? Date
    }
    
    /// Track milestone reached
    func trackMilestoneReached(milestone: String, value: Int, daysSinceInstall: Int? = nil) {
        let event = AnalyticsEvent.milestoneReached(
            milestone: milestone,
            daysSinceInstall: daysSinceInstall ?? self.daysSinceInstall,
            sessionsCount: totalSessionCount
        )
        logEvent(event)
    }
    
    /// Track conversion journey for analytics
    func trackConversionJourney(timeToConversionHours: Int, sessionsBeforeConversion: Int) {
        let event = AnalyticsEvent.conversionJourney(
            timeToConversionHours: timeToConversionHours,
            sessionsBeforeConversion: sessionsBeforeConversion,
            paywallViewsBeforeConversion: UserDefaults.standard.integer(forKey: "analytics_paywall_views"),
            onboardingCompleted: UserDefaults.standard.bool(forKey: "has_completed_onboarding")
        )
        logEvent(event)
    }
    
    /// Track trial started
    func trackTrialStarted(productId: String, trialLength: Int) {
        UserDefaults.standard.set(Date(), forKey: "analytics_trial_start_date")
        
        let event = AnalyticsEvent.trialStarted(
            productId: productId,
            trialDays: trialLength
        )
        logEvent(event)
    }
    
    /// Track trial converted to paid
    func trackTrialConverted(productId: String, revenue: Double) {
        UserDefaults.standard.set(true, forKey: "analytics_is_premium_user")
        UserDefaults.standard.set(Date(), forKey: "analytics_conversion_date")
        
        let trialStart = UserDefaults.standard.object(forKey: "analytics_trial_start_date") as? Date
        let daysInTrial = trialStart.map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0 } ?? 0
        
        let event = AnalyticsEvent.trialConverted(
            productId: productId,
            daysUsedInTrial: daysInTrial
        )
        logEvent(event)
    }
    
    /// Track trial expired without conversion
    func trackTrialExpired(productId: String, engagementScore: Double) {
        let event = AnalyticsEvent.trialExpired(
            productId: productId,
            engagementScore: Int(engagementScore)
        )
        logEvent(event)
    }
    
    /// Track subscription renewal
    func trackSubscriptionRenewed(productId: String, renewalCount: Int, totalRevenue: Double) {
        let event = AnalyticsEvent.subscriptionRenewed(
            productId: productId,
            renewalCount: renewalCount,
            totalRevenue: totalRevenue
        )
        logEvent(event)
    }
    
    /// Track subscription cancellation
    func trackSubscriptionCancelled(productId: String, reason: String, daysSubscribed: Int) {
        UserDefaults.standard.set(false, forKey: "analytics_is_premium_user")
        
        let event = AnalyticsEvent.subscriptionCancelled(
            productId: productId,
            reason: reason,
            monthsSubscribed: daysSubscribed / 30
        )
        logEvent(event)
    }
    
    /// Track churn risk detection
    func trackChurnRiskDetected(riskScore: Int, daysSinceLastActive: Int) {
        let event = AnalyticsEvent.churnRiskDetected(
            riskScore: riskScore,
            daysSinceLastActive: daysSinceLastActive,
            totalSessions: totalSessionCount
        )
        logEvent(event)
    }
    
    // MARK: - Engagement Tracking
    
    /// Track weekly engagement summary
    func trackWeeklyEngagement(sessionsThisWeek: Int, notesCreated: Int, wallpaperUpdates: Int, engagementScore: Double) {
        let event = AnalyticsEvent.weeklyEngagement(
            notesCreated: notesCreated,
            wallpapersUpdated: wallpaperUpdates,
            sessionsThisWeek: sessionsThisWeek,
            avgSessionDuration: 0, // Placeholder
            engagementScore: Int(engagementScore)
        )
        logEvent(event)
    }
    
    // MARK: - Notification Tracking
    
    /// Track notification received
    func trackNotificationReceived(notificationType: String, notificationId: String) {
        let event = AnalyticsEvent.notificationReceived(
            notificationType: notificationType,
            notificationId: notificationId
        )
        logEvent(event)
    }
    
    /// Track notification opened
    func trackNotificationOpened(notificationType: String, notificationId: String, timeToOpen: Int) {
        let event = AnalyticsEvent.notificationOpened(
            notificationType: notificationType,
            notificationId: notificationId,
            hoursAfterSent: timeToOpen / 3600
        )
        logEvent(event)
    }
    
    /// Track notification dismissed
    func trackNotificationDismissed(notificationType: String, notificationId: String) {
        let event = AnalyticsEvent.notificationDismissed(
            notificationType: notificationType,
            notificationId: notificationId
        )
        logEvent(event)
    }
    
    // MARK: - Milestone Helpers
    
    private func checkNoteMilestone(_ count: Int) {
        let milestones = [1, 5, 10, 25, 50, 100, 250, 500, 1000]
        if milestones.contains(count) {
            trackMilestoneReached(milestone: "notes_created", value: count)
        }
    }
    
    private func checkWallpaperMilestone(_ count: Int) {
        let milestones = [1, 5, 10, 25, 50, 100]
        if milestones.contains(count) {
            trackMilestoneReached(milestone: "wallpapers_updated", value: count)
        }
    }
    
    // MARK: - Private Helpers
    
    private func logDebug(_ message: String) {
        guard isVerboseLoggingEnabled else { return }
        print(message)
    }
    
    private func calculateStepDuration(stepId: String) -> Int {
        guard let startTime = stepStartTimes[stepId] else { return 0 }
        let duration = Date().timeIntervalSince(startTime)
        return Int(duration * 1000) // Convert to milliseconds
    }
    
    private func calculateOnboardingDuration() -> Int {
        guard let startTime = onboardingStartTime else { return 0 }
        let duration = Date().timeIntervalSince(startTime)
        return Int(duration * 1000) // Convert to milliseconds
    }
    
    /// Sanitize parameters to comply with Firebase limits
    /// - Event name: max 40 chars, alphanumeric + underscore
    /// - Parameter name: max 40 chars
    /// - Parameter value (string): max 100 chars
    /// - Max 25 parameters per event
    private func sanitizeParameters(_ params: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]
        
        // Limit to 25 parameters
        let limitedParams = Array(params.prefix(25))
        
        for (key, value) in limitedParams {
            let sanitizedKey = sanitizePropertyName(key)
            
            if let stringValue = value as? String {
                sanitized[sanitizedKey] = sanitizePropertyValue(stringValue)
            } else {
                sanitized[sanitizedKey] = value
            }
        }
        
        return sanitized
    }
    
    /// Sanitize property names (max 40 chars, alphanumeric + underscore)
    private func sanitizePropertyName(_ name: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        let sanitized = name
            .components(separatedBy: allowedCharacters.inverted)
            .joined(separator: "_")
        return String(sanitized.prefix(40))
    }
    
    /// Sanitize property values (max 100 chars)
    private func sanitizePropertyValue(_ value: String) -> String {
        return String(value.prefix(100))
    }
    
    /// Sanitize error messages to prevent PII leakage
    private func sanitizeErrorMessage(_ message: String) -> String {
        // Remove potential PII (emails, phone numbers, etc.)
        var sanitized = message
        
        // Remove email patterns
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        if let regex = try? NSRegularExpression(pattern: emailPattern) {
            sanitized = regex.stringByReplacingMatches(in: sanitized, range: NSRange(sanitized.startIndex..., in: sanitized), withTemplate: "[EMAIL]")
        }
        
        // Truncate to prevent cardinality explosion
        return String(sanitized.prefix(100))
    }
    
    /// Bucket error codes to prevent cardinality explosion
    private func bucketErrorCode(_ errorCode: String) -> String {
        // Common RevenueCat/StoreKit error patterns
        let code = errorCode.lowercased()
        
        if code.contains("cancel") || code.contains("cancelled") {
            return "user_cancelled"
        } else if code.contains("network") || code.contains("connection") {
            return "network_error"
        } else if code.contains("payment") || code.contains("billing") {
            return "payment_error"
        } else if code.contains("product") || code.contains("invalid") {
            return "invalid_product"
        } else if code.contains("receipt") {
            return "receipt_error"
        } else if code.contains("already") || code.contains("owned") {
            return "already_owned"
        } else if code.contains("not_allowed") || code.contains("restricted") {
            return "not_allowed"
        } else {
            return "unknown_error"
        }
    }
}

// MARK: - Supporting Enums

/// Actions that can occur during onboarding
enum OnboardingAction: String {
    case next = "next"
    case back = "back"
    case skip = "skip"
    case close = "close"
    case learnMore = "learn_more"
    case watchVideo = "watch_video"
    case toggleOption = "toggle_option"
    case selectOption = "select_option"
    case installShortcut = "install_shortcut"
    case verifyShortcut = "verify_shortcut"
    case pickWallpaper = "pick_wallpaper"
    case pickPhoto = "pick_photo"
    case addNote = "add_note"
    case deleteNote = "delete_note"
    case requestPermission = "request_permission"
    case openSettings = "open_settings"
    case contactSupport = "contact_support"
    case retrySetup = "retry_setup"
}

/// Permission prompt actions
enum PermissionAction: String {
    case shown = "shown"
    case accepted = "accepted"
    case denied = "denied"
    case notDetermined = "not_determined"
}

/// Reasons for onboarding abandonment
enum AbandonReason: String {
    case appBackgrounded = "app_backgrounded"
    case appTerminated = "app_terminated"
    case userClosed = "user_closed"
    case timeout = "timeout"
    case unknown = "unknown"
}
