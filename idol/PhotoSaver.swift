import UIKit
import Photos
import SwiftUI

struct PhotoSaver {
    static func saveImage(_ image: UIImage, completion: @escaping (Bool, String?) -> Void) {
        // Check if user wants to save to Photos library
        let saveToPhotos = UserDefaults.standard.bool(forKey: "saveWallpapersToPhotos")
        
        if !saveToPhotos {
            // User opted to skip Photos library - return success without saving
            print("📸 PhotoSaver: Skipping Photos library save (user preference)")
            DispatchQueue.main.async {
                completion(true, nil)
            }
            return
        }
        
        // Check authorization status
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .authorized, .limited:
            performSave(image, completion: completion)

        case .notDetermined:
            // Request permission
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        performSave(image, completion: completion)
                    } else {
                        completion(false, nil)
                    }
                }
            }

        case .denied, .restricted:
            DispatchQueue.main.async {
                completion(false, nil)
            }

        @unknown default:
            DispatchQueue.main.async {
                completion(false, nil)
            }
        }
    }
    
    static func deleteAsset(withIdentifier identifier: String, completion: @escaping (Bool) -> Void) {
        // Check if user wants to save to Photos library
        let saveToPhotos = UserDefaults.standard.bool(forKey: "saveWallpapersToPhotos")
        
        if !saveToPhotos {
            // User opted to skip Photos library - nothing to delete
            print("🗑️ PhotoSaver: Skipping deletion (user preference - not saving to Photos)")
            DispatchQueue.main.async {
                completion(true)
            }
            return
        }
        
        // Always request permission to ensure the system dialog shows
        // This is important for user awareness, even if permission was previously granted
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    // Permission granted, proceed with deletion
                    // iOS will show a confirmation dialog when deleting
                    performDelete(identifier: identifier, completion: completion)
                    
                case .denied, .restricted:
                    completion(false)
                    
                case .notDetermined:
                    // This shouldn't happen after requestAuthorization, but handle it
                    completion(false)
                    
                @unknown default:
                    completion(false)
                }
            }
        }
    }
    
    private static func performDelete(identifier: String, completion: @escaping (Bool) -> Void) {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        
        guard fetchResult.count > 0 else {
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }
        
        let asset = fetchResult.firstObject!
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error deleting asset: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(success)
                }
            }
        }
    }

    private static func performSave(_ image: UIImage, completion: @escaping (Bool, String?) -> Void) {
        var assetIdentifier: String?
        
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            assetIdentifier = request.placeholderForCreatedAsset?.localIdentifier
        }) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error saving image: \(error.localizedDescription)")
                    CrashReporter.logPhotoSaveError(error)
                    completion(false, nil)
                } else {
                    completion(success, assetIdentifier)
                }
            }
        }
    }
}
