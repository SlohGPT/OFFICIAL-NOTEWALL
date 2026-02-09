import UIKit
import SwiftUI

struct WallpaperRenderer {
    // MARK: - Adaptive Text Sizing Configuration
    
    /// Maximum font size - for short verses (1-2 lines)
    /// Sized to create readable column-style text
    private static let maxFontSize: CGFloat = 72
    
    /// Minimum font size - smallest we'll go for readability
    private static let minFontSize: CGFloat = 26
    
    /// Canvas dimensions (base reference) - High resolution for crisp text
    private static let canvasWidth: CGFloat = 1290
    private static let screenHeight: CGFloat = 2796
    
    // MARK: - Proportional Positioning (Universal iPhone Support)
    
    /// PROPORTIONAL POSITIONING (percentage-based)
    /// These percentages ensure consistent placement across all iPhone sizes
    
    /// Top padding WITHOUT widgets (clock area)
    /// Clock typically ends at ~25-28% of screen height on all iPhones
    /// Start notes at 30% - right below the clock
    private static var topPaddingNoWidgets: CGFloat { screenHeight * 0.30 }
    
    /// Top padding WITH widgets (widget area)
    /// Widgets end at ~35-37% of screen height
    /// Start notes at 38% to give clearance below widgets
    private static var topPaddingWithWidgets: CGFloat { screenHeight * 0.38 }
    
    /// Bottom safe area (flashlight/camera icons)
    /// These icons occupy ~18-20% of bottom screen
    /// Add 1% buffer → reserve 21% from bottom
    private static var bottomSafeArea: CGFloat { screenHeight * 0.21 }
    
    /// Horizontal padding for centered column-style text
    /// Reduced to 12% to match Preview (10%) and allow larger text
    private static var leftPadding: CGFloat { canvasWidth * 0.12 }
    private static var rightPadding: CGFloat { canvasWidth * 0.12 }
    
    /// Text max width - centered column style
    private static var textMaxWidth: CGFloat { canvasWidth - leftPadding - rightPadding }
    
    // MARK: - Configuration Models
    
    enum WallpaperFont: String, CaseIterable, Identifiable {
        case classic = "Classic"    // Serif (New York)
        case modern = "Modern"      // Sans-Serif (System)
        case rounded = "Rounded"    // Rounded
        case typewriter = "Mono"    // Monospace
        case strong = "Strong"      // Heavy / Impact-style
        case neon = "Neon"          // Cursive / Script
        
        var id: String { rawValue }
        
        func font(size: CGFloat, weight: UIFont.Weight) -> UIFont {
            switch self {
            case .classic:
                if let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.serif) {
                    return UIFont(descriptor: descriptor, size: size)
                }
                return UIFont(name: "Georgia-Bold", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
                
            case .modern:
                return UIFont.systemFont(ofSize: size, weight: weight)
                
            case .rounded:
                if let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.rounded) {
                    return UIFont(descriptor: descriptor, size: size)
                }
                return UIFont.systemFont(ofSize: size, weight: weight)
                
            case .typewriter:
                if let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.monospaced) {
                    return UIFont(descriptor: descriptor, size: size)
                }
                return UIFont.monospacedSystemFont(ofSize: size, weight: weight)
                
            case .strong:
                // Instagram's "Strong" is usually a very heavy, condensed sans-serif.
                // We'll use System Heavy/Black.
                return UIFont.systemFont(ofSize: size, weight: .black)
                
            case .neon:
                // Instagram's "Neon" is a cursive/script font.
                // "SnellRoundhand-Bold" is a good built-in candidate.
                // Adjust size slightly as script fonts can appear smaller.
                return UIFont(name: "SnellRoundhand-Bold", size: size * 1.1) ?? UIFont.italicSystemFont(ofSize: size)
            }
        }
    }
    
    // MARK: - Highlight Configuration
    
    enum WallpaperTextHighlight: Int, CaseIterable, Identifiable {
        case none = 0
        case outline = 1
        case whiteBox = 2
        case blackBox = 3
        
        var id: Int { rawValue }
    }
    
    // MARK: - Device-Aware Adjustments (Continued)
    
    /// Font weight for notes - semibold for serif fonts (matches mockup)
    private static let fontWeight: UIFont.Weight = .semibold
    
    /// Helper to load the correct font based on selection
    private static func loadFont(_ fontType: WallpaperFont, size: CGFloat, weight: UIFont.Weight = .semibold) -> UIFont {
        return fontType.font(size: size, weight: weight)
    }
    
    // MARK: - Device-Aware Adjustments
    
    /// DEVICE-SPECIFIC FINE-TUNING
    /// Detect if device has smaller screen and apply minor adjustments
    /// This handles edge cases where proportions might still be slightly off
    private static func getDeviceAdjustedTopPadding(basePadding: CGFloat) -> CGFloat {
        // Get actual device screen height with safety check
        let deviceScreenHeight: CGFloat
        if UIScreen.main.nativeBounds.height > 0 {
            deviceScreenHeight = UIScreen.main.nativeBounds.height
        } else {
            // Fallback: use base padding if screen detection fails
            return basePadding
        }
        
        // Apply minor adjustments for specific device categories
        switch deviceScreenHeight {
        case 0..<1500:  // iPhone SE, 8, 7, 6 (4.7" and smaller)
            // Slightly higher percentage for smaller devices
            return basePadding * 1.05  // +5%
            
        case 1500..<2400:  // iPhone 12 mini, 13 mini (5.4")
            return basePadding * 1.02  // +2%
            
        case 2400..<2900:  // iPhone 12, 13, 14 (6.1")
            return basePadding  // Base calculation (perfect)
            
        default:  // iPhone Pro Max, Plus models (6.7"+)
            return basePadding * 0.98  // -2% (more screen space)
        }
    }
    
    /// Get top padding based on widget setting with device-aware adjustments
    static func topPadding(hasWidgets: Bool) -> CGFloat {
        let basePadding = hasWidgets ? topPaddingWithWidgets : topPaddingNoWidgets
        return getDeviceAdjustedTopPadding(basePadding: basePadding)
    }
    
    /// Get available height based on widget setting
    static func availableHeight(hasWidgets: Bool) -> CGFloat {
        return screenHeight - topPadding(hasWidgets: hasWidgets) - bottomSafeArea
    }
    
    // MARK: - Debug Helper
    
    /// Debug function to help test on different devices
    private static func logPositioningInfo(hasLockScreenWidgets: Bool) {
        let deviceHeight = UIScreen.main.nativeBounds.height
        let deviceWidth = UIScreen.main.nativeBounds.width
        let baseTopPadding = hasLockScreenWidgets ? topPaddingWithWidgets : topPaddingNoWidgets
        let adjustedTopPadding = topPadding(hasWidgets: hasLockScreenWidgets)
        let availableHeight = screenHeight - adjustedTopPadding - bottomSafeArea
        
        print("━━━ FaithWall Positioning Debug ━━━")
        print("Device Screen: \(deviceWidth)×\(deviceHeight)px")
        print("Canvas Size: \(canvasWidth)×\(screenHeight)px")
        print("Base Top Padding: \(baseTopPadding)px (\(Int((baseTopPadding/screenHeight)*100))%)")
        print("Adjusted Top Padding: \(adjustedTopPadding)px (\(Int((adjustedTopPadding/screenHeight)*100))%)")
        print("Bottom Safe: \(bottomSafeArea)px (\(Int((bottomSafeArea/screenHeight)*100))%)")
        print("Available Height: \(availableHeight)px")
        print("Left Padding: \(leftPadding)px, Right Padding: \(rightPadding)px")
        print("Has Widgets: \(hasLockScreenWidgets)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    static func generateWallpaper(
        from notes: [Note],
        backgroundColor: UIColor,
        backgroundImage: UIImage? = nil,
        hasLockScreenWidgets: Bool = true,
        customFontName: String? = nil,
        customTextColor: UIColor? = nil,
        highlightMode: WallpaperTextHighlight = .none,
        isShadowEnabled: Bool = false,
        shadowIntensity: Double = 0.5,
        textAlignment: NSTextAlignment = .center
    ) -> UIImage {
        print("🎨 WallpaperRenderer: Generating wallpaper")
        print("   Total notes: \(notes.count)")
        print("   Background image: \(backgroundImage != nil ? "YES" : "NO")")
        print("   Has widgets: \(hasLockScreenWidgets)")
        
        // Debug positioning info
        #if DEBUG
        logPositioningInfo(hasLockScreenWidgets: hasLockScreenWidgets)
        #endif
        
        // iPhone wallpaper dimensions
        let width: CGFloat = 1290
        let height: CGFloat = 2796
        
        // Get layout values based on widget setting
        let currentTopPadding = topPadding(hasWidgets: hasLockScreenWidgets)
        let currentAvailableHeight = availableHeight(hasWidgets: hasLockScreenWidgets)

        // CRITICAL: Configure renderer with explicit sRGB color space
        // This ensures colors are preserved when iOS Shortcuts applies the wallpaper
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0  // Use actual pixel dimensions
        format.opaque = true  // Wallpaper has no transparency
        if #available(iOS 12.0, *) {
            format.preferredRange = .extended  // Support wide color gamut
        }
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)

        return renderer.image { context in
            let canvasRect = CGRect(x: 0, y: 0, width: width, height: height)

            backgroundColor.setFill()
            context.fill(canvasRect)

            if let image = backgroundImage {
                drawBackground(image: image, in: canvasRect, on: context.cgContext)
                print("   ✅ Drew background image")
            }

            let activeNotes = notes.filter { !$0.isCompleted }
            let completedNotes = notes.filter { $0.isCompleted }
            print("   Active notes: \(activeNotes.count)")
            print("   Completed notes: \(completedNotes.count)")

            guard !notes.isEmpty else {
                print("   ⚠️ NO NOTES TO SHOW - Wallpaper will be blank")
                return
            }
            
            
            // Resolve Font
            let selectedFont: WallpaperFont
            if let fontName = customFontName, let font = WallpaperFont(rawValue: fontName) {
                selectedFont = font
            } else {
                selectedFont = .classic // Default
            }

            // Calculate the optimal font size for all notes
            let optimalFontSize = calculateOptimalFontSize(for: notes, availableHeight: currentAvailableHeight, fontType: selectedFont)
            print("   📏 Optimal font size: \(optimalFontSize)pt (Font: \(selectedFont.rawValue))")
            
            // Get the notes that fit at this font size (should be all of them unless we hit min font)
            let notesToShow = getNotesToShowAtFontSize(notes, fontSize: optimalFontSize, availableHeight: currentAvailableHeight, fontType: selectedFont)
            print("   Notes to show: \(notesToShow.count)")
            
            guard !notesToShow.isEmpty else {
                print("   ⚠️ NO NOTES FIT - Wallpaper will be blank")
                return
            }

            // Determine final text color (Custom or Auto)
            let finalTextColor = customTextColor ?? textColorForBackground(
                backgroundColor: backgroundColor,
                backgroundImage: backgroundImage
            )
            
            print("   🎨 Text color: \(finalTextColor)")

            // Build attributed string with adaptive sizing
            // Pass whether there's a background image for shadow rendering
            let attributedString = buildAttributedString(
                for: notesToShow,
                fontSize: optimalFontSize,
                textColor: finalTextColor,
                hasBackgroundImage: backgroundImage != nil,
                fontType: selectedFont,
                highlightMode: highlightMode,
                isShadowEnabled: isShadowEnabled,
                shadowIntensity: shadowIntensity,
                textAlignment: textAlignment
            )
            
            print("   📝 Combined text length: \(attributedString.length) chars")

            let textSize = attributedString.boundingRect(
                with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )

            // Position text based on widget setting - use leftPadding for x position
            let textRect = CGRect(
                x: leftPadding,
                y: currentTopPadding,
                width: textMaxWidth,
                height: textSize.height
            )
            
            // Draw attribute text
            // If highlight mode is Box, we draw the background MANUALLY here as a rounded rect
            // instead of using NSAttributedString.backgroundColor (which is line-by-line)
            if highlightMode == .whiteBox || highlightMode == .blackBox {
                let padding: CGFloat = 32 // Generous padding for card look
                let backgroundRect = textRect.insetBy(dx: -padding, dy: -padding)
                
                let boxColor: UIColor = (highlightMode == .whiteBox) 
                    ? UIColor.white.withAlphaComponent(0.85) 
                    : UIColor.black.withAlphaComponent(0.85)
                
                let path = UIBezierPath(roundedRect: backgroundRect, cornerRadius: 16)
                boxColor.setFill()
                path.fill()
                
                // Add shadow to the box itself if enabled
                if isShadowEnabled {
                    context.cgContext.setShadow(
                        offset: CGSize(width: 2, height: 4), 
                        blur: 10, 
                        color: UIColor.black.withAlphaComponent(0.4).cgColor
                    )
                    // Redraw to apply shadow (clipped to path to avoid doubling opacity on fill)
                    context.cgContext.addPath(path.cgPath)
                    context.cgContext.fillPath()
        // Reset shadow for text
                    context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
                }
            }
            
            print("   📍 Text rect: x=\(leftPadding), y=\(currentTopPadding), w=\(textMaxWidth), h=\(textSize.height)")
            
            // OUTLINE MODE: Use multi-pass drawing for clean, smooth outlines
            // This avoids the artifacts that stroke attributes cause on curved letters
            if highlightMode == .outline {
                // Build outline version (same text, but with outline color)
                let outlineString = buildOutlineString(
                    for: notesToShow,
                    fontSize: optimalFontSize,
                    outlineColor: .black,
                    fontType: selectedFont,
                    textAlignment: textAlignment
                )
                
                // Draw outline passes - 8 directions for smooth outline
                // Offset proportional to font size for consistent appearance
                let outlineWidth: CGFloat = max(3.0, optimalFontSize * 0.045)
                let offsets: [(CGFloat, CGFloat)] = [
                    (-outlineWidth, 0),           // Left
                    (outlineWidth, 0),            // Right
                    (0, -outlineWidth),           // Top
                    (0, outlineWidth),            // Bottom
                    (-outlineWidth * 0.7, -outlineWidth * 0.7),  // Top-left (diagonal)
                    (outlineWidth * 0.7, -outlineWidth * 0.7),   // Top-right
                    (-outlineWidth * 0.7, outlineWidth * 0.7),   // Bottom-left
                    (outlineWidth * 0.7, outlineWidth * 0.7)     // Bottom-right
                ]
                
                for (dx, dy) in offsets {
                    let offsetRect = textRect.offsetBy(dx: dx, dy: dy)
                    outlineString.draw(in: offsetRect)
                }
                
                // Now draw the main text on top
                attributedString.draw(in: textRect)
                print("   ✅ Drew text with clean multi-pass outline")
            } else {
                // Standard drawing for non-outline modes
                attributedString.draw(in: textRect)
                print("   ✅ Drew text on wallpaper (with strikethrough for completed notes)")
            }
        }
    }
    
    // MARK: - Adaptive Font Size Calculation
    
    /// Calculates the optimal font size to fit all notes in the available space
    /// - Parameters:
    ///   - notes: Array of notes to fit
    ///   - availableHeight: The height available for notes (depends on widget setting)
    /// - Returns: The largest font size that fits all notes, clamped to min/max bounds
    private static func calculateOptimalFontSize(for notes: [Note], availableHeight: CGFloat, fontType: WallpaperFont) -> CGFloat {
        guard !notes.isEmpty else { return maxFontSize }
        
        // First check: do all notes fit at max font size?
        if doesAllNotesFit(notes, atFontSize: maxFontSize, availableHeight: availableHeight, fontType: fontType) {
            print("   ✅ All notes fit at max font size (\(maxFontSize)pt)")
            return maxFontSize
        }
        
        // Binary search to find the largest font size that fits all notes
        var low = minFontSize
        var high = maxFontSize
        var bestFit = minFontSize
        
        while low <= high {
            let mid = (low + high) / 2
            
            if doesAllNotesFit(notes, atFontSize: mid, availableHeight: availableHeight, fontType: fontType) {
                bestFit = mid
                low = mid + 1 // Try larger
            } else {
                high = mid - 1 // Try smaller
            }
        }
        
        print("   🔍 Binary search found optimal size: \(bestFit)pt")
        return bestFit
    }
    
    /// Checks if all notes fit in the available space at the given font size
    private static func doesAllNotesFit(_ notes: [Note], atFontSize fontSize: CGFloat, availableHeight: CGFloat, fontType: WallpaperFont) -> Bool {
        let lineSpacing = lineSpacingForFontSize(fontSize)
        let separatorHeight = separatorHeightForFontSize(fontSize)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: fontType.font(size: fontSize, weight: fontWeight),
            .paragraphStyle: paragraphStyle
        ]
        
        var totalHeight: CGFloat = 0
        
        for (index, note) in notes.enumerated() {
            let attributedString = NSAttributedString(string: note.text, attributes: attributes)
            let textSize = attributedString.boundingRect(
                with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            
            let noteHeight = textSize.height + (index > 0 ? separatorHeight : 0)
            totalHeight += noteHeight
            
            if totalHeight > availableHeight {
                return false
            }
        }
        
        return true
    }
    
    /// Gets the notes that fit at the given font size
    private static func getNotesToShowAtFontSize(_ notes: [Note], fontSize: CGFloat, availableHeight: CGFloat, fontType: WallpaperFont) -> [Note] {
        let lineSpacing = lineSpacingForFontSize(fontSize)
        let separatorHeight = separatorHeightForFontSize(fontSize)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: fontType.font(size: fontSize, weight: fontWeight),
            .paragraphStyle: paragraphStyle
        ]
        
        var notesToShow: [Note] = []
        var totalHeight: CGFloat = 0
        
        for (index, note) in notes.enumerated() {
            let attributedString = NSAttributedString(string: note.text, attributes: attributes)
            let textSize = attributedString.boundingRect(
                with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            
            let noteHeight = textSize.height + (index > 0 ? separatorHeight : 0)
            
            if totalHeight + noteHeight <= availableHeight {
                notesToShow.append(note)
                totalHeight += noteHeight
            } else {
                break
            }
        }
        
        return notesToShow
    }
    
    /// Builds the attributed string with the given font size
    private static func buildAttributedString(
        for notes: [Note],
        fontSize: CGFloat,
        textColor: UIColor,
        hasBackgroundImage: Bool,
        fontType: WallpaperFont,
        highlightMode: WallpaperTextHighlight,
        isShadowEnabled: Bool,
        shadowIntensity: Double = 0.5,
        textAlignment: NSTextAlignment
    ) -> NSMutableAttributedString {
        let lineSpacing = lineSpacingForFontSize(fontSize)
        let noteSeparation = separatorHeightForFontSize(fontSize) // Gap between notes
        
        // Determine text and background colors based on highlight
        let finalTextColor: UIColor
        let highlightColor: UIColor?
        var shadow: NSShadow? = nil
        var strokeWidth: CGFloat = 0
        var strokeColor: UIColor = .clear
        
        switch highlightMode {
        case .none:
            finalTextColor = textColor
            highlightColor = nil
            
            // Standard shadow logic (overridden if isShadowEnabled is true)
            shadow = NSShadow()
            
            if isShadowEnabled {
                // FIXED: Use much larger blur radius for soft shadows matching the SwiftUI preview
                // shadowIntensity controls the opacity (0.0 to 1.0)
                let effectiveOpacity = 0.7 * shadowIntensity
                shadow?.shadowColor = UIColor.black.withAlphaComponent(effectiveOpacity)
                shadow?.shadowOffset = CGSize(width: 2, height: 3) // Larger offset for visibility
                shadow?.shadowBlurRadius = fontSize * 0.15 // Much larger blur (was 0.053)
            } else {
                // Default subtle shadows
                let isLightText: Bool
                if finalTextColor == .white {
                    isLightText = true
                } else {
                    var w: CGFloat = 0, a: CGFloat = 0
                    finalTextColor.getWhite(&w, alpha: &a)
                    isLightText = w > 0.8
                }
                
                if fontType == .neon {
                    // NEON GLOW EFFECT
                    // Always use the text color for the glow
                    shadow?.shadowColor = finalTextColor
                    shadow?.shadowOffset = .zero
                    // Increase blur radius for stronger glow
                    shadow?.shadowBlurRadius = fontSize * 0.6
                } else if isLightText {
                    shadow?.shadowColor = UIColor.black.withAlphaComponent(0.8)
                    shadow?.shadowOffset = CGSize(width: 0, height: 2)
                    shadow?.shadowBlurRadius = fontSize * 0.12
                } else if hasBackgroundImage {
                    shadow?.shadowColor = UIColor.white.withAlphaComponent(0.5)
                    shadow?.shadowOffset = CGSize(width: 0, height: 1)
                    shadow?.shadowBlurRadius = fontSize * 0.06
                }
            }
            
        case .outline:
            // Outline Mode - DO NOT use stroke attributes here!
            // Stroke attributes cause artifacts on curved letters (e, o, s, etc.)
            // Outline is handled manually in generateWallpaper using multi-pass drawing
            finalTextColor = textColor
            highlightColor = nil
            // No stroke attributes - we draw outline manually for clean results
            strokeWidth = 0
            strokeColor = .clear
            
            // Shadow is optional for outline mode
            if isShadowEnabled {
                let effectiveOpacity = 0.6 * shadowIntensity
                shadow = NSShadow()
                shadow?.shadowColor = UIColor.black.withAlphaComponent(effectiveOpacity)
                shadow?.shadowOffset = CGSize(width: 2, height: 3)
                shadow?.shadowBlurRadius = fontSize * 0.12
            }
            
        case .whiteBox:
            // Use user-selected color (was forcing black)
            finalTextColor = textColor
            // Manual drawing in generateWallpaper, so no background attribute here
            highlightColor = nil 
            // No shadow on text inside box
            shadow = nil
            
        case .blackBox:
            // Use user-selected color (was forcing white)
            finalTextColor = textColor
            // Manual drawing in generateWallpaper, so no background attribute here
            highlightColor = nil
            // No shadow on text inside box
            shadow = nil
            
            if isShadowEnabled {
                // For manual box drawing, we handle shadow there.
                // But if we wanted text shadow inside box, we could add it here.
                // Standard "Card" usually has clean text inside.
                shadow = nil 
            }
        }
        
        // SPECIAL HANDLING FOR STRONG FONT
        // "Strong" font implies a background color behind the text (like Instagram)
        // We only apply this if NO other specific highlight mode (box) is selected
        var finalHighlightColor = highlightColor
        let finalStrokeWidth = strokeWidth
        let finalStrokeColor = strokeColor
        
        if fontType == .strong && highlightMode == .none && !isShadowEnabled {
            // Instagram Strong: White text on auto-colored background (usually theme color)
            // For Simplicity: We'll use a semi-transparent background derived from text color inverted,
            // or just a standard white/black semi-transparent box depending on text brightness.
            
            // If text is light -> Black background
            // If text is dark -> White background
            var w: CGFloat = 0, a: CGFloat = 0
            finalTextColor.getWhite(&w, alpha: &a)
            
            if w > 0.5 {
                 // White text -> Dark background (Classic Instagram Strong)
                finalHighlightColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.7) // Dark gray/black
            } else {
                // Dark text -> Light background
                finalHighlightColor = UIColor(white: 1.0, alpha: 0.8)
            }
            
            // Strong often has nil shadow to let background pop, or very subtle
            if !isShadowEnabled {
                shadow = nil 
            }
        }
        
        let attributedString = NSMutableAttributedString()
        
        for (index, note) in notes.enumerated() {
            // Create paragraph style for THIS note
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = textAlignment // Apply requested alignment
            paragraphStyle.lineSpacing = lineSpacing
            
            // Add spacing BEFORE this note (except for the first one)
            if index > 0 {
                paragraphStyle.paragraphSpacingBefore = noteSeparation
            }
            
            // Base attributes for this note
            var noteAttributes: [NSAttributedString.Key: Any] = [
                .font: fontType.font(size: fontSize, weight: fontWeight),
                .paragraphStyle: paragraphStyle
            ]
            
            if let shadow = shadow {
                noteAttributes[.shadow] = shadow
            }
            
            if let bg = finalHighlightColor {
                noteAttributes[.backgroundColor] = bg
            }
            
            if finalStrokeWidth != 0 {
                noteAttributes[.strokeWidth] = finalStrokeWidth
                noteAttributes[.strokeColor] = finalStrokeColor
            }
            
            if note.isCompleted {
                // Completed notes: dimmed text color and strikethrough
                let dimmedColor = finalTextColor.withAlphaComponent(0.5)
                noteAttributes[.foregroundColor] = dimmedColor
                noteAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                noteAttributes[.strikethroughColor] = dimmedColor
            } else {
                // Active notes: normal text color
                noteAttributes[.foregroundColor] = finalTextColor
            }
            
            // Add newline before each note (except first) to create separate paragraphs
            if index > 0 {
                attributedString.append(NSAttributedString(string: "\n", attributes: noteAttributes))
            }
            
            let noteAttributedString = NSAttributedString(string: note.text, attributes: noteAttributes)
            attributedString.append(noteAttributedString)
        }
        
        return attributedString
    }
    
    // MARK: - Outline Text Builder
    
    /// Builds an attributed string for the outline layer (single solid color)
    /// Used for multi-pass outline drawing to avoid stroke attribute artifacts
    private static func buildOutlineString(
        for notes: [Note],
        fontSize: CGFloat,
        outlineColor: UIColor,
        fontType: WallpaperFont,
        textAlignment: NSTextAlignment
    ) -> NSMutableAttributedString {
        let lineSpacing = lineSpacingForFontSize(fontSize)
        let noteSeparation = separatorHeightForFontSize(fontSize)
        
        let attributedString = NSMutableAttributedString()
        
        for (index, note) in notes.enumerated() {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = textAlignment
            paragraphStyle.lineSpacing = lineSpacing
            
            if index > 0 {
                paragraphStyle.paragraphSpacingBefore = noteSeparation
            }
            
            // Simple attributes - just color and font, no shadows or effects
            var noteAttributes: [NSAttributedString.Key: Any] = [
                .font: fontType.font(size: fontSize, weight: fontWeight),
                .paragraphStyle: paragraphStyle,
                .foregroundColor: outlineColor
            ]
            
            // For completed notes, apply strikethrough to match main text
            if note.isCompleted {
                noteAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                noteAttributes[.strikethroughColor] = outlineColor.withAlphaComponent(0.5)
            }
            
            if index > 0 {
                attributedString.append(NSAttributedString(string: "\n", attributes: noteAttributes))
            }
            
            let noteAttributedString = NSAttributedString(string: note.text, attributes: noteAttributes)
            attributedString.append(noteAttributedString)
        }
        
        return attributedString
    }
    
    // MARK: - Proportional Spacing Helpers
    
    /// Line spacing scales proportionally with font size
    /// Increased for better readability within multi-line notes
    private static func lineSpacingForFontSize(_ fontSize: CGFloat) -> CGFloat {
        return fontSize * 0.15 // Slightly increased for better readability
    }
    
    /// Separator height between notes - BIGGER gaps for visual separation
    /// This creates clear breathing room between each note
    private static func separatorHeightForFontSize(_ fontSize: CGFloat) -> CGFloat {
        return fontSize * 0.45 // Increased from 0.25 to 0.45 for much better separation
    }

    static func generateBlankWallpaper(
        backgroundColor: UIColor,
        backgroundImage: UIImage? = nil
    ) -> UIImage {
        let width: CGFloat = 1290
        let height: CGFloat = 2796
        
        // Use same format configuration as generateWallpaper for color consistency
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        format.opaque = true
        if #available(iOS 12.0, *) {
            format.preferredRange = .extended
        }
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.image { context in
            let canvasRect = CGRect(x: 0, y: 0, width: width, height: height)

            backgroundColor.setFill()
            context.fill(canvasRect)

            if let image = backgroundImage {
                drawBackground(image: image, in: canvasRect, on: context.cgContext)
            }
        }
    }

    // MARK: - Public API
    
    /// Calculate how many notes will appear on wallpaper with adaptive sizing
    /// - Parameters:
    ///   - notes: Array of notes to check
    ///   - hasLockScreenWidgets: Whether user has lock screen widgets (affects available space)
    static func getWallpaperNoteCount(from notes: [Note], hasLockScreenWidgets: Bool = true) -> Int {
        guard !notes.isEmpty else { return 0 }
        
        let height = availableHeight(hasWidgets: hasLockScreenWidgets)
        
        // Calculate optimal font size for all notes
        let optimalFontSize = calculateOptimalFontSize(for: notes, availableHeight: height, fontType: .classic)
        
        // Get how many notes fit at that font size
        return getNotesToShowAtFontSize(notes, fontSize: optimalFontSize, availableHeight: height, fontType: .classic).count
    }
    
    /// Returns the font size that will be used for rendering the given notes
    /// - Parameters:
    ///   - notes: Array of notes to render
    ///   - hasLockScreenWidgets: Whether user has lock screen widgets (affects available space)
    static func getFontSizeForNotes(_ notes: [Note], hasLockScreenWidgets: Bool = true) -> CGFloat {
        let height = availableHeight(hasWidgets: hasLockScreenWidgets)
        return calculateOptimalFontSize(for: notes, availableHeight: height, fontType: .classic)
    }

    private static func drawBackground(image: UIImage, in canvasRect: CGRect, on context: CGContext) {
        let canvasSize = canvasRect.size
        let imageSize = image.size

        let coverScale = max(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        let coverSize = CGSize(width: imageSize.width * coverScale, height: imageSize.height * coverScale)
        let coverOrigin = CGPoint(
            x: (canvasSize.width - coverSize.width) / 2,
            y: (canvasSize.height - coverSize.height) / 2
        )

        image.draw(in: CGRect(origin: coverOrigin, size: coverSize))

        // REMOVED: White overlay that was washing out the image
        // context.setFillColor(UIColor.white.withAlphaComponent(0.1).cgColor)
        // context.fill(canvasRect)
    }

    private static func textColorForBackground(backgroundColor: UIColor, backgroundImage: UIImage?) -> UIColor {
        let brightness: CGFloat

        if let image = backgroundImage {
            brightness = averageBrightness(of: image)
        } else {
            brightness = brightnessOfColor(backgroundColor)
        }

        // STRONGLY prefer white text - only use black for very bright/white wallpapers
        // Threshold set to 0.85 = only nearly white images get black text
        // White text with shadows looks better on most backgrounds
        if brightness < 0.85 {
            return UIColor.white
        } else {
            return UIColor.black.withAlphaComponent(0.9)
        }
    }

    private static func brightnessOfColor(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var white: CGFloat = 0
        var alpha: CGFloat = 0

        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return 0.299 * red + 0.587 * green + 0.114 * blue
        } else if color.getWhite(&white, alpha: &alpha) {
            return white
        } else if let components = color.cgColor.components, components.count >= 3 {
            return 0.299 * components[0] + 0.587 * components[1] + 0.114 * components[2]
        }

        return 0.5
    }

    /// Samples brightness from the TEXT AREA of the image (middle-lower portion)
    /// This gives better results than sampling the whole image
    private static func averageBrightness(of image: UIImage) -> CGFloat {
        let imageSize = image.size
        
        // Define the text area region (where notes appear on lock screen)
        // Approximately: top 38% to bottom 85% of the image, left side
        // This corresponds to where notes are rendered (below widgets, above flashlight)
        let textAreaRect = CGRect(
            x: 0,
            y: imageSize.height * 0.38,  // Start below clock/widgets area
            width: imageSize.width * 0.8, // Left portion where text is
            height: imageSize.height * 0.47 // Up to above flashlight area
        )
        
        // Crop to text area first
        guard let cgImage = image.cgImage,
              let croppedCGImage = cgImage.cropping(to: CGRect(
                x: textAreaRect.origin.x * CGFloat(cgImage.width) / imageSize.width,
                y: textAreaRect.origin.y * CGFloat(cgImage.height) / imageSize.height,
                width: textAreaRect.width * CGFloat(cgImage.width) / imageSize.width,
                height: textAreaRect.height * CGFloat(cgImage.height) / imageSize.height
              )) else {
            return averageBrightnessFullImage(of: image)
        }
        
        let croppedImage = UIImage(cgImage: croppedCGImage)
        return averageBrightnessFullImage(of: croppedImage)
    }
    
    /// Samples brightness from the entire image (fallback)
    private static func averageBrightnessFullImage(of image: UIImage) -> CGFloat {
        let sampleSize = CGSize(width: 12, height: 12)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: sampleSize, format: format)
        let downsampled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: sampleSize))
        }

        guard let cgImage = downsampled.cgImage,
              let data = cgImage.dataProvider?.data,
              let pointer = CFDataGetBytePtr(data) else {
            return 0.5
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        guard bytesPerPixel >= 3 else { return 0.5 }

        var total: CGFloat = 0
        let width = Int(sampleSize.width)
        let height = Int(sampleSize.height)

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * cgImage.bytesPerRow) + (x * bytesPerPixel)
                let r = CGFloat(pointer[index])
                let g = CGFloat(pointer[index + 1])
                let b = CGFloat(pointer[index + 2])
                total += (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            }
        }

        let pixelCount = CGFloat(width * height)
        guard pixelCount > 0 else { return 0.5 }
        return total / pixelCount
    }
}
