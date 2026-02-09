import SwiftUI
import AVKit  // Kept for potential future use with PiP video player

/// Full-screen onboarding view for the one-time shortcut setup.
/// This view guides users through installing and configuring the NoteWall Shortcut.
/// It includes automatic verification.
// NOTE: PiP video tutorial is currently commented out but can be re-enabled if needed
struct ShortcutSetupView: View {
    
    // MARK: - Environment & State
    
    @StateObject private var viewModel: ShortcutSetupViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    
    /// Callback when setup is complete
    let onComplete: () -> Void
    
    /// Whether to show this view as a full-screen sheet
    @State private var isPresented = true
    
    // MARK: - Initialization
    
    /// Creates a new ShortcutSetupView.
    /// - Parameters:
    ///   - shortcutURL: The iCloud Shortcut URL to open for installation
    ///   - onComplete: Callback when setup is complete
    init(
        shortcutURL: String? = nil,
        onComplete: @escaping () -> Void = {}
    ) {
        let vm = ShortcutSetupViewModel(
            shortcutURL: shortcutURL
        )
        _viewModel = StateObject(wrappedValue: vm)
        self.onComplete = onComplete
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background color
            Color(.systemBackground)
                .ignoresSafeArea()
            
            // Content based on setup state
            switch viewModel.setupState {
            case .initial:
                initialSetupView
                    .onAppear {
                        // When user arrives at this step after installing shortcut,
                        // automatically start verification instead of showing "Start Setup" again
                        // Check if shortcut can be verified immediately
                        print("📱 ShortcutSetupView: Initial view appeared, checking if shortcut is ready")
                        Task {
                            // Small delay to ensure view is ready
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            // Try to verify immediately - if shortcut is already installed
                            // this will work, otherwise user can tap "Start Setup"
                            if ShortcutVerificationService.verifyShortcutSetup().isVerified {
                                // Shortcut is already set up, mark as complete
                                viewModel.setupState = .complete
                            } else {
                                // Shortcut not ready yet, user needs to tap "Start Setup"
                                // But we can still auto-start the flow to make it smoother
                                // Actually, let's just let user tap the button for clarity
                            }
                        }
                    }
                
            case .setupStarted:
                setupInProgressView
                
            case .returnedFromShortcuts, .verifying:
                verifyingView
                
            case .verified:
                verificationSuccessView
                
            case .verificationFailed:
                verificationFailedView
                
            case .complete:
                // Setup complete - call onComplete and dismiss
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .onAppear {
                        onComplete()
                    }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onChange(of: viewModel.setupState) { _, newState in
            handleSetupStateChange(newState)
        }
    }
    
    // MARK: - View Components
    
    /// Initial setup view showing instructions and "Start Setup" button
    private var initialSetupView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    // Icon
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.appAccent)
                        .padding(.top, 40)
                    
                    // Title
                    Text("One-Time Shortcut Setup Required")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    // Subtitle
                    Text("This takes 30 seconds and you only do it once.")
                        .font(.system(.title3))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    // Important note
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.appAccent)
                                .font(.system(size: 16))
                            Text("Important:")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.appAccent)
                        }
                        Text("When the shortcut asks for folder access, you'll need to navigate to:\nFiles → On My iPhone → NoteWall → LockScreen")
                            .font(.system(.caption))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.appAccent.opacity(0.1))
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
                
                // Steps list
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(ShortcutSetupViewModel.SetupStep.allSteps) { step in
                        HStack(alignment: .top, spacing: 16) {
                            // Step number
                            ZStack {
                                Circle()
                                    .fill(Color.appAccent)
                                    .frame(width: 32, height: 32)
                                
                                Text("\(step.id)")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .accessibilityHidden(true)
                            
                            // Step description
                            Text(step.description)
                                .font(.system(.body))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical, 24)
                
                // Start Setup button
                Button(action: {
                    // PiP video preparation commented out - can be re-enabled if needed
                    // Task {
                    //     await prepareVideoForSetup()
                    //     viewModel.startSetup()
                    // }
                    viewModel.startSetup()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text("Start Setup")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.appAccent,
                                        Color.appAccent.opacity(0.9)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 16, x: 0, y: 8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        // PiP video player commented out - can be re-enabled if needed
        // .background(
        //     // Hidden video player to preload video
        //     tutorialVideoPlayer
        //         .frame(width: 1, height: 1)
        //         .opacity(0)
        // )
        // .onAppear {
        //     // Preload video when initial view appears
        //     preloadVideo()
        // }
    }
    
    /// View shown when setup has started (video playing, Shortcuts app opened)
    private var setupInProgressView: some View {
        ZStack {
            VStack(spacing: 24) {
                // Instructions
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.appAccent)
                    
                    Text("Follow the Instructions")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                    
                    Text("Follow the instructions in Shortcuts, then return to this app.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 80)
                
                // PiP video placeholder commented out - can be re-enabled if needed
                // ZStack {
                //     RoundedRectangle(cornerRadius: 20, style: .continuous)
                //         .fill(Color(.secondarySystemBackground))
                //         .frame(width: 300, height: 533)
                //     
                //     VStack(spacing: 16) {
                //         if pipVideoManager.isPiPActive {
                //             Image(systemName: "pip.fill")
                //             .font(.system(size: 50))
                //             .foregroundColor(.appAccent)
                //         
                //         Text("Video playing in Picture-in-Picture")
                //             .font(.subheadline)
                //             .foregroundColor(.secondary)
                //         } else {
                //             Image(systemName: "play.circle.fill")
                //                 .font(.system(size: 50))
                //                 .foregroundColor(.appAccent)
                //             
                //             Text("Starting video...")
                //                 .font(.subheadline)
                //                 .foregroundColor(.secondary)
                //             
                //             // Debug info
                //             #if DEBUG
                //             VStack(spacing: 4) {
                //                 Text("Ready: \(pipVideoManager.isReadyToPlay ? "Yes" : "No")")
                //                     .font(.caption2)
                //                 Text("PiP Available: \(pipVideoManager.isPiPAvailable ? "Yes" : "No")")
                //                     .font(.caption2)
                //                 if let error = pipVideoManager.playbackError {
                //                     Text("Error: \(error.localizedDescription)")
                //                         .font(.caption2)
                //                         .foregroundColor(.red)
                //                 }
                //             }
                //             .padding(.top, 8)
                //             #endif
                //         }
                //     }
                // }
                // .padding(.vertical, 40)
                // 
                // // Test button for PiP (debug only)
                // #if DEBUG
                // Button(action: {
                //     print("🧪 Test: Manually starting PiP...")
                //     _ = pipVideoManager.startPictureInPicture()
                // }) {
                //     Text("Test PiP (Debug)")
                //         .font(.caption)
                //         .foregroundColor(.appAccent)
                // }
                // .padding(.top, 8)
                // #endif
                
                Spacer()
            }
            
            // PiP video player commented out - can be re-enabled if needed
            // tutorialVideoPlayer
            //     .frame(width: 100, height: 100)
            //     .opacity(0.3)
            //     .allowsHitTesting(false)
        }
        // PiP video setup commented out - can be re-enabled if needed
        // .onAppear {
        //     // When this view appears, ensure video is loaded and playing
        //     setupVideoForPiP()
        // }
    }
    
    // MARK: - PiP Video Player (Commented Out - Can be re-enabled if needed)
    
    // /// The tutorial video player view (hidden, only used for PiP)
    // @StateObject private var pipVideoManager = PIPVideoPlayerManager()
    // 
    // @ViewBuilder
    // private var tutorialVideoPlayer: some View {
    //     if let videoURL = Bundle.main.url(forResource: "tutorial", withExtension: "mp4") {
    //         // Use a minimal visible player that can activate PiP
    //         // The player must be in the view hierarchy for PiP to work
    //         Group {
    //             if let player = pipVideoManager.getPlayer() {
    //                 VideoPlayer(player: player)
    //                     .onAppear {
    //                         print("📹 ShortcutSetupView: VideoPlayer appeared")
    //                     }
    //                     .onDisappear {
    //                         print("📹 ShortcutSetupView: VideoPlayer disappeared")
    //                     }
    //             } else {
    //                 // Show loading state
    //                 ZStack {
    //                     Color.black.opacity(0.1)
    //                     ProgressView()
    //                 }
    //                     .onAppear {
    //                     print("📹 ShortcutSetupView: Loading video...")
    //                         _ = pipVideoManager.loadVideo(url: videoURL)
    //                     }
    //             }
    //         }
    //     } else {
    //         // If tutorial video doesn't exist, show error
    //         VStack(spacing: 8) {
    //             Image(systemName: "exclamationmark.triangle.fill")
    //                 .foregroundColor(.orange)
    //             Text("Tutorial video not found")
    //                 .font(.caption)
    //                 .foregroundColor(.secondary)
    //             Text("Add 'tutorial.mp4' to the app bundle")
    //                 .font(.caption2)
    //                 .foregroundColor(.secondary)
    //         }
    //         .frame(width: 200, height: 200)
    //         .onAppear {
    //             print("❌ ShortcutSetupView: Tutorial video not found in bundle")
    //             print("❌ ShortcutSetupView: Expected file: tutorial.mp4")
    //         }
    //     }
    // }
    // 
    // /// Preloads the video when the initial view appears
    // private func preloadVideo() {
    //     guard let videoURL = Bundle.main.url(forResource: "tutorial", withExtension: "mp4") else {
    //         print("❌ ShortcutSetupView: Tutorial video not found in bundle")
    //         return
    //     }
    //     
    //     print("📹 ShortcutSetupView: Preloading video...")
    //     _ = pipVideoManager.loadVideo(url: videoURL)
    // }
    // 
    // /// Prepares the video for setup by ensuring it's loaded and ready
    // private func prepareVideoForSetup() async {
    //     guard let videoURL = Bundle.main.url(forResource: "tutorial", withExtension: "mp4") else {
    //         print("❌ ShortcutSetupView: Tutorial video not found")
    //         return
    //     }
    //     
    //     // Load video if not already loaded
    //     if pipVideoManager.getPlayer() == nil {
    //         print("📹 ShortcutSetupView: Loading video before setup...")
    //         _ = pipVideoManager.loadVideo(url: videoURL)
    //     }
    //     
    //     // Wait for video to be ready
    //     var attempts = 0
    //     while !pipVideoManager.isReadyToPlay && attempts < 50 {
    //         try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    //         attempts += 1
    //     }
    //     
    //     if pipVideoManager.isReadyToPlay {
    //         print("✅ ShortcutSetupView: Video is ready for setup")
    //     } else {
    //         print("⚠️ ShortcutSetupView: Video not ready, but proceeding anyway")
    //     }
    // }
    // 
    // /// Sets up the video for PiP playback
    // /// This should be called when the setup in progress view appears
    // private func setupVideoForPiP() {
    //     guard let videoURL = Bundle.main.url(forResource: "tutorial", withExtension: "mp4") else {
    //         print("❌ ShortcutSetupView: Tutorial video not found")
    //         return
    //     }
    //     
    //     print("📹 ShortcutSetupView: Setting up video for PiP")
    //     
    //     // Load video if not already loaded
    //     if pipVideoManager.getPlayer() == nil {
    //         let loaded = pipVideoManager.loadVideo(url: videoURL)
    //         print("📹 ShortcutSetupView: Video loaded: \(loaded)")
    //     }
    //     
    //     // Wait for video to be ready, then play and start PiP
    //     Task {
    //         print("📹 ShortcutSetupView: Waiting for video to be ready...")
    //         var attempts = 0
    //         while !pipVideoManager.isReadyToPlay && attempts < 100 {
    //             try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    //             attempts += 1
    //         }
    //         
    //         if pipVideoManager.isReadyToPlay {
    //             print("✅ ShortcutSetupView: Video is ready, starting playback")
    //             let played = pipVideoManager.play()
    //             print("📹 ShortcutSetupView: Play called, result: \(played)")
    //             
    //             // Wait a moment for playback to start, then start PiP
    //             // PiP should be started while app is still in foreground
    //             try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
    //             
    //             print("📹 ShortcutSetupView: Attempting to start PiP...")
    //             print("📹 ShortcutSetupView: PiP available: \(pipVideoManager.isPiPAvailable)")
    //             print("📹 ShortcutSetupView: Player ready: \(pipVideoManager.isReadyToPlay)")
    //             
    //             // Start PiP while still in foreground
    //             let pipStarted = pipVideoManager.startPictureInPicture()
    //             print("📹 ShortcutSetupView: PiP start called, result: \(pipStarted)")
    //             
    //             // Check PiP status after a moment
    //             try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    //             print("📹 ShortcutSetupView: PiP active: \(pipVideoManager.isPiPActive)")
    //             
    //             if !pipVideoManager.isPiPActive {
    //                 print("⚠️ ShortcutSetupView: PiP did not start. This might work when app goes to background.")
    //             }
    //         } else {
    //             print("❌ ShortcutSetupView: Video failed to become ready after \(attempts) attempts")
    //             if let error = pipVideoManager.playbackError {
    //                 print("❌ ShortcutSetupView: Error: \(error.localizedDescription)")
    //             }
    //         }
    //     }
    // }
    
    /// View shown while verification is in progress
    private var verifyingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(2)
                .padding(.top, 100)
            
            Text("Verifying Setup...")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.semibold)
            
            Text("Please wait while we verify that your shortcut is configured correctly.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    /// View shown when verification succeeds
    private var verificationSuccessView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success animation
            ZStack {
                Circle()
                    .fill(Color.appAccent)
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 24)
            
            // Success message
            VStack(spacing: 16) {
                Text("Setup Complete ✓")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.appAccent)
                
                Text("Your shortcut is configured correctly. You're all set!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .padding(.vertical, 60)
    }
    
    /// View shown when verification fails
    private var verificationFailedView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Error icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .padding(.top, 40)
                
                // Error title
                Text("Setup Not Finished")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                
                // Error details
                if let errorMessage = viewModel.userFriendlyErrorMessage {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What's missing:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal, 24)
                }
                
                // Action buttons
                VStack(spacing: 16) {
                    // Retry Verification button
                    Button(action: {
                        viewModel.retryVerification()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Text("Retry Verification")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.appAccent)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Watch Tutorial Again button
                    Button(action: {
                        viewModel.reopenShortcuts()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Text("Watch Tutorial Again")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.appAccent)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.appAccent, lineWidth: 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.appAccent.opacity(0.1))
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Reopen Shortcuts button
                    Button(action: {
                        viewModel.reopenShortcuts()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.right.square.fill")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Text("Reopen Shortcuts")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.appAccent)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.appAccent, lineWidth: 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.appAccent.opacity(0.1))
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Handles scene phase changes to detect when user returns from Shortcuts app
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        // When app becomes active, check if we should verify
        if newPhase == .active {
            if viewModel.shouldAutoVerify && viewModel.setupState == .setupStarted {
                // Small delay to ensure app is fully active
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.handleAppReturn()
                }
            }
        }
    }
    
    /// Handles setup state changes
    private func handleSetupStateChange(_ newState: ShortcutSetupViewModel.SetupState) {
        // When setup is complete, call onComplete after a brief delay
        if newState == .complete {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete()
            }
        }
    }
}

// MARK: - Video Tutorial View (Commented Out - Can be re-enabled if needed)

// /// A view that shows the Picture-in-Picture video tutorial.
// /// This is integrated into the setup flow to show instructions while the user configures the shortcut.
// private struct TutorialVideoView: View {
//     
//     @StateObject private var playerManager = PIPVideoPlayerManager()
//     @Environment(\.scenePhase) private var scenePhase
//     
//     var body: some View {
//         Group {
//             // Load tutorial video from bundle
//             if let videoURL = Bundle.main.url(forResource: "tutorial", withExtension: "mp4") {
//                 PIPVideoPlayerView(
//                     videoURL: videoURL,
//                     autoplay: true,
//                     autoStartPiP: true,
//                     onError: { error in
//                         print("❌ Tutorial video error: \(error.localizedDescription)")
//                     }
//                 )
//             } else {
//                 // Placeholder if video not found
//                 ZStack {
//                     Color.black
//                     VStack(spacing: 16) {
//                         Image(systemName: "video.slash.fill")
//                             .font(.system(size: 50))
//                             .foregroundColor(.white.opacity(0.5))
//                         
//                         Text("Tutorial video not found")
//                             .font(.subheadline)
//                             .foregroundColor(.white.opacity(0.7))
//                     }
//                 }
//             }
//         }
//         .onChange(of: scenePhase) { newPhase in
//             // Auto-start PiP when app goes to background
//             if newPhase == .background {
//                 _ = playerManager.startPictureInPicture()
//             }
//         }
//     }
// }

// MARK: - Preview Support

#if DEBUG
struct ShortcutSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ShortcutSetupView(
            shortcutURL: "https://www.icloud.com/shortcuts/test",
            onComplete: {
                print("Setup complete")
            }
        )
    }
}
#endif

