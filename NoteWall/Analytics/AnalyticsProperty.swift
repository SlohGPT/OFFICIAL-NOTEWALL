//
//  AnalyticsProperty.swift
//  NoteWall
//
//  Centralized analytics property keys to ensure consistency
//

import Foundation

// MARK: - Analytics Property Keys

/// Centralized property keys for analytics
/// All keys follow snake_case convention and are limited to 40 characters
enum AnalyticsProperty {
    
    // MARK: - Screen/View Properties
    static let screenName = "screen_name"
    static let screenClass = "screen_class"
    
    // MARK: - Action Properties
    static let action = "action"
    static let element = "element"
    
    // MARK: - Onboarding Properties
    static let flowId = "flow_id"
    static let variantId = "variant_id"
    static let stepId = "step_id"
    static let stepIndex = "step_index"
    static let stepName = "step_name"
    static let durationMs = "duration_ms"
    static let totalDurationMs = "total_duration_ms"
    static let reason = "reason"
    
    // MARK: - Quiz Properties
    static let question = "question"
    static let answer = "answer"
    
    // MARK: - Permission Properties
    static let permissionType = "permission_type"
    
    // MARK: - Paywall Properties
    static let paywallId = "paywall_id"
    static let trigger = "trigger"
    static let placement = "placement"
    
    // MARK: - Purchase Properties
    static let productId = "product_id"
    static let price = "price"
    static let period = "period"
    static let currency = "currency"
    static let transactionId = "transaction_id"
    static let revenue = "revenue"
    static let errorCode = "error_code"
    static let converted = "converted"
    
    // MARK: - Error Properties
    static let errorType = "error_type"
    static let errorMessage = "error_message"
    
    // MARK: - Feature Properties
    static let feature = "feature"
    static let count = "count"
    static let success = "success"
    
    // MARK: - User Properties
    static let isPremium = "is_premium"
    static let isFirstLaunch = "is_first_launch"
    static let hasCompletedOnboarding = "has_completed_onboarding"
    static let onboardingVariant = "onboarding_variant"
    static let installDate = "install_date"
    
    // MARK: - Metadata
    static let timestamp = "timestamp"
}

// MARK: - Onboarding Step IDs

/// Consistent step IDs for onboarding tracking
/// These map to the OnboardingPage enum in OnboardingView.swift
enum OnboardingStepId: String, CaseIterable {
    // Phase 0: Pre-onboarding
    case preOnboardingHook = "pre_onboarding_hook"
    case nameInput = "name_input"
    
    // Phase 1: Emotional Hook (Quiz)
    case painPoint = "pain_point"
    case quizForgetMost = "quiz_forget_most"
    case quizPhoneChecks = "quiz_phone_checks"
    case quizDistraction = "quiz_distraction"
    case personalizationLoading = "personalization_loading"
    case resultsPreview = "results_preview"
    case resultsInsight = "results_insight"
    
    // Phase 2: Social Proof & Notification Permission
    case socialProof = "social_proof"
    case notificationPermission = "notification_permission"
    
    // Phase 3: Technical Setup
    case setupIntro = "setup_intro"
    case welcome = "welcome"
    case installShortcut = "install_shortcut"
    case shortcutSuccess = "shortcut_success"
    case addNotes = "add_notes"
    case chooseWallpapers = "choose_wallpapers"
    case allowPermissions = "allow_permissions"
    
    // Phase 4: Celebration & Completion
    case setupComplete = "setup_complete"
    case overview = "overview"
    case reviewPage = "review_page"
    
    /// Get the step index (0-based)
    var index: Int {
        OnboardingStepId.allCases.firstIndex(of: self) ?? 0
    }
    
    /// Human-readable step name (numbered for Mixpanel clarity)
    var displayName: String {
        let num = index + 1
        switch self {
        case .preOnboardingHook: return "\(num). Welcome Hook"
        case .nameInput: return "\(num). Name Input"
        case .painPoint: return "\(num). Pain Point"
        case .quizForgetMost: return "\(num). Quiz: Forget Most"
        case .quizPhoneChecks: return "\(num). Quiz: Phone Checks"
        case .quizDistraction: return "\(num). Quiz: Distraction"
        case .personalizationLoading: return "\(num). Personalization"
        case .resultsPreview: return "\(num). Results Preview"
        case .resultsInsight: return "\(num). Results Insight"
        case .socialProof: return "\(num). Social Proof"
        case .notificationPermission: return "\(num). Notification Permission"
        case .setupIntro: return "\(num). Setup Intro"
        case .welcome: return "\(num). Welcome"
        case .installShortcut: return "\(num). Install Shortcut"
        case .shortcutSuccess: return "\(num). Shortcut Success"
        case .addNotes: return "\(num). Add Notes"
        case .chooseWallpapers: return "\(num). Choose Wallpapers"
        case .allowPermissions: return "\(num). Allow Permissions"
        case .setupComplete: return "\(num). Setup Complete"
        case .overview: return "\(num). Overview"
        case .reviewPage: return "\(num). Review Page"
        }
    }
}

// MARK: - Paywall IDs

/// Consistent paywall identifiers
enum PaywallId: String {
    case postOnboarding = "post_onboarding"
    case limitReached = "limit_reached"
    case settings = "settings"
    case manual = "manual"
    case exitIntercept = "exit_intercept"
    case superwall = "superwall"
}

// MARK: - Feature IDs

/// Consistent feature identifiers for usage tracking
enum FeatureId: String {
    case wallpaperExport = "wallpaper_export"
    case noteAdd = "note_add"
    case noteDelete = "note_delete"
    case shortcutRun = "shortcut_run"
    case backgroundChange = "background_change"
    case widgetSetup = "widget_setup"
    case promoCodeApply = "promo_code_apply"
    case shareApp = "share_app"
    case rateApp = "rate_app"
    case contactSupport = "contact_support"
}

// MARK: - Permission Types

/// Permission types for tracking
enum PermissionType: String {
    case notifications = "notifications"
    case photoLibrary = "photo_library"
    case camera = "camera"
}
