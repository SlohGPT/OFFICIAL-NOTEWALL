import SwiftUI
import PhotosUI
import UIKit
import QuartzCore
import AVKit
import AVFoundation
import AudioToolbox
import StoreKit

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

private enum OnboardingPage: Int, CaseIterable, Hashable {
    case welcome
    case installShortcut
    case addNotes
    case chooseWallpapers
    case allowPermissions
    case overview
}

struct OnboardingView: View {
    @Binding var isPresented: Bool
    let onboardingVersion: Int
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @AppStorage("completedOnboardingVersion") private var completedOnboardingVersion = 0
    @AppStorage("shouldShowTroubleshootingBanner") private var shouldShowTroubleshootingBanner = false
    @AppStorage("lockScreenBackground") private var lockScreenBackgroundRaw = LockScreenBackgroundOption.default.rawValue
    @AppStorage("lockScreenBackgroundMode") private var lockScreenBackgroundModeRaw = LockScreenBackgroundMode.default.rawValue
    @AppStorage("lockScreenBackgroundPhotoData") private var lockScreenBackgroundPhotoData: Data = Data()

    @AppStorage("homeScreenPresetSelection") private var homeScreenPresetSelectionRaw = ""
    @AppStorage("homeScreenUsesCustomPhoto") private var homeScreenUsesCustomPhoto = false
    @AppStorage("savedNotes") private var savedNotesData: Data = Data()
    @AppStorage("saveWallpapersToPhotos") private var saveWallpapersToPhotos = false
    @AppStorage("autoUpdateWallpaperAfterDeletion") private var autoUpdateWallpaperAfterDeletionRaw: String = ""
    @AppStorage("hasShownAutoUpdatePrompt") private var hasShownAutoUpdatePrompt = false
    @AppStorage("hasRequestedAppReview") private var hasRequestedAppReview = false
    @AppStorage("hasLockScreenWidgets") private var hasLockScreenWidgets = true
    @State private var didOpenShortcut = false
    @State private var isSavingHomeScreenPhoto = false
    @State private var homeScreenStatusMessage: String?
    @State private var homeScreenStatusColor: Color = .gray
    @State private var isSavingLockScreenBackground = false
    @State private var lockScreenBackgroundStatusMessage: String?
    @State private var lockScreenBackgroundStatusColor: Color = .gray

    @State private var currentPage: OnboardingPage = .welcome
    @State private var isLaunchingShortcut = false
    @State private var shortcutLaunchFallback: DispatchWorkItem?
    @State private var wallpaperVerificationTask: Task<Void, Never>?
    @State private var didTriggerShortcutRun = false
    @State private var isLoadingWallpaperStep = false
    @State private var demoVideoPlayer: AVQueuePlayer?
    @State private var demoVideoLooper: AVPlayerLooper?
    @State private var notificationsVideoPlayer: AVQueuePlayer?
    @State private var notificationsVideoLooper: AVPlayerLooper?
    @StateObject private var pipVideoPlayerManager = PIPVideoPlayerManager()
    @State private var shouldStartPiP = false
    private let demoVideoPlaybackRate: Float = 1.5
    
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
    @StateObject private var paywallManager = PaywallManager.shared
    
    // Final step mockup preview
    @State private var showMockupPreview = false
    @State private var loadedWallpaperImage: UIImage?
    @State private var useLightMockup: Bool = true
    
    // Transition animation from step 5 to step 6
    @State private var showTransitionScreen = false
    @State private var countdownNumber: Int = 3
    @State private var showConfetti = false
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

    private let shortcutURL = "https://www.icloud.com/shortcuts/37aa5bd3a1274af1b502c8eeda60fbf7"

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                navigationStackOnboarding
            } else {
                navigationViewOnboarding
            }
        }
        .interactiveDismissDisabled()
        .background {
            // Player layer for PiP - positioned behind content but technically on-screen
            // iOS requires the layer to be in the view hierarchy and not hidden/0-alpha
            // Using .background ensures it's behind main content but still rendered
            if shouldStartPiP {
                GeometryReader { geometry in
                    HiddenPiPPlayerLayerView(playerManager: pipVideoPlayerManager)
                        .frame(width: 320, height: 568)
                        // Position at bottom-right, mostly off-screen but 1 pixel visible
                        .position(
                            x: geometry.size.width - 1,
                            y: geometry.size.height - 1
                        )
                        .allowsHitTesting(false)
                }
            }
        }
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
        }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutWallpaperApplied)) { _ in
            completeShortcutLaunch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .wallpaperGenerationFinished)) { _ in
            handleWallpaperGenerationFinished()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                debugLog("📱 Onboarding: App became active, currentPage: \(currentPage), didOpenShortcut: \(didOpenShortcut)")
                // Stop PiP when returning to app
                if pipVideoPlayerManager.isPiPActive {
                    pipVideoPlayerManager.stopPictureInPicture()
                    pipVideoPlayerManager.stop()
                }
                shouldStartPiP = false
                
                // Handle return from Shortcuts app after installing shortcut
                // Only advance if we're still on the install shortcut step and shortcut was opened
                if currentPage == .installShortcut && didOpenShortcut {
                    debugLog("📱 Onboarding: Detected return from Shortcuts app, navigating to add notes step immediately")
                    // Navigate immediately - no delay needed
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.currentPage = .addNotes
                    }
                    self.didOpenShortcut = false
                    debugLog("✅ Onboarding: Now on page: \(self.currentPage)")
                }
                // Only complete shortcut launch if we're on the chooseWallpapers step
                if currentPage == .chooseWallpapers {
                    completeShortcutLaunch()
                }
            } else if newPhase == .background {
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
        .onChange(of: currentPage) { page in
            if page == .chooseWallpapers {
                HomeScreenImageManager.prepareStorageStructure()
            }
        }
        .onChange(of: shouldRestartOnboarding) { shouldRestart in
            if shouldRestart {
                // Reset to first page and restart onboarding
                withAnimation {
                    currentPage = .welcome
                }
                shouldRestartOnboarding = false
            }
        }
        .sheet(isPresented: $showPostOnboardingPaywall) {
            PaywallView(triggerReason: .firstWallpaperCreated, allowDismiss: true)
                .onDisappear {
                    // AFTER paywall is dismissed, NOW complete the setup
                    // This prevents the onboarding from being dismissed prematurely
                    hasCompletedSetup = true
                    completedOnboardingVersion = onboardingVersion
                    
                    // Show review popup
                    requestAppReviewIfNeeded()
                    
                    // Small delay before dismissing onboarding to let review popup appear
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isPresented = false
                    }
                }
        }
        .preferredColorScheme(.dark)
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
            VStack(spacing: 0) {
                // Progress indicator - hidden on overview step and during transition
                if !hideProgressIndicator && !showTransitionScreen && currentPage != .overview {
                    onboardingProgressIndicatorCompact
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            Color(.systemBackground)
                                .ignoresSafeArea()
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                ZStack {
                    // Solid background to prevent seeing underlying content during transitions
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    
                    Group {
                        switch currentPage {
                        case .welcome:
                            welcomeStep()
                        case .installShortcut:
                            installShortcutStep()
                        case .addNotes:
                            addNotesStep()
                        case .chooseWallpapers:
                            chooseWallpapersStep(includePhotoPicker: includePhotoPicker)
                        case .allowPermissions:
                            allowPermissionsStep()
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

                // Hide button during transition
                if !showTransitionScreen {
                    primaryButtonSection
                }
            }
            .opacity(showTransitionScreen ? 0 : 1)
            
            // Transition screen overlay
            if showTransitionScreen {
                transitionCountdownView
                    .transition(.opacity)
            }
            
            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.4), value: hideProgressIndicator)
        .animation(.easeInOut(duration: 0.3), value: showTransitionScreen)
    }

    private var onboardingProgressIndicatorCompact: some View {
        HStack(alignment: .center, spacing: 12) {
            ForEach(OnboardingPage.allCases, id: \.self) { page in
                progressIndicatorItem(for: page, displayMode: .compact)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("\(currentPage.accessibilityLabel) of \(OnboardingPage.allCases.count)")
    }

    private var primaryButtonSection: some View {
        VStack(spacing: 12) {
            Button(action: handlePrimaryButton) {
                HStack(spacing: 12) {
                    if currentPage == .chooseWallpapers && isLaunchingShortcut {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .tint(.white)
                    } else if let iconName = primaryButtonIconName {
                        Image(systemName: iconName)
                            .font(.system(size: 20, weight: .semibold))
                    }

                    Text(primaryButtonTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(height: 56)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: primaryButtonEnabled))
            .disabled(!primaryButtonEnabled)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }

    private func welcomeStep() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 28) {
                VStack(spacing: 16) {
                    Image("OnboardingLogo")
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFit()
                        .frame(width: 110, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
                        .accessibilityHidden(true)
                    
                    Text("Welcome to NoteWall")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    VStack(spacing: 8) {
                        Text("You forget things for one simple reason: you don't see them. NoteWall fixes that.")
                            .font(.system(.title3))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                    }
                    .padding(.horizontal, 12)
                }
                
                VStack(spacing: 16) {
                    welcomeHighlightCard(
                        title: "Turn Every Pickup Into Focus",
                        subtitle: "You pick up your phone up to 498× per day. Now each one becomes a reminder of what matters.",
                        icon: "bolt.fill"
                    )
                    
                    welcomeHighlightCard(
                        title: "Keep Your Goals Always in Sight",
                        subtitle: "Your lock screen becomes a visual cue you can't ignore.",
                        icon: "target"
                    )
                    
                    welcomeHighlightCard(
                        title: "Beat Scrolling Before It Starts",
                        subtitle: "See your goals before TikTok, Instagram, or distractions.",
                        icon: "stop.fill"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.vertical, 36)
        }
        .scrollAlwaysBounceIfAvailable()
    }
    
    private func welcomeHighlightCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.appAccent)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
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
    
    private func installShortcutStep() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 60, weight: .semibold))
                        .foregroundColor(.appAccent)
                        .padding(.top, 8)
                    
                    Text("Install the Shortcut")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("This takes 40 seconds. A video guide will help you.")
                        .font(.system(.title3))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                
                VStack(spacing: 14) {
                    installShortcutInfoCard(
                        title: "Add the Shortcut",
                        subtitle: "Tap 'Add Shortcut' in the Shortcuts app.",
                        icon: "plus.circle.fill"
                    )
                    
                    installShortcutInfoCard(
                        title: "Choose Your Current Wallpaper",
                        subtitle: "Select the wallpaper you're using RIGHT NOW. This is the one you want to replace with notes.",
                        icon: "photo.fill",
                        highlightedText: "Current Wallpaper"
                    )
                    
                    installShortcutInfoCard(
                        title: "Follow the Video",
                        subtitle: "A Picture-in-Picture video will show you exactly what to do.",
                        icon: "play.rectangle.fill"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.vertical, 36)
        }
        .scrollAlwaysBounceIfAvailable()
        .onAppear {
            // Prepare PiP video when this step appears
            preparePiPVideo()
            // Preload/prepare the next step (addNotes) for instant transition
            // This ensures the view is ready when user returns from Shortcuts app
        }
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
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Add Your First Notes")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                    
                    Text("These notes will appear on your lock screen wallpaper")
                        .font(.system(.title3))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 16) {
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
                            .padding(16)
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
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .id("inputField")
                        
                        if onboardingNotes.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary.opacity(0.5))
                                
                                Text("Add at least one note to continue")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 32)
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
        return onboardingNotes.firstIndex(where: { $0.id == note.id }) ?? 0
    }

    private func allowPermissionsStep() -> some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                Text("Allow 4 Permissions")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                
                Text("Click \"Allow\" for exactly 4 permissions")
                    .font(.system(.title3))
                    .foregroundColor(.appAccent)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 8)
                    .padding(.horizontal, 24)
                    .zIndex(10)
                
                notificationsVideoSection(minHeight: proxy.size.height - 200)
                    .padding(.horizontal, 16)
                    .padding(.top, -30)
                    .zIndex(1)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            // Prepare video player (may already be preloaded from step 3)
            prepareNotificationsVideoPlayerIfNeeded()
        }
    }

    @ViewBuilder
    private func chooseWallpapersStep(includePhotoPicker: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Choose Your Wallpapers")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Edit Notes button to go back to step 2
                    Button(action: {
                        // Light impact haptic for edit notes button
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage = .addNotes
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Edit Notes")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.appAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.appAccent.opacity(0.1))
                        )
                    }
                }

                if includePhotoPicker {
                    if #available(iOS 16.0, *) {
                        if isLoadingWallpaperStep {
                            VStack(spacing: 16) {
                                LoadingPlaceholder()
                                LoadingPlaceholder()
                                LoadingPlaceholder()
                            }
                            .transition(.opacity)
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                HomeScreenPhotoPickerView(
                                    isSavingHomeScreenPhoto: $isSavingHomeScreenPhoto,
                                    homeScreenStatusMessage: $homeScreenStatusMessage,
                                    homeScreenStatusColor: $homeScreenStatusColor,
                                    homeScreenImageAvailable: Binding(
                                        get: { homeScreenUsesCustomPhoto },
                                        set: { homeScreenUsesCustomPhoto = $0 }
                                    ),
                                    handlePickedHomeScreenData: handlePickedHomeScreenData
                                )

                                HomeScreenQuickPresetsView(
                                    isSavingHomeScreenPhoto: $isSavingHomeScreenPhoto,
                                    homeScreenStatusMessage: $homeScreenStatusMessage,
                                    homeScreenStatusColor: $homeScreenStatusColor,
                                    homeScreenImageAvailable: Binding(
                                        get: { homeScreenUsesCustomPhoto },
                                        set: { homeScreenUsesCustomPhoto = $0 }
                                    ),
                                    handlePickedHomeScreenData: handlePickedHomeScreenData
                                )

                                if let message = homeScreenStatusMessage {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(homeScreenStatusColor)
                                }
                                
                                Divider()
                                    .padding(.vertical, 12)

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
                                    .padding(.top, 24)
                            }
                            .transition(.opacity)
                        }
                    }
                } else {
                        Text("Update to iOS 16+ to pick a photo directly. For now, the shortcut will reuse your current home screen wallpaper.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 32)
        }
        .onAppear(perform: ensureCustomPhotoFlagIsAccurate)
        .scrollAlwaysBounceIfAvailable()
    }
    
    private var lockScreenWidgetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Clear heading
            VStack(alignment: .leading, spacing: 4) {
                Text("Do you use lock screen widgets?")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("This adjusts where your notes appear on the lock screen")
                    .font(.caption)
                    .foregroundColor(Color(.systemGray2))
            }
            
            // Option buttons
            HStack(spacing: 12) {
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
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
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
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemGray6).opacity(0.3))
        )
    }

    private func overviewStep() -> some View {
        // iPhone mockup preview - large and prominent, fills the screen
        iPhoneMockupPreview
            .opacity(showMockupPreview ? 1 : 0)
            .scaleEffect(showMockupPreview ? 1 : 0.95)
            .animation(.easeOut(duration: 0.5), value: showMockupPreview)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadWallpaperForPreview()
            // Trigger fade-in animation after a slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation {
                    showMockupPreview = true
                }
            }
        }
        .onDisappear {
            // Reset animation state for when user navigates back
            showMockupPreview = false
        }
    }
    
    // MARK: - Transition Countdown View (Epic Version)
    
    private var transitionCountdownView: some View {
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
                VStack(spacing: 12) {
                    // "Ready for your new"
                    HStack(spacing: 8) {
                        AnimatedWord(text: "Ready", isVisible: word1Visible, delay: 0)
                        AnimatedWord(text: "for", isVisible: word1Visible, delay: 0.1)
                        AnimatedWord(text: "your", isVisible: word1Visible, delay: 0.2)
                        AnimatedWord(text: "new", isVisible: word1Visible, delay: 0.3)
                    }
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    
                    // "PRODUCTIVITY HACK"
                    HStack(spacing: 8) {
                        AnimatedWord(text: "PRODUCTIVITY", isVisible: word2Visible, delay: 0, isAccent: true)
                        AnimatedWord(text: "HACK", isVisible: word2Visible, delay: 0.15, isAccent: true)
                        AnimatedWord(text: "?", isVisible: word2Visible, delay: 0.25, isAccent: true)
                    }
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    
                    // "You'll never forget again"
                    HStack(spacing: 5) {
                        AnimatedWord(text: "So", isVisible: word3Visible, delay: 0)
                        AnimatedWord(text: "you'll", isVisible: word3Visible, delay: 0.08)
                        AnimatedWord(text: "never", isVisible: word3Visible, delay: 0.16)
                        AnimatedWord(text: "forget", isVisible: word3Visible, delay: 0.24)
                        AnimatedWord(text: "again", isVisible: word3Visible, delay: 0.32)
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 8)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                
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
                            lineWidth: 3
                        )
                        .frame(width: 200, height: 200)
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
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .opacity(countdownOpacity)
                    
                    // Inner glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.appAccent.opacity(0.2), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 90
                            )
                        )
                        .frame(width: 180, height: 180)
                        .opacity(countdownGlow)
                    
                    // Countdown number with effects
                    Text("\(countdownNumber)")
                        .font(.system(size: 100, weight: .black, design: .rounded))
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
                .frame(width: 220, height: 220)
                
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
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                gradientRotation = 360
            }
        }
    }
    
    private func startTransitionCountdown() {
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
        let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
        
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
            }
            
            // Transition to overview
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showTransitionScreen = false
                currentPage = .overview
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
            // iPhone mockup aspect ratio is approximately 1:2.16 (width:height)
            let mockupAspectRatio: CGFloat = 1 / 2.16
            
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
            // 🔧 ADJUST ZOOM: Change .scaleEffect(0.85) on line ~1352
            //    - 0.85 = Current (85% size - zoomed out to show all content)
            //    - 1.0 = No zoom (100% - may crop edges)
            //    - 0.75 = More zoom out (75% - shows more but smaller)
            //    - 0.9 = Less zoom out (90% - closer to edges)
            
            ZStack {
                // Wallpaper layer (behind the mockup) - TRUE 1:1 size, no cropping
                ZStack {
                    if let wallpaper = loadedWallpaperImage {
                        Image(uiImage: wallpaper)
                            .resizable()
                            .aspectRatio(contentMode: .fit) // ✅ Maintains aspect ratio, shows full image
                            .frame(maxWidth: screenWidth, maxHeight: screenHeight)
                            .scaleEffect(0.75) // 🔍 Zoom out to 85% to show all content without cropping
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
                Image(useLightMockup ? "mockup_light" : "mockup_dark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: mockupWidth, height: mockupHeight)
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
        case .welcome:
            return "Next"
        case .overview:
            return "Start Using NoteWall"
        case .chooseWallpapers:
            return isLaunchingShortcut ? "Launching Shortcut…" : "Next"
        case .allowPermissions:
            return "Continue"
        case .installShortcut:
            return didOpenShortcut ? "Next" : "Install"
        case .addNotes:
            return "Continue"
        }
    }

    private var primaryButtonIconName: String? {
        switch currentPage {
        case .welcome:
            return "arrow.right.circle.fill"
        case .overview:
            return "checkmark.circle.fill"
        case .chooseWallpapers:
            return isLaunchingShortcut ? nil : "paintbrush.pointed.fill"
        case .allowPermissions:
            return "checkmark.shield.fill"
        case .installShortcut:
            return "bolt.fill"
        case .addNotes:
            return "arrow.right.circle.fill"
        }
    }

    private var primaryButtonEnabled: Bool {
        switch currentPage {
        case .welcome:
            return true
        case .installShortcut:
            return true
        case .addNotes:
            return !onboardingNotes.isEmpty
        case .allowPermissions:
            return true
        case .chooseWallpapers:
            let hasHomeSelection = homeScreenUsesCustomPhoto || !homeScreenPresetSelectionRaw.isEmpty
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
            return hasHomeSelection && hasLockSelection && hasWidgetSelection && !isSavingHomeScreenPhoto && !isSavingLockScreenBackground && !isLaunchingShortcut
        case .overview:
            return true
        }
    }

    private func handlePrimaryButton() {
        debugLog("🎯 Onboarding: Primary button tapped on page: \(currentPage.progressTitle)")
        
        // Light impact haptic for primary button tap
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Dismiss keyboard before any transition for smooth animation
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        switch currentPage {
        case .welcome:
            advanceStep()
        case .installShortcut:
            if didOpenShortcut {
                // User already tapped "Next" after installing shortcut
                // Navigate to add notes step (this happens if user taps Next before leaving app)
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPage = .addNotes
                    didOpenShortcut = false // Reset flag to prevent double navigation
                }
            } else {
                // Open shortcut installation URL
                installShortcut()
                // Navigation to addNotes will happen automatically when user 
                // returns to app (handled in onChange of scenePhase)
                // The flag didOpenShortcut is set in installShortcut() callback
            }
        case .addNotes:
            // Preload video player when moving to step 3 (so it's ready for step 4)
            prepareNotificationsVideoPlayerIfNeeded()
            // Show loading state
            isLoadingWallpaperStep = true
            // Small delay to let keyboard dismiss and show loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.currentPage = .chooseWallpapers
                }
                // Hide loading after transition completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.isLoadingWallpaperStep = false
                }
            }
        case .chooseWallpapers:
            startShortcutLaunch()
        case .allowPermissions:
            // Start the transition animation with countdown and confetti
            startTransitionCountdown()
        case .overview:
            completeOnboarding()
        }
    }

    private func advanceStep() {
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
                currentPage = .addNotes
            } else if currentPage == .chooseWallpapers && primaryButtonEnabled {
                startShortcutLaunch()
            } else if currentPage == .allowPermissions {
                // Use transition countdown for swipe as well
                startTransitionCountdown()
            }
        }
    }

    private func startShortcutLaunch() {
        // CRITICAL: Only allow shortcut launch from step 4 (chooseWallpapers)
        // This prevents shortcuts from running automatically when onboarding first appears
        guard currentPage == .chooseWallpapers else {
            debugLog("⚠️ Onboarding: startShortcutLaunch called but not on chooseWallpapers step (current: \(currentPage))")
            return
        }
        
        guard !isSavingHomeScreenPhoto, !isSavingLockScreenBackground, !isLaunchingShortcut else { 
            return 
        }
        
        debugLog("✅ Onboarding: Starting shortcut launch from step 4 (chooseWallpapers)")
        
        HomeScreenImageManager.prepareStorageStructure()
        wallpaperVerificationTask?.cancel()
        wallpaperVerificationTask = nil
        
        // Save notes BEFORE generating wallpaper so ContentView can read them
        saveOnboardingNotes()
        
        isLaunchingShortcut = true
        didTriggerShortcutRun = false
        shortcutLaunchFallback?.cancel()

        let fallback = DispatchWorkItem {
            if self.currentPage == .chooseWallpapers {
                if self.isLaunchingShortcut && !self.didTriggerShortcutRun {
                    self.openShortcutToApplyWallpaper()
                }
            }
        }
        shortcutLaunchFallback = fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: fallback)

        finalizeWallpaperSetup()
    }

    private func installShortcut() {
        guard let url = URL(string: shortcutURL) else { return }
        
        // Only prepare PiP video if not already loaded (it's prepared in onAppear of installShortcutStep)
        if !pipVideoPlayerManager.hasLoadedVideo {
        preparePiPVideo()
        }
        shouldStartPiP = true
        
        Task {
            // Wait for player to be ready
            var attempts = 0
            while !pipVideoPlayerManager.isReadyToPlay && attempts < 50 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                attempts += 1
            }
            
            // Wait for PiP controller to be ready
            attempts = 0
            while !pipVideoPlayerManager.isPiPControllerReady && attempts < 50 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                attempts += 1
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
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func preparePiPVideo() {
        // Don't reload if video is already loaded - this prevents resetting the player
        if pipVideoPlayerManager.hasLoadedVideo {
            debugLog("✅ Onboarding: PiP video already loaded, skipping reload")
            return
        }
        
        guard let bundleURL = Bundle.main.url(forResource: "pip-slow-guide-video", withExtension: "mp4") else {
            debugLog("⚠️ Onboarding: PiP demo video not found in bundle")
            return
        }
        
        debugLog("🎬 Onboarding: Preparing PiP video from: \(bundleURL.path)")
        
        // Load the video
        let loaded = pipVideoPlayerManager.loadVideo(url: bundleURL)
        
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
        
        // Show soft paywall after onboarding completion
        // hasCompletedSetup will be set after paywall is dismissed
        // Review popup will be shown after paywall is dismissed
        showPostOnboardingPaywall = true
    }

    

    private func prepareDemoVideoPlayerIfNeeded() {
        guard demoVideoPlayer == nil else { return }
        guard let bundleURL = Bundle.main.url(forResource: "pip-slow-guide-video", withExtension: "mp4") else {
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
                    .allowsHitTesting(false)
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
        guard notificationsVideoPlayer == nil else { 
            print("⚠️ Video player already exists, skipping preparation")
            return 
        }
        
        debugLog("🔍 Onboarding: Preparing notifications video player...")
        
        // Try to find the video file
        guard let bundleURL = Bundle.main.url(forResource: "notifications", withExtension: "mov") else {
            print("❌ CRITICAL: notifications.mov not found in bundle!")
            print("📁 Bundle path: \(Bundle.main.bundlePath)")
            
            // List ALL video files in bundle for debugging
            if let files = try? FileManager.default.contentsOfDirectory(atPath: Bundle.main.bundlePath) {
                let videoFiles = files.filter { $0.hasSuffix(".mov") || $0.hasSuffix(".mp4") }
                print("📁 Video files in bundle: \(videoFiles)")
            }
            return
        }
        
        print("✅ Found notifications.mov at: \(bundleURL.path)")
        
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
        let statusObservation = item.observe(\.status, options: [.new, .initial]) { playerItem, _ in
            DispatchQueue.main.async {
                switch playerItem.status {
                case .readyToPlay:
                    print("✅ notifications.mov player item READY TO PLAY (Allow Permissions step)")
                    print("   - Duration: \(playerItem.duration.seconds) seconds")
                    if let videoTrack = playerItem.asset.tracks(withMediaType: .video).first {
                        print("   - Natural size: \(videoTrack.naturalSize)")
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
        let errorObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { notification in
            print("❌ Playback failed to play to end time")
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("   Error: \(error.localizedDescription)")
            }
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

    private func finalizeWallpaperSetup() {
        // CRITICAL: Only allow wallpaper setup from step 4 (chooseWallpapers) when user explicitly clicks CTA
        // This prevents shortcuts from running automatically when onboarding first appears
        guard currentPage == .chooseWallpapers, isLaunchingShortcut else {
            debugLog("⚠️ Onboarding: finalizeWallpaperSetup called but not in correct context")
            debugLog("   - Current page: \(currentPage)")
            debugLog("   - Is launching shortcut: \(isLaunchingShortcut)")
            return
        }
        
        debugLog("✅ Onboarding: Finalizing wallpaper setup from step 4")
        
        // Don't track onboarding wallpaper for paywall limit
        let request = WallpaperUpdateRequest(skipDeletionPrompt: true, trackForPaywall: false)
        
        // Small delay to ensure ContentView has loaded the notes from savedNotesData
        // The onChange handler needs time to trigger after saveOnboardingNotes()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: .requestWallpaperUpdate, object: request)
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
            currentPage = .allowPermissions
        }
    }
    
    private func requestAppReviewIfNeeded() {
        #if DEBUG
        // In DEBUG builds, always show review for testing (ignore the "already shown" flag)
        print("🌟 DEBUG: Requesting app review (DEBUG mode - always showing)")
        #else
        // In production, only request review once
        guard !hasRequestedAppReview else {
            print("🌟 Review already requested, skipping")
            return
        }
        #endif
        
        hasRequestedAppReview = true
        print("🌟 Requesting app review after onboarding completion")
        
        // Small delay to let the onboarding dismissal complete smoothly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            print("🌟 Triggering SKStoreReviewController.requestReview()")
            if let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
                print("🌟 Review request sent to window scene")
            } else {
                print("🌟 No active window scene found")
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
                await launchShortcutAfterVerification()
            } else {
                await handleWallpaperVerificationFailure()
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
            let homeURL = HomeScreenImageManager.homeScreenImageURL(),
            let lockURL = HomeScreenImageManager.lockScreenWallpaperURL()
        else {
            return false
        }
        return isReadableNonZeroFile(at: homeURL) && isReadableNonZeroFile(at: lockURL)
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
        homeScreenStatusMessage = "We couldn’t prepare the wallpaper files. Tap “Save Lock Screen” again."
        homeScreenStatusColor = .red
    }

    @MainActor
    private func launchShortcutAfterVerification() {
        wallpaperVerificationTask = nil

        guard areWallpaperFilesReady() else {
            handleWallpaperVerificationFailure()
            return
        }

        debugLog("✅ Onboarding: Wallpaper files verified, opening shortcut")

        let shortcutName = "Set NoteWall Wallpaper"
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

    @available(iOS 16.0, *)
    private func handlePickedHomeScreenData(_ data: Data) {
        debugLog("📸 Onboarding: Handling picked home screen data")
        debugLog("   Data size: \(data.count) bytes")
        isSavingHomeScreenPhoto = true
        homeScreenStatusMessage = "Saving photo…"
        homeScreenStatusColor = .gray

        Task {
            do {
                guard let image = UIImage(data: data) else {
                    throw HomeScreenImageManagerError.unableToEncodeImage
                }
                debugLog("   Image size: \(image.size)")
                try HomeScreenImageManager.saveHomeScreenImage(image)
                debugLog("✅ Onboarding: Saved custom home screen photo")
                if let url = HomeScreenImageManager.homeScreenImageURL() {
                    debugLog("   File path: \(url.path)")
                    debugLog("   File exists: \(FileManager.default.fileExists(atPath: url.path))")
                }

                await MainActor.run {
                    homeScreenUsesCustomPhoto = true
                    homeScreenStatusMessage = nil
                    homeScreenStatusColor = .gray
                    homeScreenPresetSelectionRaw = ""
                    debugLog("   homeScreenUsesCustomPhoto set to: true")
                    debugLog("   homeScreenPresetSelectionRaw cleared")
                }
            } catch {
                debugLog("❌ Onboarding: Failed to save home screen photo: \(error)")
                await MainActor.run {
                    homeScreenStatusMessage = error.localizedDescription
                    homeScreenStatusColor = .red
                }
            }

            await MainActor.run {
                isSavingHomeScreenPhoto = false
                isSavingLockScreenBackground = false
            }
        }
    }
}

private extension OnboardingView {
    enum ProgressIndicatorDisplayMode {
        case large
        case compact
    }

    func progressIndicatorItem(for page: OnboardingPage, displayMode: ProgressIndicatorDisplayMode) -> some View {
        let position = page.rawValue + 1
        let isCurrent = currentPage == page
        let isComplete = currentPage.rawValue > page.rawValue

        let circleFill: Color = {
            if isCurrent || isComplete {
                return Color.appAccent  // Cyan for current and completed
            } else {
                return Color(.systemGray5)  // Light gray for future steps
            }
        }()

        let circleTextColor: Color = isCurrent || isComplete ? .white : Color(.secondaryLabel)

        let circleSize: CGFloat
        let circleShadowOpacity: Double
        let circleStrokeOpacity: Double
        let circleStrokeWidth: CGFloat
        let circleFontSize: CGFloat
        let circleFontDesign: Font.Design
        let labelFont: Font
        let labelWeight: Font.Weight
        let vSpacing: CGFloat

        switch displayMode {
        case .large:
            circleSize = 38
            circleShadowOpacity = isCurrent ? 0.18 : 0.0
            circleStrokeOpacity = isCurrent ? 0.25 : 0.15
            circleStrokeWidth = isCurrent ? 1.5 : 1
            circleFontSize = 16
            circleFontDesign = .rounded
            labelFont = .footnote
            labelWeight = isCurrent ? .semibold : .regular
            vSpacing = 8
        case .compact:
            circleSize = 40
            circleShadowOpacity = 0.0
            circleStrokeOpacity = isCurrent ? 0.28 : 0.18
            circleStrokeWidth = 1
            circleFontSize = 18
            circleFontDesign = .rounded
            labelFont = .caption2
            labelWeight = isCurrent ? .semibold : .regular
            vSpacing = 4
        }

        return ZStack {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(position)")
        .accessibilityValue(isComplete ? "Complete" : (isCurrent ? "Current step" : "Not started"))
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

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let colors = buttonColors(isPressed: configuration.isPressed)

        return configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: colors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
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
        case .welcome:
            return "Welcome"
        case .installShortcut:
            return "Install Shortcut"
        case .addNotes:
            return "Add Notes"
        case .allowPermissions:
            return "Allow Permissions"
        case .chooseWallpapers:
            return "Choose Wallpapers"
        case .overview:
            return "All Set"
        }
    }

    var progressTitle: String {
        switch self {
        case .welcome:
            return "Welcome"
        case .installShortcut:
            return "Install Shortcut"
        case .addNotes:
            return "Add Notes"
        case .chooseWallpapers:
            return "Choose Wallpapers"
        case .allowPermissions:
            return "Allow Permissions"
        case .overview:
            return "All Set"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .welcome:
            return "Step 1"
        case .installShortcut:
            return "Step 2"
        case .addNotes:
            return "Step 3"
        case .chooseWallpapers:
            return "Step 4"
        case .allowPermissions:
            return "Step 5"
        case .overview:
            return "Step 6"
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
    func ensureCustomPhotoFlagIsAccurate() {
        // During onboarding, don't auto-enable based on file existence
        // Only sync the flag in Settings view where it makes sense
        // This prevents pre-selection during first-time setup
        
        // If user hasn't completed setup yet, ensure flag starts as false
        if !hasCompletedSetup {
            homeScreenUsesCustomPhoto = false
            return
        }
        
        // After setup is complete, sync with actual file state
        let shouldBeEnabled = homeScreenPresetSelectionRaw.isEmpty && HomeScreenImageManager.homeScreenImageExists()
        if homeScreenUsesCustomPhoto != shouldBeEnabled {
            homeScreenUsesCustomPhoto = shouldBeEnabled
        }
    }

    private func advanceAfterShortcutInstallIfNeeded() {
        // This method is no longer needed - navigation is handled directly in onChange
        // Keeping it for backwards compatibility but it shouldn't be called
    }
}

// MARK: - Hidden PiP Player Layer View

/// A UIView that contains the player layer for PiP support.
/// PiP requires the player layer to be genuinely visible on screen.
private struct HiddenPiPPlayerLayerView: UIViewRepresentable {
    @ObservedObject var playerManager: PIPVideoPlayerManager
    
    func makeUIView(context: Context) -> PiPContainerView {
        let view = PiPContainerView()
        view.backgroundColor = .clear
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 568) // Proper video size
        view.alpha = 1.0 // Must NOT be 0 for PiP
        view.isHidden = false // Must NOT be hidden for PiP
        view.clipsToBounds = false // Allow layer to render
        
        debugLog("🔧 HiddenPiPPlayerLayerView: Creating view for PiP (size: 320x568)")
        
        // Store a reference to the manager
        view.playerManager = playerManager
        
        return view
    }
    
    func updateUIView(_ uiView: PiPContainerView, context: Context) {
        // Ensure view has proper size for PiP
        if uiView.bounds.width == 0 || uiView.bounds.height == 0 {
            uiView.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        }
        
        // Update existing player layer frame if it exists
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            // Use fixed size for PiP (not view bounds which might be wrong)
            playerLayer.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        }
        
        // When player is loaded and layer hasn't been added yet
        if playerManager.hasLoadedVideo && uiView.layer.sublayers?.isEmpty != false {
            debugLog("🔧 HiddenPiPPlayerLayerView: Player loaded, adding layer")
            if let playerLayer = playerManager.createPlayerLayer() {
                // Use fixed size for PiP
                playerLayer.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
                uiView.layer.addSublayer(playerLayer)
                debugLog("✅ HiddenPiPPlayerLayerView: Added player layer (320x568)")
            }
        }
    }
}

/// Container view for PiP player layer
private class PiPContainerView: UIView {
    weak var playerManager: PIPVideoPlayerManager?
    private var hasPreparedPiP = false
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Ensure view has proper size even if SwiftUI gives us wrong frame
        if bounds.width == 0 || bounds.height == 0 {
            frame = CGRect(x: frame.origin.x, y: frame.origin.y, width: 320, height: 568)
        }
        
        // Keep player layer at fixed size for PiP
        if let playerLayer = layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
            
            // Set up PiP controller once layer is ready
            if !hasPreparedPiP,
               let manager = playerManager,
               !manager.isPiPControllerReady,
               window != nil {
                hasPreparedPiP = true
                debugLog("✅ PiPContainerView: Setting up PiP controller")
                
                // Small delay to ensure everything is stable
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    manager.setupPictureInPictureControllerWithExistingLayer()
                }
            }
        }
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        if window != nil {
            debugLog("✅ PiPContainerView: View added to window (frame: \(frame), bounds: \(bounds))")
        }
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
            .onChange(of: isVisible) { visible in
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

// MARK: - Epic Confetti View (Explosion Style)

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    
    private let colors: [Color] = [
        .appAccent,
        Color(red: 1, green: 0.84, blue: 0),     // Gold
        Color(red: 0.3, green: 0.85, blue: 0.5), // Green
        Color(red: 1, green: 0.4, blue: 0.4),    // Coral
        Color(red: 0.4, green: 0.7, blue: 1),    // Sky Blue
        Color(red: 1, green: 0.6, blue: 0.8),    // Pink
        Color(red: 0.7, green: 0.5, blue: 1),    // Lavender
        .white
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Central flash
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.8), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .opacity(particles.isEmpty ? 0 : 1)
                    .animation(.easeOut(duration: 0.3), value: particles.isEmpty)
                
                ForEach(particles) { particle in
                    ConfettiPiece(particle: particle, centerX: geometry.size.width / 2, centerY: geometry.size.height / 2)
                }
            }
            .onAppear {
                createExplosion(in: geometry.size)
            }
        }
    }
    
    private func createExplosion(in size: CGSize) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        // Create particles that explode from center
        particles = (0..<120).map { i in
            let angle = Double.random(in: 0...(2 * .pi))
            let velocity = CGFloat.random(in: 200...600)
            let targetX = centerX + cos(angle) * velocity
            let targetY = centerY + sin(angle) * velocity - CGFloat.random(in: 100...300) // Bias upward
            
            return ConfettiParticle(
                x: centerX,
                y: centerY,
                color: colors.randomElement()!,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.6...1.4),
                shape: ConfettiShape.allCases.randomElement()!,
                delay: Double.random(in: 0...0.15),
                duration: Double.random(in: 2.0...3.5),
                targetX: targetX,
                targetY: targetY + size.height * 0.5 // Fall below screen
            )
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let color: Color
    let rotation: Double
    let scale: CGFloat
    let shape: ConfettiShape
    let delay: Double
    let duration: Double
    var targetX: CGFloat = 0
    var targetY: CGFloat = 0
}

enum ConfettiShape: CaseIterable {
    case circle
    case rectangle
    case star
}

struct ConfettiPiece: View {
    let particle: ConfettiParticle
    let centerX: CGFloat
    let centerY: CGFloat
    
    @State private var currentX: CGFloat
    @State private var currentY: CGFloat
    @State private var currentRotation: Double
    @State private var opacity: Double = 1
    @State private var currentScale: CGFloat = 0.1
    
    init(particle: ConfettiParticle, centerX: CGFloat, centerY: CGFloat) {
        self.particle = particle
        self.centerX = centerX
        self.centerY = centerY
        self._currentX = State(initialValue: particle.x)
        self._currentY = State(initialValue: particle.y)
        self._currentRotation = State(initialValue: particle.rotation)
    }
    
    var body: some View {
        confettiShape()
            .fill(particle.color)
            .frame(width: 12 * particle.scale, height: 16 * particle.scale)
            .rotationEffect(.degrees(currentRotation))
            .scaleEffect(currentScale)
            .position(x: currentX, y: currentY)
            .opacity(opacity)
            .shadow(color: particle.color.opacity(0.5), radius: 3, x: 0, y: 0)
            .onAppear {
                // Initial pop scale
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5).delay(particle.delay)) {
                    currentScale = particle.scale
                }
                
                // Explosion outward then gravity fall
                withAnimation(
                    Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: particle.duration)
                        .delay(particle.delay)
                ) {
                    currentX = particle.targetX
                    currentY = particle.targetY
                    currentRotation += Double.random(in: 540...1080)
                }
                
                // Fade out
                withAnimation(
                    .easeIn(duration: 0.6)
                    .delay(particle.delay + particle.duration - 0.6)
                ) {
                    opacity = 0
                }
            }
    }
    
    private func confettiShape() -> AnyShape {
        switch particle.shape {
        case .circle:
            return AnyShape(Circle())
        case .rectangle:
            return AnyShape(RoundedRectangle(cornerRadius: 2))
        case .star:
            return AnyShape(StarShape())
        }
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4
        let points = 5
        
        var path = Path()
        
        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// Type eraser for Shape protocol
struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = shape.path(in:)
    }
    
    func path(in rect: CGRect) -> Path {
        return _path(rect)
    }
}
