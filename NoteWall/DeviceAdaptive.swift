import SwiftUI
import UIKit

// MARK: - Device Size Categories

/// Categorizes devices by screen size for adaptive layout decisions
enum DeviceSizeCategory {
    /// iPhone SE, iPhone 8 and smaller (375×667 points and below)
    case compact
    /// Standard iPhones (iPhone 12, 13, 14 base models - ~390×844 points)
    case medium
    /// Pro Max models and larger devices (~428×926 points and above)
    case large
    
    /// Returns the device's size category based on screen dimensions
    static var current: DeviceSizeCategory {
        let screenHeight = UIScreen.main.bounds.height
        let screenWidth = UIScreen.main.bounds.width
        
        // Use the smaller dimension to determine category (works for both orientations)
        let minDimension = min(screenWidth, screenHeight)
        let maxDimension = max(screenWidth, screenHeight)
        
        // iPhone SE/8 has height of 667 points
        // iPhone 12 mini has height of 780 points
        // Standard iPhone 12/13/14 has height of 844 points
        // Pro Max models have height of 926+ points
        
        if maxDimension <= 700 {
            return .compact
        } else if maxDimension <= 860 {
            return .medium
        } else {
            return .large
        }
    }
}

// MARK: - Screen Dimensions Helper

/// Provides convenient access to screen dimensions
struct ScreenDimensions {
    static var width: CGFloat { UIScreen.main.bounds.width }
    static var height: CGFloat { UIScreen.main.bounds.height }
    
    /// Safe area insets for the current device
    static var safeAreaInsets: UIEdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return .zero
        }
        return window.safeAreaInsets
    }
    
    /// Available height after accounting for safe areas
    static var availableHeight: CGFloat {
        height - safeAreaInsets.top - safeAreaInsets.bottom
    }
    
    /// Whether the device has a notch/Dynamic Island
    static var hasNotch: Bool {
        safeAreaInsets.top > 24
    }
    
    /// Whether the device is an iPhone SE-class device
    static var isCompactDevice: Bool {
        DeviceSizeCategory.current == .compact
    }
    
    /// Whether the device has limited vertical space
    static var hasLimitedVerticalSpace: Bool {
        height < 750
    }
}

// MARK: - Adaptive Scaling

/// Provides scale factors and dimensions that adapt to device size
struct AdaptiveLayout {
    
    // MARK: - Scale Factors
    
    /// Overall scale factor (1.0 for medium, reduced for compact, increased for large)
    static var scaleFactor: CGFloat {
        switch DeviceSizeCategory.current {
        case .compact: return 0.85
        case .medium: return 1.0
        case .large: return 1.1
        }
    }
    
    /// Spacing scale factor - more aggressive reduction on compact devices
    static var spacingScale: CGFloat {
        switch DeviceSizeCategory.current {
        case .compact: return 0.65 // Aggressive space reduction
        case .medium: return 1.0
        case .large: return 1.15
        }
    }
    
    /// Font scale factor - subtle adjustment to maintain readability
    static var fontScale: CGFloat {
        switch DeviceSizeCategory.current {
        case .compact: return 0.9
        case .medium: return 1.0
        case .large: return 1.05
        }
    }
    
    // MARK: - Common Dimensions
    
    /// Standard horizontal padding
    static var horizontalPadding: CGFloat {
        switch DeviceSizeCategory.current {
        case .compact: return 16
        case .medium: return 24
        case .large: return 28
        }
    }
    
    /// Vertical spacing between major sections
    static var sectionSpacing: CGFloat {
        switch DeviceSizeCategory.current {
        case .compact: return 12
        case .medium: return 24
        case .large: return 32
        }
    }
    
    /// Button height
    static var buttonHeight: CGFloat {
        switch DeviceSizeCategory.current {
        case .compact: return 50
        case .medium: return 56
        case .large: return 60
        }
    }
    
    /// Standard corner radius
    static var cornerRadius: CGFloat {
        switch DeviceSizeCategory.current {
        case .compact: return 12
        case .medium: return 16
        case .large: return 18
        }
    }
    
    // MARK: - Video Dimensions
    
    /// Maximum video height as a proportion of screen height
    static var maxVideoHeightRatio: CGFloat {
        switch DeviceSizeCategory.current {
        case .compact: return 0.28 // Much smaller on compact devices
        case .medium: return 0.35
        case .large: return 0.40
        }
    }
    
    /// Maximum video height in points
    static var maxVideoHeight: CGFloat {
        ScreenDimensions.height * maxVideoHeightRatio
    }
    
    // MARK: - Image Dimensions
    
    /// Maximum image/mockup height ratio
    static var maxImageHeightRatio: CGFloat {
        switch DeviceSizeCategory.current {
        case .compact: return 0.40
        case .medium: return 0.50
        case .large: return 0.55
        }
    }
    
    /// Hero image height
    static var heroImageHeight: CGFloat {
        ScreenDimensions.height * maxImageHeightRatio
    }
    
    // MARK: - Bottom Safe Area
    
    /// Bottom padding for scrollable content to ensure visibility above sticky footer
    static var bottomScrollPadding: CGFloat {
        switch DeviceSizeCategory.current {
        case .compact: return 120 // Extra padding on compact for sticky button
        case .medium: return 100
        case .large: return 100
        }
    }
    
    /// Height reserved for sticky bottom button area
    static var stickyButtonAreaHeight: CGFloat {
        switch DeviceSizeCategory.current {
        case .compact: return 90
        case .medium: return 100
        case .large: return 110
        }
    }
}

// MARK: - Adaptive View Modifiers

extension View {
    /// Applies adaptive horizontal padding
    func adaptivePadding() -> some View {
        self.padding(.horizontal, AdaptiveLayout.horizontalPadding)
    }
    
    /// Applies adaptive spacing above and below
    func adaptiveVerticalSpacing(_ base: CGFloat = 24) -> some View {
        self.padding(.vertical, base * AdaptiveLayout.spacingScale)
    }
    
    /// Scales font size adaptively
    func adaptiveFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        self.font(.system(size: size * AdaptiveLayout.fontScale, weight: weight, design: design))
    }
    
    /// Applies bottom padding for scroll content above sticky footer
    func bottomScrollSafeArea() -> some View {
        self.padding(.bottom, AdaptiveLayout.bottomScrollPadding)
    }
}

// MARK: - Adaptive Container View

/// A scroll view container that ensures content is always scrollable and adds proper bottom padding
struct AdaptiveScrollContainer<Content: View>: View {
    let showsIndicators: Bool
    @ViewBuilder let content: Content
    
    init(showsIndicators: Bool = false, @ViewBuilder content: () -> Content) {
        self.showsIndicators = showsIndicators
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: showsIndicators) {
                content
                    .frame(minHeight: proxy.size.height, alignment: .top)
            }
        }
    }
}

// MARK: - Sticky Button Container

/// A container that places content in a scroll view with a sticky button at the bottom
struct StickyButtonScrollContainer<Content: View, ButtonContent: View>: View {
    let showsIndicators: Bool
    @ViewBuilder let content: Content
    @ViewBuilder let stickyButton: ButtonContent
    
    init(
        showsIndicators: Bool = false,
        @ViewBuilder content: () -> Content,
        @ViewBuilder stickyButton: () -> ButtonContent
    ) {
        self.showsIndicators = showsIndicators
        self.content = content()
        self.stickyButton = stickyButton()
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Scrollable content
            ScrollView(.vertical, showsIndicators: showsIndicators) {
                content
                    .padding(.bottom, AdaptiveLayout.stickyButtonAreaHeight + 20) // Extra padding for sticky button
            }
            
            // Sticky button with gradient background
            VStack(spacing: 0) {
                // Gradient fade to indicate more content above
                LinearGradient(
                    colors: [
                        Color(.systemBackground).opacity(0),
                        Color(.systemBackground).opacity(0.9),
                        Color(.systemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 30)
                
                // Button container
                VStack {
                    stickyButton
                }
                .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                .padding(.bottom, max(ScreenDimensions.safeAreaInsets.bottom, 16))
                .background(Color(.systemBackground))
            }
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct DeviceAdaptive_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Device Category: \(String(describing: DeviceSizeCategory.current))")
            Text("Screen: \(Int(ScreenDimensions.width))×\(Int(ScreenDimensions.height))")
            Text("Scale Factor: \(AdaptiveLayout.scaleFactor, specifier: "%.2f")")
            Text("Is Compact: \(ScreenDimensions.isCompactDevice ? "Yes" : "No")")
            Text("Max Video Height: \(Int(AdaptiveLayout.maxVideoHeight))")
        }
        .padding()
    }
}
#endif
