import SwiftUI
import AudioToolbox

/// A beautiful loading overlay that appears when updating wallpaper via shortcut.
/// Shows countdown timer, progress circle, and handles success/error states.
struct WallpaperUpdateLoadingView: View {
    @Binding var isPresented: Bool
    @Binding var showTroubleshooting: Bool
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    @State private var timer: Timer?
    @State private var startTime: Date = Date()
    @State private var didGoToBackground: Bool = false
    
    // Animation states
    @State private var progressRotation: Double = 0
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var checkmarkOpacity: Double = 0
    @State private var errorShake: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var progress: Double = 0.0
    @State private var remainingSeconds: Int = 10
    
    private let timeoutDuration: TimeInterval = 25.0
    private let expectedDuration: TimeInterval = 10.0
    
    
    var body: some View {
        ZStack {
            // Semi-transparent overlay to dim the homepage
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // Prevent dismissal by tapping outside
                }
            
            if showSuccess {
                successView
                    .transition(.scale.combined(with: .opacity))
            } else if showError {
                errorView
                    .transition(.scale.combined(with: .opacity))
            } else {
                loadingView
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            startLoading()
        }
        .onDisappear {
            cleanup()
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutWallpaperApplied)) { _ in
            // Notification received from shortcut! Trigger success immediately
            let elapsed = Date().timeIntervalSince(startTime)
            print("🎉 WallpaperUpdateLoading: Received .shortcutWallpaperApplied notification at \(elapsed)s - triggering success!")
            handleSuccess()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Backup detection: if app returns to foreground after being backgrounded
            handleAppReturnToForeground()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 22) {
                ZStack {
                    // Outer subtle glow
                    Circle()
                        .fill(Color.appAccent.opacity(0.08))
                        .frame(width: 88, height: 88)
                        .scaleEffect(pulseScale)
                    
                    // Background track
                    Circle()
                        .stroke(Color.appAccent.opacity(0.15), lineWidth: 5)
                        .frame(width: 76, height: 76)
                    
                    // Progress circle that fills up
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color.appAccent,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(-90)) // Start from top
                        .shadow(color: Color.appAccent.opacity(0.4), radius: 6, x: 0, y: 2)
                    
                    // Countdown number in center
                    VStack(spacing: 2) {
                        Text("\(remainingSeconds)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("sec")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Status text
                Text("Updating wallpaper...")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 48)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.3), radius: 28, x: 0, y: 14)
            )
            
            // Cancel X button
            Button(action: handleCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.systemGray))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color(.systemGray5))
                    )
            }
            .offset(x: -8, y: 8)
        }
        .padding(32)
    }
    
    private func handleCancel() {
        // Light impact haptic for cancel
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        print("❌ WallpaperUpdateLoading: User cancelled loading")
        
        // Cleanup and dismiss
        cleanup()
        
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
    }
    
    // MARK: - Success View
    
    private var successView: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outer glow effect
                Circle()
                    .fill(Color.appAccent.opacity(0.12))
                    .frame(width: 72, height: 72)
                    .blur(radius: 10)
                
                // Success circle background
                Circle()
                    .fill(Color.appAccent)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                
                // Checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.white)
                    .scaleEffect(checkmarkScale)
                    .opacity(checkmarkOpacity)
            }
            
            Text("Wallpaper Updated!")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 40)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.25), radius: 25, x: 0, y: 12)
        )
        .padding(32)
        .onAppear {
            animateSuccess()
        }
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 24) {
            ZStack {
                // Error circle background
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 3)
                    .frame(width: 120, height: 120)
                
                // Error icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.red)
                    .offset(x: errorShake)
            }
            .padding(.top, 48)
            
            VStack(spacing: 12) {
                Text("Update Timed Out")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("The wallpaper update took longer than expected. This might be a setup issue.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            
            VStack(spacing: 12) {
                // Troubleshooting button
                Button(action: {
                    // Medium impact haptic
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    isPresented = false
                    // Small delay to let the overlay dismiss
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showTroubleshooting = true
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Get Help & Fix This")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.appAccent, Color.appAccent.opacity(0.9)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                
                // Dismiss button
                Button(action: {
                    // Light impact haptic
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    
                    isPresented = false
                }) {
                    Text("Dismiss")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 15)
        )
        .padding(32)
        .onAppear {
            animateError()
        }
    }
    
    // MARK: - Timer & Loading Management
    
    private func startLoading() {
        startTime = Date()
        
        // Subtle breathing pulse effect
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.12
        }
        
        // Smooth progress animation from 0 to 1 over expected duration
        withAnimation(.linear(duration: expectedDuration)) {
            progress = 1.0
        }
        
        // Timer to update countdown and check timeout
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            
            // Update countdown (8, 7, 6... down to 0)
            let remaining = max(0, Int(ceil(expectedDuration - elapsed)))
            if remaining != remainingSeconds {
                // Haptic feedback on each second change
                if remaining > 0 && remaining < Int(expectedDuration) {
                    let generator = UIImpactFeedbackGenerator(style: .soft)
                    generator.impactOccurred(intensity: 0.3)
                }
                remainingSeconds = remaining
            }
            
            // Check for timeout at 25 seconds
            if elapsed >= timeoutDuration {
                handleTimeout()
            }
        }
    }
    
    // MARK: - State Handlers
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .background {
            // App went to background (shortcut is running)
            didGoToBackground = true
            print("📱 WallpaperUpdateLoading: App went to background (shortcut running)")
        } else if newPhase == .active {
            print("📱 WallpaperUpdateLoading: App became active")
        }
    }
    
    private func handleAppReturnToForeground() {
        // Only treat as success if we actually went to background first
        // AND haven't already shown success/error
        guard didGoToBackground, !showSuccess, !showError else {
            return
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // If we returned within reasonable time (< timeout), we can assume success
        // But prioritize the notification - this is just a backup
        if elapsed >= 2.0 && elapsed < timeoutDuration {
            print("🔄 WallpaperUpdateLoading: App returned to foreground (backup success trigger)")
            // Longer delay to allow notification to arrive first
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Only trigger if notification hasn't already triggered success
                if !self.showSuccess && !self.showError {
                    print("✅ WallpaperUpdateLoading: Backup success trigger activated")
                    self.handleSuccess()
                }
            }
        }
    }
    
    func handleSuccess() {
        guard !showSuccess && !showError else {
            print("⚠️ WallpaperUpdateLoading: Ignoring success (already showing success=\(showSuccess) or error=\(showError))")
            return
        }
        
        print("✅ WallpaperUpdateLoading: Showing success animation!")
        
        cleanup()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showSuccess = true
        }
        
        // Auto-dismiss after 1 second (shortened for better UX)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                isPresented = false
            }
        }
    }
    
    private func handleTimeout() {
        // Don't show error if success already shown
        guard !showSuccess && !showError else {
            return
        }
        
        print("⏰ WallpaperUpdateLoading: Timeout reached at 25 seconds, showing error")
        cleanup()
        
        // Error notification haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showError = true
        }
    }
    
    // MARK: - Animations
    
    private func animateSuccess() {
        // Play success sound
        AudioServicesPlaySystemSound(1519) // Success sound
        
        // Medium impact haptic - refined for minimalist design
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.prepare()
        impactGenerator.impactOccurred()
        
        // Animate checkmark with smooth spring
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }
        }
    }
    
    private func animateError() {
        // Shake animation
        withAnimation(.default.repeatCount(3, autoreverses: true).speed(4)) {
            errorShake = 8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            errorShake = 0
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        timer?.invalidate()
        timer = nil
        
        // Stop any ongoing animations
        withAnimation(.none) {
            pulseScale = 1.0
        }
    }
}

#Preview {
    WallpaperUpdateLoadingView(
        isPresented: .constant(true),
        showTroubleshooting: .constant(false)
    )
    .preferredColorScheme(.dark)
}

