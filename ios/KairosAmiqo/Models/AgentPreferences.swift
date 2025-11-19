//
//  AgentPreferences.swift
//  KairosAmiqo
//
//  Task 28: Agent-to-Agent Negotiation - Preferences Model
//  Week 1, Day 3: Define agent learning structures
//
//  Created: 2025-11-01
//  See: /AGENT-TO-AGENT-IMPLEMENTATION-PLAN.md
//

import Foundation

// MARK: - Agent Preferences (Top-Level Model)

/// Complete agent preferences for a user
/// Stored encrypted in Directus: /items/user_agent_preferences
/// Server cannot read plaintext (E2EE with user's master key)
struct AgentPreferences: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var learnedPatterns: LearnedPatterns
    var autonomySettings: AutonomySettings
    var vetoRules: [VetoRule]
    let dateCreated: Date
    var dateUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case learnedPatterns = "learned_patterns"
        case autonomySettings = "autonomy_settings"
        case vetoRules = "veto_rules"
        case dateCreated = "date_created"
        case dateUpdated = "date_updated"
    }
    
    /// Initialize new preferences with defaults
    init(userId: UUID) {
        self.id = UUID()
        self.userId = userId
        self.learnedPatterns = LearnedPatterns()
        self.autonomySettings = AutonomySettings()
        self.vetoRules = []
        self.dateCreated = Date()
        self.dateUpdated = Date()
    }
}

// MARK: - Learned Patterns

/// Machine-learned patterns from negotiation history
/// Continuously updated as user accepts/counters/rejects proposals
struct LearnedPatterns: Codable {
    /// Favorite venues by POI ID (key = poi_id, value = preference score 0.0-1.0)
    /// Updated when user accepts plans with specific venues
    /// Higher score = more likely to propose
    var favoriteVenues: [UUID: Double]
    
    /// Preferred times by hour (key = hour 0-23, value = preference score 0.0-1.0)
    /// Updated when user accepts plans at specific times
    /// Example: {18: 0.9, 19: 0.8, 20: 0.7} → prefers evening plans
    var preferredTimes: [Int: Double]
    
    /// Category preferences (key = category, value = preference score 0.0-1.0)
    /// Categories: "restaurant", "coffee", "bar", "activity", "outdoors"
    /// Updated based on accepted plan types
    var categoryPreferences: [String: Double]
    
    /// Preferred plan duration in minutes (key = category, value = avg duration)
    /// Example: {"coffee": 45, "dinner": 120, "drinks": 90}
    var preferredDurations: [String: Int]
    
    /// Friend affinity scores (key = friend_user_id, value = score 0.0-1.0)
    /// Higher score = more likely to include in group plans
    /// Updated based on who user plans with most often
    var friendAffinityScores: [UUID: Double]
    
    /// Total negotiations analyzed for learning
    /// Used to weight confidence in learned patterns
    var negotiationCount: Int
    
    /// Last learning update timestamp
    var lastUpdated: Date
    
    /// Initialize with empty patterns
    init() {
        self.favoriteVenues = [:]
        self.preferredTimes = [:]
        self.categoryPreferences = [:]
        self.preferredDurations = [:]
        self.friendAffinityScores = [:]
        self.negotiationCount = 0
        self.lastUpdated = Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case favoriteVenues = "favorite_venues"
        case preferredTimes = "preferred_times"
        case categoryPreferences = "category_preferences"
        case preferredDurations = "preferred_durations"
        case friendAffinityScores = "friend_affinity_scores"
        case negotiationCount = "negotiation_count"
        case lastUpdated = "last_updated"
    }
}

// MARK: - Autonomy Settings

/// User-controlled agent autonomy parameters
/// Determines how aggressively agent acts on user's behalf
struct AutonomySettings: Codable {
    /// Global autonomy level (0.0 = manual only, 1.0 = full auto)
    /// User sets via toggle in Settings → Agent Preferences
    /// Default: 0.5 (moderate autonomy)
    var globalAutonomyLevel: Double
    
    /// Auto-accept threshold (0.0-1.0)
    /// If proposal confidence ≥ this threshold, agent accepts automatically
    /// Example: 0.9 → only auto-accept near-perfect matches
    /// Default: 0.85
    var autoAcceptThreshold: Double
    
    /// Auto-counter threshold (0.0-1.0)
    /// If proposal is below accept threshold but above this, agent counters
    /// Example: 0.6 → counter proposals with 60-85% confidence
    /// Default: 0.65
    var autoCounterThreshold: Double
    
    /// Maximum negotiation rounds before escalating to user
    /// Prevents infinite loops between agents
    /// Default: 5
    var maxNegotiationRounds: Int
    
    /// Per-plan autonomy override (optional)
    /// User can toggle "Let agent handle this" on specific plans
    /// If true for a plan, ignore global level and use full autonomy
    /// Stored per-negotiation in negotiations.agent_mode field
    var allowPerPlanOverride: Bool
    
    /// Require confirmation before finalizing
    /// If true, agent proposes final time but waits for user tap to confirm
    /// If false, agent auto-finalizes when consensus reached
    /// Default: true (safer)
    var requireFinalConfirmation: Bool
    
    /// Initialize with conservative defaults
    init() {
        self.globalAutonomyLevel = 0.5
        self.autoAcceptThreshold = 0.85
        self.autoCounterThreshold = 0.65
        self.maxNegotiationRounds = 5
        self.allowPerPlanOverride = true
        self.requireFinalConfirmation = true
    }
    
    enum CodingKeys: String, CodingKey {
        case globalAutonomyLevel = "global_autonomy_level"
        case autoAcceptThreshold = "auto_accept_threshold"
        case autoCounterThreshold = "auto_counter_threshold"
        case maxNegotiationRounds = "max_negotiation_rounds"
        case allowPerPlanOverride = "allow_per_plan_override"
        case requireFinalConfirmation = "require_final_confirmation"
    }
}

// MARK: - Veto Rule

/// User-defined hard constraints that agent must never violate
/// Examples: "Never before 9am", "Never schedule over existing calendar events"
/// Agent checks veto rules before proposing/accepting times
struct VetoRule: Codable, Identifiable {
    let id: UUID
    let type: VetoRuleType
    let value: String // JSON-encoded rule parameters
    var isActive: Bool
    let dateCreated: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case value
        case isActive = "is_active"
        case dateCreated = "date_created"
    }
    
    /// Initialize new veto rule
    init(type: VetoRuleType, value: String) {
        self.id = UUID()
        self.type = type
        self.value = value
        self.isActive = true
        self.dateCreated = Date()
    }
}

// MARK: - Veto Rule Types

/// Predefined veto rule types
/// Each type has specific validation logic in PreferenceLearningService
enum VetoRuleType: String, Codable {
    /// Never propose times before specified hour (value = hour 0-23)
    /// Example: value = "9" → no plans before 9am
    case neverBefore = "never_before"
    
    /// Never propose times after specified hour (value = hour 0-23)
    /// Example: value = "22" → no plans after 10pm
    case neverAfter = "never_after"
    
    /// Never propose on specific days (value = ["monday", "tuesday", ...])
    /// Example: value = '["monday"]' → no Monday plans
    case neverOnDays = "never_on_days"
    
    /// Never propose at specific venue (value = poi_id UUID)
    /// Example: user had bad experience at a restaurant
    case neverAtVenue = "never_at_venue"
    
    /// Never overlap with calendar events (value = calendar identifier)
    /// Example: value = "Work" → check Work calendar for conflicts
    case respectCalendar = "respect_calendar"
    
    /// Never propose duration longer than X minutes (value = minutes)
    /// Example: value = "120" → no plans over 2 hours
    case maxDuration = "max_duration"
    
    /// Never invite specific person (value = friend_user_id UUID)
    /// Example: user avoiding an ex-friend
    case neverInvite = "never_invite"
    
    /// Custom rule with freeform logic (value = JSON rule definition)
    /// Advanced users can define complex constraints
    case custom = "custom"
}

// MARK: - Agent Message (Peer-to-Peer Communication)

/// E2EE message sent between user agents during negotiation
/// Stored encrypted in Directus: /items/agent_messages
/// Only participant agents can decrypt (Diffie-Hellman shared secret)
struct AgentMessage: Codable, Identifiable {
    let id: UUID
    let negotiationId: UUID
    let fromUserId: UUID
    let toUserId: UUID
    let messageType: AgentMessageType
    let payload: String // JSON-encoded message content (encrypted)
    let round: Int // Negotiation round number
    let dateCreated: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case negotiationId = "negotiation_id"
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case messageType = "message_type"
        case payload
        case round
        case dateCreated = "date_created"
    }
    
    /// Initialize new agent message
    init(
        negotiationId: UUID,
        fromUserId: UUID,
        toUserId: UUID,
        messageType: AgentMessageType,
        payload: String,
        round: Int
    ) {
        self.id = UUID()
        self.negotiationId = negotiationId
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.messageType = messageType
        self.payload = payload
        self.round = round
        self.dateCreated = Date()
    }
}

// MARK: - Agent Message Types

/// Types of messages agents can send to each other
enum AgentMessageType: String, Codable {
    /// Initial proposal from initiator's agent
    /// Payload: {time_slots: [...], venue_options: [...], reasoning: "..."}
    case proposal = "proposal"
    
    /// Counter-proposal with adjusted constraints
    /// Payload: {original_proposal_id: UUID, counter_time_slots: [...], reasoning: "..."}
    case counter = "counter"
    
    /// Accept current proposal
    /// Payload: {accepted_proposal_id: UUID, confirmation: true}
    case accept = "accept"
    
    /// Reject proposal (end negotiation)
    /// Payload: {rejected_proposal_id: UUID, reason: "..."}
    case reject = "reject"
    
    /// Request user intervention (escalation)
    /// Payload: {reason: "max_rounds_reached", current_state: {...}}
    case escalate = "escalate"
    
    /// Finalize plan (consensus reached)
    /// Payload: {final_time: ISO8601, final_venue: UUID, event_id: UUID}
    case finalize = "finalize"
}

// MARK: - User Public Key (Diffie-Hellman Key Exchange)

/// User's public key for E2EE key exchange
/// Stored in Directus: /items/user_public_keys
/// Used to derive shared secrets for agent-to-agent messages
struct UserPublicKey: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let publicKey: String // Base64-encoded Curve25519 public key
    let keyVersion: Int // Increments on key rotation
    let dateCreated: Date
    var dateExpires: Date? // Optional key expiration
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case publicKey = "public_key"
        case keyVersion = "key_version"
        case dateCreated = "date_created"
        case dateExpires = "date_expires"
    }
    
    /// Initialize new public key entry
    init(userId: UUID, publicKey: String, keyVersion: Int = 1) {
        self.id = UUID()
        self.userId = userId
        self.publicKey = publicKey
        self.keyVersion = keyVersion
        self.dateCreated = Date()
        self.dateExpires = nil
    }
}
