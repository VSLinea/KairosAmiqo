//
//  StoreKitManager.swift
//  KairosAmiqo
//
//  Created by AI Agent on 2025-11-03.
//  Task 29: Billing & In-App Purchases
//  Pricing: $6.99/mo, $59/yr (15% discount)
//

import Foundation
import StoreKit

/// Manages StoreKit 2 in-app purchases for Plus tier subscriptions
/// - Monthly Plus: $6.99/month (com.kairos.amiqo.plus.monthly)
/// - Yearly Plus: $59/year (com.kairos.amiqo.plus.yearly)
@MainActor
class StoreKitManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var availableProducts: [Product] = []
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: String? = nil
    
    // MARK: - Product IDs (App Store Connect Configuration)
    
    enum ProductID: String, CaseIterable {
        case monthlyPlus = "com.kairos.amiqo.plus.monthly"  // $6.99/month
        case yearlyPlus = "com.kairos.amiqo.plus.yearly"    // $59/year (15% discount)
        
        var displayName: String {
            switch self {
            case .monthlyPlus: return "Plus - Monthly"
            case .yearlyPlus: return "Plus - Annual"
            }
        }
    }
    
    // MARK: - Subscription Status
    
    enum SubscriptionStatus: Equatable {
        case free
        case plus(period: SubscriptionPeriod)
        case expired
        case unknown
        
        var isPlusUser: Bool {
            if case .plus = self { return true }
            return false
        }
        
        var displayName: String {
            switch self {
            case .free: return "Free"
            case .plus(let period): return "Plus (\(period.displayName))"
            case .expired: return "Expired"
            case .unknown: return "Unknown"
            }
        }
    }
    
    enum SubscriptionPeriod: Equatable {
        case monthly
        case yearly
        
        var displayName: String {
            switch self {
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }
    }
    
    // MARK: - Transaction Listener Task
    
    private var transactionListenerTask: Task<Void, Error>?
    
    // MARK: - Initialization
    
    init() {
        // Start listening for transaction updates
        transactionListenerTask = listenForTransactions()
        
        // Load initial subscription status
        Task {
            await checkSubscriptionStatus()
            await loadProducts()
        }
    }
    
    deinit {
        transactionListenerTask?.cancel()
    }
    
    // MARK: - Transaction Listener
    
    /// Listen for transaction updates from App Store
    /// This handles purchases made on other devices or subscription renewals
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    
                    // Update subscription status
                    await self.updateSubscriptionStatus(from: transaction)
                    
                    // Finish the transaction
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Product Loading
    
    /// Fetch available products from App Store
    func loadProducts() async {
        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            let products = try await Product.products(for: productIDs)
            
            // Sort by price (monthly first, then yearly)
            availableProducts = products.sorted { $0.price < $1.price }
            
            print("✅ Loaded \(products.count) products")
        } catch {
            print("❌ Failed to load products: \(error)")
            purchaseError = "Failed to load products. Please try again."
        }
    }
    
    // MARK: - Subscription Status Check
    
    /// Check current subscription status from App Store
    func checkSubscriptionStatus() async {
        var highestStatus: SubscriptionStatus = .free
        var latestDate: Date = .distantPast
        
        // Check all subscription groups
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Determine subscription period
                let period = determinePeriod(from: transaction)
                
                // Keep the latest/highest status
                if let expirationDate = transaction.expirationDate {
                    if expirationDate > latestDate {
                        latestDate = expirationDate
                        
                        if expirationDate > Date() {
                            highestStatus = .plus(period: period)
                        } else {
                            highestStatus = .expired
                        }
                    }
                } else {
                    // No expiration date (shouldn't happen for subscriptions)
                    highestStatus = .plus(period: period)
                }
            } catch {
                print("Transaction verification failed: \(error)")
                highestStatus = .unknown
            }
        }
        
        subscriptionStatus = highestStatus
        print("📊 Subscription status: \(highestStatus.displayName)")
    }
    
    // MARK: - Purchase Flow
    
    /// Purchase a subscription product
    func purchase(_ product: Product) async throws {
        guard !isPurchasing else {
            throw StoreError.purchaseInProgress
        }
        
        isPurchasing = true
        purchaseError = nil
        
        defer {
            isPurchasing = false
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Verify the transaction
                let transaction = try checkVerified(verification)
                
                // Update subscription status
                await updateSubscriptionStatus(from: transaction)
                
                // Finish the transaction
                await transaction.finish()
                
                print("✅ Purchase successful: \(product.displayName)")
                
            case .userCancelled:
                print("⚠️ User cancelled purchase")
                throw StoreError.userCancelled
                
            case .pending:
                print("⏳ Purchase pending approval")
                throw StoreError.pendingApproval
                
            @unknown default:
                print("❌ Unknown purchase result")
                throw StoreError.unknown
            }
        } catch {
            purchaseError = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Restore Purchases
    
    /// Restore previous purchases
    func restorePurchases() async throws {
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            print("✅ Purchases restored")
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            purchaseError = "Failed to restore purchases. Please try again."
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    /// Verify transaction signature
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    /// Determine subscription period from transaction
    private func determinePeriod(from transaction: Transaction) -> SubscriptionPeriod {
        if transaction.productID == ProductID.monthlyPlus.rawValue {
            return .monthly
        } else if transaction.productID == ProductID.yearlyPlus.rawValue {
            return .yearly
        } else {
            return .monthly // Default fallback
        }
    }
    
    /// Update subscription status from transaction
    private func updateSubscriptionStatus(from transaction: Transaction) async {
        let period = determinePeriod(from: transaction)
        
        // Check if transaction is still valid
        if let expirationDate = transaction.expirationDate {
            if expirationDate > Date() {
                subscriptionStatus = .plus(period: period)
            } else {
                subscriptionStatus = .expired
            }
        } else {
            subscriptionStatus = .plus(period: period)
        }
    }
    
    // MARK: - Store Errors
    
    enum StoreError: LocalizedError {
        case failedVerification
        case userCancelled
        case pendingApproval
        case purchaseInProgress
        case unknown
        
        var errorDescription: String? {
            switch self {
            case .failedVerification:
                return "Purchase verification failed. Please contact support."
            case .userCancelled:
                return "Purchase cancelled."
            case .pendingApproval:
                return "Purchase pending approval. Please check back later."
            case .purchaseInProgress:
                return "A purchase is already in progress."
            case .unknown:
                return "An unknown error occurred. Please try again."
            }
        }
    }
}
