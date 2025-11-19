//
//  UserAgentManager.swift
//  KairosAmiqo
//
//  Task 28: Agent-to-Agent Negotiation - User Agent Core
//  Week 1, Days 6-7: Agent message protocol, decision logic, autonomous negotiation
//
//  Created: 2025-11-02
//  See: /AGENT-TO-AGENT-IMPLEMENTATION-PLAN.md
//  See: /.github/apple-docs-grounded-mode.md (Foundation.UUID iOS 6.0+, CryptoKit iOS 13.0+)
//

import Foundation
import CryptoKit

/// User's autonomous negotiation agent
/// Represents user preferences, evaluates proposals, generates counters
///
/// **Capabilities:**
/// - Evaluate incoming proposals (accept/counter/escalate)
/// - Generate counter-proposals based on learned patterns
/// - Send/receive encrypted agent messages (peer-to-peer)
/// - Track negotiation rounds to prevent loops
/// - Escalate to user when confidence low or max rounds reached
///
/// **Privacy:**
/// - All agent-to-agent messages are E2EE encrypted
/// - Server cannot read message content (only metadata)
/// - Learned patterns never leave device unencrypted
///
/// @available(iOS 15.0, *)
final class UserAgentManager {
    
    // MARK: - Properties
    
    /// Current user ID
    private let userId: UUID
    
    /// User's agent preferences (learned patterns, autonomy settings, veto rules)
    private var preferences: AgentPreferences
    
    /// Directus client for sending/receiving messages
    private let directusClient: HTTPClient
    
    /// Preference learning service for scoring algorithms
    private let learningService: PreferenceLearningService
    
    /// AI decision service for intelligent reasoning (optional)
    private var aiService: AgentDecisionService?
    
    // MARK: - Initialization
    
    /// Initialize user agent manager
    /// - Parameters:
    ///   - userId: Current user UUID
    ///   - preferences: User's agent preferences
    ///   - directusClient: HTTP client for Directus API
    ///   - openAIKey: OpenAI API key (optional - falls back to heuristics)
    init(
        userId: UUID,
        preferences: AgentPreferences,
        directusClient: HTTPClient,
        openAIKey: String? = nil
    ) {
        self.userId = userId
        self.preferences = preferences
        self.directusClient = directusClient
        self.learningService = PreferenceLearningService(
            userId: userId,
            directusClient: directusClient
        )
        
        // Initialize AI service if key provided (main actor isolated)
        if let key = openAIKey {
            Task { @MainActor in
                self.aiService = AgentDecisionService(apiKey: key)
                print("✅ AI decision service enabled")
            }
        } else {
            print("⚠️ No OpenAI key - using heuristic decisions only")
        }
    }
    
    // MARK: - Public API - Decision Making
    
    /// Evaluate incoming AI-suggested options and decide action
    /// - Parameter proposal: AI-generated time/venue suggestions from other agent
    /// - Returns: Decision (accept/counter/escalate) with reasoning
    /// - Throws: If evaluation fails
    ///
    /// **Note:** "Proposal" here refers to AI-suggested options, not user invitations.
    /// Negotiation lifecycle states use "awaiting_invites/awaiting_replies" terminology.
    func evaluateProposal(_ proposal: ProposalData) async throws -> AgentDecision {
        print("🤖 UserAgent: Evaluating proposal...")
        print("   Venues: \(proposal.venues.count), Time slots: \(proposal.timeSlots.count)")
        
        // Step 1: Check veto rules (hard constraints)
        for slot in proposal.timeSlots {
            for venue in proposal.venues {
                if let violation = learningService.checkVetoRules(
                    time: slot.time,
                    duration: slot.durationMinutes,
                    venueId: venue.poiId,
                    vetoRules: preferences.vetoRules
                ) {
                    print("⛔ Veto rule violated: \(violation)")
                    return AgentDecision(
                        action: .escalate,
                        confidence: 0.0,
                        reasoning: "Veto rule: \(violation)",
                        suggestedAlternatives: nil
                    )
                }
            }
        }
        
        // Step 2: Try AI decision if service available
        if let aiService = aiService {
            do {
                print("🧠 Using AI decision service...")
                let aiDecision = try await aiService.evaluateProposalWithAI(
                    proposal: proposal,
                    preferences: preferences
                )
                
                // Convert AI decision to AgentDecision
                let mappedAction: AgentDecision.Action
                switch aiDecision.action {
                case .accept: mappedAction = .accept
                case .counter: mappedAction = .counter
                case .escalate: mappedAction = .escalate
                }
                
                return AgentDecision(
                    action: mappedAction,
                    confidence: aiDecision.confidence,
                    reasoning: aiDecision.reason,
                    suggestedAlternatives: nil  // TODO: Parse from AI alternatives
                )
            } catch {
                print("⚠️ AI decision failed: \(error.localizedDescription)")
                print("   Falling back to heuristic scoring...")
                // Fall through to heuristic scoring
            }
        }
        
        // Step 3: Fallback - Heuristic scoring (original algorithm)
        let venueScores = proposal.venues.map { scoreVenue($0) }
        let timeScores = proposal.timeSlots.map { scoreTimeSlot($0) }
        
        guard let maxVenueScore = venueScores.max(),
              let maxTimeScore = timeScores.max() else {
            return AgentDecision(
                action: .escalate,
                confidence: 0.0,
                reasoning: "No valid venue or time options",
                suggestedAlternatives: nil
            )
        }
        
        let overallScore = maxVenueScore * maxTimeScore
        
        // Step 4: Apply autonomy settings to determine action
        let autonomySettings = preferences.autonomySettings
        
        if overallScore >= autonomySettings.autoAcceptThreshold {
            // High confidence - auto-accept
            print("✅ Auto-accepting (heuristic score: \(overallScore))")
            return AgentDecision(
                action: .accept,
                confidence: overallScore,
                reasoning: "Proposal matches preferences well (score: \(String(format: "%.2f", overallScore)))",
                suggestedAlternatives: nil
            )
            
        } else if overallScore >= autonomySettings.autoCounterThreshold {
            // Medium confidence - generate counter-proposal
            print("🔄 Generating counter (heuristic score: \(overallScore))")
            let counter = try await generateCounterProposal(original: proposal)
            
            return AgentDecision(
                action: .counter,
                confidence: overallScore,
                reasoning: "Proposal partially matches - suggesting alternatives (score: \(String(format: "%.2f", overallScore)))",
                suggestedAlternatives: counter
            )
            
        } else {
            // Low confidence - escalate to user
            print("⬆️ Escalating to user (heuristic score: \(overallScore))")
            return AgentDecision(
                action: .escalate,
                confidence: overallScore,
                reasoning: "Low confidence match (score: \(String(format: "%.2f", overallScore))) - need user input",
                suggestedAlternatives: nil
            )
        }
    }
    
    /// Generate counter-suggestions with better time/venue alternatives
    /// - Parameter original: Original AI-generated suggestions to counter
    /// - Returns: Counter-suggestions with improved options
    /// - Throws: If generation fails
    ///
    /// **Note:** "Proposal" here refers to AI-suggested options, not user invitations.
    /// Negotiation lifecycle states use "awaiting_invites/awaiting_replies" terminology.
    func generateCounterProposal(original: ProposalData) async throws -> CounterProposalData {
        print("🤖 UserAgent: Generating counter-proposal...")
        
        // Try AI counter-generation if service available
        if let aiService = aiService {
            do {
                print("🧠 Using AI for counter-proposal...")
                let aiCounter = try await aiService.generateCounterWithAI(
                    original: original,
                    preferences: preferences
                )
                return aiCounter
            } catch {
                print("⚠️ AI counter generation failed: \(error.localizedDescription)")
                print("   Falling back to heuristic generation...")
                // Fall through to heuristic generation
            }
        }
        
        // Fallback - Heuristic strategy: Keep high-scoring elements, suggest better alternatives
        
        // Step 1: Analyze what's good/bad in original proposal
        let venueScores = original.venues.map { (venue: $0, score: scoreVenue($0)) }
        let timeScores = original.timeSlots.map { (slot: $0, score: scoreTimeSlot($0)) }
        
        let bestVenue = venueScores.max(by: { $0.score < $1.score })
        let _ = timeScores.max(by: { $0.score < $1.score })
        
        // Step 2: Suggest alternative time slots (based on learned patterns)
        var suggestedTimes: [TimeSlotData] = []
        
        // Get user's preferred hours from learned patterns
        let preferredHours = preferences.learnedPatterns.preferredTimes
            .sorted(by: { $0.value > $1.value })
            .prefix(3)
            .map { $0.key }
        
        // Generate time slots for preferred hours
        for hour in preferredHours {
            // Use same day of week as original proposal (if available)
            if let originalTime = original.timeSlots.first?.time {
                let calendar = Calendar.current
                var components = calendar.dateComponents([.year, .month, .day, .weekday], from: originalTime)
                components.hour = hour
                components.minute = 0
                
                if let suggestedTime = calendar.date(from: components) {
                    suggestedTimes.append(TimeSlotData(
                        time: suggestedTime,
                        durationMinutes: original.timeSlots.first?.durationMinutes ?? 60
                    ))
                }
            }
        }
        
        // Step 3: Suggest alternative venues (based on learned patterns)
        var suggestedVenues: [VenueData] = []
        
        // Get user's favorite venues from learned patterns
        let _ = preferences.learnedPatterns.favoriteVenues
            .sorted(by: { $0.value > $1.value })
            .prefix(3)
            .map { $0.key }
        
        // TODO: Fetch venue details from POI collection
        // For now, keep best venue from original proposal if available
        if let bestVenue = bestVenue {
            suggestedVenues.append(bestVenue.venue)
        }
        
        // Step 4: Build counter-proposal
        let counter = CounterProposalData(
            originalProposalId: UUID(), // TODO: Track proposal IDs
            suggestedTimeSlots: suggestedTimes.isEmpty ? original.timeSlots : suggestedTimes,
            suggestedVenues: suggestedVenues.isEmpty ? original.venues : suggestedVenues,
            reasoning: "Suggesting times that better match your typical availability",
            confidence: bestVenue?.score ?? 0.5
        )
        
        print("✅ Counter generated: \(counter.suggestedTimeSlots.count) times, \(counter.suggestedVenues.count) venues")
        return counter
    }
    
    /// Check if negotiation should escalate to user
    /// - Parameters:
    ///   - negotiation: Current negotiation state
    ///   - currentRound: Current round number
    /// - Returns: `true` if should escalate, `false` if agent can continue
    func shouldEscalate(negotiation: Negotiation, currentRound: Int) -> Bool {
        // Escalate if max rounds reached
        if currentRound >= preferences.autonomySettings.maxNegotiationRounds {
            print("⬆️ Escalating: Max rounds (\(currentRound)) reached")
            return true
        }
        
        // Escalate if user has low autonomy level
        if preferences.autonomySettings.globalAutonomyLevel < 0.3 {
            print("⬆️ Escalating: Low autonomy level (\(preferences.autonomySettings.globalAutonomyLevel))")
            return true
        }
        
        // Escalate if learned patterns have low confidence
        let patternConfidence = learningService.calculateConfidence(for: preferences.learnedPatterns)
        if patternConfidence < 0.5 {
            print("⬆️ Escalating: Low pattern confidence (\(patternConfidence))")
            return true
        }
        
        return false
    }
    
    // MARK: - Public API - Messaging
    
    /// Send encrypted agent message to peer
    /// - Parameters:
    ///   - message: Agent message to send
    ///   - recipientId: Recipient user UUID
    ///   - negotiationId: Negotiation UUID
    /// - Throws: If encryption or upload fails
    func sendMessage(
        _ message: AgentMessagePayload,
        to recipientId: UUID,
        negotiation negotiationId: UUID,
        round: Int
    ) async throws {
        print("📤 UserAgent: Sending message to \(recipientId)...")
        
        // Step 1: Encode message to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(message)
        
        // Step 2: Encrypt with shared secret (Diffie-Hellman)
        // TODO: Implement key exchange with recipient's public key
        // For now, use user's master key as placeholder
        let masterKey = try await KeychainManager.loadOrGenerateUserMasterKey()
        
        let encryptedData = try await E2EEManager.encrypt(jsonData, with: masterKey)
        let base64Payload = encryptedData.base64EncodedString()
        
        // Step 3: Create agent message record
        let messageRecord: [String: Any] = [
            "negotiation_id": negotiationId.uuidString,
            "from_user_id": userId.uuidString,
            "to_user_id": recipientId.uuidString,
            "message_type": message.type.rawValue,
            "encrypted_payload": base64Payload,
            "round": round,
            "date_created": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Step 4: Upload to Directus (convert dictionary to Data)
        let messageData = try JSONSerialization.data(withJSONObject: messageRecord)
        _ = try await directusClient.post(
            path: "/items/agent_messages",
            body: messageData
        )
        
        print("✅ Message sent successfully")
    }
    
    /// Receive and decrypt agent message from peer
    /// - Parameters:
    ///   - encryptedPayload: Base64-encoded encrypted payload
    ///   - senderId: Sender user UUID
    /// - Returns: Decrypted agent message payload
    /// - Throws: If decryption or parsing fails
    func receiveMessage(
        encryptedPayload: String,
        from senderId: UUID
    ) async throws -> AgentMessagePayload {
        print("📥 UserAgent: Receiving message from \(senderId)...")
        
        // Step 1: Decode base64
        guard let encryptedData = Data(base64Encoded: encryptedPayload) else {
            throw UserAgentError.invalidEncryptedPayload
        }
        
        // Step 2: Decrypt with shared secret
        // TODO: Derive shared secret from sender's public key
        // For now, use user's master key as placeholder
        let masterKey = try await KeychainManager.loadOrGenerateUserMasterKey()
        
        let decryptedData = try await E2EEManager.decrypt(encryptedData, with: masterKey)
        
        // Step 3: Decode JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let message = try decoder.decode(AgentMessagePayload.self, from: decryptedData)
        
        print("✅ Message received: \(message.type)")
        return message
    }
    
    // MARK: - Private Scoring Methods
    
    /// Score a venue based on learned preferences
    /// - Parameter venue: Venue to score
    /// - Returns: Score 0.0-1.0 (higher = better match)
    private func scoreVenue(_ venue: VenueData) -> Double {
        guard let venueId = venue.poiId else {
            return 0.5 // Unknown venue - neutral score
        }
        
        // Check if venue is in learned favorites
        if let score = preferences.learnedPatterns.favoriteVenues[venueId] {
            return score
        }
        
        // Check if venue category matches learned category preferences
        if let category = venue.category,
           let categoryScore = preferences.learnedPatterns.categoryPreferences[category] {
            return categoryScore * 0.8 // Slightly lower weight for category match vs exact venue
        }
        
        // Unknown venue, unknown category - return neutral
        return 0.5
    }
    
    /// Score a time slot based on learned preferences
    /// - Parameter slot: Time slot to score
    /// - Returns: Score 0.0-1.0 (higher = better match)
    private func scoreTimeSlot(_ slot: TimeSlotData) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: slot.time)
        
        // Check if hour is in learned preferred times
        if let hourScore = preferences.learnedPatterns.preferredTimes[hour] {
            return hourScore
        }
        
        // Check if neighboring hours have high scores (smooth distribution)
        let neighboringHours = [(hour - 1 + 24) % 24, (hour + 1) % 24]
        let neighborScores = neighboringHours.compactMap {
            preferences.learnedPatterns.preferredTimes[$0]
        }
        
        if !neighborScores.isEmpty {
            return neighborScores.reduce(0, +) / Double(neighborScores.count) * 0.7
        }
        
        // Unknown time - return neutral
        return 0.5
    }
    
    /// Score overall proposal (best venue × best time)
    /// - Parameters:
    ///   - venues: Proposed venues
    ///   - timeSlots: Proposed time slots
    /// - Returns: Overall score 0.0-1.0
    private func scoreOverall(venues: [VenueData], timeSlots: [TimeSlotData]) -> Double {
        let venueScores = venues.map { scoreVenue($0) }
        let timeScores = timeSlots.map { scoreTimeSlot($0) }
        
        guard let maxVenueScore = venueScores.max(),
              let maxTimeScore = timeScores.max() else {
            return 0.0
        }
        
        return maxVenueScore * maxTimeScore
    }
    
    // MARK: - AI Service Stats
    
    /// Get AI usage stats (if AI service enabled)
    /// Returns (used, limit) tuple or nil if no AI service
    @MainActor
    func getAIUsageStats() -> (used: Int, limit: Int)? {
        return aiService?.getUsageStats()
    }
}

// MARK: - Data Structures

/// Agent decision result
struct AgentDecision {
    enum Action {
        case accept
        case counter
        case escalate
    }
    
    let action: Action
    let confidence: Double // 0.0-1.0
    let reasoning: String
    let suggestedAlternatives: CounterProposalData?
}

/// Proposal data from another agent
struct ProposalData: Codable {
    let timeSlots: [TimeSlotData]
    let venues: [VenueData]
    let reasoning: String?
    let confidence: Double?
    
    enum CodingKeys: String, CodingKey {
        case timeSlots = "time_slots"
        case venues
        case reasoning
        case confidence
    }
}

/// Time slot data
struct TimeSlotData: Codable {
    let time: Date
    let durationMinutes: Int
    
    enum CodingKeys: String, CodingKey {
        case time
        case durationMinutes = "duration_minutes"
    }
}

/// Venue data
struct VenueData: Codable {
    let poiId: UUID?
    let name: String
    let address: String?
    let category: String?
    
    enum CodingKeys: String, CodingKey {
        case poiId = "poi_id"
        case name
        case address
        case category
    }
}

/// Counter-proposal data
struct CounterProposalData: Codable {
    let originalProposalId: UUID
    let suggestedTimeSlots: [TimeSlotData]
    let suggestedVenues: [VenueData]
    let reasoning: String
    let confidence: Double
    
    enum CodingKeys: String, CodingKey {
        case originalProposalId = "original_proposal_id"
        case suggestedTimeSlots = "suggested_time_slots"
        case suggestedVenues = "suggested_venues"
        case reasoning
        case confidence
    }
}

/// Agent message payload (encrypted content)
struct AgentMessagePayload: Codable {
    enum MessageType: String, Codable {
        case proposal
        case counterProposal = "counter_proposal"
        case accept
        case reject
        case escalate
        case finalize
    }
    
    let type: MessageType
    let proposalData: ProposalData?
    let counterData: CounterProposalData?
    let finalData: FinalizedPlanData?
    let reasoning: String?
    let confidence: Double?
    
    enum CodingKeys: String, CodingKey {
        case type
        case proposalData = "proposal_data"
        case counterData = "counter_data"
        case finalData = "final_data"
        case reasoning
        case confidence
    }
}

/// Finalized plan data (consensus reached)
struct FinalizedPlanData: Codable {
    let finalTime: Date
    let finalVenue: VenueData
    let eventId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case finalTime = "final_time"
        case finalVenue = "final_venue"
        case eventId = "event_id"
    }
}

// MARK: - Errors

enum UserAgentError: Error, LocalizedError {
    case encryptionKeyNotFound
    case invalidEncryptedPayload
    case evaluationFailed
    case counterGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .encryptionKeyNotFound:
            return "Encryption key not found. Please log in again."
        case .invalidEncryptedPayload:
            return "Could not decrypt agent message."
        case .evaluationFailed:
            return "Failed to evaluate proposal."
        case .counterGenerationFailed:
            return "Failed to generate counter-proposal."
        }
    }
}
