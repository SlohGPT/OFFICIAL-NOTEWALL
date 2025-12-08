import SwiftUI
import AVKit
import AVFoundation
import UIKit

/// A Picture-in-Picture capable video player that automatically starts PiP when the app goes to the background.
/// This is used to show tutorial videos while the user interacts with the Shortcuts app.
@MainActor
final class PIPVideoPlayerManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether the video player is ready to play
    @Published var isReadyToPlay = false
    
    /// Whether Picture-in-Picture is currently active
    @Published var isPiPActive = false
    
    /// Whether Picture-in-Picture is available on this device
    @Published var isPiPAvailable = false
    
    /// Current playback error, if any
    @Published var playbackError: Error?
    
    /// Whether a video has been loaded (triggers view updates)
    @Published var hasLoadedVideo = false
    
    /// Equatable error wrapper for observing errors
    struct EquatableError: Equatable {
        internal let error: Error?
        
        static func == (lhs: EquatableError, rhs: EquatableError) -> Bool {
            if lhs.error == nil && rhs.error == nil {
                return true
            }
            guard let lhsError = lhs.error, let rhsError = rhs.error else {
                return false
            }
            return lhsError.localizedDescription == rhsError.localizedDescription &&
                   String(describing: type(of: lhsError)) == String(describing: type(of: rhsError))
        }
    }
    
    /// Observable error wrapper for onChange
    var observableError: EquatableError {
        EquatableError(error: playbackError)
    }
    
    // MARK: - Private Properties
    
    /// Debug print helper - only prints in DEBUG builds
    private func debugPrint(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }
    
    /// The AVPlayer instance for video playback
    private var player: AVPlayer?
    
    /// The AVPlayerLayer for rendering video
    private var playerLayer: AVPlayerLayer?
    
    /// The AVPlayerViewController for better PiP control
    private var playerViewController: AVPlayerViewController?
    
    /// The AVPictureInPictureController for PiP functionality
    private var pipController: AVPictureInPictureController?
    
    /// The player item observer for tracking playback status
    private var playerItemObserver: NSKeyValueObservation?
    
    /// The player rate observer for tracking playback state
    private var playerRateObserver: NSKeyValueObservation?
    
    /// The scene phase observer for auto-starting PiP
    private var scenePhaseObserver: NSObjectProtocol?
    
    /// Whether PiP should start automatically when app goes to background
    private var shouldAutoStartPiP = true
    
    /// The video file URL
    private var videoURL: URL?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        // Set up audio session for PiP - REQUIRED for PiP to work
        setupAudioSession()
        
        // Check if PiP is available on this device
        checkPiPAvailability()
        
        // Set up scene phase observer to auto-start PiP
        setupScenePhaseObserver()
    }
    
    /// Sets up the audio session for PiP support.
    /// This MUST be called before creating the PiP controller.
    private func setupAudioSession() {
        do {
            // CRITICAL: Use .playback without .mixWithOthers for PiP to work
            // PiP requires exclusive audio playback
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            debugPrint("✅ PIPVideoPlayerManager: Audio session configured for PiP")
        } catch {
            #if DEBUG
            print("❌ PIPVideoPlayerManager: Failed to set up audio session: \(error)")
            #endif
        }
    }
    
    deinit {
        // Note: Main actor-isolated properties will be cleaned up automatically
        // when the object is deallocated. Observers will be invalidated automatically
        // when the observation objects are deallocated. We avoid manual cleanup here
        // to prevent actor isolation violations from deinit.
        // 
        // Best practice: The observers are weak references and will be automatically
        // cleaned up. The player and pipController will also be cleaned up when
        // their owning objects are deallocated.
    }
    
    // MARK: - Public Methods
    
    /// Loads a video from the specified URL and prepares it for playback.
    /// - Parameter url: The URL of the video file to load (must be in the app bundle for PiP support)
    /// - Returns: true if loading started successfully, false otherwise
    func loadVideo(url: URL) -> Bool {
        // Clean up previous player if exists
        performCleanup()
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ PIPVideoPlayerManager: Video file not found at: \(url.path)")
            playbackError = NSError(
                domain: "PIPVideoPlayerManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Video file not found"]
            )
            return false
        }
        
        self.videoURL = url
        
        // Create AVAsset
        let asset = AVAsset(url: url)
        
        // Create player item
        let playerItem = AVPlayerItem(asset: asset)
        
        // CRITICAL: Disable seeking controls in PiP
        // Setting this to true hides the skip forward/back buttons
        if #available(iOS 9.0, *) {
            playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = false
            playerItem.preferredForwardBufferDuration = 1
        }
        
        // Create player
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.isMuted = false // Don't mute - PiP works better with audio
        newPlayer.allowsExternalPlayback = true
        newPlayer.actionAtItemEnd = .none // Don't stop at end - we'll handle looping
        
        // Prevent user interaction with playback controls
        if #available(iOS 14.2, *) {
            newPlayer.preventsDisplaySleepDuringVideoPlayback = true
        }
        
        self.player = newPlayer
        
        // Set up looping
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // Set up player item observers
        setupPlayerItemObservers(playerItem: playerItem)
        
        // Don't set up PiP controller yet - wait for layer to be added to view hierarchy
        // setupPictureInPictureController() will be called from setupPictureInPictureControllerWithExistingLayer()
        
        // Mark as loaded to trigger view updates
        hasLoadedVideo = true
        
        debugPrint("✅ PIPVideoPlayerManager: Video loaded successfully")
        return true
    }
    
    /// Starts video playback.
    /// - Returns: true if playback started, false otherwise
    func play() -> Bool {
        guard let player = player else {
            #if DEBUG
            print("❌ PIPVideoPlayerManager: Cannot play - player is nil")
            #endif
            return false
        }
        
        guard isReadyToPlay else {
            debugPrint("⚠️ PIPVideoPlayerManager: Player not ready yet, will play when ready")
            // Set up observer to play when ready
            setupPlayerReadyObserver()
            return false
        }
        
        // Use playImmediately to force immediate playback without waiting for buffering
        // This is critical for PiP to work - the video MUST be actively playing
        player.playImmediately(atRate: 1.0)
        
        // Log actual player state
        debugPrint("✅ PIPVideoPlayerManager: Playback started")
        debugPrint("   - Player rate after play: \(player.rate)")
        debugPrint("   - Player timeControlStatus: \(player.timeControlStatus.rawValue)")
        
        return true
    }
    
    /// Checks if the video is currently playing
    var isPlaying: Bool {
        return player?.rate ?? 0 > 0
    }
    
    /// Pauses video playback.
    func pause() {
        player?.pause()
        debugPrint("⏸️ PIPVideoPlayerManager: Playback paused")
    }
    
    /// Stops video playback and resets to beginning.
    func stop() {
        pause()
        player?.seek(to: .zero)
        debugPrint("⏹️ PIPVideoPlayerManager: Playback stopped")
    }
    
    /// Starts Picture-in-Picture mode.
    /// This will show the video in a floating window while the user interacts with other apps.
    /// - Returns: true if PiP started successfully, false otherwise
    func startPictureInPicture() -> Bool {
        guard isPiPAvailable else {
            #if DEBUG
            print("❌ PIPVideoPlayerManager: PiP is not available on this device")
            #endif
            return false
        }
        
        guard let controller = pipController else {
            debugPrint("❌ PIPVideoPlayerManager: PiP controller is nil - not set up yet")
            debugPrint("   - Player exists: \(player != nil)")
            debugPrint("   - Player layer exists: \(playerLayer != nil)")
            return false
        }
        
        // CRITICAL: Re-activate audio session before starting PiP
        // This is required for PiP to work when app is backgrounding
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            debugPrint("✅ PIPVideoPlayerManager: Audio session reactivated for PiP")
        } catch {
            #if DEBUG
            print("⚠️ PIPVideoPlayerManager: Failed to reactivate audio session: \(error)")
            #endif
        }
        
        // Ensure player is playing before we check PiP readiness. Some iOS versions
        // won't mark PiP as possible until playback has actually started.
        if let player = player, player.rate == 0 {
            debugPrint("⚠️ PIPVideoPlayerManager: Player not playing, starting playback")
            player.playImmediately(atRate: 1.0)
        }

        // If PiP isn't possible yet, give the system a brief moment to update after
        // starting playback and try one more time before failing.
        guard controller.isPictureInPicturePossible else {
            debugPrint("❌ PIPVideoPlayerManager: PiP is not possible at this time")
            debugPrint("   - Player ready: \(isReadyToPlay)")
            debugPrint("   - Player rate: \(player?.rate ?? 0)")
            debugPrint("   - Player time control status: \(player?.timeControlStatus.rawValue ?? -1)")
            if let layer = playerLayer {
                debugPrint("   - Layer in superlayer: \(layer.superlayer != nil)")
                debugPrint("   - Layer frame: \(layer.frame)")
                debugPrint("   - Layer bounds: \(layer.bounds)")
                if let superlayer = layer.superlayer {
                    debugPrint("   - Superlayer frame: \(superlayer.frame)")
                }
            }

            // Retry shortly after kicking playback just in case the PiP controller
            // needed the player to be actively rendering.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                
                // Re-check if PiP is possible
                guard let retryController = self.pipController else { return }
                
                #if DEBUG
                print("🔁 PIPVideoPlayerManager: Retrying PiP start...")
                print("   - isPictureInPicturePossible: \(retryController.isPictureInPicturePossible)")
                #endif
                
                if retryController.isPictureInPicturePossible {
                    retryController.startPictureInPicture()
                } else {
                    // Force attempt anyway - sometimes isPictureInPicturePossible is wrong
                    #if DEBUG
                    print("🔁 PIPVideoPlayerManager: Force-attempting PiP start despite isPictureInPicturePossible being false")
                    #endif
                    retryController.startPictureInPicture()
                }
            }

            return false
        }

        controller.startPictureInPicture()
        debugPrint("✅ PIPVideoPlayerManager: Picture-in-Picture started")
        return true
    }
    
    /// Stops Picture-in-Picture mode.
    func stopPictureInPicture() {
        pipController?.stopPictureInPicture()
        debugPrint("⏹️ PIPVideoPlayerManager: Picture-in-Picture stopped")
    }
    
    /// Sets whether PiP should start automatically when the app goes to the background.
    /// - Parameter autoStart: true to auto-start PiP, false otherwise
    func setAutoStartPiP(_ autoStart: Bool) {
        shouldAutoStartPiP = autoStart
    }
    
    /// Gets the AVPlayer instance for use in SwiftUI VideoPlayer views.
    /// - Returns: The AVPlayer instance, or nil if not ready
    func getPlayer() -> AVPlayer? {
        return player
    }
    
    /// Checks if the PiP controller is set up and ready.
    /// - Returns: true if PiP controller exists, false otherwise
    var isPiPControllerReady: Bool {
        return pipController != nil
    }
    
    /// Checks if PiP is actually possible right now (controller exists AND iOS says it's ready).
    /// - Returns: true if PiP can be started immediately
    var isPiPPossible: Bool {
        return pipController?.isPictureInPicturePossible ?? false
    }
    
    /// Creates a player layer for use in UIKit views.
    /// - Returns: An AVPlayerLayer configured for this player, or nil if player is not ready
    func createPlayerLayer() -> AVPlayerLayer? {
        guard let player = player else {
            return nil
        }
        
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        
        // Store reference for cleanup
        self.playerLayer = layer
        
        return layer
    }
    
    // MARK: - Private Methods
    
    /// Checks if Picture-in-Picture is available on this device.
    private func checkPiPAvailability() {
        // PiP is available on iPad (iOS 9+) and iPhone (iOS 14+)
        if UIDevice.current.userInterfaceIdiom == .pad {
            isPiPAvailable = true
        } else if #available(iOS 14.0, *) {
            isPiPAvailable = AVPictureInPictureController.isPictureInPictureSupported()
        } else {
            isPiPAvailable = false
        }
        
        debugPrint("📱 PIPVideoPlayerManager: PiP available: \(isPiPAvailable)")
    }
    
    /// Sets up the AVPictureInPictureController for PiP functionality.
    private func setupPictureInPictureController() {
        guard let player = player else {
            return
        }
        
        guard isPiPAvailable else {
            debugPrint("⚠️ PIPVideoPlayerManager: PiP not available, skipping controller setup")
            return
        }
        
        // Create player view controller for better control over PiP UI
        let viewController = AVPlayerViewController()
        viewController.player = player
        viewController.showsPlaybackControls = false // CRITICAL: Hide all playback controls
        viewController.allowsPictureInPicturePlayback = true
        viewController.delegate = self as? any AVPlayerViewControllerDelegate
        
        self.playerViewController = viewController
        
        // Use existing player layer if available (from view hierarchy), otherwise create new one
        let layer: AVPlayerLayer
        if let existingLayer = self.playerLayer {
            layer = existingLayer
            debugPrint("✅ PIPVideoPlayerManager: Using existing player layer from view hierarchy")
        } else {
            layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspect
            self.playerLayer = layer
            debugPrint("✅ PIPVideoPlayerManager: Created new player layer")
        }
        
        // Create PiP controller with the view controller for better control
        // Try content source first (iOS 15+) for better control
        if #available(iOS 15.0, *) {
            let contentSource = AVPictureInPictureController.ContentSource(
                playerLayer: layer
            )
            
            // Note: This initializer returns non-optional on iOS 15+
            let controller = AVPictureInPictureController(contentSource: contentSource)
            self.pipController = controller
            controller.delegate = self
            
            // Enable automatic PiP start when app backgrounds
            controller.canStartPictureInPictureAutomaticallyFromInline = true
            
            debugPrint("✅ PIPVideoPlayerManager: PiP controller created with content source (no controls)")
            
            if controller.isPictureInPicturePossible {
                debugPrint("✅ PIPVideoPlayerManager: Picture-in-Picture ready")
            } else {
                debugPrint("⚠️ PIPVideoPlayerManager: PiP not possible yet")
                debugPrint("   - Player rate: \(player.rate)")
            }
        } else {
            // Fallback for older iOS versions
            if let controller = try? AVPictureInPictureController(playerLayer: layer) {
                self.pipController = controller
                controller.delegate = self
                
                if #available(iOS 14.2, *) {
                    controller.canStartPictureInPictureAutomaticallyFromInline = true
                }
                
                debugPrint("✅ PIPVideoPlayerManager: PiP controller created (legacy)")
            }
        }
        
        if pipController == nil {
            let error = NSError(
                domain: "PIPVideoPlayerManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create Picture-in-Picture controller"]
            )
            #if DEBUG
            print("❌ PIPVideoPlayerManager: Failed to create PiP controller")
            #endif
            playbackError = error
        }
    }
    
    /// Sets up the PiP controller using an existing player layer from the view hierarchy.
    /// This should be called after the layer is added to a view.
    func setupPictureInPictureControllerWithExistingLayer() {
        guard pipController == nil else {
            debugPrint("⚠️ PIPVideoPlayerManager: PiP controller already exists, skipping setup")
            return
        }
        
        guard let playerLayer = self.playerLayer else {
            debugPrint("⚠️ PIPVideoPlayerManager: No player layer available yet, cannot set up PiP controller")
            return
        }
        
        debugPrint("🔧 PIPVideoPlayerManager: Setting up PiP controller with existing layer")
        setupPictureInPictureController()
    }
    
    /// Sets up observers for player item status changes.
    private func setupPlayerItemObservers(playerItem: AVPlayerItem) {
        // Observe player item status
        playerItemObserver = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                switch item.status {
                case .readyToPlay:
                    self.isReadyToPlay = true
                    self.playbackError = nil
                    debugPrint("✅ PIPVideoPlayerManager: Player item ready to play")
                    
                    // If player was waiting to play, start now
                    if self.player?.rate == 0 {
                        // Don't auto-play here - let the view control playback
                    }
                    
                case .failed:
                    let error = item.error ?? NSError(
                        domain: "PIPVideoPlayerManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown playback error"]
                    )
                    self.isReadyToPlay = false
                    self.playbackError = error
                    #if DEBUG
                    print("❌ PIPVideoPlayerManager: Player item failed: \(error.localizedDescription)")
                    #endif
                    
                case .unknown:
                    self.isReadyToPlay = false
                    debugPrint("⚠️ PIPVideoPlayerManager: Player item status unknown")
                    
                @unknown default:
                    self.isReadyToPlay = false
                    debugPrint("⚠️ PIPVideoPlayerManager: Player item status unknown default")
                }
            }
        }
        
        // Observe playback errors
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlayerItemError),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        )
    }
    
    /// Sets up observer to automatically play when player becomes ready.
    private func setupPlayerReadyObserver() {
        // This will be handled by the player item status observer
    }
    
    /// Sets up scene phase observer to auto-start PiP when app goes to background.
    private func setupScenePhaseObserver() {
        // This will be handled by the view using onChange(of: scenePhase)
        // We don't set up the observer here to avoid conflicts with SwiftUI's scene phase tracking
    }
    
    /// Handles player item errors.
    @objc private func handlePlayerItemError(_ notification: Notification) {
        guard let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error else {
            return
        }
        
        Task { @MainActor [weak self] in
            self?.playbackError = error
            #if DEBUG
            print("❌ PIPVideoPlayerManager: Playback error: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// Handles player item reaching end - loops the video.
    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self = self, let player = self.player else { return }
            debugPrint("🔄 PIPVideoPlayerManager: Video reached end, looping...")
            player.seek(to: .zero)
            player.play()
        }
    }
    
    /// Cleans up all resources (called from main actor context).
    private func performCleanup() {
        // Remove observers
        playerItemObserver?.invalidate()
        playerItemObserver = nil
        
        playerRateObserver?.invalidate()
        playerRateObserver = nil
        
        if let observer = scenePhaseObserver {
            NotificationCenter.default.removeObserver(observer)
            scenePhaseObserver = nil
        }
        
        // Stop PiP
        pipController?.stopPictureInPicture()
        pipController = nil
        
        // Stop and release player
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        
        // Release player view controller
        playerViewController?.player = nil
        playerViewController = nil
        
        // Release player layer
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        
        // Reset state
        isReadyToPlay = false
        isPiPActive = false
        playbackError = nil
        videoURL = nil
        hasLoadedVideo = false
    }
    
}

// MARK: - AVPictureInPictureControllerDelegate

extension PIPVideoPlayerManager: AVPictureInPictureControllerDelegate {
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.isPiPActive = true
            debugPrint("🎬 PIPVideoPlayerManager: Picture-in-Picture will start")
        }
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.isPiPActive = true
            debugPrint("✅ PIPVideoPlayerManager: Picture-in-Picture started")
        }
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            debugPrint("⏹️ PIPVideoPlayerManager: Picture-in-Picture will stop")
        }
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.isPiPActive = false
            debugPrint("✅ PIPVideoPlayerManager: Picture-in-Picture stopped")
        }
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.isPiPActive = false
            self?.playbackError = error
            #if DEBUG
            print("❌ PIPVideoPlayerManager: Failed to start PiP: \(error.localizedDescription)")
            #endif
        }
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        Task { @MainActor [weak self] in
            debugPrint("🔄 PIPVideoPlayerManager: Restoring user interface for PiP stop")
            completionHandler(true)
        }
    }
}

// MARK: - SwiftUI Video Player View

/// A SwiftUI view wrapper for the Picture-in-Picture video player.
/// This view manages the video playback and automatically starts PiP when the app goes to the background.
struct PIPVideoPlayerView: View {
    
    @StateObject private var playerManager = PIPVideoPlayerManager()
    @Environment(\.scenePhase) private var scenePhase
    
    /// The video file URL
    let videoURL: URL
    
    /// Whether the video should autoplay when ready
    let autoplay: Bool
    
    /// Whether to auto-start PiP when app goes to background
    let autoStartPiP: Bool
    
    /// Callback when playback error occurs
    let onError: ((Error) -> Void)?
    
    init(
        videoURL: URL,
        autoplay: Bool = true,
        autoStartPiP: Bool = true,
        onError: ((Error) -> Void)? = nil
    ) {
        self.videoURL = videoURL
        self.autoplay = autoplay
        self.autoStartPiP = autoStartPiP
        self.onError = onError
    }
    
    var body: some View {
        Group {
            if let player = playerManager.getPlayer() {
                VideoPlayer(player: player)
                    .aspectRatio(9/16, contentMode: .fit)
                    .onAppear {
                        setupPlayer()
                    }
                    .onDisappear {
                        playerManager.stop()
                    }
                    .onChange(of: scenePhase) { newPhase in
                        handleScenePhaseChange(newPhase)
                    }
                    .onChange(of: playerManager.observableError) { errorWrapper in
                        if let error = errorWrapper.error {
                            onError?(error)
                        }
                    }
            } else {
                // Placeholder while loading
                ZStack {
                    Color.black
                    ProgressView()
                        .tint(.white)
                }
            }
        }
    }
    
    private func setupPlayer() {
        // Load video
        guard playerManager.loadVideo(url: videoURL) else {
            return
        }
        
        // Set auto-start PiP
        playerManager.setAutoStartPiP(autoStartPiP)
        
        // Autoplay if requested
        if autoplay {
            // Wait for player to be ready
            Task {
                // Poll until ready or timeout
                var attempts = 0
                while !playerManager.isReadyToPlay && attempts < 50 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    attempts += 1
                }
                
                if playerManager.isReadyToPlay {
                    _ = playerManager.play()
                }
            }
        }
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        // Auto-start PiP when app goes to background
        if newPhase == .background && autoStartPiP {
            if !playerManager.isPiPActive {
                _ = playerManager.startPictureInPicture()
            }
        }
    }
}

// MARK: - Preview Support

#if DEBUG
struct PIPVideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a placeholder URL for preview
        let placeholderURL = Bundle.main.url(forResource: "tutorial", withExtension: "mp4") ?? URL(fileURLWithPath: "/tmp/placeholder.mp4")
        
        PIPVideoPlayerView(videoURL: placeholderURL)
            .previewLayout(.sizeThatFits)
    }
}
#endif

