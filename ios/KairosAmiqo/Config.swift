//
//  Config.swift
//  KairosAmiqo
//
//  Environment-based API configuration for Kairos Amiqo
//  Phase 0-3: Mock server (8056) for data, local Directus (8055) for auth
//  Phase 4+: Local Directus (8055) for data + auth
//  Production: Cloud Directus + Node-RED
//

import Foundation

enum Config {
    #if DEBUG
        // MARK: - Development Environment (Xcode Debug builds)
        
        /// Toggle mock server vs real Directus for data endpoints
        /// Set in Xcode scheme: Edit Scheme → Run → Arguments → Environment Variables
        /// DEPRECATED 2025-11-05: Mock server eliminated, all endpoints use Directus
        /// USE_MOCK=1 → Ignored (Directus used regardless)
        /// USE_MOCK=0 → Directus (same as =1 now)
        private static let useMock = false  // Hardcoded: mock server eliminated
        
        // Base URLs - Development & Production options
        // Production server: 83.250.24.174 (Directus:8055, Node-RED:1881)
        // Local development: localhost/LAN IP (configurable via DEV_SERVER_IP env var)
        
        /// Get development server IP dynamically
        /// CRITICAL: Must be Mac's IP (where Directus runs), NOT localhost or device IP
        /// - Build script (inject-dev-ip.sh) auto-detects Mac's IP during Xcode build
        /// - Injected into Info.plist as DEV_SERVER_IP
        /// - Fallback: Last known Mac IP (update manually when network changes)
        private static let devServerIP: String = {
            // Try Info.plist (auto-injected by build script - Mac's IP)
            if let plistIP = Bundle.main.object(forInfoDictionaryKey: "DEV_SERVER_IP") as? String,
               !plistIP.isEmpty,
               plistIP != "localhost" {
                return plistIP
            }
            
            // Try environment variable (manual override)
            if let envIP = ProcessInfo.processInfo.environment["DEV_SERVER_IP"],
               envIP != "localhost" {
                return envIP
            }
            
            // Fallback: Current Mac IP (update this when your network changes)
            // 2025-11-07: Hotspot IP (ISP down, using mobile hotspot)
            return "172.20.10.10"
        }()
        
        #if targetEnvironment(simulator)
            private static let mockAPIBase = URL(string: "http://localhost:8056")!
            private static let localDirectusBase = URL(string: "http://localhost:8055")!
            private static let localNodeRedBase = URL(string: "http://localhost:1881")!
            private static let productionDirectusBase = URL(string: "http://83.250.24.174:8055")!
            private static let productionNodeRedBase = URL(string: "http://83.250.24.174:1881")!
        #else
            // Physical device - use environment variable DEV_SERVER_IP (or fallback to last known IP)
            private static let mockAPIBase = URL(string: "http://\(devServerIP):8056")!
            private static let localDirectusBase = URL(string: "http://\(devServerIP):8055")!
            private static let localNodeRedBase = URL(string: "http://\(devServerIP):1881")!
            private static let productionDirectusBase = URL(string: "http://83.250.24.174:8055")!
            private static let productionNodeRedBase = URL(string: "http://83.250.24.174:1881")!
        #endif
        
        // MARK: - Auth Endpoint (Local Development Only)
        /// LOCAL ONLY: Using localhost Directus (8055) for development
        /// Production deployment deferred until app launch (Phase 8+)
        static let directusBase = localDirectusBase
        
        // MARK: - Data Endpoints (Directus Primary - 2025-11-05)
        /// MIGRATION COMPLETE: All data endpoints now use Directus (localhost:8055)
        /// Mock server (8056) eliminated - comprehensive test data migrated to Directus
        /// Negotiations: 25 records ✅ | Events: 15 records ✅ | POI: 10 records ✅
        static var eventsBase: URL { localDirectusBase }
        
        /// Plans API: Now using Directus exclusively 
        static var plansBase: URL { localDirectusBase }
        
        /// Negotiations API: Now using Directus exclusively (25 test records available)
        static var negotiationsBase: URL { localDirectusBase }
        
        /// Places API: Now using Directus exclusively
        static var placesBase: URL { localDirectusBase }
        
        // MARK: - Workflow Engine (Local Node-RED)
        /// Node-RED flows for negotiation FSM and AI proposals
        /// Using local Node-RED (localhost:1881) for development
        static let nodeRedBase = localNodeRedBase
        
    #else
        // MARK: - Production Environment (App Store / TestFlight builds)
        
        /// TODO(Phase 8 - Production Deployment Checklist):
        /// 1. Set DIRECTUS_CLOUD_URL in Xcode build settings (Release config)
        /// 2. Set NODE_RED_CLOUD_URL in Xcode build settings (Release config)
        /// 3. Update Info.plist with production domain exceptions
        /// 4. Test auth flow against cloud Directus
        /// 5. Verify HTTPS certificates
        /// 6. Update ROADMAP.md Phase 8 deployment steps
        
        /// Production Directus URL (handles auth + data)
        /// Default placeholder - override via Xcode build setting: DIRECTUS_CLOUD_URL
        private static let cloudDirectusURL = ProcessInfo.processInfo.environment["DIRECTUS_CLOUD_URL"] 
            ?? "https://api.kairos.example" // ⚠️ PLACEHOLDER - update before production!
        
        /// Production Node-RED URL (handles workflows)
        /// Default placeholder - override via Xcode build setting: NODE_RED_CLOUD_URL
        private static let cloudNodeRedURL = ProcessInfo.processInfo.environment["NODE_RED_CLOUD_URL"] 
            ?? "https://flows.kairos.example" // ⚠️ PLACEHOLDER - update before production!
        
        static let directusBase = URL(string: cloudDirectusURL)!
        static var eventsBase: URL { directusBase }
        static var plansBase: URL { directusBase }
        static var negotiationsBase: URL { directusBase }
        static var placesBase: URL { directusBase }
        static let nodeRedBase = URL(string: cloudNodeRedURL)!
    #endif
    
    // MARK: - E2EE Configuration (Task 28 - Agent-to-Agent)
    
    /// Enable/disable end-to-end encryption for development
    /// Set in Xcode scheme: Edit Scheme → Run → Arguments → Environment Variables
    /// DISABLE_E2EE=1 → Skip encryption (faster testing)
    /// DISABLE_E2EE=0 or unset → Use full E2EE (production behavior)
    ///
    /// When disabled:
    /// - AgentPreferences stored in plaintext
    /// - Agent messages not encrypted
    /// - Keychain operations skipped
    /// - Diffie-Hellman key exchange skipped
    ///
    /// **PRODUCTION BUILDS ALWAYS ENFORCE E2EE** (this flag ignored in Release config)
    #if DEBUG
    static let enableE2EE = ProcessInfo.processInfo.environment["DISABLE_E2EE"] != "1"
    #else
    static let enableE2EE = true // Always on for production
    #endif
    
    // MARK: - LLM Configuration (Task 28 - External LLM)
    
    /// LM Studio Configuration (Local Llama 3.1-8b model)
    /// LM Studio runs on port 11234 (not 1234) with OpenAI-compatible API
    /// See: https://lmstudio.ai/docs/api/openai-compatibility
    static var lmStudioBase: URL {
        #if targetEnvironment(simulator)
            return URL(string: "http://localhost:11234")!
        #else
            // Physical device - use Mac's LAN IP where LM Studio is running
            return URL(string: "http://192.168.68.108:11234")!
        #endif
    }
    
    /// Model name as configured in LM Studio (usually the filename without .gguf extension)
    /// User's model: /Users/lyra/.lmstudio/models/mlx-community/Meta-Llama-3.1-8B-Instruct-8bit
    static let lmStudioModel = "meta-llama-3.1-8b-instruct"
    
    /// Toggle between LM Studio (local) and OpenAI (cloud)
    /// Set USE_LM_STUDIO=0 environment variable to use OpenAI instead
    static let useLMStudio = ProcessInfo.processInfo.environment["USE_LM_STUDIO"] != "0"
    
    /// OpenAI API key for conversational AI (Phase 3)
    /// Only used if useLMStudio = false
    /// Reads from Secrets.swift (gitignored file with actual key)
    /// Cost: ~$0.002/request for GPT-3.5-turbo
    /// Budget: $150/mo for 1k users with conversational AI
    static var openAIKey: String? {
        // Read from Secrets.swift (gitignored file)
        // If key is valid (starts with "sk-"), use it
        let secretKey = Secrets.openAIAPIKey
        if !secretKey.isEmpty && secretKey.hasPrefix("sk-") {
            #if DEBUG
            print("🤖 [DEBUG] OpenAI API Key loaded from Secrets.swift (first 10 chars): \(String(secretKey.prefix(10)))...")
            #endif
            return secretKey
        }
        // Fallback to environment variable (for CI/CD or if Secrets.swift empty)
        let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        #if DEBUG
        if envKey != nil {
            print("🤖 [DEBUG] OpenAI API Key loaded from environment variable")
        } else {
            print("⚠️ [DEBUG] No OpenAI API Key found - will use LM Studio if enabled")
        }
        #endif
        return envKey
    }
    
    // MARK: - Current Configuration Summary (Debug only)
    #if DEBUG
    static func printConfiguration() {
        let e2eeStatus = enableE2EE ? "✅ ENABLED" : "⚠️ DISABLED (plaintext mode)"
        print("""
        
        ╔══════════════════════════════════════════════════════════════╗
        ║          Kairos Amiqo API Configuration                      ║
        ╠══════════════════════════════════════════════════════════════╣
        ║ Mode: PRODUCTION SERVER (83.250.24.174)                      ║
        ║                                                              ║
        ║ Auth (Directus):      \(directusBase.absoluteString.padding(toLength: 35, withPad: " ", startingAt: 0))║
        ║ Events API:           \(eventsBase.absoluteString.padding(toLength: 35, withPad: " ", startingAt: 0))║
        ║ Plans API:            \(plansBase.absoluteString.padding(toLength: 35, withPad: " ", startingAt: 0))║
        ║ Negotiations API:     \(negotiationsBase.absoluteString.padding(toLength: 35, withPad: " ", startingAt: 0))║
        ║ Places API:           \(placesBase.absoluteString.padding(toLength: 35, withPad: " ", startingAt: 0))║
        ║ Node-RED Workflows:   \(nodeRedBase.absoluteString.padding(toLength: 35, withPad: " ", startingAt: 0))║
        ║                                                              ║
        ║ E2EE Encryption:      \(e2eeStatus.padding(toLength: 35, withPad: " ", startingAt: 0))║
        ╚══════════════════════════════════════════════════════════════╝
        
        """)
    }
    #endif
}
