import SwiftUI
import Combine
import RevenueCat
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

@available(iOS 15.0, *)
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var paywallManager = PaywallManager.shared
    
    let triggerReason: PaywallTriggerReason
    let allowDismiss: Bool
    let applyExitInterceptDiscount: Bool // 30% discount for exit-intercept
    
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
    @State private var hasInitializedPlanSelection = false
    @State private var benefitCarouselIndex = 0
    @State private var isUserDraggingBenefits = false
    @State private var lastManualSwipeTime: Date = Date()
    @State private var showRedemptionInstructions = false
    @State private var copiedPromoCode = false

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

    @GestureState private var benefitDragOffset: CGFloat = 0
    
    private let benefitsAutoScrollTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    
    init(triggerReason: PaywallTriggerReason = .manual, allowDismiss: Bool = true, applyExitInterceptDiscount: Bool = false) {
        self.triggerReason = triggerReason
        self.allowDismiss = allowDismiss
        self.applyExitInterceptDiscount = applyExitInterceptDiscount
    }
    
    var body: some View {
        ZStack {
            // Enhanced background with subtle accent glows
            paywallBackground
                .ignoresSafeArea()
            
            if currentStep == 1 {
                step1PlanSelection
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else {
                step2TrialExplanation
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
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
            
            // Track exit-intercept discount view
            if applyExitInterceptDiscount {
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
        .onChange(of: paywallManager.availablePackages) { packages in
            if selectedProductIndex >= packages.count {
                selectedProductIndex = max(0, packages.count - 1)
            }
            initializePlanSelection()
        }
        .onChange(of: shouldShowTrialStep) { hasTrial in
            if !hasTrial {
                currentStep = 1
            }
        }
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
    }
    
    // MARK: - Background
    
    private var paywallBackground: some View {
        ZStack {
            // Base dark gradient - richer than pure black
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.08),
                    Color(red: 0.01, green: 0.01, blue: 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Accent color glow orb - top left
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: -120, y: -180)
                .blur(radius: 50)
            
            // Accent color glow orb - bottom right
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.08), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .offset(x: 140, y: 320)
                .blur(radius: 40)
            
            // Very subtle noise/texture overlay for depth
            Rectangle()
                .fill(Color.white.opacity(0.015))
        }
    }
    
    // MARK: - Step 1: Plan Selection
    
    private var step1PlanSelection: some View {
        paywallScrollView {
        VStack(spacing: 20) {
                // Close button at top
                HStack {
                    Spacer()
                    Button(action: {
                        paywallManager.trackPaywallDismiss()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                logoHeader
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.85), value: animateIn)
                
                // Exit-intercept discount badge
                if applyExitInterceptDiscount {
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
                
                // Pricing options
                pricingSection
                    .padding(.horizontal, 24)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateIn)
                
                lifetimePrompt
                    .padding(.horizontal, 24)
                    .padding(.bottom, -8)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: animateIn)
                
                // Redemption instructions for exit-intercept discount
                if applyExitInterceptDiscount {
                    redemptionInstructionsButton
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .opacity(animateIn ? 1 : 0)
                        .scaleEffect(animateIn ? 1 : 0.95)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.4), value: animateIn)
                }
                
                // Continue button (goes to step 2 or purchase directly)
                Button(action: {
                    if shouldShowTrialStep {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = 2
                        animateIn = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            animateIn = true
                        }
                        }
                    } else {
                        handlePurchase()
                    }
                }) {
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            if !shouldShowTrialStep && (isPurchasing || paywallManager.isLoadingOfferings) {
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
                        
                        // Show redemption reminder for exit-intercept
                        if applyExitInterceptDiscount && !isPurchasing && !paywallManager.isLoadingOfferings {
                            Text("(Redeem code NOTEWALL30 for 30% off the yearly plan)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .frame(height: applyExitInterceptDiscount ? 70 : 60)
                    .frame(maxWidth: .infinity)
                    .background(Color.appAccent)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Color.appAccent.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 24)
                .disabled(!shouldShowTrialStep && (isPurchasing || paywallManager.isLoadingOfferings))
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
                        if let url = URL(string: "https://peat-appendix-c3c.notion.site/PRIVACY-POLICY-2b7f6a63758f804cab16f58998d7787e?source=copy_link") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    
                    Button("Restore Purchases") {
                        Task {
                            await paywallManager.restoreRevenueCatPurchases()
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
        }
    }
    
    // MARK: - Step 2: Trial Explanation
    
    private var step2TrialExplanation: some View {
        paywallScrollView {
        VStack(spacing: 20) {
                // Close button at top
                HStack {
                    Spacer()
                    Button(action: {
                        paywallManager.trackPaywallDismiss()
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
            Image("OnboardingLogo")
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(width: 160, height: 160)
                .cornerRadius(44)
                .overlay(
                    RoundedRectangle(cornerRadius: 44)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 7)
        }
        .padding(.horizontal, 12)
    }
    
    private var exitInterceptDiscountBadge: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.yellow)
                
                Text("SPECIAL OFFER")
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
            
            VStack(spacing: 8) {
                Text("30% OFF Yearly Plan - Your Exclusive Code:")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                // Promo code display
                Button(action: {
                    UIPasteboard.general.string = "NOTEWALL30"
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // Show checkmark animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        copiedPromoCode = true
                    }
                    
                    // Reset after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            copiedPromoCode = false
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("NOTEWALL30")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(.appAccent)
                        
                        Image(systemName: copiedPromoCode ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            .font(.system(size: 14))
                            .foregroundColor(copiedPromoCode ? .green : .appAccent.opacity(0.7))
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: copiedPromoCode)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.appAccent.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(copiedPromoCode ? Color.green.opacity(0.5) : Color.appAccent.opacity(0.5), lineWidth: 1.5)
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: copiedPromoCode)
                    )
                }
                
                Text(copiedPromoCode ? "✓ Copied to clipboard!" : "Tap to copy code")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(copiedPromoCode ? .green : .white.opacity(0.5))
                    .animation(.easeInOut(duration: 0.2), value: copiedPromoCode)
            }
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
                    }
                }
                .offset(x: baseOffset + benefitDragOffset)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: benefitCarouselIndex)
                .frame(width: screenWidth, height: cardHeight, alignment: .leading)
                .clipped()
                .gesture(
                    DragGesture()
                        .updating($benefitDragOffset) { value, state, _ in
                            state = value.translation.width
                        }
                        .onChanged { _ in
                            if !isUserDraggingBenefits {
                                isUserDraggingBenefits = true
                                lastManualSwipeTime = Date()
                            }
                        }
                        .onEnded { value in
                            isUserDraggingBenefits = false
                            lastManualSwipeTime = Date()
                            handleCarouselDragEnd(
                                translation: value.translation.width,
                                itemWidth: itemWidth,
                                originalCount: originalCount,
                                totalCount: slides.count
                            )
                        }
                )
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
            
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
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
                .fill(Color(red: 27/255, green: 28/255, blue: 37/255).opacity(0.6))
        )
    }
    
    private var lifetimePrompt: some View {
        VStack(spacing: 6) {
            Text("Want a lifetime solution?")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Button(action: {
                showLifetimeSheet = true
            }) {
                Text("Unlock once, own NoteWall+ forever →")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.appAccent)
            }
            .buttonStyle(.plain)
        }
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
            Text("""
            1. Copy the code: NOTEWALL30
            2. Subscribe to the YEARLY plan below
            3. Open App Store → Profile → Redeem
            4. Paste the code to get 30% off!
            
            The discount applies to the yearly subscription only.
            """)
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
        // Only show Monthly and Yearly in main paywall (exclude Lifetime)
        availablePackages.filter { 
            let kind = planKind(for: $0)
            return kind == .monthly || kind == .yearly
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
        case .yearly:
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

    private var shouldShowTrialStep: Bool {
        selectedPlanKind == .yearly && trialDaysForSelectedPackage(selectedPackage) != nil
    }

    private var monthlyPackage: Package? {
        availablePackages.first { planKind(for: $0) == .monthly }
    }
    
    private var lifetimePackage: Package? {
        availablePackages.first { planKind(for: $0) == .lifetime }
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
        guard let lifetimeIndex = availablePackages.firstIndex(where: { planKind(for: $0) == .lifetime }) else {
            return false
        }
        selectedProductIndex = lifetimeIndex
        return true
    }

    private var fallbackPlans: [FallbackPlan] {
        [
            FallbackPlan(
                kind: .yearly,
                label: "Yearly",
                subtitle: "",
                priceText: "€14.99",
                highlight: true,
                trialDays: 3
            ),
            FallbackPlan(
                kind: .monthly,
                label: "Monthly",
                subtitle: "",
                priceText: "€6.99",
                highlight: false,
                trialDays: 3
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
        let isYearlyPlan = plan.kind == .yearly
        let showExitDiscount = applyExitInterceptDiscount && isYearlyPlan
        
        // Determine display price and original price
        let displayPrice: String
        let originalPrice: String?
        if showExitDiscount {
            // Show $9.99 (or €9.99) as discounted price
            displayPrice = plan.priceText.contains("€") ? "€9.99" : "$9.99"
            originalPrice = plan.priceText // Show original with strikethrough
        } else {
            displayPrice = plan.priceText
            originalPrice = nil
        }
        
        let perMonthText: String?
        if plan.kind == .monthly {
            perMonthText = "\(displayPrice)/mo"
        } else if plan.kind == .yearly {
            if showExitDiscount {
                // Calculate per month for discounted yearly: $9.99 / 12 = $0.83/mo
                perMonthText = plan.priceText.contains("€") ? "€0.83/mo" : "$0.83/mo"
            } else {
                // Calculate per month for yearly: €14.99 / 12 = €1.25/mo
                perMonthText = plan.priceText.contains("€") ? "€1.25/mo" : "$1.25/mo"
            }
        } else {
            perMonthText = nil
        }
        
        let badgeText: String?
        if plan.kind == .yearly {
            if showExitDiscount {
                badgeText = "USE CODE FOR 30% OFF"
            } else {
                // Monthly is €6.99 × 12 = €83.88
                // Yearly is €14.99
                // Savings: (83.88 - 14.99) / 83.88 = 82%
                badgeText = "82% OFF"
            }
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
        
        // Determine if this is a yearly plan
        let isYearlyPlan = planLabel.lowercased().contains("year")
        
        // Show discounted price if exit-intercept discount is enabled
        let displayPrice: String
        let showOriginalPrice: String?
        
        if applyExitInterceptDiscount && isYearlyPlan {
            // Show $9.99 (or equivalent) as discounted price for exit-intercept
            let discountedPriceString = getExitInterceptDiscountedPrice(for: package)
            displayPrice = discountedPriceString
            showOriginalPrice = package.localizedPriceString // Show original with strikethrough
        } else {
            displayPrice = package.localizedPriceString
            showOriginalPrice = nil
        }

        // Only show "USE CODE FOR 30% OFF" badge on yearly plans
        let exitBadgeText = (applyExitInterceptDiscount && isYearlyPlan) ? "USE CODE FOR 30% OFF" : nil
        
        return selectablePricingCard(
            planLabel: planLabel,
            subtitle: "", // No subtitle
            price: displayPrice,
            originalPrice: showOriginalPrice,
            highlight: highlight,
            index: index,
            perMonthText: perMonthText(for: package, displayAlways: true, applyDiscount: applyExitInterceptDiscount && isYearlyPlan),
            badgeText: exitBadgeText ?? discountBadgeText(for: package)
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
        let isMonthlyPlan = planLabel.lowercased().contains("month")
        let isYearlyPlan = planLabel.lowercased().contains("year")
        let selectionAnimation: Animation = isYearlyPlan
            ? .spring(response: 0.32, dampingFraction: 0.65)
            : .easeOut(duration: 0.18)
        
        return Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(selectionAnimation) {
                selectedProductIndex = index
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
                    
                VStack(alignment: .leading, spacing: isYearlyPlan ? 6 : 2) {
                        Text(planLabel)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    // For yearly, show price below the title
                    if isYearlyPlan {
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
            .padding(.vertical, isYearlyPlan ? 18 : 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appAccent.opacity(0.12))
                    .shadow(color: (isSelected && isYearlyPlan) ? Color.appAccent.opacity(0.25) : Color.black.opacity(0.05), radius: isSelected ? 14 : 6, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke((isSelected && isYearlyPlan) ? Color.appAccent : Color.clear, lineWidth: 2)
            )
            .overlay(
                Group {
                    if let badgeText {
                        badgeLabel(text: badgeText)
                    }
                }
            )
            .scaleEffect((isSelected && isYearlyPlan) ? 1.02 : 1)
            .animation(selectionAnimation, value: isSelected)
        }
        .buttonStyle(.plain)
    }
    
    private func packageSubtitle(for package: Package) -> String {
        if let discount = package.storeProduct.introductoryDiscount {
            let period = trialDescription(for: discount.subscriptionPeriod)
            return period.isEmpty ? "Includes trial" : "\(period) free trial"
        }

        if package.packageType == .lifetime {
            return "Own NoteWall+ forever"
        }

        return ""
    }

    private func trialDescription(for period: SubscriptionPeriod?) -> String {
        guard let period else { return "" }
        switch period.unit {
        case .day:
            return period.value == 1 ? "1-day" : "\(period.value)-day"
        case .week:
            return period.value == 1 ? "1-week" : "\(period.value)-week"
        case .month:
            return period.value == 1 ? "1-month" : "\(period.value)-month"
        case .year:
            return period.value == 1 ? "1-year" : "\(period.value)-year"
        @unknown default:
            return ""
        }
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

    private func isLifetimePlan(_ package: Package?) -> Bool {
        guard let package else { return selectedProductIndex == 0 }
        if package.packageType == .lifetime { return true }
        return package.storeProduct.productIdentifier.lowercased().contains("lifetime")
    }

    private func trialDaysForSelectedPackage(_ package: Package?) -> Int? {
        if let period = package?.storeProduct.introductoryDiscount?.subscriptionPeriod {
            return convertPeriodToDays(period)
        }
        return currentFallbackPlan?.trialDays
    }

    private func convertPeriodToDays(_ period: SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day:
            return period.value
        case .week:
            return period.value * 7
        case .month:
            return period.value * 30
        case .year:
            return period.value * 365
        @unknown default:
            return period.value
        }
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
            let days = trialDays ?? 3
            return "Start \(days)-day free trial"
        case .monthly:
            return "Continue"
        case .lifetime:
            return "Unlock lifetime access"
        case .unknown:
            return "Continue"
        }
    }
    
    // MARK: - Actions
    
    private func initializePlanSelection() {
        guard !hasInitializedPlanSelection else { return }
        let packages = paywallManager.availablePackages
        
        guard !packages.isEmpty else { return }
        
        // Find yearly package index in availablePackages
        if let yearlyIndex = packages.firstIndex(where: { planKind(for: $0) == .yearly }) {
            selectedProductIndex = yearlyIndex
            hasInitializedPlanSelection = true
        } else if !packages.isEmpty {
            // If no yearly package, select first available (but mark as initialized)
            selectedProductIndex = 0
            hasInitializedPlanSelection = true
        }
    }
    
    @ViewBuilder
    private func paywallScrollView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            content()
        }
    }
    
    private func handlePurchase() {
        guard let package = selectedPackage else {
            errorMessage = availablePackages.isEmpty
            ? "Products are still loading. Please try again in a moment."
            : "Please select a pricing option."
            showError = true
            return
        }
        
        Task {
            isPurchasing = true
            do {
                try await paywallManager.purchase(package: package)
                await MainActor.run {
                    isPurchasing = false
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        dismiss()
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = paywallManager.lastErrorMessage ?? error.localizedDescription
                    showError = true
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
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
            let currencyCode = locale.currencyCode ?? "USD"
            
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
    
    /// Returns $9.99 (or equivalent) for exit-intercept discount display
    private func getExitInterceptDiscountedPrice(for package: Package) -> String {
        let formatter = currencyFormatter(for: package)
        let locale = formatter.locale ?? Locale.current
        
        // Determine currency and set appropriate discounted price
        let currencyCode = locale.currencyCode ?? "USD"
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
                Image("OnboardingLogo")
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                            .frame(width: 100, height: 100)
                            .cornerRadius(26)
                            .shadow(color: Color.appAccent.opacity(0.6), radius: 30, x: 0, y: 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 26)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
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

