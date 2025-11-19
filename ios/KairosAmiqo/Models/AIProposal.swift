import Foundation

/// AI-generated plan proposal containing time slots and venue suggestions
/// Used by AIService implementations to return structured AI recommendations
struct AIProposal: Codable {
    let timeSlots: [TimeSlot]
    let venues: [Venue]
    let explanation: String
    let confidence: Double // 0.0-1.0
}

/// Suggested time slot for a plan
struct TimeSlot: Codable, Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case start, end, reason
    }
}

/// Suggested venue for a plan
struct Venue: Codable, Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let category: String // "cafe", "restaurant", "bar", etc.
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case name, address, category, reason
    }
}
