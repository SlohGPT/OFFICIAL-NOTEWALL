import SwiftUI
import Combine
import RevenueCat
import AudioToolbox
import StoreKit
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

@available(iOS 15.0, *)
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var paywallManager = PaywallManager.shared
    
    let triggerReason: PaywallTriggerReason
    let allowDismiss: Bool
    private let initialExitInterceptDiscount: Bool // Stored solely for analytics/init
    
    // Dynamic state that can be updated via Quick Actions
    @State private var discountApplied: Bool
    
    @State private var selectedProductIndex = 0  // Default to first package
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animateIn = false
    @State private var currentStep = 1  // 1 = plan selection, 2 = trial explanation
    @State private var showTermsAndPrivacy = false
    @State private var selectedLegalDocument: LegalDocumentType = .termsAndPrivacy
    @State private var promoCode: String = ""
    @State private var showCodeSuccess = false
    @State private var showCodeError = false
    @FocusState private var isCodeFieldFocused: Bool
    @State private var showLifetimeSheet = false
    @State private var showPromoCodeSheet = false
    @State private var hasInitializedPlanSelection = false
    @State private var benefitCarouselIndex = 0
    @State private var isUserDraggingBenefits = false
    @State private var lastManualSwipeTime: Date = Date()
    @State private var showRedemptionInstructions = false
    @State private var copiedPromoCode = false
    @State private var shouldDismissAfterPromoCode = false
    @State private var showOfferCodeRedemption = false
    @State private var isRedeemingCode = false
    @State private var showNotificationPrePrompt = false
    @State private var pendingPackage: Package?
    @State private var particleData: [ParticleData] = []
    @State private var particleAnimationTime: Double = 0
    @State private var showPrivacyOptions = false
    


    private let benefitSlides: [BenefitSlide] = [
        BenefitSlide(
            icon: "sparkles",
            title: "Lock Screen Focus",
            subtitle: "Keep your goals in front of you every single time you pickup your phone to stay locked in."
        ),
        BenefitSlide(
            icon: "checkmark.seal",
            title: "Stay Accountable",
            subtitle: "See your notes, reminders or to-do list up to 498x times a day and never forget things."
        ),
        BenefitSlide(
            icon: "wand.and.rays",
            title: "Instant Exports",
            subtitle: "Create gorgeous NoteWall wallpapers in seconds with unlimited exports."
        )
    ]

    // Create a large enough array (9 sets = 27 items) so users won't notice the jump
    private var loopingBenefitSlides: [BenefitSlide] {
        guard !benefitSlides.isEmpty else { return [] }
        var slides: [BenefitSlide] = []
        for _ in 0..<9 {
            slides.append(contentsOf: benefitSlides)
        }
        return slides
    }
    
    // Calculate the starting index to be in the middle of the array
    private var startingIndex: Int {
        let originalCount = benefitSlides.count
        return originalCount * 4 // Start in the middle (4 sets in, so we have 4 sets before and 4 sets after)
    }

    // @GestureState private var benefitDragOffset: CGFloat = 0 // Unused
    
    private let benefitsAutoScrollTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    private let particleAnimationTimer = Timer.publish(every: 0.033, on: .main, in: .common).autoconnect() // ~30fps for smooth, efficient animation
    
    init(triggerReason: PaywallTriggerReason = .manual, allowDismiss: Bool = true, applyExitInterceptDiscount: Bool = false) {
        self.triggerReason = triggerReason
        self.allowDismiss = allowDismiss
        self.initialExitInterceptDiscount = applyExitInterceptDiscount
        _discountApplied = State(initialValue: applyExitInterceptDiscount)
    }
    
    var body: some View {
        ZStack {
            // Enhanced background with subtle accent glows and floating particles
            paywallBackground
                .ignoresSafeArea()
                .drawingGroup() // Optimize background rendering
            
            // Floating particles (dots) - same as lifetime sheet
            floatingParticles
            
            step1PlanSelection
        }
        .ignoresSafeArea(.all) // Extend background to all edges including bottom
        // Note: Don't use drawingGroup on entire body - it breaks scrolling and interactivity
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Enable Notifications", isPresented: $showNotificationPrePrompt) {
            Button("Allow", role: .none) {
                // Request permission, then purchase
                NotificationManager.shared.requestPermission { _ in
                    if let package = pendingPackage {
                        purchase(package)
                    }
                }
            }
            Button("Not Now", role: .cancel) {
                // Proceed without permission
                if let package = pendingPackage {
                    purchase(package)
                }
            }
        } message: {
            Text("To notify you before your trial ends, we need to send you notifications. Please allow them in the next step.")
        }
        .sheet(isPresented: $showTermsAndPrivacy) {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if selectedLegalDocument == .termsAndPrivacy {
                            // Show EULA and Privacy Policy buttons
                            VStack(spacing: 16) {
                                Text("Legal Documents")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.top, 20)
                                
                                // EULA Button
                                Button(action: {
                                    if let url = URL(string: "https://peat-appendix-c3c.notion.site/END-USER-LICENSE-AGREEMENT-2b7f6a63758f80a58aebf0207e51f7fb?source=copy_link") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Text("End-User License Agreement (EULA)")
                                            .fontWeight(.semibold)
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.appAccent)
                                    .cornerRadius(12)
                                }
                                
                                // Privacy Policy Button
                                Button(action: {
                                    if let url = URL(string: "https://peat-appendix-c3c.notion.site/PRIVACY-POLICY-2b7f6a63758f804cab16f58998d7787e?source=copy_link") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Text("Privacy Policy")
                                            .fontWeight(.semibold)
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.appAccent)
                                    .cornerRadius(12)
                                }
                                
                                // Terms of Use Button
                                Button(action: {
                                    if let url = URL(string: "https://peat-appendix-c3c.notion.site/TERMS-OF-USE-2b7f6a63758f8067a318e16486b16f47?source=copy_link") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Text("Terms of Use")
                                            .fontWeight(.semibold)
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.appAccent)
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal, 20)
                        
                            // Code input field at the bottom
                            VStack(spacing: 12) {
                                Divider()
                                    .padding(.vertical, 8)
                                
                                Text("Have a promo code?")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 12) {
                                    TextField("Enter code", text: $promoCode)
                                        .textFieldStyle(.roundedBorder)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .focused($isCodeFieldFocused)
                                        .submitLabel(.done)
                                        .onSubmit {
                                            validateAndApplyCode()
                                        }
                                    
                                    Button(action: validateAndApplyCode) {
                                        Text("Apply")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(Color.appAccent)
                                            .cornerRadius(8)
                                    }
                                    .disabled(promoCode.isEmpty)
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.bottom, 20)
                        } else {
                            // For other document types, show the content
                            Text(getLegalDocumentContent())
                                .font(.system(.body, design: .default))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                        }
                    }
                }
                .navigationTitle(selectedLegalDocument.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showTermsAndPrivacy = false
                        }
                    }
                }
            }
        }
        .alert("Code Applied!", isPresented: $showCodeSuccess) {
            Button("OK") {
                showTermsAndPrivacy = false
                dismiss()
            }
        } message: {
            Text("Lifetime access has been granted. Enjoy NoteWall+!")
        }
        .alert("Invalid Code", isPresented: $showCodeError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The code you entered is not valid. Please check and try again.")
        }
        .onAppear {
            paywallManager.trackPaywallView()
            
            // Track paywall impression with Mixpanel Analytics
            let paywallId: PaywallId = discountApplied ? .exitIntercept : triggerReasonToPaywallId(triggerReason)
            AnalyticsService.shared.trackPaywallImpression(
                paywallId: paywallId.rawValue,
                trigger: triggerReason.rawValue,
                placement: discountApplied ? "exit_intercept" : nil
            )
            
            // Also track as a screen view for funnel analysis
            AnalyticsService.shared.trackScreenView(
                screenName: "paywall_onboarding",
                screenClass: "PaywallView"
            )
            
            // Track exit-intercept discount view
            if discountApplied {
                CrashReporter.logMessage("Paywall: Exit-intercept 30% discount shown", level: .info)
                CrashReporter.setCustomKey("showed_exit_discount", value: "true")
            }
            
            // Initialize plan selection immediately if packages are already loaded
            initializePlanSelection()
            
            Task {
                await paywallManager.loadOfferings(force: false)
                await paywallManager.refreshCustomerInfo()
                
                // Initialize plan selection after packages are loaded (in case they weren't loaded before)
                await MainActor.run {
                    initializePlanSelection()
                }
            }
            
            // Trigger animations
            withAnimation {
                animateIn = true
            }
        }
        .onChange(of: paywallManager.availablePackages) { _, packages in
            if selectedProductIndex >= packages.count {
                selectedProductIndex = max(0, packages.count - 1)
            }
            initializePlanSelection()
        }
        .onChange(of: paywallManager.isPremium) { _, isPremium in
            // Auto-dismiss paywall when user becomes premium (e.g., after restore or purchase)
            if isPremium {
                dismiss()
            }
        }
        .modifier(OfferCodeRedemptionModifier(
            isPresented: $showOfferCodeRedemption,
            isRedeeming: $isRedeemingCode,
            paywallManager: paywallManager,
            onDismiss: {
                // Dismiss paywall if user now has premium access
                if paywallManager.isPremium {
                    dismiss()
                }
            }
        ))
        .sheet(isPresented: $showLifetimeSheet) {
            LifetimePlanSheet(
                priceText: lifetimePriceText,
                subtitle: lifetimeSubtitleText,
                isAvailable: lifetimePackage != nil,
                onPurchase: {
                    if selectLifetimePackage() {
                        showLifetimeSheet = false
                        handlePurchase()
                    }
                },
                onDismiss: {
                    showLifetimeSheet = false
                }
            )
        }
        .sheet(isPresented: $showPromoCodeSheet) {
            PromoCodeInputView(
                isPresented: $showPromoCodeSheet,
                onSuccess: {
                    // Dismiss promo code sheet first
                    showPromoCodeSheet = false
                    // Set paywall manager flag to false (this will help dismiss the paywall)
                    PaywallManager.shared.shouldShowPaywall = false
                    // Trigger paywall dismissal after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // Post notification to trigger dismissal
                        NotificationCenter.default.post(name: .dismissPaywallAfterPromoCode, object: nil)
                    }
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissPaywallAfterPromoCode)) { _ in
            // Set paywall manager flag to false
            PaywallManager.shared.shouldShowPaywall = false
            // Dismiss lifetime sheet if presented
            showLifetimeSheet = false
            // Trigger dismissal via state variable (which will be handled in onChange)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                shouldDismissAfterPromoCode = true
            }
        }
        .onChange(of: shouldDismissAfterPromoCode) { _, newValue in
            if newValue {
                shouldDismissAfterPromoCode = false
                dismiss()
            }
        }
        .confirmationDialog("Privacy Options", isPresented: $showPrivacyOptions, titleVisibility: .visible) {
            Button("Privacy Policy") {
                if let url = URL(string: "https://peat-appendix-c3c.notion.site/PRIVACY-POLICY-2b7f6a63758f804cab16f58998d7787e?source=copy_link") {
                    UIApplication.shared.open(url)
                }
            }
            
            Button("Redeem Code") {
                showPromoCodeSheet = true
            }
            
            Button("Cancel", role: .cancel) { }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickActionTriggered)) { notification in
            if let actionType = notification.object as? QuickActionsManager.QuickActionType {
                if actionType == .claimDiscount {
                    // Upgrade to discounted paywall in-place
                    if !discountApplied {
                        withAnimation {
                            discountApplied = true
                        }
                        
                        // Re-initialize selection to pick the discounted plan
                        hasInitializedPlanSelection = false
                        initializePlanSelection()
                        
                        // Track the new impression/event
                        CrashReporter.logMessage("Paywall: In-place upgrade to 30% discount via Quick Action", level: .info)
                        AnalyticsService.shared.trackPaywallImpression(
                            paywallId: PaywallId.exitIntercept.rawValue,
                            trigger: "quick_action_upgrade",
                            placement: "exit_intercept"
                        )
                        
                        // Haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                }
            }
        }
    }
    
    // MARK: - Background
    
    private var paywallBackground: some View {
        ZStack {
            // Base dark gradient - matching lifetime sheet
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.12),
                    Color(red: 0.02, green: 0.02, blue: 0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Accent glow orbs - matching lifetime sheet
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
    
    // Floating particles (dots) - smooth animation using linear interpolation
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
                    .opacity(animateIn ? 1 : 0)
            }
        }
        .compositingGroup() // First composite particles
        .drawingGroup() // Then render as single layer for maximum performance
        .allowsHitTesting(false)
        .onAppear {
            if particleData.isEmpty {
                particleData = (0..<12).map { _ in
                    ParticleData(
                        opacity: Double.random(in: 0.1...0.4),
                        size: CGFloat.random(in: 3...8),
                        x: Double.random(in: 0...1),
                        y: Double.random(in: 0...1),
                        duration: Double.random(in: 4...6), // Longer duration for smoother, slower motion
                        delay: Double.random(in: 0...3) // Spread out delays for more natural movement
                    )
                }
            }
        }
        .onReceive(particleAnimationTimer) { _ in
            if animateIn {
                // Smooth continuous animation - increment matches timer interval for consistent speed
                particleAnimationTime += 0.033
            }
        }
    }
    
    // MARK: - Step 1: Plan Selection
    
    private var step1PlanSelection: some View {
        paywallScrollView {
        VStack(spacing: 20) {
                // Close button at top - only show if dismissible
                if allowDismiss {
                    HStack {
                        Spacer()
                        Button(action: {
                            paywallManager.trackPaywallDismiss()
                            
                            // Track paywall close without conversion
                            // Track paywall close without conversion
                            let paywallId = discountApplied ? PaywallId.exitIntercept : triggerReasonToPaywallId(triggerReason)
                            AnalyticsService.shared.trackPaywallClose(
                                paywallId: paywallId.rawValue,
                                converted: false
                            )
                            
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                } else {
                    // Add top padding when close button is hidden (hard paywall)
                    Spacer()
                        .frame(height: 40)
                }
                
                logoHeader
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.85), value: animateIn)
                
                // Exit-intercept discount badge
                if discountApplied {
                    exitInterceptDiscountBadge
                        .opacity(animateIn ? 1 : 0)
                        .scaleEffect(animateIn ? 1 : 0.9)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15), value: animateIn)
                        .padding(.top, 8)
                }
                
                benefitsCarousel
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 24)
                    .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.1), value: animateIn)
                
                // Urgency banner (44% Off Sale + 9 spots remaining)
                // Only show if NOT showing the special offer (exit intercept)
                if !discountApplied {
                    urgencyBanner
                        .padding(.horizontal, 24)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: animateIn)
                }
                
                // Pricing options (Lifetime first, then Monthly)
                pricingSection
                    .padding(.horizontal, 24)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateIn)
                
                // Purchase button
                Button(action: {
                    handlePurchase()
                }) {
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            if isPurchasing || paywallManager.isLoadingOfferings {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(purchaseButtonTitle)
                                .font(.headline)
                                .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .background(Color.appAccent)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Color.appAccent.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 24)
                .disabled(isPurchasing || paywallManager.isLoadingOfferings)
                .opacity(animateIn ? 1 : 0)
                .scaleEffect(animateIn ? 1 : 0.9)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.7), value: animateIn)
                
                // Terms & Privacy and Restore Purchases
                HStack(spacing: 20) {
                    Button("Terms") {
                        if let url = URL(string: "https://peat-appendix-c3c.notion.site/TERMS-OF-USE-2b7f6a63758f8067a318e16486b16f47?source=copy_link") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    
                    Button("EULA") {
                        if let url = URL(string: "https://peat-appendix-c3c.notion.site/END-USER-LICENSE-AGREEMENT-2b7f6a63758f80a58aebf0207e51f7fb") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    
                    Button("Privacy") {
                        showPrivacyOptions = true
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    
                    Button("Restore Purchases") {
                        // Track restore tap
                        AnalyticsService.shared.trackRestoreTap()
                        
                        Task {
                            await paywallManager.restoreRevenueCatPurchases()
                            
                            // Track restore result
                            await MainActor.run {
                                if paywallManager.isPremium {
                                    AnalyticsService.shared.trackRestoreSuccess()
                                } else {
                                    AnalyticsService.shared.trackRestoreFail(errorCode: "no_purchases_found")
                                }
                            }
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, -8)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeIn.delay(0.7), value: animateIn)
        }
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear) // Ensure VStack background is transparent
        }
        .background(Color.clear) // Ensure ScrollView content area is transparent
    }
    
    // MARK: - Step 2: Trial Explanation (REMOVED - No longer using trials)
    
    // This view has been removed as we're switching to lifetime-only purchases
    private var step2TrialExplanation: some View {
        paywallScrollView {
        VStack(spacing: 20) {
                // Close button at top
                HStack {
                    Spacer()
                    Button(action: {
                        paywallManager.trackPaywallDismiss()
                        
                        // Track paywall close without conversion
                        let paywallId = discountApplied ? PaywallId.exitIntercept : triggerReasonToPaywallId(triggerReason)
                        AnalyticsService.shared.trackPaywallClose(
                            paywallId: paywallId.rawValue,
                            converted: false
                        )
                        
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                // Header
                VStack(spacing: 8) {
                    Text("How your free trial works")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                }
                .padding(.horizontal, 24)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateIn)
                
                // Timeline
                trialTimeline
                    .padding(.horizontal, 24)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateIn)
                
                // Value proposition box
                VStack(spacing: 16) {
                    // Guarantee badge
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.appAccent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("100% Risk-Free")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("Cancel anytime during trial.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appAccent.opacity(0.1))
                    .cornerRadius(12)
                    
                }
                .padding(.horizontal, 24)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeIn.delay(0.4), value: animateIn)
                
                // Start trial button with urgency
                VStack(spacing: 12) {
                    Button(action: handlePurchase) {
                        VStack(spacing: 6) {
                            if isPurchasing || paywallManager.isLoadingOfferings {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 18, weight: .bold))
                                    Text(purchaseButtonTitle)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            }
                        }
                        .frame(height: 64)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.appAccent, Color.appAccent.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: Color.appAccent.opacity(0.5), radius: 16, x: 0, y: 8)
                    }
                    .disabled(isPurchasing || paywallManager.isLoadingOfferings)
                    
                }
                .padding(.horizontal, 24)
                .opacity(animateIn ? 1 : 0)
                .scaleEffect(animateIn ? 1 : 0.9)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: animateIn)
                .padding(.top, 8)
                
                // Show all plans button
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = 1
                        animateIn = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            animateIn = true
                        }
                    }
                }) {
                    Text("Show all plans")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeIn.delay(0.6), value: animateIn)
        }
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Pricing Section (iOS 15+)

    private var logoHeader: some View {
        VStack(spacing: 16) {
            AppIconAnimationView(size: 160)
        }
        .padding(.horizontal, 12)
    }
    
    private var exitInterceptDiscountBadge: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.yellow)
                
                Text("🚨🚨 SPECIAL OFFER 🚨🚨")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: Color.appAccent.opacity(0.5), radius: 12, x: 0, y: 4)
            )
            
            Text("30% OFF Lifetime Offer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 16)
        }
    }
    
    private var benefitsCarousel: some View {
        let slides = loopingBenefitSlides
        let originalCount = benefitSlides.count
        let cardHeight: CGFloat = 140
        
        return VStack(spacing: 8) {
            GeometryReader { outerGeometry in
                let screenWidth = outerGeometry.size.width
                let cardWidth: CGFloat = screenWidth - 80 // Narrower card to show adjacent cards on both sides (40pt peek on each side)
                let cardSpacing: CGFloat = 15.4 // Larger gap between cards to reduce needed padding
                let sidePadding = (screenWidth - cardWidth) / 2
                let itemWidth = cardWidth + cardSpacing
                // Calculate offset to center the current card
                // Start position: center the first card (sidePadding)
                // Then shift left by (current index * itemWidth) to bring current card to center
                let baseOffset = sidePadding - CGFloat(benefitCarouselIndex) * itemWidth
                
                HStack(spacing: cardSpacing) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { idx, slide in
                        benefitCard(slide: slide)
                            .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
                            .id("benefit-\(idx)")
                    }
                }
                .zIndex(10)
                .offset(x: baseOffset)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: benefitCarouselIndex)
                .frame(width: screenWidth, height: cardHeight, alignment: .leading)
                .clipped()
                .compositingGroup() // First composite
                .drawingGroup() // Then render as single layer for smooth scrolling

                .onAppear {
                    if benefitCarouselIndex == 0 {
                        benefitCarouselIndex = startingIndex
                    }
                }
            }
            .frame(height: cardHeight)
        }
        .onReceive(benefitsAutoScrollTimer) { _ in
            guard !isUserDraggingBenefits else { return }
            
            // Only auto-scroll if at least 2 seconds have passed since last manual swipe
            let timeSinceLastSwipe = Date().timeIntervalSince(lastManualSwipeTime)
            guard timeSinceLastSwipe >= 2.0 else { return }
            
            // Use transaction to optimize animation
            var transaction = Transaction(animation: .spring(response: 0.45, dampingFraction: 0.85))
            transaction.disablesAnimations = false
            withTransaction(transaction) {
                benefitCarouselIndex = min(benefitCarouselIndex + 1, slides.count - 1)
            }
            stabilizeCarouselIndex(originalCount: originalCount, totalCount: slides.count)
        }
    }
    
    private func handleCarouselDragEnd(
        translation: CGFloat,
        itemWidth: CGFloat,
        originalCount: Int,
        totalCount: Int
    ) {
        let threshold = itemWidth * 0.2
        if translation < -threshold {
            benefitCarouselIndex = min(benefitCarouselIndex + 1, totalCount - 1)
        } else if translation > threshold {
            benefitCarouselIndex = max(benefitCarouselIndex - 1, 0)
        }
        stabilizeCarouselIndex(originalCount: originalCount, totalCount: totalCount)
    }
    
    private func stabilizeCarouselIndex(originalCount: Int, totalCount: Int) {
        guard totalCount > 0 else { return }
        let lowerBound = originalCount * 2
        let upperBound = originalCount * 7
        if benefitCarouselIndex < lowerBound {
            benefitCarouselIndex = originalCount * 5
        } else if benefitCarouselIndex > upperBound {
            benefitCarouselIndex = originalCount * 3
        }
    }
    
    private func benefitCard(slide: BenefitSlide) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: slide.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.appAccent)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.appAccent.opacity(0.12)))
                
                Text(slide.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
            }
            
            Text(slide.subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(3)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 27/255, green: 28/255, blue: 37/255).opacity(0.95))
        )
        .compositingGroup() // Optimize rendering
        .zIndex(10)
    }
    
    // MARK: - Urgency Banner (44% Off Sale + 9 spots remaining)
    
    private var urgencyBanner: some View {
        HStack(spacing: 0) {
            // Left side: Sale badge with sparkle icon
            HStack(spacing: 10) {
                // Sparkle icon with gradient
                ZStack {
                    Image(systemName: "sparkle")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appAccent.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Small sparkles around
                    ForEach(0..<4, id: \.self) { i in
                        Image(systemName: "plus")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(Color.appAccent.opacity(0.7))
                            .offset(
                                x: CGFloat([12, -10, 8, -8][i]),
                                y: CGFloat([-10, -8, 10, 6][i])
                            )
                    }
                }
                .frame(width: 36, height: 36)
                
                Text("44% Sale")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Right side: Spots remaining
            Text("9 spots remaining")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var redemptionInstructionsButton: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            showRedemptionInstructions = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                
                Text("How to use this code?")
                    .font(.system(size: 18, weight: .semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.appAccent.opacity(0.9), Color.appAccent.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appAccent, lineWidth: 1.5)
                    )
                    .shadow(color: Color.appAccent.opacity(0.4), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
        .alert("How to Redeem Your 30% Discount", isPresented: $showRedemptionInstructions) {
            if #available(iOS 16.3, *) {
                Button("Redeem in App", action: {
                    showOfferCodeRedemption = true
                })
            }
            Button("Copy Code", action: {
                UIPasteboard.general.string = "NOTEWALL30"
                copiedPromoCode = true
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            })
            Button("Open App Store", action: {
                openRedeemURL()
            })
            Button("Cancel", role: .cancel) { }
        } message: {
            if #available(iOS 16.3, *) {
                Text("""
                Redeem your code "NoteWall 30" to get 30% off the Lifetime plan.
                
                You can redeem it directly in the app (recommended) or through the App Store.
                
                The discount applies to the lifetime plan only.
                """)
            } else {
                Text("""
                Redeem your code "NoteWall 30" to get 30% off the Lifetime plan.
                
                1. Copy the code: NoteWall 30
                2. Open App Store → Profile → Redeem
                3. Paste the code to get 30% off!
                
                The discount applies to the lifetime plan only.
                """)
            }
        }
    }
    
    private func openRedeemURL() {
        // Open App Store redeem page
        if let url = URL(string: "https://apps.apple.com/redeem") {
            UIApplication.shared.open(url)
        }
    }
    
    @available(iOS 15.0, *)
    private var pricingSection: some View {
        VStack(spacing: 16) {
            if paywallManager.isLoadingOfferings {
                ProgressView()
                    .padding()
            } else if primaryPackages.isEmpty {
                fallbackPricingCards
            } else {
                ForEach(Array(sortedPrimaryPackages.enumerated()), id: \.element.identifier) { index, package in
                    pricingCard(for: package, index: packageGlobalIndex(package))
                }
            }
        }
        .padding(.top, 4)
    }

    private var availablePackages: [Package] {
        paywallManager.availablePackages
    }
    
    private var primaryPackages: [Package] {
        // Show Lifetime and Monthly in main paywall (Lifetime replaces Yearly)
        // When exit intercept discount is active, prefer the discounted lifetime product
        if discountApplied {
            return availablePackages.filter { package in
                let kind = planKind(for: package)
                let identifier = package.storeProduct.productIdentifier.lowercased()
                // Include monthly, or lifetime products (prefer discounted when available)
                if kind == .monthly {
                    return true
                } else if kind == .lifetime {
                    // If we have a discounted lifetime, only show that one
                    let hasDiscounted = availablePackages.contains { pkg in
                        let id = pkg.storeProduct.productIdentifier.lowercased()
                        return (id == "lifetime_discount" || id.contains("lifetime_discount")) && planKind(for: pkg) == .lifetime
                    }
                    if hasDiscounted {
                        // Only include if this is the discounted one
                        return identifier == "lifetime_discount" || identifier.contains("lifetime_discount")
                    }
                    // Otherwise include regular lifetime
                    return !identifier.contains("discount")
                }
                return false
            }
        } else {
            // Normal flow: exclude discounted lifetime product
            return availablePackages.filter { package in
                let kind = planKind(for: package)
                let identifier = package.storeProduct.productIdentifier.lowercased()
                if kind == .monthly {
                    return true
                } else if kind == .lifetime {
                    // Exclude discounted lifetime in normal flow
                    return !identifier.contains("discount")
                }
                return false
            }
        }
    }
    
    private var sortedPrimaryPackages: [Package] {
        primaryPackages.sorted { planSortPriority(for: $0) < planSortPriority(for: $1) }
    }
    
    private func packageGlobalIndex(_ package: Package) -> Int {
        availablePackages.firstIndex(where: { $0.identifier == package.identifier }) ?? 0
    }
    
    private func planSortPriority(for package: Package) -> Int {
        switch planKind(for: package) {
        case .lifetime:
            return 0
        case .monthly:
            return 1
        default:
            return 2
        }
    }

    private var selectedPackage: Package? {
        guard selectedProductIndex >= 0,
              selectedProductIndex < availablePackages.count else {
            return nil
        }
        return availablePackages[selectedProductIndex]
    }

    private var selectedPlanKind: PlanKind {
        planKind(for: selectedPackage)
    }


    private var monthlyPackage: Package? {
        availablePackages.first { planKind(for: $0) == .monthly }
    }
    
    private var lifetimePackage: Package? {
        // If exit intercept discount is active, prefer the discounted lifetime product
        if discountApplied {
            // Look for the discounted lifetime product first
            if let discountedLifetime = availablePackages.first(where: { package in
                let identifier = package.storeProduct.productIdentifier.lowercased()
                return identifier == "lifetime_discount" || identifier.contains("lifetime_discount")
            }) {
                return discountedLifetime
            }
        }
        // Otherwise, use the regular lifetime package
        return availablePackages.first { planKind(for: $0) == .lifetime && 
            !$0.storeProduct.productIdentifier.lowercased().contains("discount") }
    }
    
    private var lifetimeFallbackPlan: FallbackPlan? {
        // Return hardcoded lifetime plan for the separate sheet
        FallbackPlan(
            kind: .lifetime,
            label: "Lifetime",
            subtitle: "One-time purchase, own NoteWall+ forever",
            priceText: "€24.99",
            highlight: false,
            trialDays: nil
        )
    }
    
    private var lifetimePriceText: String {
        lifetimePackage?.localizedPriceString ?? lifetimeFallbackPlan?.priceText ?? "€24.99"
    }
    
    private var lifetimeSubtitleText: String {
        "Own NoteWall+ forever • No renewals"
    }
    
    @discardableResult
    private func selectLifetimePackage() -> Bool {
        // If exit intercept discount is active, prefer the discounted lifetime product
        if discountApplied {
            if let discountedLifetimeIndex = availablePackages.firstIndex(where: { package in
                let identifier = package.storeProduct.productIdentifier.lowercased()
                return identifier == "lifetime_discount" || identifier.contains("lifetime_discount")
            }) {
                selectedProductIndex = discountedLifetimeIndex
                return true
            }
        }
        
        // Otherwise, use the regular lifetime package
        guard let lifetimeIndex = availablePackages.firstIndex(where: { 
            planKind(for: $0) == .lifetime && 
            !$0.storeProduct.productIdentifier.lowercased().contains("discount")
        }) else {
            return false
        }
        selectedProductIndex = lifetimeIndex
        return true
    }

    private var fallbackPlans: [FallbackPlan] {
        [
            FallbackPlan(
                kind: .lifetime,
                label: "Lifetime",
                subtitle: "One-time purchase, own NoteWall+ forever",
                priceText: "€24.99",
                highlight: true,
                trialDays: nil
            ),
            FallbackPlan(
                kind: .monthly,
                label: "Monthly",
                subtitle: "",
                priceText: "€6.99",
                highlight: false,
                trialDays: nil
            )
        ]
    }

    private var currentFallbackPlan: FallbackPlan? {
        guard availablePackages.isEmpty,
              selectedProductIndex >= 0,
              selectedProductIndex < fallbackPlans.count else {
            return nil
        }
        return fallbackPlans[selectedProductIndex]
    }
    
    // Fallback pricing cards when StoreKit packages are not available
    private var fallbackPricingCards: some View {
        VStack(spacing: 16) {
            ForEach(Array(fallbackPlans.enumerated()), id: \.element.id) { index, plan in
                fallbackPricingCard(plan: plan, index: index)
            }
        }
    }
    
    private func fallbackPricingCard(plan: FallbackPlan, index: Int) -> some View {
        // Unused: let isLifetimePlan = plan.kind == .lifetime
        
        // Determine display price
        let displayPrice = plan.priceText
        let originalPrice: String? = nil
        
        let perMonthText: String?
        if plan.kind == .monthly {
            perMonthText = "\(displayPrice)/mo"
        } else if plan.kind == .lifetime {
            // For lifetime, show "One-time" or similar
            perMonthText = nil
        } else {
            perMonthText = nil
        }
        
        let badgeText: String?
        if plan.kind == .lifetime {
            badgeText = "BEST VALUE"
        } else {
            badgeText = nil
        }
        
        return selectablePricingCard(
            planLabel: plan.label,
            subtitle: plan.subtitle,
            price: displayPrice,
            originalPrice: originalPrice,
            highlight: plan.highlight,
            index: index,
            perMonthText: perMonthText,
            badgeText: badgeText
        )
    }

    @available(iOS 15.0, *)
    private func pricingCard(for package: Package, index: Int) -> some View {
        let identifier = package.storeProduct.productIdentifier.lowercased()
        let planLabel: String
        if package.packageType == .lifetime || identifier.contains("lifetime") {
            planLabel = "Lifetime"
        } else if package.packageType == .annual || identifier.contains("year") {
            planLabel = "Yearly"
        } else {
            planLabel = "Monthly"
        }

        let highlight = false
        
        // Determine if this is a lifetime plan
        let isLifetimePlan = planLabel.lowercased().contains("lifetime")
        
        // For lifetime plan, show current price with crossed-out $29.99
        let displayPrice: String
        let showOriginalPrice: String?
        let badgeText: String?
        
        if isLifetimePlan {
            // Check if this is the discounted lifetime product
            let isDiscountedLifetime = package.storeProduct.productIdentifier.lowercased().contains("lifetime_discount") || 
                                       package.storeProduct.productIdentifier.lowercased() == "lifetime_discount"
            
            // For exit-intercept discount, use the discounted lifetime product's actual price
            if discountApplied && isDiscountedLifetime {
                // Use the discounted product's price (it's already discounted in App Store Connect)
                displayPrice = package.localizedPriceString
                // Find the regular lifetime package to show as original price
                if let regularLifetime = availablePackages.first(where: { pkg in
                    let id = pkg.storeProduct.productIdentifier.lowercased()
                    return planKind(for: pkg) == .lifetime && !id.contains("discount")
                }) {
                    showOriginalPrice = regularLifetime.localizedPriceString
                } else {
                    showOriginalPrice = getLifetimeOriginalPrice(for: package)
                }
                badgeText = "30% OFF" // Show discount badge
            } else if discountApplied && !isDiscountedLifetime {
                // Fallback: calculate discount if discounted product not found
                displayPrice = getDiscountedPriceString(for: package)
                showOriginalPrice = package.localizedPriceString
                badgeText = "30% OFF"
            } else {
                displayPrice = package.localizedPriceString
                // Show $29.99 (or equivalent) as crossed-out original price
                showOriginalPrice = getLifetimeOriginalPrice(for: package)
                badgeText = "BEST VALUE"
            }
        } else {
            displayPrice = package.localizedPriceString
            showOriginalPrice = nil
            badgeText = discountBadgeText(for: package)
        }
        
        return selectablePricingCard(
            planLabel: planLabel,
            subtitle: "", // No subtitle
            price: displayPrice,
            originalPrice: showOriginalPrice,
            highlight: highlight,
            index: index,
            perMonthText: perMonthText(for: package, displayAlways: true, applyDiscount: false),
            badgeText: badgeText
        )
    }

    private func selectablePricingCard(
        planLabel: String,
        subtitle: String,
        price: String,
        originalPrice: String? = nil,
        highlight: Bool,
        index: Int,
        perMonthText: String? = nil,
        badgeText: String? = nil
    ) -> some View {
        let isSelected = selectedProductIndex == index
        let isLifetimePlan = planLabel.lowercased().contains("lifetime")
        let selectionAnimation: Animation = isLifetimePlan
            ? .spring(response: 0.32, dampingFraction: 0.65)
            : .easeOut(duration: 0.18)
        
        return Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            // Use transaction for optimized animation
            var transaction = Transaction(animation: selectionAnimation)
            transaction.disablesAnimations = false
            withTransaction(transaction) {
                selectedProductIndex = index
                
                // Track plan selection
                if index < availablePackages.count {
                    trackPlanSelection(availablePackages[index])
                }
            }
        }) {
            HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        let indicatorSize: CGFloat = 18
                        Circle()
                            .stroke(isSelected ? Color.appAccent : Color.secondary.opacity(0.35), lineWidth: 2)
                            .frame(width: indicatorSize, height: indicatorSize)
                        
                        if isSelected {
                            Circle()
                                .fill(Color.appAccent)
                                .frame(width: indicatorSize, height: indicatorSize)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                VStack(alignment: .leading, spacing: isLifetimePlan ? 6 : 2) {
                        Text(planLabel)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    // For lifetime, show price below the title
                    if isLifetimePlan {
                        HStack(spacing: 8) {
                            Text(price)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            // Show original price strikethrough if discount applied
                            if let originalPrice = originalPrice {
                                Text(originalPrice)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .strikethrough(true, color: .secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Show per month text on the right
                if let perMonthText {
                    Text(perMonthText)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                        .padding(.vertical, 4)
                }
            }
            .padding(.vertical, isLifetimePlan ? 18 : 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appAccent.opacity(0.12))
                    .shadow(color: (isSelected && isLifetimePlan) ? Color.appAccent.opacity(0.25) : Color.black.opacity(0.05), radius: isSelected ? 14 : 6, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke((isSelected && isLifetimePlan) ? Color.appAccent : Color.clear, lineWidth: 2)
            )
            .overlay(
                Group {
                    if let badgeText {
                        badgeLabel(text: badgeText)
                    }
                }
            )
            .scaleEffect((isSelected && isLifetimePlan) ? 1.02 : 1)
            .animation(selectionAnimation, value: isSelected)
        }
        .buttonStyle(.plain)
    }
    
    private func packageSubtitle(for package: Package) -> String {
        if let discount = package.storeProduct.introductoryDiscount {
            let period = trialDescription(from: discount.subscriptionPeriod)
            return period.isEmpty ? "Includes trial" : "\(period) free trial"
        }

        if package.packageType == .lifetime {
            return "Own NoteWall+ forever"
        }

        return ""
    }

    private func trialDescription(from period: Any?) -> String {
        guard let period = period else { return "" }
        
        // Try to extract value and unit - works with both StoreKit 1 and StoreKit 2 types
        let mirror = Mirror(reflecting: period)
        var value: Int?
        var unitString: String = ""
        
        for child in mirror.children {
            if child.label == "value", let intValue = child.value as? Int {
                value = intValue
            } else if child.label == "unit" {
                unitString = String(describing: child.value)
            }
        }
        
        guard let value = value else { return "" }
        
        // Determine period description based on unit
        if unitString.contains("day") || unitString.contains(".day") {
            return value == 1 ? "1-day" : "\(value)-day"
        } else if unitString.contains("week") || unitString.contains(".week") {
            return value == 1 ? "1-week" : "\(value)-week"
        } else if unitString.contains("month") || unitString.contains(".month") {
            return value == 1 ? "1-month" : "\(value)-month"
        } else if unitString.contains("year") || unitString.contains(".year") {
            return value == 1 ? "1-year" : "\(value)-year"
        }
        
        return ""
    }

    private func planKind(for package: Package?) -> PlanKind {
        if let package {
            switch package.packageType {
            case .monthly: return .monthly
            case .annual: return .yearly
            case .lifetime: return .lifetime
            default:
                let identifier = package.storeProduct.productIdentifier.lowercased()
                if identifier.contains("month") { return .monthly }
                if identifier.contains("year") || identifier.contains("annual") { return .yearly }
                if identifier.contains("life") { return .lifetime }
            }
        }
        return currentFallbackPlan?.kind ?? .unknown
    }

    private func fallbackPriceDescription(for plan: FallbackPlan) -> String {
        switch plan.kind {
        case .monthly:
            return "\(plan.priceText)/month"
        case .yearly:
            return "\(plan.priceText)/year"
        case .lifetime:
            return plan.priceText
        case .unknown:
            return plan.priceText
        }
    }



    private func trialDaysForSelectedPackage(_ package: Package?) -> Int? {
        if let period = package?.storeProduct.introductoryDiscount?.subscriptionPeriod {
            return convertPeriodToDays(from: period)
        }
        return currentFallbackPlan?.trialDays
    }

    private func convertPeriodToDays(from period: Any) -> Int {
        // Extract value and unit using reflection to handle type ambiguity
        let mirror = Mirror(reflecting: period)
        var value: Int?
        var unitString: String = ""
        
        for child in mirror.children {
            if child.label == "value", let intValue = child.value as? Int {
                value = intValue
            } else if child.label == "unit" {
                unitString = String(describing: child.value)
            }
        }
        
        guard let value = value else { return 0 }
        
        // Convert to days based on unit type
        if unitString.contains("day") || unitString.contains(".day") {
            return value
        } else if unitString.contains("week") || unitString.contains(".week") {
            return value * 7
        } else if unitString.contains("month") || unitString.contains(".month") {
            return value * 30
        } else if unitString.contains("year") || unitString.contains(".year") {
            return value * 365
        }
        
        return value
    }

    private func localizedPriceDescription(for package: Package?) -> String? {
        if let package {
            switch planKind(for: package) {
            case .monthly:
                return "\(package.localizedPriceString)/month"
            case .yearly:
                return "\(package.localizedPriceString)/year"
            case .lifetime:
                return package.localizedPriceString
            case .unknown:
                return package.localizedPriceString
            }
        }
        if let fallbackPlan = currentFallbackPlan {
            return fallbackPriceDescription(for: fallbackPlan)
        }
        return nil
    }
    
    private var purchaseButtonTitle: String {
        if let package = selectedPackage {
            let plan = planKind(for: package)
            let trialDays = trialDaysForSelectedPackage(package)
            return ctaTitle(for: plan, trialDays: trialDays)
        } else if let fallbackPlan = currentFallbackPlan {
            return ctaTitle(for: fallbackPlan.kind, trialDays: fallbackPlan.trialDays)
        }
        return "Continue"
    }
    
    private func ctaTitle(for plan: PlanKind, trialDays: Int?) -> String {
        switch plan {
        case .yearly:
            return "Get yearly access"
        case .monthly:
            return "Get monthly access"
        case .lifetime:
            return "Get lifetime access"
        case .unknown:
            return "Continue"
        }
    }
    
    // MARK: - Actions
    
    private func initializePlanSelection() {
        guard !hasInitializedPlanSelection else { return }
        let packages = paywallManager.availablePackages
        
        guard !packages.isEmpty else { return }
        
        // If exit intercept discount is active, prefer the discounted lifetime product
        if discountApplied {
            if let discountedLifetimeIndex = packages.firstIndex(where: { package in
                let identifier = package.storeProduct.productIdentifier.lowercased()
                return identifier == "lifetime_discount" || identifier.contains("lifetime_discount")
            }) {
                selectedProductIndex = discountedLifetimeIndex
                hasInitializedPlanSelection = true
                return
            }
        }
        
        // Find lifetime package index in availablePackages (preferred)
        if let lifetimeIndex = packages.firstIndex(where: { planKind(for: $0) == .lifetime && 
            !$0.storeProduct.productIdentifier.lowercased().contains("discount") }) {
            selectedProductIndex = lifetimeIndex
            hasInitializedPlanSelection = true
        } else if !packages.isEmpty {
            // If no lifetime package, select first available
            selectedProductIndex = 0
            hasInitializedPlanSelection = true
        }
    }
    
    @ViewBuilder
    private func paywallScrollView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            content()
        }
        .background(Color.clear) // Make ScrollView background transparent to show animated background
        // Note: scrollContentBackground is iOS 16+, so we use .background(Color.clear) for iOS 15+ compatibility
    }
    
    private func handlePurchase() {
        guard let package = selectedPackage else {
            errorMessage = availablePackages.isEmpty
            ? "Products are still loading. Please try again in a moment."
            : "Please select a pricing option."
            showError = true
            return
        }
        
        // If this is a trial package, check for notification permissions first
        if package.storeProduct.introductoryDiscount != nil {
            // Store package for later
            pendingPackage = package
            
            // Check current status
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    if settings.authorizationStatus == .notDetermined {
                        // Ask nicely first
                        showNotificationPrePrompt = true
                    } else {
                        // Already determined (allowed or denied), proceed directly
                        purchase(package)
                    }
                }
            }
        } else {
            // No trial, just purchase
            purchase(package)
        }
    }
    
    private func purchase(_ package: Package) {
        let productId = package.storeProduct.productIdentifier
        
        // Track purchase start
        AnalyticsService.shared.trackPurchaseStart(productId: productId)
        
        Task {
            isPurchasing = true
            do {
                try await paywallManager.purchase(package: package)
                await MainActor.run {
                    isPurchasing = false
                    
                    // Track purchase success
                    let price = NSDecimalNumber(decimal: package.storeProduct.price).doubleValue
                    let currency = package.storeProduct.currencyCode
                    AnalyticsService.shared.trackPurchaseSuccess(
                        productId: productId,
                        transactionId: nil, // RevenueCat handles this
                        revenue: price,
                        currency: currency
                    )
                    
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    // Only dismiss on successful purchase
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    
                    // Check if this is a cancellation - don't show error or dismiss
                    if let purchasesError = error as? ErrorCode,
                       purchasesError == .purchaseCancelledError {
                        // Track cancellation
                        AnalyticsService.shared.trackPurchaseCancel(productId: productId)
                        // User cancelled - silently handle, keep paywall open
                        // No error message, no dismiss, just reset purchasing state
                        return
                    }
                    
                    // Track purchase failure
                    AnalyticsService.shared.trackPurchaseFail(
                        productId: productId,
                        errorCode: error.localizedDescription
                    )
                    
                    // For other errors, show error message but DON'T dismiss paywall
                    errorMessage = paywallManager.lastErrorMessage ?? error.localizedDescription
                    showError = true
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    // Paywall stays open - user can try again
                }
            }
        }
    }
    
    private func openSubscriptionManagement() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }
    
    private func validateAndApplyCode() {
        // Trim whitespace and convert to uppercase for comparison
        let trimmedCode = promoCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Validate the promo code
        // Change this code to whatever you want to share with friends
        let validCode = "FRIEND2024" // You can change this to any code you want
        
        if trimmedCode == validCode {
            // Grant lifetime access
            paywallManager.grantLifetimeAccess()
            
            // Provide haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Clear the code field
            promoCode = ""
            
            // Show success alert
            showCodeSuccess = true
        } else {
            // Invalid code
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            showCodeError = true
        }
    }
    
    // MARK: - Trial Timeline
    
    private struct TimelineEvent: Identifiable {
        let id = UUID()
        let iconName: String
        let iconColor: Color
        let title: String
        let subtitle: String
    }

    private var trialTimeline: some View {
        let package = selectedPackage
        let planKind = planKind(for: package)
        let trialDays = trialDaysForSelectedPackage(package)
        let iconSize: CGFloat = 44
        let itemSpacing: CGFloat = 18

        let priceText = localizedPriceDescription(for: package)
            ?? currentFallbackPlan.flatMap { fallbackPriceDescription(for: $0) }
            ?? "€14.99"

        var events: [TimelineEvent] = [
            TimelineEvent(
                iconName: "crown.fill",
                iconColor: .appAccent,
                title: "Today",
                subtitle: "Start staying locked in and focused on what matters."
            )
        ]

        if let trialDays {
            // Calculate reminder day: 1 day before trial ends (so user has time to cancel)
            // For 3-day trial: remind on day 2 = "Tomorrow" (1 day from now)
            // For 7-day trial: remind on day 6 = "In 5 days" (5 days from now)
            let reminderDay = max(trialDays - 2, 1)
            events.append(
                TimelineEvent(
                    iconName: "bell.fill",
                    iconColor: .appAccent,
                    title: reminderDay == 1 ? "Tomorrow" : "In \(reminderDay) days",
                    subtitle: "We'll remind you so you only keep NoteWall+ if you love it."
                )
            )

            events.append(
            TimelineEvent(
                iconName: "checkmark.circle.fill",
                iconColor: .appAccent,
                    title: planKind == .yearly ? "Day \(trialDays)" : "In \(trialDays) days",
                    subtitle: planKind == .lifetime
                        ? "Your lifetime access will begin and you'll be charged \(priceText)."
                        : "Your subscription will begin and you'll be charged \(priceText)."
                )
            )
        } else {
            events.append(
                TimelineEvent(
                    iconName: "checkmark.circle.fill",
                    iconColor: .appAccent,
                    title: "After confirmation",
                    subtitle: planKind == .lifetime
                        ? "Lifetime access unlocks immediately for \(priceText)."
                        : "Your subscription will begin immediately for \(priceText)."
                )
            )
        }

        return VStack(alignment: .leading, spacing: itemSpacing) {
            ForEach(events) { event in
                HStack(alignment: .top, spacing: 12) {
                    timelineIcon(for: event, size: iconSize)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(event.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .leading) {
            timelineLineBackground(iconSize: iconSize, spacing: itemSpacing, eventCount: events.count)
                .blendMode(.normal)
        }
    }

    private func timelineLineBackground(iconSize: CGFloat, spacing: CGFloat, eventCount: Int) -> some View {
        GeometryReader { geo in
            let lineColor = Color.appAccent.opacity(0.16)
            let fadeHeight: CGFloat = 36
            let topOffset = iconSize / 2
            let totalHeight = geo.size.height
            let lineHeight = max(totalHeight - topOffset, 0)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(lineColor)
                    .frame(width: 2, height: max(lineHeight - fadeHeight, 0))

                if lineHeight > 0 {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.appAccent.opacity(0.16), Color.appAccent.opacity(0)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: 2, height: min(fadeHeight, lineHeight))
                }
            }
            .frame(width: 2, height: lineHeight, alignment: .top)
            .offset(x: iconSize / 2 - 1, y: topOffset)
        }
        .frame(width: iconSize)
        .allowsHitTesting(false)
    }

    private func timelineIcon(for event: TimelineEvent, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(event.iconColor.opacity(0.16))
                .frame(width: size, height: size)

            Image(systemName: event.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(event.iconColor)
        }
        .frame(width: size, height: size)
    }
    
    private func perMonthPrice(for package: Package) -> Decimal? {
        let price = package.storeProduct.price
        switch planKind(for: package) {
        case .monthly:
            return price
        case .yearly:
            return price / Decimal(12)
        default:
            return nil
        }
    }
    
    private func perMonthText(for package: Package, displayAlways: Bool = false, applyDiscount: Bool = false) -> String? {
        let kind = planKind(for: package)
        
        // For monthly, show price/mo
        if kind == .monthly {
            let price = applyDiscount ? getDiscountedPriceString(for: package) : package.localizedPriceString
            return "\(price)/mo"
        }
        
        // For yearly, calculate and show per month
        if kind == .yearly {
            let formatter = currencyFormatter(for: package)
            let locale = formatter.locale ?? Locale.current
            let currencyCode: String
            if #available(iOS 16, *) {
                currencyCode = locale.currency?.identifier ?? "USD"
            } else {
                currencyCode = locale.currencyCode ?? "USD"
            }
            
            if applyDiscount {
                // For exit-intercept discount, show $9.99/12 = $0.83/mo
                let discountedYearlyPrice: Decimal = currencyCode == "EUR" ? 9.99 : 9.99
                let perMonthValue = discountedYearlyPrice / 12
                let formatted = formatter.string(from: NSDecimalNumber(decimal: perMonthValue))
                return formatted.map { "\($0)/mo" }
            } else if let value = perMonthPrice(for: package) {
                let formatted = formatter.string(from: NSDecimalNumber(decimal: value))
                return formatted.map { "\($0)/mo" }
            }
        }
        
        return nil
    }
    
    /// Calculates and returns the discounted price string (30% off) for a package
    private func getDiscountedPriceString(for package: Package) -> String {
        let originalPrice = package.storeProduct.price
        let discountedPrice = originalPrice * 0.7 // 30% discount
        
        let formatter = currencyFormatter(for: package)
        return formatter.string(from: NSDecimalNumber(decimal: discountedPrice)) ?? package.localizedPriceString
    }
    
    /// Returns €17.99 (or equivalent) for lifetime original price display (crossed out)
    private func getLifetimeOriginalPrice(for package: Package) -> String {
        let formatter = currencyFormatter(for: package)
        let locale = formatter.locale ?? Locale.current
        
        // Determine currency and set appropriate original price
        let currencyCode: String
        if #available(iOS 16, *) {
            currencyCode = locale.currency?.identifier ?? "USD"
        } else {
            currencyCode = locale.currencyCode ?? "USD"
        }
        let originalAmount: Decimal
        
        // Set €17.99 for EUR, $17.99 for USD, or equivalent
        if currencyCode == "EUR" {
            originalAmount = 17.99
        } else if currencyCode == "USD" {
            originalAmount = 17.99
        } else {
            // For other currencies, use the same base price
            originalAmount = 17.99
        }
        
        return formatter.string(from: NSDecimalNumber(decimal: originalAmount)) ?? "€17.99"
    }
    
    /// Returns $9.99 (or equivalent) for exit-intercept discount display
    private func getExitInterceptDiscountedPrice(for package: Package) -> String {
        let formatter = currencyFormatter(for: package)
        let locale = formatter.locale ?? Locale.current
        
        // Determine currency and set appropriate discounted price
        let currencyCode: String
        if #available(iOS 16, *) {
            currencyCode = locale.currency?.identifier ?? "USD"
        } else {
            currencyCode = locale.currencyCode ?? "USD"
        }
        let discountedAmount: Decimal
        
        // Set $9.99 for USD, €9.99 for EUR, or equivalent
        if currencyCode == "EUR" {
            discountedAmount = 9.99
        } else if currencyCode == "USD" {
            discountedAmount = 9.99
        } else {
            // For other currencies, calculate 33% off (to get close to $9.99 from $14.99)
            let originalPrice = package.storeProduct.price
            discountedAmount = originalPrice * 0.67 // ~33% discount to approximate $9.99
        }
        
        return formatter.string(from: NSDecimalNumber(decimal: discountedAmount)) ?? "$9.99"
    }
    
    private func discountBadgeText(for package: Package) -> String? {
        guard planKind(for: package) == .yearly,
              let monthlyPkg = monthlyPackage else { return nil }
        
        // Calculate annual cost if paid monthly
        let monthlyPrice = NSDecimalNumber(decimal: monthlyPkg.storeProduct.price).doubleValue
        let annualIfMonthly = monthlyPrice * 12
        
        // Get yearly price
        let yearlyPrice = NSDecimalNumber(decimal: package.storeProduct.price).doubleValue
        
        guard annualIfMonthly > yearlyPrice else { return nil }
        
        // Calculate discount percentage
        let discount = (annualIfMonthly - yearlyPrice) / annualIfMonthly
        let percent = Int((discount * 100).rounded())
        
        return percent >= 5 ? "\(percent)% OFF" : nil
    }
    
    private func currencyFormatter(for package: Package) -> NumberFormatter {
        if let formatter = package.storeProduct.priceFormatter {
            return formatter
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = package.storeProduct.priceFormatter?.locale ?? Locale.current
        formatter.maximumFractionDigits = 2
        return formatter
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func badgeLabel(text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.appAccent))
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
            .padding(.trailing, 4)
            .padding(.top, -2)
            .offset(x: -10, y: -12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
    
    private func getLegalDocumentContent() -> String {
        switch selectedLegalDocument {
        case .termsOfService:
            // Terms of Use is hosted on Notion - open URL
            DispatchQueue.main.async {
                if let url = URL(string: "https://peat-appendix-c3c.notion.site/TERMS-OF-USE-2b7f6a63758f8067a318e16486b16f47?source=copy_link") {
                    UIApplication.shared.open(url)
                }
            }
            return """
            Opening Terms of Use...
            
            Your browser will open with the Terms of Use.
            """
        case .privacyPolicy:
            // Privacy Policy is hosted on Notion - open URL
            DispatchQueue.main.async {
                if let url = URL(string: "https://peat-appendix-c3c.notion.site/PRIVACY-POLICY-2b7f6a63758f804cab16f58998d7787e?source=copy_link") {
                    UIApplication.shared.open(url)
                }
            }
            return """
            Opening Privacy Policy...
            
            Your browser will open with the Privacy Policy.
            """
        case .termsAndPrivacy:
            return """
            TERMS OF SERVICE & PRIVACY POLICY
            
            Last Updated: November 13, 2025
            
            PART I: END-USER LICENSE AGREEMENT (EULA)
            
            The End-User License Agreement (EULA) is hosted online. Please review the complete EULA at the link below.
            
            [EULA Link will be displayed as a button]
            

            PART II: SUBSCRIPTION TERMS


            11. AUTO-RENEWABLE SUBSCRIPTIONS
            
            • Payment will be charged to your iTunes Account at confirmation of purchase
            • Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period
            • Account will be charged for renewal within 24-hours prior to the end of the current period, and identify the cost of the renewal
            • Subscriptions may be managed by the user and auto-renewal may be turned off by going to the user's Account Settings after purchase
            • Any unused portion of a free trial period, if offered, will be forfeited when the user purchases a subscription to that publication, where applicable
            
            12. FREE TRIAL TERMS
            
            • New users receive 3 free wallpaper exports to try the app
            • Premium subscriptions may include a free trial period (typically 3 days)
            • You will be charged at the end of the trial period unless you cancel before it ends
            • To cancel: Settings app → [Your Name] → Subscriptions → NoteWall → Cancel Subscription
            • Free trials are available to new subscribers only
            
            13. REFUND POLICY
            
            • All refund requests must be made through Apple's App Store
            • Contact Apple Support directly for refund assistance
            • Refunds are subject to Apple's refund policy
            • We cannot process refunds directly as all payments are handled by Apple
            
            14. PRICING AND AVAILABILITY
            
            • Prices are subject to change without notice
            • Subscription prices may vary by region and currency
            • Features and availability may vary by device and iOS version
            • We reserve the right to modify or discontinue features at any time
            

            PART III: PRIVACY POLICY

            
            15. INFORMATION WE COLLECT
            
            15.1 Personal Information You Provide:
            • Notes and Text: All notes you create are stored locally on your device only
            • Photos: Any photos you select for wallpaper backgrounds are processed locally on your device
            • No personal content is transmitted to our servers or third parties
            
            15.2 Automatically Collected Information:
            • Device Information: iOS version, device model (for app compatibility and optimization)
            • App Performance Data: Anonymous crash reports and performance metrics to improve the app
            • Purchase Information: Subscription status and transaction records (processed by Apple)
            • Usage Analytics: Anonymous data about app features used (no personal content)
            
            15.3 Information We Do NOT Collect:
            • We do not collect your name, email address, or contact information unless you contact us
            • We do not access your contacts, location, camera roll, or other personal data
            • We do not track your browsing habits or app usage patterns across other apps
            • We do not use cookies or similar tracking technologies
            
            16. HOW WE USE YOUR INFORMATION
            
            We use collected information to:
            • Provide the core wallpaper generation functionality
            • Process in-app purchases through Apple's App Store
            • Improve app performance and fix technical issues
            • Provide customer support when you contact us directly
            • Ensure app compatibility across different iOS versions and devices
            • Analyze app usage patterns to improve user experience (anonymized data only)
            
            17. DATA STORAGE AND SECURITY
            
            17.1 Local Storage:
            • All your notes and photos are stored exclusively on your device using iOS secure storage
            • We do not upload, sync, or backup your personal content to external servers
            • Your data remains completely private and under your control
            • Data is protected by iOS built-in security features including device encryption
            • When you delete the app, all your data is permanently removed
            
            17.2 Data Transmission:
            • No personal content (notes, photos) is transmitted over the internet
            • Only anonymous technical data may be sent for app improvement purposes
            • All purchase transactions are handled securely by Apple using industry-standard encryption
            • Any data transmission uses secure HTTPS protocols
            
            18. DATA SHARING AND DISCLOSURE
            
            We do not sell, trade, rent, or share your personal information with third parties, except in the following limited circumstances:
            
            18.1 Apple Inc.:
            • Purchase and subscription information is shared with Apple for payment processing
            • Anonymous crash reports may be shared through Apple's developer tools
            • App Store analytics data is processed by Apple according to their privacy policy
            
            18.2 Legal Requirements:
            • We may disclose information if required by law, court order, or government request
            • We may disclose information to protect our rights, property, or safety
            • We may disclose information to prevent fraud or illegal activities
            
            18.3 Business Transfers:
            • In the event of a merger, acquisition, or sale of assets, user information may be transferred
            • Users will be notified of any such transfer and their rights regarding their data
            
            19. YOUR PRIVACY RIGHTS
            
            19.1 European Union (GDPR) Rights:
            If you are located in the EU, you have the following rights:
            • Right of Access: Request information about data we process about you
            • Right of Rectification: Correct inaccurate personal data
            • Right of Erasure: Request deletion of your personal data
            • Right of Portability: Export your data in a readable format
            • Right to Object: Object to processing of your personal data
            • Right to Restrict Processing: Limit how we process your data
            • Right to Lodge a Complaint: File a complaint with your local data protection authority
            
            19.2 California Privacy Rights (CCPA):
            If you are a California resident, you have the right to:
            • Know what personal information is collected about you
            • Delete personal information we have collected
            • Opt-out of the sale of personal information (we do not sell personal information)
            • Non-discrimination for exercising your privacy rights
            
            19.3 Exercising Your Rights:
            To exercise any of these rights, contact us at: iosnotewall@gmail.com
            We will respond to your request within 30 days.
            
            20. DATA RETENTION
            
            • Notes: Stored locally on your device until you delete them or uninstall the app
            • App Settings: Stored locally until app is uninstalled
            • Purchase Records: Maintained by Apple according to their retention policies
            • Technical Data: Anonymous performance data may be retained for up to 2 years for app improvement
            • Support Communications: Retained for up to 3 years for customer service purposes
            
            21. CHILDREN'S PRIVACY
            
            NoteWall is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If we become aware that we have collected personal information from a child under 13, we will take steps to delete such information immediately. Parents who believe their child has provided us with personal information should contact us at iosnotewall@gmail.com.
            
            22. INTERNATIONAL DATA TRANSFERS
            
            Since all personal data is processed locally on your device, there are no international data transfers of your personal content. Any anonymous technical data shared with us is processed in accordance with applicable data protection laws and may be transferred to countries with different data protection standards.
            
            23. CHANGES TO THIS PRIVACY POLICY
            
            We may update this Privacy Policy from time to time to reflect changes in our practices, technology, or applicable laws. We will notify you of any material changes by:
            • Posting the updated policy in the app
            • Updating the "Last Updated" date at the top of this policy
            • Sending a notification through the app if changes are significant
            
            Your continued use of the app after any changes constitutes acceptance of the updated policy.
            
            24. CONTACT INFORMATION
            
            If you have questions, concerns, or requests regarding this Privacy Policy or our privacy practices, please contact us:
            
            Email: iosnotewall@gmail.com
            Developer: NoteWall Team
            
            For EU residents: You also have the right to lodge a complaint with your local data protection authority.
            
            
            PART IV: GENERAL TERMS

            
            25. DISCLAIMER OF WARRANTIES
            
            THE LICENSED APPLICATION IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. WE DO NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED OR ERROR-FREE.
            
            26. LIMITATION OF LIABILITY
            
            TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE DEVELOPER SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS OR REVENUES, WHETHER INCURRED DIRECTLY OR INDIRECTLY, OR ANY LOSS OF DATA, USE, GOODWILL, OR OTHER INTANGIBLE LOSSES.
            
            27. TERMINATION
            
            This EULA is effective until terminated by you or the Developer. Your rights under this EULA will terminate automatically without notice if you fail to comply with any term(s) of this EULA. Upon termination, you must cease all use of the Licensed Application and delete all copies.
            
            28. GOVERNING LAW
            
            This EULA and Privacy Policy are governed by the laws of Slovakia, without regard to conflict of law principles. Any disputes will be resolved in the courts of Slovakia.
            
            29. SEVERABILITY
            
            If any provision of this EULA is held to be unenforceable or invalid, such provision will be changed and interpreted to accomplish the objectives of such provision to the greatest extent possible under applicable law, and the remaining provisions will continue in full force and effect.
            
            30. ENTIRE AGREEMENT
            
            This EULA, together with this Privacy Policy, constitutes the entire agreement between you and the Developer regarding the Licensed Application and supersedes all prior or contemporaneous understandings regarding such subject matter. No amendment to or modification of this EULA will be binding unless in writing and signed by the Developer.


            
            By using NoteWall, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service and Privacy Policy.
            
            Thank you for using NoteWall!
            """
        }
    }
}

// MARK: - Preview

struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView(triggerReason: .firstWallpaperCreated)
        
        PaywallView(triggerReason: .limitReached, allowDismiss: false)
            .preferredColorScheme(.dark)
    }
}

private enum PlanKind {
    case monthly
    case yearly
    case lifetime
    case unknown

    var friendlyName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .lifetime: return "Lifetime"
        case .unknown: return "Plan"
        }
    }
}

private struct BenefitSlide: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

private struct ParticleData {
    let opacity: Double
    let size: CGFloat
    let x: Double  // 0.0 to 1.0 (relative position)
    let y: Double  // 0.0 to 1.0 (relative position)
    let duration: Double
    let delay: Double
}

private struct LifetimePlanSheet: View {
    let priceText: String
    let subtitle: String
    let isAvailable: Bool
    let onPurchase: () -> Void
    let onDismiss: () -> Void

    @State private var animateIn = false
    @State private var pulseGlow = false
    @State private var shimmerOffset: CGFloat = -200
    @State private var floatingOffset: CGFloat = 0
    @State private var showPromoCodeSheet = false
    
    private let lifetimeFeatures = [
        ("infinity", "Forever Access", "Your goals appear every time you pick up your phone — stay consistent effortlessly"),
        ("arrow.triangle.2.circlepath", "Habit Builder", "Micro-reminders on each pickup help you follow through without thinking"),
        ("sparkles", "Daily Motivation", "Turn your phone into a focus anchor instead of a distraction magnet"),
        ("paintbrush.fill", "Unlimited Personalization", "Create unlimited NoteWalls with full customization"),
        ("crown.fill", "Lifetime Ownership", "Pay once. Use forever. No subscriptions or future charges")
    ]

    var body: some View {
        ZStack {
            // Animated mesh gradient background
            animatedBackground
            
            // Floating particles
            floatingParticles
            
            // Main content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Close button - top right
                    HStack {
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    Spacer().frame(height: 20)
                    
                    // Premium crown badge
                    ZStack {
                        // Outer glow rings
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.appAccent.opacity(0.3), Color.appAccent.opacity(0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                                .frame(width: 140 + CGFloat(i) * 30, height: 140 + CGFloat(i) * 30)
                                .scaleEffect(pulseGlow ? 1.1 : 1.0)
                                .opacity(pulseGlow ? 0.3 : 0.6)
                                .animation(
                                    Animation.easeInOut(duration: 2)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(i) * 0.3),
                                    value: pulseGlow
                                )
                        }
                        
                        // Logo with premium glow
                AppIconAnimationView(size: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: Color.appAccent.opacity(0.6), radius: 30, x: 0, y: 10)
                            .offset(y: floatingOffset)
                        
                        // Crown badge
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(red: 1, green: 0.84, blue: 0), Color(red: 1, green: 0.65, blue: 0)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 36, height: 36)
                                        .shadow(color: Color.orange.opacity(0.6), radius: 8, x: 0, y: 4)
                                    
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .offset(x: 8, y: 8)
                            }
                        }
                        .frame(width: 100, height: 100)
                        .offset(y: floatingOffset)
                    }
                    .frame(height: 180)
                    .opacity(animateIn ? 1 : 0)
                    .scaleEffect(animateIn ? 1 : 0.8)
                    .animation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1), value: animateIn)
                    
                    // Lifetime badge with shimmer
                    ZStack {
                        Text("LIFETIME")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.appAccent)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.appAccent.opacity(0.15))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.appAccent.opacity(0.4), lineWidth: 1)
                                    )
                            )
                            .overlay(
                                // Shimmer effect
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0),
                                                Color.white.opacity(0.4),
                                                Color.white.opacity(0)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .offset(x: shimmerOffset)
                                    .mask(
                                        Capsule()
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 8)
                                    )
                            )
                    }
                    .padding(.top, 8)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: animateIn)
                    
                    // Main headline
                    VStack(spacing: 12) {
                        Text("Own NoteWall+")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Forever")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.appAccent.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                .multilineTextAlignment(.center)
                    .padding(.top, 20)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateIn)
                    
                    // Price display
                    VStack(spacing: 6) {
                        Text(priceText)
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("one-time payment")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                    }
                    .padding(.top, 20)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateIn)
                    
                    // Features list
                    VStack(spacing: 14) {
                        ForEach(Array(lifetimeFeatures.enumerated()), id: \.offset) { index, feature in
                            featureRow(icon: feature.0, title: feature.1, subtitle: feature.2)
                                .opacity(animateIn ? 1 : 0)
                                .offset(x: animateIn ? 0 : -30)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.8)
                                        .delay(0.4 + Double(index) * 0.08),
                                    value: animateIn
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    
                    Spacer().frame(height: 32)
                    
                    // CTA Button with glow
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .heavy)
                        generator.impactOccurred()
                        onPurchase()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 18, weight: .bold))
                            
                            Text("Unlock Forever")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            ZStack {
                                // Glow layer
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.appAccent)
                                    .blur(radius: pulseGlow ? 20 : 15)
                                    .opacity(0.6)
                                    .scaleEffect(pulseGlow ? 1.05 : 1.0)
                                
                                // Main button
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.appAccent, Color.appAccent.opacity(0.85)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .disabled(!isAvailable)
                    .opacity(isAvailable ? 1 : 0.5)
                    .padding(.horizontal, 24)
                    .opacity(animateIn ? 1 : 0)
                    .scaleEffect(animateIn ? 1 : 0.9)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.7), value: animateIn)
                
                if !isAvailable {
                        Text("Lifetime option is currently unavailable")
                        .font(.footnote)
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.top, 12)
                    }
                    
                    // Promo Code Prompt
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        showPromoCodeSheet = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "ticket.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Do you have a promo code?")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.appAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.appAccent.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.appAccent.opacity(0.3), lineWidth: 1.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeIn.delay(0.75), value: animateIn)
                    
                    // Trust badges
                    HStack(spacing: 24) {
                        trustBadge(icon: "lock.shield.fill", text: "Secure")
                        trustBadge(icon: "arrow.triangle.2.circlepath", text: "Restore Anytime")
                        trustBadge(icon: "checkmark.seal.fill", text: "Verified")
                    }
                    .padding(.top, 24)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeIn.delay(0.8), value: animateIn)
                    
                    // Skip button
                    Button(action: onDismiss) {
                        Text("Maybe later")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeIn.delay(0.9), value: animateIn)
                }
            }
        }
        .sheet(isPresented: $showPromoCodeSheet) {
            PromoCodeInputView(
                isPresented: $showPromoCodeSheet,
                onSuccess: {
                    // Dismiss promo code sheet first
                    showPromoCodeSheet = false
                    // Set paywall manager flag to false (this will help dismiss the paywall)
                    PaywallManager.shared.shouldShowPaywall = false
                    // Trigger paywall dismissal after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // Post notification to trigger dismissal
                        NotificationCenter.default.post(name: .dismissPaywallAfterPromoCode, object: nil)
                    }
                }
            )
        }
        .onAppear {
            withAnimation {
                animateIn = true
            }
            
            // Start pulse animation
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
            
            // Start floating animation
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                floatingOffset = -8
            }
            
            // Start shimmer animation
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                shimmerOffset = 200
            }
        }
    }
    
    private var animatedBackground: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.12),
                    Color(red: 0.02, green: 0.02, blue: 0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Accent glow orbs
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
            
            // Subtle noise texture overlay
            Rectangle()
                .fill(Color.white.opacity(0.02))
                .background(
                    Image(systemName: "circle.fill")
                        .resizable()
                        .frame(width: 2, height: 2)
                        .foregroundColor(.white.opacity(0.03))
                )
        }
        .ignoresSafeArea()
    }
    
    private var floatingParticles: some View {
        GeometryReader { geo in
            ForEach(0..<15, id: \.self) { i in
                Circle()
                    .fill(Color.appAccent.opacity(Double.random(in: 0.1...0.4)))
                    .frame(width: CGFloat.random(in: 3...8), height: CGFloat.random(in: 3...8))
                    .offset(
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: CGFloat.random(in: 0...geo.size.height)
                    )
                    .offset(y: animateIn ? -20 : 20)
                    .opacity(animateIn ? 1 : 0)
                    .animation(
                        Animation.easeInOut(duration: Double.random(in: 3...5))
                            .repeatForever(autoreverses: true)
                            .delay(Double.random(in: 0...2)),
                        value: animateIn
                    )
            }
        }
        .allowsHitTesting(false)
    }
    
    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.appAccent)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.appAccent.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    private func trustBadge(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.appAccent.opacity(0.7))
            
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

private struct FallbackPlan: Identifiable {
    let id = UUID()
    let kind: PlanKind
    let label: String
    let subtitle: String
    let priceText: String
    let highlight: Bool
    let trialDays: Int?
}

// MARK: - Promo Code Input View

private struct PromoCodeInputView: View {
    @Binding var isPresented: Bool
    let onSuccess: () -> Void
    
    @State private var promoCode: String = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var redeemedCodeType: PromoCodeType?
    @State private var animateIn = false
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var checkmarkOpacity: Double = 0
    @State private var pulseGlow = false
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
        ZStack {
            // Background
            promoCodeBackground
                .ignoresSafeArea()
            
            if showSuccess {
                successView
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                inputView
                    .transition(.opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animateIn = true
            }
            // Auto-focus the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isCodeFieldFocused = true
            }
        }
    }
    
    private var promoCodeBackground: some View {
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
                        colors: [Color.appAccent.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: -120, y: -200)
                .blur(radius: 50)
                .opacity(pulseGlow ? 0.8 : 0.5)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.1), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .offset(x: 140, y: 350)
                .blur(radius: 40)
                .opacity(pulseGlow ? 0.6 : 0.4)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
    }
    
    private var inputView: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    isPresented = false
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
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Spacer()
            
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.appAccent)
                }
                .opacity(animateIn ? 1 : 0)
                .scaleEffect(animateIn ? 1 : 0.8)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateIn)
                
                // Title
                VStack(spacing: 8) {
                    Text("Enter Promo Code")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Unlock lifetime access with a valid code")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateIn)
                
                // Input field
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        TextField("Enter promo code", text: $promoCode)
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($isCodeFieldFocused)
                            .onSubmit {
                                validateAndRedeem()
                            }
                            .onChange(of: promoCode) { _, newValue in
                                // Auto-format: PREFIX-XXXX-XXXX (LT- or MO-)
                                let filtered = newValue.uppercased()
                                    .replacingOccurrences(of: " ", with: "")
                                
                                // Check if it starts with LT- or MO-
                                let prefix: String
                                let codePart: String
                                
                                if filtered.hasPrefix("LT-") {
                                    prefix = "LT-"
                                    codePart = String(String(filtered.dropFirst(3))
                                        .replacingOccurrences(of: "-", with: "")
                                        .prefix(8))
                                } else if filtered.hasPrefix("MO-") {
                                    prefix = "MO-"
                                    codePart = String(String(filtered.dropFirst(3))
                                        .replacingOccurrences(of: "-", with: "")
                                        .prefix(8))
                                } else if filtered.hasPrefix("LT") && filtered.count > 2 {
                                    prefix = "LT-"
                                    codePart = String(String(filtered.dropFirst(2))
                                        .replacingOccurrences(of: "-", with: "")
                                        .prefix(8))
                                } else if filtered.hasPrefix("MO") && filtered.count > 2 {
                                    prefix = "MO-"
                                    codePart = String(String(filtered.dropFirst(2))
                                        .replacingOccurrences(of: "-", with: "")
                                        .prefix(8))
                                } else {
                                    // No prefix yet, allow typing
                                    promoCode = filtered
                                    if errorMessage != nil {
                                        errorMessage = nil
                                    }
                                    return
                                }
                                
                                // Format code part: XXXX-XXXX
                                let formattedCodePart: String
                                if codePart.count > 4 {
                                    formattedCodePart = String(codePart.prefix(4)) + "-" + String(codePart.dropFirst(4).prefix(4))
                                } else {
                                    formattedCodePart = String(codePart)
                                }
                                
                                let formatted = prefix + formattedCodePart
                                if formatted != newValue {
                                    promoCode = formatted
                                }
                                
                                // Clear error when user types
                                if errorMessage != nil {
                                    errorMessage = nil
                                }
                            }
                        
                        if isValidating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                        } else {
                            Button(action: validateAndRedeem) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.appAccent)
                            }
                            .disabled(promoCode.isEmpty)
                            .opacity(promoCode.isEmpty ? 0.5 : 1.0)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        isCodeFieldFocused ? Color.appAccent.opacity(0.5) : Color.white.opacity(0.1),
                                        lineWidth: isCodeFieldFocused ? 2 : 1
                                    )
                            )
                    )
                    
                    // Error message
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red.opacity(0.8))
                            
                            Text(error)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                    }
                }
                .padding(.horizontal, 24)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateIn)
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    private var successView: some View {
        ZStack {
            // Brand background - black with turquoise accents
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.1, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Turquoise glow effects
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
                .offset(x: -100, y: -150)
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
                .offset(x: 150, y: 200)
                .blur(radius: 50)
            
            VStack(spacing: 0) {
                Spacer()
                
                // Enhanced success icon with brand colors
                ZStack {
                    // Outer pulsing rings - turquoise
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.appAccent.opacity(0.4),
                                        Color.appAccent.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 120 + CGFloat(i) * 35, height: 120 + CGFloat(i) * 35)
                            .scaleEffect(animateIn ? 1.15 : 1.0)
                            .opacity(animateIn ? 0.3 : 0.6)
                            .animation(
                                Animation.easeOut(duration: 1.8)
                                    .delay(Double(i) * 0.12)
                                    .repeatForever(autoreverses: false),
                                value: animateIn
                            )
                    }
                    
                    // Main checkmark circle - black with turquoise border
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.appAccent,
                                                Color.appAccent.opacity(0.7)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 4
                                    )
                            )
                            .shadow(color: Color.appAccent.opacity(0.5), radius: 20, x: 0, y: 10)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(.appAccent)
                            .scaleEffect(checkmarkScale)
                            .opacity(checkmarkOpacity)
                    }
                    .scaleEffect(animateIn ? 1 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.65), value: animateIn)
                }
                .padding(.bottom, 40)
                
                // Success message with brand styling
                VStack(spacing: 20) {
                    Text("Success! 🎉")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: Color.appAccent.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    if let codeType = redeemedCodeType {
                        if codeType == .lifetime {
                            Text("Lifetime Access Granted")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.appAccent)
                                .shadow(color: Color.appAccent.opacity(0.4), radius: 8, x: 0, y: 4)
                            
                            Text("You've redeemed a lifetime promo code.\nEnjoy unlimited NoteWall+ features forever.")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                        } else {
                            Text("Monthly Access Granted")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.appAccent)
                                .shadow(color: Color.appAccent.opacity(0.4), radius: 8, x: 0, y: 4)
                            
                            Text("You've redeemed a monthly promo code.\nEnjoy NoteWall+ features for 1 month.")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                        }
                    } else {
                        Text("Access Granted")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.appAccent)
                            .shadow(color: Color.appAccent.opacity(0.4), radius: 8, x: 0, y: 4)
                        
                        Text("Enjoy NoteWall+ features.")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 40)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.3), value: animateIn)
                
                Spacer()
            }
        }
        .onAppear {
            animateSuccess()
            // Auto-dismiss after showing success and navigate to home
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                // Post notification to navigate to home tab
                NotificationCenter.default.post(name: .navigateToHomeTab, object: nil)
                // Dismiss paywall
                onSuccess()
            }
        }
    }
    
    // MARK: - Actions
    
    private func validateAndRedeem() {
        guard !promoCode.isEmpty else {
            errorMessage = "Please enter a promo code"
            return
        }
        
        guard !isValidating else { return }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        isValidating = true
        errorMessage = nil
        
        // Validate and redeem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let validation = PromoCodeManager.shared.validateCode(promoCode)
            
            DispatchQueue.main.async {
                isValidating = false
                
                if validation.isValid {
                    // Get the code type before redeeming
                    let codeType = validation.codeType ?? .lifetime
                    
                    // Redeem the code
                    let success = PromoCodeManager.shared.redeemCode(promoCode)
                    
                    if success {
                        // Store the redeemed code type
                        redeemedCodeType = codeType
                        
                        // Dismiss keyboard immediately
                        isCodeFieldFocused = false
                        
                        // Small delay to ensure keyboard is dismissed before showing success
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Show success animation smoothly
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showSuccess = true
                            }
                            
                            // Play success sound and haptic
                            AudioServicesPlaySystemSound(1519) // Success sound
                            let notification = UINotificationFeedbackGenerator()
                            notification.notificationOccurred(.success)
                        }
                    } else {
                        errorMessage = "Failed to redeem code. Please try again."
                        let errorGenerator = UINotificationFeedbackGenerator()
                        errorGenerator.notificationOccurred(.error)
                    }
                } else {
                    // Show error
                    errorMessage = validation.message
                    
                    // Error haptic
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
                }
            }
        }
    }
    
    private func animateSuccess() {
        // Reset animation state
        animateIn = false
        checkmarkScale = 0.5
        checkmarkOpacity = 0
        
        // Animate in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            animateIn = true
        }
        
        // Animate checkmark
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }
        }
    }
}

// MARK: - Offer Code Redemption Modifier
/// ViewModifier to handle offer code redemption using StoreKit's native API
/// RevenueCat automatically detects transactions from StoreKit redemptions, so this is safe and more reliable
@available(iOS 15.0, *)
struct OfferCodeRedemptionModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var isRedeeming: Bool
    let paywallManager: PaywallManager
    let onDismiss: () -> Void
    
    func body(content: Content) -> some View {
        if #available(iOS 16.3, *) {
            content
                .offerCodeRedemption(isPresented: $isPresented) { result in
                    // Reset redeeming state
                    isRedeeming = false
                    
                    switch result {
                    case .success:
                        // RevenueCat will automatically detect the transaction via its delegate
                        // Refresh customer info after a short delay to allow transaction to process
                        Task {
                            // Wait for transaction to be processed
                            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                            
                            // Refresh customer info to sync with RevenueCat
                            await paywallManager.refreshCustomerInfo()
                            
                            // Check if user now has premium and dismiss if so
                            if paywallManager.isPremium {
                                await MainActor.run {
                                    onDismiss()
                                }
                            }
                        }
                    case .failure:
                        // User cancelled or error occurred - no action needed
                        // State is already reset
                        break
                    }
                }
        } else {
            // Fallback for iOS < 16.3: Use RevenueCat's method
            content
                .onChange(of: isPresented) { newValue in
                    if newValue && !isRedeeming {
                        isRedeeming = true
                        Purchases.shared.presentCodeRedemptionSheet()
                        
                        // Reset after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isPresented = false
                            isRedeeming = false
                            
                            // Check for updates after redemption
                            Task {
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                await paywallManager.refreshCustomerInfo()
                                if paywallManager.isPremium {
                                    await MainActor.run {
                                        onDismiss()
                                    }
                                }
                            }
                        }
                    }
                }
        }
    }
}

// MARK: - Analytics Helpers

extension PaywallView {
    /// Convert trigger reason to PaywallId for analytics
    func triggerReasonToPaywallId(_ reason: PaywallTriggerReason) -> PaywallId {
        switch reason {
        case .firstWallpaperCreated:
            return .postOnboarding
        case .limitReached:
            return .limitReached
        case .settings:
            return .settings
        case .manual:
            return .manual
        case .exitIntercept:
            return .exitIntercept
        }
    }
    
    /// Track plan selection change
    func trackPlanSelection(_ package: Package?) {
        guard let package = package else { return }
        
        let productId = package.storeProduct.productIdentifier
        let price = (package.storeProduct.price as NSDecimalNumber).doubleValue
        let currency = package.storeProduct.currencyCode
        
        // Determine period
        let period: String?
        switch package.packageType {
        case .monthly:
            period = "monthly"
        case .annual:
            period = "yearly"
        case .lifetime:
            period = "lifetime"
        default:
            period = nil
        }
        
        AnalyticsService.shared.trackPlanSelected(
            productId: productId,
            price: price,
            period: period,
            currency: currency
        )
    }
}
