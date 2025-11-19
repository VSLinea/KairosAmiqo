import Foundation
import CryptoKit

/// Cache layer for AI proposal responses
/// - Uses UserDefaults for MVP simplicity (can migrate to Core Data later)
/// - TTL: 24 hours (configurable)
/// - Max size: 100 cached responses (FIFO eviction)
/// - Key: SHA256 hash of (intent + participants + constraints)
class AIResponseCache {
    private let userDefaults = UserDefaults.standard
    private let maxCacheSize = 100
    private let cachePrefix = "ai_cache_"
    
    /// Retrieve cached AI proposal if available and not expired
    func get(key: String) -> AIProposal? {
        let cacheKey = cachePrefix + hashKey(key)
        guard let data = userDefaults.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(CachedResponse.self, from: data) else {
            return nil
        }
        
        // Check TTL expiration
        if Date().timeIntervalSince(cached.timestamp) > cached.ttl {
            userDefaults.removeObject(forKey: cacheKey)
            return nil
        }
        
        return cached.proposal
    }
    
    /// Cache an AI proposal with configurable TTL
    /// - Parameters:
    ///   - key: Cache key (will be hashed)
    ///   - value: AI proposal to cache
    ///   - ttl: Time-to-live in seconds (default: 24 hours)
    func set(key: String, value: AIProposal, ttl: TimeInterval = 86400) {
        let cacheKey = cachePrefix + hashKey(key)
        let cached = CachedResponse(proposal: value, timestamp: Date(), ttl: ttl)
        
        if let data = try? JSONEncoder().encode(cached) {
            userDefaults.set(data, forKey: cacheKey)
            evictOldestIfNeeded()
        }
    }
    
    /// Hash a key using SHA256 for consistent cache lookups
    private func hashKey(_ key: String) -> String {
        let data = Data(key.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Evict oldest cache entries if over max size (simple FIFO for MVP)
    private func evictOldestIfNeeded() {
        let allKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(cachePrefix) }
        if allKeys.count > maxCacheSize {
            // Remove oldest entries (simple FIFO for MVP)
            let toRemove = allKeys.prefix(allKeys.count - maxCacheSize)
            toRemove.forEach { userDefaults.removeObject(forKey: $0) }
        }
    }
    
    /// Clear all cached AI responses (for testing/debugging)
    func clearAll() {
        let allKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(cachePrefix) }
        allKeys.forEach { userDefaults.removeObject(forKey: $0) }
    }
}

/// Internal cached response wrapper
private struct CachedResponse: Codable {
    let proposal: AIProposal
    let timestamp: Date
    let ttl: TimeInterval
}
