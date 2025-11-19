//
//  VoiceService.swift
//  KairosAmiqo
//
//  Voice Input Service for Conversational Planning
//  Uses iOS Speech framework (iOS 10+) - FREE, no API cost
//

import Foundation
import Speech
import AVFoundation

/// Voice-to-text service using iOS native Speech framework
/// Supports 62+ languages including Romanian, Spanish, French, etc.
/// NOT Siri - uses SFSpeechRecognizer for cross-platform compatible approach
@MainActor
class VoiceService: NSObject, ObservableObject {
    // MARK: - Published State
    
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var isAuthorized = false
    @Published var currentLanguage: String = "en-US" // Default, can be changed
    
    // MARK: - Private Properties
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Supported Languages
    
    /// Check if a language is supported
    static func isLanguageSupported(_ locale: String) -> Bool {
        return SFSpeechRecognizer.supportedLocales().contains(where: { $0.identifier == locale })
    }
    
    /// Get list of supported languages
    static var supportedLanguages: [String] {
        SFSpeechRecognizer.supportedLocales().map { $0.identifier }.sorted()
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Auto-detect user's preferred language or default to English
        let preferredLanguage = Locale.preferredLanguages.first ?? "en-US"
        setLanguage(preferredLanguage)
        checkAuthorization()
    }
    
    /// Set recognition language (e.g., "ro-RO" for Romanian, "es-ES" for Spanish)
    func setLanguage(_ locale: String) {
        guard SFSpeechRecognizer.supportedLocales().contains(where: { $0.identifier == locale }) else {
            print("⚠️ Language \(locale) not supported, falling back to en-US")
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            currentLanguage = "en-US"
            return
        }
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
        currentLanguage = locale
        print("✅ Voice recognition language set to: \(locale)")
    }
    
    // MARK: - Authorization
    
    /// Request speech recognition permission
    func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.isAuthorized = (status == .authorized)
            }
        }
    }
    
    // MARK: - Voice Input
    
    /// Start listening for speech input
    func startListening() throws {
        guard isAuthorized else {
            throw VoiceError.notAuthorized
        }
        
        // Cancel any existing task
        if let task = recognitionTask {
            task.cancel()
            recognitionTask = nil
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.setupFailed
        }
        recognitionRequest.shouldReportPartialResults = true
        
        // Start audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    self?.recognizedText = result.bestTranscription.formattedString
                }
                
                if error != nil || result?.isFinal == true {
                    self?.stopListening()
                }
            }
        }
        
        isListening = true
    }
    
    /// Stop listening and return final text
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }
    
    /// Get final transcribed text and reset
    func getFinalText() -> String {
        let text = recognizedText
        recognizedText = ""
        return text
    }
}

// MARK: - Errors

enum VoiceError: Error {
    case notAuthorized
    case setupFailed
    case recognitionFailed
    
    var localizedDescription: String {
        switch self {
        case .notAuthorized:
            return "Speech recognition permission denied. Enable in Settings."
        case .setupFailed:
            return "Failed to set up speech recognition."
        case .recognitionFailed:
            return "Speech recognition failed. Please try again."
        }
    }
}
