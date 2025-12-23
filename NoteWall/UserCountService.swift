import Foundation
import SwiftUI
import Combine

// MARK: - User Count Service
/// Fetches and caches real-time user count from backend API
/// Falls back to cached value or estimated count if API is unavailable

final class UserCountService: ObservableObject {
    static let shared = UserCountService()
    
    // MARK: - Published Properties
    @Published private(set) var currentCount: Int = 57 // Default fallback
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastUpdateTime: Date?
    @Published private(set) var fetchError: String?
    
    // MARK: - AppStorage for persistence
    @AppStorage("cachedUserCount") private var cachedUserCount: Int = 57
    @AppStorage("userCountLastFetch") private var lastFetchTimestamp: Double = 0
    @AppStorage("userCountBaseValue") private var baseValue: Int = 80 // Your real download count
    
    // MARK: - Configuration
    private let cacheValidityDuration: TimeInterval = 3600 // 1 hour cache
    private let minimumDisplayCount: Int = 50 // Never show less than this
    
    // MARK: - Computed Properties
    
    /// Estimated count based on base value with slight variation
    /// This provides a realistic number even when API is unavailable
    var estimatedCount: Int {
        // Apply a slight reduction (70-85% of total downloads)
        // to represent "active focused users" rather than total downloads
        let activeUserRatio = Double.random(in: 0.70...0.85)
        let estimated = Int(Double(baseValue) * activeUserRatio)
        return max(minimumDisplayCount, estimated)
    }
    
    /// Whether cached data is still valid
    var isCacheValid: Bool {
        guard lastFetchTimestamp > 0 else { return false }
        let cacheAge = Date().timeIntervalSince1970 - lastFetchTimestamp
        return cacheAge < cacheValidityDuration
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load cached value or use estimated
        if cachedUserCount > 0 && isCacheValid {
            currentCount = cachedUserCount
        } else {
            currentCount = estimatedCount
        }
    }
    
    // MARK: - Public Methods
    
    /// Fetch latest count from API or return cached/estimated value
    @MainActor
    func fetchUserCount() async -> Int {
        // Return cached if still valid
        if isCacheValid {
            currentCount = cachedUserCount
            return currentCount
        }
        
        isLoading = true
        fetchError = nil
        
        // Try to fetch from API
        if let apiURL = Config.userCountAPIURL, let url = URL(string: apiURL) {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    
                    // Try to parse JSON response
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let count = json["count"] as? Int {
                        updateCache(with: count)
                        isLoading = false
                        return count
                    }
                    
                    // Try plain text number
                    if let countString = String(data: data, encoding: .utf8),
                       let count = Int(countString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        updateCache(with: count)
                        isLoading = false
                        return count
                    }
                }
            } catch {
                #if DEBUG
                print("📊 UserCountService: API fetch failed - \(error.localizedDescription)")
                #endif
                fetchError = error.localizedDescription
            }
        }
        
        // Fallback to estimated count
        let estimated = estimatedCount
        currentCount = estimated
        isLoading = false
        
        #if DEBUG
        print("📊 UserCountService: Using estimated count - \(estimated)")
        #endif
        
        return estimated
    }
    
    /// Update the base value (call this when you know the real download count)
    func updateBaseCount(_ count: Int) {
        baseValue = count
        // Recalculate current count if cache is stale
        if !isCacheValid {
            currentCount = estimatedCount
        }
    }
    
    /// Force refresh from API
    @MainActor
    func forceRefresh() async -> Int {
        lastFetchTimestamp = 0 // Invalidate cache
        return await fetchUserCount()
    }
    
    // MARK: - Private Methods
    
    private func updateCache(with count: Int) {
        let validCount = max(minimumDisplayCount, count)
        cachedUserCount = validCount
        currentCount = validCount
        lastFetchTimestamp = Date().timeIntervalSince1970
        lastUpdateTime = Date()
        
        #if DEBUG
        print("📊 UserCountService: Updated cache with count - \(validCount)")
        #endif
    }
}

// MARK: - Preview Helper
#if DEBUG
extension UserCountService {
    static var preview: UserCountService {
        let service = UserCountService.shared
        service.currentCount = 85
        return service
    }
}
#endif
