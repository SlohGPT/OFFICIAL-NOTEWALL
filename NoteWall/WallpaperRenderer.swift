import UIKit
import SwiftUI

struct WallpaperRenderer {
    // MARK: - Adaptive Text Sizing Configuration
    
    /// Maximum font size - used when you have few notes
    /// This is much larger to make 1-3 notes look prominent
    private static let maxFontSize: CGFloat = 140
    
    /// Minimum font size - smallest we'll go for readability
    private static let minFontSize: CGFloat = 52
    
    /// Horizontal padding on each side
    private static let horizontalPadding: CGFloat = 80
    
    /// Canvas width
    private static let canvasWidth: CGFloat = 1290
    
    /// Text max width
    private static var textMaxWidth: CGFloat { canvasWidth - (horizontalPadding * 2) }
    
    /// Font weight for notes - heavy for better visibility
    private static let fontWeight: UIFont.Weight = .heavy
    
    // MARK: - Layout Configuration (Widget-aware)
    
    /// Top padding when user HAS widgets (just below widgets)
    /// Balanced to clear widgets but not too far
    private static let topPaddingWithWidgets: CGFloat = 1020
    
    /// Top padding when user has NO widgets (closer to clock)
    private static let topPaddingNoWidgets: CGFloat = 700
    
    /// Bottom safe area padding (above flashlight/camera icons)
    /// Increased to ensure notes never overlap flashlight/camera
    private static let bottomSafeArea: CGFloat = 550
    
    /// Screen height
    private static let screenHeight: CGFloat = 2796
    
    /// Get top padding based on widget setting
    static func topPadding(hasWidgets: Bool) -> CGFloat {
        return hasWidgets ? topPaddingWithWidgets : topPaddingNoWidgets
    }
    
    /// Get available height based on widget setting
    static func availableHeight(hasWidgets: Bool) -> CGFloat {
        return screenHeight - topPadding(hasWidgets: hasWidgets) - bottomSafeArea
    }
    
    static func generateWallpaper(
        from notes: [Note],
        backgroundColor: UIColor,
        backgroundImage: UIImage? = nil,
        hasLockScreenWidgets: Bool = true
    ) -> UIImage {
        print("🎨 WallpaperRenderer: Generating wallpaper")
        print("   Total notes: \(notes.count)")
        print("   Background image: \(backgroundImage != nil ? "YES" : "NO")")
        print("   Has widgets: \(hasLockScreenWidgets)")
        
        // iPhone wallpaper dimensions
        let width: CGFloat = 1290
        let height: CGFloat = 2796
        
        // Get layout values based on widget setting
        let currentTopPadding = topPadding(hasWidgets: hasLockScreenWidgets)
        let currentAvailableHeight = availableHeight(hasWidgets: hasLockScreenWidgets)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))

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
            
            // Calculate the optimal font size for all notes
            let optimalFontSize = calculateOptimalFontSize(for: notes, availableHeight: currentAvailableHeight)
            print("   📏 Optimal font size: \(optimalFontSize)pt")
            
            // Get the notes that fit at this font size (should be all of them unless we hit min font)
            let notesToShow = getNotesToShowAtFontSize(notes, fontSize: optimalFontSize, availableHeight: currentAvailableHeight)
            print("   Notes to show: \(notesToShow.count)")
            
            guard !notesToShow.isEmpty else {
                print("   ⚠️ NO NOTES FIT - Wallpaper will be blank")
                return
            }

            let baseTextColor = textColorForBackground(
                backgroundColor: backgroundColor,
                backgroundImage: backgroundImage
            )
            
            print("   🎨 Text color: \(baseTextColor == .white ? "WHITE" : "BLACK")")

            // Build attributed string with adaptive sizing
            // Pass whether there's a background image for shadow rendering
            let attributedString = buildAttributedString(
                for: notesToShow,
                fontSize: optimalFontSize,
                textColor: baseTextColor,
                hasBackgroundImage: backgroundImage != nil
            )
            
            print("   📝 Combined text length: \(attributedString.length) chars")

            let textSize = attributedString.boundingRect(
                with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )

            // Position text based on widget setting
            let textRect = CGRect(
                x: horizontalPadding,
                y: currentTopPadding,
                width: textMaxWidth,
                height: textSize.height
            )
            
            print("   📍 Text rect: x=\(horizontalPadding), y=\(currentTopPadding), w=\(textMaxWidth), h=\(textSize.height)")

            // Draw attributed text
            attributedString.draw(in: textRect)
            print("   ✅ Drew text on wallpaper (with strikethrough for completed notes)")
        }
    }
    
    // MARK: - Adaptive Font Size Calculation
    
    /// Calculates the optimal font size to fit all notes in the available space
    /// - Parameters:
    ///   - notes: Array of notes to fit
    ///   - availableHeight: The height available for notes (depends on widget setting)
    /// - Returns: The largest font size that fits all notes, clamped to min/max bounds
    private static func calculateOptimalFontSize(for notes: [Note], availableHeight: CGFloat) -> CGFloat {
        guard !notes.isEmpty else { return maxFontSize }
        
        // First check: do all notes fit at max font size?
        if doesAllNotesFit(notes, atFontSize: maxFontSize, availableHeight: availableHeight) {
            print("   ✅ All notes fit at max font size (\(maxFontSize)pt)")
            return maxFontSize
        }
        
        // Binary search to find the largest font size that fits all notes
        var low = minFontSize
        var high = maxFontSize
        var bestFit = minFontSize
        
        while low <= high {
            let mid = (low + high) / 2
            
            if doesAllNotesFit(notes, atFontSize: mid, availableHeight: availableHeight) {
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
    private static func doesAllNotesFit(_ notes: [Note], atFontSize fontSize: CGFloat, availableHeight: CGFloat) -> Bool {
        let lineSpacing = lineSpacingForFontSize(fontSize)
        let separatorHeight = separatorHeightForFontSize(fontSize)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight),
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
    private static func getNotesToShowAtFontSize(_ notes: [Note], fontSize: CGFloat, availableHeight: CGFloat) -> [Note] {
        let lineSpacing = lineSpacingForFontSize(fontSize)
        let separatorHeight = separatorHeightForFontSize(fontSize)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight),
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
        hasBackgroundImage: Bool
    ) -> NSMutableAttributedString {
        let lineSpacing = lineSpacingForFontSize(fontSize)
        let noteSeparation = separatorHeightForFontSize(fontSize) // Gap between notes
        
        // Create shadow for better readability on photo backgrounds
        let shadow = NSShadow()
        if hasBackgroundImage {
            let isLightText = textColor == .white || textColor.cgColor.alpha == 1.0
            shadow.shadowColor = isLightText 
                ? UIColor.black.withAlphaComponent(0.7)
                : UIColor.white.withAlphaComponent(0.7)
            shadow.shadowOffset = CGSize(width: 0, height: 2)
            shadow.shadowBlurRadius = fontSize * 0.08
        }
        
        let attributedString = NSMutableAttributedString()
        
        for (index, note) in notes.enumerated() {
            // Create paragraph style for THIS note
            // First note has no spacing before, subsequent notes have gap
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            paragraphStyle.lineSpacing = lineSpacing
            
            // Add spacing BEFORE this note (except for the first one)
            if index > 0 {
                paragraphStyle.paragraphSpacingBefore = noteSeparation
            }
            
            // Base attributes for this note
            var noteAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight),
                .paragraphStyle: paragraphStyle
            ]
            
            // Add shadow only for photo backgrounds
            if hasBackgroundImage {
                noteAttributes[.shadow] = shadow
            }
            
            if note.isCompleted {
                // Completed notes: dimmed text color and strikethrough
                let dimmedColor = textColor.withAlphaComponent(0.5)
                noteAttributes[.foregroundColor] = dimmedColor
                noteAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                noteAttributes[.strikethroughColor] = dimmedColor
            } else {
                // Active notes: normal text color
                noteAttributes[.foregroundColor] = textColor
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
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
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
        let optimalFontSize = calculateOptimalFontSize(for: notes, availableHeight: height)
        
        // Get how many notes fit at that font size
        return getNotesToShowAtFontSize(notes, fontSize: optimalFontSize, availableHeight: height).count
    }
    
    /// Returns the font size that will be used for rendering the given notes
    /// - Parameters:
    ///   - notes: Array of notes to render
    ///   - hasLockScreenWidgets: Whether user has lock screen widgets (affects available space)
    static func getFontSizeForNotes(_ notes: [Note], hasLockScreenWidgets: Bool = true) -> CGFloat {
        let height = availableHeight(hasWidgets: hasLockScreenWidgets)
        return calculateOptimalFontSize(for: notes, availableHeight: height)
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

        // Threshold chosen so mid-tone images still get high-contrast text.
        if brightness < 0.55 {
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
