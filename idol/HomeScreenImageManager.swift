import Foundation
import UIKit

enum HomeScreenImageManagerError: LocalizedError {
    case documentsDirectoryUnavailable
    case unableToCreateDirectory
    case unableToEncodeImage

    var errorDescription: String? {
        switch self {
        case .documentsDirectoryUnavailable:
            return "The app's local files directory could not be accessed."
        case .unableToCreateDirectory:
            return "The FaithWall folder inside Files could not be created."
        case .unableToEncodeImage:
            return "The selected image could not be saved."
        }
    }
}

enum HomeScreenImageManager {
    private static let noteWallFolderName = "FaithWall"
    private static let editorFolderName = "TextEditor"
    private static let legacyShortcutsFolderName = "Shortcuts"
    private static let homeScreenFolderName = "HomeScreen"
    private static let lockScreenFolderName = "LockScreen"
    private static let editorBackgroundFileName = "lockscreen_background.jpg"
    private static let homeScreenFileName = "homescreen.jpg"
    private static let lockScreenFileName = "lockscreen.jpg"
    private static let homePresetBlackFileName = "home_preset_black.jpg"
    private static let homePresetGrayFileName = "home_preset_gray.jpg"
    private static let presetIndicatorFileName = "preset_selection.txt"
    private static let legacyHomeScreenExtensions = ["png", "heic", "heif"]
    private static let legacyMirrorMarkerFileName = ".faithwall_legacy_mirror"

    static var displayFolderPath: String {
        "Files → On My iPhone → \(noteWallFolderName) → (HomeScreen or LockScreen)"
    }

    private static var documentsDirectoryURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private static var baseDirectoryURL: URL? {
        guard let documentsURL = documentsDirectoryURL else {
            return nil
        }

        let newBaseURL = documentsURL
            .appendingPathComponent(noteWallFolderName, isDirectory: true)

        migrateLegacyDirectoryIfNeeded(documentsDirectory: documentsURL, newBaseURL: newBaseURL)

        return newBaseURL
    }

    private static var legacyBaseDirectoryURL: URL? {
        documentsDirectoryURL?
            .appendingPathComponent(legacyShortcutsFolderName, isDirectory: true)
            .appendingPathComponent(noteWallFolderName, isDirectory: true)
    }

    private static var homeScreenDirectoryURL: URL? {
        baseDirectoryURL?.appendingPathComponent(homeScreenFolderName, isDirectory: true)
    }

    private static var lockScreenDirectoryURL: URL? {
        baseDirectoryURL?.appendingPathComponent(lockScreenFolderName, isDirectory: true)
    }

    private static var editorDirectoryURL: URL? {
        baseDirectoryURL?.appendingPathComponent(editorFolderName, isDirectory: true)
    }

    private static var homeScreenFileURL: URL? {
        homeScreenDirectoryURL?.appendingPathComponent(homeScreenFileName, isDirectory: false)
    }

    private static var lockScreenFileURL: URL? {
        lockScreenDirectoryURL?.appendingPathComponent(lockScreenFileName, isDirectory: false)
    }

    private static var editorBackgroundFileURL: URL? {
        editorDirectoryURL?.appendingPathComponent(editorBackgroundFileName, isDirectory: false)
    }

    private static var homePresetBlackURL: URL? {
        baseDirectoryURL?.appendingPathComponent(homePresetBlackFileName, isDirectory: false)
    }

    private static var homePresetGrayURL: URL? {
        baseDirectoryURL?.appendingPathComponent(homePresetGrayFileName, isDirectory: false)
    }

    private static var editorHomePresetBlackURL: URL? {
        editorDirectoryURL?.appendingPathComponent(homePresetBlackFileName, isDirectory: false)
    }

    private static var editorHomePresetGrayURL: URL? {
        editorDirectoryURL?.appendingPathComponent(homePresetGrayFileName, isDirectory: false)
    }

    private static var presetIndicatorURL: URL? {
        editorDirectoryURL?.appendingPathComponent(presetIndicatorFileName, isDirectory: false)
    }

    static func prepareStorageStructure() {
        guard let baseURL = baseDirectoryURL else { return }

        do {
            try ensureDirectoryExists(at: baseURL)
            let directories = [
                homeScreenDirectoryURL,
                lockScreenDirectoryURL,
                editorDirectoryURL
            ]
            try directories.forEach { url in
                if let url {
                    try ensureDirectoryExists(at: url)
                }
            }
            print("✅ HomeScreenImageManager: Created folder structure at: \(baseURL.path)")
        } catch {
            print("⚠️ HomeScreenImageManager: Failed to prepare directories: \(error)")
        }
    }

    private static func ensureDirectoryExists(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private static func migrateLegacyDirectoryIfNeeded(documentsDirectory: URL, newBaseURL: URL) {
        let legacyBaseURL = documentsDirectory
            .appendingPathComponent(legacyShortcutsFolderName, isDirectory: true)
            .appendingPathComponent(noteWallFolderName, isDirectory: true)

        let markerURL = legacyBaseURL.appendingPathComponent(legacyMirrorMarkerFileName, isDirectory: false)

        guard !FileManager.default.fileExists(atPath: markerURL.path) else {
            // This is our intentional compatibility mirror. Skip migration.
            return
        }

        guard FileManager.default.fileExists(atPath: legacyBaseURL.path) else { return }

        do {
            try FileManager.default.createDirectory(at: newBaseURL, withIntermediateDirectories: true)
            let contents = try FileManager.default.contentsOfDirectory(at: legacyBaseURL, includingPropertiesForKeys: nil, options: [])

            for item in contents {
                let destinationURL = newBaseURL.appendingPathComponent(item.lastPathComponent)

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    continue
                }

                try FileManager.default.moveItem(at: item, to: destinationURL)
            }

            try? FileManager.default.removeItem(at: legacyBaseURL)

            let legacyShortcutsURL = documentsDirectory.appendingPathComponent(legacyShortcutsFolderName, isDirectory: true)
            if let remainingItems = try? FileManager.default.contentsOfDirectory(atPath: legacyShortcutsURL.path), remainingItems.isEmpty {
                try? FileManager.default.removeItem(at: legacyShortcutsURL)
            }
        } catch {
            // Best-effort migration; ignore errors to avoid disrupting wallpaper saves.
        }

        // Handle prior numbered folder experiment (`1-HomeScreen`, `2-LockScreen`)
        let numberedFolders: [(old: String, new: String)] = [
            ("1-HomeScreen", homeScreenFolderName),
            ("2-LockScreen", lockScreenFolderName)
        ]

        numberedFolders.forEach { pair in
            let oldURL = newBaseURL.appendingPathComponent(pair.old, isDirectory: true)
            let newURL = newBaseURL.appendingPathComponent(pair.new, isDirectory: true)

            guard FileManager.default.fileExists(atPath: oldURL.path) else { return }

            do {
                if FileManager.default.fileExists(atPath: newURL.path) {
                    // If new folder already exists, merge contents
                    let files = try FileManager.default.contentsOfDirectory(at: oldURL, includingPropertiesForKeys: nil, options: [])
                    for file in files {
                        let destination = newURL.appendingPathComponent(file.lastPathComponent)
                        if FileManager.default.fileExists(atPath: destination.path) {
                            try? FileManager.default.removeItem(at: destination)
                        }
                        try FileManager.default.moveItem(at: file, to: destination)
                    }
                    try? FileManager.default.removeItem(at: oldURL)
                } else {
                    try FileManager.default.moveItem(at: oldURL, to: newURL)
                }
            } catch {
                // best effort; ignore
            }
        }
    }

    static func saveHomeScreenImage(_ image: UIImage) throws {
        guard
            let baseURL = baseDirectoryURL,
            let directoryURL = homeScreenDirectoryURL
        else {
            throw HomeScreenImageManagerError.documentsDirectoryUnavailable
        }

        do {
            try ensureDirectoryExists(at: baseURL)
            try ensureDirectoryExists(at: directoryURL)
        } catch {
            throw HomeScreenImageManagerError.unableToCreateDirectory
        }

        guard let destinationURL = homeScreenFileURL else {
            throw HomeScreenImageManagerError.documentsDirectoryUnavailable
        }

        removeLegacyHomeScreenFiles(at: directoryURL)

        guard let data = jpegData(from: image, compressionQuality: 0.9) else {
            throw HomeScreenImageManagerError.unableToEncodeImage
        }

        try data.write(to: destinationURL, options: .atomic)

        removeUnderscoreFilesIfNeeded(in: directoryURL, fileNames: ["home_screen.jpg"])
    }

    static func saveLockScreenWallpaper(_ image: UIImage) throws {
        guard
            let baseURL = baseDirectoryURL,
            let directoryURL = lockScreenDirectoryURL,
            let destinationURL = lockScreenFileURL
        else {
            throw HomeScreenImageManagerError.documentsDirectoryUnavailable
        }

        do {
            try ensureDirectoryExists(at: baseURL)
            try ensureDirectoryExists(at: directoryURL)
        } catch {
            throw HomeScreenImageManagerError.unableToCreateDirectory
        }

        guard let data = jpegData(from: image, compressionQuality: 0.9) else {
            throw HomeScreenImageManagerError.unableToEncodeImage
        }

        try data.write(to: destinationURL, options: .atomic)

        removeUnderscoreFilesIfNeeded(in: directoryURL, fileNames: ["lock_screen.jpg"])
    }

    static func saveLockScreenBackgroundSource(_ image: UIImage) throws {
        guard
            let baseURL = baseDirectoryURL,
            let directoryURL = editorDirectoryURL,
            let destinationURL = editorBackgroundFileURL
        else {
            throw HomeScreenImageManagerError.documentsDirectoryUnavailable
        }

        do {
            try ensureDirectoryExists(at: baseURL)
            try ensureDirectoryExists(at: directoryURL)
        } catch {
            throw HomeScreenImageManagerError.unableToCreateDirectory
        }

        guard let data = jpegData(from: image, compressionQuality: 0.88) else {
            throw HomeScreenImageManagerError.unableToEncodeImage
        }

        try data.write(to: destinationURL, options: .atomic)
    }

    static func removeHomeScreenImage() throws {
        guard let directoryURL = homeScreenDirectoryURL else {
            throw HomeScreenImageManagerError.documentsDirectoryUnavailable
        }

        if let destinationURL = homeScreenFileURL,
           FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        removeLegacyHomeScreenFiles(at: directoryURL)
    }

    static func homeScreenImageURL() -> URL? {
        homeScreenFileURL
    }

    static func homeScreenImageExists() -> Bool {
        guard let url = homeScreenFileURL else {
            return false
        }

        return FileManager.default.fileExists(atPath: url.path)
    }

    static func lockScreenWallpaperURL() -> URL? {
        lockScreenFileURL
    }

    static func lockScreenBackgroundSourceURL() -> URL? {
        editorBackgroundFileURL
    }

    static func lockScreenBackgroundSourceImage() -> UIImage? {
        guard let url = editorBackgroundFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    static func removeLockScreenBackgroundSource() {
        guard let url = editorBackgroundFileURL else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func loadHomeScreenImage() -> UIImage? {
        guard let url = homeScreenFileURL else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func saveHomePresetBlack(_ image: UIImage) throws {
        try savePresetImage(image, at: homePresetBlackURL)
    }

    static func saveHomePresetGray(_ image: UIImage) throws {
        try savePresetImage(image, at: homePresetGrayURL)
    }

    static func homePresetBlackImage() -> UIImage? {
        if let url = homePresetBlackURL,
           FileManager.default.fileExists(atPath: url.path),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        let image = solidColorImage(color: LockScreenBackgroundOption.black.uiColor)
        try? saveHomePresetBlack(image)
        return image
    }

    static func homePresetGrayImage() -> UIImage? {
        if let url = homePresetGrayURL,
           FileManager.default.fileExists(atPath: url.path),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        let image = solidColorImage(color: LockScreenBackgroundOption.gray.uiColor)
        try? saveHomePresetGray(image)
        return image
    }

    // MARK: - TextEditor Preset Management

    static func saveEditorHomePresetBlack(_ image: UIImage) throws {
        try savePresetImage(image, at: editorHomePresetBlackURL)
        try savePresetIndicator("black")
    }

    static func saveEditorHomePresetGray(_ image: UIImage) throws {
        try savePresetImage(image, at: editorHomePresetGrayURL)
        try savePresetIndicator("gray")
    }

    static func savePresetIndicator(_ presetName: String) throws {
        guard
            let baseURL = baseDirectoryURL,
            let directoryURL = editorDirectoryURL,
            let indicatorURL = presetIndicatorURL
        else {
            throw HomeScreenImageManagerError.documentsDirectoryUnavailable
        }

        do {
            try ensureDirectoryExists(at: baseURL)
            try ensureDirectoryExists(at: directoryURL)
        } catch {
            throw HomeScreenImageManagerError.unableToCreateDirectory
        }

        try presetName.write(to: indicatorURL, atomically: true, encoding: .utf8)
    }

    static func getCurrentPresetSelection() -> String? {
        guard let indicatorURL = presetIndicatorURL,
              FileManager.default.fileExists(atPath: indicatorURL.path) else {
            return nil
        }
        return try? String(contentsOf: indicatorURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func editorHomePresetBlackImage() -> UIImage? {
        if let url = editorHomePresetBlackURL,
           FileManager.default.fileExists(atPath: url.path),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        let image = solidColorImage(color: LockScreenBackgroundOption.black.uiColor)
        try? saveEditorHomePresetBlack(image)
        return image
    }

    static func editorHomePresetGrayImage() -> UIImage? {
        if let url = editorHomePresetGrayURL,
           FileManager.default.fileExists(atPath: url.path),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        let image = solidColorImage(color: LockScreenBackgroundOption.gray.uiColor)
        try? saveEditorHomePresetGray(image)
        return image
    }

    private static func removeLegacyHomeScreenFiles(at directoryURL: URL) {
        let legacyBaseURL = baseDirectoryURL
        legacyHomeScreenExtensions.forEach { ext in
            if let legacyBaseURL {
                let legacyURL = legacyBaseURL.appendingPathComponent("homescreen.\(ext)", isDirectory: false)
                if FileManager.default.fileExists(atPath: legacyURL.path) {
                    try? FileManager.default.removeItem(at: legacyURL)
                }
            }

            let legacyURL = directoryURL.appendingPathComponent("homescreen.\(ext)", isDirectory: false)
            if FileManager.default.fileExists(atPath: legacyURL.path) {
                try? FileManager.default.removeItem(at: legacyURL)
            }
        }

        if let legacyBaseURL = legacyBaseURL {
            let oldHomeScreenURL = legacyBaseURL.appendingPathComponent(homeScreenFileName, isDirectory: false)
            if FileManager.default.fileExists(atPath: oldHomeScreenURL.path) {
                try? FileManager.default.removeItem(at: oldHomeScreenURL)
            }
            let underscoreURL = legacyBaseURL.appendingPathComponent("home_screen.jpg", isDirectory: false)
            if FileManager.default.fileExists(atPath: underscoreURL.path) {
                try? FileManager.default.removeItem(at: underscoreURL)
            }
        }
    }

    private static func jpegData(from image: UIImage, compressionQuality: CGFloat) -> Data? {
        if let data = image.jpegData(compressionQuality: compressionQuality) {
            return data
        }

        // Fallback: re-render with explicit sRGB format
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = true  // JPEG has no transparency
        if #available(iOS 12.0, *) {
            format.preferredRange = .extended  // Preserve wide color gamut
        }

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }

        return rendered.jpegData(compressionQuality: compressionQuality)
    }

    private static func savePresetImage(_ image: UIImage, at url: URL?) throws {
        guard
            let baseURL = baseDirectoryURL,
            let destinationURL = url
        else {
            throw HomeScreenImageManagerError.documentsDirectoryUnavailable
        }

        do {
            try ensureDirectoryExists(at: baseURL)
        } catch {
            throw HomeScreenImageManagerError.unableToCreateDirectory
        }

        guard let data = jpegData(from: image, compressionQuality: 0.9) else {
            throw HomeScreenImageManagerError.unableToEncodeImage
        }

        try data.write(to: destinationURL, options: .atomic)
    }

    private static func solidColorImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 1290, height: 2796)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    // Legacy folder mirroring removed - now using only primary folder structure

    private static func removeUnderscoreFilesIfNeeded(in directoryURL: URL, fileNames: [String]) {
        fileNames.forEach { fileName in
            let url = directoryURL.appendingPathComponent(fileName, isDirectory: false)
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}

