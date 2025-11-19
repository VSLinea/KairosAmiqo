//
//  ChatMessage.swift
//  KairosAmiqo
//
//  Phase 2: Conversational AI Planning - Data Model
//  Task: Agent-to-Agent Negotiation (Conversational UI)
//  See: /HANDOVER-CONVERSATIONAL-AI-IMPLEMENTATION.md (Day 2)
//

import Foundation

/// Represents a single message in the conversational planning flow
struct ChatMessage: Identifiable, Equatable {
    let id: String
    let sender: Sender
    let content: Content
    let timestamp: Date
    let inputSource: InputSource? // Track how user message was created
    
    enum Sender: Equatable {
        case ai
        case user
    }
    
    enum InputSource: Equatable {
        case typed
        case voice
    }
    
    enum Content: Equatable {
        /// Plain text message
        case text(String)
        /// AI message with attached suggestion chips
        case textWithSuggestions(text: String, suggestions: [String])
        /// AI suggestion with tappable options (standalone)
        case suggestions([String])
        /// Loading indicator (AI is thinking)
        case loading
        /// Error message
        case error(String)
    }
    
    init(
        id: String = UUID().uuidString,
        sender: Sender,
        content: Content,
        timestamp: Date = Date(),
        inputSource: InputSource? = nil
    ) {
        self.id = id
        self.sender = sender
        self.content = content
        self.timestamp = timestamp
        self.inputSource = inputSource
    }
    
    // MARK: - Convenience Initializers
    
    static func aiText(_ text: String) -> ChatMessage {
        ChatMessage(sender: .ai, content: .text(text))
    }
    
    static func aiTextWithSuggestions(_ text: String, suggestions: [String]) -> ChatMessage {
        ChatMessage(sender: .ai, content: .textWithSuggestions(text: text, suggestions: suggestions))
    }
    
    static func userText(_ text: String, source: InputSource = .typed) -> ChatMessage {
        ChatMessage(sender: .user, content: .text(text), inputSource: source)
    }
    
    static func aiSuggestions(_ options: [String]) -> ChatMessage {
        ChatMessage(sender: .ai, content: .suggestions(options))
    }
    
    static func aiLoading() -> ChatMessage {
        ChatMessage(sender: .ai, content: .loading)
    }
    
    static func aiError(_ message: String) -> ChatMessage {
        ChatMessage(sender: .ai, content: .error(message))
    }
}
