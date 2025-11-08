import SwiftUI
import PhotosUI
import UIKit
import Combine

struct SettingsView: View {
    @AppStorage("savedNotes") private var savedNotesData: Data = Data()
    @AppStorage("skipDeletingOldWallpaper") private var skipDeletingOldWallpaper = false
    @AppStorage("lockScreenBackground") private var lockScreenBackgroundRaw = LockScreenBackgroundOption.default.rawValue
    @AppStorage("lockScreenBackgroundMode") private var lockScreenBackgroundModeRaw = LockScreenBackgroundMode.default.rawValue
    @AppStorage("lockScreenBackgroundPhotoData") private var lockScreenBackgroundPhotoData: Data = Data()
    @State private var showDeleteAlert = false
    var selectedTab: Binding<Int>?

    private let shortcutURL = "https://www.icloud.com/shortcuts/62d89adfc4074e22acb0b58b11850ea4"
    private let appVersion = "1.0"
    
    init(selectedTab: Binding<Int>? = nil) {
        self.selectedTab = selectedTab
    }

    @AppStorage("homeScreenPresetSelection") private var homeScreenPresetSelectionRaw = "black"
    @State private var isSavingHomeScreenPhoto = false
    @State private var homeScreenStatusMessage: String?
    @State private var homeScreenStatusColor: Color = .gray
    @State private var homeScreenImageAvailable = HomeScreenImageManager.homeScreenImageExists()
    @State private var isSavingLockScreenBackground = false
    @State private var lockScreenBackgroundStatusMessage: String?
    @State private var lockScreenBackgroundStatusColor: Color = .gray

    var body: some View {
        NavigationView {
            settingsList
                .listStyle(.insetGrouped)
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
                .alert("Delete All Notes?", isPresented: $showDeleteAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        deleteAllNotes()
                    }
                } message: {
                    Text("This action cannot be undone. All your notes will be permanently deleted.")
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    @ViewBuilder
    private var settingsList: some View {
        List {
            appInfoSection
            wallpaperSettingsSection
            homeScreenSection
            actionsSection
            supportSection
        }
    }

    private var appInfoSection: some View {
        Section(header: Text("App Info")) {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("About App")
                    .fontWeight(.medium)
                Text("NoteWall converts your text notes into black wallpaper images with white centered text. Create notes, generate wallpapers, and set them via Shortcuts.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 4)
        }
    }

    private var wallpaperSettingsSection: some View {
        Section(header: Text("Wallpaper Settings")) {
            Toggle(isOn: $skipDeletingOldWallpaper) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skip Deleting Old Wallpapers")
                    Text("When enabled, old wallpapers won't be deleted automatically. This avoids system permission popups.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    @ViewBuilder
    private var homeScreenSection: some View {
        if #available(iOS 16.0, *) {
            Section("Home Screen Photo") {
                HomeScreenPhotoPickerView(
                    isSavingHomeScreenPhoto: $isSavingHomeScreenPhoto,
                    homeScreenStatusMessage: $homeScreenStatusMessage,
                    homeScreenStatusColor: $homeScreenStatusColor,
                    homeScreenImageAvailable: $homeScreenImageAvailable,
                    handlePickedHomeScreenData: handlePickedHomeScreenData
                )
                .listRowSeparator(.hidden)

                HomeScreenQuickPresetsView(
                    isSavingHomeScreenPhoto: $isSavingHomeScreenPhoto,
                    homeScreenStatusMessage: $homeScreenStatusMessage,
                    homeScreenStatusColor: $homeScreenStatusColor,
                    handlePickedHomeScreenData: handlePickedHomeScreenData
                )

                LockScreenBackgroundPickerView(
                    isSavingBackground: $isSavingLockScreenBackground,
                    statusMessage: $lockScreenBackgroundStatusMessage,
                    statusColor: $lockScreenBackgroundStatusColor,
                    backgroundMode: Binding(
                        get: { LockScreenBackgroundMode(rawValue: lockScreenBackgroundModeRaw) ?? .default },
                        set: { lockScreenBackgroundModeRaw = $0.rawValue }
                    ),
                    backgroundOption: Binding(
                        get: { LockScreenBackgroundOption(rawValue: lockScreenBackgroundRaw) ?? .default },
                        set: { lockScreenBackgroundRaw = $0.rawValue }
                    ),
                    backgroundPhotoData: Binding(
                        get: { lockScreenBackgroundPhotoData },
                        set: { lockScreenBackgroundPhotoData = $0 }
                    ),
                    backgroundPhotoAvailable: !lockScreenBackgroundPhotoData.isEmpty
                )
                .padding(.top, 4)

                UpdateWallpaperButton()
                    .listRowSeparator(.hidden)
                    .padding(.top, 8)
            }
        } else {
            Section(header: Text("Home Screen Photo")) {
                Text("Save a home screen image requires iOS 16 or newer.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 4)
            }
        }
    }

    private var actionsSection: some View {
        Section(header: Text("Actions")) {
            Button(action: {
                showDeleteAlert = true
            }) {
                HStack {
                    Text("Delete All Notes")
                        .foregroundColor(.red)
                    Spacer()
                }
            }

            Button(action: reinstallShortcut) {
                HStack {
                    Text("Reinstall Shortcut")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.appAccent)
                }
            }
        }
    }

    private var supportSection: some View {
        Section(header: Text("Support")) {
            HStack {
                Text("Contact")
                Spacer()
                Text("NoteWall Support")
                    .foregroundColor(.gray)
            }
        }
    }

    private func deleteAllNotes() {
        savedNotesData = Data()
        // Switch back to Home tab after deleting notes
        if let selectedTab = selectedTab {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                selectedTab.wrappedValue = 0
            }
        }
    }

    private func reinstallShortcut() {
        guard let url = URL(string: shortcutURL) else { return }
        UIApplication.shared.open(url)
    }

    @available(iOS 16.0, *)
    fileprivate func handlePickedHomeScreenData(_ data: Data) {
        isSavingHomeScreenPhoto = true
        homeScreenStatusMessage = "Saving photo…"
        homeScreenStatusColor = .gray

        Task {
            do {
                guard let image = UIImage(data: data) else {
                    throw HomeScreenImageManagerError.unableToEncodeImage
                }
                try HomeScreenImageManager.saveHomeScreenImage(image)

                await MainActor.run {
                    homeScreenImageAvailable = true
                    homeScreenStatusMessage = "Saved!"
                    homeScreenStatusColor = .green
                    lockScreenBackgroundPhotoData = data
                    lockScreenBackgroundModeRaw = LockScreenBackgroundMode.photo.rawValue
                    lockScreenBackgroundStatusMessage = "Using selected photo."
                    lockScreenBackgroundStatusColor = .green
                    homeScreenPresetSelectionRaw = ""
                }
            } catch {
                await MainActor.run {
                    homeScreenStatusMessage = error.localizedDescription
                    homeScreenStatusColor = .red
                }
            }

            await MainActor.run {
                isSavingHomeScreenPhoto = false
                isSavingLockScreenBackground = false
            }
        }
    }
}

private struct UpdateWallpaperButton: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isGenerating = false

    var body: some View {
        Button(action: triggerUpdate) {
            HStack(spacing: 12) {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(isGenerating ? "Updating…" : "Update Wallpaper Now")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.appAccent)
            .foregroundColor(.white)
            .cornerRadius(14)
            .animation(.easeInOut(duration: 0.2), value: isGenerating)
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
        .onReceive(NotificationCenter.default.publisher(for: .requestWallpaperUpdate)) { _ in
            isGenerating = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .wallpaperGenerationFinished)) { _ in
            isGenerating = false
        }
    }

    private func triggerUpdate() {
        guard !isGenerating else { return }
        isGenerating = true
        NotificationCenter.default.post(name: .requestWallpaperUpdate, object: nil)
    }
}

#Preview {
    SettingsView()
}
