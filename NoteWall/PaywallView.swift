import SwiftUI
import StoreKit

@available(iOS 15.0, *)
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var paywallManager = PaywallManager.shared
    @StateObject private var storeManager = StoreKitManager.shared
    
    let triggerReason: PaywallTriggerReason
    let allowDismiss: Bool
    
    @State private var selectedProductIndex = 0  // Default to Lifetime (index 0)
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animateIn = false
    @State private var currentStep = 1  // 1 = plan selection, 2 = trial explanation
    
    init(triggerReason: PaywallTriggerReason = .manual, allowDismiss: Bool = true) {
        self.triggerReason = triggerReason
        self.allowDismiss = allowDismiss
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.appAccent.opacity(0.15),
                    Color(.systemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
        .onAppear {
            paywallManager.trackPaywallView()
            Task {
                await storeManager.loadProducts()
            }
            
            // Trigger animations
            withAnimation {
                animateIn = true
            }
        }
    }
    
    // MARK: - Step 1: Plan Selection
    
    private var step1PlanSelection: some View {
        VStack(spacing: 20) {
                // Close button
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
                .padding(.top, 4)
                // Header
                VStack(spacing: 8) {
                    Text(triggerReason.title)
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Because if you see it - you'll do it")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateIn)
                
                
                // Features list
                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "brain.head.profile", title: "Never Forget Again", subtitle: "Keep your key goals, notes, and ideas always visible - every time you unlock your phone.", delay: 0.1)
                    featureRow(icon: "target", title: "Stay Focused, Not Busy", subtitle: "See your priorities 50× a day and act on what really matters.", delay: 0.2)
                }
                .padding(.horizontal, 4)
                
                // Pricing options
                pricingSection
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: animateIn)
                
                
                // Continue button (goes to step 2)
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = 2
                        animateIn = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            animateIn = true
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Start Free Trial")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .background(Color.appAccent)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: Color.appAccent.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .opacity(animateIn ? 1 : 0)
                .scaleEffect(animateIn ? 1 : 0.9)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.7), value: animateIn)
                .padding(.top, 8)
                
                // Terms & Privacy and Restore Purchases
                HStack(spacing: 24) {
                    Button("Terms & Privacy") {
                        // TODO: Open terms and privacy URL
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Button("Restore Purchases") {
                        Task {
                            await storeManager.restorePurchases()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 0)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeIn.delay(0.7), value: animateIn)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Step 2: Trial Explanation
    
    private var step2TrialExplanation: some View {
        VStack(spacing: 20) {
                // Close button
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
                .padding(.top, 26
                )
                // Header (matching step 1 structure)
                VStack(spacing: 8) {
                    Text("How your free trial works")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    // Add spacing to match step 1's subtitle height
                    Spacer()
                        .frame(height: 20)
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateIn)
                
                // Timeline
                trialTimeline
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
                            Text("Cancel anytime during trial. No questions asked.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appAccent.opacity(0.1))
                    .cornerRadius(12)
                    
                }
                .opacity(animateIn ? 1 : 0)
                .animation(.easeIn.delay(0.4), value: animateIn)
                
                // Start trial button with urgency
                VStack(spacing: 12) {
                    Button(action: handlePurchase) {
                        VStack(spacing: 6) {
                            if isPurchasing || storeManager.isLoading {
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
                    .disabled(isPurchasing || storeManager.isLoading)
                    
                }
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
                .padding(.top, 8)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeIn.delay(0.6), value: animateIn)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Pricing Section (iOS 15+)
    
    @available(iOS 15.0, *)
    private var pricingSection: some View {
        VStack(spacing: 12) {
            if storeManager.isLoading {
                ProgressView()
                    .padding()
            } else if storeManager.products.isEmpty {
                // Show fallback pricing when products aren't loaded from App Store Connect
                fallbackPricingCards
            } else {
                ForEach(Array(storeManager.products.enumerated()), id: \.element.id) { index, product in
                    pricingCard(for: product, index: index)
                }
            }
        }
    }
    
    // Fallback pricing cards for testing before App Store Connect setup
    private var fallbackPricingCards: some View {
        VStack(spacing: 12) {
            fallbackPricingCard(title: "NoteWall+ Lifetime", price: "€9.99", subtitle: "7-day free trial", index: 0)
            fallbackPricingCard(title: "NoteWall+ Monthly", price: "€5.99/m", subtitle: "5-day free trial", index: 1)
        }
    }
    
    private func fallbackPricingCard(title: String, price: String, subtitle: String, index: Int) -> some View {
        let isSelected = selectedProductIndex == index
        let isLifetime = index == 0  // Lifetime is now first
        
        return Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedProductIndex = index
            }
        }) {
            ZStack(alignment: .topLeading) {
                HStack(spacing: 16) {
                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.appAccent : Color.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(Color.appAccent)
                                .frame(width: 14, height: 14)
                                .scaleEffect(isSelected ? 1 : 0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isLifetime ? "Lifetime" : "Monthly")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if isLifetime {
                            Text("7-day free trial")
                                .font(.subheadline)
                                .foregroundColor(.appAccent)
                                .fontWeight(.medium)
                        } else {
                            Text("5-day free trial")
                                .font(.subheadline)
                                .foregroundColor(.appAccent)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(price)
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
                .padding(18)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: isSelected ? Color.appAccent.opacity(0.3) : Color.black.opacity(0.05), radius: isSelected ? 12 : 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.appAccent : Color.clear, lineWidth: 2)
            )
            .overlay(
                // Popular badge on the edge - in separate overlay to be above border
                Group {
                    if isLifetime {
                        HStack {
                            Spacer()
                            Text("POPULAR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.appAccent))
                                .offset(x: -8, y: -8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
            )
            .scaleEffect(isSelected ? 1.02 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
    
    @available(iOS 15.0, *)
    private func pricingCard(for product: Product, index: Int) -> some View {
        let isSelected = selectedProductIndex == index
        let isLifetime = !product.id.contains("monthly")  // Lifetime doesn't contain "monthly"
        
        return Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedProductIndex = index
            }
        }) {
            ZStack(alignment: .topLeading) {
                HStack(spacing: 16) {
                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.appAccent : Color.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(Color.appAccent)
                                .frame(width: 14, height: 14)
                                .scaleEffect(isSelected ? 1 : 0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isLifetime ? "Lifetime" : "Monthly")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if isLifetime {
                            Text("7-day free trial")
                                .font(.subheadline)
                                .foregroundColor(.appAccent)
                                .fontWeight(.medium)
                        } else {
                            Text("5-day free trial")
                                .font(.subheadline)
                                .foregroundColor(.appAccent)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(product.displayPrice)
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
                .padding(18)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: isSelected ? Color.appAccent.opacity(0.3) : Color.black.opacity(0.05), radius: isSelected ? 12 : 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.appAccent : Color.clear, lineWidth: 2)
            )
            .overlay(
                // Popular badge on the edge - in separate overlay to be above border
                Group {
                    if isLifetime {
                        HStack {
                            Spacer()
                            Text("POPULAR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.appAccent))
                                .offset(x: -8, y: -8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
            )
            .scaleEffect(isSelected ? 1.02 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
    
    
    private var purchaseButtonTitle: String {
        selectedProductIndex == 0 ? "Start 7-Day Free Trial" : "Start 5-Day Free Trial"
    }
    
    // MARK: - Actions
    
    private func handlePurchase() {
        // If products aren't loaded from App Store Connect, show helpful message
        if storeManager.products.isEmpty {
            errorMessage = "In-app purchases are not yet configured. Please set up products in App Store Connect first."
            showError = true
            return
        }
        
        guard selectedProductIndex < storeManager.products.count else {
            errorMessage = "Please select a pricing option"
            showError = true
            return
        }
        
        let product = storeManager.products[selectedProductIndex]
        
        Task {
            isPurchasing = true
            
            do {
                let transaction = try await storeManager.purchase(product)
                
                await MainActor.run {
                    isPurchasing = false
                    
                    if transaction != nil {
                        // Purchase successful with haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                    showError = true
                    
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
    
    // MARK: - Trial Timeline
    
    private var trialTimeline: some View {
        let isLifetime = selectedProductIndex == 0  // Index 0 is now Lifetime
        let trialDays = isLifetime ? 7 : 5
        let reminderDay = isLifetime ? 5 : 3
        
        return VStack(alignment: .leading, spacing: 0) {  // No spacing for continuous line
            // Today
            timelineItem(
                icon: "crown.fill",
                iconColor: .appAccent,
                title: "Today",
                subtitle: "Start enjoying full access to unlimited wallpapers.",
                isFirst: true
            )
            
            // Reminder
            timelineItem(
                icon: "bell.fill",
                iconColor: .orange,
                title: "In \(reminderDay) days",
                subtitle: "You'll get a reminder that your trial is about to end.",
                isFirst: false
            )
            
            // Charge
            timelineItem(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                title: "In \(trialDays) days",
                subtitle: isLifetime ? "Your lifetime access will begin and you'll be charged." : "Your subscription will begin and you'll be charged.",
                isFirst: false,
                isLast: true
            )
        }
        .padding(.vertical, 8)
    }
    
    private func timelineItem(icon: String, iconColor: Color, title: String, subtitle: String, isFirst: Bool = false, isLast: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Left side: icon with continuous line
            VStack(spacing: 0) {
                // Top line segment (connects to previous item)
                if !isFirst {
                    Rectangle()
                        .fill(Color.appAccent.opacity(0.3))
                        .frame(width: 2, height: 22)
                }
                
                // Icon with background
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.appAccent)
                }
                
                // Bottom line segment (connects to next item or fades out)
                if isLast {
                    // Fade out gradient for last item
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.appAccent.opacity(0.3),
                            Color.appAccent.opacity(0.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: 2, height: 40)
                } else {
                    Rectangle()
                        .fill(Color.appAccent.opacity(0.3))
                        .frame(width: 2, height: 44)  // Fixed height for consistent spacing
                }
            }
            .frame(width: 44)
            
            // Right side: title and subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)  // Align text with icon center
            
            Spacer()
        }
    }
    
    private var selectedPlanInfo: some View {
        let isLifetime = selectedProductIndex == 0  // Index 0 is now Lifetime
        let trialDays = isLifetime ? 7 : 5
        let price = isLifetime ? "€9.99" : "€5.99/month"
        let planName = isLifetime ? "Lifetime" : "Monthly"
        
        return VStack(spacing: 8) {
            Text("\(trialDays)-day free trial, then \(price)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(planName)
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
    }
    
    // MARK: - Feature Row
    
    private func featureRow(icon: String, title: String, subtitle: String, delay: Double) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.appAccent)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .opacity(animateIn ? 1 : 0)
        .offset(x: animateIn ? 0 : -20)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay), value: animateIn)
    }
    
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appAccent)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
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
