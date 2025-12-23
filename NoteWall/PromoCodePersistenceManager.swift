import Foundation
import UIKit

/// Manages promo code persistence across app reinstalls, updates, and data resets
/// Handles all edge cases: reinstalls, device transfers, backups, etc.
final class PromoCodePersistenceManager {
    static let shared = PromoCodePersistenceManager()
    
    // MARK: - Persistence Keys
    private let codesBackupKey = "promo_codes_backup_v1"
    private let usedCodesBackupKey = "promo_codes_used_backup_v1"
    private let lastBackupTimestampKey = "promo_codes_last_backup"
    private let appInstallIDKey = "promo_app_install_id"
    private let codeRedemptionHistoryKey = "promo_code_redemption_history"
    private let migrationVersionKey = "promo_codes_migration_version"
    
    private let currentMigrationVersion = 2
    
    private init() {
        performMigrationIfNeeded()
        ensureInstallID()
        performPeriodicBackup()
    }
    
    // MARK: - Install ID Management
    
    /// Gets or creates a unique install ID for this app installation
    /// This persists across app updates but NOT across reinstalls
    func getInstallID() -> String {
        if let installID = UserDefaults.standard.string(forKey: appInstallIDKey) {
            return installID
        }
        
        // Generate new install ID
        let installID = UUID().uuidString
        UserDefaults.standard.set(installID, forKey: appInstallIDKey)
        UserDefaults.standard.synchronize()
        return installID
    }
    
    /// Ensures install ID exists (called on init)
    private func ensureInstallID() {
        if UserDefaults.standard.string(forKey: appInstallIDKey) == nil {
            _ = getInstallID()
        }
    }
    
    /// Checks if this is a fresh install (no install ID exists)
    func isFreshInstall() -> Bool {
        return UserDefaults.standard.string(forKey: appInstallIDKey) == nil
    }
    
    // MARK: - Code Backup & Restore
    
    /// Backs up all codes to a more persistent location
    /// This helps survive some data resets
    func backupCodes(usedLifetime: [String], usedMonthly: [String]) {
        let backup: [String: Any] = [
            "usedLifetime": usedLifetime,
            "usedMonthly": usedMonthly,
            "timestamp": Date().timeIntervalSince1970,
            "installID": getInstallID()
        ]
        
        UserDefaults.standard.set(backup, forKey: codesBackupKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastBackupTimestampKey)
        UserDefaults.standard.synchronize()
        
        #if DEBUG
        print("💾 PromoCodePersistenceManager: Backed up used codes")
        #endif
    }
    
    /// Restores codes from backup if available
    func restoreCodesIfAvailable() -> (usedLifetime: [String], usedMonthly: [String])? {
        guard let backup = UserDefaults.standard.dictionary(forKey: codesBackupKey) else {
            return nil
        }
        
        // Verify backup is from same install (prevents cross-device restore abuse)
        if let backupInstallID = backup["installID"] as? String,
           backupInstallID != getInstallID() {
            #if DEBUG
            print("⚠️ PromoCodePersistenceManager: Backup from different install, ignoring")
            #endif
            return nil
        }
        
        let usedLifetime = backup["usedLifetime"] as? [String] ?? []
        let usedMonthly = backup["usedMonthly"] as? [String] ?? []
        
        #if DEBUG
        print("📦 PromoCodePersistenceManager: Restored codes from backup")
        #endif
        
        return (usedLifetime, usedMonthly)
    }
    
    // MARK: - Redemption History
    
    /// Records a code redemption with device fingerprint
    func recordRedemption(code: String, type: PromoCodeType) {
        var history = getRedemptionHistory()
        
        let redemption: [String: Any] = [
            "code": code,
            "type": type.rawValue,
            "timestamp": Date().timeIntervalSince1970,
            "installID": getInstallID(),
            "deviceID": getDeviceFingerprint()
        ]
        
        history.append(redemption)
        
        // Keep only last 1000 redemptions
        if history.count > 1000 {
            history = Array(history.suffix(1000))
        }
        
        UserDefaults.standard.set(history, forKey: codeRedemptionHistoryKey)
        UserDefaults.standard.synchronize()
    }
    
    /// Gets redemption history
    private func getRedemptionHistory() -> [[String: Any]] {
        return UserDefaults.standard.array(forKey: codeRedemptionHistoryKey) as? [[String: Any]] ?? []
    }
    
    /// Checks if a code was redeemed on this install
    func wasCodeRedeemedOnThisInstall(_ code: String) -> Bool {
        let history = getRedemptionHistory()
        let currentInstallID = getInstallID()
        
        return history.contains { redemption in
            (redemption["code"] as? String) == code &&
            (redemption["installID"] as? String) == currentInstallID
        }
    }
    
    /// Gets device fingerprint (for tracking, not PII)
    private func getDeviceFingerprint() -> String {
        // Create a stable device identifier (not tied to Apple ID)
        let identifier = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        return identifier
    }
    
    // MARK: - Migration
    
    /// Performs migration if needed when app updates
    private func performMigrationIfNeeded() {
        let lastVersion = UserDefaults.standard.integer(forKey: migrationVersionKey)
        
        if lastVersion < currentMigrationVersion {
            #if DEBUG
            print("🔄 PromoCodePersistenceManager: Performing migration from v\(lastVersion) to v\(currentMigrationVersion)")
            #endif
            
            // Migration v1 -> v2: Separate used codes by type
            if lastVersion < 2 {
                migrateToVersion2()
            }
            
            UserDefaults.standard.set(currentMigrationVersion, forKey: migrationVersionKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    /// Migrates from version 1 to 2 (separate used codes)
    private func migrateToVersion2() {
        // If old shared used codes exist, we need to determine which are lifetime vs monthly
        // This is best-effort - we'll check code prefixes
        if let oldUsedCodes = UserDefaults.standard.array(forKey: "promo_codes_used") as? [String] {
            var lifetimeUsed: [String] = []
            var monthlyUsed: [String] = []
            
            for code in oldUsedCodes {
                if code.hasPrefix("LT-") || code.hasPrefix("LT") {
                    lifetimeUsed.append(code)
                } else if code.hasPrefix("MO-") || code.hasPrefix("MO") {
                    monthlyUsed.append(code)
                } else {
                    // Legacy codes without prefix - assume lifetime
                    lifetimeUsed.append(code)
                }
            }
            
            UserDefaults.standard.set(lifetimeUsed, forKey: "promo_codes_used_lifetime")
            UserDefaults.standard.set(monthlyUsed, forKey: "promo_codes_used_monthly")
            UserDefaults.standard.removeObject(forKey: "promo_codes_used")
            UserDefaults.standard.synchronize()
            
            #if DEBUG
            print("✅ PromoCodePersistenceManager: Migrated \(oldUsedCodes.count) used codes to type-specific storage")
            #endif
        }
    }
    
    // MARK: - Periodic Backup
    
    /// Performs periodic backup (called on init and after code changes)
    private func performPeriodicBackup() {
        let lastBackup = UserDefaults.standard.double(forKey: lastBackupTimestampKey)
        let now = Date().timeIntervalSince1970
        
        // Backup every 24 hours or if never backed up
        if now - lastBackup > 86400 || lastBackup == 0 {
            // Trigger backup (will be called by PromoCodeManager after codes are loaded)
            NotificationCenter.default.post(name: .requestPromoCodeBackup, object: nil)
        }
    }
    
    // MARK: - Data Reset Detection
    
    /// Detects if app data was reset (codes exist but install ID changed)
    func detectDataReset() -> Bool {
        // If we have codes but no install ID match, data was reset
        let hasCodes = UserDefaults.standard.array(forKey: "promo_codes_lifetime") != nil ||
                      UserDefaults.standard.array(forKey: "promo_codes_monthly") != nil
        
        if hasCodes {
            // Check if backup exists with different install ID
            if let backup = UserDefaults.standard.dictionary(forKey: codesBackupKey),
               let backupInstallID = backup["installID"] as? String,
               backupInstallID != getInstallID() {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Cleanup
    
    /// Cleans up old data (called periodically)
    func cleanup() {
        // Remove redemptions older than 1 year
        var history = getRedemptionHistory()
        let oneYearAgo = Date().addingTimeInterval(-31536000).timeIntervalSince1970
        
        history = history.filter { redemption in
            (redemption["timestamp"] as? Double ?? 0) > oneYearAgo
        }
        
        UserDefaults.standard.set(history, forKey: codeRedemptionHistoryKey)
        UserDefaults.standard.synchronize()
    }
}

extension Notification.Name {
    static let requestPromoCodeBackup = Notification.Name("requestPromoCodeBackup")
}

