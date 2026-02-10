import SwiftUI
import SuperwallKit

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showWallpaperUpdateLoading = false
    @State private var showDeleteNotesLoading = false
    @State private var showTroubleshooting = false
    @StateObject private var paywallManager = PaywallManager.shared
    
    // Quick Actions state
    @State private var showExitFeedback = false
    @State private var showDiscountedPaywall = false
    @State private var shouldRestartOnboarding = false
    
    // What's New popup state
    @State private var showWhatsNew = false
    
    // Pipeline migration state
    @State private var showPipelineMigrationOnboarding = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ZStack {
                    ContentView()
                        .opacity(selectedTab == 0 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 0)

                    SettingsView(selectedTab: $selectedTab)
                        .opacity(selectedTab == 1 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 1)
                }

                BottomNavigationBar(selectedTab: $selectedTab)
            }
            
            // Global loading overlays - shows on top of everything regardless of tab
            if showWallpaperUpdateLoading {
                WallpaperUpdateLoadingView(
                    isPresented: $showWallpaperUpdateLoading,
                    showTroubleshooting: $showTroubleshooting
                )
                .zIndex(1000)
            }
            
            if showDeleteNotesLoading {
                DeleteNotesLoadingView(isPresented: $showDeleteNotesLoading)
                    .zIndex(1000)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showGlobalLoadingOverlay)) { notification in
            // Show loading overlay immediately, then switch tab
            showWallpaperUpdateLoading = true
            
            // Switch to home tab after a tiny delay (overlay is already visible)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                selectedTab = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showDeleteNotesLoadingOverlay)) { notification in
            // Show delete notes loading overlay immediately, then switch tab
            showDeleteNotesLoading = true
            
            // Switch to home tab after a tiny delay (overlay is already visible)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                selectedTab = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToHomeTab)) { _ in
            // Navigate to home tab
            selectedTab = 0
        }
        // Quick Action modals
        .sheet(isPresented: $showExitFeedback) {
            ExitFeedbackView()
        }
        .sheet(isPresented: $showTroubleshooting) {
            TroubleshootingView(
                isPresented: $showTroubleshooting,
                shouldRestartOnboarding: $shouldRestartOnboarding
            )
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
        .sheet(isPresented: $paywallManager.shouldShowSuperwallPaywall) {
            if !paywallManager.superwallPlacement.isEmpty {
                SuperwallPaywallView(placement: paywallManager.superwallPlacement)
                    .interactiveDismissDisabled(true)
            }
        }
        // What's New popup for app updates (pipeline migration for pre-Feb 9th users)
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView(isPresented: $showWhatsNew, onStartMigration: {
                // User chose to switch to the new pipeline
                // Trigger the migration onboarding after a small delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showPipelineMigrationOnboarding = true
                }
            })
                .interactiveDismissDisabled(true)
        }
        // Pipeline migration onboarding (re-runs OnboardingView with paywall skipped)
        .fullScreenCover(isPresented: $showPipelineMigrationOnboarding) {
            OnboardingView(
                isPresented: $showPipelineMigrationOnboarding,
                onboardingVersion: 3,
                isPipelineMigration: true
            )
        }
        // Quick Action handler
        .onReceive(NotificationCenter.default.publisher(for: .quickActionTriggered)) { notification in
            #if DEBUG
            print("📥 MainTabView: Received quick action notification")
            #endif
            handleQuickAction(notification)
        }
        .onAppear {
            // Check if What's New popup should be shown (for app updates)
            checkAndShowWhatsNew()
            
            // Check if there's a pending Quick Action on app appear
            if let triggeredAction = QuickActionsManager.shared.triggeredAction {
                #if DEBUG
                print("📥 MainTabView: Found pending Quick Action on appear - \(triggeredAction.title)")
                #endif
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    #if DEBUG
                    print("📥 MainTabView: Processing pending Quick Action after delay")
                    #endif
                    switch triggeredAction {
                    case .claimDiscount:
                        if !PaywallManager.shared.isPremium {
                            #if DEBUG
                            print("✅ MainTabView: Opening discounted paywall (from appear)")
                            #endif
                            self.showDiscountedPaywall = true
                        }
                    case .giveFeedback:
                        #if DEBUG
                        print("✅ MainTabView: Opening feedback modal (from appear)")
                        #endif
                        self.showExitFeedback = true
                    case .shareApp:
                        #if DEBUG
                        print("✅ MainTabView: Opening share sheet (from appear)")
                        #endif
                        // Get the root view controller and present share sheet
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            SocialSharingManager.shared.shareAppReferral(from: rootViewController)
                        }
                    }
                    QuickActionsManager.shared.clearTriggeredAction()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // When app comes to foreground, check for pending Quick Actions
            #if DEBUG
            print("📱 MainTabView: App entering foreground, checking for Quick Actions")
            #endif
            if let triggeredAction = QuickActionsManager.shared.triggeredAction {
                #if DEBUG
                print("📥 MainTabView: Found pending Quick Action on foreground - \(triggeredAction.title)")
                #endif
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.handleQuickAction(Notification(name: .quickActionTriggered, object: triggeredAction))
                }
            }
        }
    }
    
    // MARK: - What's New Popup
    
    private func checkAndShowWhatsNew() {
        // Delay slightly to let the view fully appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if WhatsNewManager.shared.checkShouldShow() {
                #if DEBUG
                print("🎉 MainTabView: Showing What's New popup")
                #endif
                self.showWhatsNew = true
            }
        }
    }
    
    // MARK: - Quick Action Handler
    
    private func handleQuickAction(_ notification: Notification) {
        guard let actionType = notification.object as? QuickActionsManager.QuickActionType else {
            #if DEBUG
            print("⚠️ MainTabView: Invalid quick action notification object")
            #endif
            return
        }
        
        #if DEBUG
        print("🎬 MainTabView: Handling quick action - \(actionType.title)")
        #endif
        
        // Provide haptic feedback immediately
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Open the page immediately (no delay needed if app is already running)
        DispatchQueue.main.async {
            #if DEBUG
            print("🎯 MainTabView: Executing quick action switch statement")
            #endif
            
            switch actionType {
            case .claimDiscount:
                // Safety check: Only show discount to non-premium users
                if !PaywallManager.shared.isPremium {
                    #if DEBUG
                    print("✅ MainTabView: Setting showDiscountedPaywall = true")
                    #endif
                    self.showDiscountedPaywall = true
                } else {
                    #if DEBUG
                    print("⚠️ MainTabView: Blocked discount for premium user")
                    #endif
                }
                
            case .giveFeedback:
                #if DEBUG
                print("✅ MainTabView: Setting showExitFeedback = true")
                #endif
                self.showExitFeedback = true
                
            case .shareApp:
                #if DEBUG
                print("✅ MainTabView: Opening share sheet")
                #endif
                // Get the root view controller and present share sheet
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    SocialSharingManager.shared.shareAppReferral(from: rootViewController)
                }
            }
            
            // Clear the triggered action
            QuickActionsManager.shared.clearTriggeredAction()
            
            // Verify state was set
            #if DEBUG
            print("🔍 MainTabView: State after action - showExitFeedback: \(self.showExitFeedback), showTroubleshooting: \(self.showTroubleshooting), showDiscountedPaywall: \(self.showDiscountedPaywall)")
            #endif
        }
    }
}

struct BottomNavigationBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack {
            Spacer()

            // Home Tab
            Button(action: {
                // Light impact haptic for tab switch (only if switching to a different tab)
                if selectedTab != 0 {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
                selectedTab = 0
            }) {
                VStack(spacing: 4) {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                        .font(.title2)
                    Text("Home")
                        .font(.caption)
                }
                .foregroundColor(selectedTab == 0 ? .appAccent : .gray)
            }

            Spacer()

            // Settings Tab
            Button(action: {
                // Light impact haptic for tab switch (only if switching to a different tab)
                if selectedTab != 1 {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
                selectedTab = 1
            }) {
                VStack(spacing: 4) {
                    Image(systemName: selectedTab == 1 ? "gearshape.fill" : "gearshape")
                        .font(.title2)
                    Text("Settings")
                        .font(.caption)
                }
                .foregroundColor(selectedTab == 1 ? .appAccent : .gray)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
    }
}

#Preview {
    MainTabView()
}
