import Foundation

/// API Keys and Secrets
/// ⚠️ CRITICAL: This file is gitignored and should NEVER be committed to version control
/// - Add this file to .gitignore: ios/KairosAmiqo/Services/Secrets.swift
/// - For production: Store keys in Xcode build configuration or secure keychain
struct Secrets {
    /// OpenAI API Key for AI-powered plan proposals (Plus tier feature)
    /// Get your key from: https://platform.openai.com/api-keys
    /// Cost: ~$0.002 per request with GPT-3.5-turbo
    static let openAIAPIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    
    /// Fallback API key (optional - for future use)
    /// Together AI: https://api.together.xyz/
    static let togetherAPIKey = ""
    
    /// Speed mode API key (optional - for future use)
    /// Groq: https://console.groq.com/
    static let groqAPIKey = ""
}
