import Foundation

// MARK: - AIService Protocol

/// Protocol for AI services that generate plan proposals
/// Allows swapping between OpenAI, Together AI, Groq, etc.
///
/// **Terminology Note:** "Proposal" in this context refers to AI-generated time/venue suggestions,
/// NOT user invitations. Negotiation lifecycle states use "awaiting_invites/awaiting_replies" terminology.
protocol AIService {
    /// Generate AI-suggested time/venue options for a plan
    /// - Parameters:
    ///   - intent: Plan intent (e.g., "Coffee", "Lunch", "Dinner")
    ///   - participants: List of participant names
    ///   - constraints: Additional constraints (time, budget, radius, etc.)
    /// - Returns: AI-generated suggestions with time slots and venues
    ///
    /// **Note:** "Proposal" here means AI-suggested options, not user invitations.
    func generateProposal(
        intent: String,
        participants: [String],
        constraints: [String: Any]
    ) async throws -> AIProposal
    
    /// Suggest alternatives based on feedback (Phase 2 feature - not MVP)
    /// - Parameters:
    ///   - currentProposal: The current proposal to improve
    ///   - feedback: User feedback (e.g., "Too expensive", "Different time")
    /// - Returns: Alternative proposals
    func suggestAlternatives(
        currentProposal: AIProposal,
        feedback: String
    ) async throws -> [AIProposal]
}

// MARK: - OpenAI Request/Response Models

private struct OpenAIChatRequest: Codable {
    struct Message: Codable {
        let role: String
        let content: String
    }
    
    let model: String
    let messages: [Message]
    let temperature: Double
    let response_format: ResponseFormat?
    
    struct ResponseFormat: Codable {
        let type: String
    }
}

private struct OpenAIChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let message: Message
    }
    
    let choices: [Choice]
}

// MARK: - OpenAI Service Implementation

/// OpenAI-based AI service (GPT-3.5-turbo or GPT-4)
/// Cost: ~$0.002 per request with GPT-3.5-turbo
class OpenAIService: AIService {
    private let apiKey: String
    private let httpClient: HTTPClient
    private let cache: AIResponseCache
    private let model: String
    
    init(model: String = "gpt-3.5-turbo") {
        self.apiKey = Secrets.openAIAPIKey
        self.httpClient = HTTPClient(base: URL(string: "https://api.openai.com/v1")!)
        self.cache = AIResponseCache()
        self.model = model
    }
    
    func generateProposal(
        intent: String,
        participants: [String],
        constraints: [String: Any]
    ) async throws -> AIProposal {
        // 1. Check cache first
        let cacheKey = makeCacheKey(intent: intent, participants: participants, constraints: constraints)
        if let cached = cache.get(key: cacheKey) {
            print("✅ Cache hit for AI proposal")
            return cached
        }
        
        // 2. Build prompt
        let prompt = buildPrompt(intent: intent, participants: participants, constraints: constraints)
        
        // 3. Call OpenAI API
        let request = OpenAIChatRequest(
            model: model,
            messages: [
                OpenAIChatRequest.Message(role: "system", content: systemPrompt),
                OpenAIChatRequest.Message(role: "user", content: prompt)
            ],
            temperature: 0.7,
            response_format: OpenAIChatRequest.ResponseFormat(type: "json_object")
        )
        
        let (data, _) = try await httpClient.postJSON(
            path: "/chat/completions",
            body: request,
            headers: [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json"
            ]
        )
        
        // 4. Parse response
        let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = response.choices.first?.message.content else {
            throw AIServiceError.invalidResponse
        }
        
        // 5. Decode AI proposal
        guard let proposalData = content.data(using: .utf8) else {
            throw AIServiceError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let proposal = try decoder.decode(AIProposal.self, from: proposalData)
        
        // 6. Cache result
        cache.set(key: cacheKey, value: proposal, ttl: 86400) // 24 hours
        
        return proposal
    }
    
    func suggestAlternatives(
        currentProposal: AIProposal,
        feedback: String
    ) async throws -> [AIProposal] {
        // Phase 2 feature - not implemented in MVP
        throw AIServiceError.notImplemented
    }
    
    // MARK: - Private Helpers
    
    private func makeCacheKey(intent: String, participants: [String], constraints: [String: Any]) -> String {
        let sortedParticipants = participants.sorted().joined(separator: ",")
        let constraintsStr = constraints.map { "\($0.key):\($0.value)" }.sorted().joined(separator: "|")
        return "\(intent)|\(sortedParticipants)|\(constraintsStr)"
    }
    
    private var systemPrompt: String {
        """
        You are Amiqo, a friendly AI assistant helping friends make social plans.
        
        Your job is to suggest time slots and venues for group activities.
        Be conversational, helpful, and consider everyone's needs.
        
        Always respond in valid JSON format with this structure:
        {
          "timeSlots": [
            {"start": "2025-11-03T14:00:00Z", "end": "2025-11-03T15:00:00Z", "reason": "..."},
            {"start": "2025-11-03T19:00:00Z", "end": "2025-11-03T20:30:00Z", "reason": "..."},
            {"start": "2025-11-04T11:00:00Z", "end": "2025-11-04T12:30:00Z", "reason": "..."}
          ],
          "venues": [
            {"name": "...", "address": "...", "category": "cafe", "reason": "..."},
            {"name": "...", "address": "...", "category": "restaurant", "reason": "..."},
            {"name": "...", "address": "...", "category": "bar", "reason": "..."}
          ],
          "explanation": "Here's why I think these options would work well for your group...",
          "confidence": 0.85
        }
        
        Guidelines:
        - Suggest 3 time slots and 3 venues
        - Use ISO8601 format for dates (e.g., "2025-11-03T14:00:00Z")
        - Confidence should be 0.0-1.0 (higher = more confident)
        - Be specific with venue addresses (real or plausible)
        - Consider the intent and participant count
        """
    }
    
    private func buildPrompt(intent: String, participants: [String], constraints: [String: Any]) -> String {
        var prompt = """
        Help plan a social activity with these details:
        
        Intent: \(intent)
        Participants: \(participants.joined(separator: ", ")) (\(participants.count) people)
        """
        
        if let time = constraints["time"] as? String {
            prompt += "\nPreferred time: \(time)"
        }
        
        if let budget = constraints["budget"] as? String {
            prompt += "\nBudget: \(budget)"
        }
        
        if let radius = constraints["radius"] as? Double {
            prompt += "\nRadius: \(radius) km"
        }
        
        prompt += """
        
        
        Suggest 3 time slots and 3 venues that would work well for this group.
        Consider typical schedules (work hours, weekends, etc.) and the activity type.
        """
        
        return prompt
    }
}

// MARK: - AI Service Manager

/// Manages AI service with fallback chain (OpenAI primary, others as fallback)
class AIServiceManager {
    private let primary: AIService
    
    init() {
        // For MVP: OpenAI only
        // Phase 2: Add fallback providers (Together AI, Groq)
        self.primary = OpenAIService(model: "gpt-3.5-turbo")
    }
    
    func generateProposal(
        intent: String,
        participants: [String],
        constraints: [String: Any]
    ) async throws -> AIProposal {
        do {
            return try await primary.generateProposal(
                intent: intent,
                participants: participants,
                constraints: constraints
            )
        } catch {
            print("❌ AI service error: \(error)")
            // Phase 2: Try fallback providers here
            throw error
        }
    }
}

// MARK: - Errors

enum AIServiceError: Error, LocalizedError {
    case invalidResponse
    case notImplemented
    case rateLimitExceeded
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "AI service returned an invalid response"
        case .notImplemented:
            return "Feature not yet implemented"
        case .rateLimitExceeded:
            return "AI request limit exceeded. Please try again later."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
