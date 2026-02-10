import SwiftUI
import PhotosUI
import Photos
import UIKit
import QuartzCore
import AVKit
import AVFoundation
import AudioToolbox
import StoreKit
import UserNotifications

// Only log in debug builds to reduce console noise
#if DEBUG
private func debugLog(_ message: String) {
    print(message)
}
#else
private func debugLog(_ message: String) {
    // No-op in release builds
}
#endif

// MARK: - Video URL Helper
/// Gets video URL from Config (remote) or bundle (fallback)
/// This allows videos to be hosted online to reduce app bundle size
private func getVideoURL(for resourceName: String, withExtension ext: String = "mp4") -> URL? {
    // Try remote URL first from Config
    if let remoteURLString = Config.videoURLs[resourceName],
       let remoteURL = URL(string: remoteURLString),
       remoteURLString != "https://your-cdn-url.com/videos/\(resourceName).mp4" { // Check if placeholder URL
        debugLog("🌐 Using remote video URL for \(resourceName): \(remoteURLString)")
        return remoteURL
    }
    
    // Fallback to bundle if enabled or if remote URL is placeholder
    if Config.useBundleVideosAsFallback {
        if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: ext) {
            debugLog("📦 Using bundle video for \(resourceName) (fallback mode)")
            return bundleURL
        }
    }
    
    // If remote URL is placeholder, try bundle as last resort
    if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: ext) {
        debugLog("📦 Using bundle video for \(resourceName) (remote URL not configured)")
        return bundleURL
    }
    
    debugLog("❌ Video not found: \(resourceName).\(ext)")
    return nil
}

// MARK: - Video Player Without Controls (for Step 6)
struct VideoPlayerNoControlsView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView(player: player)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No update needed - player is managed externally
    }
    
    class PlayerUIView: UIView {
        private var playerLayer: AVPlayerLayer
        
        init(player: AVPlayer) {
            playerLayer = AVPlayerLayer(player: player)
            super.init(frame: .zero)
            
            playerLayer.videoGravity = .resizeAspect
            layer.addSublayer(playerLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}

// MARK: - Video Player With Controls and Top Crop
struct CroppedVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let topCrop: CGFloat
    
    func makeUIViewController(context: Context) -> UIViewController {
        let containerVC = ContainerViewController()
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.showsPlaybackControls = true
        // Use resizeAspect to show full width of video (no side cropping)
        // Container will clip top/bottom to remove black bar
        playerVC.videoGravity = .resizeAspect
        
        containerVC.addChild(playerVC)
        containerVC.view.addSubview(playerVC.view)
        containerVC.playerViewController = playerVC
        containerVC.topCrop = topCrop
        containerVC.player = player
        // Enable clipping to ensure overflow is discarded
        containerVC.view.clipsToBounds = true
        
        return containerVC
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let containerVC = uiViewController as? ContainerViewController {
            containerVC.topCrop = topCrop
            containerVC.view.setNeedsLayout()
        }
    }
    
    class ContainerViewController: UIViewController {
        var playerViewController: AVPlayerViewController?
        var topCrop: CGFloat = 0
        var player: AVPlayer?
        private var hasStartedPlayback = false
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
        }
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // Auto-play video when view appears
            if !hasStartedPlayback, let player = player {
                player.seek(to: .zero)
                player.play()
                hasStartedPlayback = true
                debugLog("▶️ CroppedVideoPlayerView: Auto-started playback")
            }
        }
        
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            
            guard let playerVC = playerViewController else { return }
            
            // With resizeAspect, the video shows full width and fits within container
            // Shift the video upward by topCrop to push the black bar outside visible bounds
            let containerHeight = view.bounds.height
            let containerWidth = view.bounds.width
            
            // Make the player view taller than container to accommodate the upward shift
            // The video will fit within this frame with aspect-fit (showing full width), and the container will clip the excess
            let expandedHeight = containerHeight + topCrop
            
            // Position player view shifted upward - this pushes the top black bar outside visible area
            // Bottom excess will also be clipped by the container
            playerVC.view.frame = CGRect(
                x: 0,
                y: -topCrop, // Negative offset shifts video up, pushing black bar outside container
                width: containerWidth,
                height: expandedHeight
            )
            
            // Force layout update
            playerVC.view.setNeedsLayout()
            playerVC.view.layoutIfNeeded()
        }
    }
}

enum OnboardingPage: Int, CaseIterable, Hashable {
    // Phase 0: Pre-onboarding
    case preOnboardingHook
    case nameInput
    
    // Phase 1: Emotional Hook
    case painPoint
    case quizForgetMost
    case quizPhoneChecks
    case quizDistraction
    case personalizationLoading
    case resultsPreview
    case resultsInsight
    
    // Phase 2: Social Proof & Value Demo
    case socialProof
    
    // Phase 2.5: Notification Permission (after user sees value)
    case notificationPermission
    
    // Phase 3: Technical Setup (wrapped in encouragement)
    case setupIntro
    case welcome  // Keep existing welcome (now becomes video intro step)
    case installShortcut
    case shortcutSuccess
    case addNotes
    case chooseWallpapers
    case allowPermissions
    
    // Phase 4: Celebration & Completion
    case setupComplete
    case overview    // Mockup/Overview first
    case reviewPage  // Then Review Page
}

struct OnboardingView: View {
    @Binding var isPresented: Bool
    let onboardingVersion: Int
    /// When true, this is a pipeline migration (old shortcut → new shortcut).
    /// The user is already premium, so the paywall is skipped entirely.
    var isPipelineMigration: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @AppStorage("completedOnboardingVersion") private var completedOnboardingVersion = 0
    @AppStorage("shouldShowTroubleshootingBanner") private var shouldShowTroubleshootingBanner = false
    @AppStorage("lockScreenBackground") private var lockScreenBackgroundRaw = LockScreenBackgroundOption.default.rawValue
    @AppStorage("lockScreenBackgroundMode") private var lockScreenBackgroundModeRaw = LockScreenBackgroundMode.default.rawValue
    @AppStorage("lockScreenBackgroundPhotoData") private var lockScreenBackgroundPhotoData: Data = Data()

    @AppStorage("savedNotes") private var savedNotesData: Data = Data()
    @AppStorage("saveWallpapersToPhotos") private var saveWallpapersToPhotos = false
    @AppStorage("autoUpdateWallpaperAfterDeletion") private var autoUpdateWallpaperAfterDeletionRaw: String = ""
    @AppStorage("hasShownAutoUpdatePrompt") private var hasShownAutoUpdatePrompt = false
    @AppStorage("hasRequestedAppReview") private var hasRequestedAppReview = false
    @AppStorage("hasLockScreenWidgets") private var hasLockScreenWidgets = true
    @AppStorage("onboarding_lastPageRawValue") private var savedOnboardingPageRaw: Int = 0
    @State private var didOpenShortcut = false
    @State private var shouldAdvanceToInstallStep = false
    @State private var advanceToInstallStepTimer: Timer?
    @State private var isInstallingShortcut = false
    @State private var isSavingLockScreenBackground = false
    @State private var lockScreenBackgroundStatusMessage: String?
    @State private var lockScreenBackgroundStatusColor: Color = .gray

    @State private var currentPage: OnboardingPage = .preOnboardingHook
    // Resume from saved progress (set in .onAppear)
    // For pipeline migration, starts at .welcome (set in .onAppear)
    @State private var isLaunchingShortcut = false
    @State private var shortcutLaunchFallback: DispatchWorkItem?
    @State private var wallpaperVerificationTask: Task<Void, Never>?
    @State private var didTriggerShortcutRun = false
    @State private var isLoadingWallpaperStep = false
    @State private var demoVideoPlayer: AVQueuePlayer?
    @State private var demoVideoLooper: AVPlayerLooper?
    @State private var notificationsVideoPlayer: AVQueuePlayer?
    @State private var notificationsVideoLooper: AVPlayerLooper?
    @State private var notificationsVideoAspectRatio: CGFloat?
    @State private var welcomeVideoPlayer: AVQueuePlayer?
    @State private var welcomeVideoLooper: AVPlayerLooper?
    @State private var isWelcomeVideoMuted: Bool = false
    @State private var isWelcomeVideoPaused: Bool = false
    @State private var welcomeVideoProgress: Double = 0.0
    @State private var welcomeVideoDuration: Double = 0.0
    @State private var welcomeVideoProgressTimer: Timer?
    @State private var stuckGuideVideoPlayer: AVQueuePlayer?
    @State private var stuckGuideVideoLooper: AVPlayerLooper?
    @State private var isStuckVideoMuted: Bool = false
    @State private var isStuckVideoPaused: Bool = false
    @State private var stuckVideoProgress: Double = 0.0
    @State private var stuckVideoDuration: Double = 0.0
    @State private var stuckVideoProgressTimer: Timer?
    @StateObject private var pipVideoPlayerManager = PIPVideoPlayerManager()
    @State private var shouldStartPiP = false
    private let demoVideoPlaybackRate: Float = 1.5
    private let stuckVideoResourceName = "how-to-fix-guide"
    
    // Post-onboarding troubleshooting
    @State private var showTroubleshooting = false
    @State private var shouldRestartOnboarding = false
    
    // Notes management for onboarding
    @State private var onboardingNotes: [Note] = []
    @State private var currentNoteText = ""
    @FocusState private var isNoteFieldFocused: Bool
    
    // Widget selection tracking
    @State private var hasSelectedWidgetOption = false
    
    // Post-onboarding paywall
    @State private var showPostOnboardingPaywall = false
    @State private var showDiscountedPaywall = false
    @StateObject private var paywallManager = PaywallManager.shared
    
    // Final step mockup preview
    @State private var showMockupPreview = false
    @State private var loadedWallpaperImage: UIImage?
    @State private var useLightMockup: Bool = true
    
    // Transition animation from step 6 to step 7
    @State private var showTransitionScreen = false
    @State private var countdownNumber: Int = 3
    @State private var showConfetti = false
    @State private var confettiTrigger: Int = 0
    @State private var hideProgressIndicator = false
    @State private var transitionTextOpacity: Double = 0
    @State private var countdownOpacity: Double = 0
    
    // Enhanced transition animation states
    @State private var word1Visible = false
    @State private var word2Visible = false
    @State private var word3Visible = false
    @State private var word4Visible = false
    @State private var ringProgress: CGFloat = 0
    @State private var countdownGlow: CGFloat = 0
    @State private var particleBurst: Bool = false
    @State private var gradientRotation: Double = 0
    
    // Help button and support
    @State private var showHelpSheet = false
    @State private var improvementText = ""
    @State private var showImprovementSuccess = false
    @State private var showImprovementForm = false
    @State private var showHelpAlert = false
    @State private var helpAlertMessage = ""
    @State private var isSendingImprovement = false
    @FocusState private var isImprovementFieldFocused: Bool
    
    // Safari availability check
    @State private var showShortcutsCheckAlert = false
    @State private var isTransitioningBetweenPopups = false
    @State private var hasCheckedSafariOnStep2 = false
    @State private var hasCompletedShortcutsCheck = false
    @State private var hasCompletedSafariCheck = false
    @State private var wentToAppStoreForShortcuts = false
    
    // Pre-onboarding hook animation states
    @State private var firstNoteOpacity: Double = 0
    @State private var firstNoteScale: CGFloat = 0.8
    @State private var firstNoteOffset: CGFloat = 0
    @State private var firstNoteXOffset: CGFloat = -300 // Start off-screen left (left to right)
    @State private var firstNoteRotation: Double = -15 // Start rotated
    @State private var notesOpacity: [Double] = [0, 0, 0]
    @State private var notesOffset: [CGFloat] = [0, 0, 0]
    // Alternate directions: [right-to-left, left-to-right, right-to-left]
    @State private var notesXOffset: [CGFloat] = [300, -300, 300] // Alternate: right, left, right
    @State private var notesScale: [CGFloat] = [0.8, 0.8, 0.8] // Start smaller
    @State private var notesRotation: [Double] = [15, -15, 15] // Alternate rotation directions
    @State private var mockupOpacity: Double = 0
    @State private var mockupScale: CGFloat = 0.95
    @State private var mockupRotation: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var continueButtonOpacity: Double = 0
    @State private var overallScale: CGFloat = 1.0
    @State private var overallOffset: CGFloat = 100 // Start lower on screen
    @State private var hasStartedPreOnboardingAnimation = false

    private var shortcutURL: String {
        // During pipeline migration, always use the new lock-screen-only shortcut
        if isPipelineMigration {
            return ShortcutSetupViewModel.newShortcutURLString
        }
        return ShortcutSetupViewModel.getShortcutURL()
    }
    private let whatsappNumber = "421907758852" // Replace with your actual WhatsApp number
    private let supportEmail = "iosnotewall@gmail.com" // Replace with your actual support email

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                navigationStackOnboarding
            } else {
                navigationViewOnboarding
            }
        }
        .interactiveDismissDisabled()
        .task {
            HomeScreenImageManager.prepareStorageStructure()
        }
        .onAppear {
            // CRITICAL: Reset shortcut launch state when onboarding appears
            // This prevents shortcuts from running automatically when onboarding first opens
            // (e.g., when user clicks "Reinstall Shortcut" button)
            debugLog("📱 Onboarding: View appeared, resetting shortcut launch state")
            isLaunchingShortcut = false
            didTriggerShortcutRun = false
            shortcutLaunchFallback?.cancel()
            shortcutLaunchFallback = nil
            wallpaperVerificationTask?.cancel()
            wallpaperVerificationTask = nil
            
            // Pipeline migration: skip quiz/hook sections, jump straight to technical setup
            if isPipelineMigration {
                debugLog("📱 Onboarding: Pipeline migration mode — skipping to technical setup (.welcome)")
                currentPage = .welcome
                AnalyticsService.shared.logEvent(
                    .custom(
                        name: "pipeline_migration_onboarding_started",
                        parameters: ["start_page": "welcome"]
                    )
                )
                return // Skip saved progress restoration and abandoned notifications
            }
            
            // Track onboarding start (fires only once per session)
            OnboardingAnalyticsTracker.shared.onboardingDidAppear()
            
            #if !DEBUG
            // Restore onboarding progress - resume where user left off
            // NOTE: This is disabled in DEBUG builds to allow testing the full onboarding flow
            if savedOnboardingPageRaw > 0,
               let savedPage = OnboardingPage(rawValue: savedOnboardingPageRaw) {
                debugLog("📱 Onboarding: Resuming from saved page: \(savedPage.progressTitle)")
                currentPage = savedPage
                // Cancel abandoned onboarding notifications since user returned
                NotificationManager.shared.cancelAbandonedOnboardingReminders()
                // Re-schedule them (they'll be cancelled when onboarding completes)
                NotificationManager.shared.scheduleAbandonedOnboardingReminders()
            }
            #endif
        }
        .onChange(of: currentPage) { _, newPage in
            // Track step view whenever page changes
            OnboardingAnalyticsTracker.shared.trackStepView(newPage)
            #if !DEBUG
            // Persist progress so user can resume if they quit
            // NOTE: This is disabled in DEBUG builds to allow testing the full onboarding flow
            savedOnboardingPageRaw = newPage.rawValue
            #endif
            // Reschedule abandoned notifications on each step (resets the timers)
            if newPage != .preOnboardingHook {
                NotificationManager.shared.scheduleAbandonedOnboardingReminders()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutWallpaperApplied)) { _ in
            completeShortcutLaunch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .wallpaperGenerationFinished)) { _ in
            handleWallpaperGenerationFinished()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                debugLog("📱 Onboarding: App became active, currentPage: \(currentPage), didOpenShortcut: \(didOpenShortcut)")
                // ALWAYS stop PiP when returning to app - be aggressive about it
                // This ensures PiP disappears when user returns from Shortcuts app
                debugLog("🛑 Onboarding: Stopping PiP video (app became active)")
                pipVideoPlayerManager.stopPictureInPicture()
                pipVideoPlayerManager.stop()
                shouldStartPiP = false
                
                // Double-check after a brief delay to ensure it's stopped
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if self.pipVideoPlayerManager.isPiPActive {
                        debugLog("⚠️ Onboarding: PiP still active after stop, forcing stop again")
                        self.pipVideoPlayerManager.stopPictureInPicture()
                        self.pipVideoPlayerManager.stop()
                    }
                }
                
                // Handle return from App Store during welcome step setup
                if currentPage == .welcome && wentToAppStoreForShortcuts {
                    debugLog("📱 Onboarding: Returned from App Store (Shortcuts download)")
                    wentToAppStoreForShortcuts = false
                    
                    // Ensure Shortcuts check is marked complete so Safari section shows
                    withAnimation {
                        hasCompletedShortcutsCheck = true
                    }
                    
                    // Ensure the sheet is still showing
                    if !showShortcutsCheckAlert {
                        showShortcutsCheckAlert = true
                    }
                    isTransitioningBetweenPopups = false
                }
                
                // Handle return from Shortcuts app after installing shortcut
                // DON'T auto-advance - let user stay on Step 3 to see "Did it work?" screen
                if currentPage == .installShortcut && didOpenShortcut {
                    debugLog("📱 Onboarding: Detected return from Shortcuts app, staying on installShortcut step")
                    // Reset the flag and hide "Ready to Try Again?" screen to show "Installation Check"
                    self.didOpenShortcut = false
                    self.userWentToSettings = false
                    debugLog("✅ Onboarding: User can now interact with Step 3 - showing Installation Check screen")
                }
                // Only complete shortcut launch if we're on the chooseWallpapers step
                if currentPage == .chooseWallpapers {
                    completeShortcutLaunch()
                }
            } else if newPhase == .background {
                // Advance to step 3 when app backgrounds after opening Shortcuts
                if shouldAdvanceToInstallStep {
                    debugLog("📱 Onboarding: App went to background, advancing to installShortcut step")
                    // Cancel fallback timer since app backgrounded successfully
                    advanceToInstallStepTimer?.invalidate()
                    advanceToInstallStepTimer = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut) {
                            self.currentPage = .installShortcut
                        }
                        self.shouldAdvanceToInstallStep = false
                    }
                }
                
                // PiP should automatically take over the already-playing video
                // because we set canStartPictureInPictureAutomaticallyFromInline = true
                if shouldStartPiP && currentPage == .installShortcut {
                    debugLog("🎬 Onboarding: App went to background")
                    debugLog("   - Video should already be playing")
                    debugLog("   - PiP should take over automatically")
                    
                    // If automatic PiP doesn't work, try manual start as fallback
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if !self.pipVideoPlayerManager.isPiPActive {
                            debugLog("⚠️ Onboarding: Automatic PiP didn't start, trying manual start")
                            if self.pipVideoPlayerManager.isReadyToPlay && self.pipVideoPlayerManager.isPiPControllerReady {
                                let success = self.pipVideoPlayerManager.startPictureInPicture()
                                if success {
                                    debugLog("✅ Onboarding: PiP started manually")
                                } else {
                                    debugLog("❌ Onboarding: Manual PiP start also failed")
                                }
                            }
                        } else {
                            debugLog("✅ Onboarding: Automatic PiP is active")
                        }
                    }
                }
            }
        }
        .onChange(of: currentPage) { _, page in
            if page == .chooseWallpapers {
                HomeScreenImageManager.prepareStorageStructure()
            }
            

            
            // Auto-play notifications video when entering step 6
            if page == .allowPermissions {
                prepareNotificationsVideoPlayerIfNeeded()
                
                // Start playback with multiple retry attempts
                func startVideoPlayback() {
                    if let player = self.notificationsVideoPlayer {
                        // Ensure looper is active for continuous looping
                        if let looper = self.notificationsVideoLooper {
                            if looper.status == .failed, let item = player.currentItem {
                                // Recreate looper if needed
                                let newLooper = AVPlayerLooper(player: player, templateItem: item)
                                self.notificationsVideoLooper = newLooper
                                debugLog("🔄 Recreated video looper in onChange")
                            }
                        } else if let item = player.currentItem {
                            // Create looper if it doesn't exist
                            let newLooper = AVPlayerLooper(player: player, templateItem: item)
                            self.notificationsVideoLooper = newLooper
                            debugLog("🔄 Created video looper in onChange")
                        }
                        
                        player.seek(to: .zero)
                        player.play()
                        
                        // Verify playback started
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if player.rate == 0 {
                                player.seek(to: .zero)
                                player.play()
                                debugLog("▶️ Notifications video retry (entering step 6)")
                            } else {
                                debugLog("▶️ Notifications video playing and looping (entering step 6)")
                            }
                        }
                    } else {
                        // Player not ready, try again
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            startVideoPlayback()
                        }
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    startVideoPlayback()
                }
            }
        }
        .onChange(of: shouldRestartOnboarding) { _, shouldRestart in
            if shouldRestart {
                // Reset to first page and restart onboarding
                withAnimation {
                    currentPage = .welcome
                }
                shouldRestartOnboarding = false
            }
        }
        .onChange(of: showShortcutsCheckAlert) { _, isShowing in
            // No special handling needed - requirements check is a simple sheet
        }
        .onChange(of: showInstallSheet) { _, isShowing in
            if isShowing {
                // Install sheet is showing
            }
            // Reset flag after a short delay
            if !isShowing && isInstallingShortcut {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isInstallingShortcut = false
                }
            }
        }
        .sheet(isPresented: $showInstallSheet) {
            installSheetView()
                .onAppear {
                    AnalyticsService.shared.trackScreenView(screenName: "onboarding_install_sheet")
                }
        }
        .sheet(isPresented: $showTroubleshooting) {
            troubleshootingModalView
                .onAppear {
                    AnalyticsService.shared.trackScreenView(screenName: "troubleshooting_modal")
                }
        }
        .sheet(isPresented: $showPostOnboardingPaywall) {
            PaywallView(triggerReason: .firstWallpaperCreated, allowDismiss: false)
                .interactiveDismissDisabled(true)
                .onDisappear {
                    // When paywall is dismissed (user subscribed, or restored)
                    
                    // CRITICAL: Only complete onboarding if user is PREMIUM or LIFETIME
                    // This enforces the hard paywall requirement
                    guard PaywallManager.shared.isPremium else {
                        // If they somehow dismissed it without paying (shouldn't happen with interactiveDismissDisabled),
                        // do NOT complete setup. They will remain in onboarding.
                        debugLog("⚠️ Paywall dismissed but user is NOT premium. Staying in onboarding.")
                        return
                    }
                    
                    // Track analytics
                    OnboardingQuizState.shared.paywallShown = true
                    OnboardingAnalytics.trackPaywallShown(totalSetupTime: OnboardingQuizState.shared.totalSetupTime)
                    
                    // Update Superwall attributes
                    SuperwallUserAttributesManager.shared.updateOnboardingAttributes()

                    debugLog("✅ Onboarding Paywall dismissed")
                    
                    // Complete onboarding regardless of subscription status
                    // Freemium users get access to home but features are gated
                    if currentPage == .reviewPage {
                        debugLog("✅ Completing onboarding - user may proceed as freemium")
                        hasCompletedSetup = true
                        completedOnboardingVersion = onboardingVersion
                        WhatsNewManager.shared.markAsShown()
                    }
                }
        }
        .sheet(isPresented: $showDiscountedPaywall) {
            if #available(iOS 15.0, *) {
                PaywallView(
                    triggerReason: .exitIntercept,
                    allowDismiss: true,
                    applyExitInterceptDiscount: true
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickActionTriggered)) { notification in
            debugLog("📥 OnboardingView: Received quick action notification")
            if let actionType = notification.object as? QuickActionsManager.QuickActionType {
                if actionType == .claimDiscount {
                    // Force show the discounted paywall
                    // We need a slight delay to ensure any existing sheets are dismissed if needed,
                    // or to present over them. Since sheets can stack in SwiftUI 2.0+ (iOS 15+),
                    // simply setting this to true should work, but for safety:
                    
                    debugLog("✅ OnboardingView: Presenting discounted paywall via Quick Action")
                    
                    // Provide haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // Present the sheet
                    self.showDiscountedPaywall = true
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func installSheetView() -> some View {
        if #available(iOS 16.0, *) {
            installSheetContent()
                .presentationDetents([.medium])
        } else {
            installSheetContent()
        }
    }

    private func installSheetContent() -> some View {
        ZStack(alignment: .topTrailing) {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundColor(.appAccent)
                    .padding(.top, 40)
                
                Text("Install Shortcut")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(spacing: 8) {
                    Text("We'll open the Shortcuts app now.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "pip")
                            .font(.body)
                            .foregroundColor(.appAccent)
                        Text("A video guide will appear")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.appAccent)
                    }
                    
                    Text("Follow the guide step-by-step - it will show you exactly what to do!")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                
                Spacer(minLength: 0)
                
                Button(action: {
                    // Medium haptic for important installation action
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // Set flag to prevent video from auto-resuming
                    isInstallingShortcut = true
                    showInstallSheet = false
                    // Set flag to advance to step 3 when app backgrounds
                    shouldAdvanceToInstallStep = true
                    // Set up fallback timer in case app doesn't background (e.g., iPad split screen)
                    advanceToInstallStepTimer?.invalidate()
                    advanceToInstallStepTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                        if self.shouldAdvanceToInstallStep {
                            debugLog("📱 Onboarding: Fallback timer triggered, advancing to installShortcut step")
                            withAnimation(.easeInOut) {
                                self.currentPage = .installShortcut
                            }
                            self.shouldAdvanceToInstallStep = false
                        }
                    }
                    // Launch installation - this will open Shortcuts app
                    // Step 3 will be shown automatically when app backgrounds
                    installShortcut()
                }) {
                    Text("Install & Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appAccent)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
            
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                showInstallSheet = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
            .zIndex(1000)
        }
    }

    @ViewBuilder
    private var navigationViewOnboarding: some View {
        NavigationView {
            onboardingPager(includePhotoPicker: false)
        }
    }

    @available(iOS 16.0, *)
    private var navigationStackOnboarding: some View {
        NavigationStack {
            onboardingPager(includePhotoPicker: true)
        }
    }

    private func onboardingPager(includePhotoPicker: Bool) -> some View {
        ZStack {
            // Dark gradient background for new emotional pages and video introduction
            // These pages have their own dark backgrounds
            let needsDarkBackground = [
                OnboardingPage.painPoint, .quizForgetMost, .quizPhoneChecks, .quizDistraction,
                .personalizationLoading, .resultsPreview, .socialProof, .notificationPermission, .reviewPage, .setupIntro,
                .shortcutSuccess, .setupComplete
            ].contains(currentPage)
            
            if needsDarkBackground {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            } else {
                Color(.systemBackground)
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // Progress indicator - only shown on technical setup steps
                if !hideProgressIndicator && !showTransitionScreen && currentPage.showsProgressIndicator {
                    onboardingProgressIndicatorCompact
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity)
                        // Transparent background for dark pages
                        .background(
                            needsDarkBackground ? Color.clear : Color(.systemBackground)
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                ZStack {
                    // Transparent background for dark pages to show continuous gradient
                    if needsDarkBackground {
                        Color.clear
                            .ignoresSafeArea()
                    } else {
                    // Solid background to prevent seeing underlying content during transitions
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    }
                    
                    Group {
                        switch currentPage {
                        case .preOnboardingHook:
                            preOnboardingHookStep()
                        case .nameInput:
                            NameInputView {
                                OnboardingAnalyticsTracker.shared.trackAction(.next, on: .nameInput)
                                advanceStep()
                            }
                        case .notificationPermission:
                            NotificationPermissionView {
                                // Track action
                                OnboardingAnalyticsTracker.shared.trackAction(.next, on: .notificationPermission)
                                // Schedule abandoned onboarding notifications
                                NotificationManager.shared.scheduleAbandonedOnboardingReminders()
                                advanceStep()
                            }
                        case .painPoint:
                            PainPointView {
                                advanceStep()
                            }
                        case .quizForgetMost:
                            MultiSelectQuizQuestionView(
                                question: "But before we start, what do you forget the most?",
                                subtitle: "Select all that apply",
                                options: QuizData.forgetMostOptions
                            ) { answers in
                                OnboardingQuizState.shared.forgetMostList = answers
                                // Track action with answers
                                OnboardingAnalyticsTracker.shared.trackAction(.next, on: .quizForgetMost, additionalParams: ["answers": answers.joined(separator: ",")])
                                advanceStep()
                            }
                        case .quizPhoneChecks:
                            QuizQuestionView(
                                question: "And how often do you check your phone?",
                                subtitle: "Be honest, no judgment!",
                                options: QuizData.phoneChecksOptions
                            ) { answer in
                                OnboardingQuizState.shared.phoneChecks = answer
                                // Track action
                                OnboardingAnalyticsTracker.shared.trackAction(.next, on: .quizPhoneChecks, additionalParams: ["answer": answer])
                                advanceStep()
                            }
                        case .quizDistraction:
                            MultiSelectQuizQuestionView(
                                question: "Last one: what's your biggest distraction?",
                                subtitle: "Select all that apply",
                                options: QuizData.distractionOptions
                            ) { answers in
                                OnboardingQuizState.shared.biggestDistractionList = answers
                                // Track action
                                OnboardingAnalyticsTracker.shared.trackAction(.next, on: .quizDistraction, additionalParams: ["answers": answers.joined(separator: ",")])
                                advanceStep()
                            }
                        case .personalizationLoading:
                            PersonalizationLoadingView {
                                // Track action
                                OnboardingAnalyticsTracker.shared.trackAction(.next, on: .personalizationLoading)
                                advanceStep()
                            }
                        case .resultsPreview:
                            ResultsPreviewView {
                                // Track action
                                OnboardingAnalyticsTracker.shared.trackAction(.next, on: .resultsPreview)
                                advanceStep()
                            }
                        case .resultsInsight:
                            ResultsInsightView {
                                // Track action
                                OnboardingAnalyticsTracker.shared.trackAction(.next, on: .resultsInsight)
                                advanceStep()
                            }
                        case .socialProof:
                            SocialProofView {
                                // Track action
                                OnboardingAnalyticsTracker.shared.trackAction(.next, on: .socialProof)
                                advanceStep()
                            }
                        case .setupIntro:
                            SetupIntroView(
                                title: "Quick 4-Minute Setup",
                                subtitle: "Let's get your focus system working",
                                icon: "gearshape.2.fill",
                                steps: QuizData.setupSteps,
                                timeEstimate: "About 4 minutes",
                                ctaText: "Let's Do This!"
                            ) {
                                // Track action
                                OnboardingAnalyticsTracker.shared.trackAction(.next, on: .setupIntro)
                                advanceStep()
                            }
                        case .welcome:
                            welcomeStep()
                        case .installShortcut:
                            installShortcutStep()
                        case .shortcutSuccess:
                            CelebrationView(
                                title: "🎉 Nailed It!",
                                subtitle: "That was the hardest part.\nEverything else takes under 60 seconds.",
                                encouragement: "You're crushing this setup!",
                                nextStepPreview: "Add your first notes"
                            ) {
                                // Track action
                                OnboardingAnalyticsTracker.shared.trackAction(.next, on: .shortcutSuccess)
                                advanceStep()
                            }
                        case .addNotes:
                            addNotesStep()
                        case .chooseWallpapers:
                            chooseWallpapersStep(includePhotoPicker: includePhotoPicker)
                        case .allowPermissions:
                            allowPermissionsStep()
                        case .setupComplete:
                            SetupCompleteView {
                                // Track action
                                OnboardingAnalyticsTracker.shared.trackAction(.next, on: .setupComplete)
                                // Trigger countdown transition after setup complete
                                startTransitionCountdown()
                            }
                        case .reviewPage:
                            ReviewPageView {
                                // Track action
                                OnboardingAnalyticsTracker.shared.trackAction(.next, on: .reviewPage)
                                advanceStep()
                            }
                        case .overview:
                            overviewStep()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .id(currentPage)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                .animation(.easeInOut(duration: 0.25), value: currentPage)
                .gesture(
                    DragGesture()
                        .onEnded { gesture in
                            handleSwipeGesture(gesture)
                        }
                )

                // Hide button during transition and on pages with their own buttons
                // New emotional hook pages (painPoint, quiz, results, socialProof, setupIntro, celebrations) have built-in buttons
                if !showTransitionScreen && currentPage.showsProgressIndicator {
                    primaryButtonSection
                }
            }
            .opacity(showTransitionScreen ? 0 : 1)
            
            // Transition screen overlay
            if showTransitionScreen {
                transitionCountdownView
                    .transition(.opacity)
            }
            
            // Confetti overlay (uses ConfettiView from OnboardingEnhanced.swift)
            if showConfetti {
                ConfettiView(trigger: $confettiTrigger)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
            
            // Help button - visible only on technical setup steps
            // Different positioning for overview step (smaller, in grey corner)
            // Hidden on chooseWallpapers step as it's now integrated into the content
            if currentPage.showsProgressIndicator && currentPage != .welcome && currentPage != .chooseWallpapers {
                VStack {
                    HStack {
                        Spacer()
                        if currentPage == .overview {
                            // Smaller help button for overview step
                            compactHelpButton
                                .padding(.top, 8)
                                .padding(.trailing, 8)
                        } else {
                            helpButton
                                .padding(.top, 100)
                                .padding(.trailing, 16)
                        }
                    }
                    Spacer()
                }
                .allowsHitTesting(true)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: showHelpSheet) { _, isShowing in
            // Help sheet dismissed - no special handling needed
        }
        .sheet(isPresented: $showHelpSheet) {
            helpOptionsSheet
                .onAppear {
                    AnalyticsService.shared.trackScreenView(screenName: "onboarding_help_sheet")
                }
        }
        .sheet(isPresented: $showImprovementForm) {
            improvementFormSheet
                .onAppear {
                    AnalyticsService.shared.trackScreenView(screenName: "onboarding_feedback_sheet")
                }
        }
        .alert(isPresented: $showHelpAlert) {
            Alert(
                title: Text("Notice"),
                message: Text(helpAlertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .animation(.easeInOut(duration: 0.4), value: hideProgressIndicator)
        .animation(.easeInOut(duration: 0.3), value: showTransitionScreen)
    }

    private var onboardingProgressIndicatorCompact: some View {
        let technicalSteps: [OnboardingPage] = [.welcome, .installShortcut, .addNotes, .chooseWallpapers, .allowPermissions]
        
        return HStack(alignment: .center, spacing: 12) {
            ForEach(technicalSteps, id: \.self) { page in
                Button(action: {
                    // Only allow navigation to previous steps (not future ones)
                    if page.rawValue < currentPage.rawValue {
                        // Light haptic for navigation
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage = page
                        }
                    }
                }) {
                    progressIndicatorItem(for: page, displayMode: .compact)
                }
                .buttonStyle(.plain)
                .disabled(page.rawValue >= currentPage.rawValue) // Disable future steps
            }
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("\(currentPage.accessibilityLabel) of 6")
    }

    private var primaryButtonSection: some View {
        let isCompact = ScreenDimensions.isCompactDevice
        let buttonHeight: CGFloat = isCompact ? 48 : 56
        let buttonIconSize: CGFloat = isCompact ? 18 : 20
        let horizontalPadding: CGFloat = isCompact ? 16 : 24
        let topPadding: CGFloat = isCompact ? 12 : 18
        let bottomPadding: CGFloat = isCompact ? 16 : 22
        
        return VStack(spacing: isCompact ? 8 : 12) {
            // Hide primary button for installShortcut and overview steps as they have custom buttons
            if currentPage != .installShortcut && currentPage != .overview {
            Button(action: handlePrimaryButton) {
                HStack(spacing: 12) {
                    if currentPage == .chooseWallpapers && isLaunchingShortcut {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .tint(.white)
                    } else if let iconName = primaryButtonIconName {
                        Image(systemName: iconName)
                            .font(.system(size: buttonIconSize, weight: .semibold))
                    }

                    Text(primaryButtonTitle)
                        .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(height: buttonHeight)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: primaryButtonEnabled))
            .disabled(!primaryButtonEnabled)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .background(
            Color(.systemBackground).ignoresSafeArea(edges: .bottom)
        )
    }

    private func preOnboardingHookStep() -> some View {
        let isCompact = ScreenDimensions.isCompactDevice
        let titleFontSize: CGFloat = isCompact ? 26 : 32
        let taglineFontSize: CGFloat = isCompact ? 17 : 20
        let buttonHeight: CGFloat = isCompact ? 48 : 56
        let buttonIconSize: CGFloat = isCompact ? 18 : 20
        
        return GeometryReader { geometry in
            ZStack {
                // Pure black or very dark gradient background
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Phone mockup container with actual mockup image
                    preOnboardingMockupView(geometry: geometry)
                    
                    Spacer()
                    
                    // App title below mockup
                    Text("NoteWall")
                        .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(taglineOpacity)
                        .padding(.top, isCompact ? 20 : 30)
                    
                    // Tagline below app title - action-oriented phrase that suggests the benefit
                    Text("Never miss what matters")
                        .font(.system(size: taglineFontSize, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(taglineOpacity)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, isCompact ? 8 : 12)
                    
                    // Continue button with fade-in - matching Step 1 button position
                    Button(action: {
                        // Track "Get Started" tap
                        OnboardingAnalyticsTracker.shared.trackAction(.next, on: .preOnboardingHook)
                        
                        // Start quiz state tracking
                        OnboardingQuizState.shared.startTime = Date()
                        
                        withAnimation(.easeInOut(duration: 0.4)) {
                            currentPage = .nameInput
                        }
                    }) {
                        HStack(spacing: 12) {
                            Text("Get Started")
                                .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                            
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: buttonIconSize, weight: .semibold))
                        }
                        .frame(height: buttonHeight)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
                    .opacity(continueButtonOpacity)
                    .padding(.horizontal, isCompact ? 16 : 24)
                    .padding(.top, isCompact ? 12 : 18) // Match Step 1 button top padding
                    .padding(.bottom, isCompact ? 16 : 22) // Match Step 1 button bottom padding
                }
            }
        }
        .onAppear {
            if !hasStartedPreOnboardingAnimation {
                hasStartedPreOnboardingAnimation = true
                startPreOnboardingAnimation()
            }
        }
    }
    
    @ViewBuilder
    private func preOnboardingMockupView(geometry: GeometryProxy) -> some View {
        // Calculate mockup dimensions - made bigger since button is now positioned higher
        let availableHeight = geometry.size.height * 0.75 // Increased from 0.7 to 0.75
        let availableWidth = geometry.size.width
        // Actual aspect ratio of step0_mockup.png: 1892 x 4300 = 0.44 (1/2.27)
        let mockupAspectRatio: CGFloat = 1892.0 / 4300.0
        let maxMockupHeight = availableHeight
        let maxMockupWidth = availableWidth * 0.9 // Increased from 0.85 to 0.9
        
        // Calculate dimensions that preserve aspect ratio without cropping
        let mockupWidth = min(maxMockupHeight * mockupAspectRatio, maxMockupWidth)
        let mockupHeight = mockupWidth / mockupAspectRatio
        
        // Screen insets within the mockup frame (must match transparent screen window in mockup PNG)
        let screenInsetTop: CGFloat = mockupHeight * 0.012
        let screenInsetBottom: CGFloat = mockupHeight * 0.012
        let screenInsetHorizontal: CGFloat = mockupWidth * 0.042
        
        // Calculate screen dimensions - fits within the transparent window
        let screenWidth = mockupWidth - (screenInsetHorizontal * 2)
        let screenHeight = mockupHeight - screenInsetTop - screenInsetBottom
        
        // Corner radius that matches the mockup's screen corners
        let screenCornerRadius = mockupWidth * 0.115
        
        ZStack {
            // iPhone mockup overlay (transparent screen window) - positioned behind notes
            // Use aspectRatio modifier to preserve the full image without cropping
            // Remove frame constraints to allow natural sizing based on aspect ratio
            Image("step0_mockup")
                .resizable()
                .aspectRatio(mockupAspectRatio, contentMode: .fit)
                .frame(width: mockupWidth, height: mockupHeight)
                .opacity(mockupOpacity)
                .scaleEffect(mockupScale)
                .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 15)
                .zIndex(1) // Mockup behind notes
            
            // Lock screen content layer (above the mockup) - shows through transparent screen area
            // Positioned exactly like step 7 - content is centered, sized to screen area, and masked
            // Note: Time and date are already in the mockup image, so we only show notes here
            // Uses same font system as WallpaperRenderer: San Francisco, Heavy weight, adaptive size
            preOnboardingNotesView(
                screenWidth: screenWidth,
                screenHeight: screenHeight
            )
            .frame(width: screenWidth, height: screenHeight)
            .clipped()
            .mask(
                RoundedRectangle(cornerRadius: screenCornerRadius, style: .continuous)
            )
            // Offset content to align with mockup's transparent screen area
            // Screen area is at (screenInsetHorizontal, screenInsetTop) from mockup's top-left
            // Since mockup is centered, offset content by: (inset - mockupSize/2 + screenSize/2)
            .offset(
                x: screenInsetHorizontal - mockupWidth/2 + screenWidth/2,
                y: screenInsetTop - mockupHeight/2 + screenHeight/2
            )
            .zIndex(2) // Notes above mockup
        }
        .frame(width: mockupWidth, height: mockupHeight, alignment: .center)
    }
    
    @ViewBuilder
    private func preOnboardingNotesView(screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        // Notes positioned on lock screen - using same styling as actual wallpaper
        // Calculate adaptive font size similar to WallpaperRenderer
        let sampleNotes = [
            "Remember to call mom",
            "Read 10 pages tonight",
            "Stop doom scrolling",
            "Text Sarah back"
        ]
        // Calculate available space for notes (similar to WallpaperRenderer)
        // Use a portion of screen height for notes area
        let availableHeightForNotes = screenHeight * 0.5
        let availableWidthForNotes = screenWidth - 64 // Account for horizontal padding (32 on each side)
        let calculatedFontSize = calculateAdaptiveFontSize(
            for: sampleNotes,
            availableHeight: availableHeightForNotes,
            availableWidth: availableWidthForNotes
        )
        
        VStack(spacing: 0) {
            // Add top spacing to push notes down from the time display
            Spacer()
                .frame(height: 60) // Gap between time and first note when they appear on mockup
            
            VStack(alignment: .leading, spacing: 0) {
                // First note
                Text("Remember to call mom")
                    .font(.system(size: calculatedFontSize, weight: .heavy))
                    .foregroundColor(Color.white)
                    .opacity(firstNoteOpacity)
                    .scaleEffect(firstNoteScale)
                    .rotationEffect(.degrees(firstNoteRotation))
                    .offset(x: firstNoteXOffset, y: firstNoteOffset)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: Color.black.opacity(0.7), radius: calculatedFontSize * 0.08, x: 0, y: 2)
                    .padding(.bottom, calculatedFontSize * 0.45) // Separator spacing like WallpaperRenderer
                
                // Additional notes
                Text("Read 10 pages tonight")
                    .font(.system(size: calculatedFontSize, weight: .heavy))
                    .foregroundColor(Color.white)
                    .opacity(notesOpacity[0])
                    .scaleEffect(notesScale[0])
                    .rotationEffect(.degrees(notesRotation[0]))
                    .offset(x: notesXOffset[0], y: notesOffset[0])
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: Color.black.opacity(0.7), radius: calculatedFontSize * 0.08, x: 0, y: 2)
                    .padding(.bottom, calculatedFontSize * 0.45)
                
                Text("Stop doom scrolling")
                    .font(.system(size: calculatedFontSize, weight: .heavy))
                    .foregroundColor(Color.white)
                    .opacity(notesOpacity[1])
                    .scaleEffect(notesScale[1])
                    .rotationEffect(.degrees(notesRotation[1]))
                    .offset(x: notesXOffset[1], y: notesOffset[1])
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: Color.black.opacity(0.7), radius: calculatedFontSize * 0.08, x: 0, y: 2)
                    .padding(.bottom, calculatedFontSize * 0.45)
                
                Text("Text Sarah back")
                    .font(.system(size: calculatedFontSize, weight: .heavy))
                    .foregroundColor(Color.white)
                    .opacity(notesOpacity[2])
                    .scaleEffect(notesScale[2])
                    .rotationEffect(.degrees(notesRotation[2]))
                    .offset(x: notesXOffset[2], y: notesOffset[2])
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: Color.black.opacity(0.7), radius: calculatedFontSize * 0.08, x: 0, y: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.bottom, 120)
            .scaleEffect(overallScale)
            .offset(y: overallOffset)
            
            Spacer()
        }
    }
    
    /// Calculates adaptive font size for notes (similar to WallpaperRenderer)
    /// Returns font size that fits all notes without truncation
    private func calculateAdaptiveFontSize(
        for notes: [String],
        availableHeight: CGFloat,
        availableWidth: CGFloat
    ) -> CGFloat {
        let minFontSize: CGFloat = 20 // Half of 40
        let maxFontSize: CGFloat = 50 // Half of 100
        let fontWeight = UIFont.Weight.heavy
        
        guard !notes.isEmpty else { return maxFontSize }
        
        // Check if all notes fit at max font size
        if doNotesFit(notes, atFontSize: maxFontSize, availableHeight: availableHeight, availableWidth: availableWidth, fontWeight: fontWeight) {
            return maxFontSize
        }
        
        // Binary search to find optimal size
        var low = minFontSize
        var high = maxFontSize
        var bestFit = minFontSize
        
        while low <= high {
            let mid = (low + high) / 2
            if doNotesFit(notes, atFontSize: mid, availableHeight: availableHeight, availableWidth: availableWidth, fontWeight: fontWeight) {
                bestFit = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        
        return bestFit
    }
    
    /// Checks if all notes fit at given font size
    private func doNotesFit(
        _ notes: [String],
        atFontSize fontSize: CGFloat,
        availableHeight: CGFloat,
        availableWidth: CGFloat,
        fontWeight: UIFont.Weight
    ) -> Bool {
        let lineSpacing = fontSize * 0.15 // Same as WallpaperRenderer
        let separatorHeight = fontSize * 0.45 // Same as WallpaperRenderer
        
        let font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        var totalHeight: CGFloat = 0
        
        for (index, note) in notes.enumerated() {
            let attributedString = NSAttributedString(string: note, attributes: attributes)
            let textSize = attributedString.boundingRect(
                with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            
            let noteHeight = textSize.height + (index > 0 ? separatorHeight : 0)
            totalHeight += noteHeight
            
            if totalHeight > availableHeight {
                return false
            }
        }
        
        return true
    }
    
    private func startPreOnboardingAnimation() {
        // Phase 1: First note slides in from left with bounce effect (0-0.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                firstNoteOpacity = 1.0
                firstNoteXOffset = 0
                firstNoteScale = 1.0
                firstNoteRotation = 0
            }
        }
        
        // Phase 2: Remaining notes slide in one by one from left to right (0.8-2.5s)
        // Each note appears with a spring animation, creating a cascading effect
        for i in 0..<3 {
            let delay = 0.8 + Double(i) * 0.4 // Staggered: 0.8s, 1.2s, 1.6s
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                    notesOpacity[i] = 1.0
                    notesXOffset[i] = 0
                    notesScale[i] = 1.0
                    notesRotation[i] = 0
                }
            }
        }
        
        // Phase 2.5: Slight upward float after all notes appear (2.5-3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                overallOffset = 50 // Float up slightly from starting position
            }
        }
        
        // Phase 3: Mockup appears and notes settle into position (3-5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Mockup fades in
            withAnimation(.easeOut(duration: 0.5)) {
                mockupOpacity = 1.0
            }
            
            // Notes settle into final position on mockup
            // overallOffset controls vertical position: positive = down, negative = up
            // Adjust this value to move notes up/down on the mockup lock screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    firstNoteOffset = 0
                    firstNoteScale = 1.0
                    firstNoteRotation = 0
                    firstNoteXOffset = 0
                    for i in 0..<3 {
                        notesOffset[i] = 0
                        notesScale[i] = 1.0
                        notesRotation[i] = 0
                        notesXOffset[i] = 0
                    }
                    overallOffset = 120 // Move notes down on mockup (increase to move down more, decrease to move up)
                    overallScale = 1.0
                }
            }
            
            // Scale up to 1.0 (removed tilt animation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.7)) {
                    mockupScale = 1.0
                }
            }
        }
        
        // Phase 4: Tagline and button appear after animation completes (after 3.5s)
        // Wait for mockup animation to complete, then show tagline and button
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            // Tagline fades in
            withAnimation(.easeOut(duration: 0.6)) {
                taglineOpacity = 1.0
            }
            
            // Button fades in slightly after tagline
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.6)) {
                    continueButtonOpacity = 1.0
                }
            }
        }
    }
    
    @ViewBuilder
    private func welcomeStep() -> some View {
        let isCompact = ScreenDimensions.isCompactDevice
        let iconSize: CGFloat = isCompact ? 85 : 110
        let titleFontSize: CGFloat = isCompact ? 26 : 34
        let sectionSpacing: CGFloat = isCompact ? 18 : 28
        let cardSpacing: CGFloat = isCompact ? 10 : 16
        
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: sectionSpacing) {
                VStack(spacing: isCompact ? 10 : 16) {
                    AppIconAnimationView(size: iconSize)
                        .scaleEffect(welcomeIconScale)
                        .opacity(welcomeIconOpacity)
                    
                    Text("Welcome to NoteWall")
                        .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .opacity(welcomeTitleOpacity)
                    
                    VStack(spacing: 8) {
                        Text("You forget things for one simple reason: you don't see them. NoteWall fixes that.")
                            .font(.system(size: isCompact ? 16 : 20))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                    }
                    .padding(.horizontal, isCompact ? 8 : 12)
                    .opacity(welcomeSubtitleOpacity)
                }
                
                VStack(spacing: cardSpacing) {
                    welcomeHighlightCard(
                        title: "Turn Every Pickup Into Focus",
                        subtitle: "You pick up your phone up to 498× per day. Now each one becomes a reminder of what matters.",
                        icon: "bolt.fill"
                    )
                    .opacity(welcomeCard1Opacity)
                    .scaleEffect(welcomeCard1Scale)
                    .offset(y: welcomeCard1Offset)
                    
                    welcomeHighlightCard(
                        title: "Keep Your Goals Always in Sight",
                        subtitle: "Your lock screen becomes a visual cue you can't ignore.",
                        icon: "target"
                    )
                    .opacity(welcomeCard2Opacity)
                    .scaleEffect(welcomeCard2Scale)
                    .offset(y: welcomeCard2Offset)
                    
                    welcomeHighlightCard(
                        title: "Beat Scrolling Before It Starts",
                        subtitle: "See your goals before TikTok, Instagram, or distractions.",
                        icon: "stop.fill"
                    )
                    .opacity(welcomeCard3Opacity)
                    .scaleEffect(welcomeCard3Scale)
                    .offset(y: welcomeCard3Offset)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, AdaptiveLayout.horizontalPadding)
            .padding(.vertical, isCompact ? 20 : 36)
            .padding(.bottom, AdaptiveLayout.bottomScrollPadding)
        }
        .scrollAlwaysBounceIfAvailable()
        .onAppear {
            // Reset animation states when view appears
            welcomeIconScale = 0.3
            welcomeIconOpacity = 0
            welcomeTitleOpacity = 0
            welcomeSubtitleOpacity = 0
            welcomeCard1Opacity = 0
            welcomeCard1Scale = 0.9
            welcomeCard1Offset = 20
            welcomeCard2Opacity = 0
            welcomeCard2Scale = 0.9
            welcomeCard2Offset = 20
            welcomeCard3Opacity = 0
            welcomeCard3Scale = 0.9
            welcomeCard3Offset = 20
            
            // Staggered animation sequence
            // 1. App icon bounces in with spring
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                welcomeIconScale = 1.0
                welcomeIconOpacity = 1.0
            }
            
            // 2. Title fades in
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                welcomeTitleOpacity = 1.0
            }
            
            // 3. Subtitle fades in
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                welcomeSubtitleOpacity = 1.0
            }
            
            // 4. First card slides up and fades in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.9)) {
                welcomeCard1Opacity = 1.0
                welcomeCard1Scale = 1.0
                welcomeCard1Offset = 0
            }
            
            // 5. Second card slides up and fades in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(1.1)) {
                welcomeCard2Opacity = 1.0
                welcomeCard2Scale = 1.0
                welcomeCard2Offset = 0
            }
            
            // 6. Third card slides up and fades in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(1.3)) {
                welcomeCard3Opacity = 1.0
                welcomeCard3Scale = 1.0
                welcomeCard3Offset = 0
            }
            
            // Light haptic feedback when cards appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred(intensity: 0.5)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred(intensity: 0.5)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred(intensity: 0.5)
            }
        }
        .sheet(isPresented: $showShortcutsCheckAlert) {
            requirementsCheckView
                .onAppear {
                    AnalyticsService.shared.trackScreenView(screenName: "shortcuts_check_alert")
                }
        }
    }
    
    private func welcomeHighlightCard(title: String, subtitle: String, icon: String) -> some View {
        let isCompact = ScreenDimensions.isCompactDevice
        
        return HStack(alignment: .top, spacing: isCompact ? 12 : 16) {
            // Icon with circular background and subtle glow
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.appAccent.opacity(0.15), Color.appAccent.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isCompact ? 44 : 52, height: isCompact ? 44 : 52)
                
                Image(systemName: icon)
                    .font(.system(size: isCompact ? 20 : 24, weight: .semibold))
                    .foregroundColor(.appAccent)
            }
            
            VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
                Text(title)
                    .font(.system(size: isCompact ? 16 : 20, weight: .semibold, design: .rounded))
                
                Text(subtitle)
                    .font(.system(size: isCompact ? 14 : 17))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(isCompact ? 16 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                // Gradient background
                RoundedRectangle(cornerRadius: isCompact ? 14 : 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.secondarySystemBackground),
                                Color(.secondarySystemBackground).opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Subtle accent border
                RoundedRectangle(cornerRadius: isCompact ? 14 : 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.appAccent.opacity(0.1),
                                Color.appAccent.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    @State private var showTextVersion = false
    @State private var showInstallSheet = false
    @State private var userWentToSettings = false
    
    // Welcome step animation states
    @State private var welcomeIconScale: CGFloat = 0.3
    @State private var welcomeIconOpacity: Double = 0
    @State private var welcomeTitleOpacity: Double = 0
    @State private var welcomeSubtitleOpacity: Double = 0
    @State private var welcomeCard1Opacity: Double = 0
    @State private var welcomeCard1Scale: CGFloat = 0.9
    @State private var welcomeCard1Offset: CGFloat = 20
    @State private var welcomeCard2Opacity: Double = 0
    @State private var welcomeCard2Scale: CGFloat = 0.9
    @State private var welcomeCard2Offset: CGFloat = 20
    @State private var welcomeCard3Opacity: Double = 0
    @State private var welcomeCard3Scale: CGFloat = 0.9
    @State private var welcomeCard3Offset: CGFloat = 20

    private func stepRowImproved(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.appAccent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Step \(number)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.appAccent)
                    .textCase(.uppercase)
                
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var requirementsCheckView: some View {
        ZStack {
            // Brand identity dark gradient background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    shortcutsSection
                    
                    if hasCompletedShortcutsCheck {
                        safariSection
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    if hasCompletedShortcutsCheck && hasCompletedSafariCheck {
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            
                            // Close the requirements sheet and show install shortcut sheet
                            isTransitioningBetweenPopups = true
                            showShortcutsCheckAlert = false
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                showInstallSheet = true
                                isTransitioningBetweenPopups = false
                            }
                        }) {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.appAccent)
                                )
                                .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        .padding(.top, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 24)
            }
        }
    }
    
    private var shortcutsSection: some View {
        VStack(spacing: 24) {
            // Shortcuts App Logo
            if let shortcutsImage = UIImage(named: "shortcuts-app-logo") {
                Image(uiImage: shortcutsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 15, x: 0, y: 8)
            } else {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.appAccent)
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 15, x: 0, y: 8)
            }
            
            // Title Section
            VStack(spacing: 8) {
                Text("Shortcuts Required")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("NoteWall uses Apple's Shortcuts app to automatically update your lock screen.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            if !hasCompletedShortcutsCheck {
                // Info Card
                BrandCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.appAccent)
                            Text("Why Shortcuts?")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Text("It's a free Apple app that allows NoteWall to work in the background.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        debugLog("✅ User confirmed Shortcuts is installed")
                        withAnimation(.spring()) {
                            hasCompletedShortcutsCheck = true
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("I Have Shortcuts")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.appAccent))
                    }
                    
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        if let url = URL(string: "https://apps.apple.com/app/shortcuts/id915249334") {
                            UIApplication.shared.open(url)
                            debugLog("🌐 Opening App Store to install Shortcuts")
                            wentToAppStoreForShortcuts = true
                            withAnimation(.spring()) {
                                hasCompletedShortcutsCheck = true
                            }
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download Shortcuts")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        )
                    }
                }
            } else {
                // Completed state
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Shortcuts Ready")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(Capsule().fill(Color.green.opacity(0.15)))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
    
    private var safariSection: some View {
        VStack(spacing: 24) {
            // Safari Logo
            if let safariImage = UIImage(named: "safari-logo") {
                Image(uiImage: safariImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 15, x: 0, y: 8)
            } else {
                Image(systemName: "safari")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.appAccent)
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 15, x: 0, y: 8)
            }
            
            // Title Section
            VStack(spacing: 8) {
                Text("Safari Required")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("The shortcut requires Safari to work properly.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            if !hasCompletedSafariCheck {
                // Info Card
                BrandCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.appAccent)
                            Text("Why Safari?")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Text("Safari is used to securely process the wallpaper updates.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        debugLog("✅ User confirmed Safari is installed")
                        withAnimation(.spring()) {
                            hasCompletedSafariCheck = true
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("I Have Safari")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.appAccent))
                    }
                    
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        if let url = URL(string: "https://apps.apple.com/app/id1146562112") {
                            UIApplication.shared.open(url)
                            debugLog("🌐 Opening App Store to install Safari")
                            hasCompletedSafariCheck = true
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download Safari")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        )
                    }
                }
            } else {
                // Completed state
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Safari Ready")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(Capsule().fill(Color.green.opacity(0.15)))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
    
    @State private var showTroubleshootingTextVersion = false

    private var troubleshootingModalView: some View {
        ZStack {
            // Brand identity dark gradient background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .onAppear {
                // Set up video player when modal appears - force setup
                debugLog("📱 Troubleshooting modal appeared - setting up video")
                setupStuckVideoPlayerIfNeeded()
                
                // If video player is still nil after a brief delay, try again
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self.stuckGuideVideoPlayer == nil {
                        debugLog("⚠️ Video player still nil after 0.5s, retrying setup...")
                        self.setupStuckVideoPlayerIfNeeded()
                    } else {
                        // Force ensure playing after delay for returning visits
                        self.ensureStuckVideoPlaying()
                    }
                }
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Text Version / Back Button - Brand Identity Design (top left like step 2)
                    HStack {
                        if showTroubleshootingTextVersion {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    showTroubleshootingTextVersion = false
                                }
                                resumeStuckVideoIfNeeded()
                                // Ensure progress tracking restarts after a small delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    self.ensureStuckVideoPlaying()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.left")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Back to Video")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.appAccent)
                                )
                                .shadow(color: Color.appAccent.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .padding(.leading, 0) // Text version page: minimal padding
                        } else {
                            HStack(spacing: 12) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        showTroubleshootingTextVersion = true
                                    }
                                    pauseStuckVideo()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "text.alignleft")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Text version")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.appAccent)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .frame(height: 38) // Fixed height to match help button
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.appAccent.opacity(0.15))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                
                                // Help button next to Text version - same height as Text version
                                Button(action: {
                                    // Medium haptic feedback
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    pauseStuckVideo()
                                    showHelpSheet = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "headphones")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.appAccent)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .frame(height: 38) // Match Text version button height exactly
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.appAccent.opacity(0.15))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.leading, 48) // Video page: more padding
                        }
                        Spacer()
                        
                        // X button with grey border (top right) - larger like paywall
                        Button(action: {
                            // Light haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            stopStuckVideoPlayback()
                            showTroubleshooting = false
                            showTroubleshootingTextVersion = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                        }
                        .padding(.trailing, showTroubleshootingTextVersion ? 0 : 48) // 8 for text version, 40 for video
                    }
                    .padding(.top, 20)
                    
                    if !showTroubleshootingTextVersion {
                        // Video Version - Brand Identity Design
                        VStack(spacing: 24) {
                            // Title Section (icon removed)
                            VStack(spacing: 12) {
                                Text("Quick Fix for Apple Presets")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text("This happens when you're using Apple's built-in wallpapers. No worries, we will fix this.")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            
                            // Video outside of card
                            VStack(spacing: 16) {
                                Text("Watch this short guide to fix the issue:")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                ZStack {
                                    // Video player - always try to show video
                                    if let player = stuckGuideVideoPlayer {
                                        AutoPlayingLoopingVideoPlayer(player: player)
                                            .aspectRatio(9/16, contentMode: .fit)
                                            .frame(width: ScreenDimensions.width * 0.7)
                                            .cornerRadius(16)
                                            .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
                                    } else {
                                        // Loading state while video is being set up
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.gray.opacity(0.2))
                                            .aspectRatio(9/16, contentMode: .fit)
                                            .frame(width: ScreenDimensions.width * 0.7)
                                            .overlay(
                                                VStack(spacing: 8) {
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    Text("Loading video...")
                                                        .font(.caption)
                                                        .foregroundColor(.white.opacity(0.6))
                                                }
                                            )
                                    }
                                    
                                    // Overlay controls styled the same as the intro video
                                    let videoWidth = ScreenDimensions.width * 0.7
                                    let leftEdge = (ScreenDimensions.width - videoWidth) / 2
                                    let rightEdge = leftEdge + videoWidth
                                    let leftSpace = leftEdge
                                    let rightSpace = ScreenDimensions.width - rightEdge
                                    
                                    VStack {
                                        Spacer()
                                        
                                        HStack(spacing: 0) {
                                            // Backward button
                                            HStack {
                                                Spacer()
                                                VStack {
                                                    Spacer()
                                                    Button(action: {
                                                        seekStuckVideo(by: -3.0)
                                                    }) {
                                                        Image("skipBackward3s")
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(width: 44, height: 44)
                                                            .opacity(stuckGuideVideoPlayer == nil ? 0.5 : 1)
                                                    }
                                                    .padding(.trailing, 8)
                                                    .disabled(stuckGuideVideoPlayer == nil)
                                                    Spacer()
                                                }
                                            }
                                            .frame(width: leftSpace)
                                            
                                            Spacer()
                                                .frame(width: videoWidth)
                                            
                                            // Forward button
                                            HStack {
                                                VStack {
                                                    Spacer()
                                                    Button(action: {
                                                        seekStuckVideo(by: 3.0)
                                                    }) {
                                                        Image("skipForward3s")
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(width: 44, height: 44)
                                                            .opacity(stuckGuideVideoPlayer == nil ? 0.5 : 1)
                                                    }
                                                    .padding(.leading, 8)
                                                    .disabled(stuckGuideVideoPlayer == nil)
                                                    Spacer()
                                                }
                                                Spacer()
                                            }
                                            .frame(width: rightSpace)
                                        }
                                        .frame(width: ScreenDimensions.width)
                                        
                                        Spacer()
                                    }
                                    .frame(width: ScreenDimensions.width)
                                    
                                    // Progress bar
                                    VStack {
                                        HStack {
                                            Spacer()
                                                .frame(width: (ScreenDimensions.width - ScreenDimensions.width * 0.7) / 2)
                                            
                                            GeometryReader { geometry in
                                                let availableWidth = geometry.size.width - 22
                                                let progressWidth = availableWidth * CGFloat(stuckVideoProgress)
                                                
                                                ZStack(alignment: .leading) {
                                                    Rectangle()
                                                        .fill(Color.white.opacity(0.2))
                                                        .frame(height: 3)
                                                    
                                                    Rectangle()
                                                        .fill(Color.appAccent)
                                                        .frame(width: progressWidth, height: 3)
                                                }
                                                .padding(.leading, 12)
                                                .padding(.trailing, 10)
                                            }
                                            .frame(width: ScreenDimensions.width * 0.7, height: 3)
                                            
                                            Spacer()
                                                .frame(width: (ScreenDimensions.width - ScreenDimensions.width * 0.7) / 2)
                                        }
                                        .padding(.top, 0)
                                        
                                        Spacer()
                                    }
                                    
                                    // Mute button (top-left) and Pause/Play button (top-right)
                                    VStack {
                                        HStack {
                                            Button(action: {
                                                toggleStuckVideoMute()
                                            }) {
                                                Image(systemName: isStuckVideoMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .frame(width: 36, height: 36)
                                                    .background(
                                                        Circle()
                                                            .fill(Color.black.opacity(0.6))
                                                            .overlay(
                                                                Circle()
                                                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                                            )
                                                    )
                                                    .opacity(stuckGuideVideoPlayer == nil ? 0.5 : 1)
                                            }
                                            .disabled(stuckGuideVideoPlayer == nil)
                                            .padding(.leading, ScreenDimensions.width * 0.15 + 12)
                                            .padding(.top, 12)
                                            Spacer()
                                            
                                            // Pause/Play button (top-right corner of video)
                                            Button(action: {
                                                if let player = stuckGuideVideoPlayer {
                                                    if player.rate > 0 {
                                                        pauseStuckVideo()
                                                    } else {
                                                        resumeStuckVideoIfNeeded(forcePlay: true)
                                                    }
                                                }
                                            }) {
                                                Image(systemName: isStuckVideoPaused ? "play.fill" : "pause.fill")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .frame(width: 36, height: 36)
                                                    .background(
                                                        Circle()
                                                            .fill(Color.black.opacity(0.6))
                                                            .overlay(
                                                                Circle()
                                                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                                            )
                                                    )
                                                    .opacity(stuckGuideVideoPlayer == nil ? 0.5 : 1)
                                            }
                                            .disabled(stuckGuideVideoPlayer == nil)
                                            .padding(.trailing, ScreenDimensions.width * 0.15 + 12)
                                            .padding(.top, 12)
                                        }
                                        Spacer()
                                    }
                                }
                                .onAppear {
                                    setupStuckVideoPlayerIfNeeded()
                                }
                            }
                            .padding(.horizontal, 24)
                            
                            // Instruction wallpaper image
                            VStack(spacing: 12) {
                                Image("InstructionWallpaper")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: ScreenDimensions.width * 0.5)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                                
                                Text("This red image will be saved to your Photos. Set it as your wallpaper to make the shortcut work!")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            
                            // Primary CTA Button - Brand Style
            Button(action: {
                // Medium haptic for important action
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                stopStuckVideoPlayback()
                
                // Save instruction wallpaper to Photos first, then open Photos
                saveInstructionWallpaperToPhotos()
                
                // Small delay to ensure image is saved before opening Photos
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    openWallpaperSettings()
                }
            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 18, weight: .semibold))
                            Text("Open Photos")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.appAccent)
                                            .blur(radius: 12)
                                            .opacity(0.4)
                                            .offset(y: 4)
                                        
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.appAccent)
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        .padding(.horizontal, 48)
                        
                            // Secondary Button
                        Button(action: {
                        stopStuckVideoPlayback()
                            showTroubleshooting = false
                        }) {
                            Text("I'll Do This Later")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.top, 8)
                        }
                    } else {
                        // Text Version - Brand Identity Design
                        troubleshootingTextGuide
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onDisappear {
            stopStuckVideoPlayback()
        }
        .onChange(of: showHelpSheet) { _, isShowing in
            if isShowing {
                pauseStuckVideo()
            }
        }
    }
    
    private var troubleshootingTextGuide: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 32) {
                // Hero Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent.opacity(0.25), Color.appAccent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
            Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(.appAccent)
                        .shadow(color: Color.appAccent.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .padding(.top, 20)
                
                // Title Section
                VStack(spacing: 12) {
            Text("Why Couldn't You Select a Wallpaper?")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            
                // Content Cards - Brand Identity Design
                VStack(spacing: 20) {
                    // Problem Card
                    BrandCard {
            VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.appAccent)
                Text("The Problem: Apple's Limitation")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                
                Text("The reason you couldn't select any wallpaper is simple: You're currently using one of Apple's built-in wallpaper presets.")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                
                Text("Apple designed the Shortcuts app to only work with wallpapers that use photos from your library. It cannot work with Apple's built-in preset wallpapers - like gradients, astronomy images, emoji designs, or any of their default wallpapers.")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            // Highlight box
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.appAccent)
                                    .padding(.top, 2)
                
                Text("This isn't a NoteWall bug. It's an Apple limitation that affects all shortcuts that try to modify wallpapers.")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.appAccent)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.appAccent.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    
                    // Red Wallpaper Card
                    BrandCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.appAccent)
                                Text("We've Saved a Special Image for You")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            // Show the instruction wallpaper
                            Image("InstructionWallpaper")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                            
                            Text("This bright red image will be saved to your Photos once you click the continue button below. It says \"SET THIS AS YOUR WALLPAPER\" - that's exactly what you need to do!")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            Text("Don't worry - this is temporary. Once you've set it up and the shortcut works, you can change it to your own custom image wallpaper with your notes on it.")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.appAccent)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    // Solution Card
                    BrandCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.appAccent)
                Text("The Easy Fix")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                
                Text("We need to set up a photo-based wallpaper so the shortcut can work. The red image is saved to your Photos - let's set it as your wallpaper now.")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                
                Text("This takes about 2 minutes. Here's exactly what to do:")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.appAccent)
                
                VStack(alignment: .leading, spacing: 12) {
                    troubleshootingStep(number: 1, title: "Open Photos", description: "Tap the \"Open Photos\" button below. This will open your Photos app to the Recents album where this red birght image should be.")
                    troubleshootingStep(number: 2, title: "Find the RED Image", description: "Look in the Recents album - the red image should be there. If you don't see it in Recents, check your \"All Photos\" and scroll to the most recent images.")
                    troubleshootingStep(number: 3, title: "Long-Press the Image", description: "Long-press (press and hold) on it.")
                    troubleshootingStep(number: 4, title: "Tap SHARE", description: "Tap SHARE from the menu that appears.")
                    troubleshootingStep(number: 4, title: "Use as Wallpaper", description: "Scroll down a bit and then tap the \"Use as Wallpaper\" from the menu that appears.")
                    troubleshootingStep(number: 5, title: "Set as Lock Screen", description: "You'll see a preview. Tap add in top right corner and then Set as wallppaer pair.")
                    troubleshootingStep(number: 6, title: "Return to NoteWall App", description: "Swipe up to go back to NoteWall app.")
                            }
                        }
                    }
                    
                    // What Happens Next Card
                    BrandCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.appAccent)
                Text("What Happens Next?")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                
                Text("Once you've set your NoteWall image as your wallpaper, come back to the app. We'll go back to the shortcut installation step. This time, when you tap on \"Wallpaper\" in the Shortcuts app, you'll see your NoteWall wallpaper in the list and you'll be able to tap on it!")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                
                Text("The shortcut will then work perfectly - every time you add, edit, or delete notes, your wallpaper will update automatically.")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    // Call to Action Card
                    BrandCard {
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 24))
                                    .foregroundColor(.appAccent)
                                Text("Ready? Let's Do This!")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
            }
            .padding(.horizontal, 24)
            
                // Primary CTA Button - Brand Style
            Button(action: {
                // Medium haptic for important action
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                // Save instruction wallpaper to Photos first, then open Photos
                saveInstructionWallpaperToPhotos()
                
                // Small delay to ensure image is saved before opening Photos
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    openWallpaperSettings()
                }
            }) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 18, weight: .semibold))
                Text("Open Photos")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.appAccent)
                                .blur(radius: 12)
                                .opacity(0.4)
                                .offset(y: 4)
                            
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.appAccent)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 24)
            
                // Secondary Button
            Button(action: {
                showTroubleshooting = false
                showTroubleshootingTextVersion = false
            }) {
                Text("Got It - I'll Set This Up Later")
                    .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.5))
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
            }
        }
    }
    
    private func troubleshootingStep(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.appAccent)
                    .frame(width: 28, height: 28)
                
                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    @ViewBuilder
    private func installShortcutStep() -> some View {
        let isCompact = ScreenDimensions.isCompactDevice
        let titleFontSize: CGFloat = isCompact ? 26 : 32
        let subtitleFontSize: CGFloat = isCompact ? 17 : 20
        let cardTitleFontSize: CGFloat = isCompact ? 16 : 18
        let cardBodyFontSize: CGFloat = isCompact ? 14 : 16
        let cardIconSize: CGFloat = isCompact ? 18 : 20
        let buttonIconSize: CGFloat = isCompact ? 18 : 20
        let buttonFontSize: CGFloat = isCompact ? 16 : 18
        let sectionSpacing: CGFloat = isCompact ? 20 : 32
        let buttonSpacing: CGFloat = isCompact ? 12 : 16
        let horizontalPadding: CGFloat = isCompact ? 16 : 24
        let heroIconSize: CGFloat = isCompact ? 90 : 110
        let checkIconSize: CGFloat = isCompact ? 36 : 44
        let ringSize: CGFloat = isCompact ? 100 : 130
        let heroHeight: CGFloat = isCompact ? 130 : 160
        
        ZStack {
            // Black background for step 3
            Color.black
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: isCompact ? 16 : 24) {
                    if userWentToSettings {
                        // "Ready to Try Again?" screen after returning from Settings - Brand Identity Design
                        ZStack {
                            // Black background
                            Color.black
                                .ignoresSafeArea()
                            
                            VStack(spacing: sectionSpacing) {
                            // Hero Icon
                            ZStack {
                                // Animated rings
                                ForEach(0..<3, id: \.self) { i in
                                    Circle()
                                        .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                                        .frame(width: ringSize + CGFloat(i) * (isCompact ? 22 : 30), height: ringSize + CGFloat(i) * (isCompact ? 22 : 30))
                                        .scaleEffect(1.1)
                                        .opacity(0.4)
                                }
                                
                                // Main icon
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.appAccent.opacity(0.25), Color.appAccent.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: heroIconSize, height: heroIconSize)
                                    
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: checkIconSize, weight: .medium))
                                        .foregroundColor(.appAccent)
                                        .shadow(color: Color.appAccent.opacity(0.5), radius: 10, x: 0, y: 5)
                                }
                            }
                            .frame(height: heroHeight)
                            .padding(.top, isCompact ? 12 : 20)
                            
                            // Title Section
                            VStack(spacing: isCompact ? 8 : 12) {
                                Text("Ready to Try Again?")
                                    .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, horizontalPadding)
                            
                            // Success Card
                            BrandCard {
                                VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: cardIconSize))
                                            .foregroundColor(.appAccent)
                                        Text("All Set!")
                                            .font(.system(size: cardTitleFontSize, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("Great job! Your photo-based wallpaper is ready. The shortcut installation will work perfectly this time.")
                                        .font(.system(size: cardBodyFontSize))
                                        .foregroundColor(.white.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                    
                                    Text("This next attempt should only take 30 seconds.")
                                        .font(.system(size: cardBodyFontSize, weight: .semibold))
                                        .foregroundColor(.appAccent)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                            
                            // Action Button
                            Button(action: {
                                // Track action
                                OnboardingAnalyticsTracker.shared.trackAction(.retrySetup, on: .installShortcut, additionalParams: ["subtype": "install_shortcut_retry"])
                                
                                // Medium haptic for important action
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                
                                // Stop any active PiP before opening install sheet again
                                pipVideoPlayerManager.stopPictureInPicture()
                                pipVideoPlayerManager.stop()
                                shouldStartPiP = false
                                
                                // Don't reset userWentToSettings yet - keep "Ready to Try Again?" visible
                                // It will be reset when user returns from Shortcuts app
                                showInstallSheet = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: buttonIconSize, weight: .semibold))
                                    Text("Install Shortcut Again")
                                        .font(.system(size: buttonFontSize, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isCompact ? 14 : 18)
                                .background(
                                    RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                        .fill(Color.appAccent)
                                )
                                .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                            }
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, isCompact ? 24 : 40)
                            }
                        }
                    } else {
                        // Standard "Installation Check" screen - Black background, no icon
                        VStack(spacing: sectionSpacing) {
                            // Title Section only (no icon)
                            VStack(spacing: isCompact ? 8 : 12) {
                                Text("Installation Check")
                                    .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text("Were you able to select a wallpaper?")
                                    .font(.system(size: subtitleFontSize, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, isCompact ? 36 : 60)
                            
                            // Quick Info Card
                            BrandCard {
                                VStack(alignment: .leading, spacing: isCompact ? 10 : 12) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "info.circle.fill")
                                            .font(.system(size: cardIconSize))
                                            .foregroundColor(.appAccent)
                                        Text("Quick Check")
                                            .font(.system(size: cardTitleFontSize, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("Did you see your wallpapers in the list and could tap one?")
                                        .font(.system(size: cardBodyFontSize))
                                        .foregroundColor(.white.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                            
                            // Action Buttons
                            VStack(spacing: buttonSpacing) {
                                Button(action: {
                                    // Track action
                                    OnboardingAnalyticsTracker.shared.trackAction(.verifyShortcut, on: .installShortcut, additionalParams: ["subtype": "install_success_confirmed", "verification": "success"])
                                    
                                    // Medium haptic for positive confirmation
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    
                                    // Just advance to next step - don't run shortcut yet
                                    // Shortcut will run in step 5 (chooseWallpapers) after user selects wallpapers
                                    advanceStep()
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: isCompact ? 20 : 24, weight: .semibold))
                                        Text("Yes, It Worked!")
                                            .font(.system(size: buttonFontSize, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, isCompact ? 14 : 18)
                                    .background(
                                        RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                            .fill(Color.appAccent)
                                    )
                                    .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                                }
                                
                        Button(action: {
                            // Track action
                            OnboardingAnalyticsTracker.shared.trackAction(.verifyShortcut, on: .installShortcut, additionalParams: ["subtype": "install_stuck_troubleshoot", "verification": "stuck"])
                            
                            // Medium haptic for important troubleshooting action
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            
                            showTroubleshooting = true
                        }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "wrench.and.screwdriver.fill")
                                            .font(.system(size: buttonIconSize, weight: .semibold))
                                        Text("No, Got Stuck")
                                            .font(.system(size: buttonFontSize, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, isCompact ? 14 : 18)
                                    .background(
                                        RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                            .fill(Color.white.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1.5)
                                            )
                                    )
                                }
                                
                                // Subtle CTA to replay video
                                Button(action: {
                                    // Track action
                                    OnboardingAnalyticsTracker.shared.trackAction(.watchVideo, on: .installShortcut, additionalParams: ["subtype": "install_replay_video"])
                                    
                                    // Light haptic for subtle action
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    
                                    // Replay the video - open Shortcuts app with PiP video
                                    installShortcut()
                                }) {
                                    VStack(spacing: 2) {
                                        Text("Accidentally clicked or cancelled?")
                                            .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                                        if #available(iOS 15.0, *) {
                                            Text(createUnderlinedText("Tap here to replay the video"))
                                                .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                                        } else {
                                            Text("Tap here to replay the video")
                                                .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                                        }
                                    }
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .padding(.top, isCompact ? 4 : 8)
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, isCompact ? 24 : 40)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, isCompact ? 20 : 36)
                .padding(.bottom, AdaptiveLayout.bottomScrollPadding)
            }
        }
        .scrollAlwaysBounceIfAvailable()
    }
    
    private func installShortcutInfoCard(title: String, subtitle: String, icon: String, highlightedText: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.appAccent)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                
                if let highlightedText = highlightedText, subtitle.contains(highlightedText) {
                    // Create attributed text with highlighted portion
                    let parts = subtitle.components(separatedBy: highlightedText)
                    if parts.count == 2 {
                        (Text(parts[0])
                            .foregroundColor(.secondary) +
                         Text(highlightedText)
                            .foregroundColor(.appAccent)
                            .fontWeight(.bold) +
                         Text(parts[1])
                            .foregroundColor(.secondary))
                        .font(.body)
                    } else {
                        Text(subtitle)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(subtitle)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func addNotesStep() -> some View {
        let isCompact = ScreenDimensions.isCompactDevice
        let titleFontSize: CGFloat = isCompact ? 26 : 34
        let subtitleFontSize: CGFloat = isCompact ? 16 : 20
        let sectionSpacing: CGFloat = isCompact ? 16 : 24
        let noteSpacing: CGFloat = isCompact ? 12 : 16
        let notePadding: CGFloat = isCompact ? 12 : 16
        let emptyIconSize: CGFloat = isCompact ? 36 : 48
        let horizontalPadding: CGFloat = isCompact ? 16 : 24
        let topPadding: CGFloat = isCompact ? 20 : 32
        
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    Text("Add Your First Notes")
                        .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                    
                    Text("These notes will appear on your lock screen wallpaper")
                        .font(.system(size: subtitleFontSize))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: noteSpacing) {
                        // Display existing notes
                        ForEach(onboardingNotes) { note in
                            HStack(spacing: 12) {
                                Text("\(noteIndex(for: note) + 1).")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, alignment: .leading)
                                
                                Text(note.text)
                                    .font(.system(.body))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Button(action: {
                                    withAnimation {
                                        removeNote(note)
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 20))
                                }
                            }
                            .padding(notePadding)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .id(note.id)
                        }
                        
                        // Input field for new note
                        HStack(spacing: 12) {
                            TextField("Type a note...", text: $currentNoteText)
                                .font(.system(.body))
                                .focused($isNoteFieldFocused)
                                .onSubmit {
                                    addCurrentNote(scrollProxy: proxy)
                                }
                            
                            Button(action: {
                                // Light impact haptic for adding note button
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                addCurrentNote(scrollProxy: proxy)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(currentNoteText.isEmpty ? .gray : .appAccent)
                            }
                            .disabled(currentNoteText.isEmpty)
                        }
                        .padding(notePadding)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .id("inputField")
                        
                        if onboardingNotes.isEmpty {
                            VStack(spacing: isCompact ? 8 : 12) {
                                Image(systemName: "note.text")
                                    .font(.system(size: emptyIconSize))
                                    .foregroundColor(.secondary.opacity(0.5))
                                
                                Text("Add at least one note to continue")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, isCompact ? 20 : 32)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
                .padding(.bottom, AdaptiveLayout.bottomScrollPadding)
            }
            .scrollAlwaysBounceIfAvailable()
            .onTapGesture {
                // Dismiss keyboard when tapping outside
                isNoteFieldFocused = false
            }
            .onAppear {
                // Focus the text field when the view appears - reduced delay for faster feel
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isNoteFieldFocused = true
                }
            }
        }
    }
    
    private func addCurrentNote(scrollProxy: ScrollViewProxy) {
        let trimmed = currentNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Light impact haptic for adding note during onboarding
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        withAnimation {
            let newNote = Note(text: trimmed, isCompleted: false)
            onboardingNotes.append(newNote)
            currentNoteText = ""
            isNoteFieldFocused = true
            
            // Scroll to the newly added note with center anchor
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrollProxy.scrollTo(newNote.id, anchor: .center)
                }
            }
        }
    }
    
    private func removeNote(_ note: Note) {
        if let index = onboardingNotes.firstIndex(where: { $0.id == note.id }) {
            // Light impact haptic for removing note during onboarding
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            onboardingNotes.remove(at: index)
        }
    }
    
    private func noteIndex(for note: Note) -> Int {
        return onboardingNotes.firstIndex(where: { $0.id ==
            note.id }) ?? 0
    }

    @State private var hasConfirmedPermissions: Bool = false // Simple checkbox state
    
    // Permission detection via URL callback only
    @State private var permissionGrantedViaURL = false
    @State private var permissionPollTimer: Timer?

    private func allowPermissionsStep() -> some View {
        // Use adaptive layout values based on device size
        let isCompact = ScreenDimensions.isCompactDevice
        let horizontalPadding = AdaptiveLayout.horizontalPadding
        let titleFontSize: CGFloat = isCompact ? 24 : 34
        let hintFontSize: CGFloat = isCompact ? 16 : 20
        let instructionFontSize: CGFloat = isCompact ? 15 : 18
        let arrowSize: CGFloat = isCompact ? 16 : 20
        let arrowSpacing: CGFloat = isCompact ? 12 : 20
        let topPadding: CGFloat = isCompact ? 12 : 24
        let sectionSpacing: CGFloat = isCompact ? 8 : 16
        
        return GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Title - adaptive font size
                    Text("Allow ALL Permissions")
                        .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, topPadding)
                        .padding(.horizontal, horizontalPadding)
                    
                    // Arrows pointing up - compact on small devices
                    HStack(spacing: arrowSpacing) {
                        ForEach(0..<3, id: \.self) { _ in
                            VStack(spacing: isCompact ? 2 : 4) {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: arrowSize, weight: .bold))
                                Image(systemName: "chevron.up")
                                    .font(.system(size: arrowSize, weight: .bold))
                                    .opacity(0.5)
                            }
                            .foregroundColor(.appAccent)
                        }
                    }
                    .padding(.top, sectionSpacing)
                    .padding(.bottom, isCompact ? 4 : 8)
                    
                    // Hint text - adaptive font size
                    Text("Permission popups appear here")
                        .font(.system(size: hintFontSize, weight: .semibold))
                        .foregroundColor(.appAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.bottom, isCompact ? 4 : 8)
                    
                    // Title below hint text
                    Text("click ALLOW for all")
                        .font(.system(size: instructionFontSize, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.bottom, sectionSpacing)
                    
                    // Video at adaptive size - CRITICAL: Scale down significantly on compact devices
                    if let player = notificationsVideoPlayer {
                        let availableWidth = proxy.size.width - (horizontalPadding * 2)
                        
                        // Scale down the mockup to prevent interference with subtitle and CTA
                        let mockupScale: CGFloat = 0.85
                        let scaledWidth = availableWidth * mockupScale
                        
                        // CRITICAL FIX: Use much smaller video height on compact devices
                        // to ensure confirmation button is visible without scrolling
                        let maxVideoHeight = AdaptiveLayout.maxVideoHeight
                        let aspectBasedHeight = scaledWidth * 0.6
                        let containerHeight = min(aspectBasedHeight, maxVideoHeight)
                        let topCrop: CGFloat = isCompact ? 5 : 10
                        
                        CroppedVideoPlayerView(
                            player: player,
                            topCrop: topCrop
                        )
                        .frame(width: scaledWidth, height: containerHeight)
                        .clipped()
                        .contentShape(Rectangle())
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, isCompact ? 8 : 20)
                        .padding(.bottom, isCompact ? 6 : 12)
                        .onAppear {
                            // Bulletproof video playback when view appears
                            func startPlayback(attempt: Int = 1) {
                                guard attempt <= 10 else {
                                    debugLog("❌ VideoPlayer max retry attempts reached")
                                    return
                                }
                                
                                // Check if player item is ready
                                if let item = player.currentItem {
                                    if item.status != .readyToPlay {
                                        debugLog("⚠️ VideoPlayer item not ready (status: \(item.status.rawValue), attempt \(attempt)), retrying in 0.2s")
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            startPlayback(attempt: attempt + 1)
                                        }
                                        return
                                    }
                                }
                                
                                // Ensure looper is active for continuous looping
                                if let looper = notificationsVideoLooper {
                                    if looper.status == .failed, let item = player.currentItem {
                                        let newLooper = AVPlayerLooper(player: player, templateItem: item)
                                        notificationsVideoLooper = newLooper
                                        debugLog("🔄 Recreated video looper in video view onAppear")
                                    }
                                } else if let item = player.currentItem {
                                    let newLooper = AVPlayerLooper(player: player, templateItem: item)
                                    notificationsVideoLooper = newLooper
                                    debugLog("🔄 Created video looper in video view onAppear")
                                }
                                
                                // Configure audio session
                                do {
                                    try AVAudioSession.sharedInstance().setActive(false)
                                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                                    try AVAudioSession.sharedInstance().setActive(true)
                                } catch {
                                    debugLog("⚠️ Failed to configure audio session in onAppear: \(error)")
                                }
                                
                                // Start playback
                                player.seek(to: .zero)
                                player.play()
                                debugLog("▶️ VideoPlayer onAppear: Started playback (attempt \(attempt), rate: \(player.rate))")
                                
                                // Verify it's playing, retry if needed
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    if player.rate == 0 {
                                        debugLog("⚠️ VideoPlayer not playing, retrying...")
                                        startPlayback(attempt: attempt + 1)
                                    } else {
                                        debugLog("✅ VideoPlayer playing and looping")
                                    }
                                }
                            }
                            
                            DispatchQueue.main.async {
                                startPlayback()
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if player.rate == 0 {
                                    startPlayback(attempt: 5)
                                }
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                if player.rate == 0 {
                                    debugLog("⚠️ VideoPlayer still not playing after 1.5s, final retry")
                                    startPlayback(attempt: 8)
                                }
                            }
                        }
                        .onDisappear {
                            debugLog("⚠️ VideoPlayer disappeared")
                        }
                    } else {
                        // Placeholder while loading - smaller on compact
                        VStack(spacing: isCompact ? 8 : 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isCompact ? 20 : 40)
                        .padding(.horizontal, horizontalPadding)
                        .onAppear {
                            prepareNotificationsVideoPlayerIfNeeded()
                        }
                    }
                    
                    // Text below video - adaptive font
                    Text("(this is how it should look)")
                        .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.top, isCompact ? 6 : 12)
                    
                    // Status text showing success
                    if permissionGrantedViaURL {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: isCompact ? 16 : 18))
                                .foregroundColor(.green)
                            Text("Permissions granted!")
                                .font(.system(size: isCompact ? 15 : 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.top, isCompact ? 12 : 16)
                    }
                    
                    // CRITICAL: Add generous bottom padding to ensure visibility above sticky Continue button
                    Color.clear
                        .frame(height: AdaptiveLayout.bottomScrollPadding)
                }
            }
        }
        .onAppear {
            debugLog("📱 Allow Permissions step appeared")
            hasConfirmedPermissions = false
            permissionGrantedViaURL = false
            
            // Check if the shortcut already completed (URL callback fired before this view appeared)
            if UserDefaults.standard.bool(forKey: "shortcut_wallpaper_applied") {
                debugLog("✅ Shortcut already completed before view appeared - enabling button immediately")
                permissionGrantedViaURL = true
                hasConfirmedPermissions = true
            } else {
                // Poll UserDefaults for the flag set by SceneDelegate/NoteWallApp URL handler
                // This handles the case where the URL fires after the view appears
                permissionPollTimer?.invalidate()
                permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    if UserDefaults.standard.bool(forKey: "shortcut_wallpaper_applied") {
                        debugLog("✅ Detected wallpaper-updated via UserDefaults poll")
                        permissionGrantedViaURL = true
                        hasConfirmedPermissions = true
                        permissionPollTimer?.invalidate()
                        permissionPollTimer = nil
                        
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                }
            }
            
            // CRITICAL: Configure audio session for notifications video playback
            // The PiP video player might have set it to a different mode
            do {
                try AVAudioSession.sharedInstance().setActive(false)
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                debugLog("✅ Audio session configured for notifications video")
            } catch {
                debugLog("⚠️ Failed to configure audio session: \(error)")
            }
            
            prepareNotificationsVideoPlayerIfNeeded()
            
            // Ensure video starts playing automatically and loops - try multiple times to handle timing
            func startVideoPlayback() {
                if let player = self.notificationsVideoPlayer {
                    // Ensure looper is active for continuous looping
                    if let looper = self.notificationsVideoLooper {
                        if looper.status == .failed, let item = player.currentItem {
                            // Recreate looper if it failed
                            let newLooper = AVPlayerLooper(player: player, templateItem: item)
                            self.notificationsVideoLooper = newLooper
                            debugLog("🔄 Recreated video looper")
                        }
                    } else if let item = player.currentItem {
                        // Create looper if it doesn't exist
                        let newLooper = AVPlayerLooper(player: player, templateItem: item)
                        self.notificationsVideoLooper = newLooper
                        debugLog("🔄 Created video looper")
                    }
                    
                    // Start playback
                    player.seek(to: .zero)
                    player.play()
                    debugLog("▶️ Attempted to start notifications video (rate: \(player.rate))")
                    
                    // Verify playback started and retry if needed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if player.rate == 0 {
                            // Retry with audio session reconfiguration
                            do {
                                try AVAudioSession.sharedInstance().setActive(false)
                                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                                try AVAudioSession.sharedInstance().setActive(true)
                            } catch {
                                debugLog("⚠️ Failed to reconfigure audio session: \(error)")
                            }
                            player.seek(to: .zero)
                            player.play()
                            debugLog("✅ Retry: Started notifications video playback (rate: \(player.rate))")
                        } else {
                            debugLog("✅ Notifications video playing and looping (rate: \(player.rate))")
                        }
                    }
                } else {
                    // Player not created yet, wait and try again
                    debugLog("⚠️ Player not ready, retrying in 0.3s")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        startVideoPlayback()
                    }
                }
            }
            
            // Start playback attempt immediately and with delays
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startVideoPlayback()
            }
            
            // Also try after a longer delay to ensure it starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let player = self.notificationsVideoPlayer, player.rate == 0 {
                    debugLog("⚠️ Video still not playing after 0.5s, forcing restart")
                    startVideoPlayback()
                }
            }
            
            // Final retry after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let player = self.notificationsVideoPlayer, player.rate == 0 {
                    debugLog("⚠️ Video still not playing after 1.0s, final retry")
                    startVideoPlayback()
                }
            }
        }
        .onDisappear {
            permissionPollTimer?.invalidate()
            permissionPollTimer = nil
            // Clear the flag so it's fresh if user returns to this step
            UserDefaults.standard.set(false, forKey: "shortcut_wallpaper_applied")
        }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutWallpaperApplied)) { _ in
            debugLog("✅ Received wallpaper-updated URL callback - enabling button")
            permissionGrantedViaURL = true
            hasConfirmedPermissions = true
            
            // Success haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    
    // Removed old permission tracking functions - now using simple checkbox confirmation
    
    /*
    private func handlePermissionAreaTap() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastPermissionTapTime)
        
        debugLog("🔵 Permission tap detected! Current count: \(permissionCount), Time since last: \(timeSinceLastTap)")
        
        // Increment permission count for each tap (0 → 1 → 2 → 3)
        if permissionCount < 3 {
            let newCount = permissionCount + 1
            debugLog("🔵 Incrementing permission count: \(permissionCount) → \(newCount)")
            
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                permissionCount = newCount
            }
            
            // If we've reached 3, set the flag and stop tracking
            if permissionCount >= 3 {
                debugLog("✅ Reached 3 permissions via taps, stopping tracking")
                hasManuallySetToThree = true
                stopPermissionTracking()
            }
        } else {
            debugLog("⚠️ Permission count already at 3, ignoring tap")
        }
        
        // Track tap timing for analytics (but don't use it for counting)
        if timeSinceLastTap < 3.0 {
            permissionTapCount += 1
        } else {
            permissionTapCount = 1
        }
        
        lastPermissionTapTime = now
        
        // Also check actual permissions after a short delay to catch real permission grants
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !self.hasManuallySetToThree {
                debugLog("🔵 Checking actual permissions after tap...")
            self.updatePermissionCount()
            }
        }
    }
    
    private func updatePermissionCount() {
        // Don't update if we've manually set to 3 based on taps
        guard !hasManuallySetToThree else {
            debugLog("⏭️ Skipping permission check - manually set to 3")
            return
        }
        
        debugLog("🔍 updatePermissionCount() called - checking all permissions...")
        var count = 0
        
        // Check 1: Lock Screen folder access via marker file
        let lockScreenFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("NoteWall", isDirectory: true)
            .appendingPathComponent("LockScreen", isDirectory: true)
        
        var hasLockScreenAccess = false
        if let lockURL = lockScreenFolderURL {
            let markerFiles = [
                ".permission-granted",
                ".shortcut-success",
                "lockscreen.jpg", // The actual wallpaper file the shortcut creates
                "lockscreen_background.jpg"
            ]
            
            for markerName in markerFiles {
                let markerFile = lockURL.appendingPathComponent(markerName)
                if FileManager.default.fileExists(atPath: markerFile.path) {
                    // Check if file was created recently (within last 5 minutes)
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: markerFile.path),
                       let creationDate = attributes[.creationDate] as? Date,
                       Date().timeIntervalSince(creationDate) < 300 { // 5 minutes
                        hasLockScreenAccess = true
                        debugLog("📁 Lock Screen folder: ✅ accessible (found marker: \(markerName), created \(Int(Date().timeIntervalSince(creationDate)))s ago)")
                        break
                    } else if FileManager.default.fileExists(atPath: markerFile.path) {
                        // File exists but might be old - still count it as permission was granted at some point
                        hasLockScreenAccess = true
                        debugLog("📁 Lock Screen folder: ✅ accessible (found marker: \(markerName), may be older)")
                        break
                    }
                }
            }
            
            if !hasLockScreenAccess {
                debugLog("📁 Lock Screen folder: ❌ no marker files found")
            }
        }
        
        if hasLockScreenAccess {
            count += 1
            debugLog("   ✅ Counting Lock Screen folder (count now: \(count))")
        }
        
        // Check 3: Notification permission
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                // Don't update if we've manually set to 3 based on taps
                guard !self.hasManuallySetToThree else {
                    debugLog("⏭️ Skipping permission check (async) - manually set to 3")
                    return
                }
                
                var newCount = count
                let notificationAuthorized = settings.authorizationStatus == .authorized
                debugLog("🔔 Notifications: status=\(settings.authorizationStatus.rawValue) (\(notificationAuthorized ? "✅ granted" : "❌ not granted"))")
                
                if notificationAuthorized {
                    newCount += 1
                    debugLog("   ✅ Counting Notifications (count now: \(newCount))")
                }
                
                debugLog("📊 Permission check result: \(newCount)/3 (current displayed: \(self.permissionCount)/3)")
                
                // Always update if the new count is different (but only increase, never decrease)
                if newCount > self.permissionCount {
                    debugLog("✅ Updating permission count: \(self.permissionCount) → \(newCount)")
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        self.permissionCount = newCount
                    }
                } else if newCount == self.permissionCount {
                    debugLog("➡️ Permission count unchanged: \(newCount)/3")
                } else {
                    debugLog("⚠️ Permission count would decrease (\(self.permissionCount) → \(newCount)), not updating")
                }
            }
        }
    }
    */

    @ViewBuilder
    private func chooseWallpapersStep(includePhotoPicker: Bool) -> some View {
        let isCompact = ScreenDimensions.isCompactDevice
        let titleFontSize: CGFloat = isCompact ? 24 : 28
        let sectionSpacing: CGFloat = isCompact ? 16 : 24
        let horizontalPadding: CGFloat = isCompact ? 16 : 24
        let topPadding: CGFloat = isCompact ? 20 : 32
        let buttonSize: CGFloat = isCompact ? 32 : 36
        let buttonIconSize: CGFloat = isCompact ? 12 : 14
        
        return ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                // Title row with help and edit buttons
                HStack(alignment: .top) {
                    Text("Choose Your Wallpapers")
                        .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                    
                    Spacer()
                    
                    // Buttons stacked vertically, aligned to the right
                    VStack(alignment: .trailing, spacing: isCompact ? 6 : 8) {
                        // Help button tile (squarish) - above Edit Notes
                        Button(action: {
                            // Medium haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            showHelpSheet = true
                        }) {
                            Image(systemName: "headphones")
                                .font(.system(size: buttonIconSize, weight: .semibold))
                                .foregroundColor(.appAccent)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.appAccent.opacity(0.1))
                                )
                        }
                        
                        // Edit Notes button
                        Button(action: {
                            // Track action
                            OnboardingAnalyticsTracker.shared.trackAction(.addNote, on: .chooseWallpapers, additionalParams: ["subtype": "edit_notes_tapped"])
                            
                            // Light impact haptic for edit notes button
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage = .addNotes
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.system(size: buttonIconSize, weight: .semibold))
                                Text("Edit Notes")
                                    .font(.system(size: isCompact ? 13 : 15, weight: .medium))
                            }
                            .foregroundColor(.appAccent)
                            .padding(.horizontal, isCompact ? 10 : 12)
                            .padding(.vertical, isCompact ? 6 : 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.appAccent.opacity(0.1))
                            )
                        }
                    }
                }

                if includePhotoPicker {
                    if #available(iOS 16.0, *) {
                        if isLoadingWallpaperStep {
                            VStack(spacing: isCompact ? 12 : 16) {
                                LoadingPlaceholder()
                                LoadingPlaceholder()
                                LoadingPlaceholder()
                            }
                            .transition(.opacity)
                        } else {
                            VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
                                LockScreenBackgroundPickerView(
                                    isSavingBackground: $isSavingLockScreenBackground,
                                    statusMessage: $lockScreenBackgroundStatusMessage,
                                    statusColor: $lockScreenBackgroundStatusColor,
                                    backgroundMode: Binding(
                                        get: { LockScreenBackgroundMode(rawValue: lockScreenBackgroundModeRaw) ?? .default },
                                        set: { lockScreenBackgroundModeRaw = $0.rawValue }
                                    ),
                                    backgroundOption: Binding(
                                        get: { LockScreenBackgroundOption(rawValue: lockScreenBackgroundRaw) ?? .default },
                                        set: { lockScreenBackgroundRaw = $0.rawValue }
                                    ),
                                    backgroundPhotoData: Binding(
                                        get: { lockScreenBackgroundPhotoData },
                                        set: { lockScreenBackgroundPhotoData = $0 }
                                    ),
                                    backgroundPhotoAvailable: !lockScreenBackgroundPhotoData.isEmpty
                                )

                                if let message = lockScreenBackgroundStatusMessage {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(lockScreenBackgroundStatusColor)
                                }
                                
                                // Lock Screen Widgets Section - clear card-based design
                                lockScreenWidgetsSection
                                    .padding(.top, isCompact ? 16 : 24)
                            }
                            .transition(.opacity)
                        }
                    }
                } else {
                        Text("Update to iOS 16+ to pick a photo directly. For now, the shortcut will reuse your current lock screen wallpaper.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, AdaptiveLayout.bottomScrollPadding)
        }
        .scrollAlwaysBounceIfAvailable()
    }
    
    private var lockScreenWidgetsSection: some View {
        let isCompact = ScreenDimensions.isCompactDevice
        
        return VStack(alignment: .leading, spacing: isCompact ? 10 : 12) {
            // Clear heading
            VStack(alignment: .leading, spacing: 4) {
                Text("Do you use lock screen widgets?")
                    .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("This adjusts where your notes appear on the lock screen")
                    .font(.caption)
                    .foregroundColor(Color(.systemGray2))
            }
            
            // Option buttons
            HStack(spacing: isCompact ? 10 : 12) {
                // Yes button (black)
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation {
                        hasLockScreenWidgets = true
                        hasSelectedWidgetOption = true
                    }
                }) {
                    Text("Yes")
                        .font(.system(size: isCompact ? 14 : 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isCompact ? 12 : 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(hasSelectedWidgetOption && hasLockScreenWidgets ? Color.appAccent : Color.clear, lineWidth: 2.5)
                                )
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                // No button (gray - matches preset gray color)
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation {
                        hasLockScreenWidgets = false
                        hasSelectedWidgetOption = true
                    }
                }) {
                    Text("No")
                        .font(.system(size: isCompact ? 14 : 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isCompact ? 12 : 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(red: 40 / 255, green: 40 / 255, blue: 40 / 255))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(hasSelectedWidgetOption && !hasLockScreenWidgets ? Color.appAccent : Color.clear, lineWidth: 2.5)
                                )
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            
            // Settings note
            Text("You can change this anytime in Settings")
                .font(.caption)
                .foregroundColor(Color(.systemGray3))
        }
        .padding(isCompact ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                .fill(Color(.systemGray6).opacity(0.3))
        )
    }

    @ViewBuilder
    private func overviewStep() -> some View {
        let isCompact = ScreenDimensions.isCompactDevice
        let subtitleFontSize: CGFloat = isCompact ? 14 : 16
        let buttonFontSize: CGFloat = isCompact ? 16 : 18
        let topSpacing: CGFloat = isCompact ? 24 : 40
        let mockupSpacing: CGFloat = isCompact ? 16 : 24
        let horizontalPadding: CGFloat = isCompact ? 28 : 40
        let buttonBottomPadding: CGFloat = isCompact ? 24 : 40
        
        ZStack {
            // Dark background
            Color.black.ignoresSafeArea()
            
            // Confetti overlay
            if showConfetti {
                ConfettiView(trigger: $confettiTrigger)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: topSpacing)
                
                // iPhone mockup preview - large and prominent
                iPhoneMockupPreview
                    .opacity(showMockupPreview ? 1 : 0)
                    .scaleEffect(showMockupPreview ? 1 : 0.95)
                    .animation(.easeOut(duration: 0.5), value: showMockupPreview)
                
                Spacer()
                    .frame(height: mockupSpacing)
                
                // Settings tip (only message shown)
                Text("You can change the font, color, and size of your notes anytime in Settings.")
                    .font(.system(size: subtitleFontSize * 0.9))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, horizontalPadding)
                    .opacity(showMockupPreview ? 1 : 0)
                
                Spacer()
                    .frame(height: isCompact ? 16 : 24) // Minimal padding before button
                
                // Continue button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // Continue to next step (Review Page)
                    advanceStep()
                }) {
                    Text("Continue")
                        .font(.system(size: buttonFontSize, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isCompact ? 14 : 18)
                        .background(
                            RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                .fill(Color.appAccent)
                        )
                        .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .opacity(showMockupPreview ? 1 : 0)
                .padding(.horizontal, isCompact ? 16 : 24)
                .padding(.bottom, buttonBottomPadding)
            }
        }
        .onAppear {
            loadWallpaperForPreview()
            
            // Trigger confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    showConfetti = true
                    confettiTrigger += 1
                }
            }
            
            // Fade in mockup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation {
                    showMockupPreview = true
                }
            }
            
            // Hide confetti after a few seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation {
                    showConfetti = false
                }
            }
        }
        .onDisappear {
            showMockupPreview = false
            showConfetti = false
        }
    }
    
    // MARK: - Transition Countdown View (Epic Version)
    
    @ViewBuilder
    private var transitionCountdownView: some View {
        let isCompact = ScreenDimensions.isCompactDevice
        let readyFontSize: CGFloat = isCompact ? 18 : 22
        let productivityFontSize: CGFloat = isCompact ? 22 : 28
        let neverForgetFontSize: CGFloat = isCompact ? 14 : 16
        let ringSize: CGFloat = isCompact ? 140 : 180
        let outerRingSize: CGFloat = isCompact ? 160 : 200
        
        ZStack {
            // Animated gradient background
            animatedGradientBackground
                .ignoresSafeArea()
            
            // Floating ambient particles
            FloatingParticlesView()
                .opacity(0.6)
            
            VStack(spacing: 0) {
                Spacer()
                
                // Animated text - word by word
                VStack(spacing: isCompact ? 8 : 12) {
                    // "Ready for your new"
                    HStack(spacing: isCompact ? 6 : 8) {
                        AnimatedWord(text: "Ready", isVisible: word1Visible, delay: 0)
                        AnimatedWord(text: "for", isVisible: word1Visible, delay: 0.1)
                        AnimatedWord(text: "your", isVisible: word1Visible, delay: 0.2)
                        AnimatedWord(text: "new", isVisible: word1Visible, delay: 0.3)
                    }
                    .font(.system(size: readyFontSize, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    
                    // "PRODUCTIVITY HACK"
                    HStack(spacing: isCompact ? 6 : 8) {
                        AnimatedWord(text: "PRODUCTIVITY", isVisible: word2Visible, delay: 0, isAccent: true)
                        AnimatedWord(text: "HACK", isVisible: word2Visible, delay: 0.15, isAccent: true)
                        AnimatedWord(text: "?", isVisible: word2Visible, delay: 0.25, isAccent: true)
                    }
                    .font(.system(size: productivityFontSize, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    
                    // "You'll never forget again"
                    HStack(spacing: isCompact ? 4 : 5) {
                        AnimatedWord(text: "So", isVisible: word3Visible, delay: 0)
                        AnimatedWord(text: "you'll", isVisible: word3Visible, delay: 0.08)
                        AnimatedWord(text: "never", isVisible: word3Visible, delay: 0.16)
                        AnimatedWord(text: "forget", isVisible: word3Visible, delay: 0.24)
                        AnimatedWord(text: "again", isVisible: word3Visible, delay: 0.32)
                    }
                    .font(.system(size: neverForgetFontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, isCompact ? 4 : 8)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, isCompact ? 24 : 32)
                
                Spacer()
                
                // Epic countdown with ring - centered
                ZStack {
                    // Outer glow ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.appAccent.opacity(0.3), Color.appAccent.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: isCompact ? 2 : 3
                        )
                        .frame(width: outerRingSize, height: outerRingSize)
                        .blur(radius: 8)
                        .opacity(countdownOpacity)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appAccent.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: isCompact ? 4 : 6, lineCap: .round)
                        )
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .opacity(countdownOpacity)
                    
                    // Inner glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.appAccent.opacity(0.2), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: ringSize / 2
                            )
                        )
                        .frame(width: ringSize, height: ringSize)
                        .opacity(countdownGlow)
                    
                    // Countdown number with effects
                    Text("\(countdownNumber)")
                        .font(.system(size: isCompact ? 72 : 100, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.appAccent],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.appAccent.opacity(0.5), radius: 20, x: 0, y: 0)
                        .shadow(color: Color.appAccent.opacity(0.3), radius: 40, x: 0, y: 0)
                        .scaleEffect(particleBurst ? 1.1 : 1.0)
                        .opacity(countdownOpacity)
                    
                    // Particle burst effect
                    if particleBurst {
                        CountdownBurstView()
                    }
                }
                .frame(width: isCompact ? 170 : 220, height: isCompact ? 170 : 220)
                
                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var animatedGradientBackground: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Animated accent glow - top
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .offset(x: -100, y: -200)
                .rotationEffect(.degrees(gradientRotation))
            
            // Animated accent glow - bottom
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .offset(x: 150, y: 400)
                .rotationEffect(.degrees(-gradientRotation * 0.5))
                .onAppear {
                    // Review prompt removed from here - only shown on Review Page now
                }
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                gradientRotation = 360
            }
        }
    }
    
    private func startTransitionCountdown() {
        // Medium haptic for important transition to final step
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Reset all states
        countdownNumber = 3
        transitionTextOpacity = 0
        countdownOpacity = 0
        showConfetti = false
        word1Visible = false
        word2Visible = false
        word3Visible = false
        word4Visible = false
        ringProgress = 0
        countdownGlow = 0
        particleBurst = false
        gradientRotation = 0
        
        // Hide progress indicator
        withAnimation(.easeOut(duration: 0.3)) {
            hideProgressIndicator = true
        }
        
        // Show transition screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.4)) {
                showTransitionScreen = true
            }
        }
        
        // Animate words in sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                word1Visible = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                word2Visible = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                word3Visible = true
            }
        }
        
        // Start countdown after text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.4)) {
                countdownOpacity = 1
            }
            startCountdown()
        }
    }
    
    private func startCountdown() {
        // Heavy haptic for countdown start
        let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
        
        // Countdown: 3
        countdownNumber = 3
        heavyImpact.impactOccurred()
        triggerBurst()
        
        // Animate ring to 25% (even spacing: 1/4 of circle)
        withAnimation(.easeInOut(duration: 0.9)) {
            ringProgress = 0.25
        }
        
        // Pulse glow
        withAnimation(.easeInOut(duration: 0.3)) {
            countdownGlow = 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.5)) {
                countdownGlow = 0.2
            }
        }
        
        // Countdown: 2
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                countdownNumber = 2
            }
            heavyImpact.impactOccurred()
            triggerBurst()
            
            // Animate ring to 50% (even spacing: 2/4 of circle)
            withAnimation(.easeInOut(duration: 0.9)) {
                ringProgress = 0.50
            }
            
            withAnimation(.easeInOut(duration: 0.3)) {
                countdownGlow = 0.8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    countdownGlow = 0.2
                }
            }
        }
        
        // Countdown: 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                countdownNumber = 1
            }
            heavyImpact.impactOccurred()
            triggerBurst()
            
            // Ring fills to 75% (even spacing: 3/4 of circle, leaving 25% for completion)
            withAnimation(.easeInOut(duration: 0.7)) {
                ringProgress = 0.75
            }
            
            withAnimation(.easeInOut(duration: 0.3)) {
                countdownGlow = 0.9
            }
            
            // After a brief pause, complete the ring smoothly (final 25% to make it even)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                // Smooth completion animation - final 25% for even spacing
                withAnimation(.easeInOut(duration: 0.35)) {
                    ringProgress = 1.0
                    countdownGlow = 1.0
                }
            }
        }
        
        // FINALE - GO! (trigger when ring completes)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            // Epic haptic sequence
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
            
            // Double tap for impact
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                heavyImpact.impactOccurred()
            }
            
            // Show confetti explosion
            withAnimation(.easeOut(duration: 0.2)) {
                showConfetti = true
                confettiTrigger += 1
            }
            
            // Transition to overview page (Mockup) -> Review -> Paywall
            // Delay slightly to let confetti boom first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showTransitionScreen = false
                    currentPage = .overview
                }
            }
            
            // Keep confetti longer for impact
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeOut(duration: 0.8)) {
                    showConfetti = false
                }
            }
        }
    }
    
    private func triggerBurst() {
        particleBurst = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            particleBurst = false
        }
    }
    
    private var iPhoneMockupPreview: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let availableWidth = geometry.size.width
            
            // ⚙️ MOCKUP SIZE CONTROLS ⚙️
            // Actual aspect ratio of mockup_light.png and mockup_dark.png (1x export): 946 x 2150 = 0.44 (1/2.27)
            // This matches the actual image dimensions to prevent cropping
            let mockupAspectRatio: CGFloat = 946.0 / 2150.0
            
            // 📏 HEIGHT MULTIPLIER: Controls mockup size (1.3 = 130% of screen height)
            //    - Increase (e.g., 1.5) = LARGER mockup (more zoom effect)
            //    - Decrease (e.g., 0.9) = SMALLER mockup (more space around it)
            let maxMockupHeight = availableHeight * 1.3
            
            // 📐 WIDTH MULTIPLIER: Controls horizontal fill (1.0 = 100% of screen width)
            //    - Increase (e.g., 1.1) = Mockup can extend beyond screen edges
            //    - Decrease (e.g., 0.8) = More padding on sides
            let mockupWidth = min(maxMockupHeight * mockupAspectRatio, availableWidth * 1.0)
            let mockupHeight = mockupWidth / mockupAspectRatio
            
            // Screen insets within the mockup frame (percentage-based)
            // These values must match the transparent screen window in the cropped mockup PNG
            // The mockup bezel is about 2.5% on each side horizontally, 1% top/bottom
            let screenInsetTop: CGFloat = mockupHeight * 0.012
            let screenInsetBottom: CGFloat = mockupHeight * 0.012
            let screenInsetHorizontal: CGFloat = mockupWidth * 0.042
            
            // Calculate screen dimensions - fits within the transparent window
            let screenWidth = mockupWidth - (screenInsetHorizontal * 2)
            let screenHeight = mockupHeight - screenInsetTop - screenInsetBottom
            
            // Corner radius that matches the mockup's screen corners (iPhone 14/15 style)
            let screenCornerRadius = mockupWidth * 0.115
            
            // ⚙️ WALLPAPER DISPLAY - 1:1 TRUE REPRESENTATION ⚙️
            // The wallpaper is shown exactly as it appears on real lock screen
            // 🔧 ADJUST ZOOM: Change .scaleEffect(0.77) below
            //    - 0.77 = Current (77% size - zoomed in slightly to eliminate black edges)
            //    - 1.0 = No zoom (100% - may crop edges)
            //    - 0.75 = More zoom out (75% - shows more but smaller, may show black edges)
            //    - 0.9 = Less zoom (90% - closer to edges)
            
            ZStack {
                // Wallpaper layer (behind the mockup) - TRUE 1:1 size, no cropping
                ZStack {
                    if let wallpaper = loadedWallpaperImage {
                        Image(uiImage: wallpaper)
                            .resizable()
                            .aspectRatio(contentMode: .fit) // ✅ Maintains aspect ratio, shows full image
                            .frame(maxWidth: screenWidth, maxHeight: screenHeight)
                            .scaleEffect(0.77) // 🔍 Zoomed in slightly to eliminate black edges and make it smoother
                    } else {
                        // Fallback gradient if wallpaper not loaded
                        RoundedRectangle(cornerRadius: screenCornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.15), Color(white: 0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: screenWidth, height: screenHeight)
                    }
                }
                .frame(width: screenWidth, height: screenHeight)
                .clipped()
                .mask(
                    RoundedRectangle(cornerRadius: screenCornerRadius, style: .continuous)
                )
                
                // iPhone mockup overlay (transparent screen window)
                // Use aspectRatio modifier to preserve the full image without cropping
                Image(useLightMockup ? "mockup_light_new" : "mockup_dark_new")
                    .resizable()
                    .aspectRatio(mockupAspectRatio, contentMode: .fit)
                    .frame(maxWidth: mockupWidth, maxHeight: mockupHeight)
            }
            .frame(width: availableWidth, height: availableHeight)
            .shadow(color: Color.black.opacity(0.35), radius: 25, x: 0, y: 12)
            .offset(y: 0) // Center vertically in the available space
        }
    }
    
    private func loadWallpaperForPreview() {
        // Load the user's generated lock screen wallpaper
        if let url = HomeScreenImageManager.lockScreenWallpaperURL(),
           FileManager.default.fileExists(atPath: url.path),
           let image = UIImage(contentsOfFile: url.path) {
            loadedWallpaperImage = image
            // Determine which mockup to use based on wallpaper brightness
            // SYNCED with WallpaperRenderer.textColorForBackground() - same threshold & logic
            let brightness = averageBrightnessOfTextArea(image)
            // brightness < 0.55 = dark image = WHITE notes = use mockup_dark (has white UI)
            // brightness >= 0.55 = bright image = BLACK notes = use mockup_light (has black UI)
            // useLightMockup = true means use "mockup_light", false means use "mockup_dark"
            useLightMockup = brightness >= 0.55
            debugLog("✅ Onboarding: Loaded wallpaper for preview")
            debugLog("   📊 Text area brightness: \(String(format: "%.3f", brightness))")
            debugLog("   🎨 Notes are \(brightness < 0.55 ? "WHITE" : "BLACK")")
            debugLog("   📱 Using mockup_\(useLightMockup ? "light" : "dark")")
        } else {
            debugLog("⚠️ Onboarding: Could not load wallpaper for preview")
            loadedWallpaperImage = nil
            useLightMockup = false // Default to dark mockup (white UI) for dark fallback
        }
    }
    
    /// Calculates average brightness of the TEXT AREA of an image
    /// SYNCED with WallpaperRenderer.averageBrightness() - same sampling region & formula
    /// Returns brightness value 0.0 (black) to 1.0 (white)
    private func averageBrightnessOfTextArea(_ image: UIImage) -> CGFloat {
        let imageSize = image.size
        
        // Sample from the TEXT AREA (where notes appear on lock screen)
        // Same region as WallpaperRenderer: top 38% to bottom 85%, left 80%
        let textAreaRect = CGRect(
            x: 0,
            y: imageSize.height * 0.38,  // Start below clock/widgets area
            width: imageSize.width * 0.8, // Left portion where text is
            height: imageSize.height * 0.47 // Up to above flashlight area
        )
        
        // Crop to text area first
        guard let cgImage = image.cgImage,
              let croppedCGImage = cgImage.cropping(to: CGRect(
                x: textAreaRect.origin.x * CGFloat(cgImage.width) / imageSize.width,
                y: textAreaRect.origin.y * CGFloat(cgImage.height) / imageSize.height,
                width: textAreaRect.width * CGFloat(cgImage.width) / imageSize.width,
                height: textAreaRect.height * CGFloat(cgImage.height) / imageSize.height
              )) else {
            return averageBrightnessFullImage(of: image)
        }
        
        let croppedImage = UIImage(cgImage: croppedCGImage)
        return averageBrightnessFullImage(of: croppedImage)
        }
    
    /// Samples brightness from the entire image
    private func averageBrightnessFullImage(of image: UIImage) -> CGFloat {
        let sampleSize = CGSize(width: 12, height: 12)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: sampleSize, format: format)
        let downsampled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: sampleSize))
        }

        guard let cgImage = downsampled.cgImage,
              let data = cgImage.dataProvider?.data,
              let pointer = CFDataGetBytePtr(data) else {
            return 0.5
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        guard bytesPerPixel >= 3 else { return 0.5 }

        var total: CGFloat = 0
        let width = Int(sampleSize.width)
        let height = Int(sampleSize.height)

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * cgImage.bytesPerRow) + (x * bytesPerPixel)
                let r = CGFloat(pointer[index])
                let g = CGFloat(pointer[index + 1])
                let b = CGFloat(pointer[index + 2])
                // ITU-R BT.601 formula (same as WallpaperRenderer)
                total += (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            }
        }

        return total / CGFloat(width * height)
    }

    private func demoVideoSection(minHeight: CGFloat) -> some View {
        Group {
            if let player = demoVideoPlayer {
                VideoPlayer(player: player)
                    .aspectRatio(9/16, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: minHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
                    .allowsHitTesting(false)
                    .onAppear {
                        player.playImmediately(atRate: demoVideoPlaybackRate)
                    }
                    .onDisappear {
                        player.pause()
                        player.seek(to: .zero)
                    }
                    .accessibilityLabel("NoteWall demo video showing the shortcut flow")
            } else {
                demoVideoPlaceholder(minHeight: minHeight)
            }
        }
        .onAppear(perform: prepareDemoVideoPlayerIfNeeded)
    }

    private func demoVideoPlaceholder(minHeight: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.systemGray6))
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color.appAccent)
                    Text("Demo video coming soon")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            )
            .frame(minHeight: minHeight)
            .accessibilityHidden(true)
    }

    private var primaryButtonTitle: String {
        switch currentPage {
        case .preOnboardingHook, .nameInput, .painPoint, .quizForgetMost, .quizPhoneChecks, .quizDistraction,
             .personalizationLoading, .resultsPreview, .resultsInsight, .socialProof, .notificationPermission, .reviewPage, .setupIntro, .shortcutSuccess, .setupComplete:
            return ""
        case .welcome:
            return NSLocalizedString("Continue", comment: "")
        case .installShortcut:
            return didOpenShortcut ? NSLocalizedString("Next", comment: "") : NSLocalizedString("Install", comment: "")
        case .addNotes:
            return NSLocalizedString("Continue", comment: "")
        case .chooseWallpapers:
            return isLaunchingShortcut ? NSLocalizedString("Launching Shortcut…", comment: "") : NSLocalizedString("Next", comment: "")
        case .allowPermissions:
            return hasConfirmedPermissions ? NSLocalizedString("Continue", comment: "") : NSLocalizedString("Grant Permissions First", comment: "")
        case .overview:
            return NSLocalizedString("Start Using NoteWall", comment: "")
        }
    }

    private var primaryButtonIconName: String? {
        switch currentPage {
        case .preOnboardingHook, .nameInput, .painPoint, .quizForgetMost, .quizPhoneChecks, .quizDistraction,
             .personalizationLoading, .resultsPreview, .resultsInsight, .socialProof, .notificationPermission, .reviewPage, .setupIntro, .shortcutSuccess, .setupComplete:
            return nil // These pages have their own buttons
        case .welcome:
            return "arrow.right.circle.fill"
        case .installShortcut:
            return "bolt.fill"
        case .addNotes:
            return "arrow.right.circle.fill"
        case .chooseWallpapers:
            return isLaunchingShortcut ? nil : "paintbrush.pointed.fill"
        case .allowPermissions:
            return "checkmark.shield.fill"
        case .overview:
            return "checkmark.circle.fill"
        }
    }

    private var primaryButtonEnabled: Bool {
        switch currentPage {
        case .preOnboardingHook, .nameInput, .painPoint, .quizForgetMost, .quizPhoneChecks, .quizDistraction,
             .personalizationLoading, .resultsPreview, .resultsInsight, .socialProof, .notificationPermission, .reviewPage, .setupIntro, .shortcutSuccess, .setupComplete:
            return false // These pages have their own buttons
        case .welcome:
            return true
        case .installShortcut:
            return true
        case .addNotes:
            return !onboardingNotes.isEmpty
        case .chooseWallpapers:
            let hasLockSelection: Bool
            if let mode = LockScreenBackgroundMode(rawValue: lockScreenBackgroundModeRaw) {
                if mode == .photo {
                    hasLockSelection = !lockScreenBackgroundPhotoData.isEmpty
                } else if mode == .notSelected {
                    hasLockSelection = false
                } else {
                    hasLockSelection = true
                }
            } else {
                hasLockSelection = false
            }
            let hasWidgetSelection = hasSelectedWidgetOption
            return hasLockSelection && hasWidgetSelection && !isSavingLockScreenBackground && !isLaunchingShortcut
        case .allowPermissions:
            return hasConfirmedPermissions
        case .overview:
            return true
        }
    }

    private func handlePrimaryButton() {
        debugLog("🎯 Onboarding: Primary button tapped on page: \(currentPage.progressTitle)")
        
        // Track button tap action
        OnboardingAnalyticsTracker.shared.trackAction(.next, on: currentPage)
        
        // Light impact haptic for primary button tap
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Dismiss keyboard before any transition for smooth animation
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        switch currentPage {
        case .preOnboardingHook, .nameInput, .painPoint, .quizForgetMost, .quizPhoneChecks, .quizDistraction,
             .personalizationLoading, .resultsPreview, .resultsInsight, .socialProof, .notificationPermission, .reviewPage, .setupIntro, .shortcutSuccess, .setupComplete:
            // These pages have their own buttons and handle navigation internally
            break
        case .welcome:
            // Show Shortcuts/Safari requirements check before proceeding
            showShortcutsCheckAlert = true
        case .installShortcut:
            // This is now handled by custom buttons in the view
             break
        case .addNotes:
            // Auto-save pending note content if present
            let trimmed = currentNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let newNote = Note(text: trimmed, isCompleted: false)
                onboardingNotes.append(newNote)
                currentNoteText = ""
                // Generate haptic feedback for the save
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            
            // Move directly to wallpapers
            withAnimation(.easeInOut(duration: 0.3)) {
                self.currentPage = .chooseWallpapers
            }
        case .chooseWallpapers:
            saveWallpaperAndContinue()
        case .allowPermissions:
            // Go to setup complete celebration
            withAnimation(.easeInOut(duration: 0.3)) {
                self.currentPage = .setupComplete
            }
        case .overview:
            completeOnboarding()
        }
    }

    private func advanceStep() {
        // INTERCEPT: Show Paywall after Review Page
        // This must be checked BEFORE the 'next' guard because reviewPage is the last step
        // SKIP paywall entirely for pipeline migration users (they are already premium)
        if currentPage == .reviewPage && !isPipelineMigration {
            // Only show if we haven't already (though logic should prevent loops)
            if !showPostOnboardingPaywall {
                showPostOnboardingPaywall = true
                return // Stop advancement until paywall is dismissed
            }
        }

        guard let next = OnboardingPage(rawValue: currentPage.rawValue + 1) else { 
            return 
        }
        
        // Light impact haptic for page transition
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        withAnimation(.easeInOut) {
            currentPage = next
        }
    }
    
    private func goBackStep() {
        guard currentPage.rawValue > 0 else { return }
        guard let previous = OnboardingPage(rawValue: currentPage.rawValue - 1) else { return }
        
        // Track back action
        OnboardingAnalyticsTracker.shared.trackAction(.back, on: currentPage)
        
        // Light impact haptic for going back
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Reset transition states when going back from overview
        if currentPage == .overview {
            hideProgressIndicator = false
            showConfetti = false
        }
        
        withAnimation(.easeInOut) {
            currentPage = previous
        }
    }
    
    private func handleSwipeGesture(_ gesture: DragGesture.Value) {
        let horizontalAmount = gesture.translation.width
        let verticalAmount = abs(gesture.translation.height)
        
        // Only handle horizontal swipes (not vertical)
        guard abs(horizontalAmount) > verticalAmount else { return }
        
        // Swipe right to go back
        if horizontalAmount > 50 {
            // Only allow going back from overview to chooseWallpapers
            if currentPage == .overview {
                goBackStep()
            }
        }
        // Swipe left to go forward (optional, can be removed if not desired)
        else if horizontalAmount < -50 {
            if currentPage == .welcome {
                advanceStep()
            } else if currentPage == .installShortcut && didOpenShortcut {
                advanceStep()
            } else if currentPage == .addNotes && primaryButtonEnabled {
                advanceStep()
            } else if currentPage == .chooseWallpapers && primaryButtonEnabled {
                saveWallpaperAndContinue()
            } else if currentPage == .allowPermissions {
                // Go to setup complete on swipe as well
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPage = .setupComplete
                }
            }
        }
    }

    private func saveWallpaperAndContinue() {
        debugLog("✅ Onboarding: Saving wallpaper and running shortcut to apply it")
        
        HomeScreenImageManager.prepareStorageStructure()
        
        // Save notes BEFORE generating wallpaper so ContentView can read them
        saveOnboardingNotes()
        
        // Generate wallpaper and launch shortcut to apply it
        // This will trigger permission prompts automatically
        finalizeWallpaperSetup(shouldLaunchShortcut: true)
        
        // Advance to next step (Allow Permissions) - this happens after wallpaper is generated
        advanceStep()
    }

    private func installShortcut() {
        guard let url = URL(string: shortcutURL) else { return }
        
        // Track shortcut install action
        OnboardingAnalyticsTracker.shared.trackAction(.installShortcut, on: currentPage)
        
        // If user is on "Ready to Try Again" page (userWentToSettings == true),
        // we need to reload the video with the fix guide version
        // Otherwise, prepare PiP video if not already loaded
        if userWentToSettings {
            // Stop any active PiP and reload with the correct video for the fix flow
            pipVideoPlayerManager.stopPictureInPicture()
            pipVideoPlayerManager.stop()
            // Force reload by calling preparePiPVideo which will load the fix guide
            // preparePiPVideo checks userWentToSettings to determine which video to use
            preparePiPVideo()
        } else if !pipVideoPlayerManager.hasLoadedVideo {
            preparePiPVideo()
        }
        shouldStartPiP = true
        
        Task {
            // Brief wait for player to be ready (much shorter now!)
            var attempts = 0
            while !pipVideoPlayerManager.isReadyToPlay && attempts < 20 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                attempts += 1
            }
            
            // PiP controller should be ready immediately since 1x1 container is created in loadVideo()
            // But let's verify it's ready
            if !pipVideoPlayerManager.isPiPControllerReady {
                debugLog("⚠️ Onboarding: PiP controller not ready yet, waiting briefly...")
                attempts = 0
                while !pipVideoPlayerManager.isPiPControllerReady && attempts < 10 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    attempts += 1
                }
            }
            
            if pipVideoPlayerManager.isReadyToPlay && pipVideoPlayerManager.isPiPControllerReady {
                debugLog("✅ Onboarding: Player and PiP controller ready")
                
                // Make sure video is at the beginning
                await MainActor.run {
                    pipVideoPlayerManager.getPlayer()?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                }
                
                // CRITICAL: Start playing the video BEFORE opening Shortcuts
                // iOS requires the video to be actively playing before PiP can work
                _ = pipVideoPlayerManager.play()
                debugLog("✅ Onboarding: Started video playback")
                
                // VERIFY playback actually started - this is the key fix!
                // Wait a moment for playback to begin
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                
                // Check if video is actually playing
                var playbackAttempts = 0
                while !pipVideoPlayerManager.isPlaying && playbackAttempts < 10 {
                    debugLog("⚠️ Onboarding: Playback not started yet, retrying... (attempt \(playbackAttempts + 1))")
                    await MainActor.run {
                        // Force play again
                        pipVideoPlayerManager.getPlayer()?.playImmediately(atRate: 1.0)
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    playbackAttempts += 1
                }
                
                if pipVideoPlayerManager.isPlaying {
                    debugLog("✅ Onboarding: Verified video is playing (rate > 0)")
                } else {
                    debugLog("⚠️ Onboarding: Video may not be playing, but proceeding anyway")
                }
                
                
                // Open Shortcuts immediately - PiP will start AUTOMATICALLY when app backgrounds
                // Thanks to: canStartPictureInPictureAutomaticallyFromInline = true
                debugLog("🚀 Onboarding: Opening Shortcuts - PiP will start automatically when app backgrounds")
                
                // Pause the main video player (welcomeVideoPlayer) if it's playing
                await MainActor.run {
                    if let player = self.welcomeVideoPlayer, player.rate > 0 {
                        player.pause()
                        self.isWelcomeVideoPaused = true
                        debugLog("⏸️ Welcome video paused before opening Shortcuts")
                    }
                }
                
                await MainActor.run {
                    UIApplication.shared.open(url) { success in
                        DispatchQueue.main.async {
                            if success {
                                self.didOpenShortcut = true
                                debugLog("✅ Onboarding: Opened Shortcuts")
                            } else {
                                debugLog("⚠️ Onboarding: Shortcut URL open failed. This may be due to:")
                                debugLog("   - iCloud Drive connectivity issues")
                                debugLog("   - Pending iCloud terms acceptance")
                                debugLog("   - Network connectivity problems")
                                debugLog("   - Shortcuts app privacy settings")
                                self.shouldStartPiP = false
                                // Stop PiP and playback if Shortcuts didn't open
                                self.pipVideoPlayerManager.stopPictureInPicture()
                                self.pipVideoPlayerManager.stop()
                                // Still advance to step 3 even if Shortcuts didn't open
                                if self.shouldAdvanceToInstallStep {
                                    // Cancel fallback timer since we're handling it here
                                    self.advanceToInstallStepTimer?.invalidate()
                                    self.advanceToInstallStepTimer = nil
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        withAnimation(.easeInOut) {
                                            self.currentPage = .installShortcut
                                        }
                                        self.shouldAdvanceToInstallStep = false
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                debugLog("❌ Onboarding: Cannot prepare PiP - Player ready: \(self.pipVideoPlayerManager.isReadyToPlay), Controller ready: \(self.pipVideoPlayerManager.isPiPControllerReady)")
                // Still open the Shortcuts URL even if PiP isn't ready
                await MainActor.run {
                    UIApplication.shared.open(url) { success in
                        DispatchQueue.main.async {
                            if success {
                                self.didOpenShortcut = true
                            } else {
                                // Still advance to step 3 even if Shortcuts didn't open
                                if self.shouldAdvanceToInstallStep {
                                    // Cancel fallback timer since we're handling it here
                                    self.advanceToInstallStepTimer?.invalidate()
                                    self.advanceToInstallStepTimer = nil
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        withAnimation(.easeInOut) {
                                            self.currentPage = .installShortcut
                                        }
                                        self.shouldAdvanceToInstallStep = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func preparePiPVideo() {
        // Determine which video to use based on whether user went to Settings (fix flow)
        let videoResourceName = userWentToSettings ? "fix-guide-final-version" : "notewall-pip-vid"
        
        // If userWentToSettings is true, always reload (we're switching to fix guide)
        // Otherwise, only load if not already loaded
        let needsReload = userWentToSettings || !pipVideoPlayerManager.hasLoadedVideo
        
        if !needsReload {
            debugLog("✅ Onboarding: PiP video already loaded, skipping reload")
            return
        }
        
        guard let videoURL = getVideoURL(for: videoResourceName) else {
            debugLog("⚠️ Onboarding: PiP demo video not found for resource: \(videoResourceName)")
            return
        }
        
        debugLog("🎬 Onboarding: Preparing PiP video from: \(videoURL.absoluteString) (resource: \(videoResourceName))")
        
        // Load the video (this will call performCleanup() internally if needed)
        let loaded = pipVideoPlayerManager.loadVideo(url: videoURL)
        
        if loaded {
            debugLog("✅ Onboarding: Video loaded, waiting for player to be ready")
            
            // Wait for player to be ready, then set up the layer
            Task {
                var attempts = 0
                while !pipVideoPlayerManager.isReadyToPlay && attempts < 50 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    attempts += 1
                }
                
                if pipVideoPlayerManager.isReadyToPlay {
                    debugLog("✅ Onboarding: Player is ready")
                    
                    // Trigger a state update to make the view add the layer
                    await MainActor.run {
                        // Force update by touching a @Published property
                        _ = pipVideoPlayerManager.isReadyToPlay
                    }
                }
            }
        }
    }

    private func completeOnboarding() {
        // Save notes to AppStorage before completing
        saveOnboardingNotes()
        
        // Cancel abandoned onboarding notifications - user completed!
        NotificationManager.shared.cancelAbandonedOnboardingReminders()
        // Clear saved onboarding progress
        savedOnboardingPageRaw = 0
        
        // Track onboarding completion
        OnboardingAnalyticsTracker.shared.trackOnboardingComplete()
        
        // Success notification haptic for completing onboarding
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // NOTE: hasCompletedSetup and completedOnboardingVersion are set AFTER paywall is dismissed
        // to prevent the onboarding from being dismissed before the paywall sheet can be shown.
        // See the .sheet(isPresented: $showPostOnboardingPaywall) onDisappear handler.
        
        shouldShowTroubleshootingBanner = true // Show troubleshooting banner on home screen
        hasShownAutoUpdatePrompt = true // No longer needed but keep for compatibility
        
        // Always use automatic wallpaper updates - this is the default app behavior
        autoUpdateWallpaperAfterDeletionRaw = "true"
        saveWallpapersToPhotos = false // Files only for clean experience
        
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
        
        // MARK: - Hard Paywall Check
        // CRITICAL: Ensure user is premium before completing setup
        // EXCEPTION: Pipeline migration users are already premium, skip this check
        guard PaywallManager.shared.isPremium || isPipelineMigration else {
            debugLog("⚠️ completeOnboarding called but user is NOT premium. Aborting completion.")
            return
        }
        
        // If this is a pipeline migration, mark the user as migrated to the new pipeline
        if isPipelineMigration {
            UserDefaults.standard.set(true, forKey: "hasCompletedPipelineMigration")
            debugLog("✅ Pipeline migration complete - user switched to new lock-screen-only shortcut")
        }
        
        // Mark as complete immediately since paywall is now earlier
        hasCompletedSetup = true
        completedOnboardingVersion = onboardingVersion
        WhatsNewManager.shared.markAsShown()
        requestAppReviewIfNeeded()
    }

    

    private func prepareDemoVideoPlayerIfNeeded() {
        guard demoVideoPlayer == nil else { return }
        guard let bundleURL = Bundle.main.url(forResource: "notewall-pip-vid", withExtension: "mp4") else {
            debugLog("⚠️ Onboarding: Demo video not found in bundle")
            return
        }

        // Use bundle URL directly - bundle resources are always accessible to AVFoundation
        // and don't trigger sandbox extension warnings
        let item = AVPlayerItem(url: bundleURL)
        let queuePlayer = AVQueuePlayer()
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        queuePlayer.isMuted = true
        queuePlayer.automaticallyWaitsToMinimizeStalling = false
        queuePlayer.playImmediately(atRate: demoVideoPlaybackRate)

        demoVideoPlayer = queuePlayer
        demoVideoLooper = looper
    }
    
    private func notificationsVideoSection(minHeight: CGFloat) -> some View {
        Group {
            if let player = notificationsVideoPlayer {
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .mask(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .padding(.vertical, 20)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
                    .onAppear {
                        print("🎬 Video view appeared")
                        print("   - Player exists: true")
                        print("   - Current item: \(player.currentItem != nil)")
                        print("   - Item status: \(player.currentItem?.status.rawValue ?? -1)")
                        print("   - Current rate: \(player.rate)")
                        
                        // Small delay to ensure view hierarchy is ready
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            print("▶️ Attempting to play...")
                            player.playImmediately(atRate: self.demoVideoPlaybackRate)
                            
                            // Check if playback actually started
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                let currentRate = player.rate
                                let currentTime = player.currentTime().seconds
                                print("📊 Playback status after 0.5s:")
                                print("   - Rate: \(currentRate) (target: \(self.demoVideoPlaybackRate))")
                                print("   - Current time: \(currentTime)s")
                                print("   - Time base rate: \(player.currentItem?.timebase?.rate ?? 0)")
                                
                                if currentRate == 0 {
                                    print("⚠️ WARNING: Player rate is 0 - video may not be playing!")
                                    print("   Trying alternative play method...")
                                    player.play()
                                    player.rate = self.demoVideoPlaybackRate
                                }
                            }
                        }
                    }
                    .onDisappear {
                        print("⏸️ Video view disappeared, pausing")
                        player.pause()
                        player.seek(to: .zero)
                    }
                    .accessibilityLabel("Notifications demo video")
            } else {
                notificationsVideoPlaceholder(minHeight: minHeight)
                    .onAppear {
                        print("⚠️ Video player is nil when view appeared!")
                        print("   Attempting to prepare player now...")
                        prepareNotificationsVideoPlayerIfNeeded()
                    }
            }
        }
    }
    
    private func notificationsVideoPlaceholder(minHeight: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.systemGray6))
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color.appAccent)
                    Text("Notifications video loading...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            )
            .frame(minHeight: minHeight)
            .accessibilityHidden(true)
    }
    
    private func prepareNotificationsVideoPlayerIfNeeded() {
        // If player already exists, ensure it's playing (don't skip)
        if let existingPlayer = notificationsVideoPlayer {
            print("⚠️ Video player already exists, ensuring playback")
            // Ensure audio session is configured for playback
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("⚠️ Failed to configure audio session: \(error)")
            }
            // Force playback if not playing
            if existingPlayer.rate == 0 {
                existingPlayer.seek(to: .zero)
                existingPlayer.play()
                print("▶️ Restarted existing notifications video player")
            }
            return
        }
        
        debugLog("🔍 Onboarding: Preparing notifications video player...")
        
        // Try to find the video file
        guard let bundleURL = Bundle.main.url(forResource: "notifications-of-permissions", withExtension: "mp4") else {
            print("❌ CRITICAL: notifications-of-permissions.mp4 not found in bundle!")
            print("📁 Bundle path: \(Bundle.main.bundlePath)")
            
            // List ALL video files in bundle for debugging
            if let files = try? FileManager.default.contentsOfDirectory(atPath: Bundle.main.bundlePath) {
                let videoFiles = files.filter { $0.hasSuffix(".mov") || $0.hasSuffix(".mp4") }
                print("📁 Video files in bundle: \(videoFiles)")
            }
            return
        }
        
        print("✅ Found notifications-of-permissions.mp4 at: \(bundleURL.path)")
        
        // Verify file is accessible and has content
        let fileManager = FileManager.default
        guard fileManager.isReadableFile(atPath: bundleURL.path) else {
            print("❌ File exists but is not readable!")
            return
        }
        
        if let attrs = try? fileManager.attributesOfItem(atPath: bundleURL.path),
           let size = attrs[.size] as? Int64 {
            print("📊 File size: \(size) bytes (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))")
            if size == 0 {
                print("❌ File is empty!")
                return
            }
        }
        
        // Create asset and check if it's playable
        let asset = AVAsset(url: bundleURL)
        
        // Log asset properties
        Task {
            let isPlayable = try? await asset.load(.isPlayable)
            let duration = try? await asset.load(.duration)
            let tracks = try? await asset.load(.tracks)
            
            await MainActor.run {
                print("📹 Asset properties:")
                print("   - Playable: \(isPlayable ?? false)")
                print("   - Duration: \(duration?.seconds ?? 0) seconds")
                print("   - Tracks: \(tracks?.count ?? 0)")
                
                if let videoTracks = tracks?.filter({ $0.mediaType == .video }) {
                    print("   - Video tracks: \(videoTracks.count)")
                }
            }
        }
        
        let item = AVPlayerItem(asset: asset)
        
        // Observe player item status with detailed logging
        _ = item.observe(\.status, options: [.new, .initial]) { playerItem, _ in
            DispatchQueue.main.async {
                switch playerItem.status {
                case .readyToPlay:
                    print("✅ notifications-of-permissions.mp4 player item READY TO PLAY (Allow Permissions step)")
                    print("   - Duration: \(playerItem.duration.seconds) seconds")
                    if let videoTrack = playerItem.asset.tracks(withMediaType: .video).first {
                        let videoSize = videoTrack.naturalSize
                        let aspectRatio = videoSize.width / videoSize.height
                        self.notificationsVideoAspectRatio = aspectRatio
                        print("   - Natural size: \(videoSize)")
                        print("   - Aspect ratio: \(aspectRatio)")
                    }
                    // Auto-play when ready if we're on the allowPermissions step
                    if self.currentPage == .allowPermissions, let player = self.notificationsVideoPlayer {
                        player.seek(to: .zero)
                        player.play()
                        print("   - Auto-playing video (step 6 is active)")
                    }
                case .failed:
                    print("❌ Player item FAILED")
                    if let error = playerItem.error as NSError? {
                        print("   - Error: \(error.localizedDescription)")
                        print("   - Domain: \(error.domain)")
                        print("   - Code: \(error.code)")
                        print("   - UserInfo: \(error.userInfo)")
                    }
                case .unknown:
                    print("⚠️ Player item status UNKNOWN")
                @unknown default:
                    print("⚠️ Player item status @unknown default")
                }
            }
        }
        
        // Observe playback errors
        _ = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { notification in
            print("❌ Playback failed to play to end time")
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("   Error: \(error.localizedDescription)")
            }
        }
        
        // Configure audio session for notifications video playback
        // This ensures it works even after PiP video has been used
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ Audio session configured for notifications video")
        } catch {
            print("⚠️ Failed to configure audio session: \(error)")
        }
        
        // Create looping player
        let queuePlayer = AVQueuePlayer()
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        
        queuePlayer.isMuted = true
        queuePlayer.automaticallyWaitsToMinimizeStalling = false
        
        // Store everything
        notificationsVideoPlayer = queuePlayer
        notificationsVideoLooper = looper
        
        print("✅ Notifications video player created")
        print("   - Player ready: \(queuePlayer.currentItem != nil)")
        print("   - Looper status: \(looper.status.rawValue)")
        
        // IMPORTANT: Don't call play here - let the view's onAppear handle it
        // This prevents race conditions with the VideoPlayer view setup
    }
    
    private func setupWelcomeVideoPlayer() {
        guard welcomeVideoPlayer == nil else {
            // If player already exists, just ensure it's playing
            if let player = welcomeVideoPlayer, player.rate == 0 {
                player.play()
            }
            return
        }
        
        debugLog("🔍 Onboarding: Setting up welcome video player...")
        
        // Try to find the video file (remote URL or bundle fallback)
        guard let videoURL = getVideoURL(for: "welcome-video") else {
            debugLog("❌ welcome-video.mp4 not found!")
            return
        }
        
        debugLog("✅ Found welcome-video at: \(videoURL.absoluteString)")
        
        // Create asset and player item
        let asset = AVAsset(url: videoURL)
        let item = AVPlayerItem(asset: asset)
        
        // Create looping player
        let queuePlayer = AVQueuePlayer()
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        
        // Configure player for autoplay and looping
        queuePlayer.isMuted = isWelcomeVideoMuted // Sync with state
        queuePlayer.automaticallyWaitsToMinimizeStalling = false
        
        // Store everything
        welcomeVideoPlayer = queuePlayer
        welcomeVideoLooper = looper
        
        debugLog("✅ Welcome video player created")
        
        // Get video duration
        Task {
            let duration = try? await asset.load(.duration)
            await MainActor.run {
                if let duration = duration {
                    welcomeVideoDuration = duration.seconds
                    debugLog("📹 Welcome video duration: \(welcomeVideoDuration) seconds")
                }
            }
        }
        
        // Set up progress tracking timer
        startWelcomeVideoProgressTracking()
        
        // Start playing automatically
        queuePlayer.play()
        isWelcomeVideoPaused = false
        debugLog("▶️ Welcome video started playing")
    }
    
    private func startWelcomeVideoProgressTracking() {
        // Stop any existing timer
        welcomeVideoProgressTimer?.invalidate()
        
        // Create new timer to update progress
        welcomeVideoProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = self.welcomeVideoPlayer else { return }
            
            let currentTime = CMTimeGetSeconds(player.currentTime())
            let duration = self.welcomeVideoDuration > 0 ? self.welcomeVideoDuration : CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
            
            if duration > 0 {
                // Calculate progress, handling looping
                var progress = currentTime / duration
                
                // If video loops and we're past the duration, reset progress
                if progress >= 1.0 {
                    progress = 0.0
                }
                
                self.welcomeVideoProgress = min(max(progress, 0), 1)
            }
        }
    }
    
    private func stopWelcomeVideoProgressTracking() {
        welcomeVideoProgressTimer?.invalidate()
        welcomeVideoProgressTimer = nil
    }
    
    private func seekVideo(by seconds: Double) {
        guard let player = welcomeVideoPlayer else { return }
        
        // Get current time
        let currentTime = player.currentTime()
        let currentSeconds = CMTimeGetSeconds(currentTime)
        
        // Calculate new time
        let newSeconds = max(0, currentSeconds + seconds)
        let newTime = CMTime(seconds: newSeconds, preferredTimescale: currentTime.timescale)
        
        // Seek to new time
        player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
        
        debugLog("⏩ Video seeked by \(seconds) seconds to \(newSeconds)s")
    }
    
    private func toggleMute() {
        guard let player = welcomeVideoPlayer else { return }
        
        isWelcomeVideoMuted.toggle()
        player.isMuted = isWelcomeVideoMuted
        
        debugLog(isWelcomeVideoMuted ? "🔇 Welcome video muted" : "🔊 Welcome video unmuted")
    }
    
    // MARK: - Stuck/Troubleshooting Video Controls
    
    private func setupStuckVideoPlayerIfNeeded() {
        // If player already exists, just ensure it's playing and tracking
        if stuckGuideVideoPlayer != nil {
            debugLog("⚠️ Stuck guide video player already exists - ensuring playback")
            ensureStuckVideoPlaying()
            return
        }
        
        debugLog("🔍 Setting up stuck guide video player...")
        debugLog("   - Looking for resource: \(stuckVideoResourceName)")
        
        guard let url = Bundle.main.url(forResource: stuckVideoResourceName, withExtension: "mp4") ??
                        Bundle.main.url(forResource: stuckVideoResourceName, withExtension: "mov") else {
            debugLog("❌ Stuck guide video not found in bundle!")
            debugLog("   - Tried: \(stuckVideoResourceName).mp4")
            debugLog("   - Tried: \(stuckVideoResourceName).mov")
            debugLog("   - Bundle path: \(Bundle.main.bundlePath)")
            
            // List video files in bundle for debugging
            if let files = try? FileManager.default.contentsOfDirectory(atPath: Bundle.main.bundlePath) {
                let videoFiles = files.filter { $0.hasSuffix(".mp4") || $0.hasSuffix(".mov") }
                debugLog("   - Video files in bundle: \(videoFiles)")
            }
            
            debugLog("⚠️ Stuck guide video not found. Placeholder image will be shown.")
            return
        }
        
        debugLog("✅ Found stuck guide video at: \(url.path)")
        
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let queuePlayer = AVQueuePlayer()
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        
        queuePlayer.isMuted = isStuckVideoMuted
        queuePlayer.automaticallyWaitsToMinimizeStalling = false
        
        stuckGuideVideoPlayer = queuePlayer
        stuckGuideVideoLooper = looper
        
        debugLog("✅ Stuck guide video player created")
        
        Task {
            let duration = try? await asset.load(.duration)
            await MainActor.run {
                if let duration = duration {
                    stuckVideoDuration = duration.seconds
                    debugLog("📹 Stuck guide video duration: \(stuckVideoDuration) seconds")
                }
            }
        }
        
        startStuckVideoProgressTracking()
        queuePlayer.play()
        isStuckVideoPaused = false
        debugLog("▶️ Stuck guide video started")
    }
    
    private func startStuckVideoProgressTracking() {
        stuckVideoProgressTimer?.invalidate()
        stuckVideoProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = self.stuckGuideVideoPlayer else { return }
            let currentTime = CMTimeGetSeconds(player.currentTime())
            let duration = self.stuckVideoDuration > 0 ? self.stuckVideoDuration : CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
            
            if duration > 0 {
                var progress = currentTime / duration
                if progress >= 1.0 {
                    progress = 0.0
                }
                self.stuckVideoProgress = min(max(progress, 0), 1)
            }
        }
    }
    
    private func stopStuckVideoProgressTracking() {
        stuckVideoProgressTimer?.invalidate()
        stuckVideoProgressTimer = nil
    }
    
    private func seekStuckVideo(by seconds: Double) {
        guard let player = stuckGuideVideoPlayer else { return }
        
        let currentTime = player.currentTime()
        let currentSeconds = CMTimeGetSeconds(currentTime)
        let newSeconds = max(0, currentSeconds + seconds)
        let newTime = CMTime(seconds: newSeconds, preferredTimescale: currentTime.timescale)
        
        player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
        
        debugLog("⏩ Stuck guide seeked by \(seconds) seconds to \(newSeconds)s")
    }
    
    private func toggleStuckVideoMute() {
        guard let player = stuckGuideVideoPlayer else { return }
        isStuckVideoMuted.toggle()
        player.isMuted = isStuckVideoMuted
        debugLog(isStuckVideoMuted ? "🔇 Stuck guide muted" : "🔊 Stuck guide unmuted")
    }
    
    private func pauseStuckVideo() {
        guard let player = stuckGuideVideoPlayer else { return }
        player.pause()
        isStuckVideoPaused = true
        debugLog("⏸️ Stuck guide paused")
    }
    
    private func resumeStuckVideoIfNeeded(forcePlay: Bool = false) {
        guard let player = stuckGuideVideoPlayer else { return }
        guard forcePlay || !showTroubleshootingTextVersion else { return }
        player.play()
        isStuckVideoPaused = false
        // Ensure progress tracking is running
        if stuckVideoProgressTimer == nil || !stuckVideoProgressTimer!.isValid {
            startStuckVideoProgressTracking()
        }
        debugLog("▶️ Stuck guide resumed")
    }
    
    private func stopStuckVideoPlayback() {
        if let player = stuckGuideVideoPlayer {
            player.pause()
            player.seek(to: .zero)
        }
        isStuckVideoPaused = true
        stopStuckVideoProgressTracking()
    }
    
    /// Ensures the stuck video is playing and progress is being tracked.
    /// Call this when returning to the troubleshooting modal.
    private func ensureStuckVideoPlaying() {
        guard let player = stuckGuideVideoPlayer else { return }
        
        // Restart progress tracking if not running
        if stuckVideoProgressTimer == nil || !stuckVideoProgressTimer!.isValid {
            startStuckVideoProgressTracking()
            debugLog("📊 Stuck video progress tracking restarted")
        }
        
        // Ensure video is playing if not paused and not in text version
        if player.rate == 0 && !isStuckVideoPaused && !showTroubleshootingTextVersion {
            player.play()
            debugLog("▶️ Stuck video resumed (ensureStuckVideoPlaying)")
        }
    }
    
    private func saveOnboardingNotes() {
        guard !onboardingNotes.isEmpty else { return }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(onboardingNotes)
            savedNotesData = data
            print("✅ Saved \(onboardingNotes.count) notes from onboarding")
        } catch {
            print("❌ Failed to save onboarding notes: \(error)")
        }
    }

    private func finalizeWallpaperSetup(shouldLaunchShortcut: Bool = false) {
        // Allow wallpaper generation if we are on chooseWallpapers step
        // We removed the isLaunchingShortcut guard because we want to save without launching now
        guard currentPage == .chooseWallpapers else {
            debugLog("⚠️ Onboarding: finalizeWallpaperSetup called but not in correct context")
            return
        }
        
        debugLog("✅ Onboarding: Finalizing wallpaper setup from step 5")
        
        // Generate wallpaper directly
        
        // 1. Resolve background color
        let backgroundOption = LockScreenBackgroundOption(rawValue: lockScreenBackgroundRaw) ?? .default
        let backgroundColor = backgroundOption.uiColor
        
        // 2. Resolve background image
        var backgroundImage: UIImage? = nil
        let backgroundMode = LockScreenBackgroundMode(rawValue: lockScreenBackgroundModeRaw) ?? .default
        
        if backgroundMode == .photo {
            if !lockScreenBackgroundPhotoData.isEmpty, let image = UIImage(data: lockScreenBackgroundPhotoData) {
                backgroundImage = image
            }
        }
        
        // 3. Generate wallpaper
        debugLog("🎨 Onboarding: Generating wallpaper with \(onboardingNotes.count) notes")
        let lockScreenImage = WallpaperRenderer.generateWallpaper(
            from: onboardingNotes,
            backgroundColor: backgroundColor,
            backgroundImage: backgroundImage,
            hasLockScreenWidgets: hasLockScreenWidgets
        )
        
        // 4. Save to file system
        do {
            try HomeScreenImageManager.saveLockScreenWallpaper(lockScreenImage)
            debugLog("✅ Onboarding: Saved generated wallpaper to file system")
            
            // 5. Trigger shortcut launch ONLY if requested
            if shouldLaunchShortcut {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.didTriggerShortcutRun = true
                self.openShortcutToApplyWallpaper()
                }
            }
        } catch {
            debugLog("❌ Onboarding: Failed to save generated wallpaper: \(error)")
            // Only show error if we were trying to launch
            if shouldLaunchShortcut {
            handleWallpaperVerificationFailure()
            }
        }
    }

    private func completeShortcutLaunch() {
        shortcutLaunchFallback?.cancel()
        shortcutLaunchFallback = nil
        wallpaperVerificationTask?.cancel()
        wallpaperVerificationTask = nil
        guard isLaunchingShortcut else { 
            return 
        }
        isLaunchingShortcut = false
        didTriggerShortcutRun = false
        if currentPage == .chooseWallpapers {
            currentPage = .welcome
        }
    }
    
    private func requestAppReviewIfNeeded() {
        #if DEBUG
        // In DEBUG builds, always show review for testing (ignore the "already shown" flag)
        print("🌟 DEBUG: Requesting app review (DEBUG mode - always showing)")
        #else
        // In production, only request review once
        guard !hasRequestedAppReview else {
            return
        }
        #endif
        
        hasRequestedAppReview = true
        #if DEBUG
        print("🌟 Requesting app review after onboarding completion")
        #endif
        
        // Small delay to let the onboarding dismissal complete smoothly and arrive at home screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            #if DEBUG
            print("🌟 Triggering SKStoreReviewController.requestReview()")
            #endif
            if let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                // SKStoreReviewController.requestReview(in: windowScene) // DISABLED - Duplicate
                #if DEBUG
                print("🌟 Review request sent to window scene")
                #endif
            } else {
                #if DEBUG
                print("🌟 No active window scene found")
                #endif
            }
        }
    }

    private func handleWallpaperGenerationFinished() {
        guard isLaunchingShortcut, currentPage == .chooseWallpapers, !didTriggerShortcutRun else { 
            return 
        }
        didTriggerShortcutRun = true
        openShortcutToApplyWallpaper()
    }

    private func openShortcutToApplyWallpaper() {
        wallpaperVerificationTask?.cancel()
        wallpaperVerificationTask = Task {
            let filesReady = await waitForWallpaperFilesReady()
            
            if Task.isCancelled {
                return
            }
            
            if filesReady {
                launchShortcutAfterVerification()
            } else {
                handleWallpaperVerificationFailure()
            }
        }
    }

    private func waitForWallpaperFilesReady(maxWait: TimeInterval = 6.0, pollInterval: TimeInterval = 0.25) async -> Bool {
        let deadline = Date().addingTimeInterval(maxWait)
        while Date() < deadline {
            if Task.isCancelled {
                return false
            }

            if areWallpaperFilesReady() {
                return true
            }

            let jitter = Double.random(in: 0...0.05)
            let delay = pollInterval + jitter
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        return areWallpaperFilesReady()
    }

    private func areWallpaperFilesReady() -> Bool {
        guard
            let lockURL = HomeScreenImageManager.lockScreenWallpaperURL()
        else {
            return false
        }
        return isReadableNonZeroFile(at: lockURL)
    }

    private func isReadableNonZeroFile(at url: URL) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path),
              fileManager.isReadableFile(atPath: url.path) else {
            return false
        }

        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? NSNumber else {
            return false
        }
        return fileSize.intValue > 0
    }

    @MainActor
    private func handleWallpaperVerificationFailure() {
        debugLog("❌ Onboarding: Wallpaper file verification failed or timed out")
        wallpaperVerificationTask = nil
        didTriggerShortcutRun = false
        isLaunchingShortcut = false
        lockScreenBackgroundStatusMessage = "We couldn’t prepare the wallpaper files. Tap “Save Lock Screen” again."
        lockScreenBackgroundStatusColor = .red
    }

    @MainActor
    private func launchShortcutAfterVerification() {
        wallpaperVerificationTask = nil

        guard areWallpaperFilesReady() else {
            handleWallpaperVerificationFailure()
            return
        }

        debugLog("✅ Onboarding: Wallpaper files verified, opening shortcut")

        let shortcutName = "set wallpaper photo"
        let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "shortcuts://run-shortcut?name=\(encodedName)"
        guard let url = URL(string: urlString) else {
            debugLog("❌ Onboarding: Failed to create shortcut URL")
            handleWallpaperVerificationFailure()
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                debugLog("⚠️ Onboarding: Shortcut URL open returned false")
                DispatchQueue.main.async {
                    self.didTriggerShortcutRun = false
                    self.isLaunchingShortcut = false
                }
            }
        }
    }
    
    private func runShortcutForPermissions() {
        debugLog("🚀 Onboarding: Running shortcut for permissions step")
        
        let shortcutName = "set wallpaper photo"
        let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "shortcuts://run-shortcut?name=\(encodedName)"
        guard let url = URL(string: urlString) else {
            debugLog("❌ Onboarding: Failed to create shortcut URL for permissions")
            return
        }
        
        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                debugLog("✅ Onboarding: Successfully opened shortcut for permissions")
            } else {
                debugLog("⚠️ Onboarding: Failed to open shortcut for permissions")
            }
        }
    }
    
    private func saveInstructionWallpaperToPhotos() {
        debugLog("💾 Onboarding: Saving instruction wallpaper to Photos")
        
        guard let instructionImage = UIImage(named: "InstructionWallpaper") else {
            debugLog("❌ Onboarding: Failed to load instruction wallpaper image")
            return
        }
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                debugLog("❌ Onboarding: Photos permission not granted")
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: instructionImage.jpegData(compressionQuality: 1.0)!, options: nil)
            }) { success, error in
                if success {
                    debugLog("✅ Onboarding: Instruction wallpaper saved to Photos")
                } else if let error = error {
                    debugLog("❌ Onboarding: Failed to save instruction wallpaper: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Help Button & Support
    
    /// Floating help button with glowy outline (performance optimized)
    private var helpButton: some View {
        Button(action: {
            // Medium haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            showHelpSheet = true
        }) {
            ZStack {
                // Background blur/material for visibility over scrolling content
                if #available(iOS 15.0, *) {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 48, height: 48)
                        )
                } else {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 48, height: 48)
                }
                
                // Simple pulsing ring (performance optimized)
                Circle()
                    .strokeBorder(
                        Color.appAccent.opacity(pulseAnimation ? 0.5 : 0.3),
                        lineWidth: pulseAnimation ? 2 : 1.5
                    )
                    .frame(width: 48, height: 48)
                    .shadow(
                        color: Color.appAccent.opacity(pulseAnimation ? 0.8 : 0.4),
                        radius: pulseAnimation ? 16 : 10,
                        x: 0,
                        y: 0
                    )
                
                // Accent background circle (on top of blur)
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                // Icon
                Image(systemName: "headphones")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.appAccent)
            }
            .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 4)
        }
        .onAppear {
            // Simple pulsing glow animation
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
    
    /// Compact help button for overview step (smaller, positioned in grey corner)
    private var compactHelpButton: some View {
        Button(action: {
            // Medium haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            showHelpSheet = true
        }) {
            ZStack {
                // Background blur/material for visibility over scrolling content
                if #available(iOS 15.0, *) {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 36, height: 36)
                        )
                } else {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 36, height: 36)
                }
                
                // Simple pulsing ring (performance optimized)
                Circle()
                    .strokeBorder(
                        Color.appAccent.opacity(pulseAnimation ? 0.5 : 0.3),
                        lineWidth: pulseAnimation ? 1.5 : 1
                    )
                    .frame(width: 36, height: 36)
                    .shadow(
                        color: Color.appAccent.opacity(pulseAnimation ? 0.7 : 0.4),
                        radius: pulseAnimation ? 10 : 6,
                        x: 0,
                        y: 0
                    )
                
                // Accent background circle (on top of blur)
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                // Icon (smaller)
                Image(systemName: "headphones")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appAccent)
            }
            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 3)
        }
        .onAppear {
            // Simple pulsing glow animation
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
    
    @State private var pulseAnimation = false
    
    /// Help options sheet with 3 support channels
    private var helpOptionsSheet: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Need Help?")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("We're here to assist you")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // If on overview page, complete onboarding instead of just closing
                        if currentPage == .overview {
                            showHelpSheet = false
                            completeOnboarding()
                        } else {
                            showHelpSheet = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                
                // Support options
                VStack(spacing: 16) {
                    // 1. WhatsApp (Primary)
                    supportOptionCard(
                        icon: "message.fill",
                        title: "Chat on WhatsApp",
                        subtitle: "Get instant help",
                        accentColor: Color(red: 0.15, green: 0.78, blue: 0.40), // WhatsApp green
                        isPrimary: true
                    ) {
                        openWhatsApp()
                    }
                    
                    // 2. Email Feedback
                    supportOptionCard(
                        icon: "envelope.fill",
                        title: "Get Help via Email",
                        subtitle: "We're here to help you",
                        accentColor: .blue
                    ) {
                        openEmailFeedback()
                    }
                    
                    // 3. In-app Improvement
                    supportOptionCard(
                        icon: "lightbulb.fill",
                        title: "Suggest Improvements",
                        subtitle: "Help us make NoteWall better",
                        accentColor: Color(red: 0.61, green: 0.35, blue: 0.71) // Purple
                    ) {
                        showHelpSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showImprovementForm = true
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Footer note
                Text("Current step: \(currentPageName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 40)
            }
        }
    }
    
    /// Support option card component
    private func supportOptionCard(
        icon: String,
        title: String,
        subtitle: String,
        accentColor: Color,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            // Light haptic
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(isPrimary ? 0.08 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isPrimary ? accentColor.opacity(0.3) : Color.white.opacity(0.1),
                                lineWidth: isPrimary ? 1.5 : 1
                            )
                    )
            )
            .shadow(color: isPrimary ? accentColor.opacity(0.2) : .clear, radius: isPrimary ? 12 : 0, x: 0, y: isPrimary ? 6 : 0)
        }
        .buttonStyle(.plain)
    }
    
    /// In-app improvement suggestions form (redesigned for performance)
    private var improvementFormSheet: some View {
        NavigationView {
            ZStack {
                // Dark gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color.black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss keyboard smoothly when tapping background
                    if isImprovementFieldFocused {
                        withAnimation(.easeOut(duration: 0.25)) {
                            isImprovementFieldFocused = false
                        }
                    }
                }
                
                if showImprovementSuccess {
                    // Success state
                    VStack(spacing: 24) {
                        Group {
                            if #available(iOS 17.0, *) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(Color("AppAccent"))
                                    .symbolEffect(.bounce, value: showImprovementSuccess)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(Color("AppAccent"))
                            }
                        }
                        
                        Text("Thank You!")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Your suggestion has been sent")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Input form with ScrollView for better keyboard handling
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header
                            VStack(alignment: .leading, spacing: 8) {
                                Text("What could we improve?")
                                    .font(.system(.title2, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("Your feedback helps us make NoteWall better for everyone.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                            
                            // Text editor container
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your suggestion")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                ZStack(alignment: .topLeading) {
                                    // Background
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(
                                                    isImprovementFieldFocused ? Color("AppAccent").opacity(0.5) : Color.white.opacity(0.1),
                                                    lineWidth: isImprovementFieldFocused ? 2 : 1
                                                )
                                        )
                                        .frame(height: 180)
                                    
                                    // Text editor
                                    if #available(iOS 16.0, *) {
                                        TextEditor(text: $improvementText)
                                            .focused($isImprovementFieldFocused)
                                            .scrollContentBackground(.hidden)
                                            .frame(height: 180)
                                            .padding(12)
                                            .foregroundColor(.white)
                                            .font(.body)
                                    } else {
                                        TextEditor(text: $improvementText)
                                            .focused($isImprovementFieldFocused)
                                            .frame(height: 180)
                                            .padding(12)
                                            .foregroundColor(.white)
                                            .font(.body)
                                            .background(Color.clear)
                                    }
                                    
                                    // Placeholder
                                    if improvementText.isEmpty {
                                        Text("Share your ideas, suggestions, or feedback...")
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 20)
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                            
                            // Character count (optional, for better UX)
                            HStack {
                                Spacer()
                                Text("\(improvementText.count) characters")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Send button
                            Button(action: {
                                sendImprovementFeedback()
                            }) {
                                HStack(spacing: 12) {
                                    if isSendingImprovement {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                    }
                                    Text(isSendingImprovement ? NSLocalizedString("Sending...", comment: "") : NSLocalizedString("Send Suggestion", comment: ""))
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(
                                            improvementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingImprovement
                                                ? Color.gray.opacity(0.3)
                                                : Color("AppAccent")
                                        )
                                )
                                .shadow(
                                    color: (improvementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingImprovement)
                                        ? .clear
                                        : Color("AppAccent").opacity(0.4),
                                    radius: 16,
                                    x: 0,
                                    y: 8
                                )
                            }
                            .disabled(improvementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingImprovement)
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    }
                    .scrollDismissesKeyboardIfAvailable()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Dismiss keyboard smoothly when tapping outside text field
                        if isImprovementFieldFocused {
                            withAnimation(.easeOut(duration: 0.25)) {
                                isImprovementFieldFocused = false
                            }
                        }
                    }
                }
            }
            .navigationTitle("Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        // Dismiss keyboard first
                        isImprovementFieldFocused = false
                        // Then close after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showImprovementForm = false
                            improvementText = ""
                            showImprovementSuccess = false
                            isSendingImprovement = false
                        }
                    }
                    .foregroundColor(Color("AppAccent"))
                }
            }
        }
    }
    
    // MARK: - Support Actions
    
    /// Opens WhatsApp with pre-filled message
    private func openWhatsApp() {
        let message = """
        Hi! I need help with NoteWall onboarding.
        
        I'm stuck on step: \(currentPageName)
        
        \(getDeviceInfo())
        """
        
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let whatsappURL = "https://wa.me/\(whatsappNumber)?text=\(encodedMessage)"
        
        guard let url = URL(string: whatsappURL) else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url) { success in
                if !success {
                    // WhatsApp didn't open, show fallback
                    DispatchQueue.main.async {
                        helpAlertMessage = "WhatsApp could not be opened. Would you like to send an email instead?"
                        showHelpAlert = true
                    }
                }
            }
            showHelpSheet = false
        } else {
            // WhatsApp not installed
            helpAlertMessage = "WhatsApp is not installed. Please send us an email at \(supportEmail)"
            showHelpAlert = true
        }
    }
    
    /// Opens email app with pre-filled feedback
    private func openEmailFeedback() {
        let subject = "NoteWall Feedback - \(currentPageName)"
        let body = """
        
        
        ---
        Current Step: \(currentPageName)
        \(getDeviceInfo())
        ---
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoURL = "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)"
        
        guard let url = URL(string: mailtoURL) else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            showHelpSheet = false
        } else {
            // Email not configured
            helpAlertMessage = "Email is not configured on your device. Our support email is: \(supportEmail)"
            showHelpAlert = true
        }
    }
    
    /// Sends improvement suggestion via email service
    private func sendImprovementFeedback() {
        guard !improvementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isSendingImprovement else { return }
        
        // Medium haptic for send action
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Show loading state immediately
        isSendingImprovement = true
        
        // Hide keyboard first with smooth animation
        withAnimation(.easeOut(duration: 0.25)) {
            isImprovementFieldFocused = false
        }
        
        // Wait for keyboard to fully dismiss before proceeding (keyboard animation takes ~0.5 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let details = """
            User Suggestion:
            \(self.improvementText)
            
            ---
            Context:
            Current Step: \(self.currentPageName)
            \(self.getDeviceInfo())
            """
            
            // Use FeedbackService to send the suggestion
            FeedbackService.shared.sendFeedback(
                reason: "Onboarding Improvement Suggestion",
                details: details,
                isPremium: self.paywallManager.isPremium
            ) { success, error in
                DispatchQueue.main.async {
                    self.isSendingImprovement = false
                    
                    if success {
                        // Keyboard should be fully dismissed by now, show success animation
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            self.showImprovementSuccess = true
                        }
                        
                        // Success haptic
                        let notification = UINotificationFeedbackGenerator()
                        notification.notificationOccurred(.success)
                        
                        // Auto-dismiss after showing success
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.showImprovementForm = false
                            self.improvementText = ""
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.showImprovementSuccess = false
                            }
                        }
                    } else {
                        // Fallback to email if service fails
                        self.openEmailFeedback()
                        self.showImprovementForm = false
                    }
                }
            }
        }
    }
    
    /// Gets device and app information
    private func getDeviceInfo() -> String {
        let device = UIDevice.current.model
        let osVersion = UIDevice.current.systemVersion
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        return "Device: \(device), iOS: \(osVersion), App: v\(appVersion)"
    }
    
    /// Creates underlined text compatible with all iOS versions
    @available(iOS 15.0, *)
    private func createUnderlinedText(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        attributedString.underlineStyle = .single
        return attributedString
    }
    
    /// Returns human-readable name for current onboarding page
    private var currentPageName: String {
        switch currentPage {
        case .preOnboardingHook:
            return "Pre-Onboarding Hook"
        case .nameInput:
            return "Name Input"
        case .notificationPermission:
            return "Notification Permission"
        case .painPoint:
            return "Why This Matters"
        case .quizForgetMost:
            return "Quick Quiz"
        case .quizPhoneChecks:
            return "Quick Quiz"
        case .quizDistraction:
            return "Quick Quiz"
        case .personalizationLoading:
             return "Loading"
        case .resultsPreview:
             return "Your Profile"
        case .resultsInsight:
             return "Insights"

        case .socialProof:
            return "What Others Say"
        case .reviewPage:
            return "Reviews"
        case .setupIntro:
            return "Setup Introduction"
        case .welcome:
            return "Welcome"
        case .installShortcut:
            return "Install Shortcut"
        case .shortcutSuccess:
            return "Shortcut Installed"
        case .addNotes:
            return "Add Notes"
        case .chooseWallpapers:
            return "Choose Wallpapers"
        case .allowPermissions:
            return "Allow Permissions"
        case .setupComplete:
            return "Setup Complete"
        case .overview:
            return "Overview"
        }
    }
    
    private func openWallpaperSettings() {
        debugLog("📱 Onboarding: Opening Photos app to Library tab")
        
        // iOS 18.1+ broke App-prefs:Wallpaper URL scheme - it no longer works.
        // Solution: Open Photos app to Library tab (all photos grid view) using reverse-engineered URL scheme.
        // The user's NoteWall wallpaper will be at the top (most recent) since it was just saved.
        
        // This opens Photos directly to Library tab showing all photos in grid view
        // NOT the Albums view - much better UX!
        if let photosURL = URL(string: "photos-navigation://contentmode?id=photos") {
            UIApplication.shared.open(photosURL) { success in
                if success {
                    debugLog("✅ Onboarding: Successfully opened Photos app to Library tab")
                    self.userWentToSettings = true
                    self.showTroubleshooting = false
                    self.showTroubleshootingTextVersion = false
                } else {
                    // Fallback: Try basic Photos redirect
                    debugLog("⚠️ Onboarding: contentmode URL failed, trying photos-redirect")
                    if let photosRedirectURL = URL(string: "photos-redirect://") {
                        UIApplication.shared.open(photosRedirectURL) { redirectSuccess in
                            if redirectSuccess {
                                debugLog("✅ Onboarding: Successfully opened Photos app")
                                self.userWentToSettings = true
                                self.showTroubleshooting = false
                                self.showTroubleshootingTextVersion = false
                            } else {
                                // Final fallback: Open Settings app
                                debugLog("⚠️ Onboarding: Photos app failed, opening Settings as fallback")
                                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsURL) { _ in
                                        self.userWentToSettings = true
                                        self.showTroubleshooting = false
                                        self.showTroubleshootingTextVersion = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // Fallback: Open Settings app
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL) { _ in
                    self.userWentToSettings = true
                    self.showTroubleshooting = false
                    self.showTroubleshootingTextVersion = false
                }
            }
        }
    }

    // MARK: - Step 2 Text Version Helper Components
    
    private struct Step3HeroIcon: View {
        @State private var animateRings = false
        @State private var floatingOffset: CGFloat = 0
        
        var body: some View {
            ZStack {
                // Animated rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                        .frame(width: 140 + CGFloat(i) * 35, height: 140 + CGFloat(i) * 35)
                        .scaleEffect(animateRings ? 1.1 : 1.0)
                        .opacity(animateRings ? 0.3 : 0.6)
                        .animation(
                            Animation.easeInOut(duration: 2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.2),
                            value: animateRings
                        )
                }
                
                // Main icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent.opacity(0.25), Color.appAccent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(.appAccent)
                        .shadow(color: Color.appAccent.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .offset(y: floatingOffset)
            }
            .onAppear {
                DispatchQueue.main.async {
                    withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        animateRings = true
                    }
                    withAnimation(Animation.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                        floatingOffset = -8
                    }
                }
            }
        }
    }
    
    private struct InstallationCheckHeroIcon: View {
        @State private var animateRings = false
        @State private var floatingOffset: CGFloat = 0
        
        var body: some View {
            ZStack {
                // Animated rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                        .frame(width: 130 + CGFloat(i) * 30, height: 130 + CGFloat(i) * 30)
                        .scaleEffect(animateRings ? 1.1 : 1.0)
                        .opacity(animateRings ? 0.3 : 0.6)
                        .animation(
                            Animation.easeInOut(duration: 2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.2),
                            value: animateRings
                        )
                }
                
                // Main icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent.opacity(0.25), Color.appAccent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(.appAccent)
                        .shadow(color: Color.appAccent.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .offset(y: floatingOffset)
            }
            .onAppear {
                DispatchQueue.main.async {
                    withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        animateRings = true
                    }
                    withAnimation(Animation.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                        floatingOffset = -8
                    }
                }
            }
        }
    }
    
    private struct BrandCard<Content: View>: View {
        let content: Content
        
        init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.appAccent.opacity(0.25), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)
        }
    }
}

private extension OnboardingView {
    enum ProgressIndicatorDisplayMode {
        case large
        case compact
    }

    @ViewBuilder
    func progressIndicatorItem(for page: OnboardingPage, displayMode: ProgressIndicatorDisplayMode) -> some View {
        // Get step number (1-6), excluding preOnboardingHook and overview
        if let position = page.stepNumber {
            // Compare using step numbers for proper ordering
            let currentStepNumber = currentPage.stepNumber ?? 0
            let pageStepNumber = page.stepNumber ?? 0
            let isCurrent = currentPage == page
            let isComplete = currentStepNumber > pageStepNumber
            let isClickable = pageStepNumber < currentStepNumber // Can navigate back to previous steps

            let circleFill: Color = {
                if isCurrent || isComplete {
                    return Color.appAccent  // Cyan for current and completed
                } else {
                    return Color(.systemGray5)  // Light gray for future steps
                }
            }()

            let circleTextColor: Color = isCurrent || isComplete ? .white : Color(.secondaryLabel)

            // Calculate values based on display mode (computed before ViewBuilder context)
            let (circleSize, circleShadowOpacity, circleStrokeOpacity, circleStrokeWidth, circleFontSize, circleFontDesign): (CGFloat, Double, Double, CGFloat, CGFloat, Font.Design) = {
                switch displayMode {
                case .large:
                    return (38, isCurrent ? 0.18 : 0.0, isCurrent ? 0.25 : 0.15, isCurrent ? 1.5 : 1, 16, .rounded)
                case .compact:
                    return (40, 0.0, isCurrent ? 0.28 : 0.18, 1, 18, .rounded)
                }
            }()

            ZStack {
                Circle()
                    .fill(circleFill)
                .frame(width: circleSize, height: circleSize)
                .shadow(color: Color.black.opacity(circleShadowOpacity), radius: isCurrent ? 10 : 0, x: 0, y: isCurrent ? 6 : 0)
                    .overlay(
                        Circle()
                        .strokeBorder(Color.white.opacity(circleStrokeOpacity), lineWidth: circleStrokeWidth)
                    )

                // Always show numbers (no checkmarks)
                Text("\(position)")
                    .font(.system(size: circleFontSize, weight: .semibold, design: circleFontDesign))
                    .foregroundColor(circleTextColor)
            }
            .opacity(isClickable ? 1.0 : 0.6) // Slightly dim future steps to show they're not clickable
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(position)")
            .accessibilityValue(isComplete ? "Complete, tap to go back" : (isCurrent ? "Current step" : "Not started"))
        } else {
            // Return empty view for preOnboardingHook and overview (they don't have step numbers)
            EmptyView()
        }
    }

    private var overviewHeroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.appAccent.opacity(0.28),
                            Color.appAccent.opacity(0.12),
                            Color(.systemBackground)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 16) {
                Text("Ready to Go")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("You’ve got everything set up. Keep these quick highlights in mind as you start using NoteWall.")
                    .font(.callout)
                    .foregroundColor(.secondary)

                HStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(Color.appAccent)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("What’s next?")
                            .font(.headline)
                        Text("Add notes, update the wallpaper, and let NoteWall keep your lock screen awesome.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
        .accessibilityElement(children: .combine)
    }

    private func overviewInfoCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.appAccent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 8)
        )
    }

    private var overviewAutomationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Pro tip: make it automatic")
                    .font(.headline)
            } icon: {
                Image(systemName: "bolt.badge.clock")
                    .foregroundColor(Color.appAccent)
            }

            Text("Create a Shortcuts automation so NoteWall runs on your schedule, like at the start of a workday or when a Focus mode activates.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                overviewAutomationRow("Trigger it every morning before you leave for the day.")
                overviewAutomationRow("Pair it with a Focus mode to keep your lock screen current throughout the week.")
                overviewAutomationRow("Use a personal automation when you arrive at the office or start a commute.")
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.appAccent.opacity(0.10), lineWidth: 1)
        )
    }

    private func overviewAutomationRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.caption)
                .foregroundColor(Color.appAccent)
                .accessibilityHidden(true)

            Text(text)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}

struct OnboardingPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    private var cornerRadius: CGFloat {
        ScreenDimensions.isCompactDevice ? 14 : 20
    }

    func makeBody(configuration: Configuration) -> some View {
        let colors = buttonColors(isPressed: configuration.isPressed)

        return configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: colors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.18 : 0.08), lineWidth: 1)
            )
            .shadow(
                color: Color.appAccent.opacity(isEnabled ? (configuration.isPressed ? 0.16 : 0.28) : 0.08),
                radius: configuration.isPressed ? 8 : 16,
                x: 0,
                y: configuration.isPressed ? 4 : 12
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.75)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }

    private func buttonColors(isPressed: Bool) -> [Color] {
        if isEnabled {
            let top = Color.appAccent.opacity(isPressed ? 0.95 : 1.0)
            let bottom = Color.appAccent.opacity(isPressed ? 0.82 : 0.9)
            return [top, bottom]
        } else {
            return [
                Color(.systemGray4),
                Color(.systemGray5)
            ]
        }
    }
}

private extension OnboardingPage {
    var navigationTitle: String {
        switch self {
        case .preOnboardingHook:
            return ""
        case .nameInput:
            return ""
        case .notificationPermission:
            return ""
        case .painPoint:
            return ""
        case .quizForgetMost, .quizPhoneChecks, .quizDistraction:
            return ""
        case .personalizationLoading:
            return ""
        case .resultsPreview:
            return ""
        case .resultsInsight:
            return ""
        case .socialProof:
            return ""
        case .reviewPage:
            return ""
        case .setupIntro:
            return ""
        case .welcome:
            return "Welcome"
        case .addNotes:
            return "Add Notes"
        case .chooseWallpapers:
            return "Choose Wallpapers"
        case .installShortcut:
            return "Install Shortcut"
        case .shortcutSuccess:
            return ""
        case .allowPermissions:
            return "Allow Permissions"
        case .setupComplete:
            return ""
        case .overview:
            return "All Set"
        }
    }

    var progressTitle: String {
        switch self {
        case .preOnboardingHook:
            return "Pre-Onboarding Hook"
        case .nameInput:
            return "Your Name"
        case .notificationPermission:
            return "Notifications"
        case .painPoint:
            return "Understanding You"
        case .quizForgetMost, .quizPhoneChecks, .quizDistraction:
            return "Personalization"
        case .personalizationLoading:
            return "Customizing"
        case .resultsPreview:
            return "Your Profile"
        case .resultsInsight:
            return "Insights"
        case .socialProof:
            return "Community"
        case .reviewPage:
            return "Reviews"
        case .setupIntro:
            return "Setup Preview"
        case .welcome:
            return "Welcome"
        case .addNotes:
            return "Add Notes"
        case .chooseWallpapers:
            return "Choose Wallpapers"
        case .installShortcut:
            return "Install Shortcut"
        case .shortcutSuccess:
            return "Success"
        case .allowPermissions:
            return "Allow Permissions"
        case .setupComplete:
            return "Complete"
        case .overview:
            return "All Set"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .preOnboardingHook:
            return "Pre-Onboarding"
        case .nameInput:
            return "Enter your name"
        case .notificationPermission:
            return "Notification Permission"
        case .painPoint:
            return "Understanding your needs"
        case .quizForgetMost:
            return "Quiz question 1"
        case .quizPhoneChecks:
            return "Quiz question 2"
        case .quizDistraction:
            return "Quiz question 3"
        case .personalizationLoading:
            return "Customizing your experience"
        case .resultsPreview:
            return "Your personalized results"
        case .resultsInsight:
            return "Insights"
        case .socialProof:
            return "Community proof"
        case .reviewPage:
            return "User reviews"
        case .setupIntro:
            return "Setup introduction"
        case .welcome:
            return "Step 1"
        case .installShortcut:
            return "Step 2"
        case .shortcutSuccess:
            return "Shortcut installed"
        case .addNotes:
            return "Step 3"
        case .chooseWallpapers:
            return "Step 4"
        case .allowPermissions:
            return "Step 5"
        case .setupComplete:
            return "Setup complete"
        case .overview:
            return "All Set"
        }
    }
    
    // Returns the step number (1-6) for display in the step counter
    // Only technical setup steps show step numbers
    var stepNumber: Int? {
        switch self {
        case .preOnboardingHook, .nameInput, .painPoint, .quizForgetMost, .quizPhoneChecks, .quizDistraction,
             .personalizationLoading, .resultsPreview, .resultsInsight, .socialProof, .notificationPermission, .reviewPage, .setupIntro, .shortcutSuccess, .setupComplete, .overview:
            return nil // These don't show step numbers
        case .welcome:
            return 1
        case .installShortcut:
            return 2
        case .addNotes:
            return 3
        case .chooseWallpapers:
            return 4
        case .allowPermissions:
            return 5
        }
    }
    
    // Phase for progress indicator
    var phase: String {
        switch self {
        case .preOnboardingHook, .nameInput, .painPoint, .quizForgetMost, .quizPhoneChecks, .quizDistraction, .personalizationLoading, .resultsPreview, .resultsInsight:
            return "Getting to Know You"
        case .socialProof, .notificationPermission, .setupIntro:
            return "Almost Ready"
        case .welcome, .installShortcut, .shortcutSuccess, .addNotes, .chooseWallpapers, .allowPermissions:
            return "Setup"
        case .setupComplete, .reviewPage, .overview:
            return "Complete"
        }
    }
    
    // Whether this page shows the compact progress indicator
    var showsProgressIndicator: Bool {
        switch self {
        case .preOnboardingHook, .nameInput, .painPoint, .quizForgetMost, .quizPhoneChecks, .quizDistraction,
             .personalizationLoading, .resultsPreview, .resultsInsight, .socialProof, .notificationPermission, .reviewPage, .setupIntro, .shortcutSuccess, .setupComplete, .overview:
            return false
        case .welcome, .installShortcut, .addNotes, .chooseWallpapers, .allowPermissions:
            return true
        }
    }
}

#if !os(macOS)
private extension View {
    @ViewBuilder
    func onboardingNavigationBarBackground() -> some View {
        if #available(iOS 16.0, *) {
            self
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbarBackground(.hidden, for: .automatic)
        } else {
            self
        }
    }
}
#endif

#if !os(macOS)
private extension View {
    @ViewBuilder
    func scrollAlwaysBounceIfAvailable() -> some View {
        if #available(iOS 16.4, *) {
            self.scrollBounceBehavior(.always)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func scrollDismissesKeyboardIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}
#endif

// MARK: - Loading Placeholder

private struct LoadingPlaceholder: View {
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray5))
            .frame(height: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 400 : -400)
            )
            .clipped()
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Looping Video Player View
private struct LoopingVideoPlayerView: UIViewRepresentable {
    let player: AVQueuePlayer
    let playbackRate: Float
    
    func makeCoordinator() -> Coordinator {
        Coordinator(player: player, playbackRate: playbackRate)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = VideoPlayerContainerView()
        view.backgroundColor = .black
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = view.bounds // Set initial frame
        view.playerLayer = playerLayer
        view.layer.addSublayer(playerLayer)
        
        // Store coordinator
        context.coordinator.containerView = view
        context.coordinator.playerLayer = playerLayer
        
        // Set up frame and playback
        DispatchQueue.main.async {
            playerLayer.frame = view.bounds
            
            // Check if item is already ready and play immediately
            if let currentItem = player.currentItem {
                if currentItem.status == .readyToPlay && player.rate == 0 {
                    // Item is ready, play immediately
                    player.playImmediately(atRate: playbackRate)
                    print("✅ LoopingVideoPlayerView: Started playing immediately (item already ready)")
                } else if currentItem.status != .readyToPlay {
                    // Item not ready yet, set up observer
                    let coordinator = context.coordinator
                    coordinator.statusObserver?.invalidate()
                    let statusObserver = currentItem.observe(\.status, options: [.new]) { [weak player, weak coordinator] item, _ in
                        guard let player = player, let coordinator = coordinator else { return }
                        DispatchQueue.main.async {
                            if item.status == .readyToPlay && player.rate == 0 {
                                if let containerView = coordinator.containerView,
                                   let layer = containerView.playerLayer {
                                    layer.frame = containerView.bounds
                                }
                                player.playImmediately(atRate: playbackRate)
                                print("✅ LoopingVideoPlayerView: Started playing after item became ready")
                            }
                        }
                    }
                    coordinator.statusObserver = statusObserver
                }
            } else {
                // No current item, try to play anyway (looper should handle it)
                if player.rate == 0 {
                    player.playImmediately(atRate: playbackRate)
                    print("✅ LoopingVideoPlayerView: Started playing (no item check)")
                }
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let containerView = uiView as? VideoPlayerContainerView,
              let playerLayer = containerView.playerLayer else {
            return
        }
        
        // Only update frame - don't try to play here, let allowPermissionsStep handle playback
        let newFrame = uiView.bounds
        if playerLayer.frame != newFrame {
            playerLayer.frame = newFrame
        }
    }
    
    class Coordinator {
        let player: AVQueuePlayer
        let playbackRate: Float
        weak var containerView: VideoPlayerContainerView?
        weak var playerLayer: AVPlayerLayer?
        var statusObserver: NSKeyValueObservation?
        
        init(player: AVQueuePlayer, playbackRate: Float) {
            self.player = player
            self.playbackRate = playbackRate
        }
        
        deinit {
            statusObserver?.invalidate()
        }
    }
}

private class VideoPlayerContainerView: UIView {
    var playerLayer: AVPlayerLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure player layer frame matches bounds after layout
        if let playerLayer = playerLayer {
            let newFrame = bounds
            if playerLayer.frame != newFrame {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                playerLayer.frame = newFrame
                CATransaction.commit()
            }
        }
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        // When view is added to window, ensure player layer frame is set
        if window != nil, let playerLayer = playerLayer {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                playerLayer.frame = self.bounds
            }
        }
    }
}

// MARK: - Non-Interactive Video Player View (no controls, no interactions)
private struct NonInteractiveVideoPlayerView: UIViewRepresentable {
    let player: AVQueuePlayer
    let playbackRate: Float
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        
        // Store layer in coordinator for frame updates
        context.coordinator.playerLayer = playerLayer
        
        // Set up frame and playback
        DispatchQueue.main.async {
            playerLayer.frame = view.bounds
            
            // Start playback when ready
            if let currentItem = player.currentItem {
                if currentItem.status == .readyToPlay && player.rate == 0 {
                    player.playImmediately(atRate: playbackRate)
                } else if currentItem.status != .readyToPlay {
                    // Wait for item to be ready
                    let statusObserver = currentItem.observe(\.status, options: [.new]) { [weak player] item, _ in
                        guard let player = player else { return }
                        DispatchQueue.main.async {
                            if item.status == .readyToPlay && player.rate == 0 {
                                player.playImmediately(atRate: playbackRate)
                            }
                        }
                    }
                    context.coordinator.statusObserver = statusObserver
                }
            } else {
                if player.rate == 0 {
                    player.playImmediately(atRate: playbackRate)
                }
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let playerLayer = context.coordinator.playerLayer else {
            return
        }
        
        // Update frame to match view bounds
        let newFrame = uiView.bounds
        if playerLayer.frame != newFrame {
            playerLayer.frame = newFrame
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var playerLayer: AVPlayerLayer?
        var statusObserver: NSKeyValueObservation?
        
        deinit {
            statusObserver?.invalidate()
        }
    }
}

// MARK: - Animated Checkmark View
private struct AnimatedCheckmarkView: View {
    @State private var isAnimating = false
    @State private var showCheckmark = false
    @State private var scale: CGFloat = 0.5
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.appAccent)
                .frame(width: 120, height: 120)
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))
                .shadow(color: Color.appAccent.opacity(0.3), radius: 20, x: 0, y: 10)
            
            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.white)
                .opacity(showCheckmark ? 1 : 0)
                .scaleEffect(showCheckmark ? 1 : 0.3)
        }
        .onAppear {
            performAnimation()
        }
    }
    
    private func performAnimation() {
        // Play haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.prepare()
        
        // Play system sound (success sound)
        AudioServicesPlaySystemSound(1519) // Success sound
        
        // Animate the circle
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
            scale = 1.0
            rotation = 360
        }
        
        // Trigger haptic after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            impactFeedback.impactOccurred()
        }
        
        // Show checkmark with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showCheckmark = true
            }
            
            // Second haptic for checkmark appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let lightFeedback = UIImpactFeedbackGenerator(style: .light)
                lightFeedback.impactOccurred()
            }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true), onboardingVersion: 2)
}

private extension OnboardingView {
    private func advanceAfterShortcutInstallIfNeeded() {
        // This method is no longer needed - navigation is handled directly in onChange
        // Keeping it for backwards compatibility but it shouldn't be called
    }
}

// MARK: - Animated Word Component

struct AnimatedWord: View {
    let text: String
    let isVisible: Bool
    let delay: Double
    var isAccent: Bool = false
    
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0
    @State private var yOffset: CGFloat = 20
    
    var body: some View {
        Text(text)
            .foregroundStyle(
                isAccent ?
                LinearGradient(
                    colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                ) :
                LinearGradient(
                    colors: [.white.opacity(0.7), .white.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: isAccent ? Color.appAccent.opacity(0.5) : .clear, radius: 10, x: 0, y: 0)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: yOffset)
            .onChange(of: isVisible) { _, visible in
                if visible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            scale = 1.0
                            opacity = 1.0
                            yOffset = 0
                        }
                    }
                }
            }
    }
}

// MARK: - Floating Ambient Particles

struct FloatingParticlesView: View {
    @State private var particles: [FloatingParticle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [particle.color.opacity(0.6), particle.color.opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: particle.size / 2
                            )
                        )
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .blur(radius: particle.blur)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
                animateParticles(in: geometry.size)
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        particles = (0..<25).map { _ in
            FloatingParticle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 4...20),
                color: [Color.appAccent, .white, Color.appAccent.opacity(0.5)].randomElement()!,
                blur: CGFloat.random(in: 0...3),
                speed: Double.random(in: 3...8)
            )
        }
    }
    
    private func animateParticles(in size: CGSize) {
        for i in particles.indices {
            let particle = particles[i]
            withAnimation(
                .easeInOut(duration: particle.speed)
                .repeatForever(autoreverses: true)
            ) {
                particles[i].y = CGFloat.random(in: 0...size.height)
                particles[i].x = particle.x + CGFloat.random(in: -50...50)
            }
        }
    }
}

struct FloatingParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let color: Color
    let blur: CGFloat
    let speed: Double
}

// MARK: - Countdown Burst Effect

struct CountdownBurstView: View {
    @State private var particles: [BurstParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: particle.offsetX, y: particle.offsetY)
                    .opacity(particle.opacity)
                    .blur(radius: 1)
            }
        }
        .onAppear {
            createBurst()
        }
    }
    
    private func createBurst() {
        particles = (0..<16).map { i in
            let angle = Double(i) * (360.0 / 16.0) * .pi / 180.0
            return BurstParticle(
                angle: angle,
                size: CGFloat.random(in: 4...8),
                color: [Color.appAccent, .white, Color.appAccent.opacity(0.7)].randomElement()!
            )
        }
        
        // Animate burst outward
        for i in particles.indices {
            let angle = particles[i].angle
            let distance: CGFloat = CGFloat.random(in: 60...100)
            
            withAnimation(.easeOut(duration: 0.4)) {
                particles[i].offsetX = cos(angle) * distance
                particles[i].offsetY = sin(angle) * distance
                particles[i].opacity = 0
            }
        }
    }
}

struct BurstParticle: Identifiable {
    let id = UUID()
    let angle: Double
    let size: CGFloat
    let color: Color
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0
    var opacity: Double = 1
}

// (Duplicate ConfettiView removed; use ConfettiView in OnboardingEnhanced.swift)

// MARK: - Auto-Playing Looping Video Player

struct AutoPlayingLoopingVideoPlayer: UIViewRepresentable {
    let player: AVQueuePlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)
        
        // Store player layer in context for updates
        context.coordinator.playerLayer = playerLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = context.coordinator.playerLayer {
            // Update frame when view bounds change
            DispatchQueue.main.async {
                playerLayer.frame = uiView.bounds
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var playerLayer: AVPlayerLayer?
    }
}

// MARK: - Review Page View

// Particle data structure for floating dots
private struct ReviewParticleData {
    let opacity: Double
    let size: CGFloat
    let x: Double  // 0.0 to 1.0 (relative position)
    let y: Double  // 0.0 to 1.0 (relative position)
    let duration: Double
    let delay: Double
}

struct ReviewModel: Identifiable {
    let id = UUID()
    let name: String
    let username: String
    let text: String
    let rating: Int
    let initial: String
    let color: Color
}

struct ReviewPageView: View {
    let onContinue: () -> Void
    
    // MARK: - Animation States
    @State private var scrollOffset1: CGFloat = 0
    @State private var scrollOffset2: CGFloat = 0
    @State private var isAnimating = false
    
    // MARK: - Floating Particles (Optimized for smooth animation)
    @State private var particleData: [ReviewParticleData] = []
    @State private var particleAnimationTime: Double = 0
    private let particleAnimationTimer = Timer.publish(every: 0.033, on: .main, in: .common).autoconnect() // ~30fps for smooth animation
    
    // Adaptive layout
    private var isCompact: Bool {
        return ScreenDimensions.height < 750
    }
    
    // Fixed user count: 2,855 (formatted with space)
    private var formattedUserCount: String {
        return "2 855"
    }
    
    // NoteWall-specific reviews - Row 1
    private let reviews1: [ReviewModel] = [
        ReviewModel(name: "Sarah Jenkins", username: "@sarahj_92", text: "Love seeing my notes on my lock screen! It's like having a personal reminder that's always there.", rating: 5, initial: "S", color: .purple),
        ReviewModel(name: "Michael Chen", username: "@mchen_dev", text: "The wallpaper feature is genius. I actually remember my tasks now because they're right on my phone.", rating: 5, initial: "M", color: .blue),
        ReviewModel(name: "Jessica Lee", username: "@jesslee", text: "Simple and effective. My lock screen keeps me focused on what matters. Game changer!", rating: 5, initial: "J", color: .pink)
    ]
    
    // NoteWall-specific reviews - Row 2 (will be blurred)
    private let reviews2: [ReviewModel] = [
        ReviewModel(name: "David Miller", username: "@dmiller", text: "Finally stopped forgetting important things. The shortcut setup was easy and it just works!", rating: 5, initial: "D", color: .orange),
        ReviewModel(name: "Emily Wilson", username: "@emilyw", text: "Best productivity app I've tried. Seeing my goals every time I unlock my phone keeps me motivated.", rating: 5, initial: "E", color: .green),
        ReviewModel(name: "Alex Thompson", username: "@alex_t", text: "The custom wallpaper with notes is brilliant. No more sticky notes everywhere - it's all on my phone!", rating: 5, initial: "A", color: .teal)
    ]
    
    var body: some View {
        ZStack {
            // Paywall-style background
            paywallBackground
                .ignoresSafeArea()
            
            // Floating particles
            floatingParticles
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: isCompact ? 20 : 40)
                        
                        // Header Image (FaithWall Logo)
                        Image("FAITHWALL")
                            .resizable()
                            .scaledToFit()
                            .frame(height: isCompact ? 120 : 160)
                            .padding(.bottom, 10)
                        
                        // Subtitle
                        Text("This app was designed for people like you...")
                            .font(.system(size: isCompact ? 16 : 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        // User Count Section (Avatars + Text)
                        HStack(spacing: 12) {
                            HStack(spacing: -12) {
                                ForEach(["image-3-review", "image-2-review", "image-1-review"], id: \.self) { imageName in
                                    Image(imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 36, height: 36)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.appAccent, lineWidth: 2)
                                        )
                                }
                            }
                            
                            Text("+\(formattedUserCount) people")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, isCompact ? 20 : 30)
                        
                        // Reviews Marquee (Scrolling Review Cards) - Optimized for smooth scrolling
                        VStack(spacing: 16) {
                            // Row 1: Right to Left
                            ReviewMarqueeRow(reviews: reviews1, direction: .rightToLeft, speed: 30)
                            
                            // Row 2: Left to Right (Uniform blur with opacity)
                            ReviewMarqueeRow(reviews: reviews2, direction: .leftToRight, speed: 35)
                                .blur(radius: 0.25)
                                .opacity(0.70)
                        }
                        .frame(height: 280)
                        .drawingGroup() // Optimize entire marquee section as one layer for smooth scrolling
                        .mask(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: 0.1),
                                    .init(color: .black, location: 0.9),
                                    .init(color: .clear, location: 1)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        
                        Spacer(minLength: 40)
                    }
                }
                
                // Bottom Button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onContinue()
                }) {
                    Text("Next")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .cornerRadius(30)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, isCompact ? 20 : 40)
            }
        }
        .onAppear {
            // Initialize particles if needed (optimized count for smooth animation)
            if particleData.isEmpty {
                particleData = (0..<10).map { _ in
                    ReviewParticleData(
                        opacity: Double.random(in: 0.15...0.35),
                        size: CGFloat.random(in: 3...7),
                        x: Double.random(in: 0...1),
                        y: Double.random(in: 0...1),
                        duration: Double.random(in: 4...6),
                        delay: Double.random(in: 0...3)
                    )
                }
            }
            
            // Request App Store review popup with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                }
            }
        }
        .onReceive(particleAnimationTimer) { _ in
            // Smooth continuous animation - increment matches timer interval for consistent speed
            particleAnimationTime += 0.033
        }
    }
    
    // Floating particles (dots) - optimized for smooth animation
    private var floatingParticles: some View {
        GeometryReader { geo in
            ForEach(particleData.indices, id: \.self) { i in
                let particle = particleData[i]
                // Calculate smooth animation phase with proper wrapping
                let totalCycle = particle.duration * 2
                let currentTime = particleAnimationTime + particle.delay
                let wrappedTime = currentTime.truncatingRemainder(dividingBy: totalCycle)
                let normalizedPhase = wrappedTime / totalCycle
                
                // Use smooth sine wave for natural floating motion
                let offset = sin(normalizedPhase * .pi * 2) * 20
                
                Circle()
                    .fill(Color.appAccent.opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .offset(
                        x: particle.x * geo.size.width,
                        y: particle.y * geo.size.height + offset
                    )
            }
        }
        .compositingGroup() // First composite particles
        .drawingGroup() // Then render as single layer for maximum performance
        .allowsHitTesting(false)
        .zIndex(0) // Behind content
    }
    
    // Paywall-style background matching PaywallView
    private var paywallBackground: some View {
        ZStack {
            // Base dark gradient - matching paywall
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.12),
                    Color(red: 0.02, green: 0.02, blue: 0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Accent glow orbs - matching paywall
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: -100, y: -200)
                .blur(radius: 60)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.2), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: 150, y: 300)
                .blur(radius: 50)
            
            // Subtle noise texture overlay for depth
            Rectangle()
                .fill(Color.white.opacity(0.02))
        }
        .compositingGroup() // Optimize background composition
    }
}

// MARK: - Review Marquee Row (Horizontal Scrolling)

struct ReviewMarqueeRow: View {
    let reviews: [ReviewModel]
    let direction: MarqueeDirection
    let speed: Double
    
    enum MarqueeDirection {
        case leftToRight
        case rightToLeft
    }
    
    private let cardWidth: CGFloat = 280
    private let spacing: CGFloat = 16
    
    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geometry in
                let contentWidth = CGFloat(reviews.count) * (cardWidth + spacing)
                let duration = speed
                let time = timeline.date.timeIntervalSinceReferenceDate
                let progress = (time / duration).truncatingRemainder(dividingBy: 1.0)
                let currentOffset = contentWidth * progress
                
                let xOffset: CGFloat = direction == .rightToLeft ? -currentOffset : -contentWidth + currentOffset
                
                HStack(spacing: spacing) {
                    // Repeat 20 times to create seamless infinite scroll
                    ForEach(0..<20) { _ in 
                        ForEach(reviews) { review in
                            ReviewCard(review: review)
                        }
                    }
                }
                .offset(x: xOffset)
            }
        }
        .frame(height: 130)
        .clipped() // Clip to bounds for better performance
        .drawingGroup() // Render as single layer for smooth scrolling
    }
}

// MARK: - Review Card (Individual Review Display)

struct ReviewCard: View {
    let review: ReviewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                // Avatar Circle
                Circle()
                    .fill(review.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(review.initial)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(review.color)
                    )
                
                // Name & Username
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(review.username)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                // 5 Stars
                HStack(spacing: 2) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            // Review Text
            Text(review.text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 40, alignment: .topLeading)
        }
        .padding(16)
        .frame(width: 280, height: 130)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
