import Foundation
import SwiftUI
import UIKit
import WidgetKit

struct Note: Identifiable, Codable {
    let id: UUID
    var text: String
    var reference: String? // Added reference field
    var isCompleted: Bool

    init(id: UUID = UUID(), text: String, reference: String? = nil, isCompleted: Bool = false) {
        self.id = id
        self.text = text
        self.reference = reference
        self.isCompleted = isCompleted
    }
}

extension Notification.Name {
    static let requestWallpaperUpdate = Notification.Name("requestWallpaperUpdate")
    static let wallpaperGenerationFinished = Notification.Name("wallpaperGenerationFinished")
    static let onboardingReplayRequested = Notification.Name("onboardingReplayRequested")
    static let shortcutWallpaperApplied = Notification.Name("shortcutWallpaperApplied")
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
    static let showGlobalLoadingOverlay = Notification.Name("showGlobalLoadingOverlay")
    static let navigateToHomeTab = Notification.Name("navigateToHomeTab")
    static let showDeleteNotesLoadingOverlay = Notification.Name("showDeleteNotesLoadingOverlay")
    static let dismissPaywallAfterPromoCode = Notification.Name("dismissPaywallAfterPromoCode")
}

struct WallpaperUpdateRequest {
    let skipDeletionPrompt: Bool
    let trackForPaywall: Bool
    let showLoadingOverlay: Bool
    
    init(skipDeletionPrompt: Bool = false, trackForPaywall: Bool = true, showLoadingOverlay: Bool = false) {
        self.skipDeletionPrompt = skipDeletionPrompt
        self.trackForPaywall = trackForPaywall
        self.showLoadingOverlay = showLoadingOverlay
    }
}

enum LockScreenBackgroundOption: String, CaseIterable, Identifiable {
    case black
    case gray
    case none = ""

    static let `default` = LockScreenBackgroundOption.none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .black: return "White"
        case .gray: return "Gray"
        case .none: return "None"
        }
    }

    var color: Color {
        switch self {
        case .black:
            return Color(red: 255 / 255, green: 255 / 255, blue: 255 / 255)
        case .gray:
            return Color(red: 40 / 255, green: 40 / 255, blue: 40 / 255)
        case .none:
            return .clear
        }
    }

    var uiColor: UIColor {
        switch self {
        case .black:
            return UIColor(red: 255 / 255, green: 255 / 255, blue: 255 / 255, alpha: 1)
        case .gray:
            return UIColor(red: 40 / 255, green: 40 / 255, blue: 40 / 255, alpha: 1)
        case .none:
            return .clear
        }
    }
}

enum LockScreenBackgroundMode: String, Identifiable {
    case presetBlack
    case presetGray
    case photo
    case notSelected = ""

    static let `default` = LockScreenBackgroundMode.notSelected

    var id: String { rawValue }

    var presetOption: LockScreenBackgroundOption? {
        switch self {
        case .presetBlack: return .black
        case .presetGray: return .gray
        case .photo: return nil
        case .notSelected: return nil
        }
    }

    static func preset(for option: LockScreenBackgroundOption) -> LockScreenBackgroundMode {
        switch option {
        case .black: return .presetBlack
        case .gray: return .presetGray
        case .none: return .notSelected
        }
    }
}

enum PresetOption: String, CaseIterable, Identifiable {
    case oceanBlue
    case sunsetOrange
    case forestGreen
    case lavenderPurple
    case roseGold
    case midnightBlue
    case peachCream
    case mintGreen
    case coralPink
    case skyBlue
    case warmAutumn
    case coolWinter
    case tropicalParadise
    case desertSand
    case cherryBlossom
    case deepOcean
    case goldenHour
    case arcticBreeze
    case berryBliss
    case serenityBlue
    case faithWall

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oceanBlue: return "Ocean Blue"
        case .sunsetOrange: return "Sunset Orange"
        case .forestGreen: return "Forest Green"
        case .lavenderPurple: return "Lavender Purple"
        case .roseGold: return "Rose Gold"
        case .midnightBlue: return "Midnight Blue"
        case .peachCream: return "Peach Cream"
        case .mintGreen: return "Mint Green"
        case .coralPink: return "Coral Pink"
        case .skyBlue: return "Sky Blue"
        case .warmAutumn: return "Warm Autumn"
        case .coolWinter: return "Cool Winter"
        case .tropicalParadise: return "Tropical Paradise"
        case .desertSand: return "Desert Sand"
        case .cherryBlossom: return "Cherry Blossom"
        case .deepOcean: return "Deep Ocean"
        case .goldenHour: return "Golden Hour"
        case .arcticBreeze: return "Arctic Breeze"
        case .berryBliss: return "Berry Bliss"
        case .serenityBlue: return "Serenity Blue"
        case .faithWall: return "FaithWall Collection"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .oceanBlue: return [Color(red: 0.1, green: 0.5, blue: 0.8), Color(red: 0.0, green: 0.3, blue: 0.6)]
        case .sunsetOrange: return [Color(red: 1.0, green: 0.6, blue: 0.3), Color(red: 0.9, green: 0.3, blue: 0.4)]
        case .forestGreen: return [Color(red: 0.2, green: 0.5, blue: 0.3), Color(red: 0.1, green: 0.3, blue: 0.2)]
        case .lavenderPurple: return [Color(red: 0.7, green: 0.6, blue: 0.9), Color(red: 0.5, green: 0.4, blue: 0.7)]
        case .roseGold: return [Color(red: 0.9, green: 0.7, blue: 0.7), Color(red: 0.8, green: 0.5, blue: 0.5)]
        case .midnightBlue: return [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.0, green: 0.0, blue: 0.2)]
        case .peachCream: return [Color(red: 1.0, green: 0.8, blue: 0.7), Color(red: 0.95, green: 0.7, blue: 0.6)]
        case .mintGreen: return [Color(red: 0.6, green: 0.9, blue: 0.8), Color(red: 0.4, green: 0.7, blue: 0.6)]
        case .coralPink: return [Color(red: 1.0, green: 0.5, blue: 0.5), Color(red: 0.9, green: 0.4, blue: 0.4)]
        case .skyBlue: return [Color(red: 0.5, green: 0.8, blue: 1.0), Color(red: 0.3, green: 0.6, blue: 0.9)]
        case .warmAutumn: return [Color(red: 0.8, green: 0.5, blue: 0.3), Color(red: 0.6, green: 0.3, blue: 0.2)]
        case .coolWinter: return [Color(red: 0.7, green: 0.8, blue: 0.9), Color(red: 0.5, green: 0.6, blue: 0.8)]
        case .tropicalParadise: return [Color(red: 0.0, green: 0.8, blue: 0.7), Color(red: 0.0, green: 0.6, blue: 0.8)]
        case .desertSand: return [Color(red: 0.9, green: 0.8, blue: 0.6), Color(red: 0.8, green: 0.6, blue: 0.4)]
        case .cherryBlossom: return [Color(red: 1.0, green: 0.7, blue: 0.8), Color(red: 0.9, green: 0.5, blue: 0.6)]
        case .deepOcean: return [Color(red: 0.0, green: 0.3, blue: 0.5), Color(red: 0.0, green: 0.1, blue: 0.3)]
        case .goldenHour: return [Color(red: 1.0, green: 0.8, blue: 0.4), Color(red: 0.9, green: 0.6, blue: 0.3)]
        case .arcticBreeze: return [Color(red: 0.8, green: 0.9, blue: 1.0), Color(red: 0.6, green: 0.8, blue: 0.95)]
        case .berryBliss: return [Color(red: 0.7, green: 0.2, blue: 0.5), Color(red: 0.5, green: 0.1, blue: 0.4)]
        case .serenityBlue: return [Color(red: 0.6, green: 0.7, blue: 0.9), Color(red: 0.4, green: 0.5, blue: 0.7)]
        case .faithWall: return [Color(red: 0.95, green: 0.4, blue: 0.2), Color(red: 1.0, green: 0.7, blue: 0.4)]
        }
    }

    var previewColor: Color {
        gradientColors.first ?? .clear
    }

    var textColor: Color {
        .white
    }

    var lockScreenOption: LockScreenBackgroundOption {
        .black // Deprecated, keeping for compatibility
    }

    func generateGradientImage() -> UIImage {
        let size = CGSize(width: 1290, height: 2796)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let colors = gradientColors.map { $0.cgColor }
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0])!
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: size.width / 2, y: 0),
                end: CGPoint(x: size.width / 2, y: size.height),
                options: []
            )
        }
    }
}

enum LegalDocumentType {
    case termsOfService
    case privacyPolicy
    case termsAndPrivacy
    
    var title: String {
        switch self {
        case .termsOfService:
            return "Terms of Service"
        case .privacyPolicy:
            return "Privacy Policy"
        case .termsAndPrivacy:
            return "Terms & Privacy"
        }
    }
}

// MARK: - Widget Data Sync

struct WidgetDataSync {
    static let appGroupIdentifier = "group.faithwall.shared"
    static let savedNotesKey = "savedNotes"
    
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    /// Syncs notes data to the shared App Group for widget access
    static func syncNotesToWidget(_ notesData: Data) {
        guard let defaults = sharedDefaults else {
            #if DEBUG
            print("WidgetDataSync: Failed to access App Group UserDefaults")
            #endif
            return
        }
        
        defaults.set(notesData, forKey: savedNotesKey)
        
        // Request widget refresh
        WidgetCenter.shared.reloadAllTimelines()
        
        #if DEBUG
        print("WidgetDataSync: Notes synced to widget")
        #endif
    }
    
    /// Syncs notes array directly to the shared App Group
    static func syncNotes(_ notes: [Note]) {
        do {
            let data = try JSONEncoder().encode(notes)
            syncNotesToWidget(data)
        } catch {
            #if DEBUG
            print("WidgetDataSync: Failed to encode notes: \(error)")
            #endif
        }
    }
}

// MARK: - Design System

/// Centralized design system for FaithWall to ensure consistency
struct DS {
    
    // MARK: - Spacing
    struct Spacing {
        /// 4pt
        static let xxs: CGFloat = 4
        /// 8pt
        static let xs: CGFloat = 8
        /// 12pt
        static let s: CGFloat = 12
        /// 16pt
        static let m: CGFloat = 16
        /// 20pt
        static let l: CGFloat = 20
        /// 24pt
        static let xl: CGFloat = 24
        /// 32pt
        static let xxl: CGFloat = 32
        /// 40pt
        static let section: CGFloat = 40
        /// 48pt
        static let largeSection: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct Radius {
        /// 8pt
        static let small: CGFloat = 8
        /// 12pt
        static let medium: CGFloat = 12
        /// 16pt
        static let large: CGFloat = 16
        /// 24pt
        static let extraLarge: CGFloat = 24
        /// 30pt (Buttons)
        static let button: CGFloat = 30
    }
    
    // MARK: - Colors
    struct Colors {
        // Primary Brand
        static let accent = Color("AppAccent")
        
        // Backgrounds
        static let background = Color.white
        static let backgroundSecondary = Color(red: 0.97, green: 0.97, blue: 0.98)
        static let card = Color(red: 0.99, green: 0.98, blue: 0.97)
        
        // Text
        static let textPrimary = Color(red: 0.15, green: 0.15, blue: 0.18)
        static let textSecondary = Color(red: 0.45, green: 0.45, blue: 0.50)
        static let textTertiary = Color(red: 0.60, green: 0.60, blue: 0.65)
        
        // UI Elements
        static let divider = Color.gray.opacity(0.15)
        static let shadow = Color.black.opacity(0.05)
    }
    
    // MARK: - Typography
    struct Fonts {
        static func titleLarge() -> Font { .system(size: 34, weight: .bold) }
        static func titleMedium() -> Font { .system(size: 28, weight: .bold) }
        static func titleSmall() -> Font { .system(size: 22, weight: .semibold) }
        
        static func bodyLarge() -> Font { .system(size: 17, weight: .regular) }
        static func bodyMedium() -> Font { .system(size: 15, weight: .regular) }
        static func bodySmall() -> Font { .system(size: 13, weight: .regular) }
        
        static func button() -> Font { .system(size: 17, weight: .semibold) }
    }
    
    // MARK: - Components
    struct Components {
        /// Standard primary button style
        struct PrimaryButtonStyle: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .font(DS.Fonts.button())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(DS.Colors.accent)
                    .cornerRadius(DS.Radius.button)
                    .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                    .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            }
        }
        
        /// Standard secondary button style (outline or light bg)
        struct SecondaryButtonStyle: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .font(DS.Fonts.button())
                    .foregroundColor(DS.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(DS.Colors.backgroundSecondary)
                    .cornerRadius(DS.Radius.button)
                    .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                    .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            }
        }
    }
}

// MARK: - View Modifiers
extension View {
    /// Applies standard horizontal padding (24pt)
    func standardPadding() -> some View {
        self.padding(.horizontal, DS.Spacing.xl)
    }
    
    /// Applies standard card styling (background, radius, shadow)
    func cardStyle() -> some View {
        self
            .background(DS.Colors.card)
            .cornerRadius(DS.Radius.large)
            .shadow(color: DS.Colors.shadow, radius: 10, x: 0, y: 4)
    }
}

// MARK: - FaithWall Theme Colors
// A warm, light theme with orange/coral accent colors for a Christian app

extension Color {
    // MARK: - Primary Accent Color (Warm Orange/Coral)
    // static let appAccent = DS.Colors.accent // Commented out to avoid redeclaration with auto-generated asset symbol

    
    // MARK: - Background Colors (Light Theme)
    /// Primary background - pure white
    static let appBackground = DS.Colors.background
    
    /// Secondary background - very light gray
    static let appBackgroundSecondary = DS.Colors.backgroundSecondary
    
    /// Tertiary background - slightly darker light gray for cards
    static let appBackgroundTertiary = Color(red: 0.94, green: 0.94, blue: 0.96)
    
    /// Card background with subtle warmth
    static let appCardBackground = DS.Colors.card
    
    // MARK: - Text Colors
    /// Primary text - dark gray (not pure black for softer look)
    static let appTextPrimary = DS.Colors.textPrimary
    
    /// Secondary text - medium gray
    static let appTextSecondary = DS.Colors.textSecondary
    
    /// Tertiary text - lighter gray
    static let appTextTertiary = Color(red: 0.65, green: 0.65, blue: 0.68)
    
    // MARK: - UI Element Colors
    /// Subtle divider color
    static let appDivider = Color(red: 0.88, green: 0.88, blue: 0.90)
    
    /// Light overlay for hover/pressed states
    static let appOverlay = Color.black.opacity(0.04)
    
    /// Border color for cards and inputs
    static let appBorder = Color(red: 0.90, green: 0.90, blue: 0.92)
    
    // MARK: - Gradient Backgrounds
    /// Light gradient for onboarding and full-screen views
    static var appLightGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.98, blue: 0.97),
                Color.white
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Warm subtle gradient with hint of orange
    static var appWarmGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.98, blue: 0.96),
                Color(red: 0.99, green: 0.97, blue: 0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Accent gradient for buttons and highlights
    static var appAccentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.appAccent,
                Color.appAccent.opacity(0.85)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - UIColor Extensions for UIKit Components

extension UIColor {
    /// Primary background - white
    static let appBackground = UIColor.white
    
    /// Secondary background - very light gray
    static let appBackgroundSecondary = UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1)
    
    /// Primary text color
    static let appTextPrimary = UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)
    
    /// Secondary text color
    static let appTextSecondary = UIColor(red: 0.45, green: 0.45, blue: 0.50, alpha: 1)
    
    /// App accent color (warm orange/coral)
    static let appAccentColor = UIColor(red: 0.91, green: 0.40, blue: 0.22, alpha: 1)
}

// MARK: - View Modifiers for Consistent Theming

struct LightThemeBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.appBackground)
            .preferredColorScheme(.light)
    }
}

struct AppGradientBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.99, green: 0.98, blue: 0.97),
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .preferredColorScheme(.light)
    }
}

extension View {
    /// Apply the light theme background
    func lightThemeBackground() -> some View {
        modifier(LightThemeBackground())
    }
    
    /// Apply the app's gradient background for full-screen views
    func appGradientBackground() -> some View {
        modifier(AppGradientBackground())
    }
}

// MARK: - Theme Configuration

struct FaithWallTheme {
    /// Force light mode for the entire app
    static func configureLightMode() {
        // Delay to ensure UIApplication is fully ready on iOS 26+
        // This prevents assertion failures during early app startup
        DispatchQueue.main.async {
            guard Thread.isMainThread else { return }
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = .light
                }
            }
        }
    }
    
    /// Apply theme to navigation bar
    static func configureNavigationBarAppearance() {
        // Use default iOS navigation bar behavior (like NoteWall) for proper large title display
        // Only customize the tint color for back buttons and bar button items
        UINavigationBar.appearance().tintColor = .appAccentColor
    }
    
    /// Apply theme to tab bar
    static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        UITabBar.appearance().tintColor = .appAccentColor
    }
}

// MARK: - Shared Button Styles

/// A button style that scales down slightly when pressed
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
