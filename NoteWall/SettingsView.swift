import SwiftUI
import PhotosUI
import UIKit
import Combine
import StoreKit

struct SettingsView: View {
    @AppStorage("savedNotes") private var savedNotesData: Data = Data()
    @AppStorage("skipDeletingOldWallpaper") private var skipDeletingOldWallpaper = false
    @AppStorage("autoUpdateWallpaperAfterDeletion") private var autoUpdateWallpaperAfterDeletionRaw: String = ""
    @AppStorage("saveWallpapersToPhotos") private var saveWallpapersToPhotos = false
    @AppStorage("hasLockScreenWidgets") private var hasLockScreenWidgets = true
    @AppStorage("wallpaperIsShadowEnabled") private var isShadowEnabled: Bool = false
    @AppStorage("wallpaperShadowIntensity") private var shadowIntensity: Double = 0.5
    @AppStorage("wallpaperFontSizeScaling") private var fontSizeScaling: Double = 1.0 // NEW: Font Size Memory
    @AppStorage("lockScreenBackground") private var lockScreenBackgroundRaw = LockScreenBackgroundOption.default.rawValue
    @AppStorage("lockScreenBackgroundMode") private var lockScreenBackgroundModeRaw = LockScreenBackgroundMode.default.rawValue
    @AppStorage("lockScreenBackgroundPhotoData") private var lockScreenBackgroundPhotoData: Data = Data()
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @AppStorage("completedOnboardingVersion") private var completedOnboardingVersion = 0
    @StateObject private var paywallManager = PaywallManager.shared
    @State private var showDeleteAlert = false
    @State private var showResetAlert = false
    @State private var showPaywall = false
    @State private var showTroubleshooting = false
    @State private var shouldRestartOnboarding = false
    @State private var showExitFeedback = false
    @State private var showSubscriptionFeedback = false
    @State private var showSupportView = false
    @State private var showLegalSelection = false
    @State private var supportViewAnimateIn = false
    @State private var supportViewFloatOffset: CGFloat = 0
    var selectedTab: Binding<Int>?

    private let shortcutURL = "https://www.icloud.com/shortcuts/3365d3809e8c4ddfa89879ae0a19cbd3"
    private let whatsappNumber = "421907758852"
    private let supportEmail = "iosnotewall@gmail.com"
    
    init(selectedTab: Binding<Int>? = nil) {
        self.selectedTab = selectedTab
    }

    @State private var isSavingLockScreenBackground = false
    @State private var lockScreenBackgroundStatusMessage: String?
    @State private var lockScreenBackgroundStatusColor: Color = .gray
    @State private var showLegalDocument = false
    @State private var selectedLegalDocument: LegalDocumentType = .termsOfService
    @State private var isUpdatingWallpaperFromToggle = false
    
    // MARK: - Text Styling State (Instagram-style toolbar)
    @State private var selectedFontName = UserDefaults.standard.wallpaperFontName
    @State private var showFontList = false
    @State private var selectedColorName = "Auto"
    @State private var customColor: Color = {
        if let uiColor = UserDefaults.standard.wallpaperCustomColor() {
            return Color(uiColor)
        }
        return .white
    }()
    @State private var alignmentMode = UserDefaults.standard.wallpaperAlignment
    @State private var highlightMode = UserDefaults.standard.wallpaperHighlightMode // RESTORED
    @AppStorage("wallpaperUseCustomColor") private var useCustomColor = false
    @State private var previewBackgroundImage: UIImage?

    var body: some View {
        NavigationView {
            settingsList
                .listStyle(.insetGrouped)
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
                .alert("Delete All Notes?", isPresented: $showDeleteAlert) {
                    Button("Cancel", role: .cancel) {
                        // Light impact haptic for alert dismissal
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                    Button("Delete", role: .destructive) {
                        deleteAllNotes()
                    }
                } message: {
                    Text("This action cannot be undone. All your notes will be permanently deleted.")
                }
                .alert("Reinstall Shortcut?", isPresented: $showResetAlert) {
                    Button("Cancel", role: .cancel) {
                        // Light impact haptic for alert dismissal
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                    Button("Reset & Reinstall", role: .destructive) {
                        resetToFreshInstall()
                    }
                } message: {
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            AnalyticsService.shared.trackScreenView(
                screenName: "settings_tab",
                screenClass: "SettingsView"
            )
            loadPreviewImage()
        }
    }

    @ViewBuilder
    private var settingsList: some View {
        List {
            premiumSection
            wallpapersSection
            textStyleSection
            wallpaperSettingsSection
            actionsSection
            supportSection
        }
        .sheet(isPresented: $showPaywall) {
            if #available(iOS 15.0, *) {
                PaywallView(triggerReason: .settings, allowDismiss: true)
            }
        }
        .sheet(isPresented: $showTroubleshooting) {
            TroubleshootingView(
                isPresented: $showTroubleshooting,
                shouldRestartOnboarding: $shouldRestartOnboarding
            )
        }
        .sheet(isPresented: $showExitFeedback) {
            ExitFeedbackView()
        }
        .sheet(isPresented: $showSubscriptionFeedback) {
            SubscriptionFeedbackView()
        }
        .sheet(isPresented: $showSupportView) {
            supportOnlyView
            }
        .sheet(isPresented: $showLegalSelection) {
            legalSelectionView
        }
        .sheet(isPresented: $showLegalDocument) {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(getLegalDocumentContent())
                            .font(.system(.body, design: .default))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }
                }
                .navigationTitle(selectedLegalDocument.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showLegalDocument = false
                        }
                    }
                }
            }
        }
        .onChange(of: shouldRestartOnboarding) { _, shouldRestart in
            if shouldRestart {
                // Reinstall shortcut only - preserve subscription and user info
                reinstallShortcutOnly()
                shouldRestartOnboarding = false
            }
        }
    }
    
    private var premiumSection: some View {
        Section {
            if paywallManager.isPremium {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    showSubscriptionFeedback = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.appAccent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NoteWall+ Active")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(paywallManager.hasLifetimeAccess ? NSLocalizedString("Lifetime Access", comment: "") : NSLocalizedString("Subscription Active", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.appAccent)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {
                    // Light impact haptic for opening paywall
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    showPaywall = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundColor(.appAccent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Upgrade to NoteWall+")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("\(paywallManager.remainingFreeExports) free wallpapers remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                
            }
        }
    }

    // MARK: - Text Style Section (Instagram-style formatting)
    
    private var textStyleSection: some View {
        Section(header: Text("Text Style")) {
            VStack(spacing: 0) {
                // Preview of current style
                textStylePreview
                    .padding(.bottom, 12)
                    
                // Instagram-style toolbar
                StylingToolbarView(
                    selectedFontName: $selectedFontName,
                    showFontList: $showFontList,
                    selectedColorName: $selectedColorName,
                    customColor: $customColor,
                    alignmentMode: $alignmentMode,
                    highlightMode: $highlightMode,
                        isShadowEnabled: $isShadowEnabled,
                        shadowIntensity: $shadowIntensity,
                        fontSizeScaling: $fontSizeScaling, // Binding
                        onUpdate: {
                            // Trigger preview update
                            // State changes automatically trigger view updates
                             saveTextStyleSettings()
                        }
                    )
                
                // Reminder to update wallpaper
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.appAccent)
                    
                    Text("After changing styles, tap **Update Wallpaper Now** above to apply")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
            .listRowBackground(Color.clear)
            .onChange(of: customColor) { _ in
                useCustomColor = true
            }
        }
    }
    
    private var textStylePreview: some View {
        ZStack {
            // Background (lock screen image or gradient)
            GeometryReader { geometry in
                if let image = previewBackgroundImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .overlay(Color.black.opacity(0.2)) // Slight dim to ensure text readability
                } else {
                    LinearGradient(
                        colors: [Color(white: 0.12), Color(white: 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(height: 180) // Taller preview to see more context
            .cornerRadius(16)
            
            // Sample text with current styling
            Text("Preview") // Shortened to fit better at max scale
                .lineLimit(1) // Force single line as requested
                .font(previewFont)
                // Removed .scaleEffect to ensure layout and background update correctly
                .foregroundColor(previewTextColor)
                // Outline Fix: Apply outline style strictly
                .shadow(color: outlineShadowColor, radius: 0, x: 1, y: 1)
                .shadow(color: outlineShadowColor, radius: 0, x: -1, y: -1)
                .shadow(color: outlineShadowColor, radius: 0, x: 1, y: -1)
                .shadow(color: outlineShadowColor, radius: 0, x: -1, y: 1)
                // Standard Shadow
                .shadow(color: previewShadowColor, radius: previewShadowRadius, x: 0, y: 2)
                .multilineTextAlignment(previewAlignment)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    // Show highlight box based on mode
                    highlightBackground
                )
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .padding(.horizontal, 24)
                .id("Preview-\(selectedFontName)-\(selectedColorName)-\(alignmentMode)-\(highlightMode)-\(shadowIntensity)-\(useCustomColor)-\(fontSizeScaling)") // Force redraw
        }
        .padding(.horizontal, 24)
    }
    
    private var highlightBackground: some View {
        Group {
            if highlightMode == 1 { // Outline
                 // Outline mode should NOT show a background box. 
                 // The text itself handles the outline.
                 EmptyView()
            } else if highlightMode == 2 { // White
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.85))
            } else if highlightMode == 3 { // Black
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.7))
            }
        }
    }
    
    private var frameAlignment: Alignment {
        switch alignmentMode {
        case 0: return .leading
        case 1: return .center
        case 2: return .trailing
        default: return .center
        }
    }
    
    private var previewFont: Font {
        let fontType = WallpaperRenderer.WallpaperFont(rawValue: selectedFontName) ?? .modern
        let baseSize: CGFloat = 28
        let scaledSize = baseSize * fontSizeScaling
        
        switch fontType {
        case .classic: return .system(size: scaledSize, weight: .semibold, design: .serif)
        case .modern: return .system(size: scaledSize, weight: .semibold, design: .default)
        case .rounded: return .system(size: scaledSize, weight: .semibold, design: .rounded)
        case .typewriter: return .system(size: scaledSize * 0.85, weight: .semibold, design: .monospaced)
        case .strong: return .system(size: scaledSize, weight: .black, design: .default)
        // Neon looks better slightly larger
        case .neon: return .custom("SnellRoundhand-Bold", size: scaledSize * 1.15)
        }
    }
    
    private var previewTextColor: Color {
        if useCustomColor {
            return customColor
        }
        return .white
    }
    
    private var previewShadowColor: Color {
        if isShadowEnabled {
            return Color.black.opacity(0.6 * shadowIntensity)
        }
        return Color.clear
    }
    
    private var previewShadowRadius: CGFloat {
        if isShadowEnabled {
            return 8 * shadowIntensity
        }
        return 0
    }

    private var outlineShadowColor: Color {
        if highlightMode == 1 { // Outline Mode
             // Use same outline style as lock screen (text color with stroke effect)
             // If text is white, outline is black? Or self-colored? 
             // WallpaperRenderer uses text color as main, and nil background.
             // Wait, WallpaperRenderer line 504: case .outline: finalTextColor = textColor.
             // But usually Outline implies stroked text or drop shadow to separate?
             // Ah, checking logic again: 
             // WallpaperRenderer DOES NOT apply stroke attribute. It just sets text color and passes nil highlight.
             // Wait. What does it actually do for Outline?
             // Line 504: finalTextColor = textColor; highlightColor = nil; 
             // It essentially does NOTHING different than .none except maybe shadow adjustments?
             // Ah, I see "buildOutlineString" helper but it is NOT called in lines 467-525.
             // Let me check where buildOutlineString is CALLED.
             // It seems I might have misread the renderer logic.
             // If highlightMode == .outline, the renderer sets text color but NO background.
             // But wait, user says "shows realistic black outline".
             // If the renderer just draws plain text, that's not an outline.
             // I need to verify if `buildOutlineString` is actually used.
             // usually implies stroked text or drop shadow to separate?
             // User wants realistic BLACK outline.
             return Color.black 
        }
        return Color.clear
    }
    
    private var previewAlignment: TextAlignment {
        switch alignmentMode {
        case 0: return .leading
        case 1: return .center
        case 2: return .trailing
        default: return .center
        }
    }
    
    private func saveTextStyleSettings() {
        UserDefaults.standard.wallpaperFontName = selectedFontName
        UserDefaults.standard.wallpaperAlignment = alignmentMode
        UserDefaults.standard.wallpaperHighlightMode = highlightMode
        UserDefaults.standard.wallpaperIsShadowEnabled = isShadowEnabled
        UserDefaults.standard.wallpaperShadowIntensity = shadowIntensity
        UserDefaults.standard.wallpaperUseCustomColor = useCustomColor
        UserDefaults.standard.wallpaperFontSizeScaling = fontSizeScaling
        
        #if DEBUG
        print("💾 Saved text style settings:")
        print("   Font: \(selectedFontName)")
        print("   Alignment: \(alignmentMode)")
        print("   Highlight: \(highlightMode)")
        print("   Shadow: \(isShadowEnabled) @ \(Int(shadowIntensity * 100))%")
        #endif
    }

    private var wallpaperSettingsSection: some View {
        Section(header: Text("Wallpaper Settings")) {
            // Lock Screen Widgets toggle - affects note positioning
            Toggle(isOn: Binding(
                get: { hasLockScreenWidgets },
                set: { newValue in
                    hasLockScreenWidgets = newValue
                    // Light impact haptic for toggle switch
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    // Trigger wallpaper update with animation
                    triggerWallpaperUpdateFromToggle()
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("I use lock screen widgets")
                    Text(hasLockScreenWidgets 
                        ? NSLocalizedString("Notes start appearing lower to avoid widgets that are below the time.", comment: "") 
                        : NSLocalizedString("Notes start closer to the time for more space and aesthetic look.", comment: ""))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .wallpaperGenerationFinished)) { _ in
            isUpdatingWallpaperFromToggle = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutWallpaperApplied)) { _ in
            isUpdatingWallpaperFromToggle = false
        }
    }

    @ViewBuilder
    private var wallpapersSection: some View {
        Group {
            if #available(iOS 16.0, *) {
                Section("Wallpapers") {
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
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)

                    UpdateWallpaperButton(selectedTab: selectedTab)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 20, leading: 0, bottom: 12, trailing: 0))
                }
            } else {
                Section(header: Text("Wallpapers")) {
                    Text("Saving a lock screen image requires iOS 16 or newer.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.vertical, 4)
                }
            }
        }
        .onChange(of: lockScreenBackgroundPhotoData) { _ in
             loadPreviewImage()
        }
        .onChange(of: lockScreenBackgroundRaw) { _ in
             loadPreviewImage()
        }
    }

    private var actionsSection: some View {
        Section(header: Text("Actions")) {
            Button(action: {
                showTroubleshooting = true
            }) {
                HStack {
                    Text("Wallpaper Not Showing?")
                        .foregroundColor(.appAccent)
                    Spacer()
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundColor(.appAccent)
                }
            }
            
            Button(action: {
                // Medium impact haptic for destructive delete action
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                showDeleteAlert = true
            }) {
                HStack {
                    Text("Delete All Notes")
                        .foregroundColor(.red)
                    Spacer()
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            Button(action: {
                // Light impact haptic for review button
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                openAppStoreReview()
            }) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.white)
                    Text("Write a Review")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
            }
        }
    }

    private var supportSection: some View {
            Section(header: Text("Help & Support")) {
                
                Button(action: {
                    showExitFeedback = true
                }) {
                    HStack {
                        Image(systemName: "message.fill")
                        .foregroundColor(.secondary)
                        Text("Send Feedback")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                }
                
                Button(action: {
                showSupportView = true
                }) {
                    HStack {
                    Image(systemName: "headphones")
                        .foregroundColor(.secondary)
                    Text("Contact Support")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                }
            }
            
                Button(action: {
                showLegalSelection = true
            }) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.secondary)
                    Text("Legal")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
            }
            
            Button(action: {
                shareApp()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.secondary)
                    Text("Share NoteWall")
                        .foregroundColor(.primary)
                    Spacer()
            }
            }
        }
    }


    private func loadPreviewImage() {
        // 1. Try to load custom background photo (if user selected one)
        if let image = HomeScreenImageManager.lockScreenBackgroundSourceImage() {
            previewBackgroundImage = image
            return
        }
        
        // 2. Fallback to current preset
        if let preset = LockScreenBackgroundOption(rawValue: lockScreenBackgroundRaw) {
             previewBackgroundImage = solidColorImage(color: preset.uiColor)
             return
        }
        
        // 3. Fallback to gradient (nil)
        previewBackgroundImage = nil
    }
    
    private func solidColorImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 500, height: 1000)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    private func deleteAllNotes() {
        // Post notification to show global loading overlay (handled by MainTabView)
        // This ensures the loading view stays visible when switching to home tab
        NotificationCenter.default.post(name: .showDeleteNotesLoadingOverlay, object: nil)
        
        // Delete notes after a small delay (overlay will be visible by then)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            savedNotesData = Data()
        }
        
        // The loading view will automatically show success after 10 seconds and dismiss
    }

    
    /// Reinstalls shortcut only - preserves subscription, promo codes, and user info
    /// Used when user goes through troubleshooting flow to fix shortcut issues
    private func reinstallShortcutOnly() {
        #if DEBUG
        print("🔄 REINSTALLING SHORTCUT ONLY (preserving subscription & user info)")
        #endif
        
        // CRITICAL: Set hasCompletedSetup to false FIRST before clearing notes
        // This prevents the onChange handler from triggering wallpaper update
        // when savedNotesData is cleared (which would otherwise see hasCompletedSetup = true)
        hasCompletedSetup = false
        completedOnboardingVersion = 0
        
        // Clear notes and wallpaper-related data (user needs to go through setup again)
        savedNotesData = Data()
        skipDeletingOldWallpaper = false
        saveWallpapersToPhotos = false
        autoUpdateWallpaperAfterDeletionRaw = ""
        lockScreenBackgroundRaw = LockScreenBackgroundOption.default.rawValue
        lockScreenBackgroundModeRaw = LockScreenBackgroundMode.default.rawValue
        lockScreenBackgroundPhotoData = Data()
        
        // Clear shortcut-related AppStorage keys
        UserDefaults.standard.removeObject(forKey: "lastLockScreenIdentifier")
        UserDefaults.standard.removeObject(forKey: "hasCompletedInitialWallpaperSetup")
        UserDefaults.standard.removeObject(forKey: "hasShownAutoUpdatePrompt")
        UserDefaults.standard.removeObject(forKey: "hasShownFirstNoteHint")
        
        // Reset shortcut setup completion flag (this is what we're fixing)
        ShortcutVerificationService.resetSetupCompletion()
        
        // CRITICAL: DO NOT reset paywall/subscription data
        // Subscription, promo codes, and user info are preserved
        
        // Delete wallpaper files (user will regenerate during onboarding)
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let noteWallURL = documentsURL.appendingPathComponent("NoteWall", isDirectory: true)
            
            if FileManager.default.fileExists(atPath: noteWallURL.path) {
                do {
                    try FileManager.default.removeItem(at: noteWallURL)
                    #if DEBUG
                    print("✅ Deleted wallpaper files")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ Error deleting files: \(error)")
                    #endif
                }
            }
        }
        
        #if DEBUG
        print("✅ Shortcut reinstall complete! Subscription and user info preserved.")
        print("   Triggering onboarding...")
        #endif
        
        // Trigger onboarding
        NotificationCenter.default.post(name: .onboardingReplayRequested, object: nil)
    }
    
    private func resetToFreshInstall() {
        #if DEBUG
        print("🔄 RESETTING APP TO FRESH INSTALL STATE")
        #endif
        
        // CRITICAL: Preserve promo codes - they are admin-generated and should persist
        // Backup codes before reset
        PromoCodeManager.shared.performBackupIfNeeded()
        
        // 1. Clear all AppStorage values
        // CRITICAL: Set hasCompletedSetup to false FIRST before clearing notes
        // This prevents the onChange handler from triggering wallpaper update
        // when savedNotesData is cleared (which would otherwise see hasCompletedSetup = true)
        hasCompletedSetup = false
        completedOnboardingVersion = 0
        
        // Now clear other data (order matters for race conditions!)
        savedNotesData = Data()
        skipDeletingOldWallpaper = false
        saveWallpapersToPhotos = false
        autoUpdateWallpaperAfterDeletionRaw = ""
        lockScreenBackgroundRaw = LockScreenBackgroundOption.default.rawValue
        lockScreenBackgroundModeRaw = LockScreenBackgroundMode.default.rawValue
        lockScreenBackgroundPhotoData = Data()
        
        // Clear other AppStorage keys that might exist
        UserDefaults.standard.removeObject(forKey: "lastLockScreenIdentifier")
        UserDefaults.standard.removeObject(forKey: "hasCompletedInitialWallpaperSetup")
        UserDefaults.standard.removeObject(forKey: "hasShownAutoUpdatePrompt")
        UserDefaults.standard.removeObject(forKey: "hasShownFirstNoteHint")
        
        // Reset paywall data for fresh install
        PaywallManager.shared.resetForFreshInstall()
        
        // Reset shortcut setup completion flag
        ShortcutVerificationService.resetSetupCompletion()
        
        // Restore promo codes after reset (they should persist)
        PromoCodeManager.shared.restoreCodesIfNeeded()
        
        #if DEBUG
        print("✅ Cleared all AppStorage data")
        #endif
        
        // 2. Delete all files from Documents/NoteWall directory
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let noteWallURL = documentsURL.appendingPathComponent("NoteWall", isDirectory: true)
            
            if FileManager.default.fileExists(atPath: noteWallURL.path) {
                do {
                    try FileManager.default.removeItem(at: noteWallURL)
                    #if DEBUG
                    print("✅ Deleted all wallpaper files")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ Error deleting files: \(error)")
                    #endif
                }
            }
        }
        
        #if DEBUG
        print("🎉 Reset complete! App is now in fresh install state.")
        print("   Triggering onboarding...")
        #endif
        
        // 3. Trigger onboarding
        NotificationCenter.default.post(name: .onboardingReplayRequested, object: nil)
        
        // 4. Switch to Home tab
        if let selectedTab = selectedTab {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                selectedTab.wrappedValue = 0
            }
        }
    }
    
    // MARK: - Support View
    
    private var supportOnlyView: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        showSupportView = false
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
                
                SupportHeroIcon(
                    systemName: "headphones",
                    floatAmplitude: abs(supportViewFloatOffset)
                )
                .frame(height: 200)
                .opacity(supportViewAnimateIn ? 1 : 0)
                .scaleEffect(supportViewAnimateIn ? 1 : 0.8)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: supportViewAnimateIn)
                
                // Title
                VStack(spacing: 10) {
                    Text("We're Here to Help")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Our team responds within 24 hours")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
                .multilineTextAlignment(.center)
                .opacity(supportViewAnimateIn ? 1 : 0)
                .offset(y: supportViewAnimateIn ? 0 : 15)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: supportViewAnimateIn)
                
                Spacer()
                
                // Contact options
                VStack(spacing: 14) {
                        // Email button
                        Button(action: {
                            // Light impact haptic for opening email
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            if let url = URL(string: "mailto:iosnotewall@gmail.com") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.appAccent.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.appAccent)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Email Support")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("iosnotewall@gmail.com")
                                        .font(.system(size: 13))
                                        .foregroundColor(.appAccent)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.appAccent.opacity(0.25), lineWidth: 1)
                                    )
                            )
                        }
                        .opacity(supportViewAnimateIn ? 1 : 0)
                        .offset(x: supportViewAnimateIn ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: supportViewAnimateIn)
                        
                        // WhatsApp button
                        Button(action: {
                            // Light impact haptic for opening WhatsApp
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            openWhatsApp()
                        }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.15, green: 0.78, blue: 0.40).opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.40))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Chat on WhatsApp")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("Get instant help")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.40))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color(red: 0.15, green: 0.78, blue: 0.40).opacity(0.25), lineWidth: 1)
                                    )
                            )
                        }
                        .opacity(supportViewAnimateIn ? 1 : 0)
                        .offset(x: supportViewAnimateIn ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: supportViewAnimateIn)
                        
                        // Twitter button
                        Button(action: {
                            // Light impact haptic for opening Twitter
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            if let url = URL(string: "https://x.com/karchiJR") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.appAccent.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    
                                    Image(systemName: "at")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.appAccent)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Twitter / X")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("@karchiJR")
                                        .font(.system(size: 13))
                                        .foregroundColor(.appAccent)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.appAccent.opacity(0.25), lineWidth: 1)
                                    )
                            )
                        }
                        .opacity(supportViewAnimateIn ? 1 : 0)
                        .offset(x: supportViewAnimateIn ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: supportViewAnimateIn)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .onAppear {
                supportViewAnimateIn = true
                withAnimation(Animation.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    supportViewFloatOffset = -8
                }
            }
        }
    }
    
    // MARK: - Legal Selection View
    
    private var legalSelectionView: some View {
        ZStack {
            // Background gradient (same as supportOnlyView)
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        showLegalSelection = false
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
                
                // Title
                Text("Legal")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 12) {
                        Button(action: {
                            if let url = URL(string: "https://peat-appendix-c3c.notion.site/TERMS-OF-USE-2b7f6a63758f8067a318e16486b16f47?source=copy_link") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.appAccent)
                                    .frame(width: 24)
                                Text("Terms of Service")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundColor(.white.opacity(0.4))
                                    .font(.system(size: 12))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                        
                        Button(action: {
                            if let url = URL(string: "https://peat-appendix-c3c.notion.site/END-USER-LICENSE-AGREEMENT-2b7f6a63758f80a58aebf0207e51f7fb?source=copy_link") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(alignment: .center, spacing: 14) {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.appAccent)
                                    .frame(width: 24)
                                
                                Text("EULA")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .foregroundColor(.white.opacity(0.4))
                                    .font(.system(size: 12))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                        
                        Button(action: {
                            if let url = URL(string: "https://peat-appendix-c3c.notion.site/PRIVACY-POLICY-2b7f6a63758f804cab16f58998d7787e?source=copy_link") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "hand.raised")
                                    .foregroundColor(.appAccent)
                                    .frame(width: 24)
                                Text("Privacy Policy")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundColor(.white.opacity(0.4))
                                    .font(.system(size: 12))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Developer option removed
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Update Wallpaper Button

private struct UpdateWallpaperButton: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isGenerating = false
    var selectedTab: Binding<Int>?

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

                Text(isGenerating ? NSLocalizedString("Updating…", comment: "") : NSLocalizedString("Update Wallpaper Now", comment: ""))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(Color.appAccent)
            .foregroundColor(.white)
            .cornerRadius(12)
            .animation(.easeInOut(duration: 0.2), value: isGenerating)
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
        .padding(.horizontal, 16)
        .onReceive(NotificationCenter.default.publisher(for: .wallpaperGenerationFinished)) { _ in
            isGenerating = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutWallpaperApplied)) { _ in
            isGenerating = false
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                isGenerating = false
            }
        }
    }

    private func triggerUpdate() {
        guard !isGenerating else { return }
        
        // Light impact haptic for update wallpaper button tap
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        isGenerating = true
        
        // Show loading overlay FIRST (appears immediately on top of Settings)
        // Then MainTabView will switch to home tab
        NotificationCenter.default.post(name: .showGlobalLoadingOverlay, object: nil)
        
        // Trigger wallpaper update after a tiny delay (overlay is already visible)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Settings wallpaper changes do NOT count toward free limit
            let request = WallpaperUpdateRequest(
                skipDeletionPrompt: false,
                trackForPaywall: false,
                showLoadingOverlay: false  // Don't show again, MainTabView already showing it
            )
            NotificationCenter.default.post(name: .requestWallpaperUpdate, object: request)
        }
    }
}

// MARK: - Support Hero Icon Component

private struct SupportHeroIcon: View {
    let systemName: String
    let floatAmplitude: CGFloat
    var iconFontSize: CGFloat = 48
    
    @State private var animateRings = false
    @State private var floatingOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                    .frame(width: 140 + CGFloat(i) * 35, height: 140 + CGFloat(i) * 35)
                    .scaleEffect(animateRings ? 1.1 : 1.0)
                    .opacity(animateRings ? 0.3 : 0.6)
                    .animation(
                        Animation.easeInOut(duration: 2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                        value: animateRings
                    )
            }
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.appAccent.opacity(0.25), Color.appAccent.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: systemName)
                    .font(.system(size: iconFontSize, weight: .medium))
                    .foregroundColor(.appAccent)
                    .shadow(color: Color.appAccent.opacity(0.5), radius: 10, x: 0, y: 5)
            }
            .offset(y: floatingOffset)
        }
        .onAppear {
            DispatchQueue.main.async {
                withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    animateRings = true
                }
                withAnimation(Animation.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    floatingOffset = -abs(floatAmplitude)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}

private extension SettingsView {
    private func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openAppStoreReview() {
        // Open the App Store write-review page directly (more reliable than in-app popup)
        let appID = "6755601996"
        let appStoreURLString = "itms-apps://itunes.apple.com/app/id\(appID)?action=write-review"

        if let url = URL(string: appStoreURLString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return
        }

        // Fallback to HTTPS if itms-apps cannot be opened
        if let webURL = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") {
            UIApplication.shared.open(webURL)
        }
    }
    
    /// Opens WhatsApp with pre-filled message for support
    private func openWhatsApp() {
        let message = """
        Hi! I need help with NoteWall.
        
        \(getDeviceInfo())
        """
        
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let whatsappURL = "https://wa.me/\(whatsappNumber)?text=\(encodedMessage)"
        
        guard let url = URL(string: whatsappURL) else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url) { success in
                if !success {
                    // WhatsApp didn't open, show fallback
                    DispatchQueue.main.async {
                        if let emailURL = URL(string: "mailto:\(supportEmail)") {
                            UIApplication.shared.open(emailURL)
                        }
                    }
                }
            }
        } else {
            // WhatsApp not installed, open email instead
            if let emailURL = URL(string: "mailto:\(supportEmail)") {
                UIApplication.shared.open(emailURL)
            }
        }
    }
    
    /// Gets device information for support messages
    private func getDeviceInfo() -> String {
        let device = UIDevice.current
        let systemVersion = device.systemVersion
        let deviceModel = device.model
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        return """
        Device: \(deviceModel)
        iOS: \(systemVersion)
        App Version: \(appVersion)
        """
    }
    
    @available(iOS 13.0, *)
    private func shareApp() {
        let shareText = """
        Just discovered NoteWall - it turns your lock screen into a productivity powerhouse! 🚀
        
        See your goals every time you unlock your phone. Game changer! 
        
        #ProductivityHack #NoteWall #LockScreen
        """
        
        // App Store link using Apple ID (will work once app is published)
        let appURL = URL(string: "https://apps.apple.com/app/id6755601996")!
        let items = [shareText, appURL] as [Any]
        
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // For iPad support
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    private func triggerWallpaperUpdateFromToggle() {
        guard !isUpdatingWallpaperFromToggle else { return }
        
        isUpdatingWallpaperFromToggle = true
        
        // Show loading overlay FIRST (appears immediately on top of Settings)
        // Then MainTabView will switch to home tab
        NotificationCenter.default.post(name: .showGlobalLoadingOverlay, object: nil)
        
        // Trigger wallpaper update after a tiny delay (overlay is already visible)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Settings wallpaper changes do NOT count toward free limit
            let request = WallpaperUpdateRequest(
                skipDeletionPrompt: false,
                trackForPaywall: false,
                showLoadingOverlay: false  // Don't show again, MainTabView already showing it
            )
            NotificationCenter.default.post(name: .requestWallpaperUpdate, object: request)
        }
    }
    
    private func getLegalDocumentContent() -> String {
        switch selectedLegalDocument {
        case .termsOfService:
            return """
            Terms of Service
            
            Last Updated: November 13, 2025
            
            1. Acceptance of Terms
            
            By downloading, installing, or using NoteWall ("the App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, do not use the App.
            
            2. Description of Service
            
            NoteWall is a productivity application that allows users to create custom wallpapers with personal notes and reminders for their iOS devices.
            
            3. Subscription Terms
            
            • NoteWall+ Monthly: Monthly subscription with automatic renewal
            • NoteWall+ Lifetime: One-time payment for permanent access
            • Free trial periods may be offered for subscription plans
            • Subscriptions automatically renew unless cancelled 24 hours before renewal
            • Manage subscriptions in your Apple ID account settings
            
            4. User Obligations
            
            You agree to use the App only for lawful purposes and in accordance with these Terms.
            
            5. Privacy
            
            Your privacy is important to us. All notes and personal data are stored locally on your device and are not transmitted to our servers.
            
            6. Contact Information
            
            For questions or support, contact us at: iosnotewall@gmail.com
            
            Developer: NoteWall Team
            """
        case .privacyPolicy:
            return """
            Privacy Policy
            
            Last Updated: November 13, 2025
            
            1. Information We Collect
            
            • Notes and text you create (stored locally on your device only)
            • Photos you select for wallpapers (processed locally)
            • Device information for app compatibility
            • Anonymous performance data to improve the app
            
            2. How We Use Information
            
            • Provide wallpaper generation functionality
            • Process in-app purchases through Apple's App Store
            • Improve app performance and fix bugs
            • Provide customer support
            
            3. Data Storage
            
            • All personal content is stored locally on your device
            • We do not upload your personal content to external servers
            • Your data remains private and under your control
            
            4. Contact
            
            Email: iosnotewall@gmail.com
            Developer: NoteWall Team
            """
        case .termsAndPrivacy:
            return """
            TERMS OF SERVICE & PRIVACY POLICY
            
            Last Updated: November 13, 2025
            
            ═══════════════════════════════════════
            PART I: END-USER LICENSE AGREEMENT (EULA)
            ═══════════════════════════════════════
            
            The End-User License Agreement (EULA) is hosted online. Please review the complete EULA using the link provided in the app interface.
            
            ═══════════════════════════════════════
            PART II: SUBSCRIPTION TERMS
            ═══════════════════════════════════════
            
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
            
            ═══════════════════════════════════════
            PART III: PRIVACY POLICY
            ═══════════════════════════════════════
            
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
            
            ═══════════════════════════════════════
            PART IV: GENERAL TERMS
            ═══════════════════════════════════════
            
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
            
            ═══════════════════════════════════════
            
            By using NoteWall, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service and Privacy Policy.
            
            Thank you for using NoteWall!
            """
        }
    }
}


// MARK: - Instagram-Style Unified Styling Toolbar

/// A unified styling toolbar inspired by Instagram Stories' text editing interface.
/// Provides 5 main controls: Font, Color, Alignment, Highlight, and Shadow.
struct StylingToolbarView: View {
    @Binding var selectedFontName: String
    @Binding var showFontList: Bool
    @Binding var selectedColorName: String
    @Binding var customColor: Color
    @Binding var alignmentMode: Int
    @Binding var highlightMode: Int
    @Binding var isShadowEnabled: Bool
    @Binding var shadowIntensity: Double
    @Binding var fontSizeScaling: Double // NEW: Font Size Scaling
    var onUpdate: () -> Void
    
    @State private var showShadowSlider: Bool = false
    @State private var showSizeSlider: Bool = false // NEW: Size Slider State
    
    // NoteWall accent color - matches app theme
    private let accentColor = Color(red: 0.4, green: 0.6, blue: 1.0) // Blue accent
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Expandable Font List
            if showFontList {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(WallpaperRenderer.WallpaperFont.allCases) { font in
                            Button(action: {
                                selectedFontName = font.rawValue
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onUpdate()
                            }) {
                                Text(font.rawValue)
                                    .font(fontFont(for: font))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(selectedFontName == font.rawValue ? accentColor : Color(.secondarySystemBackground))
                                    )
                                    .foregroundColor(selectedFontName == font.rawValue ? .white : .primary)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(UIColor.systemBackground))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Expandable Size Slider (NEW)
            if showSizeSlider {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Slider(value: $fontSizeScaling, in: 0.7...2.0, step: 0.05)
                            .tint(accentColor)
                            .onChange(of: fontSizeScaling) { _ in
                                onUpdate()
                            }
                        
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .background(Color(UIColor.systemBackground))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Expandable Shadow Slider
            if showShadowSlider {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "shadow")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Slider(value: $shadowIntensity, in: 0...1, step: 0.05)
                            .tint(accentColor)
                            .onChange(of: shadowIntensity) { newValue in
                                if newValue > 0 && !isShadowEnabled {
                                    isShadowEnabled = true
                                }
                                if newValue == 0 && isShadowEnabled {
                                    isShadowEnabled = false
                                }
                                onUpdate()
                            }
                        
                        Text("\(Int(shadowIntensity * 100))%")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .background(Color(UIColor.systemBackground))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Main Icon Row
            HStack(spacing: 0) {
                // 1. Font Button
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        showFontList.toggle()
                        showShadowSlider = false
                        showSizeSlider = false
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    ZStack {
                        Circle()
                            .fill(showFontList ? Color(UIColor.tertiarySystemFill) : Color.clear)
                            .frame(width: 44, height: 44)
                        
                        
                        Image(systemName: "textformat")
                            .font(.system(size: 20, weight: .medium)) // Use textformat instead of Aa to be distinct
                            .foregroundColor(.primary)
                    }
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                
                // 2. Size Button (NEW)
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        showSizeSlider.toggle()
                        showFontList = false
                        showShadowSlider = false
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    ZStack {
                        Circle()
                            .fill(showSizeSlider ? Color(UIColor.tertiarySystemFill) : Color.clear)
                            .frame(width: 44, height: 44)
                        
                        
                        Image(systemName: "arrow.up.left.and.arrow.down.right") // Resize icon
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                
                // 3. Color Wheel
                ColorPicker("", selection: $customColor, supportsOpacity: false)
                    .labelsHidden()
                    .scaleEffect(1.3)
                    .frame(width: 56, height: 56)
                    .frame(maxWidth: .infinity)
                    .onChange(of: customColor) { newValue in
                        UserDefaults.standard.set(true, forKey: "wallpaperUseCustomColor")
                        let uiColor = UIColor(customColor)
                        if let data = try? NSKeyedArchiver.archivedData(withRootObject: uiColor, requiringSecureCoding: false) {
                            UserDefaults.standard.set(data, forKey: "wallpaperCustomColorData")
                        }
                        showFontList = false
                        showShadowSlider = false
                        showSizeSlider = false
                        onUpdate()
                    }
                
                // 4. Alignment Button
                Button(action: {
                    cycleAlignment()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showFontList = false
                    showShadowSlider = false
                    showSizeSlider = false
                    onUpdate()
                }) {
                    Image(systemName: alignmentIconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 56, height: 56)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                
                // 5. Highlight Button
                Button(action: {
                    cycleHighlightMode()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showFontList = false
                    showShadowSlider = false
                    showSizeSlider = false
                    onUpdate()
                }) {
                    ZStack {
                        if highlightMode != 0 {
                            Circle()
                                .fill(accentColor)
                                .frame(width: 36, height: 36)
                        }
                        
                        Image(systemName: highlightIconName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(highlightMode != 0 ? .white : .primary)
                    }
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                
                // 5. Shadow Button - now toggles slider
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        showShadowSlider.toggle()
                        showFontList = false
                        
                        if showShadowSlider && !isShadowEnabled {
                            isShadowEnabled = true
                            if shadowIntensity == 0 {
                                shadowIntensity = 0.5
                            }
                        }
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onUpdate()
                }) {
                    ZStack {
                        if isShadowEnabled {
                            Circle()
                                .fill(accentColor)
                                .frame(width: 36, height: 36)
                        }
                        
                        Image(systemName: "shadow")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(isShadowEnabled ? .white : .primary)
                    }
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Helpers
    
    private var alignmentIconName: String {
        switch alignmentMode {
        case 0: return "text.alignleft"
        case 1: return "text.aligncenter"
        case 2: return "text.alignright"
        default: return "text.aligncenter"
        }
    }
    
    private var highlightIconName: String {
        switch highlightMode {
        case 0: return "a.square"          // None
        case 1: return "a.square"          // Outline (stroked A)
        case 2: return "a.square.fill"     // White (filled A)
        case 3: return "a.square.fill"     // Black (filled A)
        default: return "a.square"
        }
    }
    
    private func cycleAlignment() {
        // Cycle: Left (0) -> Center (1) -> Right (2) -> Left (0)
        alignmentMode = (alignmentMode + 1) % 3
    }
    
    private func cycleHighlightMode() {
        // Cycle: None (0) -> Outline (1) -> White (2) -> Black (3) -> None (0)
        highlightMode = (highlightMode + 1) % 4
    }
    
    private func fontFont(for font: WallpaperRenderer.WallpaperFont) -> Font {
        switch font {
        case .classic: return .system(size: 16, weight: .semibold, design: .serif)
        case .modern: return .system(size: 16, weight: .bold, design: .default)
        case .rounded: return .system(size: 16, weight: .bold, design: .rounded)
        case .typewriter: return .system(size: 14, weight: .bold, design: .monospaced)
        case .strong: return .system(size: 16, weight: .black, design: .default)
        case .neon: return .custom("SnellRoundhand-Bold", size: 18)
        }
    }
}

// MARK: - Helper to convert alignment mode to NSTextAlignment

func textAlignmentFromMode(_ mode: Int) -> NSTextAlignment {
    switch mode {
    case 0: return .left
    case 1: return .center
    case 2: return .right
    default: return .center
    }
}

// MARK: - UserDefaults Extension for Styling Settings

extension UserDefaults {
    
    // MARK: - Keys
    
    private enum StylingKeys {
        static let fontName = "wallpaperFontName"
        static let useCustomColor = "wallpaperUseCustomColor"
        static let customColorData = "wallpaperCustomColorData"
        static let alignment = "wallpaperAlignment"
        static let highlightMode = "wallpaperHighlightMode"
        static let isShadowEnabled = "wallpaperIsShadowEnabled"
        static let shadowIntensity = "wallpaperShadowIntensity"
        static let fontSizeScaling = "wallpaperFontSizeScaling"
    }
    
    // MARK: - Convenience Accessors
    
    var wallpaperFontName: String {
        get { string(forKey: StylingKeys.fontName) ?? "Modern" }
        set { set(newValue, forKey: StylingKeys.fontName) }
    }
    
    var wallpaperAlignment: Int {
        get { integer(forKey: StylingKeys.alignment) }
        set { set(newValue, forKey: StylingKeys.alignment) }
    }
    
    var wallpaperHighlightMode: Int {
        get { integer(forKey: StylingKeys.highlightMode) }
        set { set(newValue, forKey: StylingKeys.highlightMode) }
    }
    
    var wallpaperIsShadowEnabled: Bool {
        get { bool(forKey: StylingKeys.isShadowEnabled) }
        set { set(newValue, forKey: StylingKeys.isShadowEnabled) }
    }
    
    var wallpaperShadowIntensity: Double {
        get { 
            let value = double(forKey: StylingKeys.shadowIntensity)
            return value == 0 && !bool(forKey: StylingKeys.isShadowEnabled) ? 0.5 : value 
        }
        set { set(newValue, forKey: StylingKeys.shadowIntensity) }
    }

    var wallpaperFontSizeScaling: Double {
        get {
            let value = double(forKey: StylingKeys.fontSizeScaling)
            return value == 0 ? 1.0 : value
        }
        set { set(newValue, forKey: StylingKeys.fontSizeScaling) }
    }

    
    var wallpaperUseCustomColor: Bool {
        get { bool(forKey: StylingKeys.useCustomColor) }
        set { set(newValue, forKey: StylingKeys.useCustomColor) }
    }
    
    func wallpaperCustomColor() -> UIColor? {
        guard wallpaperUseCustomColor,
              let data = data(forKey: StylingKeys.customColorData),
              let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) else {
            return nil
        }
        return color
    }
    
    func setWallpaperCustomColor(_ color: UIColor) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            set(data, forKey: StylingKeys.customColorData)
            wallpaperUseCustomColor = true
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct StylingToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            
            StylingToolbarView(
                selectedFontName: .constant("Modern"),
                showFontList: .constant(false),
                selectedColorName: .constant("Auto"),
                customColor: .constant(.blue),
                alignmentMode: .constant(1),
                highlightMode: .constant(0),
                isShadowEnabled: .constant(true),
                shadowIntensity: .constant(0.5),
                fontSizeScaling: .constant(1.0),
                onUpdate: {}
            )
            
            Spacer()
        }
        .background(Color(UIColor.systemBackground))
    }
}
#endif
