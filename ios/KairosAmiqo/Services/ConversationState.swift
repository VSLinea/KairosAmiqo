//
//  ConversationState.swift
//  KairosAmiqo
//
//  Phase 2: Conversational AI Planning - State Machine
//  Task: Agent-to-Agent Negotiation (Conversation State Management)
//  See: /HANDOVER-CONVERSATIONAL-AI-IMPLEMENTATION.md (Days 3-4)
//

import Foundation

/// Manages conversation state for AI-assisted invitation creation
/// Tracks progress through planning stages and collects user preferences
@MainActor
class ConversationState: ObservableObject {
    // MARK: - Published State
    
    @Published var currentStage: Stage = .greeting
    @Published var collectedData: CollectedData = CollectedData()
    
    // MARK: - Conversation Stages
    
    enum Stage {
    case greeting           // Initial "What invitation would you like to send?"
        case intent             // What kind of activity? (dinner, coffee, etc.)
        case participants       // Who's invited?
        case timing             // When? (this weekend, next week, flexible)
        case venue              // Where? (specific place or suggestions)
        case confirmation       // Review and confirm
        case complete           // Ready to send
        
        var prompt: String {
            switch self {
            case .greeting:
                return "Hi! I'm Amiqo, your invitation assistant. What invitation would you like to send?"
            case .intent:
                return "Great choice! Tell me more about what you have in mind."
            case .participants:
                return "Awesome! Who would you like to invite?"
            case .timing:
                return "Perfect! When are you thinking?"
            case .venue:
                return "Great! Any preferences for where?"
            case .confirmation:
                return "Let me recap the invitation details. Does this look good?"
            case .complete:
                return "All set! I'll send the invites now."
            }
        }
        
        var suggestions: [String] {
            switch self {
            case .greeting, .intent:
                return [
                    "Dinner with friends",
                    "Weekend hangout",
                    "Coffee meetup",
                    "Game night"
                ]
            case .venue:
                return [
                    "I have a place in mind",
                    "Suggest some options",
                    "Flexible"
                ]
            case .timing:
                return [
                    "This weekend",
                    "Next week",
                    "Flexible"
                ]
            case .participants:
                return [
                    "Just a few close friends",
                    "The whole group",
                    "I'll pick specific people"
                ]
            case .confirmation:
                return [
                    "Yes, send it!",
                    "Let me change something",
                    "Start over"
                ]
            case .complete:
                return []
            }
        }
        
        var next: Stage? {
            switch self {
            case .greeting: return .intent
            case .intent: return .venue        // After "what", ask "where"
            case .venue: return .timing        // After "where", ask "when"
            case .timing: return .participants // After "when", ask "who"
            case .participants: return .confirmation
            case .confirmation: return .complete
            case .complete: return nil
            }
        }
    }
    
    // MARK: - Collected Data
    
    struct CollectedData {
        var intent: String?
        var participants: [String] = []
        var timePreference: String?
        var venuePreference: String?
        var additionalNotes: String?
        
        /// Convert to DraftPlan for transition to manual wizard
        func toDraftPlan() -> DraftPlan {
            // TODO(Phase 3): Parse natural language into structured data
            // For now, store raw text
            return DraftPlan(
                participants: participants.map { name in
                    // Generate temporary UUID for non-Kairos users
                    // Backend will resolve this when sending invites
                    PlanParticipant(
                        user_id: UUID(), // Temporary UUID for participant
                        name: name,
                        email: nil,
                        phone: nil,
                        status: "invited"
                    )
                },
                intent: nil, // TODO: Map intent string to IntentTemplate
                times: timePreference.map { timeText in
                    [ProposedSlot(
                        time: timeText, // ISO8601 format expected
                        venue: nil // No venue attached to time slot yet
                    )]
                } ?? [],
                venues: venuePreference.map { venueText in
                    [VenueInfo(
                        id: nil, // Custom user-entered venue (no POI match)
                        name: venueText,
                        lat: nil,
                        lon: nil,
                        address: nil,
                        category: nil,
                        price_band: nil
                    )]
                } ?? []
            )
        }
    }
    
    // MARK: - State Management
    
    /// Process user input and advance conversation
    func processUserInput(_ input: String) {
        // Store input based on current stage
        switch currentStage {
        case .greeting, .intent:
            collectedData.intent = input
        case .participants:
            // Parse participant names (comma-separated or natural language)
            let names = parseParticipants(from: input)
            collectedData.participants = names
        case .timing:
            collectedData.timePreference = input
        case .venue:
            collectedData.venuePreference = input
        case .confirmation:
            // User confirmed or wants to edit
            if input.lowercased().contains("yes") || input.lowercased().contains("send") {
                currentStage = .complete
            }
            return
        case .complete:
            return
        }
        
        // Advance to next stage
        if let nextStage = currentStage.next {
            currentStage = nextStage
        }
    }
    
    /// Generate AI response for current stage
    func getAIResponse() -> (message: String, suggestions: [String]) {
        return (currentStage.prompt, currentStage.suggestions)
    }
    
    /// Check if conversation is complete and ready to send an invitation
    var isComplete: Bool {
        currentStage == .complete
    }
    
    /// Reset conversation state
    func reset() {
        currentStage = .greeting
        collectedData = CollectedData()
    }
    
    // MARK: - Helpers
    
    /// Parse participant names from natural language input
    private func parseParticipants(from input: String) -> [String] {
        // Simple parsing: split by commas or "and"
        let separators = CharacterSet(charactersIn: ",")
        let parts = input.components(separatedBy: separators)
        
        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: " and ", with: ", ") }
            .flatMap { $0.components(separatedBy: ", ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
