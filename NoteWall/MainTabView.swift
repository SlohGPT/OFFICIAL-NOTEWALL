import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showWallpaperUpdateLoading = false
    @State private var showTroubleshooting = false

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
            
            // Global loading overlay - shows on top of everything regardless of tab
            if showWallpaperUpdateLoading {
                WallpaperUpdateLoadingView(
                    isPresented: $showWallpaperUpdateLoading,
                    showTroubleshooting: $showTroubleshooting
                )
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
        .sheet(isPresented: $showTroubleshooting) {
            TroubleshootingView(
                isPresented: $showTroubleshooting,
                shouldRestartOnboarding: .constant(false)
            )
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
