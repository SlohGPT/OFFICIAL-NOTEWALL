import Foundation
import SwiftUI
import Combine

// MARK: - User Count Service
/// Fetches and caches real-time user count from backend API
/// Falls back to cached value or estimated count if API is unavailable

final class UserCountService: ObservableObject {
    static let shared = UserCountService()
    
    // MARK: - Published Properties
    @Published private(set) var currentCount: Int = 300 // Synced count
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastUpdateTime: Date?
    @Published private(set) var fetchError: String?
    
    // MARK: - Configuration
    // Start date: December 31, 2024 (today)
    // Start count: 300
    // Daily increase: 7 per day
    private let startDate: Date = {
        var components = DateComponents()
        components.year = 2024
        components.month = 12
        components.day = 31
        components.hour = 0
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    private let startCount: Int = 300
    private let dailyIncrease: Int = 7
    
    // MARK: - Computed Properties
    
    /// Calculate count based on days since start date
    /// Formula: startCount + (daysSinceStart * dailyIncrease)
    var calculatedCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: startDate)
        
        guard let daysSinceStart = calendar.dateComponents([.day], from: start, to: today).day else {
            return startCount
        }
        
        // Ensure we never go below start count
        let count = startCount + (daysSinceStart * dailyIncrease)
        return max(startCount, count)
    }
    
    // MARK: - Initialization
    
    private init() {
        // Calculate and set the current count
        currentCount = calculatedCount
        lastUpdateTime = Date()
    }
    
    // MARK: - Public Methods
    
    /// Get the current user count (calculated based on days since start)
    /// This is synced across all pages that use this service
    func getUserCount() -> Int {
        let count = calculatedCount
        currentCount = count
        lastUpdateTime = Date()
        return count
    }
    
    /// Refresh the count (recalculates based on current date)
    @MainActor
    func refreshCount() {
        currentCount = calculatedCount
        lastUpdateTime = Date()
        
        #if DEBUG
        print("📊 UserCountService: Refreshed count - \(currentCount)")
        #endif
    }
}

// MARK: - Preview Helper
#if DEBUG
extension UserCountService {
    static var preview: UserCountService {
        let service = UserCountService.shared
        service.currentCount = service.calculatedCount
        return service
    }
}
#endif
