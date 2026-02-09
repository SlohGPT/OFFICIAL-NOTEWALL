import SwiftUI
import Combine
import UIKit

struct ContentView: View {
    @AppStorage("savedNotes") private var savedNotesData: Data = Data()
    @AppStorage("lastLockScreenIdentifier") private var lastLockScreenIdentifier: String = ""
    @AppStorage("skipDeletingOldWallpaper") private var skipDeletingOldWallpaper = false
    @AppStorage("autoUpdateWallpaperAfterDeletion") private var autoUpdateWallpaperAfterDeletionRaw: String = ""
    @AppStorage("hasShownAutoUpdatePrompt") private var hasShownAutoUpdatePrompt = false
    @AppStorage("saveWallpapersToPhotos") private var saveWallpapersToPhotos = false
    @AppStorage("lockScreenBackground") private var lockScreenBackgroundRaw = LockScreenBackgroundOption.default.rawValue
    @AppStorage("lockScreenBackgroundMode") private var lockScreenBackgroundModeRaw = LockScreenBackgroundMode.default.rawValue
    @AppStorage("lockScreenBackgroundPhotoData") private var lockScreenBackgroundPhotoData: Data = Data()
    @AppStorage("homeScreenPresetSelection") private var homeScreenPresetSelectionRaw = ""
    @AppStorage("hasCompletedInitialWallpaperSetup") private var hasCompletedInitialWallpaperSetup = false
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @AppStorage("shouldShowTroubleshootingBanner") private var shouldShowTroubleshootingBanner = false
    @AppStorage("hasLockScreenWidgets") private var hasLockScreenWidgets = true // Default: assume user has widgets
    @StateObject private var paywallManager = PaywallManager.shared
    @State private var notes: [Note]
    @State private var newNoteText = ""
    @State private var isGeneratingWallpaper = false
    @State private var pendingLockScreenImage: UIImage?
    @State private var notePendingDeletion: Note?
    @State private var pendingDeletionIndex: Int?
    @State private var activeAlert: ActiveAlert?
    @State private var isEditMode = false
    @State private var selectedNotes: Set<UUID> = []
    @State private var shouldSkipDeletionPrompt = false
    @State private var isUserInitiatedUpdate = false
    @State private var showTroubleshooting = false
    @State private var shouldRestartOnboarding = false
    @State private var showWallpaperUpdateLoading = false
    @AppStorage("hasShownFirstNoteHint") private var hasShownFirstNoteHint = false
    @AppStorage("selectedOnboardingPipeline") private var selectedOnboardingPipeline = ""
    @State private var showFirstNoteHint = false
    @FocusState private var isTextFieldFocused: Bool

    // Computed property to get indices of notes that will appear on wallpaper
    private var wallpaperNoteIndices: Set<UUID> {
        let activeNotes = notes.filter { !$0.isCompleted }
        let wallpaperCount = WallpaperRenderer.getWallpaperNoteCount(from: notes)
        return Set(activeNotes.prefix(wallpaperCount).map { $0.id })
    }

    private var activeNotesCount: Int {
        notes.filter { !$0.isCompleted }.count
    }

    private var wallpaperNoteCount: Int {
        WallpaperRenderer.getWallpaperNoteCount(from: notes)
    }

    private var isWallpaperAtCapacity: Bool {
        wallpaperNoteCount < activeNotesCount
    }

    private var sortedNotes: [Note] {
        notes
    }

    private var lockScreenBackgroundOption: LockScreenBackgroundOption {
        LockScreenBackgroundOption(rawValue: lockScreenBackgroundRaw) ?? .default
    }

    private var lockScreenBackgroundMode: LockScreenBackgroundMode {
        LockScreenBackgroundMode(rawValue: lockScreenBackgroundModeRaw) ?? .default
    }

    private var lockScreenBackgroundColor: UIColor {
        // Determine background color based on the current mode
        switch lockScreenBackgroundMode {
        case .photo:
            // When using a photo background, use pure RGB black
            // This forces the graphics context to use RGB color space instead of grayscale
            // which prevents the user's photo from being desaturated
            return UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        case .presetBlack:
            return LockScreenBackgroundOption.black.uiColor
        case .presetGray:
            return LockScreenBackgroundOption.gray.uiColor
        case .notSelected:
            // Default to black if nothing is selected
            return LockScreenBackgroundOption.black.uiColor
        }
    }

    private var lockScreenBackgroundImage: UIImage? {
        #if DEBUG
        print("🔍 lockScreenBackgroundImage - Checking for background photo...")
        print("   Mode: \(lockScreenBackgroundMode)")
        #endif
        
        guard lockScreenBackgroundMode == .photo else {
            #if DEBUG
            print("   ❌ Mode is not .photo, returning nil")
            #endif
            return nil
        }
        
        // First try to load from file system
        if let storedImage = HomeScreenImageManager.lockScreenBackgroundSourceImage() {
            #if DEBUG
            print("   ✅ Loaded from file system")
            if let url = HomeScreenImageManager.lockScreenBackgroundSourceURL() {
                print("      Path: \(url.path)")
            }
            print("      Size: \(storedImage.size)")
            #endif
            return storedImage
        }

        // Fall back to AppStorage data
        guard !lockScreenBackgroundPhotoData.isEmpty,
              let dataImage = UIImage(data: lockScreenBackgroundPhotoData) else {
            #if DEBUG
            print("   ❌ No photo data available in AppStorage either")
            #endif
            return nil
        }

        // Save to file system for next time
        do {
            try HomeScreenImageManager.saveLockScreenBackgroundSource(dataImage)
            #if DEBUG
            print("   ✅ Loaded from AppStorage and saved to file system")
            if let url = HomeScreenImageManager.lockScreenBackgroundSourceURL() {
                print("      Path: \(url.path)")
            }
            #endif
        } catch {
            #if DEBUG
            print("   ⚠️ Failed to save to file system: \(error)")
            #endif
        }
        
        return dataImage
    }

    // Unified Styling System State
    @AppStorage("wallpaperFontName") private var selectedFontName: String = "Classic"
    @AppStorage("wallpaperColorName") private var selectedColorName: String = "Auto"
    @AppStorage("wallpaperHighlightMode") private var highlightMode: Int = 0 // 0: None, 1: Outline, 2: White, 3: Black
    @AppStorage("wallpaperIsShadowEnabled") private var isShadowEnabled: Bool = false
    @AppStorage("wallpaperShadowIntensity") private var shadowIntensity: Double = 0.5 // 0.0 to 1.0
    @AppStorage("wallpaperAlignment") private var alignmentMode: Int = 1 // 0: Left, 1: Center, 2: Right
    
    // Custom Color State
    @State private var customColor: Color = .white
    @State private var useCustomColor: Bool = false
    @State private var showFontList: Bool = false
    
    init() {
        _notes = State(initialValue: Self.initialNotes())
    }
    
    // MARK: - Styling Helpers
    
    private func loadCustomColor() {
        if let data = UserDefaults.standard.data(forKey: "wallpaperCustomColorData"),
           let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) {
            customColor = Color(uiColor)
            useCustomColor = UserDefaults.standard.bool(forKey: "wallpaperUseCustomColor")
        }
    }
    
    private func saveCustomColor() {
        let uiColor = UIColor(customColor).resolvedColor(with: .current)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: uiColor, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: "wallpaperCustomColorData")
            UserDefaults.standard.set(true, forKey: "wallpaperUseCustomColor")
        }
    }

    var body: some View {
        ZStack {
            AnyView(ContentViewRoot(context: viewContext))
                .onChange(of: shouldRestartOnboarding) { shouldRestart in
                    if shouldRestart {
                        // Reset hasCompletedSetup to force onboarding to show
                        hasCompletedSetup = false
                        shouldRestartOnboarding = false
                    }
                }
            
        }
    }

    private var viewContext: ContentViewContext {
        ContentViewContext(
            notes: $notes,
            newNoteText: $newNoteText,
            isGeneratingWallpaper: $isGeneratingWallpaper,
            pendingLockScreenImage: $pendingLockScreenImage,
            activeAlert: $activeAlert,
            isEditMode: $isEditMode,
            selectedNotes: $selectedNotes,
            shouldSkipDeletionPrompt: $shouldSkipDeletionPrompt,
            isUserInitiatedUpdate: $isUserInitiatedUpdate,
            savedNotesData: $savedNotesData,
            hasCompletedSetup: hasCompletedSetup,
            shouldShowTroubleshootingBanner: $shouldShowTroubleshootingBanner,
            showTroubleshooting: $showTroubleshooting,
            shouldRestartOnboarding: $shouldRestartOnboarding,
            showWallpaperUpdateLoading: $showWallpaperUpdateLoading,
            showFirstNoteHint: $showFirstNoteHint,
            selectedOnboardingPipeline: selectedOnboardingPipeline,
            isTextFieldFocused: $isTextFieldFocused,
            addNote: addNote,
            moveNotes: moveNotes,
            toggleSelection: toggleSelection,
            handleDelete: handleDelete,
            toggleCompletion: toggleCompletion,
            noteCommit: noteCommit,
            hideKeyboard: hideKeyboard,
            updateWallpaper: updateWallpaper,
            saveNewLockScreenWallpaper: saveNewLockScreenWallpaper,
            proceedWithDeletionAndSave: proceedWithDeletionAndSave,
            restorePendingDeletionIfNeeded: restorePendingDeletionIfNeeded,
            finalizePendingDeletion: finalizePendingDeletion,
            deleteSelectedNotes: deleteSelectedNotes,
            loadNotes: loadNotes,

            handleNotesChangedAfterDeletion: handleNotesChangedAfterDeletion,
            selectedFontName: $selectedFontName,
            showFontList: $showFontList,
            selectedColorName: $selectedColorName,
            customColor: $customColor,
            alignmentMode: $alignmentMode,
            highlightMode: $highlightMode,
            isShadowEnabled: $isShadowEnabled,
            shadowIntensity: $shadowIntensity
        )
    }


    private func hideKeyboard() {
        isTextFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func loadNotes() {
        guard let data = resolvedSavedNotesData() else {
            notes = []
            return
        }

        do {
            notes = try JSONDecoder().decode([Note].self, from: data)
        } catch {
            #if DEBUG
            print("Failed to decode notes: \(error)")
            #endif
            notes = []
        }
    }

    private func saveNotes() {
        do {
            let data = try JSONEncoder().encode(notes)
            savedNotesData = data
            // Sync to widget via App Group
            WidgetDataSync.syncNotesToWidget(data)
        } catch {
            #if DEBUG
            print("Failed to encode notes: \(error)")
            #endif
        }
    }

    private func addNote() {
        let trimmedText = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        // Check if the new note would fit on the wallpaper
        let newNote = Note(text: trimmedText)
        let testNotes = notes + [newNote]

        // Check if this new note would actually appear on the wallpaper
        let activeNotes = testNotes.filter { !$0.isCompleted }
        let wouldFitCount = WallpaperRenderer.getWallpaperNoteCount(from: testNotes)

        // If the new note wouldn't appear on wallpaper, show alert
        if wouldFitCount < activeNotes.count {
            // Warning haptic for wallpaper full
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            activeAlert = .wallpaperFull
            return
        }

        // Track if this is the first note added after onboarding
        let wasFirstNoteAfterOnboarding = !hasShownFirstNoteHint && hasCompletedSetup
        
        notes.append(newNote)
        newNoteText = ""
        saveNotes()
        hideKeyboard()
        
        // Show hint after first note added after onboarding (only once)
        if wasFirstNoteAfterOnboarding {
            hasShownFirstNoteHint = true
            // Small delay to let the note appear first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showFirstNoteHint = true
            }
        }
        
        // Light impact haptic for successful note addition
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private static func initialNotes() -> [Note] {
        guard let data = resolvedStoredNotesData() else {
            return []
        }

        do {
            return try JSONDecoder().decode([Note].self, from: data)
        } catch {
            #if DEBUG
            print("Failed to decode notes during initial load: \(error)")
            #endif
            return []
        }
    }

    private func resolvedSavedNotesData() -> Data? {
        if !savedNotesData.isEmpty {
            return savedNotesData
        }
        return Self.resolvedStoredNotesData()
    }

    private static func resolvedStoredNotesData() -> Data? {
        guard let storedData = UserDefaults.standard.data(forKey: "savedNotes"),
              !storedData.isEmpty else {
            return nil
        }
        return storedData
    }

    private func moveNotes(from source: IndexSet, to destination: Int) {
        // Create a mapping from sorted notes to actual notes array
        var mutableSortedNotes = sortedNotes
        mutableSortedNotes.move(fromOffsets: source, toOffset: destination)

        // Update the actual notes array to match the new order
        notes = mutableSortedNotes
        saveNotes()
        
        // Light impact haptic for note reordering
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func toggleSelection(for note: Note) {
        if selectedNotes.contains(note.id) {
            selectedNotes.remove(note.id)
        } else {
            selectedNotes.insert(note.id)
        }
        
        // Light impact haptic for selecting/deselecting notes
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func handleDelete(for note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            // Medium impact haptic for destructive delete action
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            prepareNoteForDeletion(at: index)
        }
    }

    private func toggleCompletion(for note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].isCompleted.toggle()
            saveNotes()
            
            // Light impact haptic for toggling completion
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            // Auto-update wallpaper when note completion status changes
            if hasCompletedInitialWallpaperSetup {
                // Check if user can export wallpaper (prevent free update loophole)
                if PaywallManager.shared.canExportWallpaper() {
                    // Track for paywall to consume credit (was false)
                    let request = WallpaperUpdateRequest(skipDeletionPrompt: true, trackForPaywall: true)
                    NotificationCenter.default.post(name: .requestWallpaperUpdate, object: request)
                } else {
                    #if DEBUG
                    print("🚫 Auto-update blocked - free limit reached")
                    #endif
                    PaywallManager.shared.showPaywall(reason: .limitReached)
                }
            }
        }
    }

    private func noteCommit() {
        saveNotes()
        hideKeyboard()
    }

    private func resolveHomeWallpaperBaseImage() -> UIImage {
        if let storedImage = HomeScreenImageManager.loadHomeScreenImage() {
            return storedImage
        }

        if let presetImage = presetImageForCurrentSelection() {
            return presetImage
        }

        if let lockPhoto = lockScreenBackgroundImage {
            return lockPhoto
        }

        return solidColorWallpaperImage(color: lockScreenBackgroundColor)
    }

    private func presetImageForCurrentSelection() -> UIImage? {
        guard let preset = PresetOption(rawValue: homeScreenPresetSelectionRaw) else {
            return nil
        }

        // Generate the gradient image for the selected preset
        return preset.generateGradientImage()
    }

    private func resolveLockBackgroundImage(using homeImage: UIImage) -> UIImage? {
        // Check the mode first to respect user's preset selection
        #if DEBUG
        print("🎯 resolveLockBackgroundImage - mode: \(lockScreenBackgroundMode)")
        #endif
        switch lockScreenBackgroundMode {
        case .photo:
            // Only use photo when explicitly in photo mode
            #if DEBUG
            print("   📸 Photo mode detected")
            #endif
            if let photo = lockScreenBackgroundImage {
                #if DEBUG
                print("   ✅ Returning lock screen background photo")
                print("      Photo size: \(photo.size)")
                #endif
                return photo
            }
            #if DEBUG
            print("   ⚠️ No lock screen photo found, using home screen image as fallback")
            print("      Home image size: \(homeImage.size)")
            #endif
            return homeImage
        case .presetBlack, .presetGray:
            // Presets should have no background image (solid color only)
            print("   🎨 Preset mode detected: \(lockScreenBackgroundMode)")
            print("   ✅ Returning nil (will use solid color background)")
            return nil
        case .notSelected:
            // If nothing is selected, default to solid color (no image)
            print("   ⚠️ No selection made, defaulting to solid color")
            return nil
        }
    }

    private func solidColorWallpaperImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 1290, height: 2796)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func prepareNoteForDeletion(at index: Int) {
        restorePendingDeletionIfNeeded()

        guard notes.indices.contains(index) else { return }
        let note = notes[index]

        withAnimation {
            _ = notes.remove(at: index)
        }

        notePendingDeletion = note
        pendingDeletionIndex = index
        activeAlert = .deleteNote
    }

    private func restorePendingDeletionIfNeeded() {
        guard let note = notePendingDeletion,
              let index = pendingDeletionIndex else {
            notePendingDeletion = nil
            pendingDeletionIndex = nil
            return
        }

        let insertionIndex = min(index, notes.count)
        withAnimation {
            notes.insert(note, at: insertionIndex)
        }

        notePendingDeletion = nil
        pendingDeletionIndex = nil
    }

    private func finalizePendingDeletion() {
        guard notePendingDeletion != nil else { return }

        notePendingDeletion = nil
        pendingDeletionIndex = nil

        saveNotes()
        handleNotesChangedAfterDeletion()
    }

    private func deleteSelectedNotes() {
        // Medium impact haptic for destructive delete action
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        notes.removeAll { selectedNotes.contains($0.id) }
        selectedNotes.removeAll()
        saveNotes()
        handleNotesChangedAfterDeletion()
        activeAlert = nil
    }

    private func updateWallpaper() {
        guard !isGeneratingWallpaper else { return }
        
        // Note: We don't block wallpaper updates here
        // Users can always change wallpaper images/settings
        // Credits are only tracked when explicitly updating from homepage
        isGeneratingWallpaper = true
        
        // Show loading container for shortcut pipeline
        // Show loading container for shortcut pipeline
        if selectedOnboardingPipeline == "fullscreen" {
            // Post notification to show global loading overlay in MainTabView
            NotificationCenter.default.post(name: .showGlobalLoadingOverlay, object: nil)
            withAnimation {
                showWallpaperUpdateLoading = true
            }
        }

        #if DEBUG
        // Debug logging
        print("=== UPDATE WALLPAPER DEBUG ===")
        print("lockScreenBackgroundMode: \(lockScreenBackgroundMode)")
        print("lockScreenBackgroundModeRaw: \(lockScreenBackgroundModeRaw)")
        print("lockScreenBackgroundOption: \(lockScreenBackgroundOption)")
        print("lockScreenBackgroundColor: \(lockScreenBackgroundColor)")
        print("lockScreenBackgroundPhotoData isEmpty: \(lockScreenBackgroundPhotoData.isEmpty)")
        #endif

        let homeWallpaperImage = resolveHomeWallpaperBaseImage()
        do {
            try HomeScreenImageManager.saveHomeScreenImage(homeWallpaperImage)
            #if DEBUG
            print("✅ Saved home screen image to file system")
            if let url = HomeScreenImageManager.homeScreenImageURL() {
                print("   File path: \(url.path)")
                print("   File exists: \(FileManager.default.fileExists(atPath: url.path))")
            }
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save home screen wallpaper image: \(error)")
            #endif
        }

        let lockBackgroundImage = resolveLockBackgroundImage(using: homeWallpaperImage)
        #if DEBUG
        print("lockBackgroundImage is nil: \(lockBackgroundImage == nil)")
        #endif

        // Generate the wallpaper with notes
        // Read saved customization settings
        let savedFontName = UserDefaults.standard.string(forKey: "wallpaperFontName") ?? "Classic"
        let savedColorName = UserDefaults.standard.string(forKey: "wallpaperColorName") ?? "Auto"
        let highlightModeInt = UserDefaults.standard.integer(forKey: "wallpaperHighlightMode")
        let highlightMode = WallpaperRenderer.WallpaperTextHighlight(rawValue: highlightModeInt) ?? .none
        let isShadowEnabled = UserDefaults.standard.bool(forKey: "wallpaperIsShadowEnabled")
        let alignmentInt = UserDefaults.standard.integer(forKey: "wallpaperAlignment")
        let textAlignment: NSTextAlignment = {
            switch alignmentInt {
            case 0: return .left
            case 1: return .center
            case 2: return .right
            default: return .center
            }
        }()
        
        // Determine text color (Custom Color Picker first, then presets)
        let customTextColor: UIColor? = {
            // Check for custom color picker first
            if UserDefaults.standard.bool(forKey: "wallpaperUseCustomColor"),
               let data = UserDefaults.standard.data(forKey: "wallpaperCustomColorData"),
               let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) {
                print("🎨 ContentView: Using custom color from color picker")
                print("   Loaded UIColor: \(uiColor)")
                return uiColor
            }
            
            // Fallback to presets
            switch savedColorName {
            case "White": return .white
            case "Black": return UIColor(white: 0.1, alpha: 1.0)
            case "Gold": return UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
            case "Sky": return UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
            case "Rose": return UIColor(red: 1.0, green: 0.6, blue: 0.7, alpha: 1.0)
            default: return nil // Auto
            }
        }()
        
        // Get shadow intensity from UserDefaults
        let shadowIntensity = UserDefaults.standard.double(forKey: "wallpaperShadowIntensity")
        let effectiveShadowIntensity = shadowIntensity > 0 ? shadowIntensity : 0.5 // Default to 0.5 if not set
        
        let lockScreenImage = WallpaperRenderer.generateWallpaper(
            from: notes,
            backgroundColor: lockScreenBackgroundColor,
            backgroundImage: lockBackgroundImage,
            hasLockScreenWidgets: hasLockScreenWidgets,
            customFontName: savedFontName,
            customTextColor: customTextColor,
            highlightMode: highlightMode,
            isShadowEnabled: isShadowEnabled,
            shadowIntensity: effectiveShadowIntensity,
            textAlignment: textAlignment
        )
        #if DEBUG
        print("Generated lock screen image size: \(lockScreenImage.size)")
        #endif
        
        // Save to file system FIRST (this is what the shortcut reads)
        do {
            try HomeScreenImageManager.saveLockScreenWallpaper(lockScreenImage)
            #if DEBUG
            print("✅ Saved lock screen wallpaper to file system")
            if let url = HomeScreenImageManager.lockScreenWallpaperURL() {
                print("   File path: \(url.path)")
                print("   File exists: \(FileManager.default.fileExists(atPath: url.path))")
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let fileSize = attributes[.size] as? Int {
                    print("   File size: \(fileSize) bytes")
                }
            }
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save lock screen wallpaper image: \(error)")
            #endif
        }
        #if DEBUG
        print("==============================")
        #endif
        
        pendingLockScreenImage = lockScreenImage

        // Delete previous wallpaper if it exists and user hasn't opted to skip
        // Also skip if this update was triggered from Settings (e.g., preset selection)
        // ALSO skip if user opted for "Files Only" (no Photos library saves)
        let shouldPromptForDeletion = !skipDeletingOldWallpaper &&
            !lastLockScreenIdentifier.isEmpty &&
            hasCompletedInitialWallpaperSetup &&
            !shouldSkipDeletionPrompt &&
            saveWallpapersToPhotos // Only prompt if user is saving to Photos

        if shouldPromptForDeletion {
            withAnimation {
                activeAlert = .deletePreviousWallpaper
            }
        } else {
            // First setup, no prior wallpaper, or skipping prompt; save silently
            saveNewLockScreenWallpaper(lockScreenImage, trackForPaywall: isUserInitiatedUpdate)
            // Reset the flag after use
            shouldSkipDeletionPrompt = false
            isUserInitiatedUpdate = false
        }
    }

    private func proceedWithDeletionAndSave() {
        guard let lockScreen = pendingLockScreenImage else { return }

        // Delete previous wallpaper before saving the new one
        if !lastLockScreenIdentifier.isEmpty {
            PhotoSaver.deleteAsset(withIdentifier: lastLockScreenIdentifier) { _ in
                DispatchQueue.main.async {
                    self.saveNewLockScreenWallpaper(lockScreen, trackForPaywall: self.isUserInitiatedUpdate)
                    self.isUserInitiatedUpdate = false
                }
            }
        } else {
            saveNewLockScreenWallpaper(lockScreen, trackForPaywall: isUserInitiatedUpdate)
            isUserInitiatedUpdate = false
        }
    }

    private func saveNewLockScreenWallpaper(_ lockScreen: UIImage, trackForPaywall: Bool = false) {
        #if DEBUG
        print("📸 Attempting to save wallpaper to Photos library...")
        #endif
        
        PhotoSaver.saveImage(lockScreen) { success, identifier in
            DispatchQueue.main.async {
                self.isGeneratingWallpaper = false
                self.pendingLockScreenImage = nil
                self.hasCompletedInitialWallpaperSetup = true

                if success {
                    #if DEBUG
                    print("✅ Saved wallpaper to Photos library")
                    if let id = identifier {
                        self.lastLockScreenIdentifier = id
                        print("   Photo ID: \(id)")
                    }
                    #endif
                    
                    // Success notification haptic for wallpaper generation success
                    let successGenerator = UINotificationFeedbackGenerator()
                    successGenerator.notificationOccurred(.success)
                } else {
                    #if DEBUG
                    print("⚠️ Failed to save to Photos library (permission denied or error)")
                    print("   Wallpaper is still saved to file system and can be used by shortcut")
                    #endif
                    
                    // Error notification haptic for wallpaper generation failure
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
                }
                
                // Track wallpaper export for paywall ONLY if user-initiated from home page
                if trackForPaywall {
                    #if DEBUG
                    print("📊 Tracking wallpaper export for paywall")
                    #endif
                    PaywallManager.shared.trackWallpaperExport()
                } else {
                    #if DEBUG
                    print("ℹ️ Not tracking for paywall (onboarding/settings update)")
                    #endif
                }
                
                // Post notification FIRST so UI updates
                NotificationCenter.default.post(name: .wallpaperGenerationFinished, object: nil)
                
                // Auto-open shortcut after a delay to ensure wallpaper is fully saved
                // CRITICAL: Only auto-open shortcut if user has completed setup AND not in widget pipeline
                // During onboarding, the OnboardingView handles shortcut opening at the right time
                // Widget pipeline should never launch shortcuts - it only saves to widget
                if self.hasCompletedSetup && self.selectedOnboardingPipeline != "widget" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        #if DEBUG
                        print("🚀 Opening shortcut to apply wallpaper...")
                        #endif
                        self.openShortcut()
                    }
                } else {
                    #if DEBUG
                    if self.selectedOnboardingPipeline == "widget" {
                        print("ℹ️ Skipping auto-open shortcut (widget pipeline - no shortcut needed)")
                    } else {
                        print("ℹ️ Skipping auto-open shortcut (setup not completed, onboarding will handle)")
                    }
                    #endif
                }
            }
        }
    }

    private func handleNotesChangedAfterDeletion() {
        selectedNotes.removeAll()
        if isEditMode {
            withAnimation {
                isEditMode = false
            }
        }

        if notes.isEmpty {
            setBlankWallpaper()
        } else {
            // Check if user can export wallpaper (prevent free update loophole)
            if PaywallManager.shared.canExportWallpaper() {
                // Mark as user-initiated to consume credit
                isUserInitiatedUpdate = true
                // Always auto-update wallpaper after deletion
                updateWallpaper()
            } else {
                print("🚫 Deletion update blocked - free limit reached")
                PaywallManager.shared.showPaywall(reason: .limitReached)
            }
        }
    }

    private func setBlankWallpaper() {
        print("=== SETTING BLANK WALLPAPER ===")
        let homeWallpaperImage = resolveHomeWallpaperBaseImage()
        do {
            try HomeScreenImageManager.saveHomeScreenImage(homeWallpaperImage)
            print("✅ Saved blank home screen image")
        } catch {
            print("❌ Failed to save home screen wallpaper image: \(error)")
        }

        let lockBackgroundImage = resolveLockBackgroundImage(using: homeWallpaperImage)

        let lockScreenImage = WallpaperRenderer.generateBlankWallpaper(
            backgroundColor: lockScreenBackgroundColor,
            backgroundImage: lockBackgroundImage
        )

        do {
            try HomeScreenImageManager.saveLockScreenWallpaper(lockScreenImage)
            print("✅ Saved blank lock screen wallpaper")
        } catch {
            print("❌ Failed to save lock screen wallpaper image: \(error)")
        }
        print("==============================")
        saveNewLockScreenWallpaper(lockScreenImage)
    }

    private func openShortcut() {
        // Run the shortcut using the manager to ensure consistent naming
        // Use the centralized manager to run the shortcut
        ShortcutIntegrationManager.shared.runShortcutWithCallback { _ in
            // Reset state is handled by scene phase
        }
    }
}

private struct ContentViewContext {
    let notes: Binding<[Note]>
    let newNoteText: Binding<String>
    let isGeneratingWallpaper: Binding<Bool>
    let pendingLockScreenImage: Binding<UIImage?>
    let activeAlert: Binding<ActiveAlert?>
    let isEditMode: Binding<Bool>
    let selectedNotes: Binding<Set<UUID>>
    let shouldSkipDeletionPrompt: Binding<Bool>
    let isUserInitiatedUpdate: Binding<Bool>
    let savedNotesData: Binding<Data>
    let hasCompletedSetup: Bool
    let shouldShowTroubleshootingBanner: Binding<Bool>
    let showTroubleshooting: Binding<Bool>
    let shouldRestartOnboarding: Binding<Bool>
    let showWallpaperUpdateLoading: Binding<Bool>
    let showFirstNoteHint: Binding<Bool>
    let selectedOnboardingPipeline: String
    let isTextFieldFocused: FocusState<Bool>.Binding
    let addNote: () -> Void
    let moveNotes: (IndexSet, Int) -> Void
    let toggleSelection: (Note) -> Void
    let handleDelete: (Note) -> Void
    let toggleCompletion: (Note) -> Void
    let noteCommit: () -> Void
    let hideKeyboard: () -> Void
    let updateWallpaper: () -> Void
    let saveNewLockScreenWallpaper: (UIImage, Bool) -> Void
    let proceedWithDeletionAndSave: () -> Void
    let restorePendingDeletionIfNeeded: () -> Void
    let finalizePendingDeletion: () -> Void
    let deleteSelectedNotes: () -> Void
    let loadNotes: () -> Void
    let handleNotesChangedAfterDeletion: () -> Void
    
    // Styling Bindings
    var selectedFontName: Binding<String>
    var showFontList: Binding<Bool>
    var selectedColorName: Binding<String>
    var customColor: Binding<Color>
    var alignmentMode: Binding<Int>
    var highlightMode: Binding<Int>
    var isShadowEnabled: Binding<Bool>
    var shadowIntensity: Binding<Double>
}

private enum ActiveAlert: String, Identifiable {
    case deletePreviousWallpaper
    case deleteNote
    case deleteSelectedNotes
    case wallpaperFull

    var id: String { rawValue }
}

private struct ContentViewRoot: View {
    let context: ContentViewContext
    @StateObject private var paywallManager = PaywallManager.shared

    var body: some View {
        RootConfiguredView(context: context) {
            MainContentView(context: context)
        }
        .sheet(isPresented: $paywallManager.shouldShowPaywall) {
            if #available(iOS 15.0, *) {
                PaywallView(
                    triggerReason: paywallManager.paywallTriggerReason,
                    allowDismiss: paywallManager.paywallTriggerReason != .limitReached &&
                                  context.selectedOnboardingPipeline != "widget" &&
                                  context.selectedOnboardingPipeline != "fullscreen"
                )
                .interactiveDismissDisabled(
                    paywallManager.paywallTriggerReason == .limitReached ||
                    context.selectedOnboardingPipeline == "widget" ||
                    context.selectedOnboardingPipeline == "fullscreen"
                )
            }
        }
        .eraseToAnyView()
    }
}

private struct RootConfiguredView<Content: View>: View {
    let context: ContentViewContext
    let content: Content

    init(context: ContentViewContext, @ViewBuilder content: () -> Content) {
        self.context = context
        self.content = content()
    }

    var body: some View {
        configuredContent
    }

    @ViewBuilder
    private var configuredContent: some View {
        content
            .modifier(RootConfiguredModifier(context: context))
    }
}

private struct RootConfiguredModifier: ViewModifier {
    let context: ContentViewContext

    func body(content: Content) -> some View {
        configuredContent(for: content)
    }

    private func configuredContent(for content: Content) -> some View {
        content
            .alert(item: context.activeAlert) { alert(for: $0) }
            .contentShape(Rectangle())
            .onTapGesture { context.hideKeyboard() }
            .onAppear { context.loadNotes() }
            .onReceive(NotificationCenter.default.publisher(for: .requestWallpaperUpdate)) { notification in
                context.hideKeyboard()
                
                // Check if we should skip the deletion prompt, track for paywall, and show loading overlay
                if let request = notification.object as? WallpaperUpdateRequest {
                    context.shouldSkipDeletionPrompt.wrappedValue = request.skipDeletionPrompt
                    context.isUserInitiatedUpdate.wrappedValue = request.trackForPaywall
                    
                    // Show loading overlay if requested (e.g., from Settings)
                    if request.showLoadingOverlay {
                        context.showWallpaperUpdateLoading.wrappedValue = true
                    }
                } else {
                    // No request object - don't modify flags, use whatever was set by the caller
                    // (Homepage button sets isUserInitiatedUpdate = true explicitly)
                    context.shouldSkipDeletionPrompt.wrappedValue = false
                }
                
                context.updateWallpaper()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Reset generating state when returning from shortcut
                // This ensures the button doesn't keep spinning after onboarding
                if context.isGeneratingWallpaper.wrappedValue && context.hasCompletedSetup {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        context.isGeneratingWallpaper.wrappedValue = false
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .onboardingCompleted)) { _ in
                // Onboarding finished: ensure CTA is not spinning
                if context.isGeneratingWallpaper.wrappedValue {
                    context.isGeneratingWallpaper.wrappedValue = false
                }
                // Clear any pending image just in case
                if context.pendingLockScreenImage.wrappedValue != nil {
                    context.pendingLockScreenImage.wrappedValue = nil
                }
            }
            .onChange(of: context.savedNotesData.wrappedValue) { _ in
                let previousNotesCount = context.notes.wrappedValue.count
                context.loadNotes()
                
                // If notes became empty after loading and we had notes before, update to blank wallpaper
                if previousNotesCount > 0 && context.notes.wrappedValue.isEmpty && context.hasCompletedSetup {
                    // Small delay to ensure notes array is fully updated
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Check again to be sure notes are still empty, then trigger wallpaper update
                        if context.notes.wrappedValue.isEmpty {
                            // This will call setBlankWallpaper() which generates and saves blank wallpaper
                            context.handleNotesChangedAfterDeletion()
                        }
                    }
                }
            }
    }

    private func alert(for alert: ActiveAlert) -> Alert {
        switch alert {
        case .deletePreviousWallpaper:
            return Alert(
                title: Text("Delete Previous Wallpaper?"),
                message: Text("To avoid filling your Photos library, FaithWall can delete the previous wallpaper."),
                primaryButton: .cancel(Text("Skip")) {
                    // Light impact haptic for alert dismissal
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    if let lockScreen = context.pendingLockScreenImage.wrappedValue {
                        // Pass trackForPaywall based on whether this was user-initiated
                        let shouldTrack = context.isUserInitiatedUpdate.wrappedValue
                        context.saveNewLockScreenWallpaper(lockScreen, shouldTrack)
                        context.isUserInitiatedUpdate.wrappedValue = false
                    }
                    context.shouldSkipDeletionPrompt.wrappedValue = false
                },
                secondaryButton: .destructive(Text("Continue")) {
                    context.proceedWithDeletionAndSave()
                    context.shouldSkipDeletionPrompt.wrappedValue = false
                }
            )
        case .deleteNote:
            // Use "Delete Verse?" for widget pipeline, "Delete Note?" for shortcut pipeline
            let title = context.selectedOnboardingPipeline == "widget" ? "Delete Verse?" : "Delete Note?"
            let message = context.selectedOnboardingPipeline == "widget" 
                ? "Are you sure you want to delete this verse? This action cannot be undone."
                : "Are you sure you want to delete this note? This action cannot be undone."
            return Alert(
                title: Text(title),
                message: Text(message),
                primaryButton: .destructive(Text("Delete")) {
                    context.finalizePendingDeletion()
                },
                secondaryButton: .cancel {
                    // Light impact haptic for alert dismissal
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    context.restorePendingDeletionIfNeeded()
                }
            )
        case .deleteSelectedNotes:
            return Alert(
                title: Text("Delete Selected Notes?"),
                message: Text("Are you sure you want to delete the selected notes? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    context.deleteSelectedNotes()
                },
                secondaryButton: .cancel {
                    // Light impact haptic for alert dismissal
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            )
        case .wallpaperFull:
            return Alert(
                title: Text("Wallpaper Full"),
                message: Text("Your wallpaper has reached its maximum capacity. Complete or delete existing notes to add new ones."),
                dismissButton: .cancel(Text("OK")) {
                    // Light impact haptic for alert dismissal
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            )
        }
    }
}

private struct MainContentView: View {
    let context: ContentViewContext
    @State private var showBibleMenu = false

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    NotesSectionView(context: context)

                    if !context.isEditMode.wrappedValue && context.selectedOnboardingPipeline != "fullscreen" && context.selectedOnboardingPipeline != "widget" {
                        AddNoteSectionView(context: context)
                    }
                    
                    // Open Bible Button (OR Add Your Bible Verse Button for Shortcut Pipeline)
                    if !context.isEditMode.wrappedValue {
                        OpenBibleButtonView(showBibleMenu: $showBibleMenu, context: context)
                            // Remove bottom padding for shortcut pipeline since it's the main action
                            .padding(.bottom, (context.selectedOnboardingPipeline == "fullscreen" || context.selectedOnboardingPipeline == "widget") ? 0 : 8)
                    }
                    
                    // Styling toolbar and Update button removed - users now style wallpapers
                    // through the Open Bible → Verse Review flow
                }
            }
            .navigationTitle("FaithWall")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if context.selectedOnboardingPipeline != "fullscreen" && context.selectedOnboardingPipeline != "widget" {
                        EditModeMenuButton(context: context)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            context.loadNotes()
        }
        .sheet(isPresented: context.showTroubleshooting) {
            TroubleshootingView(
                isPresented: context.showTroubleshooting,
                shouldRestartOnboarding: context.shouldRestartOnboarding
            )
        }
        .sheet(isPresented: $showBibleMenu) {
            // Both pipelines use the unified verse selection interface
            // Shortcut pipeline: uses wallpaper preview and launches shortcut
            // Widget pipeline: uses widget preview and saves to widget
            if context.selectedOnboardingPipeline == "fullscreen" {
                ShortcutVerseSelectionView(
                    onComplete: {
                        showBibleMenu = false
                        // Trigger wallpaper generation and shortcut launch after verse is saved
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            context.updateWallpaper()
                        }
                    },
                    onCancel: {
                        // Just close the sheet without triggering wallpaper generation
                        showBibleMenu = false
                    }
                )
            } else {
                // Widget pipeline: use UnifiedVerseSelectionView with widget preview/capacity
                NavigationView {
                    UnifiedVerseSelectionView(
                        onVerseSelected: { text, reference in
                            // Save the verse as a note for the widget
                            let noteText = reference.isEmpty ? text : "\(text)\n— \(reference)"
                            let newNote = Note(text: noteText, isCompleted: false)
                            
                            // Replace existing notes with the new one
                            context.notes.wrappedValue = [newNote]
                            
                            // Save to UserDefaults
                            if let encoded = try? JSONEncoder().encode([newNote]) {
                                context.savedNotesData.wrappedValue = encoded
                                WidgetDataSync.syncNotesToWidget(encoded)
                            }
                            
                            // Haptic feedback
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            
                            showBibleMenu = false
                        },
                        showInternalReviewSheet: true // Show widget preview and capacity
                    )
                    .navigationTitle("Choose Your Verse")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                showBibleMenu = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Adds a Bible verse as a new note
    private func addVerseAsNote(_ verse: BibleVerse) {
        // Format the verse for lock screen display
        let noteText = verse.lockScreenFormat
        
        // Create a new note
        let newNote = Note(text: noteText)
        
        // Add to notes array - replacing existing notes
        // User requested: "automatically remove the old one and set this as the new one"
        var currentNotes: [Note] = []
        currentNotes.append(newNote)
        context.notes.wrappedValue = currentNotes
        
        // Save notes
        if let encoded = try? JSONEncoder().encode(currentNotes) {
            context.savedNotesData.wrappedValue = encoded
            // Sync to widget
            WidgetDataSync.syncNotesToWidget(encoded)
        }
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        #if DEBUG
        print("📖 Added verse as note: \(verse.reference)")
        #endif
    }
}





// MARK: - Open Bible Button
private struct OpenBibleButtonView: View {
    @Binding var showBibleMenu: Bool
    let context: ContentViewContext
    @StateObject private var languageManager = BibleLanguageManager.shared
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            showBibleMenu = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.system(size: 16))
                
                Text("Add your Bible verse")
                    .fontWeight(.medium)
                
                Spacer()
                
                // Show current language
                HStack(spacing: 4) {
                    Text(languageManager.selectedTranslation.flagEmoji)
                    Text(languageManager.selectedTranslation.shortName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.appAccent)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// Deprecated - kept for compatibility
private struct ExploreBibleButtonView: View {
    @Binding var showBibleExplorer: Bool
    let context: ContentViewContext
    
    var body: some View {
        OpenBibleButtonView(showBibleMenu: $showBibleExplorer, context: context)
    }
}

private struct NotesSectionView: View {
    let context: ContentViewContext

    var body: some View {
        Group {
            if context.notes.wrappedValue.isEmpty {
                EmptyStateView(hideKeyboard: context.hideKeyboard, isTextFieldFocused: context.isTextFieldFocused)
            } else {
                NotesListView(context: context)
            }
        }
    }
}

private struct EmptyStateView: View {
    let hideKeyboard: () -> Void
    let isTextFieldFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack {
            Spacer()
            
            // Text always visible, arrow only when not focused
            VStack(spacing: 8) {
                Text("No Verses Yet")
                    .foregroundColor(.gray)
                    .font(.title3)
                Text("Add a Bible verse below to get started")
                    .foregroundColor(.gray)
                    .font(.caption)
                
                // Arrow only appears when text field is not focused
                if !isTextFieldFocused.wrappedValue {
                    // Arrow pointing to plus icon
                    HStack {
                        Spacer()
                        Image("arrow")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 280, height: 160)  // Reduced height to crop top
                            .clipped()  // Crop the excess
                            .rotationEffect(.degrees(248)) // Rotate to point down-right
                            .offset(x: 20, y: 90) // Adjusted offset since we cropped
                            .opacity(0.8)
                    }
                    .padding(.top, -60) // Negative padding to bring arrow much closer
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            hideKeyboard()
        }
    }
}

private struct NotesListView: View {
    let context: ContentViewContext
    
    @State private var noteToEdit: Note?

    private var notes: [Note] {
        context.notes.wrappedValue
    }

    var body: some View {
        List {
            ForEach(notes) { note in
                NoteRowContainer(note: note, context: context)
                    .onTapGesture {
                        if context.isEditMode.wrappedValue {
                            // Toggle selection in edit mode
                            if context.selectedNotes.wrappedValue.contains(note.id) {
                                context.selectedNotes.wrappedValue.remove(note.id)
                            } else {
                                context.selectedNotes.wrappedValue.insert(note.id)
                            }
                        } else {
                            // Open edit sheet in normal mode
                            noteToEdit = note
                        }
                    }
            }
            .onMove { source, destination in
                context.moveNotes(source, destination)
            }

            // Trial reminder banner
            if !context.isEditMode.wrappedValue {
                TrialReminderBannerView()
            }
            
            // First note hint banner (shown after first note added)
            if context.showFirstNoteHint.wrappedValue && !context.isEditMode.wrappedValue {
                FirstNoteHintBannerView(context: context)
            }
            
            // Troubleshooting banner appears after notes (Shortcut pipeline only)
            if context.shouldShowTroubleshootingBanner.wrappedValue && !context.isEditMode.wrappedValue && context.selectedOnboardingPipeline != "widget" {
                TroubleshootingBannerView(context: context)
            }

            if context.isEditMode.wrappedValue {
                EditModeSupplementView(context: context, notes: notes)
            }
        }
        .listStyle(.plain)
        .animation(.easeInOut(duration: 0.3), value: notes.map { $0.id })
        .environment(\.editMode, .constant(context.isEditMode.wrappedValue ? .active : .inactive))
        .sheet(item: $noteToEdit) { note in
            // Parse the note text to extract verse and reference
            let components = note.text.components(separatedBy: "\n— ")
            let verseText = components.first ?? note.text
            let reference = components.count > 1 ? components[1] : ""
            
            // Create a placeholder BibleVerse for editing
            let verse = BibleVerse(
                bookName: reference.isEmpty ? "My Note" : reference.components(separatedBy: " ").first ?? "My Note",
                chapter: 1,
                verse: 1,
                text: verseText,
                translation: BibleLanguageManager.shared.selectedTranslation
            )
            
            if context.selectedOnboardingPipeline == "widget" {
                // Widget pipeline: Use VerseReviewView
                VerseReviewView(verse: verse, isEditing: true) { editedText, editedReference in
                    //  Save the edited verse
                    let updatedNoteText = editedReference.isEmpty ? editedText : "\(editedText)\n— \(editedReference)"
                    if let index = context.notes.wrappedValue.firstIndex(where: { $0.id == note.id }) {
                        context.notes.wrappedValue[index].text = updatedNoteText
                        
                        // Save to UserDefaults
                        if let encoded = try? JSONEncoder().encode(context.notes.wrappedValue) {
                            context.savedNotesData.wrappedValue = encoded
                            WidgetDataSync.syncNotesToWidget(encoded)
                        }
                    }
                    
                    noteToEdit = nil
                }
            } else {
                // Shortcut pipeline: Use ShortcutVerseReviewView with styling options
                ShortcutVerseReviewView(verse: verse, isEditing: true) { editedText in
                    // Save the edited verse
                    let updatedNoteText = "\(editedText)\n— \(reference)"
                    if let index = context.notes.wrappedValue.firstIndex(where: { $0.id == note.id }) {
                        context.notes.wrappedValue[index].text = updatedNoteText
                        
                        // Save to UserDefaults
                        if let encoded = try? JSONEncoder().encode(context.notes.wrappedValue) {
                            context.savedNotesData.wrappedValue = encoded
                        }
                    }
                    
                    // Trigger wallpaper update
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // Ensure loading overlay shows for landscape/portrait edits too
                        NotificationCenter.default.post(name: .showGlobalLoadingOverlay, object: nil)
                        context.showWallpaperUpdateLoading.wrappedValue = true
                        context.updateWallpaper()
                    }
                    
                    noteToEdit = nil
                }
            }
        }
    }
}

private struct EditModeMenuButton: View {
    let context: ContentViewContext

    var body: some View {
        if context.notes.wrappedValue.isEmpty {
            EmptyView()
        } else {
            Button(action: {
                toggleEditMode()
            }) {
                Image(systemName: context.isEditMode.wrappedValue ? "xmark" : "ellipsis")
                    .font(.system(size: 20, weight: .bold)) // Slightly larger for better visibility without circle
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44) // Ensure good touch target
                    .contentShape(Rectangle()) // Ensure entire 44x44 area is tappable
            }
            .accessibilityLabel(context.isEditMode.wrappedValue ? "Close Editing" : "Edit Notes")
            .highPriorityGesture(
                TapGesture()
                    .onEnded { _ in
                        toggleEditMode()
                    }
            )
            .contextMenu {
                if context.isEditMode.wrappedValue {
                    Button("Select All") {
                        selectAllNotes()
                    }

                    Button("Deselect All") {
                        deselectAllNotes()
                    }

                    Button("Delete Selected", role: .destructive) {
                        context.activeAlert.wrappedValue = .deleteSelectedNotes
                    }
                    .disabled(context.selectedNotes.wrappedValue.isEmpty)
                } else {
                    Button("Enter Edit Mode") {
                        activateEditMode()
                    }
                    Button("Select All") {
                        selectAllNotes()
                    }
                }
            }
        }
    }

    private func toggleEditMode() {
        guard !context.notes.wrappedValue.isEmpty else { return }
        context.hideKeyboard()
        
        // Light impact haptic for entering/exiting edit mode
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.25)) {
            context.isEditMode.wrappedValue.toggle()
            if !context.isEditMode.wrappedValue {
                context.selectedNotes.wrappedValue.removeAll()
            }
        }
    }

    private func activateEditMode() {
        guard !context.isEditMode.wrappedValue else { return }
        context.hideKeyboard()
        withAnimation(.easeInOut(duration: 0.25)) {
            context.isEditMode.wrappedValue = true
        }
    }

    private func selectAllNotes() {
        if !context.isEditMode.wrappedValue {
            activateEditMode()
        }
        context.selectedNotes.wrappedValue = Set(context.notes.wrappedValue.map { $0.id })
    }

    private func deselectAllNotes() {
        context.selectedNotes.wrappedValue.removeAll()
    }
}




private struct NoteRowContainer: View {
    let note: Note
    let context: ContentViewContext

    var body: some View {
        if let binding = context.binding(for: note) {
            NoteRowView(
                note: binding,
                isOnWallpaper: false,
                isEditMode: context.isEditMode.wrappedValue,
                isSelected: context.selectedNotes.wrappedValue.contains(note.id),
                toggleSelection: { context.toggleSelection(note) },
                onDelete: { context.handleDelete(note) },
                onToggleCompletion: { context.toggleCompletion(note) },
                onCommit: context.noteCommit
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .animation(.easeInOut(duration: 0.25), value: context.isEditMode.wrappedValue)
        }
    }
}

private struct EditModeSupplementView: View {
    let context: ContentViewContext
    let notes: [Note]

    var body: some View {
        Group {
            Section {
                HStack {
                    Button(action: toggleSelection) {
                        Text(selectionButtonTitle)
                            .foregroundColor(.appAccent)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: { context.activeAlert.wrappedValue = .deleteSelectedNotes }) {
                        Text("Delete (\(context.selectedNotes.wrappedValue.count))")
                            .foregroundColor(context.selectedNotes.wrappedValue.isEmpty ? .gray : .red)
                    }
                    .buttonStyle(.plain)
                    .disabled(context.selectedNotes.wrappedValue.isEmpty)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .listRowInsets(EdgeInsets())
            }
            .listSectionSeparator(.hidden)

            Section {
                Color.clear
                    .frame(height: 20)
                    .listRowInsets(EdgeInsets())
            }
            .listSectionSeparator(.hidden)
        }
    }

    private var selectionButtonTitle: String {
        context.selectedNotes.wrappedValue.count == notes.count ? "Deselect All" : "Select All"
    }

    private func toggleSelection() {
        if context.selectedNotes.wrappedValue.count == notes.count {
            context.selectedNotes.wrappedValue.removeAll()
        } else {
            context.selectedNotes.wrappedValue = Set(notes.map { $0.id })
        }
    }
}

// MARK: - Widget Character Limit
private let widgetCharacterLimit = 120

private struct AddNoteSectionView: View {
    let context: ContentViewContext
    
    private var characterCount: Int {
        context.newNoteText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).count
    }
    
    private var isOverLimit: Bool {
        characterCount > widgetCharacterLimit
    }

    var body: some View {
        VStack(spacing: 0) {
            // Warning banner when over character limit
            if isOverLimit {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Lock screen widget supports max \(widgetCharacterLimit) characters. Current: \(characterCount)")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }
            
            HStack(spacing: 12) {
                TextField("Add a note...", text: context.newNoteText)
                    .focused(context.isTextFieldFocused)
                    .submitLabel(.done)
                    .font(.system(size: 16))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isOverLimit ? Color.orange : Color.clear, lineWidth: 2)
                    )
                    .onSubmit {
                        context.addNote()
                    }

                Button(action: { context.addNote() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(isAddDisabled ? .gray : .appAccent)
                }
                .disabled(isAddDisabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color(.systemBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -1)
            )
        }
    }

    private var isAddDisabled: Bool {
        context.newNoteText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct UpdateWallpaperButtonView: View {
    let context: ContentViewContext
    @StateObject private var paywallManager = PaywallManager.shared

    var body: some View {
        Button(action: {
            context.hideKeyboard()
            
            // Check if user can export wallpaper (has credits or is premium)
            if !paywallManager.canExportWallpaper() {
                print("🚫 Wallpaper update blocked - free limit reached")
                paywallManager.showPaywall(reason: .limitReached)
                return
            }
            
            // Light impact haptic for update wallpaper button tap
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            // Mark as user-initiated from homepage - this will consume a credit
            context.isUserInitiatedUpdate.wrappedValue = true
            
            // Show loading overlay for user-initiated updates
            NotificationCenter.default.post(name: .showGlobalLoadingOverlay, object: nil)
            context.showWallpaperUpdateLoading.wrappedValue = true
            
            context.updateWallpaper()
        }) {
            HStack {
                if context.isGeneratingWallpaper.wrappedValue && !context.showWallpaperUpdateLoading.wrappedValue {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                Text(context.isGeneratingWallpaper.wrappedValue && !context.showWallpaperUpdateLoading.wrappedValue ? "Generating..." : "Update Wallpaper")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(context.notes.wrappedValue.isEmpty ? Color.gray : Color.appAccent)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .disabled(context.notes.wrappedValue.isEmpty || context.isGeneratingWallpaper.wrappedValue)
    }
}

private extension ContentViewContext {
    func binding(for note: Note) -> Binding<Note>? {
        guard let index = notes.wrappedValue.firstIndex(where: { $0.id == note.id }) else {
            return nil
        }
        return Binding<Note>(
            get: { notes.wrappedValue[index] },
            set: { newValue in
                var current = notes.wrappedValue
                current[index] = newValue
                notes.wrappedValue = current
            }
        )
    }
}

private extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

struct NoteRowView: View {
    @Binding var note: Note
    let isOnWallpaper: Bool
    let isEditMode: Bool
    let isSelected: Bool
    let toggleSelection: () -> Void
    let onDelete: () -> Void
    let onToggleCompletion: () -> Void
    let onCommit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if isEditMode {
                    Button(action: toggleSelection) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(isSelected ? .appAccent : .gray)
                    }
                    .buttonStyle(.plain)
                }

                ZStack(alignment: .center) {
                    if #available(iOS 16.0, *) {
                        TextField("Note", text: $note.text, axis: .vertical)
                            .font(.system(.body, design: .default))
                            .foregroundColor(note.isCompleted ? .secondary : .primary)
                            .disabled(!isEditMode)
                            .padding(.vertical, 8)
                    } else {
                        // Fallback for earlier versions
                        TextField("Note", text: $note.text)
                            .font(.system(.body, design: .default))
                            .foregroundColor(note.isCompleted ? .secondary : .primary)
                            .disabled(!isEditMode)
                            .padding(.vertical, 8)
                    }

                    if note.isCompleted {
                        Rectangle()
                            .fill(Color.appAccent)
                            .frame(height: 1.5)
                            .opacity(0.9)
                            .allowsHitTesting(false)
                    }
                }

                Spacer(minLength: 0)

                if isOnWallpaper && !isEditMode {
                    Image(systemName: "photo.badge.checkmark.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.appAccent)
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.m)

            Divider()
                .background(Color(.separator))
                .frame(maxWidth: .infinity)
                .opacity(isEditMode ? 0 : 1)
        }
        .background(Color(.systemBackground))
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        // .onTapGesture removed to allow parent to handle taps

        .animation(.easeInOut(duration: 0.25), value: isEditMode)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// Single-line text field that shows truncated text with ellipsis when idle,
/// then scrolls horizontally to reveal the end when you tap to edit.
struct AutoScrollingTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let textColor: UIColor
    let font: UIFont
    let isDisabled: Bool
    let onCommit: () -> Void
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.returnKeyType = .done
        textField.adjustsFontSizeToFitWidth = false
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange), for: .editingChanged)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        // Sync text
        if uiView.text != text {
            uiView.text = text
        }
        uiView.placeholder = placeholder
        uiView.textColor = textColor
        uiView.font = font
        uiView.isEnabled = !isDisabled
        uiView.alpha = isDisabled ? 0.5 : 1.0
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: NSObject, UITextFieldDelegate {
        private let parent: AutoScrollingTextField
        
        init(_ parent: AutoScrollingTextField) {
            self.parent = parent
        }
        
        @objc func textDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onCommit()
            textField.resignFirstResponder()
            return false
        }
        
        func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
            !parent.isDisabled
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            // Move cursor to the end
            DispatchQueue.main.async {
                let endPosition = textField.endOfDocument
                textField.selectedTextRange = textField.textRange(from: endPosition, to: endPosition)
            }
        }
    }
}

private struct TroubleshootingBannerView: View {
    let context: ContentViewContext
    @State private var isTemporarilyHidden = false
    
    var body: some View {
        Group {
            if !isTemporarilyHidden {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.appAccent)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Wallpaper Not Showing?")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("We can help you fix it in just a few steps.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            // Light impact haptic for dismissing banner
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            withAnimation {
                                isTemporarilyHidden = true
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: {
                        // Medium impact haptic for opening troubleshooting
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        context.showTroubleshooting.wrappedValue = true
                    }) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Get Help")
                                .fontWeight(.semibold)
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.appAccent,
                                            Color.appAccent.opacity(0.9)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appAccent.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
    }
}

private struct TrialReminderBannerView: View {
    @StateObject private var paywallManager = PaywallManager.shared
    @AppStorage("trialReminderDismissed") private var isDismissed = false
    
    var body: some View {
        if paywallManager.shouldShowTrialReminder && !isDismissed {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(.appAccent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Friendly Reminder")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Your free trial subscription will be ending soon.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Button(action: {
                    // Light impact haptic for dismissing banner
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    
                    withAnimation {
                        isDismissed = true
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appAccent.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
}

private struct FirstNoteHintBannerView: View {
    let context: ContentViewContext
    @AppStorage("selectedOnboardingPipeline") private var selectedOnboardingPipeline = ""
    @State private var isDismissed = false
    
    var body: some View {
        Group {
            if !isDismissed {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundColor(.appAccent)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Great! You added your first note")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if selectedOnboardingPipeline == "widget" {
                                Text("Add more notes using the + button. They will automatically appear on your widget.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("Add more notes using the + button, then tap \"Update Wallpaper\" to apply them to your lock screen.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            // Light impact haptic for dismissing banner
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isDismissed = true
                                context.showFirstNoteHint.wrappedValue = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appAccent.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 8)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
    }
}

#Preview {
    ContentView()
}

private struct AccentStrikethrough: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            if #available(iOS 16.0, *) {
                content
                    .strikethrough(true, color: .appAccent)
            } else {
                content
                    .overlay(
                        Rectangle()
                            .foregroundColor(.appAccent)
                            .frame(height: 1.2)
                            .mask(content)
                    )
            }
        } else {
            content
        }
    }
}

private extension View {
    func accentStrikethrough(_ isActive: Bool) -> some View {
        modifier(AccentStrikethrough(isActive: isActive))
    }
}
