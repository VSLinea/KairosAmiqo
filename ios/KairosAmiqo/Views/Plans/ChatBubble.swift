//
//  ChatBubble.swift
//  KairosAmiqo
//
//  Phase 2: Conversational AI Planning - Message Bubble Component
//  Task: Agent-to-Agent Negotiation (Conversational UI)
//  See: /HANDOVER-CONVERSATIONAL-AI-IMPLEMENTATION.md (Day 2)
//

import SwiftUI

/// iMessage-style chat bubble for conversational planning interface
struct ChatBubble: View {
    let message: ChatMessage
    var onSuggestionTap: ((String) -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.sender == .user {
                Spacer()
            }
            
            VStack(alignment: message.sender == .ai ? .leading : .trailing, spacing: 4) {
                contentView
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                // Timestamp
                HStack(spacing: 4) {
                    // Voice indicator for user messages
                    if message.sender == .user, message.inputSource == .voice {
                        Image(systemName: "waveform")
                            .font(.system(size: KairosAuth.IconSize.badge))
                            .foregroundColor(KairosAuth.Color.tertiaryText)
                            .accessibilityLabel("Voice input")
                    }
                    
                    Text(formatTimestamp(message.timestamp))
                        .font(KairosAuth.Typography.timestamp)
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                }
                .padding(.horizontal, 4)
            }
            
            if message.sender == .ai {
                Spacer()
            }
        }
        .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        switch message.content {
        case .text(let text):
            Text(text)
                .font(KairosAuth.Typography.body)
                .foregroundColor(textColor)
                .multilineTextAlignment(message.sender == .ai ? .leading : .trailing)
            
        case .textWithSuggestions(let text, let suggestions):
            // AI message with attached suggestion chips (keeps them grouped together)
            VStack(alignment: .leading, spacing: 12) {
                Text(text)
                    .font(KairosAuth.Typography.body)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
                
                // Suggestions attached to message
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(suggestions, id: \.self) { option in
                        SuggestionChip(text: option) {
                            onSuggestionTap?(option)
                        }
                    }
                }
            }
            
        case .suggestions(let options):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(options, id: \.self) { option in
                    SuggestionChip(text: option) {
                        onSuggestionTap?(option)
                    }
                }
            }
            
        case .loading:
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(KairosAuth.Color.accent)
                        .frame(width: 8, height: 8)
                        .opacity(0.6)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: true
                        )
                }
            }
            .padding(.vertical, 4)
            
        case .error(let errorMessage):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: KairosAuth.IconSize.badge))
                    .foregroundColor(KairosAuth.Color.error)
                    .accessibilityHidden(true)
                
                Text(errorMessage)
                    .font(KairosAuth.Typography.bodySmall)
                    .foregroundColor(KairosAuth.Color.error)
            }
        }
    }
    
    // MARK: - Styling
    
    private var bubbleBackground: some View {
        Group {
            if message.sender == .ai {
                KairosAuth.Color.cardBackground
            } else {
                KairosAuth.Color.accent
                    .opacity(0.2)
            }
        }
    }
    
    private var textColor: Color {
        message.sender == .ai
            ? KairosAuth.Color.primaryText
            : KairosAuth.Color.primaryText
    }
    
    // MARK: - Helpers
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Suggestion Chip Component

/// Tappable suggestion chip for AI-provided options
struct SuggestionChip: View {
    let text: String
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Text(text)
            .font(KairosAuth.Typography.buttonLabel)
            .foregroundColor(KairosAuth.Color.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                    .stroke(KairosAuth.Color.accent, lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                            .fill(isPressed ? KairosAuth.Color.accent.opacity(0.1) : Color.clear)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .onTapGesture {
                withAnimation(KairosAuth.Animation.uiUpdate) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(KairosAuth.Animation.uiUpdate) {
                        isPressed = false
                    }
                    onTap()
                }
            }
    }
}

// MARK: - Previews

#Preview("AI Text Message") {
    ChatBubble(message: .aiText("What kind of invitation are you coordinating?"))
        .padding()
}

#Preview("User Text Message") {
    ChatBubble(message: .userText("Dinner with friends"))
        .padding()
}

#Preview("AI Suggestions") {
    ChatBubble(message: .aiSuggestions([
        "Casual dinner",
        "Fine dining",
        "Brunch",
        "Happy hour"
    ]))
    .padding()
}

#Preview("AI Loading") {
    ChatBubble(message: .aiLoading())
        .padding()
}
