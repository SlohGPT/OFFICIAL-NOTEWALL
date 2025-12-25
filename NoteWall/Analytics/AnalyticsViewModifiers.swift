//
//  AnalyticsViewModifiers.swift
//  NoteWall
//
//  SwiftUI view modifiers for analytics tracking
//

import SwiftUI

// MARK: - Onboarding Step Tracking Modifier

/// View modifier that tracks onboarding step views and durations
/// Uses a fire-once mechanism to prevent duplicate events from SwiftUI re-renders
struct OnboardingStepTrackingModifier: ViewModifier {
    let stepId: OnboardingStepId
    
    @State private var hasTrackedAppear = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !hasTrackedAppear else { return }
                hasTrackedAppear = true
                
                // Track step view
                AnalyticsService.shared.trackOnboardingStep(
                    stepId: stepId.rawValue,
                    stepIndex: stepId.index,
                    stepName: stepId.displayName
                )
            }
            .onDisappear {
                // Track step completion when leaving
                if hasTrackedAppear {
                    AnalyticsService.shared.trackOnboardingStepComplete(
                        stepId: stepId.rawValue,
                        stepIndex: stepId.index,
                        stepName: stepId.displayName
                    )
                }
            }
    }
}

// MARK: - Screen View Tracking Modifier

/// View modifier that tracks screen views with fire-once behavior
struct ScreenViewTrackingModifier: ViewModifier {
    let screenName: String
    let screenClass: String?
    
    @State private var hasTracked = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !hasTracked else { return }
                hasTracked = true
                
                AnalyticsService.shared.trackScreenView(
                    screenName: screenName,
                    screenClass: screenClass ?? screenName
                )
            }
    }
}

// MARK: - Paywall Tracking Modifier

/// View modifier that tracks paywall impressions
struct PaywallTrackingModifier: ViewModifier {
    let paywallId: PaywallId
    let trigger: String
    let placement: String?
    
    @State private var hasTrackedImpression = false
    @State private var didConvert = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !hasTrackedImpression else { return }
                hasTrackedImpression = true
                
                AnalyticsService.shared.trackPaywallImpression(
                    paywallId: paywallId.rawValue,
                    trigger: trigger,
                    placement: placement
                )
            }
            .onDisappear {
                // Track close event
                if hasTrackedImpression {
                    AnalyticsService.shared.trackPaywallClose(
                        paywallId: paywallId.rawValue,
                        converted: didConvert
                    )
                }
            }
    }
    
    /// Mark that user converted (purchased)
    func markConverted() {
        didConvert = true
    }
}

// MARK: - View Extensions

extension View {
    
    /// Track onboarding step views and durations
    /// - Parameter stepId: The step identifier
    func trackOnboardingStep(_ stepId: OnboardingStepId) -> some View {
        modifier(OnboardingStepTrackingModifier(stepId: stepId))
    }
    
    /// Track screen views with fire-once behavior
    /// - Parameters:
    ///   - screenName: The screen name for analytics
    ///   - screenClass: Optional screen class (defaults to screen name)
    func trackScreenView(_ screenName: String, screenClass: String? = nil) -> some View {
        modifier(ScreenViewTrackingModifier(screenName: screenName, screenClass: screenClass))
    }
    
    /// Track paywall impressions and closes
    /// - Parameters:
    ///   - paywallId: The paywall identifier
    ///   - trigger: What triggered the paywall
    ///   - placement: Optional placement identifier
    func trackPaywall(_ paywallId: PaywallId, trigger: String, placement: String? = nil) -> some View {
        modifier(PaywallTrackingModifier(paywallId: paywallId, trigger: trigger, placement: placement))
    }
}

// MARK: - Tap Tracking Button Style

/// Button style that tracks tap events
struct AnalyticsButtonStyle: ButtonStyle {
    let action: String
    let screen: String
    let element: String?
    
    init(action: String, screen: String, element: String? = nil) {
        self.action = action
        self.screen = screen
        self.element = element
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    AnalyticsService.shared.trackTap(
                        action: action,
                        screen: screen,
                        element: element
                    )
                }
            }
    }
}

// MARK: - Analytics Tap Gesture

extension View {
    
    /// Add a tap gesture that tracks analytics
    /// - Parameters:
    ///   - action: The action name
    ///   - screen: The screen name
    ///   - element: Optional element identifier
    ///   - handler: The tap handler
    func onAnalyticsTap(
        action: String,
        screen: String,
        element: String? = nil,
        perform handler: @escaping () -> Void
    ) -> some View {
        self.onTapGesture {
            AnalyticsService.shared.trackTap(action: action, screen: screen, element: element)
            handler()
        }
    }
}

// MARK: - Environment Key for Paywall Conversion

private struct PaywallConvertedKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var paywallConverted: Binding<Bool> {
        get { self[PaywallConvertedKey.self] }
        set { self[PaywallConvertedKey.self] = newValue }
    }
}
