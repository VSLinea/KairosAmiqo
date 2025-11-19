import Foundation

/// Analytics event model (privacy-first, no PII)
struct AnalyticsEvent: Codable {
    let userIDHash: String
    let eventType: String
    let eventData: [String: AnyCodable]
    let sessionID: String
    let platform: String
    let appVersion: String
    let createdAt: Date
    
    /// Convert to dictionary for API request
    func toDictionary() -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return [
            "user_id_hash": userIDHash,
            "event_type": eventType,
            "event_data": eventData.mapValues { $0.value },
            "session_id": sessionID,
            "platform": platform,
            "app_version": appVersion,
            "created_at": formatter.string(from: createdAt)
        ]
    }
}

/// Type-erased wrapper for Any in Codable (JSON event_data)
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }
}
