//
//  ConversationalAIService.swift
//  KairosAmiqo
//
//  Phase 3: Conversational AI Planning - OpenAI Integration
//  Task: Agent-to-Agent Negotiation (AI Service for Chat)
//  See: /HANDOVER-CONVERSATIONAL-AI-IMPLEMENTATION.md (Days 5-7)
//

import Foundation

/// AI service for conversational plan creation
/// Extends base AI capabilities with chat-specific prompting
@MainActor
class ConversationalAIService {
    private let openAIKey: String?
    private let baseURL: String
    private let modelName: String
    
    /// Initialize with LM Studio (local Llama model) or OpenAI
    /// - Parameters:
    ///   - apiKey: Optional API key (not needed for LM Studio)
    ///   - useLMStudio: If true, uses local LM Studio server (default: true for Phase 5)
    init(apiKey: String? = nil, useLMStudio: Bool = true) {
        self.openAIKey = apiKey
        
        if useLMStudio {
            // LM Studio default endpoint (local server)
            #if targetEnvironment(simulator)
                self.baseURL = "http://localhost:11234/v1/chat/completions"
            #else
                // Physical device - use Mac's LAN IP
                self.baseURL = "http://192.168.68.108:11234/v1/chat/completions"
            #endif
            self.modelName = "meta-llama-3.1-8b-instruct"  // User's LM Studio model identifier
            print("🤖 [AI] Using LM Studio (local Llama 3.1-8B Instruct) at \(baseURL)")
        } else {
            // OpenAI API (original implementation)
            self.baseURL = "https://api.openai.com/v1/chat/completions"
            self.modelName = "gpt-3.5-turbo"
            print("🤖 [AI] Using OpenAI API (GPT-3.5-turbo)")
        }
    }
    
    /// AI response with contextual suggestions
    struct AIResponse {
        let message: String
        let suggestions: [String]
    }
    
    /// Generate AI response for current conversation stage (token-optimized with history)
    /// - Parameters:
    ///   - stage: Current conversation stage
    ///   - userInput: User's latest message
    ///   - collectedData: Data collected so far (semantic context)
    ///   - conversationHistory: Recent message pairs for context (last 4-6 messages)
    ///   - userPreferences: User's learned preferences (optional)
    /// - Returns: AI response with message and contextual suggestions
    func generateResponse(
        for stage: ConversationState.Stage,
        userInput: String,
        collectedData: ConversationState.CollectedData,
        conversationHistory: [(role: String, content: String)] = [],
        userPreferences: UserPreferences? = nil
    ) async throws -> AIResponse {
        let systemPrompt = buildSystemPrompt(
            for: stage,
            userPreferences: userPreferences
        )
        
        let response = try await callOpenAI(
            systemPrompt: systemPrompt,
            userInput: userInput,
            collectedData: collectedData,
            conversationHistory: conversationHistory
        )
        
        return response
    }
    
    // MARK: - User Preferences (Learning Foundation)
    
    /// User's learned preferences for personalized AI responses
    struct UserPreferences {
        var favoriteActivities: [String] = []
        var preferredTimes: [String] = []  // e.g., "weekends", "evenings"
        var frequentVenues: [String] = []
        var typicalGroupSize: Int? = nil
        var planningStyle: String? = nil  // e.g., "spontaneous", "detailed"
        
        var isEmpty: Bool {
            favoriteActivities.isEmpty &&
            preferredTimes.isEmpty &&
            frequentVenues.isEmpty &&
            typicalGroupSize == nil &&
            planningStyle == nil
        }
    }
    
    // MARK: - Prompt Engineering
    
    /// Build system prompt for current conversation stage
    private func buildSystemPrompt(
        for stage: ConversationState.Stage,
        userPreferences: UserPreferences? = nil
    ) -> String {
        var basePrompt = """
        You are Amiqo, a friendly AI planning assistant helping create social plans.
        
        CRITICAL - Response Format (MANDATORY):
        You MUST ALWAYS return ONLY valid JSON in this exact format. No other text allowed:
        {
          "message": "Your conversational response here",
          "suggestions": ["Option 1", "Option 2", "Option 3"]
        }
        
        NEVER return plain text. ALWAYS wrap your response in JSON with "message" and "suggestions" keys.
        
        Core Principles:
        - Sound like a helpful friend having a natural conversation
        - Keep responses brief and conversational (1-2 sentences max)
        - Remember everything user tells you - reference it naturally
        - When user says "I don't know" or "not sure", OFFER SUGGESTIONS
        - When user asks "what do you think?", SUGGEST OPTIONS
        - Don't repeat what user just said - acknowledge and move forward
        - Use casual language: "Fabulous!" "Great!" "Perfect!"
        - Progress through: what → where → when → who → confirm
        - If user provides all details at once, summarize and confirm
        
        Suggestions Guidelines:
        - Generate 2-4 contextual quick-reply options based on the conversation
        - Make suggestions specific to what you just asked about
        - Examples:
          * If asking about venue: ["I have a place in mind", "Suggest some options", "Flexible"]
          * If asking about time: ["This weekend", "Next week", "Flexible"]
          * If asking for participants: ["Just a few friends", "The whole group", "I'll pick specific people"]
          * If confirming: ["Yes, send it!", "Let me change something", "Start over"]
        - Always include a "Flexible" or neutral option
        - Keep suggestions SHORT (2-5 words each)
        """
        
        // Add learned preferences to prompt
        if let prefs = userPreferences, !prefs.isEmpty {
            basePrompt += "\n\nUser's preferences (use to personalize suggestions):"
            if !prefs.favoriteActivities.isEmpty {
                basePrompt += "\n- Often plans: \(prefs.favoriteActivities.joined(separator: ", "))"
            }
            if !prefs.preferredTimes.isEmpty {
                basePrompt += "\n- Prefers: \(prefs.preferredTimes.joined(separator: ", "))"
            }
            if !prefs.frequentVenues.isEmpty {
                basePrompt += "\n- Frequent venues: \(prefs.frequentVenues.joined(separator: ", "))"
            }
            if let groupSize = prefs.typicalGroupSize {
                basePrompt += "\n- Typical group: \(groupSize) people"
            }
            if let style = prefs.planningStyle {
                basePrompt += "\n- Planning style: \(style)"
            }
        }
        
        let stagePrompt: String
        switch stage {
        case .greeting, .intent:
            stagePrompt = """
            
            Stage: Understanding what to plan
            - If user says activity type (dinner, coffee, etc): Respond with enthusiasm, acknowledge the plan
            - If they mention who they're planning with: Acknowledge that too
            - Don't jump ahead - just show excitement about their idea
            - Don't interrogate - keep it conversational
            Example: "Fabulous! Dinner with Maria sounds lovely."
            """
        case .venue:
            stagePrompt = """
            
            Stage: Finding a location
            - If user has a specific place: Great! Move to timing
            - If user says "not sure" or "don't know": OFFER 2-3 VENUE SUGGESTIONS based on activity type
            - If user asks for suggestions: List 2-3 realistic options
            - Reference the activity type they mentioned earlier
            
            Venue suggestions by activity type:
            - Dinner: "Bistro Luna (cozy Italian), The Garden Table (farm-to-table), Sakura House (modern Japanese)"
            - Coffee: "Blue Bottle Cafe, Philz Coffee, Local Grind"
            - Drinks/Bar: "The Mixing Glass, Rooftop Lounge, Craft & Common"
            - Brunch: "Sunday Kitchen, The Farmhouse, Brunch Box"
            - Generic/Hangout: "Central Park (weather permitting), The Commons (indoor lounge), Riverwalk area"
            
            Example response: "I have a few places in mind: Bistro Luna (cozy Italian), The Garden Table (farm-to-table), or Sakura House (modern Japanese). What sounds good?"
            """
        case .timing:
            stagePrompt = """
            
            Stage: Scheduling when
            - If user gives specific time/date: Perfect! Move to participants
            - If user says "flexible" or "whenever they're free": Acknowledge, move on
            - Accept ranges ("this weekend", "next week", "tomorrow")
            - Don't overthink - just confirm and continue
            Example: "Great! When were you thinking?"
            """
        case .participants:
            stagePrompt = """
            
            Stage: Who's invited
            - Accept names, descriptions, or counts ("a few friends", "Maria and Alex")
            - If names given: Acknowledge you'll contact their agents
            - If user already mentioned participants earlier: Don't ask again!
            - Brief acknowledgment, then move to confirmation
            Example: "Perfect! I'll coordinate with Maria's agent. Ready to draft this?"
            """
        case .confirmation:
            stagePrompt = """
            
            Stage: Final confirmation
            - RECAP IN DETAIL with bullet points:
              📍 Where: [venue or "flexible"]
              📅 When: [time or "flexible"]
              👥 Who: [participant names]
            - After recap, ask: "Should I send this to [participants] to start planning?"
            - Use emoji for clarity
            Example:
            "Here's what we have:
            📍 Where: Flexible (we'll find a great dinner spot)
            📅 When: This weekend
            👥 Who: Maria
            
            Should I send this to Maria to start planning?"
            """
        case .complete:
            stagePrompt = """
            
            Stage: Plan sent!
            - Acknowledge plan is sent: "✅ Plan sent to [participants]!"
            - Explain what happens next: "They'll get a notification and can accept, counter-propose, or decline."
            - Keep it warm and encouraging
            Example: "✅ Plan sent to Maria! She'll get a notification and can accept, suggest changes, or let you know if it doesn't work. You'll see updates on your Dashboard."
            """
        }
        
        return basePrompt + stagePrompt
    }
    
    /// Build user message with context
    private func buildUserMessage(
        userInput: String,
        stage: ConversationState.Stage,
        collectedData: ConversationState.CollectedData
    ) -> String {
        var context = "User input: \(userInput)\n"
        
        // Add collected data for context
        if let intent = collectedData.intent {
            context += "Activity type: \(intent)\n"
        }
        if !collectedData.participants.isEmpty {
            context += "Participants: \(collectedData.participants.joined(separator: ", "))\n"
        }
        if let time = collectedData.timePreference {
            context += "When: \(time)\n"
        }
        if let venue = collectedData.venuePreference {
            context += "Where: \(venue)\n"
        }
        
        return context
    }
    
    // MARK: - OpenAI API
    
    /// Call OpenAI ChatCompletions API with conversation history + semantic context
    private func callOpenAI(
        systemPrompt: String,
        userInput: String,
        collectedData: ConversationState.CollectedData,
        conversationHistory: [(role: String, content: String)]
    ) async throws -> AIResponse {
        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Add auth header only if API key provided (OpenAI needs it, LM Studio doesn't)
        if let key = openAIKey {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build messages array with REAL conversation history
        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        
        // Add recent conversation history (last 4-6 messages for context)
        // This gives the AI memory of what was discussed
        let recentHistory = conversationHistory.suffix(6) // Last 3 exchanges (6 messages)
        for message in recentHistory {
            messages.append(["role": message.role, "content": message.content])
        }
        
        // Add semantic context summary for current state
        var contextSummary = ""
        var contextParts: [String] = []
        
        if let intent = collectedData.intent {
            contextParts.append("Activity: \(intent)")
        }
        
        if !collectedData.participants.isEmpty {
            contextParts.append("With: \(collectedData.participants.joined(separator: ", "))")
        }
        
        if let time = collectedData.timePreference {
            contextParts.append("When: \(time)")
        }
        
        if let venue = collectedData.venuePreference {
            contextParts.append("Where: \(venue)")
        }
        
        if !contextParts.isEmpty {
            contextSummary = "[Context: \(contextParts.joined(separator: " | "))]"
        }
        
        // Add current user input (with optional context summary)
        let userMessage = contextSummary.isEmpty ? userInput : "\(contextSummary)\n\(userInput)"
        messages.append(["role": "user", "content": userMessage])
        
        let requestBody: [String: Any] = [
            "model": modelName,  // "llama-3.1-8b" for LM Studio or "gpt-3.5-turbo" for OpenAI
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 150,
            "user": "kairos_conversational"  // Rate limiting identifier (TODO: Add actual user ID in Phase 5)
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🌐 [AI] Calling API at: \(baseURL)")
        print("🌐 [AI] Model: \(modelName)")
        print("🌐 [AI] Messages count: \(messages.count)")
        print("🌐 [AI] Latest user message: \(userMessage.prefix(100))")
        print("🌐 [AI] Request body: \(String(data: request.httpBody!, encoding: .utf8)?.prefix(500) ?? "nil")")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("🌐 [AI] Got response, status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        print("🌐 [AI] Response data size: \(data.count) bytes")
        if let responseString = String(data: data, encoding: .utf8) {
            print("🌐 [AI] Response body: \(responseString.prefix(500))")
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("❌ [AI] API request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            if let errorBody = String(data: data, encoding: .utf8) {
                print("❌ [AI] Error response: \(errorBody)")
            }
            throw ConversationalAIError.networkError("API request failed with status \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Log token usage
        if let usage = json?["usage"] as? [String: Any] {
            let inputTokens = usage["prompt_tokens"] as? Int ?? 0
            let outputTokens = usage["completion_tokens"] as? Int ?? 0
            let totalTokens = usage["total_tokens"] as? Int ?? 0
            let cost = Double(inputTokens) * 0.0000015 + Double(outputTokens) * 0.000002 // GPT-3.5-turbo pricing
            print("📊 [OpenAI] Tokens - Input: \(inputTokens), Output: \(outputTokens), Total: \(totalTokens)")
            print("💰 [OpenAI] Cost: $\(String(format: "%.6f", cost))")
        }
        
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ConversationalAIError.parsingError("Invalid OpenAI response format")
        }
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to parse JSON response
        if let jsonData = trimmedContent.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let aiMessage = parsed["message"] as? String,
           let suggestionsArray = parsed["suggestions"] as? [String] {
            // Successfully parsed JSON format
            print("✅ [OpenAI] Parsed JSON response with \(suggestionsArray.count) suggestions")
            return AIResponse(message: aiMessage, suggestions: suggestionsArray)
        } else {
            // Fallback: AI didn't return JSON (use raw message, empty suggestions)
            print("⚠️ [OpenAI] AI didn't return JSON format, using raw response")
            return AIResponse(message: trimmedContent, suggestions: [])
        }
    }
}

// MARK: - Error Types

enum ConversationalAIError: Error, LocalizedError {
    case networkError(String)
    case parsingError(String)
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        case .unauthorized:
            return "OpenAI API key invalid or missing"
        }
    }
}
