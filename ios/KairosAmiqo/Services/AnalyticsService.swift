import Foundation
import CryptoKit

/// Privacy-first analytics service (1% sampling for free, 100% for Plus)
class AnalyticsService {
    static let shared = AnalyticsService()
    
    private let httpClient: HTTPClient
    private var eventQueue: [AnalyticsEvent] = []
    private var sessionID: String
    private var lastFlushTime: Date = Date()
    
    // Configuration
    private let maxQueueSize = 10
    private let flushInterval: TimeInterval = 60 // 1 minute
    
    private init() {
        self.httpClient = HTTPClient(base: Config.backendBase)
        self.sessionID = HashingService.generateSessionID()
    }
    
    // MARK: - Public API
    
    /// Log analytics event (batched, sampled for free users)
    /// - Parameters:
    ///   - type: Event type (app_open, plan_created, etc.)
    ///   - data: Contextual metadata (no PII)
    func logEvent(type: String, data: [String: Any] = [:]) {
        // Check if we should track this event (1% for free, 100% for Plus)
        guard shouldTrackEvent() else { return }
        
        // Convert data to AnyCodable
        let codableData = data.mapValues { AnyCodable($0) }
        
        let event = AnalyticsEvent(
            userIDHash: hashCurrentUserID(),
            eventType: type,
            eventData: codableData,
            sessionID: sessionID,
            platform: "ios",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            createdAt: Date()
        )
        
        eventQueue.append(event)
        
        // Flush if queue is full or time elapsed
        if eventQueue.count >= maxQueueSize || Date().timeIntervalSince(lastFlushTime) > flushInterval {
            Task {
                await flush()
            }
        }
    }
    
    /// Force flush event queue (call on app background/terminate)
    func flush() async {
        guard !eventQueue.isEmpty else { return }
        
        let batch = eventQueue
        eventQueue.removeAll()
        lastFlushTime = Date()
        
        do {
            let payload = batch.map { $0.toDictionary() }
            
            // POST to backend /analytics/log endpoint
            let jsonObject: Any
            if payload.count == 1 {
                jsonObject = payload[0]
            } else {
                jsonObject = ["events": payload] as [String: Any]
            }
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject)
            
            let _ = try await httpClient.post(
                path: "/items/analytics_events",
                body: jsonData
            )
            
            #if DEBUG
            print("✅ Analytics: Sent \(batch.count) event(s)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Analytics error: \(error)")
            #endif
            
            // Re-queue events for retry (avoid data loss)
            eventQueue.insert(contentsOf: batch, at: 0)
            
            // Limit queue size to prevent memory issues
            if eventQueue.count > maxQueueSize * 3 {
                eventQueue = Array(eventQueue.suffix(maxQueueSize * 2))
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Hash current user ID (privacy-preserving)
    private func hashCurrentUserID() -> String {
        guard let userID = getCurrentUserID() else {
            return "anonymous"
        }
        return HashingService.hashUserID(userID)
    }
    
    /// Get current user ID from UserDefaults or AppVM
    private func getCurrentUserID() -> String? {
        // Try UserDefaults first
        if let userID = UserDefaults.standard.string(forKey: "user_id") {
            return userID
        }
        
        // Fallback: Generate anonymous ID (persistent across sessions)
        if let anonymousID = UserDefaults.standard.string(forKey: "anonymous_analytics_id") {
            return anonymousID
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: "anonymous_analytics_id")
            return newID
        }
    }
    
    /// Check if we should track this event (sampling logic)
    private func shouldTrackEvent() -> Bool {
        // Always track Plus users
        let isPlusUser = UserDefaults.standard.bool(forKey: "is_plus_user")
        if isPlusUser {
            return true
        }
        
        // 1% sampling for free users (1 in 100 events)
        return Int.random(in: 0..<100) == 0
    }
}

// MARK: - App Lifecycle Helpers

extension AnalyticsService {
    /// Call on app entering background
    func handleAppBackground() {
        Task {
            await flush()
        }
    }
    
    /// Call on app termination
    func handleAppTerminate() {
        Task {
            await flush()
        }
    }
}
