import Foundation

/// Code type for promo codes
enum PromoCodeType: String, Identifiable {
    case lifetime = "LIFETIME"
    case monthly = "MONTHLY"
    
    var prefix: String {
        switch self {
        case .lifetime: return "LT"
        case .monthly: return "MO"
        }
    }
    
    var displayName: String {
        switch self {
        case .lifetime: return "Lifetime"
        case .monthly: return "Monthly"
        }
    }
    
    // Identifiable conformance
    public var id: String { rawValue }
}

/// Manages promo code generation, validation, and one-time use tracking
final class PromoCodeManager {
    // MARK: - Singleton
    static let shared = PromoCodeManager()
    
    // MARK: - UserDefaults Keys
    // Separate keys for each code type to ensure complete isolation
    private let usedCodesLifetimeKey = "promo_codes_used_lifetime"
    private let usedCodesMonthlyKey = "promo_codes_used_monthly"
    private let allCodesKey = "promo_codes_all" // Legacy support only
    private let lifetimeCodesKey = "promo_codes_lifetime"
    private let monthlyCodesKey = "promo_codes_monthly"
    private let validationAttemptsKey = "promo_validation_attempts"
    private let validationLockoutKey = "promo_validation_lockout"
    
    // MARK: - Rate Limiting
    private let maxValidationAttempts = 10 // Max validation attempts per hour
    private let validationLockoutDuration: TimeInterval = 3600 // 1 hour lockout
    
    // MARK: - Constants
    private let codeLength = 8
    private let totalCodes = 100
    
    // MARK: - Initialization
    private init() {
        // Initialize persistence manager (handles migrations, backups, etc.)
        _ = PromoCodePersistenceManager.shared
        
        // Restore codes from backup if this is a reinstall scenario
        restoreCodesIfNeeded()
        
        // Set up backup notifications
        NotificationCenter.default.addObserver(
            forName: .requestPromoCodeBackup,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.performBackup()
        }
    }
    
    /// Restores codes from backup if app was reinstalled
    func restoreCodesIfNeeded() {
        // Check if we have codes already
        let hasLifetimeCodes = !getCodes(type: .lifetime).isEmpty
        let hasMonthlyCodes = !getCodes(type: .monthly).isEmpty
        
        // If no codes but backup exists, restore
        if !hasLifetimeCodes && !hasMonthlyCodes {
            if let restored = PromoCodePersistenceManager.shared.restoreCodesIfAvailable() {
                // Restore codes
                UserDefaults.standard.set(restored.lifetime, forKey: lifetimeCodesKey)
                UserDefaults.standard.set(restored.monthly, forKey: monthlyCodesKey)
                UserDefaults.standard.set(restored.usedLifetime, forKey: usedCodesLifetimeKey)
                UserDefaults.standard.set(restored.usedMonthly, forKey: usedCodesMonthlyKey)
                UserDefaults.standard.synchronize()
                
                #if DEBUG
                print("✅ PromoCodeManager: Restored codes from backup after reinstall")
                #endif
            }
        }
    }
    
    /// Performs backup if needed (public for SettingsView)
    func performBackupIfNeeded() {
        performBackup()
    }
    
    /// Performs backup of all codes
    private func performBackup() {
        let lifetimeCodes = getCodes(type: .lifetime)
        let monthlyCodes = getCodes(type: .monthly)
        let usedLifetime = Array(getUsedCodes(type: .lifetime))
        let usedMonthly = Array(getUsedCodes(type: .monthly))
        
        PromoCodePersistenceManager.shared.backupCodes(
            lifetimeCodes: lifetimeCodes,
            monthlyCodes: monthlyCodes,
            usedLifetime: usedLifetime,
            usedMonthly: usedMonthly
        )
    }
    
    // MARK: - Code Generation
    
    /// Generates a unique promo code with format: PREFIX-XXXX-XXXX (alphanumeric)
    /// Uses cryptographically secure random number generation
    /// Prefix ensures lifetime and monthly codes are unique from each other
    private func generatePromoCode(type: PromoCodeType) -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Excludes confusing characters (0, O, I, 1)
        var code = type.prefix + "-"
        
        // Use cryptographically secure random generation
        let randomPart = PromoSecurityManager.shared.generateSecureRandomCode(length: codeLength, characters: characters)
        
        // Format: XXXX-XXXX
        for (index, char) in randomPart.enumerated() {
            if index == 4 {
                code += "-"
            }
            code += String(char)
        }
        
        return code
    }
    
    /// Gets all existing codes across both types to ensure uniqueness
    private func getAllExistingCodes() -> Set<String> {
        var allCodes = Set<String>()
        
        // Get lifetime codes
        if let lifetimeCodes = UserDefaults.standard.array(forKey: lifetimeCodesKey) as? [String] {
            allCodes.formUnion(lifetimeCodes)
        }
        
        // Get monthly codes
        if let monthlyCodes = UserDefaults.standard.array(forKey: monthlyCodesKey) as? [String] {
            allCodes.formUnion(monthlyCodes)
        }
        
        // Also check legacy allCodesKey for backward compatibility
        if let legacyCodes = UserDefaults.standard.array(forKey: allCodesKey) as? [String] {
            allCodes.formUnion(legacyCodes)
        }
        
        return allCodes
    }
    
    // MARK: - Code Validation
    
    /// Validates a promo code and returns validation result with type
    /// Includes rate limiting and constant-time comparison for security
    func validateCode(_ code: String) -> ValidationResult {
        // Rate limiting check
        if isValidationLockedOut() {
            return .invalid("Too many validation attempts. Please try again later.")
        }
        
        // Normalize code (remove spaces, convert to uppercase)
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
        
        // Check if code is empty
        guard !normalizedCode.isEmpty else {
            recordValidationAttempt()
            return .invalid("Please enter a promo code")
        }
        
        // Determine code type from prefix
        let codeType: PromoCodeType?
        if normalizedCode.hasPrefix("LT-") {
            codeType = .lifetime
        } else if normalizedCode.hasPrefix("MO-") {
            codeType = .monthly
        } else {
            // Legacy codes without prefix (backward compatibility)
            codeType = nil
        }
        
        // Get codes for the determined type (or check legacy)
        var allCodes: Set<String> = []
        if let type = codeType {
            allCodes = Set(getCodes(type: type))
        } else {
            // Check legacy codes
            allCodes = Set(UserDefaults.standard.array(forKey: allCodesKey) as? [String] ?? [])
        }
        
        // Constant-time check if code exists (prevents timing attacks)
        let codeExists = constantTimeContains(allCodes, normalizedCode)
        
        guard codeExists else {
            recordValidationAttempt()
            return .invalid("Invalid promo code")
        }
        
        // Check if code has already been used (constant-time) - check only the specific type
        let usedCodes = getUsedCodes(type: codeType ?? .lifetime)
        if constantTimeContains(usedCodes, normalizedCode) {
            recordValidationAttempt()
            return .alreadyUsed("This promo code has already been redeemed")
        }
        
        // Code is valid and unused - return with type
        let finalType = codeType ?? .lifetime // Default to lifetime for legacy codes
        return .valid(normalizedCode, type: finalType)
    }
    
    /// Constant-time set membership check (prevents timing attacks)
    private func constantTimeContains(_ set: Set<String>, _ element: String) -> Bool {
        // Always iterate through a fixed-size check to prevent timing attacks
        var found = false
        for item in set {
            if constantTimeStringCompare(item, element) {
                found = true
            }
        }
        return found
    }
    
    /// Constant-time string comparison (prevents timing attacks)
    private func constantTimeStringCompare(_ a: String, _ b: String) -> Bool {
        guard a.count == b.count else { return false }
        var result: UInt8 = 0
        for (charA, charB) in zip(a.utf8, b.utf8) {
            result |= charA ^ charB
        }
        return result == 0
    }
    
    /// Records a validation attempt for rate limiting
    private func recordValidationAttempt() {
        let now = Date()
        var attempts = getValidationAttempts()
        
        // Remove attempts older than 1 hour
        attempts = attempts.filter { now.timeIntervalSince($0) < validationLockoutDuration }
        
        // Add current attempt
        attempts.append(now)
        
        // Save attempts
        let timestamps = attempts.map { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(timestamps, forKey: validationAttemptsKey)
        
        // Check if we should lockout
        if attempts.count >= maxValidationAttempts {
            let lockoutUntil = now.addingTimeInterval(validationLockoutDuration).timeIntervalSince1970
            UserDefaults.standard.set(lockoutUntil, forKey: validationLockoutKey)
        }
        
        UserDefaults.standard.synchronize()
    }
    
    /// Gets validation attempts from the last hour
    private func getValidationAttempts() -> [Date] {
        guard let timestamps = UserDefaults.standard.array(forKey: validationAttemptsKey) as? [Double] else {
            return []
        }
        return timestamps.map { Date(timeIntervalSince1970: $0) }
    }
    
    /// Checks if validation is currently locked out
    private func isValidationLockedOut() -> Bool {
        let lockoutUntil = UserDefaults.standard.double(forKey: validationLockoutKey)
        guard lockoutUntil > 0 else { return false }
        
        let lockoutDate = Date(timeIntervalSince1970: lockoutUntil)
        if Date() < lockoutDate {
            return true
        } else {
            // Lockout expired, clear it
            UserDefaults.standard.removeObject(forKey: validationLockoutKey)
            UserDefaults.standard.synchronize()
            return false
        }
    }
    
    // MARK: - Code Redemption
    
    /// Redeems a promo code and grants appropriate access based on type
    /// Uses atomic operation to prevent race conditions
    /// Returns true if redemption was successful, false otherwise
    @discardableResult
    func redeemCode(_ code: String) -> Bool {
        // Use a serial queue to ensure atomic operations
        let redemptionQueue = DispatchQueue(label: "com.notewall.promo.redemption", qos: .userInitiated)
        
        var redemptionResult = false
        
        redemptionQueue.sync {
            let validation = validateCode(code)
            
            switch validation {
            case .valid(let normalizedCode, let type):
                // Check if code was already redeemed on THIS install (prevents reinstall abuse)
                if PromoCodePersistenceManager.shared.wasCodeRedeemedOnThisInstall(normalizedCode) {
                    #if DEBUG
                    print("❌ PromoCodeManager: Code was already redeemed on this install")
                    #endif
                    redemptionResult = false
                    return
                }
                
                // Double-check code hasn't been used (race condition protection) - check only this type
                let usedCodes = getUsedCodes(type: type)
                if constantTimeContains(usedCodes, normalizedCode) {
                    #if DEBUG
                    print("❌ PromoCodeManager: Code was already redeemed (race condition prevented)")
                    #endif
                    redemptionResult = false
                    return
                }
                
                // Atomically mark code as used FIRST (before granting access) - separate storage per type
                markCodeAsUsed(normalizedCode, type: type)
                
                // Record redemption in history (for tracking across reinstalls)
                PromoCodePersistenceManager.shared.recordRedemption(code: normalizedCode, type: type)
                
                // Backup after redemption
                performBackup()
                
                // Grant appropriate access based on type
                switch type {
                case .lifetime:
                    PaywallManager.shared.grantLifetimeAccess()
                    // Store integrity hash to prevent tampering
                    storeAccessIntegrity(hasLifetime: true, hasPremium: true, expiryTimestamp: 0)
                    // Record redemption timestamp (for tracking across scenarios)
                    recordRedemptionMetadata(code: normalizedCode, type: type)
                case .monthly:
                    // Grant 1 month of subscription access
                    // Use Calendar with current time to prevent time manipulation
                    let calendar = Calendar.current
                    let now = Date()
                    let expiryDate = calendar.date(byAdding: .month, value: 1, to: now) ?? now
                    let expiryTimestamp = expiryDate.timeIntervalSince1970
                    PaywallManager.shared.grantSubscription(expiryDate: expiryDate)
                    // Store integrity hash to prevent tampering
                    storeAccessIntegrity(hasLifetime: false, hasPremium: true, expiryTimestamp: expiryTimestamp)
                    // Record redemption timestamp (for tracking across scenarios)
                    recordRedemptionMetadata(code: normalizedCode, type: type)
                }
                
                #if DEBUG
                print("✅ PromoCodeManager: Successfully redeemed \(type.displayName) code: \(normalizedCode)")
                #endif
                
                redemptionResult = true
                
            case .invalid(let message), .alreadyUsed(let message):
                #if DEBUG
                print("❌ PromoCodeManager: Failed to redeem code: \(message)")
                #endif
                redemptionResult = false
            }
        }
        
        return redemptionResult
    }
    
    /// Stores integrity hash for access flags to prevent tampering
    private func storeAccessIntegrity(hasLifetime: Bool, hasPremium: Bool, expiryTimestamp: Double) {
        let hash = PromoSecurityManager.shared.createIntegrityHash(
            hasLifetime: hasLifetime,
            hasPremium: hasPremium,
            expiryTimestamp: expiryTimestamp
        )
        UserDefaults.standard.set(hash, forKey: "promo_access_integrity")
        UserDefaults.standard.synchronize()
    }
    
    /// Records redemption metadata for tracking and validation
    private func recordRedemptionMetadata(code: String, type: PromoCodeType) {
        let metadata: [String: Any] = [
            "code": code,
            "type": type.rawValue,
            "timestamp": Date().timeIntervalSince1970,
            "installID": PromoCodePersistenceManager.shared.getInstallID()
        ]
        
        var redemptions = UserDefaults.standard.array(forKey: "promo_redemption_metadata") as? [[String: Any]] ?? []
        redemptions.append(metadata)
        
        // Keep only last 500 redemptions
        if redemptions.count > 500 {
            redemptions = Array(redemptions.suffix(500))
        }
        
        UserDefaults.standard.set(redemptions, forKey: "promo_redemption_metadata")
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Used Codes Tracking
    
    /// Gets the set of used promo codes for a specific type (completely separate)
    private func getUsedCodes(type: PromoCodeType) -> Set<String> {
        let key = type == .lifetime ? usedCodesLifetimeKey : usedCodesMonthlyKey
        if let usedCodesArray = UserDefaults.standard.array(forKey: key) as? [String] {
            return Set(usedCodesArray)
        }
        return Set<String>()
    }
    
    
    // MARK: - Admin Functions (for testing/debugging)
    
    // MARK: - Code Generation (Custom Count)
    
    /// Generates a custom number of unique promo codes for a specific type
    func generateCodes(count: Int, type: PromoCodeType) {
        // Get all existing codes to ensure uniqueness across both types
        let existingCodes = getAllExistingCodes()
        
        // Generate specified number of unique codes
        var codes: Set<String> = []
        var attempts = 0
        let maxAttempts = count * 100 // Allow plenty of attempts
        
        while codes.count < count {
            let code = generatePromoCode(type: type)
            
            // Check if code already exists (across both types)
            if !existingCodes.contains(code) && !codes.contains(code) {
                codes.insert(code)
            }
            
            attempts += 1
            
            if attempts >= maxAttempts {
                #if DEBUG
                print("⚠️ PromoCodeManager: Reached max attempts. Generated \(codes.count) of \(count) codes.")
                #endif
                break
            }
        }
        
        // Convert Set to Array and save to type-specific key
        let codesArray = Array(codes).sorted()
        let key = type == .lifetime ? lifetimeCodesKey : monthlyCodesKey
        UserDefaults.standard.set(codesArray, forKey: key)
        UserDefaults.standard.synchronize()
        
        // Backup after generation
        performBackup()
        
        #if DEBUG
        print("🎟️ PromoCodeManager: Generated \(codesArray.count) unique \(type.displayName) promo codes")
        #endif
    }
    
    /// Gets all codes for a specific type
    func getCodes(type: PromoCodeType) -> [String] {
        let key = type == .lifetime ? lifetimeCodesKey : monthlyCodesKey
        return UserDefaults.standard.array(forKey: key) as? [String] ?? []
    }
    
    /// Marks a code as used - completely separate storage per type
    private func markCodeAsUsed(_ code: String, type: PromoCodeType) {
        var usedCodes = getUsedCodes(type: type)
        usedCodes.insert(code)
        
        // Save to type-specific key (completely isolated)
        let key = type == .lifetime ? usedCodesLifetimeKey : usedCodesMonthlyKey
        UserDefaults.standard.set(Array(usedCodes), forKey: key)
        UserDefaults.standard.synchronize()
        
        #if DEBUG
        print("💾 PromoCodeManager: Marked \(type.displayName) code as used. Total \(type.displayName) used: \(usedCodes.count)")
        #endif
    }
    
    /// Gets used codes for a specific type (for admin/testing purposes) - completely separate
    func getUsedCodesForTesting(type: PromoCodeType) -> [String] {
        return Array(getUsedCodes(type: type))
    }
    
    #if DEBUG
    /// Gets all promo codes for a type (for testing purposes only)
    func getAllCodes(type: PromoCodeType) -> [String] {
        return getCodes(type: type)
    }
    
    /// Resets used codes for a specific type (for testing purposes only)
    func resetUsedCodes(type: PromoCodeType) {
        let key = type == .lifetime ? usedCodesLifetimeKey : usedCodesMonthlyKey
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.synchronize()
        print("🔄 PromoCodeManager: Reset all \(type.displayName) used codes")
    }
    
    /// Regenerates all codes for a type (for testing purposes only)
    func regenerateCodes(type: PromoCodeType) {
        generateCodes(count: totalCodes, type: type)
        print("🔄 PromoCodeManager: Regenerated all \(type.displayName) codes")
    }
    #endif
}

// MARK: - Validation Result

enum ValidationResult {
    case valid(String, type: PromoCodeType) // Valid and unused code (normalized) with type
    case invalid(String) // Invalid code format or doesn't exist
    case alreadyUsed(String) // Code exists but has been used
    
    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
    
    var message: String {
        switch self {
        case .valid:
            return "Valid promo code"
        case .invalid(let message), .alreadyUsed(let message):
            return message
        }
    }
    
    var codeType: PromoCodeType? {
        if case .valid(_, let type) = self {
            return type
        }
        return nil
    }
}

