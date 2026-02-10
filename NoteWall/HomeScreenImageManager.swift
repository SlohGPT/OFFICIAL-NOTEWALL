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
            return "The NoteWall folder inside Files could not be created."
        case .unableToEncodeImage:
            return "The selected image could not be saved."
        }
    }
}

enum HomeScreenImageManager {
    private static let noteWallFolderName = "NoteWall"
    private static let editorFolderName = "TextEditor"
    private static let legacyShortcutsFolderName = "Shortcuts"
    private static let lockScreenFolderName = "LockScreen"
    private static let homeScreenFolderName = "HomeScreen"
    private static let editorBackgroundFileName = "lockscreen_background.jpg"
    private static let lockScreenFileName = "lockscreen.jpg"
    private static let homeScreenFileName = "homescreen.jpg"
    private static let legacyMirrorMarkerFileName = ".notewall_legacy_mirror"

    static var displayFolderPath: String {
        "Files → On My iPhone → \(noteWallFolderName) → LockScreen"
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

    private static var lockScreenDirectoryURL: URL? {
        baseDirectoryURL?.appendingPathComponent(lockScreenFolderName, isDirectory: true)
    }

    private static var homeScreenDirectoryURL: URL? {
        baseDirectoryURL?.appendingPathComponent(homeScreenFolderName, isDirectory: true)
    }

    private static var editorDirectoryURL: URL? {
        baseDirectoryURL?.appendingPathComponent(editorFolderName, isDirectory: true)
    }

    private static var lockScreenFileURL: URL? {
        lockScreenDirectoryURL?.appendingPathComponent(lockScreenFileName, isDirectory: false)
    }

    private static var homeScreenFileURL: URL? {
        homeScreenDirectoryURL?.appendingPathComponent(homeScreenFileName, isDirectory: false)
    }

    private static var editorBackgroundFileURL: URL? {
        editorDirectoryURL?.appendingPathComponent(editorBackgroundFileName, isDirectory: false)
    }



    static func prepareStorageStructure() {
        guard let baseURL = baseDirectoryURL else { return }

        do {
            try ensureDirectoryExists(at: baseURL)
            let directories = [
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

        // Handle prior numbered folder experiment (`2-LockScreen`)
        let numberedFolders: [(old: String, new: String)] = [
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

    // MARK: - Legacy Home Screen Support (Grandfathered Users)
    // Users who installed the app before Feb 9 2026 had a shortcut that set
    // BOTH the home screen and the lock screen wallpaper.  The old app created
    // a `HomeScreen/` directory on every launch.  If that directory exists the
    // user is grandfathered in and we keep writing `homescreen.jpg` so their
    // existing shortcut continues to work.  New users never get this directory.

    /// Returns `true` if the device has a `HomeScreen` directory left over from
    /// a prior version, indicating the user's shortcut expects both wallpapers.
    static var isLegacyHomeScreenUser: Bool {
        guard let dirURL = homeScreenDirectoryURL else { return false }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: dirURL.path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Saves a home-screen wallpaper image for legacy users whose shortcuts
    /// still reference `HomeScreen/homescreen.jpg`.
    static func saveHomeScreenImage(_ image: UIImage) throws {
        guard
            let baseURL = baseDirectoryURL,
            let directoryURL = homeScreenDirectoryURL,
            let destinationURL = homeScreenFileURL
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
    }

    private static func jpegData(from image: UIImage, compressionQuality: CGFloat) -> Data? {
        if let data = image.jpegData(compressionQuality: compressionQuality) {
            return data
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }

        return rendered.jpegData(compressionQuality: compressionQuality)
    }
}

