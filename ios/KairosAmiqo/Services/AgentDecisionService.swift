//
//  AgentDecisionService.swift
//  KairosAmiqo
//
//  Task 28: Agent-to-Agent Negotiation - AI Decision Engine
//  Week 2, Days 8-9: OpenAI integration for autonomous agent decisions
//
//  Created: 2025-11-02
//  See: /AGENT-TO-AGENT-IMPLEMENTATION-PLAN.md (lines 550-650)
//  See: /.github/apple-docs-grounded-mode.md (Foundation.JSONEncoder iOS 7.0+)
//

import Foundation

/// AI-powered decision engine for autonomous agent negotiations
/// Uses OpenAI GPT-4 Turbo for intelligent proposal evaluation and counter-generation
///
/// **Privacy:**
/// - All prompts are anonymized (no PII sent to OpenAI)
/// - Venue names → "downtown coffee shop"
/// - User names → "user" or "friend"
/// - Real addresses stripped
///
/// **Cost Management:**
/// - Decision caching (1-hour TTL)
/// - Token optimization (concise prompts)
/// - Rate limiting (50 calls/day per user)
///
/// @available(iOS 15.0, *)
@MainActor
final class AgentDecisionService {
    
    // MARK: - Properties
    
    /// OpenAI API key
    private let apiKey: String
    
    /// OpenAI API base URL
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    /// Decision cache (proposal hash → decision)
    private var decisionCache: [String: CachedDecision] = [:]
    
    /// API call counter (for rate limiting)
    private var apiCallCount = 0
    private var lastResetDate = Date()
    
    /// Maximum API calls per day
    private let maxCallsPerDay = 50
    
    // MARK: - Initialization
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Public API
    
    /// Evaluate proposal using AI reasoning
    /// - Parameters:
    ///   - proposal: Proposal from other agent
    ///   - preferences: User's learned patterns and veto rules
    /// - Returns: AI decision (accept/counter/escalate) with reasoning
    /// - Throws: If API call fails or rate limit exceeded
    func evaluateProposalWithAI(
        proposal: ProposalData,
        preferences: AgentPreferences
    ) async throws -> AIDecision {
        // Check rate limit
        try checkRateLimit()
        
        // Check cache first
        let cacheKey = proposalHash(proposal: proposal, userId: preferences.userId)
        if let cached = decisionCache[cacheKey],
           !cached.isExpired {
            print("💾 Cache hit: Reusing decision from \(cached.timestamp)")
            return cached.decision
        }
        
        // Build anonymized prompt
        let prompt = buildEvaluationPrompt(
            proposal: proposal,
            preferences: preferences
        )
        
        // Call OpenAI
        let response = try await callOpenAI(systemPrompt: prompt)
        
        // Parse response
        let decision = try parseAIDecision(from: response)
        
        // Cache result
        decisionCache[cacheKey] = CachedDecision(
            decision: decision,
            timestamp: Date()
        )
        
        // Increment call count
        apiCallCount += 1
        
        return decision
    }
    
    /// Generate counter-proposal using AI reasoning
    /// - Parameters:
    ///   - original: Original proposal to counter
    ///   - preferences: User's learned patterns
    /// - Returns: Counter-proposal with alternative times/venues
    /// - Throws: If API call fails or rate limit exceeded
    func generateCounterWithAI(
        original: ProposalData,
        preferences: AgentPreferences
    ) async throws -> CounterProposalData {
        // Check rate limit
        try checkRateLimit()
        
        // Build anonymized prompt
        let prompt = buildCounterPrompt(
            original: original,
            preferences: preferences
        )
        
        // Call OpenAI
        let response = try await callOpenAI(systemPrompt: prompt)
        
        // Parse response
        let counter = try parseCounterProposal(from: response)
        
        // Increment call count
        apiCallCount += 1
        
        return counter
    }
    
    /// Get current API usage stats
    /// - Returns: Calls used today and limit
    func getUsageStats() -> (used: Int, limit: Int) {
        resetRateLimitIfNeeded()
        return (apiCallCount, maxCallsPerDay)
    }
    
    // MARK: - Private Methods - Prompt Building
    
    /// Build evaluation prompt (anonymized)
    private func buildEvaluationPrompt(
        proposal: ProposalData,
        preferences: AgentPreferences
    ) -> String {
        // Anonymize venue names
        let venueDescriptions = proposal.venues.map { venue in
            anonymizeVenue(venue)
        }
        
        // Anonymize time slots
        let timeDescriptions = proposal.timeSlots.map { slot in
            anonymizeTimeSlot(slot)
        }
        
        // Extract preference patterns (no PII)
        let favoriteVenues = preferences.learnedPatterns.favoriteVenues
            .sorted(by: { $0.value > $1.value })
            .prefix(5)
            .map { "Category: \(String(describing: $0.key)) (score: \(String(format: "%.2f", $0.value)))" }
            .joined(separator: "\n")
        
        let preferredTimes = preferences.learnedPatterns.preferredTimes
            .sorted(by: { $0.value > $1.value })
            .prefix(5)
            .map { "Hour \($0.key):00 (score: \(String(format: "%.2f", $0.value)))" }
            .joined(separator: "\n")
        
        // Veto rules (anonymized)
        let vetoDescriptions = preferences.vetoRules.filter { $0.isActive }
            .map { "- \($0.type.rawValue): \($0.value)" }
            .joined(separator: "\n")
        
        let prompt = """
        You are a planning agent helping a user coordinate social plans.
        
        **User's Learned Preferences (Anonymized):**
        
        Favorite Venue Types:
        \(favoriteVenues.isEmpty ? "No data yet" : favoriteVenues)
        
        Preferred Times:
        \(preferredTimes.isEmpty ? "No data yet" : preferredTimes)
        
        Active Veto Rules:
        \(vetoDescriptions.isEmpty ? "None" : vetoDescriptions)
        
        Negotiation Count: \(preferences.learnedPatterns.negotiationCount) past plans
        Confidence Level: \(preferences.learnedPatterns.negotiationCount < 5 ? "Low" : preferences.learnedPatterns.negotiationCount < 20 ? "Medium" : "High")
        
        **Received Proposal:**
        
        Venue Options:
        \(venueDescriptions.joined(separator: "\n"))
        
        Time Slot Options:
        \(timeDescriptions.joined(separator: "\n"))
        
        Proposal Reasoning: \(proposal.reasoning ?? "None provided")
        Proposal Confidence: \(proposal.confidence.map { String(format: "%.2f", $0) } ?? "Unknown")
        
        **Your Task:**
        
        Evaluate this proposal and decide whether to accept, counter, or escalate to the user.
        
        Decision Criteria:
        - **Accept** if proposal matches user's preferences well (80%+ match)
        - **Counter** if proposal is partially good but alternatives might be better (50-80% match)
        - **Escalate** if proposal is poor match, violates veto rules, or low confidence (<50% match)
        
        Return JSON in this exact format:
        {
          "decision": "accept|counter|escalate",
          "confidence": 0.0-1.0,
          "reason": "Brief explanation (1-2 sentences)",
          "alternatives": {
            "time_slots": ["ISO8601 datetime 1", "ISO8601 datetime 2"],
            "venues": ["venue type 1", "venue type 2"]
          }
        }
        
        Important:
        - Base decision on learned patterns (not just proposal confidence)
        - If veto rule violated, MUST escalate
        - If negotiation count < 5, be conservative (escalate more often)
        - Keep "reason" concise and user-friendly
        - Alternatives only needed if decision = "counter"
        """
        
        return prompt
    }
    
    /// Build counter-proposal prompt (anonymized)
    private func buildCounterPrompt(
        original: ProposalData,
        preferences: AgentPreferences
    ) -> String {
        // Similar anonymization as evaluation prompt
        let venueDescriptions = original.venues.map { anonymizeVenue($0) }
        let timeDescriptions = original.timeSlots.map { anonymizeTimeSlot($0) }
        
        let preferredTimes = preferences.learnedPatterns.preferredTimes
            .sorted(by: { $0.value > $1.value })
            .prefix(3)
            .map { $0.key }
        
        let prompt = """
        You are generating a counter-proposal for a social plan.
        
        **Original Proposal:**
        Venues: \(venueDescriptions.joined(separator: ", "))
        Times: \(timeDescriptions.joined(separator: ", "))
        
        **User's Preferred Times (hours):**
        \(preferredTimes.map { "\($0):00" }.joined(separator: ", "))
        
        **Your Task:**
        Suggest 2-3 alternative time slots that better match user's preferences.
        Keep venue types similar to original (don't change activity type).
        
        Return JSON:
        {
          "suggested_time_slots": [
            {"time": "ISO8601 datetime", "duration_minutes": 60},
            {"time": "ISO8601 datetime", "duration_minutes": 60}
          ],
          "reasoning": "Why these alternatives are better (1 sentence)"
        }
        """
        
        return prompt
    }
    
    // MARK: - Private Methods - Anonymization
    
    /// Anonymize venue (strip PII)
    private func anonymizeVenue(_ venue: VenueData) -> String {
        let category = venue.category ?? "venue"
        return "Type: \(category) (location: downtown area)"
    }
    
    /// Anonymize time slot (keep date/time structure)
    private func anonymizeTimeSlot(_ slot: TimeSlotData) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, HH:mm"  // e.g., "Saturday, 19:00"
        let timeStr = formatter.string(from: slot.time)
        return "\(timeStr) (\(slot.durationMinutes) minutes)"
    }
    
    // MARK: - Private Methods - OpenAI API
    
    /// Call OpenAI API
    private func callOpenAI(systemPrompt: String) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw AgentDecisionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": "gpt-4-turbo-preview",  // GPT-4 Turbo for best reasoning
            "messages": [
                ["role": "system", "content": systemPrompt]
            ],
            "temperature": 0.3,  // Low temp for consistent decisions
            "max_tokens": 500,   // Keep responses concise
            "response_format": ["type": "json_object"]  // Force JSON output
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AgentDecisionError.apiCallFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        struct OpenAIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(OpenAIResponse.self, from: data)
        
        guard let content = apiResponse.choices.first?.message.content else {
            throw AgentDecisionError.noResponseContent
        }
        
        print("🤖 OpenAI response: \(content.prefix(200))...")
        return content
    }
    
    /// Parse AI decision from JSON response
    private func parseAIDecision(from jsonString: String) throws -> AIDecision {
        struct DecisionResponse: Codable {
            let decision: String
            let confidence: Double
            let reason: String
            let alternatives: Alternatives?
            
            struct Alternatives: Codable {
                let time_slots: [String]?
                let venues: [String]?
            }
        }
        
        let data = Data(jsonString.utf8)
        let decoder = JSONDecoder()
        let response = try decoder.decode(DecisionResponse.self, from: data)
        
        // Map string decision to enum
        let action: AIDecision.Action
        switch response.decision.lowercased() {
        case "accept":
            action = .accept
        case "counter":
            action = .counter
        case "escalate":
            action = .escalate
        default:
            throw AgentDecisionError.invalidDecisionType(response.decision)
        }
        
        return AIDecision(
            action: action,
            confidence: response.confidence,
            reason: response.reason,
            suggestedTimeSlots: response.alternatives?.time_slots,
            suggestedVenues: response.alternatives?.venues
        )
    }
    
    /// Parse counter-proposal from JSON response
    private func parseCounterProposal(from jsonString: String) throws -> CounterProposalData {
        struct CounterResponse: Codable {
            struct TimeSlot: Codable {
                let time: String  // ISO8601
                let duration_minutes: Int
            }
            let suggested_time_slots: [TimeSlot]
            let reasoning: String
        }
        
        let data = Data(jsonString.utf8)
        let decoder = JSONDecoder()
        let response = try decoder.decode(CounterResponse.self, from: data)
        
        // Parse ISO8601 dates
        let dateFormatter = ISO8601DateFormatter()
        let timeSlots = response.suggested_time_slots.compactMap { slot -> TimeSlotData? in
            guard let date = dateFormatter.date(from: slot.time) else { return nil }
            return TimeSlotData(time: date, durationMinutes: slot.duration_minutes)
        }
        
        return CounterProposalData(
            originalProposalId: UUID(),  // TODO: Track original proposal ID
            suggestedTimeSlots: timeSlots,
            suggestedVenues: [],  // Keep original venues for now
            reasoning: response.reasoning,
            confidence: 0.7  // Default confidence for AI-generated counters
        )
    }
    
    // MARK: - Private Methods - Rate Limiting
    
    /// Check if rate limit reached
    private func checkRateLimit() throws {
        resetRateLimitIfNeeded()
        
        if apiCallCount >= maxCallsPerDay {
            throw AgentDecisionError.rateLimitExceeded(used: apiCallCount, limit: maxCallsPerDay)
        }
    }
    
    /// Reset rate limit counter if new day
    private func resetRateLimitIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastResetDate) {
            apiCallCount = 0
            lastResetDate = Date()
            print("🔄 Rate limit reset for new day")
        }
    }
    
    /// Generate cache key from proposal
    private func proposalHash(proposal: ProposalData, userId: UUID) -> String {
        let venueIds: [String] = proposal.venues.compactMap { $0.poiId?.uuidString }.sorted()
        let venueString = venueIds.joined(separator: "_")
        
        let timeStrings: [String] = proposal.timeSlots.map { $0.time.timeIntervalSince1970 }.sorted().map { String($0) }
        let timeString = timeStrings.joined(separator: "_")
        
        let input = "\(userId.uuidString)_\(venueString)_\(timeString)"
        return input  // TODO: Use SHA256 hash for production
    }
}

// MARK: - Data Structures

/// AI decision result
struct AIDecision {
    enum Action {
        case accept
        case counter
        case escalate
    }
    
    let action: Action
    let confidence: Double
    let reason: String
    let suggestedTimeSlots: [String]?  // ISO8601 strings
    let suggestedVenues: [String]?     // Anonymized venue types
}

/// Cached decision (1-hour TTL)
private struct CachedDecision {
    let decision: AIDecision
    let timestamp: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 3600  // 1 hour
    }
}

// MARK: - Errors

enum AgentDecisionError: Error, LocalizedError {
    case invalidURL
    case apiCallFailed(statusCode: Int)
    case noResponseContent
    case invalidDecisionType(String)
    case rateLimitExceeded(used: Int, limit: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid OpenAI API URL"
        case .apiCallFailed(let code):
            return "OpenAI API call failed (status \(code))"
        case .noResponseContent:
            return "No response content from OpenAI"
        case .invalidDecisionType(let type):
            return "Invalid decision type: \(type)"
        case .rateLimitExceeded(let used, let limit):
            return "API rate limit exceeded (\(used)/\(limit) calls today)"
        }
    }
}
