import Foundation
import StoreKit

/// Manages in-app purchases using StoreKit 2
@available(iOS 15.0, *)
class StoreKitManager: ObservableObject {
    // MARK: - Singleton
    static let shared = StoreKitManager()
    
    // MARK: - Product IDs
    // TODO: Replace these with your actual App Store Connect product IDs
    enum ProductID: String, CaseIterable {
        case monthlySubscription = "com.notewall.monthly.subscription"
        case lifetimePurchase = "com.notewall.lifetime.purchase"
        
        var displayName: String {
            switch self {
            case .monthlySubscription:
                return "Monthly Subscription"
            case .lifetimePurchase:
                return "Lifetime Access"
            }
        }
    }
    
    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: - Initialization
    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    
    /// Load products from App Store
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            let loadedProducts = try await Product.products(for: productIDs)
            
            await MainActor.run {
                self.products = loadedProducts.sorted { product1, product2 in
                    // Sort: monthly subscription first, then lifetime
                    if product1.id == ProductID.monthlySubscription.rawValue {
                        return true
                    }
                    return false
                }
                self.isLoading = false
            }
            
            print("✅ StoreKit: Loaded \(loadedProducts.count) products")
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load products: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("❌ StoreKit: Failed to load products: \(error)")
        }
    }
    
    // MARK: - Purchase
    
    /// Purchase a product
    func purchase(_ product: Product) async throws -> Transaction? {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let result = try await product.purchase()
            
            await MainActor.run {
                isLoading = false
            }
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedProducts()
                await transaction.finish()
                
                // Grant access based on product type
                await grantAccess(for: product)
                
                print("✅ StoreKit: Purchase successful for \(product.id)")
                return transaction
                
            case .userCancelled:
                print("ℹ️ StoreKit: User cancelled purchase")
                return nil
                
            case .pending:
                print("⏳ StoreKit: Purchase pending")
                return nil
                
            @unknown default:
                print("⚠️ StoreKit: Unknown purchase result")
                return nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Purchase failed: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("❌ StoreKit: Purchase failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Restore Purchases
    
    /// Restore previous purchases
    func restorePurchases() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            
            await MainActor.run {
                isLoading = false
            }
            
            print("✅ StoreKit: Purchases restored")
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("❌ StoreKit: Failed to restore: \(error)")
        }
    }
    
    // MARK: - Transaction Handling
    
    /// Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                    print("✅ StoreKit: Transaction updated: \(transaction.productID)")
                } catch {
                    print("❌ StoreKit: Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    /// Update the list of purchased products
    private func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchasedIDs.insert(transaction.productID)
                
                // Grant access based on transaction
                if let product = products.first(where: { $0.id == transaction.productID }) {
                    await grantAccess(for: product)
                }
            } catch {
                print("❌ StoreKit: Failed to verify transaction: \(error)")
            }
        }
        
        await MainActor.run {
            self.purchasedProductIDs = purchasedIDs
        }
        
        print("✅ StoreKit: Updated purchased products: \(purchasedIDs)")
    }
    
    /// Verify transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Access Management
    
    /// Grant access based on product
    private func grantAccess(for product: Product) async {
        await MainActor.run {
            if product.id == ProductID.lifetimePurchase.rawValue {
                PaywallManager.shared.grantLifetimeAccess()
            } else if product.id == ProductID.monthlySubscription.rawValue {
                // Grant subscription for 1 month + 5 days trial
                let expiryDate = Calendar.current.date(byAdding: .day, value: 35, to: Date()) ?? Date()
                PaywallManager.shared.grantSubscription(expiryDate: expiryDate)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if user has purchased a specific product
    func hasPurchased(_ productID: ProductID) -> Bool {
        return purchasedProductIDs.contains(productID.rawValue)
    }
    
    /// Get product by ID
    func product(for productID: ProductID) -> Product? {
        return products.first { $0.id == productID.rawValue }
    }
}

// MARK: - Store Error

enum StoreError: Error {
    case failedVerification
    
    var localizedDescription: String {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        }
    }
}
