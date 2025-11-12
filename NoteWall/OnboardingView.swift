import SwiftUI
import PhotosUI
import UIKit
import QuartzCore

private enum OnboardingPage: Int, CaseIterable, Hashable {
    case installShortcut
    case addNotes
    case chooseWallpapers
    case allowPermissions
    case overview
}

struct OnboardingView: View {
    @Binding var isPresented: Bool
    let onboardingVersion: Int
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @AppStorage("completedOnboardingVersion") private var completedOnboardingVersion = 0
    @AppStorage("lockScreenBackground") private var lockScreenBackgroundRaw = LockScreenBackgroundOption.default.rawValue
    @AppStorage("lockScreenBackgroundMode") private var lockScreenBackgroundModeRaw = LockScreenBackgroundMode.default.rawValue
    @AppStorage("lockScreenBackgroundPhotoData") private var lockScreenBackgroundPhotoData: Data = Data()

    @AppStorage("homeScreenPresetSelection") private var homeScreenPresetSelectionRaw = ""
    @AppStorage("homeScreenUsesCustomPhoto") private var homeScreenUsesCustomPhoto = false
    @AppStorage("savedNotes") private var savedNotesData: Data = Data()
    @State private var didOpenShortcut = false
    @State private var isSavingHomeScreenPhoto = false
    @State private var homeScreenStatusMessage: String?
    @State private var homeScreenStatusColor: Color = .gray
    @State private var isSavingLockScreenBackground = false
    @State private var lockScreenBackgroundStatusMessage: String?
    @State private var lockScreenBackgroundStatusColor: Color = .gray

    @State private var currentPage: OnboardingPage = .installShortcut
    @State private var isLaunchingShortcut = false
    @State private var shortcutLaunchFallback: DispatchWorkItem?
    @State private var didTriggerShortcutRun = false
    @State private var isLoadingWallpaperStep = false
    
    // Notes management for onboarding
    @State private var onboardingNotes: [Note] = []
    @State private var currentNoteText = ""
    @FocusState private var isNoteFieldFocused: Bool

    private let shortcutURL = "https://www.icloud.com/shortcuts/a00482ed7b054ee0b42d7d9a7796c7eb"

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                navigationStackOnboarding
            } else {
                navigationViewOnboarding
            }
        }
        .interactiveDismissDisabled()
        .onReceive(NotificationCenter.default.publisher(for: .shortcutWallpaperApplied)) { _ in
            completeShortcutLaunch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .wallpaperGenerationFinished)) { _ in
            handleWallpaperGenerationFinished()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                advanceAfterShortcutInstallIfNeeded()
                completeShortcutLaunch()
            }
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
            onboardingProgressIndicatorCompact
                .padding(.top, 16)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
                .background(
                    Color(.systemBackground)
                        .ignoresSafeArea()
                )

            Group {
                switch currentPage {
                case .installShortcut:
                    installShortcutStep()
                case .addNotes:
                    addNotesStep()
                case .chooseWallpapers:
                    chooseWallpapersStep(includePhotoPicker: includePhotoPicker)
                case .allowPermissions:
                    allowPermissionsStep()
                case .overview:
                    overviewStep()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(currentPage)
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            .animation(.easeInOut(duration: 0.25), value: currentPage)
            .gesture(
                DragGesture()
                    .onEnded { gesture in
                        handleSwipeGesture(gesture)
                    }
            )

            primaryButtonSection
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var onboardingProgressIndicatorCompact: some View {
        HStack(alignment: .center, spacing: 12) {
            ForEach(OnboardingPage.allCases, id: \.self) { page in
                progressIndicatorItem(for: page, displayMode: .compact)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("\(currentPage.accessibilityLabel) of \(OnboardingPage.allCases.count)")
    }

    private var primaryButtonSection: some View {
        VStack(spacing: 12) {
            Button(action: handlePrimaryButton) {
                HStack(spacing: 12) {
                    if currentPage == .chooseWallpapers && isLaunchingShortcut {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .tint(.white)
                    } else if let iconName = primaryButtonIconName {
                        Image(systemName: iconName)
                            .font(.system(size: 20, weight: .semibold))
                    }

                    Text(primaryButtonTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(height: 56)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: primaryButtonEnabled))
            .disabled(!primaryButtonEnabled)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }

    private func installShortcutStep() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Install the NoteWall Shortcut")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)

                demoVideoPlaceholder
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 32)
        }
        .scrollAlwaysBounceIfAvailable()
    }
    
    private func addNotesStep() -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Add Your First Notes")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                    
                    Text("These notes will appear on your lock screen wallpaper")
                        .font(.system(.title3))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 16) {
                        // Display existing notes
                        ForEach(onboardingNotes) { note in
                            HStack(spacing: 12) {
                                Text("\(noteIndex(for: note) + 1).")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, alignment: .leading)
                                
                                Text(note.text)
                                    .font(.system(.body))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Button(action: {
                                    withAnimation {
                                        removeNote(note)
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 20))
                                }
                            }
                            .padding(16)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .id(note.id)
                        }
                        
                        // Input field for new note
                        HStack(spacing: 12) {
                            TextField("Type a note...", text: $currentNoteText)
                                .font(.system(.body))
                                .focused($isNoteFieldFocused)
                                .onSubmit {
                                    addCurrentNote(scrollProxy: proxy)
                                }
                            
                            Button(action: {
                                addCurrentNote(scrollProxy: proxy)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(currentNoteText.isEmpty ? .gray : .appAccent)
                            }
                            .disabled(currentNoteText.isEmpty)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .id("inputField")
                        
                        if onboardingNotes.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary.opacity(0.5))
                                
                                Text("Add at least one note to continue")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 32)
            }
            .scrollAlwaysBounceIfAvailable()
            .onTapGesture {
                // Dismiss keyboard when tapping outside
                isNoteFieldFocused = false
            }
            .onAppear {
                // Focus the text field when the view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isNoteFieldFocused = true
                }
            }
        }
    }
    
    private func addCurrentNote(scrollProxy: ScrollViewProxy) {
        let trimmed = currentNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        withAnimation {
            let newNote = Note(text: trimmed, isCompleted: false)
            onboardingNotes.append(newNote)
            currentNoteText = ""
            isNoteFieldFocused = true
            
            // Scroll to the newly added note with center anchor
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrollProxy.scrollTo(newNote.id, anchor: .center)
                }
            }
        }
    }
    
    private func removeNote(_ note: Note) {
        if let index = onboardingNotes.firstIndex(where: { $0.id == note.id }) {
            onboardingNotes.remove(at: index)
        }
    }
    
    private func noteIndex(for note: Note) -> Int {
        return onboardingNotes.firstIndex(where: { $0.id == note.id }) ?? 0
    }

    private func allowPermissionsStep() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Allow Permissions")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 20) {
                    Text("After installing the shortcut, you'll see privacy notifications at the top of your screen.")
                        .font(.system(.title3))
                        .foregroundColor(.secondary)

                    // Sample notification image
                    VStack(spacing: 16) {
                        Image("notification")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                        // Arrow pointing up
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.appAccent)
                            
                            Text("Click \"Allow\" for ALL permissions")
                                .font(.system(.title2))
                                .fontWeight(.semibold)
                                .foregroundColor(.appAccent)
                                .multilineTextAlignment(.center)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why these permissions are needed:")
                            .font(.system(.headline))
                            .foregroundColor(.primary)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "photo.on.rectangle")
                                    .foregroundColor(.appAccent)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Photos Access")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("To save and apply wallpapers to your device")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "folder")
                                    .foregroundColor(.appAccent)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Files Access")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("To read wallpaper files created by the app")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    Text("💡 Tip: If you accidentally tap \"Don't Allow\", you can change permissions later in Settings > Shortcuts > NoteWall")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 32)
        }
        .scrollAlwaysBounceIfAvailable()
    }

    @ViewBuilder
    private func chooseWallpapersStep(includePhotoPicker: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Choose Your Wallpapers")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Edit Notes button to go back to step 2
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage = .addNotes
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Edit Notes")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.appAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.appAccent.opacity(0.1))
                        )
                    }
                }

                if includePhotoPicker {
                    if #available(iOS 16.0, *) {
                        if isLoadingWallpaperStep {
                            VStack(spacing: 16) {
                                LoadingPlaceholder()
                                LoadingPlaceholder()
                                LoadingPlaceholder()
                            }
                            .transition(.opacity)
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                HomeScreenPhotoPickerView(
                                    isSavingHomeScreenPhoto: $isSavingHomeScreenPhoto,
                                    homeScreenStatusMessage: $homeScreenStatusMessage,
                                    homeScreenStatusColor: $homeScreenStatusColor,
                                    homeScreenImageAvailable: Binding(
                                        get: { homeScreenUsesCustomPhoto },
                                        set: { homeScreenUsesCustomPhoto = $0 }
                                    ),
                                    handlePickedHomeScreenData: handlePickedHomeScreenData
                                )

                                HomeScreenQuickPresetsView(
                                    isSavingHomeScreenPhoto: $isSavingHomeScreenPhoto,
                                    homeScreenStatusMessage: $homeScreenStatusMessage,
                                    homeScreenStatusColor: $homeScreenStatusColor,
                                    homeScreenImageAvailable: Binding(
                                        get: { homeScreenUsesCustomPhoto },
                                        set: { homeScreenUsesCustomPhoto = $0 }
                                    ),
                                    handlePickedHomeScreenData: handlePickedHomeScreenData
                                )

                                if let message = homeScreenStatusMessage {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(homeScreenStatusColor)
                                }
                                
                                Divider()
                                    .padding(.vertical, 12)

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
                            }
                            .transition(.opacity)
                        }
                    }
                } else {
                        Text("Update to iOS 16+ to pick a photo directly. For now, the shortcut will reuse your current home screen wallpaper.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 32)
        }
        .onAppear(perform: ensureCustomPhotoFlagIsAccurate)
        .scrollAlwaysBounceIfAvailable()
    }

    private func overviewStep() -> some View {
        ScrollView {
            VStack(spacing: 28) {
                overviewHeroCard

                VStack(alignment: .leading, spacing: 18) {
                    Text("Here's how NoteWall keeps everything fresh.")
                        .font(.body)
                        .foregroundColor(.secondary)

                    VStack(spacing: 16) {
                        overviewInfoCard(
                            title: "Capture Notes Fast",
                            subtitle: "Add or pin notes in the Home tab whenever inspiration hits.",
                            icon: "square.and.pencil"
                        )

                        overviewInfoCard(
                            title: "Update the Wallpaper",
                            subtitle: "Tap \"Update Wallpaper\" to create the latest lock screen image with your current notes.",
                            icon: "paintbrush"
                        )

                        overviewInfoCard(
                            title: "Apply with Shortcuts",
                            subtitle: "Run the NoteWall shortcut to save the image to Photos and set it as your lock screen.",
                            icon: "app.badge.checkmark"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                overviewAutomationCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 36)
        }
        .scrollAlwaysBounceIfAvailable()
    }

    private var demoVideoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.systemGray6))
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color.appAccent)
                    Text("Demo video coming soon")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            )
            .frame(height: 200)
            .accessibilityHidden(true)
    }

    private var primaryButtonTitle: String {
        switch currentPage {
        case .overview:
            return "Start Using NoteWall"
        case .chooseWallpapers:
            return isLaunchingShortcut ? "Launching Shortcut…" : "Next"
        case .allowPermissions:
            return "Continue"
        case .installShortcut:
            return didOpenShortcut ? "Next" : "Install Shortcut"
        case .addNotes:
            return "Continue"
        }
    }

    private var primaryButtonIconName: String? {
        switch currentPage {
        case .overview:
            return "checkmark.circle.fill"
        case .chooseWallpapers:
            return isLaunchingShortcut ? nil : "paintbrush.pointed.fill"
        case .allowPermissions:
            return "checkmark.shield.fill"
        case .installShortcut:
            return "bolt.fill"
        case .addNotes:
            return "arrow.right.circle.fill"
        }
    }

    private var primaryButtonEnabled: Bool {
        switch currentPage {
        case .installShortcut:
            return true
        case .addNotes:
            return !onboardingNotes.isEmpty
        case .allowPermissions:
            return true
        case .chooseWallpapers:
            let hasHomeSelection = homeScreenUsesCustomPhoto || !homeScreenPresetSelectionRaw.isEmpty
            let hasLockSelection: Bool
            if let mode = LockScreenBackgroundMode(rawValue: lockScreenBackgroundModeRaw) {
                if mode == .photo {
                    hasLockSelection = !lockScreenBackgroundPhotoData.isEmpty
                } else if mode == .notSelected {
                    hasLockSelection = false
                } else {
                    hasLockSelection = true
                }
            } else {
                hasLockSelection = false
            }
            return hasHomeSelection && hasLockSelection && !isSavingHomeScreenPhoto && !isSavingLockScreenBackground && !isLaunchingShortcut
        case .overview:
            return true
        }
    }

    private func handlePrimaryButton() {
        print("🎯 Onboarding: Primary button tapped on page: \(currentPage.progressTitle)")
        
        // Dismiss keyboard before any transition for smooth animation
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        switch currentPage {
        case .installShortcut:
            if didOpenShortcut {
                print("   → Advancing to add notes")
                // Small delay to let keyboard dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.currentPage = .addNotes
                    }
                }
            } else {
                print("   → Opening shortcut installation")
                installShortcut()
            }
        case .addNotes:
            print("   → Advancing to wallpaper selection")
            // Show loading state
            isLoadingWallpaperStep = true
            // Small delay to let keyboard dismiss and show loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.currentPage = .chooseWallpapers
                }
                // Hide loading after transition completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.isLoadingWallpaperStep = false
                }
            }
        case .chooseWallpapers:
            print("   → Starting wallpaper generation and shortcut launch")
            startShortcutLaunch()
        case .allowPermissions:
            print("   → Advancing to overview")
            advanceStep()
        case .overview:
            print("   → Completing onboarding")
            completeOnboarding()
        }
    }

    private func advanceStep() {
        guard let next = OnboardingPage(rawValue: currentPage.rawValue + 1) else { 
            print("⚠️ Onboarding: Cannot advance - already at last step")
            return 
        }
        print("➡️ Onboarding: Advancing from \(currentPage.progressTitle) to \(next.progressTitle)")
        withAnimation(.easeInOut) {
            currentPage = next
        }
    }
    
    private func goBackStep() {
        guard currentPage.rawValue > 0 else { return }
        guard let previous = OnboardingPage(rawValue: currentPage.rawValue - 1) else { return }
        withAnimation(.easeInOut) {
            currentPage = previous
        }
    }
    
    private func handleSwipeGesture(_ gesture: DragGesture.Value) {
        let horizontalAmount = gesture.translation.width
        let verticalAmount = abs(gesture.translation.height)
        
        // Only handle horizontal swipes (not vertical)
        guard abs(horizontalAmount) > verticalAmount else { return }
        
        // Swipe right to go back
        if horizontalAmount > 50 {
            // Only allow going back from overview to chooseWallpapers
            if currentPage == .overview {
                goBackStep()
            }
        }
        // Swipe left to go forward (optional, can be removed if not desired)
        else if horizontalAmount < -50 {
            if currentPage == .installShortcut && didOpenShortcut {
                currentPage = .chooseWallpapers
            } else if currentPage == .chooseWallpapers && primaryButtonEnabled {
                startShortcutLaunch()
            } else if currentPage == .allowPermissions {
                advanceStep()
            }
        }
    }

    private func startShortcutLaunch() {
        print("🚀 Onboarding: Starting shortcut launch sequence")
        guard !isSavingHomeScreenPhoto, !isSavingLockScreenBackground, !isLaunchingShortcut else { 
            print("   ⚠️ Cannot start - already in progress")
            return 
        }
        print("   ✅ Validation passed")
        print("   📋 Home screen selection: \(homeScreenUsesCustomPhoto ? "Custom Photo" : homeScreenPresetSelectionRaw)")
        print("   📋 Lock screen mode: \(lockScreenBackgroundModeRaw)")
        
        // Save notes BEFORE generating wallpaper so ContentView can read them
        saveOnboardingNotes()
        
        isLaunchingShortcut = true
        didTriggerShortcutRun = false
        shortcutLaunchFallback?.cancel()

        let fallback = DispatchWorkItem {
            // Check if we're on chooseWallpapers (Step 2) - if so, we're waiting for shortcut to launch
            if self.currentPage == .chooseWallpapers {
                if self.isLaunchingShortcut && !self.didTriggerShortcutRun {
                    print("⏰ Onboarding: Fallback triggered - opening shortcut")
                    self.openShortcutToApplyWallpaper()
                }
            }
        }
        shortcutLaunchFallback = fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: fallback)

        print("   📤 Posting wallpaper update request")
        finalizeWallpaperSetup()
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
        // Save notes to AppStorage before completing
        saveOnboardingNotes()
        
        hasCompletedSetup = true
        completedOnboardingVersion = onboardingVersion
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
        isPresented = false
    }
    
    private func saveOnboardingNotes() {
        guard !onboardingNotes.isEmpty else { return }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(onboardingNotes)
            savedNotesData = data
            print("✅ Saved \(onboardingNotes.count) notes from onboarding")
        } catch {
            print("❌ Failed to save onboarding notes: \(error)")
        }
    }

    private func finalizeWallpaperSetup() {
        // Don't track onboarding wallpaper for paywall limit
        let request = WallpaperUpdateRequest(skipDeletionPrompt: true, trackForPaywall: false)
        
        // Small delay to ensure ContentView has loaded the notes from savedNotesData
        // The onChange handler needs time to trigger after saveOnboardingNotes()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: .requestWallpaperUpdate, object: request)
        }
    }

    private func completeShortcutLaunch() {
        print("✅ Onboarding: Shortcut launch completed")
        shortcutLaunchFallback?.cancel()
        shortcutLaunchFallback = nil
        guard isLaunchingShortcut else { 
            print("   ℹ️ Not in launching state, skipping")
            return 
        }
        isLaunchingShortcut = false
        didTriggerShortcutRun = false
        if currentPage == .chooseWallpapers {
            print("   → Advancing to Allow Permissions step")
            currentPage = .allowPermissions
        }
    }

    private func handleWallpaperGenerationFinished() {
        print("📱 Onboarding: Wallpaper generation finished")
        guard isLaunchingShortcut, currentPage == .chooseWallpapers, !didTriggerShortcutRun else { 
            print("   Skipping shortcut launch (already triggered or not in onboarding)")
            return 
        }
        print("   Onboarding opening shortcut now")
        didTriggerShortcutRun = true
        openShortcutToApplyWallpaper()
    }

    private func openShortcutToApplyWallpaper() {
        let shortcutName = "Set NoteWall Wallpaper"
        let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "shortcuts://run-shortcut?name=\(encodedName)"
        guard let url = URL(string: urlString) else { return }
        didTriggerShortcutRun = true
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                DispatchQueue.main.async {
                    self.didTriggerShortcutRun = false
                    self.isLaunchingShortcut = false
                }
            }
        }
    }

    @available(iOS 16.0, *)
    private func handlePickedHomeScreenData(_ data: Data) {
        print("📸 Onboarding: Handling picked home screen data")
        print("   Data size: \(data.count) bytes")
        isSavingHomeScreenPhoto = true
        homeScreenStatusMessage = "Saving photo…"
        homeScreenStatusColor = .gray

        Task {
            do {
                guard let image = UIImage(data: data) else {
                    throw HomeScreenImageManagerError.unableToEncodeImage
                }
                print("   Image size: \(image.size)")
                try HomeScreenImageManager.saveHomeScreenImage(image)
                print("✅ Onboarding: Saved custom home screen photo")
                if let url = HomeScreenImageManager.homeScreenImageURL() {
                    print("   File path: \(url.path)")
                    print("   File exists: \(FileManager.default.fileExists(atPath: url.path))")
                }

                await MainActor.run {
                    homeScreenUsesCustomPhoto = true
                    homeScreenStatusMessage = nil
                    homeScreenStatusColor = .gray
                    homeScreenPresetSelectionRaw = ""
                    print("   homeScreenUsesCustomPhoto set to: true")
                    print("   homeScreenPresetSelectionRaw cleared")
                }
            } catch {
                print("❌ Onboarding: Failed to save home screen photo: \(error)")
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

private extension OnboardingView {
    enum ProgressIndicatorDisplayMode {
        case large
        case compact
    }

    func progressIndicatorItem(for page: OnboardingPage, displayMode: ProgressIndicatorDisplayMode) -> some View {
        let position = page.rawValue + 1
        let isCurrent = currentPage == page
        let isComplete = currentPage.rawValue > page.rawValue

        let circleFill: Color = {
            if isCurrent || isComplete {
                return Color.appAccent  // Cyan for current and completed
            } else {
                return Color(.systemGray5)  // Light gray for future steps
            }
        }()

        let circleTextColor: Color = isCurrent || isComplete ? .white : Color(.secondaryLabel)

        let circleSize: CGFloat
        let circleShadowOpacity: Double
        let circleStrokeOpacity: Double
        let circleStrokeWidth: CGFloat
        let circleFontSize: CGFloat
        let circleFontDesign: Font.Design
        let labelFont: Font
        let labelWeight: Font.Weight
        let vSpacing: CGFloat

        switch displayMode {
        case .large:
            circleSize = 38
            circleShadowOpacity = isCurrent ? 0.18 : 0.0
            circleStrokeOpacity = isCurrent ? 0.25 : 0.15
            circleStrokeWidth = isCurrent ? 1.5 : 1
            circleFontSize = 16
            circleFontDesign = .rounded
            labelFont = .footnote
            labelWeight = isCurrent ? .semibold : .regular
            vSpacing = 8
        case .compact:
            circleSize = 40
            circleShadowOpacity = 0.0
            circleStrokeOpacity = isCurrent ? 0.28 : 0.18
            circleStrokeWidth = 1
            circleFontSize = 18
            circleFontDesign = .rounded
            labelFont = .caption2
            labelWeight = isCurrent ? .semibold : .regular
            vSpacing = 4
        }

        return ZStack {
            Circle()
                .fill(circleFill)
            .frame(width: circleSize, height: circleSize)
            .shadow(color: Color.black.opacity(circleShadowOpacity), radius: isCurrent ? 10 : 0, x: 0, y: isCurrent ? 6 : 0)
                .overlay(
                    Circle()
                    .strokeBorder(Color.white.opacity(circleStrokeOpacity), lineWidth: circleStrokeWidth)
                )

            // Always show numbers (no checkmarks)
            Text("\(position)")
                .font(.system(size: circleFontSize, weight: .semibold, design: circleFontDesign))
                .foregroundColor(circleTextColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(position)")
        .accessibilityValue(isComplete ? "Complete" : (isCurrent ? "Current step" : "Not started"))
    }

    private var overviewHeroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.appAccent.opacity(0.28),
                            Color.appAccent.opacity(0.12),
                            Color(.systemBackground)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 16) {
                Text("Ready to Go")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("You’ve got everything set up. Keep these quick highlights in mind as you start using NoteWall.")
                    .font(.callout)
                    .foregroundColor(.secondary)

                HStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(Color.appAccent)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("What’s next?")
                            .font(.headline)
                        Text("Add notes, update the wallpaper, and let NoteWall keep your lock screen awesome.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
        .accessibilityElement(children: .combine)
    }

    private func overviewInfoCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.appAccent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 8)
        )
    }

    private var overviewAutomationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Pro tip: make it automatic")
                    .font(.headline)
            } icon: {
                Image(systemName: "bolt.badge.clock")
                    .foregroundColor(Color.appAccent)
            }

            Text("Create a Shortcuts automation so NoteWall runs on your schedule, like at the start of a workday or when a Focus mode activates.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                overviewAutomationRow("Trigger it every morning before you leave for the day.")
                overviewAutomationRow("Pair it with a Focus mode to keep your lock screen current throughout the week.")
                overviewAutomationRow("Use a personal automation when you arrive at the office or start a commute.")
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.appAccent.opacity(0.10), lineWidth: 1)
        )
    }

    private func overviewAutomationRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.caption)
                .foregroundColor(Color.appAccent)
                .accessibilityHidden(true)

            Text(text)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let colors = buttonColors(isPressed: configuration.isPressed)

        return configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: colors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.18 : 0.08), lineWidth: 1)
            )
            .shadow(
                color: Color.appAccent.opacity(isEnabled ? (configuration.isPressed ? 0.16 : 0.28) : 0.08),
                radius: configuration.isPressed ? 8 : 16,
                x: 0,
                y: configuration.isPressed ? 4 : 12
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.75)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }

    private func buttonColors(isPressed: Bool) -> [Color] {
        if isEnabled {
            let top = Color.appAccent.opacity(isPressed ? 0.95 : 1.0)
            let bottom = Color.appAccent.opacity(isPressed ? 0.82 : 0.9)
            return [top, bottom]
        } else {
            return [
                Color(.systemGray4),
                Color(.systemGray5)
            ]
        }
    }
}

private extension OnboardingPage {
    var navigationTitle: String {
        switch self {
        case .installShortcut:
            return "Install Shortcut"
        case .addNotes:
            return "Add Notes"
        case .allowPermissions:
            return "Allow Permissions"
        case .chooseWallpapers:
            return "Choose Wallpapers"
        case .overview:
            return "All Set"
        }
    }

    var progressTitle: String {
        switch self {
        case .installShortcut:
            return "Install Shortcut"
        case .addNotes:
            return "Add Notes"
        case .chooseWallpapers:
            return "Choose Wallpapers"
        case .allowPermissions:
            return "Allow Permissions"
        case .overview:
            return "All Set"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .installShortcut:
            return "Step 1"
        case .addNotes:
            return "Step 2"
        case .chooseWallpapers:
            return "Step 3"
        case .allowPermissions:
            return "Step 4"
        case .overview:
            return "Step 5"
        }
    }
}

#if !os(macOS)
private extension View {
    @ViewBuilder
    func onboardingNavigationBarBackground() -> some View {
        if #available(iOS 16.0, *) {
            self
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbarBackground(.hidden, for: .automatic)
        } else {
            self
        }
    }
}
#endif

#if !os(macOS)
private extension View {
    @ViewBuilder
    func scrollAlwaysBounceIfAvailable() -> some View {
        if #available(iOS 16.4, *) {
            self.scrollBounceBehavior(.always)
        } else {
            self
        }
    }
}
#endif

// MARK: - Loading Placeholder

private struct LoadingPlaceholder: View {
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray5))
            .frame(height: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 400 : -400)
            )
            .clipped()
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true), onboardingVersion: 2)
}

private extension OnboardingView {
    func ensureCustomPhotoFlagIsAccurate() {
        // During onboarding, don't auto-enable based on file existence
        // Only sync the flag in Settings view where it makes sense
        // This prevents pre-selection during first-time setup
        
        // If user hasn't completed setup yet, ensure flag starts as false
        if !hasCompletedSetup {
            homeScreenUsesCustomPhoto = false
            return
        }
        
        // After setup is complete, sync with actual file state
        let shouldBeEnabled = homeScreenPresetSelectionRaw.isEmpty && HomeScreenImageManager.homeScreenImageExists()
        if homeScreenUsesCustomPhoto != shouldBeEnabled {
            homeScreenUsesCustomPhoto = shouldBeEnabled
        }
    }

    private func advanceAfterShortcutInstallIfNeeded() {
        guard currentPage == .installShortcut, didOpenShortcut else { return }
        // After installing shortcut, go to add notes (Step 2)
        currentPage = .addNotes
        didOpenShortcut = false
    }
}
