import SwiftUI
import RevenueCat

// MARK: - Apology View
/// Mandatory apology + migration screen shown to existing premium users after the update.
/// Users MUST proceed through this flow — there is no way to dismiss or skip it.
/// Flow: ApologyView → MigrationConfirmView → OnboardingView (migration) → MigrationThankYouView
/// New users never see this because completeOnboarding() marks it as shown.

struct ApologyView: View {
    
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)? = nil
    
    // MARK: - Animation States
    @State private var bgGlow: Double = 0.3
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.8
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var messageOpacity: Double = 0
    @State private var messageOffset: CGFloat = 16
    @State private var row1Opacity: Double = 0
    @State private var row1Offset: CGFloat = 20
    @State private var row2Opacity: Double = 0
    @State private var row2Offset: CGFloat = 20
    @State private var row3Opacity: Double = 0
    @State private var row3Offset: CGFloat = 20
    @State private var buttonOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 12
    @State private var shimmerX: CGFloat = -200
    
    private var isCompact: Bool {
        ScreenDimensions.height < 750
    }
    
    // Count user's saved notes to reassure them
    private var savedNotesCount: Int {
        guard let data = UserDefaults.standard.data(forKey: "savedNotes"),
              let notes = try? JSONDecoder().decode([Note].self, from: data) else {
            return 0
        }
        return notes.count
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background (matches onboarding dark gradient)
            backgroundView
                .ignoresSafeArea()
            
            // Subtle floating particles
            ApologyParticlesView()
                .ignoresSafeArea()
                .opacity(0.4)
            
            VStack(spacing: 0) {
                Spacer()
                
                // MARK: - Apology Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent.opacity(0.25), Color.appAccent.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isCompact ? 90 : 110, height: isCompact ? 90 : 110)
                    
                    Image(systemName: "heart.text.clipboard")
                        .font(.system(size: isCompact ? 40 : 50, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appAccent.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .opacity(logoOpacity)
                .scaleEffect(logoScale)
                .padding(.bottom, isCompact ? 20 : 28)
                
                // MARK: - Title
                Text(NSLocalizedString("We Owe You an Apology", comment: ""))
                    .font(.system(size: isCompact ? 26 : 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)
                    .padding(.bottom, isCompact ? 8 : 12)
                
                // MARK: - Short message
                Text(NSLocalizedString("You might have experienced a bug that prevented your wallpaper from updating. That's on us — let's get you back on track.", comment: ""))
                    .font(.system(size: isCompact ? 15 : 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .opacity(messageOpacity)
                    .offset(y: messageOffset)
                    .padding(.horizontal, 24)
                
                Spacer()
                    .frame(height: isCompact ? 28 : 40)
                
                // MARK: - Reassurance bullets
                VStack(spacing: isCompact ? 14 : 18) {
                    reassuranceRow(
                        icon: "checkmark.shield.fill",
                        iconColor: .green,
                        text: NSLocalizedString("Your premium is safe", comment: "")
                    )
                    .opacity(row1Opacity)
                    .offset(y: row1Offset)
                    
                    reassuranceRow(
                        icon: "note.text",
                        iconColor: Color("AppAccent"),
                        text: savedNotesCount > 0
                            ? (savedNotesCount == 1 
                                ? String(format: NSLocalizedString("Your %lld note is still here", comment: ""), savedNotesCount)
                                : String(format: NSLocalizedString("Your %lld notes are still here", comment: ""), savedNotesCount))
                            : NSLocalizedString("Your notes are still here", comment: "")
                    )
                    .opacity(row2Opacity)
                    .offset(y: row2Offset)
                    
                    reassuranceRow(
                        icon: "clock.fill",
                        iconColor: Color("AppAccent"),
                        text: NSLocalizedString("1-minute fix, then you're done", comment: "")
                    )
                    .opacity(row3Opacity)
                    .offset(y: row3Offset)
                }
                
                Spacer()
                
                // MARK: - CTA (mandatory — no X button, no dismiss)
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    AnalyticsService.shared.logEvent(.custom(name: "apology_fix_now_tapped", parameters: [:]))
                    ApologyManager.shared.markAsShown()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onDismiss?()
                    }
                }) {
                    ZStack {
                        HStack(spacing: 8) {
                            Text(NSLocalizedString("Fix It Now", comment: ""))
                                .font(.system(size: isCompact ? 17 : 18, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.15), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 80)
                            .offset(x: shimmerX)
                            .mask(RoundedRectangle(cornerRadius: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompact ? 54 : 58)
                    .background(
                        LinearGradient(
                            colors: [Color("AppAccent"), Color("AppAccent").opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color("AppAccent").opacity(0.4), radius: 16, x: 0, y: 8)
                }
                .opacity(buttonOpacity)
                .offset(y: buttonOffset)
                .padding(.horizontal, 28)
                .padding(.bottom, isCompact ? 36 : 52)
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            startAnimations()
            AnalyticsService.shared.trackScreenView(screenName: "migration_1_apology")
            AnalyticsService.shared.logEvent(
                .custom(name: "apology_screen_shown", parameters: [
                    "is_premium": PaywallManager.shared.isPremium,
                    "notes_count": savedNotesCount
                ])
            )
        }
    }
    
    // MARK: - Reassurance Row
    
    private func reassuranceRow(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            .frame(width: 38, alignment: .center)
            
            Text(text)
                .font(.system(size: isCompact ? 15 : 16, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            // Matches onboarding dark gradient
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.08), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Top accent glow
            RadialGradient(
                gradient: Gradient(colors: [
                    Color("AppAccent").opacity(bgGlow * 0.12),
                    Color.clear
                ]),
                center: .top,
                startRadius: 20,
                endRadius: 400
            )
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        // Background glow breathing
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            bgGlow = 0.5
        }
        
        // Logo
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.2)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }
        
        // Title
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5)) {
            titleOpacity = 1.0
            titleOffset = 0
        }
        
        // Message
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.7)) {
            messageOpacity = 1.0
            messageOffset = 0
        }
        
        // Staggered reassurance rows
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.0)) {
            row1Opacity = 1.0
            row1Offset = 0
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.2)) {
            row2Opacity = 1.0
            row2Offset = 0
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.4)) {
            row3Opacity = 1.0
            row3Offset = 0
        }
        
        // Button entrance
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.8)) {
            buttonOpacity = 1.0
            buttonOffset = 0
        }
        
        // Button shimmer
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                shimmerX = 200
            }
        }
    }
}

// MARK: - Apology Particles View

struct ApologyParticlesView: View {
    
    @State private var animationPhase: CGFloat = 0
    
    private let particleCount = 15
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                for i in 0..<particleCount {
                    let seed = Double(i) * 137.508 // Golden angle
                    let normalizedX = (Double(i) / Double(particleCount)) + CoreGraphics.sin(time * 0.2 + seed) * 0.08
                    let baseY = (time * 0.015 + seed * 0.1).truncatingRemainder(dividingBy: 1.2)
                    let y = baseY - 0.1
                    
                    let posX: CGFloat = CGFloat(normalizedX) * size.width
                    let posY: CGFloat = CGFloat(y) * size.height
                    
                    let alpha: CGFloat = CGFloat(0.15 + CoreGraphics.sin(time + seed) * 0.1)
                    let radius: CGFloat = CGFloat(1.5 + CoreGraphics.sin(time * 0.5 + seed) * 0.8)
                    
                    let rect = CGRect(
                        x: posX - radius,
                        y: posY - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    
                    let color = i % 3 == 0
                        ? Color("AppAccent").opacity(Double(alpha))
                        : Color.white.opacity(Double(alpha) * 0.5)
                    
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(color)
                    )
                }
            }
        }
    }
}

// MARK: - Migration Confirmation View
/// Shows after the apology. Explains the 3-step fix process.
/// Non-dismissible — user must proceed.

struct MigrationConfirmView: View {
    @Binding var isPresented: Bool
    var onConfirm: () -> Void

    @State private var iconRotation: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 16
    @State private var step1Opacity: Double = 0
    @State private var step1Offset: CGFloat = 24
    @State private var step2Opacity: Double = 0
    @State private var step2Offset: CGFloat = 24
    @State private var step3Opacity: Double = 0
    @State private var step3Offset: CGFloat = 24
    @State private var buttonOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 12
    @State private var shimmerX: CGFloat = -200
    @State private var iconGlowRadius: CGFloat = 10
    @State private var iconGlowOpacity: Double = 0.15
    @State private var bgGlow: Double = 0.3
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0
    @State private var stepCheckScale: [CGFloat] = [0.5, 0.5, 0.5]

    private var isCompact: Bool { ScreenDimensions.isCompactDevice }

    var body: some View {
        ZStack {
            // Background (matches onboarding)
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.04, blue: 0.08), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color("AppAccent").opacity(bgGlow * 0.10),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 20,
                    endRadius: 350
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon with glow rings
                ZStack {
                    // Pulsing ring
                    Circle()
                        .stroke(Color("AppAccent").opacity(ringOpacity * 0.15), lineWidth: 1)
                        .frame(width: isCompact ? 120 : 140, height: isCompact ? 120 : 140)
                        .scaleEffect(ringScale)
                    
                    Circle()
                        .fill(Color("AppAccent").opacity(iconGlowOpacity))
                        .frame(width: isCompact ? 100 : 120, height: isCompact ? 100 : 120)
                        .blur(radius: 8)

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: isCompact ? 44 : 52, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color("AppAccent"), Color("AppAccent").opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color("AppAccent").opacity(0.5), radius: iconGlowRadius, x: 0, y: 4)
                        .rotationEffect(.degrees(iconRotation))
                }
                .padding(.bottom, isCompact ? 24 : 32)

                // Title + subtitle
                VStack(spacing: isCompact ? 10 : 14) {
                    Text(NSLocalizedString("Here's the Plan", comment: ""))
                        .font(.system(size: isCompact ? 26 : 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 10) {
                        Text(NSLocalizedString("We'll reinstall your shortcut.\nYour notes stay exactly as they are.", comment: ""))
                            .font(.system(size: isCompact ? 16 : 17))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                        
                        Text(NSLocalizedString("Don't worry — the flow will seem like the original setup you've done already, but just bear with us for this one. Your subscription will stay the same.", comment: ""))
                            .font(.system(size: isCompact ? 14 : 15))
                            .foregroundColor(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 8)
                    }
                }
                .opacity(titleOpacity)
                .offset(y: titleOffset)

                Spacer()
                    .frame(height: isCompact ? 32 : 44)

                // Step-by-step preview
                VStack(spacing: isCompact ? 14 : 16) {
                    stepRow(number: "1", text: NSLocalizedString("Install the new shortcut", comment: ""), index: 0)
                        .opacity(step1Opacity)
                        .offset(y: step1Offset)
                    
                    stepRow(number: "2", text: NSLocalizedString("Allow one permission", comment: ""), index: 1)
                        .opacity(step2Opacity)
                        .offset(y: step2Offset)
                    
                    stepRow(number: "3", text: NSLocalizedString("Done — wallpapers update automatically", comment: ""), index: 2)
                        .opacity(step3Opacity)
                        .offset(y: step3Offset)
                }

                Spacer()

                // CTA Button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    AnalyticsService.shared.logEvent(.custom(name: "migration_confirm_accepted", parameters: [:]))
                    isPresented = false
                    onConfirm()
                }) {
                    ZStack {
                        HStack(spacing: 8) {
                            Text(NSLocalizedString("Let's Fix It", comment: ""))
                                .font(.system(size: isCompact ? 17 : 18, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)

                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.15), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 80)
                            .offset(x: shimmerX)
                            .mask(RoundedRectangle(cornerRadius: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompact ? 54 : 58)
                    .background(
                        LinearGradient(
                            colors: [Color("AppAccent"), Color("AppAccent").opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color("AppAccent").opacity(0.4), radius: 16, x: 0, y: 8)
                }
                .opacity(buttonOpacity)
                .offset(y: buttonOffset)
                .padding(.horizontal, 28)
                .padding(.bottom, isCompact ? 36 : 52)
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            AnalyticsService.shared.trackScreenView(screenName: "migration_2_confirm_setup")
            startAnimations()
        }
    }

    private func stepRow(number: String, text: String, index: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color("AppAccent").opacity(0.15))
                    .frame(width: 34, height: 34)
                
                Text(number)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color("AppAccent"))
            }
            .scaleEffect(stepCheckScale[index])

            Text(text)
                .font(.system(size: isCompact ? 15 : 16, weight: .medium))
                .foregroundColor(.white.opacity(0.85))

            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    private func startAnimations() {
        // Background glow breathing
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            bgGlow = 0.5
        }
        
        // Icon slow rotation
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            iconRotation = 360
        }
        
        // Icon glow breathing
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.5)) {
            iconGlowRadius = 22
            iconGlowOpacity = 0.25
        }
        
        // Ring pulse
        withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
            ringScale = 1.4
            ringOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(1.5)) {
            ringScale = 1.5
            ringOpacity = 0.0
        }
        
        // Title fade + slide
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
            titleOpacity = 1.0
            titleOffset = 0
        }
        
        // Staggered step rows
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.5)) {
            step1Opacity = 1.0
            step1Offset = 0
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.5)) {
            stepCheckScale[0] = 1.0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.7)) {
            step2Opacity = 1.0
            step2Offset = 0
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.7)) {
            stepCheckScale[1] = 1.0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.9)) {
            step3Opacity = 1.0
            step3Offset = 0
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.9)) {
            stepCheckScale[2] = 1.0
        }
        
        // Button entrance
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.2)) {
            buttonOpacity = 1.0
            buttonOffset = 0
        }
        
        // Button shimmer
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                shimmerX = 200
            }
        }
    }
}

// MARK: - Migration Thank You View
/// Final screen after successful migration. Shows confetti and confirmation.

struct MigrationThankYouView: View {
    @Binding var isPresented: Bool
    
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 16
    @State private var row1Opacity: Double = 0
    @State private var row1Offset: CGFloat = 20
    @State private var row2Opacity: Double = 0
    @State private var row2Offset: CGFloat = 20
    @State private var row3Opacity: Double = 0
    @State private var row3Offset: CGFloat = 20
    @State private var buttonOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 12
    @State private var shimmerX: CGFloat = -200
    @State private var bgGlow: Double = 0.3
    @State private var confettiTrigger = 0
    @State private var iconFloat: CGFloat = 0
    @State private var checkmarkScale: CGFloat = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0
    
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        ZStack {
            // Background
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.04, blue: 0.08), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color("AppAccent").opacity(bgGlow * 0.15),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 20,
                    endRadius: 400
                )
            }
            .ignoresSafeArea()
            
            // Confetti
            ConfettiView(trigger: $confettiTrigger)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            VStack(spacing: 0) {
                Spacer()
                
                // Icon
                ZStack {
                    // Pulsing ring
                    Circle()
                        .stroke(Color("AppAccent").opacity(ringOpacity * 0.15), lineWidth: 1)
                        .frame(width: 140, height: 140)
                        .scaleEffect(ringScale)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color("AppAccent").opacity(0.15),
                                    Color("AppAccent").opacity(0.03),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 5,
                                endRadius: 65
                            )
                        )
                        .frame(width: isCompact ? 110 : 130, height: isCompact ? 110 : 130)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: isCompact ? 52 : 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color("AppAccent"), Color("AppAccent").opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color("AppAccent").opacity(0.5), radius: 16, x: 0, y: 4)
                        .scaleEffect(iconScale)
                        .offset(y: iconFloat)
                }
                .opacity(iconOpacity)
                .padding(.bottom, isCompact ? 24 : 32)
                
                // Title
                VStack(spacing: isCompact ? 10 : 14) {
                    Text(NSLocalizedString("You're All Set!", comment: ""))
                        .font(.system(size: isCompact ? 28 : 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(NSLocalizedString("Thanks for bearing with us.\nEverything works now.", comment: ""))
                        .font(.system(size: isCompact ? 16 : 17))
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .opacity(titleOpacity)
                .offset(y: titleOffset)
                
                Spacer()
                    .frame(height: isCompact ? 28 : 40)
                
                // Confirmation bullets
                VStack(spacing: isCompact ? 14 : 18) {
                    thankYouRow(icon: "bolt.fill", text: NSLocalizedString("New system is active", comment: ""))
                        .opacity(row1Opacity)
                        .offset(y: row1Offset)
                    
                    thankYouRow(icon: "crown.fill", text: NSLocalizedString("Premium fully restored", comment: ""))
                        .opacity(row2Opacity)
                        .offset(y: row2Offset)
                    
                    thankYouRow(icon: "lock.shield.fill", text: NSLocalizedString("Lock screen updates automatically", comment: ""))
                        .opacity(row3Opacity)
                        .offset(y: row3Offset)
                }
                
                Spacer()
                
                // Done button
                Button(action: {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    AnalyticsService.shared.logEvent(.custom(name: "migration_thank_you_done", parameters: [:]))
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }) {
                    ZStack {
                        Text(NSLocalizedString("Back to My Notes", comment: ""))
                            .font(.system(size: isCompact ? 17 : 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.15), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 80)
                            .offset(x: shimmerX)
                            .mask(RoundedRectangle(cornerRadius: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompact ? 54 : 58)
                    .background(
                        LinearGradient(
                            colors: [Color("AppAccent"), Color("AppAccent").opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color("AppAccent").opacity(0.4), radius: 16, x: 0, y: 8)
                }
                .opacity(buttonOpacity)
                .offset(y: buttonOffset)
                .padding(.horizontal, 28)
                .padding(.bottom, isCompact ? 36 : 52)
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            AnalyticsService.shared.trackScreenView(screenName: "migration_4_thank_you")
            startAnimations()
        }
    }
    
    private func thankYouRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 38, height: 38)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.green)
            }
            .frame(width: 38, alignment: .center)
            
            Text(text)
                .font(.system(size: isCompact ? 15 : 16, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
            
            Spacer()
            
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.green.opacity(0.8))
                .scaleEffect(checkmarkScale)
        }
        .padding(.horizontal, 32)
    }
    
    private func startAnimations() {
        // Background glow
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            bgGlow = 0.6
        }
        
        // Icon spring entrance
        withAnimation(.spring(response: 0.7, dampingFraction: 0.55).delay(0.15)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        
        // Ring pulse
        withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
            ringScale = 1.5
            ringOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(1.5)) {
            ringScale = 1.6
            ringOpacity = 0.0
        }
        
        // Float
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.8)) {
            iconFloat = -6
        }
        
        // Title
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
            titleOpacity = 1.0
            titleOffset = 0
        }
        
        // Staggered rows
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8)) {
            row1Opacity = 1.0
            row1Offset = 0
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.0)) {
            row2Opacity = 1.0
            row2Offset = 0
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.2)) {
            row3Opacity = 1.0
            row3Offset = 0
        }
        
        // Checkmarks pop in
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(1.3)) {
            checkmarkScale = 1.0
        }
        
        // Confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            confettiTrigger += 1
        }
        
        // Button entrance
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.5)) {
            buttonOpacity = 1.0
            buttonOffset = 0
        }
        
        // Shimmer
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                shimmerX = 200
            }
        }
    }
}

// MARK: - Apology Manager

class ApologyManager: ObservableObject {
    static let shared = ApologyManager()
    
    @Published var shouldShowApology = false
    
    private let apologyShownKey = "ApologyShown_BugFix_v1.5.0"
    private let hasCompletedSetupKey = "hasCompletedSetup"
    
    // 🚨 DEBUG MODE: Set to true to FORCE show the apology for testing
    // ⚠️ MUST be set to false before production release!
    private let debugForceShow = false
    
    private init() {}
    
    /// Whether the apology has already been shown
    var hasBeenShownOnce: Bool {
        UserDefaults.standard.bool(forKey: apologyShownKey)
    }
    
    /// Check if user has completed initial setup (existing user)
    var hasCompletedSetup: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedSetupKey)
    }
    
    /// Cutoff date: February 9th, 2026 at 00:00:00
    private var pipelineCutoffDate: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 9
        components.hour = 0
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }
    
    /// Whether the user installed before the pipeline cutoff
    var isPreCutoffUser: Bool {
        let installDate = UserDefaults.standard.object(forKey: "analytics_install_date") as? Date ?? Date()
        return installDate < pipelineCutoffDate
    }
    
    /// Whether the user is a premium subscriber
    var isPremium: Bool {
        PaywallManager.shared.isPremium
    }
    
    /// RevenueCat user IDs excluded from the apology flow
    private let excludedUserIDs: Set<String> = [
        "$RCAnonymousID:7c8905e38de54ad9b7f9f7d6135bf451"
    ]
    
    /// Determines if the apology screen should be shown
    /// - Only shows to users who installed BEFORE February 9th, 2026
    /// - Only shows to PREMIUM users (they paid and the bug affected them)
    /// - Only shows to users who have completed setup
    /// - Only shows ONCE EVER
    /// - Excludes specific RevenueCat user IDs
    func checkShouldShow() -> Bool {
        #if DEBUG
        if debugForceShow {
            print("🚨 ApologyManager: DEBUG MODE - Forcing apology to show for testing")
            return true
        }
        #endif
        
        // Already shown once → never show again
        if hasBeenShownOnce {
            #if DEBUG
            print("💝 ApologyManager: Already shown once - never showing again")
            #endif
            return false
        }
        
        // Exclude specific RevenueCat user IDs
        // Purchases.shared.appUserID is available immediately after RC configuration (no network needed)
        let currentRCUserID = Purchases.shared.appUserID
        if excludedUserIDs.contains(currentRCUserID) {
            #if DEBUG
            print("💝 ApologyManager: Excluded RevenueCat user \(currentRCUserID) - skipping apology")
            #endif
            return false
        }
        // Also check customerInfo in case the ID format differs
        if let rcUserID = PaywallManager.shared.customerInfo?.originalAppUserId,
           excludedUserIDs.contains(rcUserID) {
            #if DEBUG
            print("💝 ApologyManager: Excluded RevenueCat user \(rcUserID) - skipping apology")
            #endif
            return false
        }
        
        // Must have completed setup (existing user)
        guard hasCompletedSetup else {
            #if DEBUG
            print("💝 ApologyManager: User hasn't completed setup - skipping apology")
            #endif
            return false
        }
        
        // NOTE: We removed the install-date check (isPreCutoffUser) because
        // analytics_install_date was often missing, causing the check to silently fail.
        // Instead, we show the apology to ALL existing premium users who haven't seen it.
        // New users who become premium through onboarding are protected because
        // completeOnboarding() calls markAsShown() immediately.
        
        // Must be premium (they paid and were affected by the bug)
        guard isPremium else {
            #if DEBUG
            print("💝 ApologyManager: Not premium - skipping apology")
            #endif
            return false
        }
        
        #if DEBUG
        print("💝 ApologyManager: Showing apology to existing premium user")
        #endif
        return true
    }
    
    /// Mark the apology as shown - permanently prevents it from showing again
    func markAsShown() {
        UserDefaults.standard.set(true, forKey: apologyShownKey)
        shouldShowApology = false
        
        #if DEBUG
        print("💝 ApologyManager: Marked as shown PERMANENTLY")
        #endif
    }
    
    /// Reset for testing
    func resetForTesting() {
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: apologyShownKey)
        print("💝 ApologyManager: Reset for testing")
        #endif
    }
}

// MARK: - Preview

#Preview {
    ApologyView(isPresented: .constant(true))
}
