import Foundation
import SwiftUI
import Combine

/// ViewModel for managing the state and logic of the Shortcut Setup onboarding step.
/// This handles the flow of downloading the shortcut, showing the tutorial video,
/// verifying the installation, and managing the user experience.
@MainActor
final class ShortcutSetupViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current state of the shortcut setup flow
    @Published var setupState: SetupState = .initial
    
    /// Verification result from the last verification attempt
    @Published var verificationResult: ShortcutVerificationService.VerificationResult?
    
    /// Error message to display to the user
    @Published var errorMessage: String?
    
    /// Whether verification is currently in progress
    @Published var isVerifying = false
    
    /// Whether the tutorial video is currently playing
    @Published var isVideoPlaying = false
    
    // PiP-related properties commented out - can be re-enabled if needed
    // /// Whether Picture-in-Picture is active
    // @Published var isPiPActive = false
    
    /// Whether the user has returned to the app after opening Shortcuts
    @Published var hasReturnedFromShortcuts = false
    
    /// Whether automatic verification should run when user returns
    @Published var shouldAutoVerify = false
    
    // MARK: - Private Properties
    
    /// The shortcut URL to open
    private let shortcutURL: URL?
    
    /// Combine cancellables for reactive updates
    private var cancellables = Set<AnyCancellable>()
    
    /// Timer for periodic verification checks
    private var verificationTimer: Timer?
    
    /// Whether we've started the setup flow
    private var hasStartedSetup = false
    
    // MARK: - Shortcut URL Configuration
    
    /// Old shortcut URL for users who installed before February 9th, 2026
    /// This version updates both home screen and lock screen
    private static let oldShortcutURL = "https://www.icloud.com/shortcuts/4735a1723f8a4cc28c12d07092c66a35"
    
    /// New shortcut URL for users who installed on or after February 9th, 2026
    /// This version only updates the lock screen
    private static let newShortcutURL = "https://www.icloud.com/shortcuts/3365d3809e8c4ddfa89879ae0a19cbd3"
    
    /// Public accessor for the new shortcut URL (lock screen only).
    /// Used during pipeline migration to force the new shortcut regardless of install date.
    static let newShortcutURLString = "https://www.icloud.com/shortcuts/3365d3809e8c4ddfa89879ae0a19cbd3"
    
    /// Determines which shortcut URL to use based on install date and migration status
    /// - Returns: The appropriate shortcut URL for the user
    private static func determineShortcutURL() -> String {
        // If the user has completed the pipeline migration, always use the new shortcut
        if UserDefaults.standard.bool(forKey: "hasCompletedPipelineMigration") {
            print("✅ ShortcutSetupViewModel: User has completed pipeline migration, using new shortcut (lock screen only)")
            return newShortcutURL
        }
        
        // Get the install date from UserDefaults (same as AnalyticsService)
        let installDate = UserDefaults.standard.object(forKey: "analytics_install_date") as? Date ?? Date()
        
        // Create February 9th, 2026 date
        var dateComponents = DateComponents()
        dateComponents.year = 2026
        dateComponents.month = 2
        dateComponents.day = 9
        dateComponents.hour = 0
        dateComponents.minute = 0
        dateComponents.second = 0
        
        guard let cutoffDate = Calendar.current.date(from: dateComponents) else {
            // If we can't create the cutoff date, use old shortcut as fallback
            print("⚠️ ShortcutSetupViewModel: Could not create cutoff date, using old shortcut")
            return oldShortcutURL
        }
        
        // Compare install date with cutoff date
        if installDate < cutoffDate {
            // User installed before February 9th, 2026 - use old shortcut
            print("✅ ShortcutSetupViewModel: Install date \(installDate) is before cutoff, using old shortcut (both screens)")
            return oldShortcutURL
        } else {
            // User installed on or after February 9th, 2026 - use new shortcut
            print("✅ ShortcutSetupViewModel: Install date \(installDate) is on/after cutoff, using new shortcut (lock screen only)")
            return newShortcutURL
        }
    }
    
    /// Public accessor for the appropriate shortcut URL based on user's install date.
    /// Use this method throughout the app to ensure consistent shortcut URL usage.
    /// - Returns: The appropriate shortcut URL string for the current user
    static func getShortcutURL() -> String {
        return determineShortcutURL()
    }
    
    // MARK: - Setup State
    
    /// States that represent the progress through the shortcut setup flow
    enum SetupState: Equatable {
        /// Initial state - showing instructions
        case initial
        
        /// Setup started - video playing, Shortcuts app opened
        case setupStarted
        
        /// User returned from Shortcuts app
        case returnedFromShortcuts
        
        /// Verification in progress
        case verifying
        
        /// Verification successful
        case verified
        
        /// Verification failed
        case verificationFailed(ShortcutVerificationService.VerificationResult)
        
        /// Setup complete
        case complete
    }
    
    // MARK: - Initialization
    
    /// Creates a new ViewModel instance.
    /// - Parameters:
    ///   - shortcutURL: The iCloud Shortcut URL to open for installation. If nil, automatically determines the correct URL based on install date.
    init(shortcutURL: String? = nil) {
        if let urlString = shortcutURL {
            // Use provided URL
            self.shortcutURL = URL(string: urlString)
        } else {
            // Automatically determine which shortcut URL to use based on install date
            let determinedURL = Self.determineShortcutURL()
            self.shortcutURL = URL(string: determinedURL)
        }
        
        // Check if setup is already complete
        if ShortcutVerificationService.hasCompletedSetup() {
            setupState = .complete
        }
    }
    
    deinit {
        verificationTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Starts the shortcut setup flow.
    /// This opens the Shortcuts app with the shortcut URL and prepares for verification.
    func startSetup() {
        guard !hasStartedSetup else {
            print("⚠️ ShortcutSetupViewModel: Setup already started")
            return
        }
        
        hasStartedSetup = true
        setupState = .setupStarted
        
        // Open Shortcuts app
        openShortcutsApp()
        
        // Enable auto-verification when user returns
        shouldAutoVerify = true
        
        // Start monitoring for app return
        monitorAppReturn()
    }
    
    /// Opens the Shortcuts app with the shortcut URL.
    /// This should trigger the shortcut installation flow.
    private func openShortcutsApp() {
        guard let shortcutURL = shortcutURL else {
            errorMessage = "Shortcut URL is not available. Please check your configuration."
            setupState = .verificationFailed(
                ShortcutVerificationService.VerificationResult.failed(
                    missing: [.shortcutFileExists],
                    error: "Shortcut URL not available"
                )
            )
            return
        }
        
        // Open the shortcut URL to trigger installation
        UIApplication.shared.open(shortcutURL) { [weak self] success in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if success {
                    print("✅ ShortcutSetupViewModel: Shortcuts app opened successfully")
                } else {
                    print("❌ ShortcutSetupViewModel: Failed to open Shortcuts app")
                    self.errorMessage = "Could not open the Shortcuts app. Please install the shortcut manually."
                    self.setupState = .verificationFailed(
                        ShortcutVerificationService.VerificationResult.failed(
                            missing: [.shortcutFileExists],
                            error: "Could not open Shortcuts app"
                        )
                    )
                }
            }
        }
        
        // Also try to open the Shortcuts app directly
        if let shortcutsURL = URL(string: "shortcuts://") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIApplication.shared.open(shortcutsURL, options: [:], completionHandler: nil)
            }
        }
    }
    
    /// Monitors for when the user returns to the app after opening Shortcuts.
    /// This is used to trigger automatic verification.
    private func monitorAppReturn() {
        // This will be handled by the view using onChange(of: scenePhase)
        // We just need to set up the state for it
    }
    
    /// Handles when the user returns to the app.
    /// This should be called from the view's scenePhase onChange handler.
    func handleAppReturn() {
        guard shouldAutoVerify else {
            return
        }
        
        guard setupState == .setupStarted || setupState == .returnedFromShortcuts else {
            return
        }
        
        hasReturnedFromShortcuts = true
        setupState = .returnedFromShortcuts
        
        // Wait a moment for things to settle, then verify
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            Task { @MainActor [weak self] in
                self?.verifySetup()
            }
        }
    }
    
    /// Verifies that the shortcut has been properly installed and configured.
    /// This checks all required conditions before allowing the user to proceed.
    func verifySetup() {
        guard setupState != .verifying else {
            print("⚠️ ShortcutSetupViewModel: Verification already in progress")
            return
        }
        
        isVerifying = true
        setupState = .verifying
        errorMessage = nil
        
        // Perform verification asynchronously
        ShortcutVerificationService.verifyShortcutSetupAsync { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                self.isVerifying = false
                self.verificationResult = result
                
                if result.isVerified {
                    // Verification successful
                    self.setupState = .verified
                    
                    // Mark setup as complete
                    ShortcutVerificationService.markSetupComplete()
                    
                    // Wait a moment to show success state, then mark complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        Task { @MainActor [weak self] in
                            self?.setupState = .complete
                        }
                    }
                } else {
                    // Verification failed
                    self.setupState = .verificationFailed(result)
                    self.errorMessage = result.errorMessage
                }
            }
        }
    }
    
    /// Retries the verification process.
    /// Useful when the user has fixed issues and wants to verify again.
    func retryVerification() {
        shouldAutoVerify = false // Disable auto-verify after manual retry
        verifySetup()
    }
    
    /// Reopens the Shortcuts app.
    /// Useful when verification fails and the user needs to complete setup.
    func reopenShortcuts() {
        hasStartedSetup = false // Allow starting setup again
        startSetup()
    }
    
    /// Resets the setup state and allows the user to start over.
    /// Useful for testing or if the user wants to redo the setup.
    func resetSetup() {
        hasStartedSetup = false
        setupState = .initial
        verificationResult = nil
        errorMessage = nil
        isVerifying = false
        hasReturnedFromShortcuts = false
        shouldAutoVerify = false
        verificationTimer?.invalidate()
        verificationTimer = nil
    }
    
    /// Checks if the user can proceed to the next step.
    /// Returns true only if verification has passed and setup is complete.
    var canProceed: Bool {
        return setupState == .complete
    }
    
    /// Gets a user-friendly error message based on the verification result.
    /// Returns nil if there's no error or if the message is already set.
    var userFriendlyErrorMessage: String? {
        guard let result = verificationResult, !result.isVerified else {
            return errorMessage
        }
        
        if let errorMessage = errorMessage, !errorMessage.isEmpty {
            return errorMessage
        }
        
        // Generate error message from missing checks
        let messages = result.missingChecks.map { $0.userFacingMessage }
        return messages.joined(separator: "\n\n")
    }
    
    /// Gets a list of missing verification checks as user-friendly messages.
    var missingChecksMessages: [String] {
        guard let result = verificationResult, !result.isVerified else {
            return []
        }
        
        return result.missingChecks.map { $0.userFacingMessage }
    }
    
    /// Gets a summary of what needs to be fixed.
    /// Returns a concise message about what's missing.
    var missingChecksSummary: String {
        guard let result = verificationResult, !result.isVerified else {
            return ""
        }
        
        let checkNames = result.missingChecks.map { $0.displayName }
        
        if checkNames.count == 1 {
            return checkNames.first ?? ""
        } else {
            return "\(checkNames.count) issues found: " + checkNames.joined(separator: ", ")
        }
    }
}

// MARK: - Setup Steps

extension ShortcutSetupViewModel {
    
    /// Steps that guide the user through the shortcut setup process
    struct SetupStep: Identifiable {
        let id: Int
        let description: String
        
        static let allSteps: [SetupStep] = [
            SetupStep(id: 1, description: "Download the NoteWall Shortcut"),
            SetupStep(id: 2, description: "Shortcuts will open automatically"),
            SetupStep(id: 3, description: "When prompted, select the folder: Navigate to Files → On My iPhone → NoteWall → LockScreen"),
            SetupStep(id: 4, description: "Tap 'Always Allow' for each folder permission")
        ]
    }
}

// MARK: - Helper Extensions

extension ShortcutSetupViewModel.SetupState {
    
    /// Whether the setup is in a terminal state (success or failure)
    var isTerminal: Bool {
        switch self {
        case .complete, .verificationFailed:
            return true
        default:
            return false
        }
    }
    
    /// Whether the setup has completed successfully
    var isComplete: Bool {
        if case .complete = self {
            return true
        }
        return false
    }
    
    /// Whether the setup has failed
    var isFailed: Bool {
        if case .verificationFailed = self {
            return true
        }
        return false
    }
}

