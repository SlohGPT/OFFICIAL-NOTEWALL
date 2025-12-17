import Foundation

/// Configuration file for sensitive credentials
/// This file is gitignored - do not commit it!
struct Config {
    /// 8-digit developer PIN for promo code admin access
    static let developerPIN = "84739261"
    
    // MARK: - Video URLs
    /// Video files are hosted online to reduce app bundle size
    /// Replace these with your actual CDN/cloud storage URLs after uploading videos
    static let videoURLs: [String: String] = [
        "welcome-video": "https://your-cdn-url.com/videos/welcome-video.mp4",
        "pip-guide-new": "https://your-cdn-url.com/videos/pip-guide-new.mp4",
        "how-to-fix-guide": "https://your-cdn-url.com/videos/how-to-fix-guide.mp4",
        "fix-guide-final-version": "https://your-cdn-url.com/videos/fix-guide-final-version.mp4",
        "notifications-of-permissions": "https://your-cdn-url.com/videos/notifications-of-permissions.mp4"
    ]
    
    /// Fallback: Try bundle first, then URL (for development/testing)
    static let useBundleVideosAsFallback = false
}

