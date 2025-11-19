//
//  ConversationalPlanFlow.swift
//  KairosAmiqo
//
//  Phase 2: Conversational AI Planning - Main Chat Interface
//  Task: Agent-to-Agent Negotiation (Conversational UI)
//  See: /HANDOVER-CONVERSATIONAL-AI-IMPLEMENTATION.md (Day 2-4)
//

import SwiftUI

/// iMessage-style conversational interface for AI-assisted plan creation
struct ConversationalPlanFlow: View {
    @ObservedObject var vm: AppVM
    @Environment(\.dismiss) private var dismiss
    
    // Conversation state machine
    @StateObject private var conversationState = ConversationState()
    
    // AI service (computed property with lazy behavior)
    @State private var cachedAIService: ConversationalAIService?
    
    private var aiService: ConversationalAIService? {
        if cachedAIService == nil {
            // Task 28: Use local LM Studio (Llama 3.1-8b) instead of OpenAI
            print("✅ [Conversational] Creating ConversationalAIService with LM Studio (local Llama 3.1)")
            cachedAIService = ConversationalAIService(apiKey: nil, useLMStudio: true)
        }
        return cachedAIService
    }
    
    // Voice service (iOS native speech recognition - FREE)
    @StateObject private var voiceService = VoiceService()
    
    // Chat state
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isVoiceInput: Bool = false // Track if current input is from voice
    @State private var autoSendTask: Task<Void, Never>? = nil // Cancellable timer for voice auto-send
    @FocusState private var isInputFocused: Bool
    
    // Navigation state
    @State private var showReviewStep = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Chat messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(messages) { message in
                                    ChatBubble(message: message) { suggestion in
                                        handleSuggestion(suggestion)
                                    }
                                    .id(message.id)
                                }
                            }
                            .padding(.vertical, KairosAuth.Spacing.medium)
                        }
                        .onChange(of: messages.count) { _, _ in
                            // Auto-scroll to latest message
                            if let lastMessage = messages.last {
                                withAnimation(KairosAuth.Animation.uiUpdate) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Input field
                    inputBar
                        .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
                        .padding(.vertical, KairosAuth.Spacing.medium)
                        .background(
                            KairosAuth.Color.cardBackground,
                            ignoresSafeAreaEdges: .bottom
                        )
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        KairosAuth.Color.gradientStart,
                        KairosAuth.Color.gradientEnd
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                ignoresSafeAreaEdges: .all
            )
            .navigationTitle("Invite with Amiqo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(KairosAuth.Color.accent)
                }
            }
            .onAppear {
                startConversation()
            }
            .onChange(of: voiceService.recognizedText) { _, newText in
                // Live update input field as speech is recognized
                if voiceService.isListening && !newText.isEmpty {
                    inputText = newText
                }
            }
        }
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            // Voice input button (Plus-exclusive)
            if vm.isPlusUser {
                Button(action: toggleVoiceInput) {
                    Image(systemName: voiceService.isListening ? "waveform" : "mic.fill")
                        .font(Font.system(size: KairosAuth.IconSize.button))
                        .foregroundColor(voiceService.isListening ? KairosAuth.Color.accent : KairosAuth.Color.secondaryText)
                        .accessibilityHidden(true)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(KairosAuth.Color.itemBackground.opacity(voiceService.isListening ? 2.0 : 1.0))
                        )
                        .scaleEffect(voiceService.isListening ? 1.1 : 1.0)
                        .animation(KairosAuth.Animation.uiUpdate, value: voiceService.isListening)
                }
                .accessibilityLabel(voiceService.isListening ? "Stop voice input" : "Start voice input")
                .accessibilityHint(voiceService.isAuthorized ? (voiceService.isListening ? "Double-tap to stop recording and review the transcription." : "Double-tap to dictate your message with Amiqo.") : "Microphone access is required to dictate messages.")
                .accessibilityValue(voiceService.isListening ? "Recording" : "Not recording")
                .disabled(!voiceService.isAuthorized)
            }
            
            // Text field
            TextField("Message Amiqo...", text: $inputText)
                .font(KairosAuth.Typography.fieldInput)
                .foregroundColor(KairosAuth.Color.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(KairosAuth.Color.itemBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                        )
                )
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit {
                    sendMessage()
                }
                .onChange(of: inputText) { oldValue, newValue in
                    // If user edits voice transcription, cancel auto-send
                    if isVoiceInput && oldValue != newValue {
                        print("🎤 [Voice] User edited transcription, canceling auto-send")
                        autoSendTask?.cancel()
                        isVoiceInput = false
                    }
                }
            
            // Send button
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(Font.system(size: 32))
                    .foregroundColor(inputText.isEmpty ? KairosAuth.Color.tertiaryText : KairosAuth.Color.accent)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("Send message")
            .accessibilityHint("Sends your message to Amiqo.")
            .disabled(inputText.isEmpty)
        }
    }
    
    // MARK: - Conversation Logic
    
    /// Start the conversation with AI greeting
    private func startConversation() {
        let (message, suggestions) = conversationState.getAIResponse()
        if !suggestions.isEmpty {
            // Attach suggestions to greeting message for better visual grouping
            messages.append(.aiTextWithSuggestions(message, suggestions: suggestions))
        } else {
            messages.append(.aiText(message))
        }
    }
    
    /// Send user message and trigger AI response
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = inputText
        let inputSource: ChatMessage.InputSource = isVoiceInput ? .voice : .typed
        inputText = ""
        isVoiceInput = false // Reset flag
        isInputFocused = false
        
        // Add user message with source tracking
        messages.append(.userText(userMessage, source: inputSource))
        
        // Process input through state machine
        conversationState.processUserInput(userMessage)
        
        // Check if conversation is complete
        if conversationState.isComplete {
            completeConversation()
            return
        }
        
        // Show AI thinking indicator
        messages.append(.aiLoading())
        
        // Get AI response (real OpenAI or fallback)
        Task {
            do {
                var responseText: String = ""
                var responseSuggestions: [String] = []
                
                if let aiService = aiService {
                    // Real OpenAI call with retry logic for transient failures
                    print("🤖 [Conversational] Using OpenAI API for response")
                    
                    // Extract conversation history for context
                    let history = extractConversationHistory()
                    
                    for attempt in 1...3 {
                        do {
                            let aiResponse = try await aiService.generateResponse(
                                for: conversationState.currentStage,
                                userInput: userMessage,
                                collectedData: conversationState.collectedData,
                                conversationHistory: history,
                                userPreferences: nil  // TODO(Phase 5): Load from AppVM
                            )
                            responseText = aiResponse.message
                            responseSuggestions = aiResponse.suggestions
                            print("✅ [Conversational] Got OpenAI response: \(responseText.prefix(50))...")
                            print("💡 [Conversational] AI generated \(responseSuggestions.count) suggestions: \(responseSuggestions)")
                            break
                        } catch {
                            print("⚠️ [Conversational] OpenAI attempt \(attempt)/3 failed: \(error.localizedDescription)")
                            if attempt < 3 {
                                print("⚠️ [Conversational] OpenAI attempt \(attempt) failed, retrying...")
                                try await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000) // Exponential backoff
                            } else {
                                print("❌ [Conversational] All OpenAI attempts failed, using fallback")
                                throw error
                            }
                        }
                    }
                } else {
                    // Fallback to state machine prompts (no API key)
                    print("⚠️ [Conversational] Using fallback state machine (no OpenAI)")
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    let (message, _) = conversationState.getAIResponse()
                    responseText = message
                    // Use hardcoded suggestions as fallback
                    responseSuggestions = conversationState.currentStage.suggestions
                }
                
                // Process user input (may advance stage)
                conversationState.processUserInput(userMessage)
                
                // Remove loading, add response with attached suggestions
                messages.removeAll { $0.content == .loading }
                
                // If we have suggestions, attach them to the message for better visual grouping
                if !responseSuggestions.isEmpty {
                    messages.append(.aiTextWithSuggestions(responseText, suggestions: responseSuggestions))
                } else {
                    // No suggestions - plain text message
                    messages.append(.aiText(responseText))
                    
                    // Fallback to stage-based suggestions if AI didn't provide any
                    let fallbackSuggestions = conversationState.currentStage.suggestions
                    if !fallbackSuggestions.isEmpty {
                        messages.append(.aiSuggestions(fallbackSuggestions))
                    }
                }
            } catch {
                // Handle error gracefully with detailed logging
                print("❌ [Conversational] Error in sendMessage: \(error)")
                print("❌ [Conversational] Error details: \(error.localizedDescription)")
                if let urlError = error as? URLError {
                    print("❌ [Conversational] URLError code: \(urlError.code.rawValue)")
                    print("❌ [Conversational] URLError description: \(urlError.localizedDescription)")
                }
                messages.removeAll { $0.content == .loading }
                messages.append(.aiError("Sorry, had trouble with that. Can you try again?"))
            }
        }
    }
    
    /// Handle suggestion chip tap
    private func handleSuggestion(_ suggestion: String) {
        // Treat as user message
        messages.append(.userText(suggestion))
        
        // Process through state machine
        conversationState.processUserInput(suggestion)
        
        // Check if complete
        if conversationState.isComplete {
            completeConversation()
            return
        }
        
        // Get AI response for next stage
        messages.append(.aiLoading())
        Task {
            do {
                var responseText: String = ""
                var responseSuggestions: [String] = []
                
                if let aiService = aiService {
                    // Real OpenAI call with retry logic
                    let history = extractConversationHistory()
                    
                    for attempt in 1...3 {
                        do {
                            let aiResponse = try await aiService.generateResponse(
                                for: conversationState.currentStage,
                                userInput: suggestion,
                                collectedData: conversationState.collectedData,
                                conversationHistory: history,
                                userPreferences: nil
                            )
                            responseText = aiResponse.message
                            responseSuggestions = aiResponse.suggestions
                            break
                        } catch {
                            if attempt < 3 {
                                print("⚠️ [Conversational] OpenAI attempt \(attempt) failed (suggestion), retrying...")
                                try await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
                            } else {
                                print("❌ [Conversational] All OpenAI attempts failed (suggestion), using fallback")
                                throw error
                            }
                        }
                    }
                } else {
                    // Fallback to state machine (no API key)
                    try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
                    let (message, suggestions) = conversationState.getAIResponse()
                    responseText = message
                    responseSuggestions = suggestions
                }
                
                messages.removeAll { $0.content == .loading }
                messages.append(.aiText(responseText))
                
                // Use AI-generated suggestions if available, otherwise fallback to stage suggestions
                let suggestionsToShow = responseSuggestions.isEmpty ? conversationState.currentStage.suggestions : responseSuggestions
                if !suggestionsToShow.isEmpty {
                    messages.append(.aiSuggestions(suggestionsToShow))
                }
            } catch {
                messages.removeAll { $0.content == .loading }
                messages.append(.aiError("Sorry, I had trouble with that. Can you try again?"))
            }
        }
    }
    
    /// Extract conversation history for OpenAI context
    /// Returns recent user/assistant message pairs
    private func extractConversationHistory() -> [(role: String, content: String)] {
        var history: [(role: String, content: String)] = []
        
        for message in messages {
            switch message.content {
            case .text(let text):
                // Determine role based on sender
                let role = message.sender == .user ? "user" : "assistant"
                history.append((role: role, content: text))
            default:
                // Skip loading indicators, errors, and suggestions
                continue
            }
        }
        
        return history
    }
    
    /// Conversation complete - transition to review
    private func completeConversation() {
        Task { @MainActor in
            // Show AI confirmation message
            messages.append(.aiText("Perfect! Let me send this invite..."))
            
            do {
                // Convert collected data to plan parameters
                let data = conversationState.collectedData
                
                // Parse intent
                guard let intentText = data.intent else {
                    throw NSError(domain: "ConversationalPlan", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing intent"])
                }
                let intent = IntentTemplate.fromText(intentText)
                
                // Parse participants (already an array, no nil coalescing needed)
                let participants = data.participants.map { name in
                    PlanParticipant(
                        user_id: UUID(), // Mock ID - backend will resolve
                        name: name,
                        status: "pending"
                    )
                }
                
                guard !participants.isEmpty else {
                    throw NSError(domain: "ConversationalPlan", code: 2, userInfo: [NSLocalizedDescriptionKey: "No participants specified"])
                }
                
                // Parse timing (use timePreference field)
                let timeText = data.timePreference ?? "flexible"
                let times = [ProposedSlot(time: timeText, venue: nil)]
                
                // Parse venue (use venuePreference field)
                let venueText = data.venuePreference ?? "flexible"
                let venues = [VenueInfo(
                    id: nil,           // No POI match for conversational input
                    name: venueText,
                    lat: nil,          // No coordinates for text-based venue
                    lon: nil,
                    address: nil,      // User will specify details later
                    category: nil,     // No category classification yet
                    price_band: nil    // No price info for text input
                )]
                
                // Create the plan via AppVM
                _ = try await vm.createProposal(
                    intent: intent,
                    participants: participants,
                    times: times,
                    venues: venues
                )
                
                // Show success message
                let participantNames = participants.map { $0.name }.joined(separator: ", ")
                messages.append(.aiText("✅ Invite sent to \(participantNames)! They'll get a notification and can accept, suggest changes, or decline. You'll see updates on your Dashboard."))
                
                // Wait briefly then dismiss
                try await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
                
                // Dismiss the conversation sheet - user returns to Plans tab
                dismiss()
                
            } catch {
                // Show error
                messages.removeAll { $0.content == .loading }
                messages.append(.aiError("Sorry, I had trouble sending the invite. Error: \(error.localizedDescription)"))
            }
        }
    }
    
    // MARK: - Voice Input
    
    /// Toggle voice input on/off
    private func toggleVoiceInput() {
        if voiceService.isListening {
            // Stop listening and use recognized text
            voiceService.stopListening()
            let voiceText = voiceService.getFinalText()
            if !voiceText.isEmpty {
                inputText = voiceText
                isVoiceInput = true // Mark as voice input
                
                // Auto-send after 1 second if user doesn't edit (cancellable)
                autoSendTask?.cancel() // Cancel any previous timer
                autoSendTask = Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if !Task.isCancelled && inputText == voiceText && !inputText.isEmpty {
                        print("🎤 [Voice] Auto-sending voice input: \(voiceText)")
                        sendMessage()
                    } else if Task.isCancelled {
                        print("🎤 [Voice] Auto-send cancelled - user edited input")
                    }
                }
            }
        } else {
            // Start listening
            do {
                try voiceService.startListening()
                isInputFocused = false // Dismiss keyboard
                print("🎤 [Voice] Started listening...")
            } catch {
                print("⚠️ Voice input failed: \(error.localizedDescription)")
                messages.append(.aiError("Voice input failed. Please check microphone permissions."))
            }
        }
    }
}

// MARK: - Previews

#Preview {
    ConversationalPlanFlow(vm: AppVM())
}
