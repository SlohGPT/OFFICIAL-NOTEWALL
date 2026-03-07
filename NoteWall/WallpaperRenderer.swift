import UIKit
import SwiftUI

struct WallpaperRenderer {
    // MARK: - Adaptive Text Sizing Configuration
    
    /// Maximum font size - for short verses (1-2 lines)
    /// Sized to create readable column-style text
    private static let maxFontSize: CGFloat = 120 // Increased for larger text impact
    
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
    /// 12% on each side for nice centered column look
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
                return UIFont.systemFont(ofSize: size, weight: .black)
                
            case .neon:
                // Instagram's "Neon" is a cursive/script font.
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
    
    /// Font weight for notes - semibold for better readability
    private static let fontWeight: UIFont.Weight = .semibold
    
    /// Helper to load the correct font based on selection
    private static func loadFont(_ fontType: WallpaperFont, size: CGFloat, weight: UIFont.Weight = .semibold) -> UIFont {
        return fontType.font(size: size, weight: weight)
    }
    
    // MARK: - Device-Aware Adjustments
    
    /// DEVICE-SPECIFIC FINE-TUNING
    /// Detect if device has smaller screen and apply minor adjustments
    private static func getDeviceAdjustedTopPadding(basePadding: CGFloat) -> CGFloat {
        let deviceScreenHeight: CGFloat
        if UIScreen.main.nativeBounds.height > 0 {
            deviceScreenHeight = UIScreen.main.nativeBounds.height
        } else {
            return basePadding
        }
        
        switch deviceScreenHeight {
        case 0..<1500:  // iPhone SE, 8, 7, 6 (4.7" and smaller)
            return basePadding * 1.05  // +5%
            
        case 1500..<2400:  // iPhone 12 mini, 13 mini (5.4")
            return basePadding * 1.02  // +2%
            
        case 2400..<2900:  // iPhone 12, 13, 14 (6.1")
            return basePadding  // Base calculation (perfect)
            
        default:  // iPhone Pro Max, Plus models (6.7"+)
            return basePadding * 0.98  // -2%
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
    
    private static func logPositioningInfo(hasLockScreenWidgets: Bool) {
        let deviceHeight = UIScreen.main.nativeBounds.height
        let deviceWidth = UIScreen.main.nativeBounds.width
        let baseTopPadding = hasLockScreenWidgets ? topPaddingWithWidgets : topPaddingNoWidgets
        let adjustedTopPadding = topPadding(hasWidgets: hasLockScreenWidgets)
        let availableHeight = screenHeight - adjustedTopPadding - bottomSafeArea
        
        print("━━━ NoteWall Positioning Debug ━━━")
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
    
    // MARK: - Main Wallpaper Generation
    
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

        fontSizeScaling: Double = 1.0, // NEW: Font Size Scaling
        textAlignment: NSTextAlignment = .left // Default to left alignment
    ) -> UIImage {
        print("🎨 WallpaperRenderer: Generating wallpaper")
        print("   Total notes: \(notes.count)")
        print("   Background image: \(backgroundImage != nil ? "YES" : "NO")")
        print("   Has widgets: \(hasLockScreenWidgets)")
        
        #if DEBUG
        logPositioningInfo(hasLockScreenWidgets: hasLockScreenWidgets)
        #endif
        
        let width: CGFloat = 1290
        let height: CGFloat = 2796
        
        let currentTopPadding = topPadding(hasWidgets: hasLockScreenWidgets)
        let currentAvailableHeight = availableHeight(hasWidgets: hasLockScreenWidgets)

        // Configure renderer with explicit sRGB color space for proper color preservation
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
                selectedFont = .modern // Default to clean sans-serif
            }

            let optimalFontSize = calculateOptimalFontSize(for: notes, availableHeight: currentAvailableHeight, fontType: selectedFont) * fontSizeScaling
            print("   📏 Optimal font size: \(optimalFontSize)pt (Font: \(selectedFont.rawValue))")
            
            let notesToShow = getNotesToShowAtFontSize(notes, fontSize: optimalFontSize, availableHeight: currentAvailableHeight, fontType: selectedFont)
            print("   Notes to show: \(notesToShow.count)")
            
            guard !notesToShow.isEmpty else {
                print("   ⚠️ NO NOTES FIT - Wallpaper will be blank")
                return
            }

            // Determine final text color
            let finalTextColor = customTextColor ?? textColorForBackground(
                backgroundColor: backgroundColor,
                backgroundImage: backgroundImage
            )
            
            print("   🎨 Text color: \(finalTextColor)")

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

            // Determine X position based on alignment to ensure background hugs the text
            var textXPosition: CGFloat = leftPadding
            
            // Adjust X to center or right align the tighter rect within the available width
            if textAlignment == .center {
                textXPosition = leftPadding + (textMaxWidth - textSize.width) / 2
            } else if textAlignment == .right {
                textXPosition = leftPadding + (textMaxWidth - textSize.width)
            }
            // If .left, it stays at leftPadding
            
            let textRect = CGRect(
                x: textXPosition,
                y: currentTopPadding,
                width: textSize.width, // Hug content width for nice highlight boxes
                height: textSize.height
            )
            
            // Draw per-note box backgrounds if highlight mode is box
            if highlightMode == .whiteBox || highlightMode == .blackBox {
                let boxPadding: CGFloat = 24
                let boxCornerRadius: CGFloat = 14
                let boxColor: UIColor = (highlightMode == .whiteBox) 
                    ? UIColor.white.withAlphaComponent(0.85) 
                    : UIColor.black.withAlphaComponent(0.85)
                
                let lineSpacing = lineSpacingForFontSize(optimalFontSize)
                let separatorHeight = separatorHeightForFontSize(optimalFontSize)
                
                let noteParaStyle = NSMutableParagraphStyle()
                noteParaStyle.alignment = textAlignment
                noteParaStyle.lineSpacing = lineSpacing
                
                let noteAttrs: [NSAttributedString.Key: Any] = [
                    .font: selectedFont.font(size: optimalFontSize, weight: fontWeight),
                    .paragraphStyle: noteParaStyle
                ]
                
                var yOffset: CGFloat = currentTopPadding
                
                for (index, note) in notesToShow.enumerated() {
                    if index > 0 {
                        yOffset += separatorHeight
                    }
                    
                    let noteAttrStr = NSAttributedString(string: note.text, attributes: noteAttrs)
                    let noteSize = noteAttrStr.boundingRect(
                        with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )
                    
                    // Calculate X for this individual note based on alignment
                    var noteX: CGFloat = leftPadding
                    if textAlignment == .center {
                        noteX = leftPadding + (textMaxWidth - noteSize.width) / 2
                    } else if textAlignment == .right {
                        noteX = leftPadding + (textMaxWidth - noteSize.width)
                    }
                    
                    let noteRect = CGRect(
                        x: noteX - boxPadding,
                        y: yOffset - boxPadding * 0.6,
                        width: noteSize.width + boxPadding * 2,
                        height: noteSize.height + boxPadding * 1.2
                    )
                    
                    let path = UIBezierPath(roundedRect: noteRect, cornerRadius: boxCornerRadius)
                    
                    if isShadowEnabled {
                        context.cgContext.saveGState()
                        context.cgContext.setShadow(
                            offset: CGSize(width: 1, height: 3), 
                            blur: 8, 
                            color: UIColor.black.withAlphaComponent(0.35).cgColor
                        )
                        boxColor.setFill()
                        path.fill()
                        context.cgContext.restoreGState()
                    } else {
                        boxColor.setFill()
                        path.fill()
                    }
                    
                    yOffset += noteSize.height
                }
                
                print("   ✅ Drew \(notesToShow.count) individual note box backgrounds")
            }
            
            print("   📍 Text rect: x=\(leftPadding), y=\(currentTopPadding), w=\(textMaxWidth), h=\(textSize.height)")
            
            // Handle outline mode with multi-pass drawing
            if highlightMode == .outline {
                let outlineString = buildOutlineString(
                    for: notesToShow,
                    fontSize: optimalFontSize,
                    outlineColor: .black, // Ensure Black Outline
                    fontType: selectedFont,
                    textAlignment: textAlignment
                )
                
                let outlineWidth: CGFloat = max(3.0, optimalFontSize * 0.045)
                let offsets: [(CGFloat, CGFloat)] = [
                    (-outlineWidth, 0), (outlineWidth, 0),
                    (0, -outlineWidth), (0, outlineWidth),
                    (-outlineWidth * 0.7, -outlineWidth * 0.7),
                    (outlineWidth * 0.7, -outlineWidth * 0.7),
                    (-outlineWidth * 0.7, outlineWidth * 0.7),
                    (outlineWidth * 0.7, outlineWidth * 0.7)
                ]
                
                for (dx, dy) in offsets {
                    let offsetRect = textRect.offsetBy(dx: dx, dy: dy)
                    outlineString.draw(in: offsetRect)
                }
                
                attributedString.draw(in: textRect)
                print("   ✅ Drew text with clean multi-pass outline")
            } else {
                attributedString.draw(in: textRect)
                print("   ✅ Drew text on wallpaper (with strikethrough for completed notes)")
            }
        }
    }
    
    // MARK: - Adaptive Font Size Calculation
    
    private static func calculateOptimalFontSize(for notes: [Note], availableHeight: CGFloat, fontType: WallpaperFont) -> CGFloat {
        guard !notes.isEmpty else { return maxFontSize }
        
        if doesAllNotesFit(notes, atFontSize: maxFontSize, availableHeight: availableHeight, fontType: fontType) {
            print("   ✅ All notes fit at max font size (\(maxFontSize)pt)")
            return maxFontSize
        }
        
        var low = minFontSize
        var high = maxFontSize
        var bestFit = minFontSize
        
        while low <= high {
            let mid = (low + high) / 2
            
            if doesAllNotesFit(notes, atFontSize: mid, availableHeight: availableHeight, fontType: fontType) {
                bestFit = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        
        print("   🔍 Binary search found optimal size: \(bestFit)pt")
        return bestFit
    }
    
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
            
            if totalHeight + noteHeight <= availableHeight || (notesToShow.isEmpty && index == 0) {
                // Always include at least the first note, even if it slightly exceeds bounds
                notesToShow.append(note)
                totalHeight += noteHeight
            } else {
                break
            }
        }
        
        return notesToShow
    }
    
    // MARK: - Attributed String Builders
    
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
        let noteSeparation = separatorHeightForFontSize(fontSize)
        
        let finalTextColor: UIColor
        let highlightColor: UIColor?
        var shadow: NSShadow? = nil
        
        switch highlightMode {
        case .none:
            finalTextColor = textColor
            highlightColor = nil
            
            shadow = NSShadow()
            
            if isShadowEnabled {
                let effectiveOpacity = 0.7 * shadowIntensity
                shadow?.shadowColor = UIColor.black.withAlphaComponent(effectiveOpacity)
                shadow?.shadowOffset = CGSize(width: 2, height: 3)
                shadow?.shadowBlurRadius = fontSize * 0.15
            } else {
                let isLightText: Bool
                if finalTextColor == .white {
                    isLightText = true
                } else {
                    var w: CGFloat = 0, a: CGFloat = 0
                    finalTextColor.getWhite(&w, alpha: &a)
                    isLightText = w > 0.8
                }
                
                if fontType == .neon {
                    shadow?.shadowColor = finalTextColor
                    shadow?.shadowOffset = .zero
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
            finalTextColor = textColor
            highlightColor = nil
            
            if isShadowEnabled {
                let effectiveOpacity = 0.6 * shadowIntensity
                shadow = NSShadow()
                shadow?.shadowColor = UIColor.black.withAlphaComponent(effectiveOpacity)
                shadow?.shadowOffset = CGSize(width: 2, height: 3)
                shadow?.shadowBlurRadius = fontSize * 0.12
            }
            
            // Outline Mode: Force text stroke effect
            // Note: standard shadow is handled above if enabled.
            // We don't apply stroke here because we handle it via multi-pass drawing in `drawText`.
            // But to ensure consistency if single-pass is ever used:
            // (No change needed here as `drawText` handles the specific outline pass)
            
        case .whiteBox:
            finalTextColor = textColor
            highlightColor = nil 
            shadow = nil
            
        case .blackBox:
            finalTextColor = textColor
            highlightColor = nil
            shadow = nil
        }
        
        var finalHighlightColor = highlightColor
        
        if fontType == .strong && highlightMode == .none && !isShadowEnabled {
            var w: CGFloat = 0, a: CGFloat = 0
            textColor.getWhite(&w, alpha: &a)
            
            if w > 0.5 {
                finalHighlightColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.7)
            } else {
                finalHighlightColor = UIColor(white: 1.0, alpha: 0.8)
            }
            
            shadow = nil
        }
        
        let attributedString = NSMutableAttributedString()
        
        for (index, note) in notes.enumerated() {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = textAlignment
            paragraphStyle.lineSpacing = lineSpacing
            
            if index > 0 {
                paragraphStyle.paragraphSpacingBefore = noteSeparation
            }
            
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
            
            if note.isCompleted {
                let dimmedColor = finalTextColor.withAlphaComponent(0.5)
                noteAttributes[.foregroundColor] = dimmedColor
                noteAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                noteAttributes[.strikethroughColor] = dimmedColor
            } else {
                noteAttributes[.foregroundColor] = finalTextColor
            }
            
            if index > 0 {
                attributedString.append(NSAttributedString(string: "\n", attributes: noteAttributes))
            }
            
            let noteAttributedString = NSAttributedString(string: note.text, attributes: noteAttributes)
            attributedString.append(noteAttributedString)
        }
        
        return attributedString
    }
    
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
            
            var noteAttributes: [NSAttributedString.Key: Any] = [
                .font: fontType.font(size: fontSize, weight: fontWeight),
                .paragraphStyle: paragraphStyle,
                .foregroundColor: outlineColor,
                .strokeColor: outlineColor,
                .strokeWidth: -3.0 // Fill + Stroke
            ]
            
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
    
    /// Line spacing within a note - very tight for cohesive multi-line notes
    private static func lineSpacingForFontSize(_ fontSize: CGFloat) -> CGFloat {
        return fontSize * 0.06 // Reduced from 0.15 for tighter intra-note spacing
    }
    
    /// Separator between notes - larger gap for visual separation
    private static func separatorHeightForFontSize(_ fontSize: CGFloat) -> CGFloat {
        return fontSize * 0.45
    }

    static func generateBlankWallpaper(
        backgroundColor: UIColor,
        backgroundImage: UIImage? = nil
    ) -> UIImage {
        let width: CGFloat = 1290
        let height: CGFloat = 2796
        
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
    
    static func getWallpaperNoteCount(from notes: [Note], hasLockScreenWidgets: Bool = true) -> Int {
        guard !notes.isEmpty else { return 0 }
        
        let height = availableHeight(hasWidgets: hasLockScreenWidgets)
        let optimalFontSize = calculateOptimalFontSize(for: notes, availableHeight: height, fontType: .modern)
        return getNotesToShowAtFontSize(notes, fontSize: optimalFontSize, availableHeight: height, fontType: .modern).count
    }
    
    static func getFontSizeForNotes(_ notes: [Note], hasLockScreenWidgets: Bool = true, scaling: Double = 1.0) -> CGFloat {
        let height = availableHeight(hasWidgets: hasLockScreenWidgets)
        return calculateOptimalFontSize(for: notes, availableHeight: height, fontType: .modern) * scaling
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

        context.setFillColor(UIColor.black.withAlphaComponent(0.18).cgColor)
        context.fill(canvasRect)
    }

    private static func textColorForBackground(backgroundColor: UIColor, backgroundImage: UIImage?) -> UIColor {
        let brightness: CGFloat

        if let image = backgroundImage {
            brightness = averageBrightness(of: image)
        } else {
            brightness = brightnessOfColor(backgroundColor)
        }

        // Prefer white text - only use black for very bright images
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

    private static func averageBrightness(of image: UIImage) -> CGFloat {
        let imageSize = image.size
        
        let textAreaRect = CGRect(
            x: 0,
            y: imageSize.height * 0.38,
            width: imageSize.width * 0.8,
            height: imageSize.height * 0.47
        )
        
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
