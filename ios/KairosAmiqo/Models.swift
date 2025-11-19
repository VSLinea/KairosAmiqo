//
//  Models.swift
//  KairosAmiqo
//
//  Created by Lyra AI on 2025-10-04.
//

import Foundation
import SwiftUI
import EventKit // For CalendarHelper types
import CryptoKit // For SHA-1 hashing (UUID v5)

// MARK: - UUID Extensions (Phase Compatibility)

extension UUID {
    /// Creates a deterministic UUID v5 (SHA-1 namespace-based) from a namespace and name string.
    /// Used to convert Directus integer IDs → UUIDs during Phase 0-8 (before database migration).
    ///
    /// - Parameters:
    ///   - namespace: Namespace UUID (e.g., Kairos-specific namespace)
    ///   - name: String to hash (e.g., "negotiation-137")
    /// - Returns: Deterministic UUID (same input always produces same output)
    ///
    /// **Why UUID v5?**
    /// - Deterministic: Same integer ID always produces same UUID
    /// - Collision-free: SHA-1 hash prevents ID conflicts
    /// - Standards-compliant: RFC 4122 UUID v5 specification
    init(namespace: UUID, name: String) {
        // Convert namespace UUID to bytes
        var namespaceBytes = [UInt8]()
        withUnsafeBytes(of: namespace.uuid) { bytes in
            namespaceBytes.append(contentsOf: bytes)
        }
        
        // Append name bytes
        let nameBytes = Array(name.utf8)
        let combined = namespaceBytes + nameBytes
        
        // Compute SHA-1 hash (UUID v5 uses SHA-1)
        var hash = Insecure.SHA1.hash(data: combined)
        
        // Set version (4 bits) and variant (2 bits) per RFC 4122
        withUnsafeMutableBytes(of: &hash) { bytes in
            bytes[6] = (bytes[6] & 0x0F) | 0x50 // Version 5
            bytes[8] = (bytes[8] & 0x3F) | 0x80 // Variant 10
        }
        
        // Extract first 16 bytes as UUID
        self = withUnsafeBytes(of: hash) { bytes in
            UUID(uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            ))
        }
    }
}

// MARK: - Plan/Negotiation Models

struct Negotiation: Codable, Identifiable, Hashable {
    let id: UUID // Client-generated UUID for offline support
    var title: String?
    var status: String?
    var started_at: String?
    var date_created: String?
    var created_at: String? // Mock server uses this instead of date_created
    var updated_at: String? // Additional timestamp field from mock server
    var date_updated: String? // Additional timestamp field
    var round: Int? // Negotiation round counter

    // Full backend fields (will be populated when backend integration is complete)
    var owner: UUID? // User who created the negotiation (required by Directus)
    var intent_category: String?
    var participants: [PlanParticipant]?
    var state: String?
    var proposed_slots: [ProposedSlot]?
    var proposed_venues: [VenueInfo]?
    var expires_at: String?
    
    // MARK: - Phase Compatibility Decoding (Integer ↔ UUID)
    
    /// Custom decoder to handle Directus integer IDs (Phase 0-8) and UUID IDs (Phase 9+)
    /// See: /TRACKING.md §DATABASE MIGRATION STATUS (UUID migration deferred to Phase 9)
    /// 
    /// **Strategy:**
    /// - Directus (Phase 0-8): Returns `"id": 137` (integer) → Convert to UUID namespace
    /// - Mock server (Phase 0-3): Returns `"id": "uuid-string"` → Parse directly
    /// - Future (Phase 9+): Database migrated to UUIDs → Parse directly
    ///
    /// **UUID Conversion (Integer → UUID):**
    /// Uses UUID v5 (SHA-1 namespace) with custom Kairos namespace to ensure deterministic,
    /// collision-free UUIDs from integer IDs. Same integer always produces same UUID.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle ID (integer or UUID string)
        if let uuidString = try? container.decode(String.self, forKey: .id) {
            // Mock server or Phase 9+ (direct UUID)
            guard let uuid = UUID(uuidString: uuidString) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .id,
                    in: container,
                    debugDescription: "Invalid UUID string: \(uuidString)"
                )
            }
            self.id = uuid
        } else if let intID = try? container.decode(Int.self, forKey: .id) {
            // Directus Phase 0-8 (integer ID) → Convert to deterministic UUID
            // Use UUID v5 with Kairos namespace to ensure same int → same UUID
            let kairosNamespace = UUID(uuidString: "6a1f0a0e-8b9c-4d3e-bf4f-1a2b3c4d5e6f")!
            self.id = UUID(namespace: kairosNamespace, name: "negotiation-\(intID)")
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .id,
                in: container,
                debugDescription: "ID must be either Int or UUID String"
            )
        }
        
        // Decode remaining fields normally
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.status = try container.decodeIfPresent(String.self, forKey: .status)
        self.started_at = try container.decodeIfPresent(String.self, forKey: .started_at)
        self.date_created = try container.decodeIfPresent(String.self, forKey: .date_created)
        self.created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
        self.updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
        self.date_updated = try container.decodeIfPresent(String.self, forKey: .date_updated)
        self.round = try container.decodeIfPresent(Int.self, forKey: .round)
        self.owner = try container.decodeIfPresent(UUID.self, forKey: .owner)
        self.intent_category = try container.decodeIfPresent(String.self, forKey: .intent_category)
        self.participants = try container.decodeIfPresent([PlanParticipant].self, forKey: .participants)
        self.state = try container.decodeIfPresent(String.self, forKey: .state)
        self.proposed_slots = try container.decodeIfPresent([ProposedSlot].self, forKey: .proposed_slots)
        self.proposed_venues = try container.decodeIfPresent([VenueInfo].self, forKey: .proposed_venues)
        self.expires_at = try container.decodeIfPresent(String.self, forKey: .expires_at)
    }
    
    // Custom encoder (always emit UUID as string for consistency)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.uuidString, forKey: .id) // Always encode as string
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(started_at, forKey: .started_at)
        try container.encodeIfPresent(date_created, forKey: .date_created)
        try container.encodeIfPresent(created_at, forKey: .created_at)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
        try container.encodeIfPresent(date_updated, forKey: .date_updated)
        try container.encodeIfPresent(round, forKey: .round)
        try container.encodeIfPresent(owner, forKey: .owner)
        try container.encodeIfPresent(intent_category, forKey: .intent_category)
        try container.encodeIfPresent(participants, forKey: .participants)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(proposed_slots, forKey: .proposed_slots)
        try container.encodeIfPresent(proposed_venues, forKey: .proposed_venues)
        try container.encodeIfPresent(expires_at, forKey: .expires_at)
    }
    
    // MARK: - Manual Memberwise Initializer
    
    /// Manual memberwise initializer required because custom `init(from:)` disables Swift's auto-generation.
    /// Used for preview mock data, testing, and offline fallback scenarios.
    /// See: Custom decoder above for API response decoding (handles integer ↔ UUID compatibility)
    init(
        id: UUID,
        title: String? = nil,
        status: String? = nil,
        started_at: String? = nil,
        date_created: String? = nil,
        created_at: String? = nil,
        updated_at: String? = nil,
        date_updated: String? = nil,
        round: Int? = nil,
        owner: UUID? = nil,
        intent_category: String? = nil,
        participants: [PlanParticipant]? = nil,
        state: String? = nil,
        proposed_slots: [ProposedSlot]? = nil,
        proposed_venues: [VenueInfo]? = nil,
        expires_at: String? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.started_at = started_at
        self.date_created = date_created
        self.created_at = created_at
        self.updated_at = updated_at
        self.date_updated = date_updated
        self.round = round
        self.owner = owner
        self.intent_category = intent_category
        self.participants = participants
        self.state = state
        self.proposed_slots = proposed_slots
        self.proposed_venues = proposed_venues
        self.expires_at = expires_at
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, status, started_at, date_created, created_at, updated_at, date_updated, round
        case owner, intent_category, participants, state, proposed_slots, proposed_venues, expires_at
    }
}

/// Plan participant - matches backend JSON schema for negotiations.participants
/// Backend structure: {"user_id": "uuid", "name": "Alice", "status": "invited|accepted|rejected|countered"}
/// Extended with email/phone for non-Kairos user invites (SMS/email routing)
/// Participant in a plan/negotiation - matches backend JSON schema
/// Used in negotiations.participants array
/// 
/// **UUID Strategy:**
/// - Kairos users: Real user UUID from backend (fetched via GET /items/friends)
/// - Non-Kairos users (contacts/manual entry): Temporary random UUID (app-generated)
/// - Backend resolves temporary UUIDs → Creates invite tokens → Sends invites
/// - Once non-user accepts invite & signs up → Backend updates with real user UUID
struct PlanParticipant: Codable, Identifiable, Hashable {
    let id = UUID() // UI-only field (SwiftUI ForEach)
    let user_id: UUID // Backend user ID (real or temporary)
    let name: String
    let email: String? // Optional: for non-Kairos user invites
    let phone: String? // Optional: for SMS invites
    let status: String // "invited" | "accepted" | "rejected" | "countered"

    enum CodingKeys: String, CodingKey {
        case user_id, name, email, phone, status
    }
    
    // Convenience init for Kairos users (no email/phone needed)
    init(user_id: UUID, name: String, status: String = "invited") {
        self.user_id = user_id
        self.name = name
        self.email = nil
        self.phone = nil
        self.status = status
    }
    
    // Full init for non-Kairos users (contact picker, manual entry)
    init(user_id: UUID, name: String, email: String?, phone: String?, status: String = "invited") {
        self.user_id = user_id
        self.name = name
        self.email = email
        self.phone = phone
        self.status = status
    }
}

/// Time slot proposal - matches backend JSON schema
/// Backend structure: {"time": "ISO8601", "venue": {...}}
struct ProposedSlot: Codable, Identifiable, Hashable {
    let id = UUID() // UI-only field
    let time: String // ISO8601 format
    let venue: VenueInfo?

    enum CodingKeys: String, CodingKey {
        case time, venue
    }

    var date: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: time)
    }
}

/// Venue information - matches backend JSON schema
/// Used in proposed_slots, proposed_venues, and events.venue
/// 
/// **UUID Strategy:**
/// - Phase 0-3: Fixed mock UUIDs (880e8400-...) hardcoded in CreatePlanSteps.mockVenues
/// - Phase 4+: Real POI database UUIDs from GET /items/poi (OSM + Google Places)
/// - Backend uses UUID to look up venue details: GET /items/poi/{uuid}
/// - Same UUID = same venue across all clients (iOS, Android, Web)
struct VenueInfo: Codable, Hashable {
    let id: UUID? // Optional: nil = user-entered custom venue (no POI match)
    let name: String
    let lat: Double?
    let lon: Double?
    let address: String?
    let category: String?
    let price_band: Int?
}

/// Intent template for plan creation - matches backend JSON schema
/// Backend: GET /api/intent_templates returns array of these
/// Used in HeroCreateCard and CreateProposalFlow
struct IntentTemplate: Identifiable, Hashable, Codable {
    let id: UUID // Changed from String to UUID (matches intent_templates.id uuid pk)
    let name: String
    let emoji: String // DEPRECATED: Will be replaced by iconName in Phase 3
    let duration_minutes: Int
    let venue_types: [String]
    let price_range: [Int]?
    let time_preferences: [String]?
    let description: String?
    
    // MARK: - SF Symbol Icon Mapping (Phase 3 Design System)
    
    /// SF Symbol icon name based on template purpose
    var iconName: String {
        switch name {
        // Social & Dining
        case "Coffee": return "cup.and.saucer.fill"
        case "Drinks": return "wineglass.fill"
        case "Lunch", "Dinner": return "fork.knife"
        case "Brunch": return "cup.and.heat.waves.fill"
        case "Meetup": return "person.2.fill"
        
        // Entertainment
        case "Movie": return "popcorn.fill"
        case "Date Night": return "heart.circle.fill"
        case "Concert", "Live Music": return "music.note.list"
        
        // Productivity
        case "Study": return "book.fill"
        case "Work Session": return "laptopcomputer"
        case "Brainstorm": return "lightbulb.fill"
        
        // Wellness
        case "Gym", "Workout": return "figure.run"
        case "Yoga": return "figure.yoga"
        case "Walk": return "figure.walk"
        
        // Custom/Flexible
        case "Custom": return "wand.and.stars"  // Magic wand = customization
        
        // Fallback
        default: return "calendar.badge.plus"  // Generic "create event"
        }
    }
    
    /// Theme-aware icon color - ALL icons use accent color for consistency
    /// Icon SHAPE conveys meaning, not color differentiation
    var iconColor: Color {
        return KairosAuth.Color.accent
    }
    
    // Computed properties for UI convenience
    var displayIcon: String { iconName } // Updated to use SF Symbol
    var displayTitle: String { name }
    var durationText: String {
        let hours = duration_minutes / 60
        let mins = duration_minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
    var priceText: String? {
        guard let range = price_range, !range.isEmpty else { return nil }
        return String(repeating: "$", count: range.max() ?? 1)
    }
    
    var backendCategory: String {
        name.lowercased()
    }
    
    /// Parse intent from conversational text (e.g., "dinner", "coffee", "game night")
    static func fromText(_ text: String) -> IntentTemplate {
        let lower = text.lowercased()
        
        // Try to match against common intents
        if lower.contains("dinner") {
            return IntentTemplate(
                id: UUID(),
                name: "Dinner",
                emoji: "🍽️",
                duration_minutes: 120,
                venue_types: ["restaurant"],
                price_range: [2, 3],
                time_preferences: ["evening"],
                description: "Dinner with friends"
            )
        } else if lower.contains("coffee") || lower.contains("cafe") {
            return IntentTemplate(
                id: UUID(),
                name: "Coffee",
                emoji: "☕",
                duration_minutes: 60,
                venue_types: ["cafe"],
                price_range: [1, 2],
                time_preferences: ["morning", "afternoon"],
                description: "Coffee meetup"
            )
        } else if lower.contains("lunch") {
            return IntentTemplate(
                id: UUID(),
                name: "Lunch",
                emoji: "🥗",
                duration_minutes: 90,
                venue_types: ["restaurant", "cafe"],
                price_range: [1, 2],
                time_preferences: ["afternoon"],
                description: "Lunch together"
            )
        } else if lower.contains("game") {
            return IntentTemplate(
                id: UUID(),
                name: "Game Night",
                emoji: "🎮",
                duration_minutes: 180,
                venue_types: ["home", "game_cafe"],
                price_range: [1],
                time_preferences: ["evening"],
                description: "Game night with friends"
            )
        } else {
            // Default to generic hangout
            return IntentTemplate(
                id: UUID(),
                name: "Hangout",
                emoji: "👋",
                duration_minutes: 120,
                venue_types: ["flexible"],
                price_range: [1, 2],
                time_preferences: nil,
                description: text
            )
        }
    }
}

/// Kairos friend for participant selection - matches backend JSON schema
/// Backend: GET /api/friends?user_id={id} returns array of these
/// Used in ParticipantsStep for friend selection
struct KairosFriend: Identifiable, Hashable, Codable {
    let user_id: UUID // Changed from String to UUID (matches app_users.id uuid pk)
    let name: String
    let username: String
    let last_plan_together: String? // ISO8601 format
    let plans_count: Int?
    
    // Conformance to Identifiable
    var id: UUID { user_id }
    
    // UI helpers
    var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
    
    var displayName: String { name }
    var displayUsername: String { "@\(username)" }
}

// MARK: - Directus Envelopes

struct DirectusEnvelope<T: Codable>: Codable { let data: T }
struct DirectusListEnvelope<T: Codable>: Codable { let data: [T] }

struct LoginEnvelope: Codable {
    struct DW: Codable {
        let access_token: String
        let expires: Int64 // Changed from Int to Int64 to match Android Long
        let refresh_token: String?
    }

    let data: DW
}

struct DirectusAPIError: Codable {
    struct E: Codable {
        struct Ext: Codable { let code: String? }
        let message: String?
        let extensions: Ext?
    }

    let errors: [E]?
}

// MARK: - Places/POI Models (Phase 5)

/// Point of Interest - matches backend /items/poi schema
/// See: /docs/01-data-model.md
struct POI: Codable, Identifiable, Hashable {
    let id: UUID // Consistent with VenueInfo and backend schema
    let name: String
    let type: String // cafe, restaurant, bar, gym
    let address: String
    let lat: Double
    let lon: Double
    let rating: Double
    private let price_range_raw: PriceRange? // Backend sends string or int, we normalize
    let hours: String?
    let distance: String? // "1.2 km" (formatted by backend based on user location)
    
    // Custom decoding to handle both String and Int from backend
    enum CodingKeys: String, CodingKey {
        case id, name, type, address, lat, lon, rating, hours, distance
        case price_range_raw = "price_range"
    }
    
    // Support both String and Int price_range from backend
    enum PriceRange: Codable, Hashable {
        case int(Int)
        case string(String)
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let intValue = try? container.decode(Int.self) {
                self = .int(intValue)
            } else if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
            } else {
                self = .int(2) // Default to $$ if unparseable
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .int(let value):
                try container.encode(value)
            case .string(let value):
                try container.encode(value)
            }
        }
        
        var normalized: Int {
            switch self {
            case .int(let value):
                return max(1, min(3, value)) // Clamp to 1-3
            case .string(let value):
                // Parse string like "$", "$$", "$$$"
                let dollarCount = value.filter { $0 == "$" }.count
                if dollarCount > 0 {
                    return max(1, min(3, dollarCount))
                }
                // Fallback: try to parse as number
                if let intValue = Int(value) {
                    return max(1, min(3, intValue))
                }
                return 2 // Default to $$ if unparseable
            }
        }
    }
    
    /// Price range as integer (1-3 for $, $$, $$$)
    var price_range: Int {
        price_range_raw?.normalized ?? 2
    }
    
    /// Category icon for display
    var categoryIcon: String {
        switch type {
        case "cafe", "coffee": return "cup.and.saucer.fill"
        case "restaurant": return "fork.knife"
        case "bar": return "wineglass.fill"
        case "gym": return "dumbbell.fill"
        case "bakery": return "birthday.cake.fill"
        case "park": return "tree.fill"
        case "market": return "cart.fill"
        case "attraction": return "star.fill"
        case "plaza": return "building.2.fill"
        default: return "mappin.circle.fill"
        }
    }
    
    /// Formatted distance for display
    var formattedDistance: String {
        distance ?? "—"
    }
}

/// Learned place - auto-detected frequent locations
/// See: /docs/01-data-model.md
/// Currently mock data only (Phase 5)
struct LearnedPlace: Identifiable, Hashable, Codable {
    let id: UUID // Consistent UUID usage
    let label: String // "Home", "Work", "Favorite Café"
    let address: String
    let lat: Double
    let lon: Double
    let icon: String // SF Symbol name
    let isPrivate: Bool // Whether to hide from friends
    let visitCount: Int // Number of visits detected
}

// MARK: - Color Hex Helpers

extension Color {
    /// Initialize Color from hex string (e.g., "#007AFF" or "007AFF")
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Convert Color to hex string (simplified for common colors)
    func toHex() -> String? {
        // For simplicity, return predefined hex for SwiftUI standard colors
        // In production, would use UIColor.cgColor components
        switch self {
        case .brown: return "#A52A2A"
        case .cyan: return "#00FFFF"
        case .purple: return "#800080"
        case .orange: return "#FFA500"
        case .red: return "#FF0000"
        case .green: return "#008000"
        case .indigo: return "#4B0082"
        case .pink: return "#FFC0CB"
        case .blue: return "#007AFF"
        case .yellow: return "#FFFF00"
        default: return "#007AFF" // Fallback
        }
    }
}
