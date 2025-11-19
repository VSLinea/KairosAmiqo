//
//  AutoAcceptScenarioTest.swift
//  KairosAmiqoTests
//
//  Task 28 Week 3: Agent-to-Agent End-to-End Testing
//  Scenario: Both users have agent mode ON, agents agree in 1 round
//
//  Run test: Open Xcode → Product → Test (Cmd+U)
//  Or: xcodebuild test -scheme KairosAmiqo -destination 'platform=iOS Simulator,name=iPhone 15'
//

import XCTest
@testable import KairosAmiqo

@MainActor
final class AutoAcceptScenarioTest: XCTestCase {
    
    // MARK: - Test: Heuristic Auto-Accept (No AI)
    
    func testHeuristicAutoAccept() async throws {
        // GIVEN: User preferences with high coffee score
        let preferences = AgentPreferences(
            id: UUID(),
            userId: UUID(),
            learnedPatterns: LearnedPatterns(
                favoriteVenues: [],
                preferredTimes: [14, 15, 16], // 2pm-4pm preferred
                preferredDayOfWeek: nil,
                categoryScores: ["coffee": 0.92, "dinner": 0.78], // High coffee preference
                venueFrequency: [:],
                averageGroupSize: 2.5
            ),
            vetoRules: VetoRules(
                neverAfterHour: 22, // No plans after 10pm
                neverBeforeHour: 8,  // No plans before 8am
                blockedDays: [],
                blockedVenues: [],
                blockedCategories: [],
                minGroupSize: nil,
                maxGroupSize: nil
            ),
            autonomySettings: AutonomySettings(
                isGloballyEnabled: true,
                autoAcceptThreshold: 0.8,  // 80% confidence to auto-accept
                autoCounterThreshold: 0.5, // 50% confidence to counter
                maxRounds: 3
            ),
            lastUpdated: Date()
        )
        
        // AND: Proposal that matches preferences (coffee at 2pm)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let proposedTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: tomorrow)! // 2pm tomorrow
        
        let proposal = ProposalData(
            timeSlots: [
                TimeSlotData(time: proposedTime, durationMinutes: 60)
            ],
            venues: [
                VenueData(poiId: nil, name: "Local Cafe", address: nil, category: "coffee")
            ],
            reasoning: "Let's grab coffee!",
            confidence: 0.9
        )
        
        // WHEN: Agent evaluates (WITHOUT AI service - heuristic only)
        let directusClient = HTTPClient(base: Config.directusBase)
        let userAgent = UserAgentManager(
            userId: UUID(),
            preferences: preferences,
            directusClient: directusClient,
            openAIKey: nil // Force heuristic mode
        )
        
        let decision = try await userAgent.evaluateProposal(proposal)
        
        // THEN: Agent should auto-accept (high confidence match)
        XCTAssertEqual(decision.action, .accept, "Agent should auto-accept when proposal matches preferences")
        XCTAssertGreaterThanOrEqual(decision.confidence, 0.5, "Confidence should be reasonable for matching proposal")
        XCTAssertNil(decision.suggestedAlternatives, "Should not generate counter when accepting")
        XCTAssertNotNil(decision.reasoning, "Should provide reasoning for decision")
        
        print("✅ [Test] Heuristic auto-accept passed:")
        print("  - Action: \(decision.action)")
        print("  - Confidence: \(decision.confidence)")
        print("  - Reasoning: \(decision.reasoning)")
    }
    
    // MARK: - Test: Auto-Accept with Venue Suggestion
    
    func testAutoAcceptWithVenueSuggestion() async throws {
        // GIVEN: Proposal is flexible on venue, agent suggests favorite
        let proposal = Negotiation(
            id: UUID(),
            title: "Coffee at your favorite spot",
            status: .pending,
            initiator: "user-a-uuid",
            participants: [
                NegotiationParticipant(
                    id: "user-b-uuid",
                    name: "Bob",
                    status: .pending,
                    isAgent: true
                )
            ],
            proposedSlots: [
                ProposedSlot(
                    time: "2024-11-05T15:00:00Z", // 3pm
                    venue: nil // Flexible - agent should suggest
                )
            ],
            intentCategory: "coffee",
            round: 1,
            lastUpdated: Date()
        )
        
        // WHEN: Agent evaluates
        let userAgent = UserAgentManager(userId: "user-b-uuid", appVM: appVM)
        let decision = try await userAgent.evaluateProposal(proposal)
        
        // THEN: Agent accepts AND suggests favorite venue
        XCTAssertEqual(decision.action, .accept, "Should accept flexible proposal")
        
        // Agent may suggest venue in reasoning/notes
        if let reasoning = decision.reasoning {
            XCTAssertTrue(
                reasoning.contains("cafe") || reasoning.contains("downtown"),
                "Reasoning should mention preferred venue"
            )
        }
        
        print("✅ [Test] Auto-accept with venue suggestion passed")
    }
    
    // MARK: - Test: Confidence Threshold Boundary
    
    func testConfidenceThresholdBoundary() async throws {
        // GIVEN: Proposal is borderline (70% confidence - below 80% threshold)
        let proposal = Negotiation(
            id: UUID(),
            title: "Dinner this weekend",
            status: .pending,
            initiator: "user-a-uuid",
            participants: [
                NegotiationParticipant(
                    id: "user-b-uuid",
                    name: "Bob",
                    status: .pending,
                    isAgent: true
                )
            ],
            proposedSlots: [
                ProposedSlot(
                    time: "2024-11-09T19:00:00Z", // Saturday 7pm (no preference for weekends)
                    venue: nil
                )
            ],
            intentCategory: "dinner", // Lower score (0.78 vs coffee 0.92)
            round: 1,
            lastUpdated: Date()
        )
        
        // WHEN: Agent evaluates
        let userAgent = UserAgentManager(userId: "user-b-uuid", appVM: appVM)
        let decision = try await userAgent.evaluateProposal(proposal)
        
        // THEN: Agent should counter (below auto-accept threshold) or escalate
        XCTAssertTrue(
            decision.action == .counter || decision.action == .escalate,
            "Should counter or escalate when confidence < 80%"
        )
        
        if decision.action == .counter {
            XCTAssertNotNil(decision.counterProposal, "Counter action should include alternative")
        }
        
        print("✅ [Test] Confidence threshold boundary passed:")
        print("  - Action: \(decision.action)")
        print("  - Confidence: \(decision.confidence)")
    }
}
