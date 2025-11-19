import Foundation

/// Cache manager for offline-first sync strategy
/// 
/// **Strategy:** Cache dirty items only (pending sync to server)
/// - User creates plan → Save locally + cache as pending
/// - Sync to server → Server confirms → Remove from cache immediately
/// - Cache cleanup: Remove synced items + age-based cleanup (>7 days)
/// 
/// **Memory Management:** Cache only unsynced items, not server-fetched data
/// 
/// See: /docs/00-CANONICAL/backend-apis.md §Negotiations (Plans) → Data Persistence & Sync Strategy
class CacheManager {
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "kairos_pending_sync"
    
    /// Sync status for cached items
    enum SyncStatus: String, Codable {
        case pending   // Created offline, needs upload
        case syncing   // Currently uploading
        case synced    // Successfully uploaded → REMOVE FROM CACHE
        case failed    // Upload failed, retry later
    }
    
    /// Represents a cached item pending sync to server
    struct CachedItem: Codable {
        let negotiationId: UUID
        let title: String?
        let intentCategory: String
        let syncStatus: SyncStatus
        let cachedAt: Date
        let rawJSON: Data  // Store as JSON blob to avoid Codable issues
    }
    
    // MARK: - Save Pending
    
    /// Save a plan that needs syncing to server
    func savePending(_ plan: Negotiation) {
        guard let jsonData = try? JSONEncoder().encode(plan) else {
            print("❌ Failed to encode plan for cache: \(plan.id)")
            return
        }
        
        var pending = loadPending()
        pending[plan.id] = CachedItem(
            negotiationId: plan.id,
            title: plan.title,
            intentCategory: plan.intent_category ?? "unknown",
            syncStatus: .pending,
            cachedAt: Date(),
            rawJSON: jsonData
        )
        save(pending)
        print("💾 Cached pending plan: \(plan.id) - \(plan.title ?? "Untitled")")
    }
    
    // MARK: - Remove Synced
    
    /// Remove a plan from cache after successful sync
    func removeSynced(_ id: UUID) {
        var pending = loadPending()
        if pending.removeValue(forKey: id) != nil {
            save(pending)
            print("🧹 Cleared synced plan from cache: \(id)")
        }
    }
    
    // MARK: - Load Pending
    
    /// Load all pending items (for sync on app launch)
    func loadPending() -> [UUID: CachedItem] {
        guard let data = userDefaults.data(forKey: cacheKey),
              let items = try? JSONDecoder().decode([UUID: CachedItem].self, from: data) else {
            return [:]
        }
        return items
    }
    
    /// Get pending items as array (for UI display)
    func getPendingPlans() -> [Negotiation] {
        loadPending().compactMap { (id, item) in
            try? JSONDecoder().decode(Negotiation.self, from: item.rawJSON)
        }
    }
    
    // MARK: - Cleanup
    
    /// Remove all items marked as synced (batch cleanup)
    func clearAllSynced() {
        var pending = loadPending()
        let beforeCount = pending.count
        pending = pending.filter { $0.value.syncStatus != .synced }
        if pending.count < beforeCount {
            save(pending)
            print("🧹 Cleared \(beforeCount - pending.count) synced items from cache")
        }
    }
    
    /// Remove stale cache items (>7 days old)
    func cleanupStale() {
        var pending = loadPending()
        let now = Date()
        let maxAge: TimeInterval = 604800 // 7 days in seconds
        
        let beforeCount = pending.count
        pending = pending.filter { (id, item) in
            let age = now.timeIntervalSince(item.cachedAt)
            if age > maxAge {
                if item.syncStatus == .synced {
                    // Definitely should be removed
                    print("🧹 Removing stale synced item: \(id)")
                    return false
                } else {
                    // Warn about old pending item
                    print("⚠️ Stale pending item (>7 days): \(id) - \(item.title ?? "Untitled")")
                }
            }
            return true
        }
        
        if pending.count < beforeCount {
            save(pending)
            print("🧹 Cleaned up \(beforeCount - pending.count) stale items")
        }
    }
    
    // MARK: - Clear All
    
    /// Clear entire cache (use with caution)
    func clearAll() {
        userDefaults.removeObject(forKey: cacheKey)
        print("🧹 Cleared entire cache")
    }
    
    // MARK: - Private Helpers
    
    private func save(_ items: [UUID: CachedItem]) {
        if let data = try? JSONEncoder().encode(items) {
            userDefaults.set(data, forKey: cacheKey)
        }
    }
}
