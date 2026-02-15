//
//  OnboardingView+Analytics.swift
//  NoteWall
//
//  Analytics tracking extension for OnboardingView
//

import SwiftUI

// MARK: - OnboardingPage Analytics Extension

extension OnboardingPage {
    
    /// Get the analytics step ID for this page
    var analyticsStepId: OnboardingStepId {
        switch self {
        case .preOnboardingHook: return .preOnboardingHook
        case .nameInput: return .nameInput
        case .notificationPermission: return .notificationPermission
        case .painPoint: return .painPoint
        case .quizForgetMost: return .quizForgetMost
        case .quizPhoneChecks: return .quizPhoneChecks
        case .quizDistraction: return .quizDistraction
        case .personalizationLoading: return .personalizationLoading
        case .resultsPreview: return .resultsPreview
        case .resultsInsight: return .resultsInsight
        case .socialProof: return .socialProof
        case .reviewPage: return .reviewPage
        case .setupIntro: return .setupIntro
        case .welcome: return .welcome
        case .installShortcut: return .installShortcut
        case .shortcutSuccess: return .shortcutSuccess
        case .addNotes: return .addNotes
        case .chooseWallpapers: return .chooseWallpapers
        case .allowPermissions: return .allowPermissions
        case .setupComplete: return .setupComplete
        case .overview: return .overview
        }
    }
}

// MARK: - Onboarding Analytics Helper

/// Helper class for tracking onboarding analytics
/// Can be used from anywhere in the onboarding flow
final class OnboardingAnalyticsTracker {
    
    // MARK: - Singleton
    static let shared = OnboardingAnalyticsTracker()
    
    // MARK: - State
    private var hasStartedOnboarding = false
    private var currentStepId: OnboardingStepId?
    
    private init() {}
    
    // MARK: - Onboarding Lifecycle
    
    /// Call when onboarding view first appears
    func onboardingDidAppear() {
        guard !hasStartedOnboarding else { return }
        hasStartedOnboarding = true
        
        // Reset analytics session
        AnalyticsService.shared.resetOnboardingSession()
        
        // Track onboarding start
        AnalyticsService.shared.trackOnboardingStart()
        
        #if DEBUG
        print("📊 Onboarding Analytics: Started")
        #endif
    }
    
    /// Call when moving to a new step
    func trackStepView(_ page: OnboardingPage) {
        let stepId = page.analyticsStepId
        
        // Complete previous step if there was one
        if let previousStepId = currentStepId, previousStepId != stepId {
            AnalyticsService.shared.trackOnboardingStepComplete(
                stepId: previousStepId.rawValue,
                stepIndex: previousStepId.index,
                stepName: previousStepId.displayName
            )
        }
        
        // Track new step view
        currentStepId = stepId
        AnalyticsService.shared.trackOnboardingStep(
            stepId: stepId.rawValue,
            stepIndex: stepId.index,
            stepName: stepId.displayName
        )
        
        // Also track as a screen view so it appears in "Pages and screens" report
        AnalyticsService.shared.trackScreenView(
            screenName: "onboarding_\(String(format: "%02d", stepId.index + 1))_\(stepId.rawValue)",
            screenClass: "OnboardingView"
        )
    }
    
    /// Call when user completes onboarding
    func trackOnboardingComplete() {
        // Complete the last step
        if let lastStepId = currentStepId {
            AnalyticsService.shared.trackOnboardingStepComplete(
                stepId: lastStepId.rawValue,
                stepIndex: lastStepId.index,
                stepName: lastStepId.displayName
            )
        }
        
        // Track completion
        AnalyticsService.shared.trackOnboardingComplete()
        
        // Reset state
        hasStartedOnboarding = false
        currentStepId = nil
        
        #if DEBUG
        print("📊 Onboarding Analytics: Completed")
        #endif
    }
    
    /// Call when app goes to background during onboarding
    func trackOnboardingBackground() {
        guard hasStartedOnboarding, let stepId = currentStepId else { return }
        
        AnalyticsService.shared.trackOnboardingAbandon(
            stepId: stepId.rawValue,
            stepIndex: stepId.index,
            reason: .appBackgrounded
        )
        
        #if DEBUG
        print("📊 Onboarding Analytics: App backgrounded at step \(stepId.displayName)")
        #endif
    }
    
    // MARK: - Action Tracking
    
    /// Track a button tap action
    func trackAction(_ action: OnboardingAction, on page: OnboardingPage, additionalParams: [String: Any]? = nil) {
        let stepId = page.analyticsStepId
        AnalyticsService.shared.trackOnboardingAction(
            action: action,
            stepId: stepId.rawValue,
            stepIndex: stepId.index,
            additionalParams: additionalParams
        )
    }
    
    /// Track a quiz answer
    func trackQuizAnswer(question: String, answer: String, on page: OnboardingPage) {
        let stepId = page.analyticsStepId
        AnalyticsService.shared.trackQuizAnswer(
            question: question,
            answer: answer,
            stepId: stepId.rawValue,
            stepIndex: stepId.index
        )
    }
    
    /// Track a permission prompt
    func trackPermission(type: PermissionType, action: PermissionAction, on page: OnboardingPage) {
        let stepId = page.analyticsStepId
        AnalyticsService.shared.trackPermissionPrompt(
            permissionType: type.rawValue,
            action: action,
            stepId: stepId.rawValue
        )
    }
    
    // MARK: - Reset
    
    /// Reset tracking state (call when user restarts onboarding)
    func reset() {
        hasStartedOnboarding = false
        currentStepId = nil
        AnalyticsService.shared.resetOnboardingSession()
    }
}

// MARK: - Convenience Extensions

extension View {
    
    /// Track this view as an onboarding step when it appears
    func trackAsOnboardingStep(_ page: OnboardingPage) -> some View {
        self.onAppear {
            OnboardingAnalyticsTracker.shared.trackStepView(page)
        }
    }
}
