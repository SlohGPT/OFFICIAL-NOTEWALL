//
//  AnalyticsEvent.swift
//  NoteWall
//
//  Type-safe analytics event definitions
//

import Foundation

// MARK: - Analytics Event

/// Type-safe analytics events with consistent naming
/// All event names follow snake_case convention and are limited to 40 characters
struct AnalyticsEvent {
    let name: String
    let parameters: [String: Any]
    
    private init(name: String, parameters: [String: Any] = [:]) {
        self.name = name
        self.parameters = parameters
    }
    
    /// Generic custom event for ad-hoc tracking
    static func custom(name: String, parameters: [String: Any] = [:]) -> AnalyticsEvent {
        AnalyticsEvent(name: name, parameters: parameters)
    }
}

// MARK: - Screen View Events

extension AnalyticsEvent {
    
    /// Standard screen view event
    static func screenView(screenName: String, screenClass: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "screen_view",
            parameters: [
                AnalyticsProperty.screenName: screenName,
                AnalyticsProperty.screenClass: screenClass
            ]
        )
    }
}

// MARK: - Tap/Action Events

extension AnalyticsEvent {
    
    /// Generic tap/action event
    static func tap(action: String, screen: String, element: String? = nil) -> AnalyticsEvent {
        var params: [String: Any] = [
            AnalyticsProperty.action: action,
            AnalyticsProperty.screenName: screen
        ]
        if let element = element {
            params[AnalyticsProperty.element] = element
        }
        return AnalyticsEvent(name: "tap", parameters: params)
    }
}

// MARK: - Onboarding Events

extension AnalyticsEvent {
    
    /// Fired once when user starts onboarding
    static func onboardingStart(flowId: String, variantId: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "onboarding_start",
            parameters: [
                AnalyticsProperty.flowId: flowId,
                AnalyticsProperty.variantId: variantId,
                AnalyticsProperty.timestamp: ISO8601DateFormatter().string(from: Date())
            ]
        )
    }
    
    /// Fired when a step becomes visible
    static func onboardingStepView(
        stepId: String,
        stepIndex: Int,
        stepName: String?,
        flowId: String,
        variantId: String
    ) -> AnalyticsEvent {
        var params: [String: Any] = [
            AnalyticsProperty.stepId: stepId,
            AnalyticsProperty.stepIndex: stepIndex,
            AnalyticsProperty.flowId: flowId,
            AnalyticsProperty.variantId: variantId
        ]
        if let stepName = stepName {
            params[AnalyticsProperty.stepName] = stepName
        }
        return AnalyticsEvent(name: "onboarding_step_view", parameters: params)
    }
    
    /// Fired when user completes a step (moves to next)
    static func onboardingStepComplete(
        stepId: String,
        stepIndex: Int,
        stepName: String?,
        durationMs: Int,
        flowId: String,
        variantId: String
    ) -> AnalyticsEvent {
        var params: [String: Any] = [
            AnalyticsProperty.stepId: stepId,
            AnalyticsProperty.stepIndex: stepIndex,
            AnalyticsProperty.durationMs: durationMs,
            AnalyticsProperty.flowId: flowId,
            AnalyticsProperty.variantId: variantId
        ]
        if let stepName = stepName {
            params[AnalyticsProperty.stepName] = stepName
        }
        return AnalyticsEvent(name: "onboarding_step_complete", parameters: params)
    }
    
    /// Fired for any action during onboarding (next, back, skip, etc.)
    static func onboardingAction(
        action: OnboardingAction,
        stepId: String,
        stepIndex: Int,
        flowId: String,
        variantId: String
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "onboarding_action",
            parameters: [
                AnalyticsProperty.action: action.rawValue,
                AnalyticsProperty.stepId: stepId,
                AnalyticsProperty.stepIndex: stepIndex,
                AnalyticsProperty.flowId: flowId,
                AnalyticsProperty.variantId: variantId
            ]
        )
    }
    
    /// Fired when user answers a quiz question
    static func quizAnswer(
        question: String,
        answer: String,
        stepId: String,
        stepIndex: Int,
        flowId: String,
        variantId: String
    ) -> AnalyticsEvent {
        // Bucket long answers to prevent cardinality explosion
        let bucketedAnswer = answer.count > 50 ? String(answer.prefix(47)) + "..." : answer
        
        return AnalyticsEvent(
            name: "quiz_answer",
            parameters: [
                AnalyticsProperty.question: String(question.prefix(100)),
                AnalyticsProperty.answer: bucketedAnswer,
                AnalyticsProperty.stepId: stepId,
                AnalyticsProperty.stepIndex: stepIndex,
                AnalyticsProperty.flowId: flowId,
                AnalyticsProperty.variantId: variantId
            ]
        )
    }
    
    /// Fired for permission prompts (notification, photos, etc.)
    static func permissionPrompt(
        permissionType: String,
        action: PermissionAction,
        stepId: String,
        flowId: String,
        variantId: String
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "permission_prompt",
            parameters: [
                AnalyticsProperty.permissionType: permissionType,
                AnalyticsProperty.action: action.rawValue,
                AnalyticsProperty.stepId: stepId,
                AnalyticsProperty.flowId: flowId,
                AnalyticsProperty.variantId: variantId
            ]
        )
    }
    
    /// Fired when user abandons onboarding
    static func onboardingAbandon(
        stepId: String,
        stepIndex: Int,
        reason: AbandonReason,
        totalDurationMs: Int,
        flowId: String,
        variantId: String
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "onboarding_abandon",
            parameters: [
                AnalyticsProperty.stepId: stepId,
                AnalyticsProperty.stepIndex: stepIndex,
                AnalyticsProperty.reason: reason.rawValue,
                AnalyticsProperty.totalDurationMs: totalDurationMs,
                AnalyticsProperty.flowId: flowId,
                AnalyticsProperty.variantId: variantId
            ]
        )
    }
    
    /// Fired when user completes onboarding
    static func onboardingComplete(
        totalDurationMs: Int,
        flowId: String,
        variantId: String
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "onboarding_complete",
            parameters: [
                AnalyticsProperty.totalDurationMs: totalDurationMs,
                AnalyticsProperty.flowId: flowId,
                AnalyticsProperty.variantId: variantId
            ]
        )
    }
}

// MARK: - Paywall Events

extension AnalyticsEvent {
    
    /// Fired when paywall is displayed
    static func paywallImpression(
        paywallId: String,
        trigger: String,
        placement: String?,
        flowId: String,
        variantId: String
    ) -> AnalyticsEvent {
        var params: [String: Any] = [
            AnalyticsProperty.paywallId: paywallId,
            AnalyticsProperty.trigger: trigger,
            AnalyticsProperty.flowId: flowId,
            AnalyticsProperty.variantId: variantId
        ]
        if let placement = placement {
            params[AnalyticsProperty.placement] = placement
        }
        return AnalyticsEvent(name: "paywall_impression", parameters: params)
    }
    
    /// Fired when user selects a plan
    static func planSelected(
        productId: String,
        price: Double?,
        period: String?,
        currency: String?
    ) -> AnalyticsEvent {
        var params: [String: Any] = [
            AnalyticsProperty.productId: productId
        ]
        if let price = price {
            params[AnalyticsProperty.price] = price
        }
        if let period = period {
            params[AnalyticsProperty.period] = period
        }
        if let currency = currency {
            params[AnalyticsProperty.currency] = currency
        }
        return AnalyticsEvent(name: "plan_selected", parameters: params)
    }
    
    /// Fired when purchase flow starts
    static func purchaseStart(productId: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "purchase_start",
            parameters: [
                AnalyticsProperty.productId: productId
            ]
        )
    }
    
    /// Fired on successful purchase
    static func purchaseSuccess(
        productId: String,
        transactionId: String?,
        revenue: Double?,
        currency: String?
    ) -> AnalyticsEvent {
        var params: [String: Any] = [
            AnalyticsProperty.productId: productId
        ]
        if let transactionId = transactionId {
            params[AnalyticsProperty.transactionId] = transactionId
        }
        if let revenue = revenue {
            params[AnalyticsProperty.revenue] = revenue
        }
        if let currency = currency {
            params[AnalyticsProperty.currency] = currency
        }
        return AnalyticsEvent(name: "purchase_success", parameters: params)
    }
    
    /// Fired when user cancels purchase
    static func purchaseCancel(productId: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "purchase_cancel",
            parameters: [
                AnalyticsProperty.productId: productId
            ]
        )
    }
    
    /// Fired when purchase fails
    static func purchaseFail(productId: String, errorCode: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "purchase_fail",
            parameters: [
                AnalyticsProperty.productId: productId,
                AnalyticsProperty.errorCode: errorCode
            ]
        )
    }
    
    /// Fired when user taps restore
    static func restoreTap() -> AnalyticsEvent {
        AnalyticsEvent(name: "restore_tap", parameters: [:])
    }
    
    /// Fired on successful restore
    static func restoreSuccess() -> AnalyticsEvent {
        AnalyticsEvent(name: "restore_success", parameters: [:])
    }
    
    /// Fired on restore failure
    static func restoreFail(errorCode: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "restore_fail",
            parameters: [
                AnalyticsProperty.errorCode: errorCode
            ]
        )
    }
    
    /// Fired when user closes paywall
    static func paywallClose(paywallId: String, converted: Bool) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "paywall_close",
            parameters: [
                AnalyticsProperty.paywallId: paywallId,
                AnalyticsProperty.converted: converted
            ]
        )
    }
}

// MARK: - Error Events

extension AnalyticsEvent {
    
    /// Generic error event
    static func error(errorType: String, errorMessage: String, screen: String?) -> AnalyticsEvent {
        var params: [String: Any] = [
            AnalyticsProperty.errorType: errorType,
            AnalyticsProperty.errorMessage: errorMessage
        ]
        if let screen = screen {
            params[AnalyticsProperty.screenName] = screen
        }
        return AnalyticsEvent(name: "app_error", parameters: params)
    }
}

// MARK: - Feature Usage Events

extension AnalyticsEvent {
    
    /// Generic feature usage event
    static func featureUsage(feature: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "feature_usage",
            parameters: [
                AnalyticsProperty.feature: feature
            ]
        )
    }
    
    /// Wallpaper export event
    static func wallpaperExport(count: Int, isPremium: Bool) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "wallpaper_export",
            parameters: [
                AnalyticsProperty.count: count,
                AnalyticsProperty.isPremium: isPremium
            ]
        )
    }
    
    /// Shortcut run event
    static func shortcutRun(success: Bool) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "shortcut_run",
            parameters: [
                AnalyticsProperty.success: success
            ]
        )
    }
}
// MARK: - Retention & Session Events

extension AnalyticsEvent {
    
    /// Fired when app is opened (cold start or from background)
    static func appOpen(isFirstLaunch: Bool, daysSinceInstall: Int, sessionCount: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "app_open",
            parameters: [
                AnalyticsProperty.isFirstLaunch: isFirstLaunch,
                "days_since_install": daysSinceInstall,
                "session_count": sessionCount,
                "launch_type": isFirstLaunch ? "first" : "returning"
            ]
        )
    }
    
    /// Fired when a new session starts
    static func sessionStart(sessionId: String, sessionNumber: Int, daysSinceLastSession: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "session_start",
            parameters: [
                "session_id": sessionId,
                "session_number": sessionNumber,
                "days_since_last_session": daysSinceLastSession
            ]
        )
    }
    
    /// Fired when session ends (app goes to background or closes)
    static func sessionEnd(sessionId: String, durationSeconds: Int, screensViewed: Int, actionsPerformed: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "session_end",
            parameters: [
                "session_id": sessionId,
                "duration_seconds": durationSeconds,
                "screens_viewed": screensViewed,
                "actions_performed": actionsPerformed
            ]
        )
    }
    
    /// Daily active user ping (fired once per day)
    static func dailyActive(daysSinceInstall: Int, isPremium: Bool, totalSessions: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "daily_active",
            parameters: [
                "days_since_install": daysSinceInstall,
                AnalyticsProperty.isPremium: isPremium,
                "total_sessions": totalSessions,
                "retention_day": daysSinceInstall
            ]
        )
    }
    
    /// Weekly active user ping (fired once per week)
    static func weeklyActive(weekNumber: Int, isPremium: Bool, sessionsThisWeek: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "weekly_active",
            parameters: [
                "week_number": weekNumber,
                AnalyticsProperty.isPremium: isPremium,
                "sessions_this_week": sessionsThisWeek
            ]
        )
    }
    
    /// User returns after being inactive
    static func userReturned(daysInactive: Int, isPremium: Bool) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "user_returned",
            parameters: [
                "days_inactive": daysInactive,
                AnalyticsProperty.isPremium: isPremium
            ]
        )
    }
}

// MARK: - Feature Usage Events (Detailed)

extension AnalyticsEvent {
    
    /// Note created
    static func noteCreated(noteCount: Int, characterCount: Int, hasEmoji: Bool) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "note_created",
            parameters: [
                "note_count": noteCount,
                "character_count": characterCount,
                "has_emoji": hasEmoji
            ]
        )
    }
    
    /// Note deleted
    static func noteDeleted(remainingNotes: Int, reason: String?) -> AnalyticsEvent {
        var params: [String: Any] = [
            "remaining_notes": remainingNotes
        ]
        if let reason = reason {
            params["reason"] = reason
        }
        return AnalyticsEvent(name: "note_deleted", parameters: params)
    }
    
    /// Wallpaper updated/generated
    static func wallpaperUpdated(wallpaperType: String, noteCount: Int, isPremium: Bool, updateMethod: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "wallpaper_updated",
            parameters: [
                "wallpaper_type": wallpaperType,
                "note_count": noteCount,
                AnalyticsProperty.isPremium: isPremium,
                "update_method": updateMethod // "manual", "shortcut", "auto"
            ]
        )
    }
    
    /// Background image changed
    static func backgroundChanged(imageSource: String, forScreen: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "background_changed",
            parameters: [
                "image_source": imageSource, // "library", "photo", "default"
                "for_screen": forScreen // "home", "lock", "both"
            ]
        )
    }
    
    /// Settings changed
    static func settingChanged(settingName: String, oldValue: String, newValue: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "setting_changed",
            parameters: [
                "setting_name": settingName,
                "old_value": oldValue,
                "new_value": newValue
            ]
        )
    }
    
    /// Share action
    static func shareAction(contentType: String, shareDestination: String?, success: Bool) -> AnalyticsEvent {
        var params: [String: Any] = [
            "content_type": contentType,
            AnalyticsProperty.success: success
        ]
        if let destination = shareDestination {
            params["share_destination"] = destination
        }
        return AnalyticsEvent(name: "share_action", parameters: params)
    }
    
    /// Settings screen opened
    static func settingsOpened(fromScreen: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "settings_opened",
            parameters: [
                "from_screen": fromScreen
            ]
        )
    }
    
    /// Troubleshooting accessed
    static func troubleshootingAccessed(issue: String?) -> AnalyticsEvent {
        var params: [String: Any] = [:]
        if let issue = issue {
            params["issue"] = issue
        }
        return AnalyticsEvent(name: "troubleshooting_accessed", parameters: params)
    }
}

// MARK: - User Journey Events

extension AnalyticsEvent {
    
    /// Tracks milestone reached
    static func milestoneReached(milestone: String, daysSinceInstall: Int, sessionsCount: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "milestone_reached",
            parameters: [
                "milestone": milestone, // "first_note", "first_wallpaper", "5_notes", "10_wallpapers", etc.
                "days_since_install": daysSinceInstall,
                "sessions_count": sessionsCount
            ]
        )
    }
    
    /// Time to first purchase (for users who convert)
    static func conversionJourney(
        timeToConversionHours: Int,
        sessionsBeforeConversion: Int,
        paywallViewsBeforeConversion: Int,
        onboardingCompleted: Bool
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "conversion_journey",
            parameters: [
                "time_to_conversion_hours": timeToConversionHours,
                "sessions_before_conversion": sessionsBeforeConversion,
                "paywall_views_before_conversion": paywallViewsBeforeConversion,
                "onboarding_completed": onboardingCompleted
            ]
        )
    }
    
    /// Trial started
    static func trialStarted(productId: String, trialDays: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "trial_started",
            parameters: [
                AnalyticsProperty.productId: productId,
                "trial_days": trialDays
            ]
        )
    }
    
    /// Trial converted to paid
    static func trialConverted(productId: String, daysUsedInTrial: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "trial_converted",
            parameters: [
                AnalyticsProperty.productId: productId,
                "days_used_in_trial": daysUsedInTrial
            ]
        )
    }
    
    /// Trial expired without conversion
    static func trialExpired(productId: String, engagementScore: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "trial_expired",
            parameters: [
                AnalyticsProperty.productId: productId,
                "engagement_score": engagementScore // based on feature usage
            ]
        )
    }
    
    /// Subscription renewed
    static func subscriptionRenewed(productId: String, renewalCount: Int, totalRevenue: Double) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "subscription_renewed",
            parameters: [
                AnalyticsProperty.productId: productId,
                "renewal_count": renewalCount,
                "total_revenue": totalRevenue
            ]
        )
    }
    
    /// Subscription cancelled
    static func subscriptionCancelled(productId: String, reason: String?, monthsSubscribed: Int) -> AnalyticsEvent {
        var params: [String: Any] = [
            AnalyticsProperty.productId: productId,
            "months_subscribed": monthsSubscribed
        ]
        if let reason = reason {
            params["reason"] = reason
        }
        return AnalyticsEvent(name: "subscription_cancelled", parameters: params)
    }
    
    /// Churn risk detected (low engagement)
    static func churnRiskDetected(riskScore: Int, daysSinceLastActive: Int, totalSessions: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "churn_risk_detected",
            parameters: [
                "risk_score": riskScore,
                "days_since_last_active": daysSinceLastActive,
                "total_sessions": totalSessions
            ]
        )
    }
}

// MARK: - Engagement Score Events

extension AnalyticsEvent {
    
    /// Weekly engagement summary
    static func weeklyEngagement(
        notesCreated: Int,
        wallpapersUpdated: Int,
        sessionsThisWeek: Int,
        avgSessionDuration: Int,
        engagementScore: Int
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "weekly_engagement",
            parameters: [
                "notes_created": notesCreated,
                "wallpapers_updated": wallpapersUpdated,
                "sessions_this_week": sessionsThisWeek,
                "avg_session_duration": avgSessionDuration,
                "engagement_score": engagementScore
            ]
        )
    }
}

// MARK: - Notification Events

extension AnalyticsEvent {
    
    /// Notification received
    static func notificationReceived(notificationType: String, notificationId: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "notification_received",
            parameters: [
                "notification_type": notificationType,
                "notification_id": notificationId
            ]
        )
    }
    
    /// Notification opened (user tapped)
    static func notificationOpened(notificationType: String, notificationId: String, hoursAfterSent: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "notification_opened",
            parameters: [
                "notification_type": notificationType,
                "notification_id": notificationId,
                "hours_after_sent": hoursAfterSent
            ]
        )
    }
    
    /// Notification dismissed
    static func notificationDismissed(notificationType: String, notificationId: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "notification_dismissed",
            parameters: [
                "notification_type": notificationType,
                "notification_id": notificationId
            ]
        )
    }
}
