import Foundation

/// Configuration file for sensitive credentials
/// This file is gitignored - do not commit it!
struct Config {
    /// 8-digit developer PIN for promo code admin access
    static let developerPIN = "84739261"
    
    // MARK: - User Count API
    /// Vercel API endpoint for real-time user count
    /// After deploying vercel-email-api, update this with your Vercel URL
    /// Format: "https://your-project.vercel.app/api/user-count"
    /// See: vercel-email-api/DEPLOY_NOW.md for setup instructions
    static let userCountAPIURL: String? = "https://vercel-email-c3tn2sbrm-slohgpt-2818s-projects.vercel.app/api/user-count"
    
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

