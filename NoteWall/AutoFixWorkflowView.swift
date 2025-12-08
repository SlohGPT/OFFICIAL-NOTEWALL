import SwiftUI

/// Automated troubleshooting workflow that attempts to fix common issues in ~30 seconds.
/// Part of the exit-intercept strategy to help users before they uninstall.
struct AutoFixWorkflowView: View {
    
    // MARK: - Environment & State
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: FixStep = .welcome
    @State private var animateIn = false
    @State private var pulseGlow = false
    @State private var progress: Double = 0
    @State private var isFixing = false
    @State private var completedSteps: Set<FixStep> = []
    @State private var detectedIssues: [String] = []
    @State private var fixedIssues: [String] = []
    
    // MARK: - Fix Steps
    
    enum FixStep: Int, CaseIterable, Identifiable {
        case welcome = 0
        case verifyingShortcut = 1
        case regeneratingWallpaper = 2
        case checkingPermissions = 3
        case complete = 4
        case failed = 5
        
        var id: Int { rawValue }
        
        var title: String {
            switch self {
            case .welcome:
                return "Auto-Fix Ready"
            case .verifyingShortcut:
                return "Verifying Shortcut"
            case .regeneratingWallpaper:
                return "Regenerating Wallpaper"
            case .checkingPermissions:
                return "Checking Permissions"
            case .complete:
                return "All Fixed! ✨"
            case .failed:
                return "Need Manual Help"
            }
        }
        
        var description: String {
            switch self {
            case .welcome:
                return "We'll automatically check and fix common issues. This takes about 30 seconds."
            case .verifyingShortcut:
                return "Checking if the shortcut is properly installed..."
            case .regeneratingWallpaper:
                return "Creating a fresh wallpaper with your notes..."
            case .checkingPermissions:
                return "Verifying folder access and permissions..."
            case .complete:
                return "Everything is working perfectly now! Your wallpaper should be updated."
            case .failed:
                return "We couldn't fix everything automatically. Let's get you personal help."
            }
        }
        
        var icon: String {
            switch self {
            case .welcome:
                return "wand.and.stars"
            case .verifyingShortcut:
                return "link"
            case .regeneratingWallpaper:
                return "photo.on.rectangle"
            case .checkingPermissions:
                return "checkmark.shield.fill"
            case .complete:
                return "checkmark.circle.fill"
            case .failed:
                return "exclamationmark.triangle.fill"
            }
        }
        
        var progressValue: Double {
            switch self {
            case .welcome:
                return 0
            case .verifyingShortcut:
                return 0.33
            case .regeneratingWallpaper:
                return 0.66
            case .checkingPermissions:
                return 0.85
            case .complete:
                return 1.0
            case .failed:
                return 1.0
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            autoFixBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                Spacer()
                
                // Main content based on current step
                Group {
                    switch currentStep {
                    case .welcome:
                        welcomeView
                    case .verifyingShortcut, .regeneratingWallpaper, .checkingPermissions:
                        progressView
                    case .complete:
                        completeView
                    case .failed:
                        failedView
                    }
                }
                .frame(maxHeight: .infinity)
                
                Spacer()
                
                // Action button
                actionButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateIn = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
    }
    
    // MARK: - Background
    
    private var autoFixBackground: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.08),
                    Color(red: 0.01, green: 0.01, blue: 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Accent glow orbs
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.2), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: -120, y: -280)
                .blur(radius: 50)
                .opacity(pulseGlow ? 0.8 : 0.5)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .offset(x: 140, y: 400)
                .blur(radius: 40)
                .opacity(pulseGlow ? 0.6 : 0.4)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                
                // Close button (only when not fixing)
                if !isFixing {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        dismiss()
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
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Progress bar (shown during fixing steps)
            if currentStep != .welcome && currentStep != .complete && currentStep != .failed {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        
                        // Progress fill
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.appAccent.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress, height: 4)
                            .shadow(color: Color.appAccent.opacity(0.5), radius: 4, x: 0, y: 0)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 24)
                .opacity(animateIn ? 1 : 0)
            }
        }
    }
    
    // MARK: - Welcome View
    
    private var welcomeView: some View {
        VStack(spacing: 32) {
            // Icon
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.appAccent.opacity(0.2), lineWidth: 2)
                        .frame(width: 100 + CGFloat(i) * 30, height: 100 + CGFloat(i) * 30)
                        .scaleEffect(pulseGlow ? 1.1 : 1.0)
                        .opacity(pulseGlow ? 0.3 : 0.6)
                        .animation(
                            Animation.easeInOut(duration: 2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.2),
                            value: pulseGlow
                        )
                }
                
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: currentStep.icon)
                        .font(.system(size: 44))
                        .foregroundColor(.appAccent)
                }
            }
            .opacity(animateIn ? 1 : 0)
            .scaleEffect(animateIn ? 1 : 0.8)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateIn)
            
            // Title and description
            VStack(spacing: 12) {
                Text(currentStep.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(currentStep.description)
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateIn)
            
            // Steps preview
            VStack(alignment: .leading, spacing: 12) {
                stepPreviewItem(icon: "link", title: "Verify Shortcut Setup")
                stepPreviewItem(icon: "photo.on.rectangle", title: "Regenerate Wallpaper")
                stepPreviewItem(icon: "checkmark.shield.fill", title: "Check Permissions")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
            .opacity(animateIn ? 1 : 0)
            .animation(.easeOut.delay(0.4), value: animateIn)
        }
    }
    
    private func stepPreviewItem(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.appAccent)
            }
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
    }
    
    // MARK: - Progress View
    
    private var progressView: some View {
        VStack(spacing: 32) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: currentStep.icon)
                    .font(.system(size: 50))
                    .foregroundColor(.appAccent)
                    .rotationEffect(.degrees(isFixing ? 360 : 0))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isFixing)
            }
            .opacity(animateIn ? 1 : 0)
            .scaleEffect(animateIn ? 1 : 0.8)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animateIn)
            
            // Title and description
            VStack(spacing: 12) {
                Text(currentStep.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(currentStep.description)
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 20)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: animateIn)
            
            // Spinner
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                .scaleEffect(1.2)
        }
    }
    
    // MARK: - Complete View
    
    private var completeView: some View {
        VStack(spacing: 32) {
            // Success icon with animation
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        .frame(width: 100 + CGFloat(i) * 30, height: 100 + CGFloat(i) * 30)
                        .scaleEffect(animateIn ? 1.2 : 1.0)
                        .opacity(animateIn ? 0.2 : 0.6)
                        .animation(
                            Animation.easeOut(duration: 1.5)
                                .delay(Double(i) * 0.15),
                            value: animateIn
                        )
                }
                
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.green)
                }
                .scaleEffect(animateIn ? 1 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: animateIn)
            }
            
            // Title and description
            VStack(spacing: 12) {
                Text(currentStep.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(currentStep.description)
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 20)
            .animation(.easeOut(duration: 0.5).delay(0.3), value: animateIn)
            
            // Completed steps list
            VStack(spacing: 12) {
                ForEach(fixedIssues, id: \.self) { issue in
                    completedStepItem(title: issue)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.green.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
            .opacity(animateIn ? 1 : 0)
            .animation(.easeOut.delay(0.5), value: animateIn)
        }
    }
    
    private func completedStepItem(title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
        }
    }
    
    // MARK: - Failed View
    
    private var failedView: some View {
        VStack(spacing: 32) {
            // Warning icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: currentStep.icon)
                    .font(.system(size: 44))
                    .foregroundColor(.orange)
            }
            .opacity(animateIn ? 1 : 0)
            .scaleEffect(animateIn ? 1 : 0.8)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateIn)
            
            // Title and description
            VStack(spacing: 12) {
                Text(currentStep.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(currentStep.description)
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateIn)
            
            // Show detected issues
            if !detectedIssues.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Issues found:")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    ForEach(detectedIssues, id: \.self) { issue in
                        Text(issue)
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 32)
                .padding(.top, 16)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut.delay(0.4), value: animateIn)
            }
            
            // Contact support button
            Button(action: contactSupport) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 16))
                    Text("Contact Support")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.appAccent)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.appAccent.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.appAccent.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .opacity(animateIn ? 1 : 0)
            .animation(.easeOut.delay(0.4), value: animateIn)
        }
    }
    
    // MARK: - Action Button
    
    private var actionButton: some View {
        Group {
            if currentStep == .welcome {
                Button(action: startAutoFix) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Start Auto-Fix")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appAccent)
                                .blur(radius: 12)
                                .opacity(0.4)
                                .offset(y: 4)
                            
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appAccent)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .opacity(animateIn ? 1 : 0)
                .scaleEffect(animateIn ? 1 : 0.95)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: animateIn)
                
            } else if currentStep == .complete {
                Button(action: {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    dismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.green)
                        )
                }
                .opacity(animateIn ? 1 : 0)
                .animation(.easeIn.delay(0.6), value: animateIn)
                
            } else if currentStep == .failed {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    dismiss()
                }) {
                    Text("Close")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func startAutoFix() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        isFixing = true
        animateIn = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                animateIn = true
            }
            
            // Start the fix process
            Task {
                await runAutoFixWorkflow()
            }
        }
    }
    
    private func runAutoFixWorkflow() async {
        var allSuccessful = true
        
        // Step 1: Verify shortcut
        await transitionToStep(.verifyingShortcut)
        let shortcutResult = await verifyShortcut()
        completedSteps.insert(.verifyingShortcut)
        
        if !shortcutResult.success {
            allSuccessful = false
            await MainActor.run {
                detectedIssues.append(shortcutResult.issue)
            }
        } else if let fixed = shortcutResult.fixed {
            await MainActor.run {
                fixedIssues.append(fixed)
            }
        }
        
        // Step 2: Regenerate wallpaper
        await transitionToStep(.regeneratingWallpaper)
        let wallpaperResult = await regenerateWallpaper()
        completedSteps.insert(.regeneratingWallpaper)
        
        if !wallpaperResult.success {
            allSuccessful = false
            await MainActor.run {
                detectedIssues.append(wallpaperResult.issue)
            }
        } else if let fixed = wallpaperResult.fixed {
            await MainActor.run {
                fixedIssues.append(fixed)
            }
        }
        
        // Step 3: Check permissions
        await transitionToStep(.checkingPermissions)
        let permissionsResult = await checkPermissions()
        completedSteps.insert(.checkingPermissions)
        
        if !permissionsResult.success {
            allSuccessful = false
            await MainActor.run {
                detectedIssues.append(permissionsResult.issue)
            }
        } else if let fixed = permissionsResult.fixed {
            await MainActor.run {
                fixedIssues.append(fixed)
            }
        }
        
        // Determine result
        await MainActor.run {
            isFixing = false
        }
        
        if allSuccessful {
            await transitionToStep(.complete)
        } else {
            await transitionToStep(.failed)
        }
    }
    
    private func transitionToStep(_ step: FixStep) async {
        await MainActor.run {
            animateIn = false
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        
        await MainActor.run {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentStep = step
                progress = step.progressValue
                animateIn = true
            }
        }
        
        // Wait for step to complete (simulate work)
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s per step
    }
    
    // MARK: - Fix Result
    
    private struct FixResult {
        let success: Bool
        let issue: String
        let fixed: String?
    }
    
    private func verifyShortcut() async -> FixResult {
        // Verify shortcut setup using the verification service
        let verificationResult = ShortcutVerificationService.verifyShortcutSetup()
        
        if verificationResult.isVerified {
            // Shortcut exists and is properly configured
            return FixResult(
                success: true,
                issue: "",
                fixed: "Shortcut is properly installed"
            )
        } else {
            // Shortcut is missing or misconfigured
            let issueMessage: String
            if let errorMessage = verificationResult.errorMessage {
                issueMessage = errorMessage
            } else if !verificationResult.missingChecks.isEmpty {
                issueMessage = verificationResult.missingChecks.first?.userFacingMessage ?? "Shortcut setup incomplete"
            } else {
                issueMessage = "Shortcut not found or not properly configured"
            }
            
            return FixResult(
                success: false,
                issue: "❌ \(issueMessage)",
                fixed: nil
            )
        }
    }
    
    private func regenerateWallpaper() async -> FixResult {
        // Check if wallpaper exists before regeneration
        let existedBefore = HomeScreenImageManager.homeScreenImageExists()
        
        // Trigger wallpaper regeneration
        await MainActor.run {
            let request = WallpaperUpdateRequest(
                skipDeletionPrompt: true,
                trackForPaywall: false,
                showLoadingOverlay: false
            )
            NotificationCenter.default.post(name: .requestWallpaperUpdate, object: request)
        }
        
        // Wait for generation to complete
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s initial wait
        
        // Poll for wallpaper creation (up to 8 seconds)
        var attempts = 0
        let maxAttempts = 8
        var wallpaperExists = false
        
        while attempts < maxAttempts {
            wallpaperExists = HomeScreenImageManager.homeScreenImageExists()
            if wallpaperExists {
                break
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s between checks
            attempts += 1
        }
        
        if wallpaperExists {
            let message = existedBefore ? "Wallpaper regenerated successfully" : "Wallpaper created successfully"
            return FixResult(
                success: true,
                issue: "",
                fixed: message
            )
        } else {
            return FixResult(
                success: false,
                issue: "❌ Wallpaper generation failed or timed out",
                fixed: nil
            )
        }
    }
    
    private func checkPermissions() async -> FixResult {
        // Check if home screen directory is accessible
        guard let homeScreenURL = HomeScreenImageManager.homeScreenImageURL() else {
            return FixResult(
                success: false,
                issue: "❌ Cannot access home screen directory",
                fixed: nil
            )
        }
        
        let fileManager = FileManager.default
        let directoryURL = homeScreenURL.deletingLastPathComponent()
        
        // Check if directory exists
        var isDirectory: ObjCBool = false
        let directoryExists = fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory)
        
        if !directoryExists {
            // Try to create the directory
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                return FixResult(
                    success: true,
                    issue: "",
                    fixed: "Created missing directory structure"
                )
            } catch {
                return FixResult(
                    success: false,
                    issue: "❌ Cannot create required directories: \(error.localizedDescription)",
                    fixed: nil
                )
            }
        }
        
        // Check if directory is writable
        if fileManager.isWritableFile(atPath: directoryURL.path) {
            return FixResult(
                success: true,
                issue: "",
                fixed: "Folder permissions are correct"
            )
        } else {
            return FixResult(
                success: false,
                issue: "❌ No write permission for home screen folder",
                fixed: nil
            )
        }
    }
    
    private func contactSupport() {
        if let url = URL(string: "mailto:iosnotewall@gmail.com?subject=Auto-Fix%20Failed") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    AutoFixWorkflowView()
        .preferredColorScheme(.dark)
}

