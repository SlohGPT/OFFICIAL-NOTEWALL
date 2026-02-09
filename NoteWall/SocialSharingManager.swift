import UIKit
import Social

class SocialSharingManager {
    static let shared = SocialSharingManager()
    
    private init() {}
    
    /// Share wallpaper design (without personal notes) for viral growth
    func shareWallpaperDesign(image: UIImage, from viewController: UIViewController) {
        let shareText = NSLocalizedString("social_share_wallpaper", comment: "Share text for wallpaper design sharing")
        guard let appURL = URL(string: "https://apps.apple.com/app/id6755601996") else {
            print("⚠️ Invalid app URL")
            return
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: [shareText, image, appURL],
            applicationActivities: nil
        )
        
        // Exclude some activities to focus on viral platforms
        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks
        ]
        
        // iPad support
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityViewController, animated: true)
    }
    
    /// Share app referral for growth
    func shareAppReferral(from viewController: UIViewController) {
        let shareText = NSLocalizedString("social_share_long", comment: "Share text for app referral")
        
        guard let appURL = URL(string: "https://apps.apple.com/app/id6755601996") else {
            print("⚠️ Invalid app URL")
            return
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: [shareText, appURL],
            applicationActivities: nil
        )
        
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityViewController, animated: true)
    }
    
    /// Create shareable template (no personal data)
    func createShareableTemplate() -> UIImage {
        let size = CGSize(width: 1290, height: 2796)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Black background
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Sample motivational text (no personal data)
            let sampleText = NSLocalizedString("social_share_goals", comment: "Sample text for shareable wallpaper template")
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            paragraphStyle.lineSpacing = 12
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .medium),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
            
            let textRect = CGRect(x: 80, y: 800, width: size.width - 160, height: 1000)
            sampleText.draw(in: textRect, withAttributes: attributes)
        }
    }
}

// MARK: - Viral Growth Tracking
extension SocialSharingManager {
    func trackShare(platform: String) {
        // Track sharing for analytics
        print("📊 Share tracked: \(platform)")
        // Add your analytics tracking here
    }
}
