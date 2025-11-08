import SwiftUI
import PhotosUI
import UIKit

private enum OnboardingPage: Int, CaseIterable, Hashable {
    case installShortcut
    case chooseWallpapers
    case overview
}

struct OnboardingView: View {
    @Binding var isPresented: Bool
    let onboardingVersion: Int
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @AppStorage("completedOnboardingVersion") private var completedOnboardingVersion = 0
    @AppStorage("lockScreenBackground") private var lockScreenBackgroundRaw = LockScreenBackgroundOption.default.rawValue
    @AppStorage("lockScreenBackgroundMode") private var lockScreenBackgroundModeRaw = LockScreenBackgroundMode.default.rawValue
    @AppStorage("lockScreenBackgroundPhotoData") private var lockScreenBackgroundPhotoData: Data = Data()

    @AppStorage("homeScreenPresetSelection") private var homeScreenPresetSelectionRaw = "black"
    @State private var didOpenShortcut = false
    @State private var isSavingHomeScreenPhoto = false
    @State private var homeScreenStatusMessage: String?
    @State private var homeScreenStatusColor: Color = .gray
    @State private var homeScreenImageAvailable = HomeScreenImageManager.homeScreenImageExists()
    @State private var isSavingLockScreenBackground = false
    @State private var lockScreenBackgroundStatusMessage: String?
    @State private var lockScreenBackgroundStatusColor: Color = .gray

    @State private var currentPage: OnboardingPage = .installShortcut

    private let shortcutURL = "https://www.icloud.com/shortcuts/66e5d23e9b0340d2b8e548c1b0cc5e04"

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                navigationStackOnboarding
            } else {
                navigationViewOnboarding
            }
        }
        .interactiveDismissDisabled()
        .safeAreaInset(edge: .bottom) {
            Button(action: handlePrimaryButton) {
                Text(primaryButtonTitle)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(primaryButtonEnabled ? Color.appAccent : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .padding(.horizontal)
            }
            .disabled(!primaryButtonEnabled)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var navigationViewOnboarding: some View {
        NavigationView {
            onboardingPager(includePhotoPicker: false)
        }
    }

    @available(iOS 16.0, *)
    private var navigationStackOnboarding: some View {
        NavigationStack {
            onboardingPager(includePhotoPicker: true)
        }
    }

    private func onboardingPager(includePhotoPicker: Bool) -> some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                installShortcutStep
                    .tag(OnboardingPage.installShortcut)

                chooseWallpapersStep(includePhotoPicker: includePhotoPicker)
                    .tag(OnboardingPage.chooseWallpapers)

                overviewStep
                    .tag(OnboardingPage.overview)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .onChange(of: currentPage) { newValue in
                if newValue != .installShortcut && !didOpenShortcut {
                    withAnimation(.easeInOut) {
                        currentPage = .installShortcut
                    }
                }
            }
        }
        .navigationTitle(currentPage.navigationTitle ?? "")
        .navigationBarTitleDisplayMode(currentPage == .chooseWallpapers ? .large : .inline)
    }

    private var installShortcutStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Welcome to NoteWall")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                setupStepCard(
                    title: "Step 1 • Install the Shortcut",
                    description: "The shortcut saves your freshly generated wallpaper to Photos and applies it for you."
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Tap the button below to download the NoteWall shortcut.")
                        Text("• When Shortcuts opens, tap “Add Shortcut”, then return here.")
                        Text("• The shortcut will set the latest NoteWall image as your lock screen.")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } footer: {
                    VStack(spacing: 12) {
                        Button(action: installShortcut) {
                            HStack {
                                Spacer()
                                Text("Install Shortcut")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding()
                            .background(Color.appAccent)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 32)
        }
    }

    @ViewBuilder
    private func chooseWallpapersStep(includePhotoPicker: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if includePhotoPicker {
                    if #available(iOS 16.0, *) {
                        setupStepCard(
                            title: "Home Screen Photo",
                            description: "Save a photo that the shortcut will reuse each time."
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                HomeScreenPhotoPickerView(
                                    isSavingHomeScreenPhoto: $isSavingHomeScreenPhoto,
                                    homeScreenStatusMessage: $homeScreenStatusMessage,
                                    homeScreenStatusColor: $homeScreenStatusColor,
                                    homeScreenImageAvailable: $homeScreenImageAvailable,
                                    handlePickedHomeScreenData: handlePickedHomeScreenData
                                )

                                HomeScreenQuickPresetsView(
                                    isSavingHomeScreenPhoto: $isSavingHomeScreenPhoto,
                                    homeScreenStatusMessage: $homeScreenStatusMessage,
                                    homeScreenStatusColor: $homeScreenStatusColor,
                                    handlePickedHomeScreenData: handlePickedHomeScreenData
                                )

                                if let message = homeScreenStatusMessage {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(homeScreenStatusColor)
                                }

                                Text("You can change this photo anytime from Settings → Home Screen Photo.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        setupStepCard(
                            title: "Lock Screen Background",
                            description: "Select the background that NoteWall will write your notes on."
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
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

                                if let message = lockScreenBackgroundStatusMessage {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(lockScreenBackgroundStatusColor)
                                }

                                Text("Pick a preset color or use the photo you just saved for your home screen.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    setupStepCard(
                        title: "Choose Your Home Screen Photo",
                        description: "This step requires iOS 16 or newer."
                    ) {
                        Text("Update to iOS 16+ to pick a photo directly. For now, the shortcut will reuse your current home screen wallpaper.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 24)
        }
    }

    private var overviewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Step 3 • Ready to Go")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Here’s a quick refresher on how NoteWall stays up to date.")
                    .font(.body)
                    .foregroundColor(.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How NoteWall Works")
                            .font(.headline)

                        Text("• Add notes in the Home tab. The newest active notes appear on your lock screen wallpaper.\n• Tap “Update Wallpaper” anytime you want a fresh image.\n• Run the shortcut to save that image to Photos and apply it as your lock screen.\n• Your home screen keeps the photo you picked, so the two wallpapers always match.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Tip: Create a Shortcuts automation to run NoteWall automatically on a schedule or as part of a Focus mode.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 32)
        }
    }

    private func setupStepCard<Content: View, Footer: View>(
        title: String,
        description: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            content()
            footer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
    }

    private var primaryButtonTitle: String {
        currentPage == .overview ? "Start Using NoteWall" : "Next"
    }

    private var primaryButtonEnabled: Bool {
        switch currentPage {
        case .installShortcut:
            return didOpenShortcut
        case .chooseWallpapers:
            return !isSavingHomeScreenPhoto && !isSavingLockScreenBackground
        case .overview:
            return true
        }
    }

    private func handlePrimaryButton() {
        if currentPage == .overview {
            completeOnboarding()
        } else {
            advanceStep()
        }
    }

    private func advanceStep() {
        guard let next = OnboardingPage(rawValue: currentPage.rawValue + 1) else { return }
        if currentPage == .chooseWallpapers {
            finalizeWallpaperSetup()
        }
        withAnimation(.easeInOut) {
            currentPage = next
        }
    }

    private func installShortcut() {
        guard let url = URL(string: shortcutURL) else { return }
        UIApplication.shared.open(url) { success in
            if success {
                didOpenShortcut = true
            }
        }
    }

    private func completeOnboarding() {
        hasCompletedSetup = true
        completedOnboardingVersion = onboardingVersion
        isPresented = false
    }

    private func finalizeWallpaperSetup() {
        NotificationCenter.default.post(name: .requestWallpaperUpdate, object: nil)
    }

    @available(iOS 16.0, *)
    private func handlePickedHomeScreenData(_ data: Data) {
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

private extension OnboardingPage {
    var navigationTitle: String? {
        switch self {
        case .installShortcut:
            return nil
        case .chooseWallpapers:
            return "Step 2 • Choose Your Wallpapers"
        case .overview:
            return "All Set"
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true), onboardingVersion: 2)
}
