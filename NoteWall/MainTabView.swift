import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
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
    }
}

struct BottomNavigationBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack {
            Spacer()

            // Home Tab
            Button(action: {
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
