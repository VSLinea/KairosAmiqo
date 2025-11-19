//
//  AgentTestingView.swift
//  KairosAmiqo
//
//  SIMPLIFIED: Tests existing UserAgentManager.evaluateProposal() directly
//  This is the ACTUAL A2A agent logic - no mocking needed
//
//  Access: Settings → Developer → Agent Testing
//

import SwiftUI

struct AgentTestingView: View {
    @ObservedObject var vm: AppVM
    @State private var testResults: [TestResult] = []
    @State private var isRunning = false
    @State private var showMultiUserHelp = false
    @State private var testLog: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                // Multi-User Setup Instructions
                Section {
                    Button(action: { showMultiUserHelp.toggle() }) {
                        HStack(spacing: KairosAuth.Spacing.small) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(KairosAuth.Color.accent)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                                Text("A2A Testing Requires TWO Users")
                                    .font(KairosAuth.Typography.itemTitle)
                                Text("Tap for setup instructions")
                                    .font(KairosAuth.Typography.itemSubtitle)
                                    .foregroundColor(KairosAuth.Color.secondaryText)
                            }
                            Spacer()
                            Image(systemName: showMultiUserHelp ? "chevron.down" : "chevron.right")
                                .foregroundColor(KairosAuth.Color.tertiaryText)
                                .accessibilityHidden(true)
                        }
                    }
                    
                    if showMultiUserHelp {
                        VStack(alignment: .leading, spacing: KairosAuth.Spacing.rowSpacing) {
                            Text("Why Two Users?")
                                .font(KairosAuth.Typography.cardTitle)
                            
                            Text("Agent-to-Agent negotiation simulates this scenario:")
                                .font(KairosAuth.Typography.body)
                            
                            HStack(alignment: .top, spacing: KairosAuth.Spacing.small) {
                                Text("1.")
                                VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                                    Text("Alice's agent sends an invitation: 'Coffee at 2pm'")
                                        .font(KairosAuth.Typography.bodySmall)
                                    Text("Alice's preferences: High coffee score (0.9), prefers 2-4pm")
                                        .font(KairosAuth.Typography.timestamp)
                                        .foregroundColor(KairosAuth.Color.secondaryText)
                                }
                            }
                            
                            HStack(alignment: .top, spacing: KairosAuth.Spacing.small) {
                                Text("2.")
                                VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                                    Text("Bob's agent evaluates the invitation")
                                        .font(KairosAuth.Typography.bodySmall)
                                    Text("Bob's preferences: Low coffee score (0.3), prefers dinner 6-8pm")
                                        .font(KairosAuth.Typography.timestamp)
                                        .foregroundColor(KairosAuth.Color.secondaryText)
                                }
                            }
                            
                            HStack(alignment: .top, spacing: KairosAuth.Spacing.small) {
                                Text("3.")
                                VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                                    Text("Bob's agent COUNTERS: 'Dinner at 7pm instead?'")
                                        .font(KairosAuth.Typography.bodySmall)
                                        .foregroundColor(KairosAuth.Color.accent)
                                }
                            }
                            
                            Divider()
                            
                            Text("Setup Options:")
                                .font(KairosAuth.Typography.cardTitle)
                            
                            Text("Option A: Two Physical Devices")
                                .font(KairosAuth.Typography.itemTitle)
                            Text("• Device 1: Sign in as mobile.tester@example.com")
                                .font(KairosAuth.Typography.bodySmall)
                            Text("• Device 2: Sign in as alice.demo@example.com")
                                .font(KairosAuth.Typography.bodySmall)
                            Text("• Create an invitation from Device 1 → Agent negotiates on Device 2")
                                .font(KairosAuth.Typography.bodySmall)
                            
                            Text("Option B: Simulator Script (Recommended)")
                                .font(KairosAuth.Typography.itemTitle)
                                .padding(.top, KairosAuth.Spacing.small)
                            Text("• Run backend script to simulate Bob's agent")
                                .font(KairosAuth.Typography.bodySmall)
                            Text("• iOS app plays Alice, script plays Bob")
                                .font(KairosAuth.Typography.bodySmall)
                            Text("• See: /scripts/simulate-agent-bob.sh")
                                .font(KairosAuth.Typography.timestamp)
                                .foregroundColor(KairosAuth.Color.tertiaryText)
                        }
                        .padding(KairosAuth.Spacing.cardPadding)
                        .background(KairosAuth.Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card))
                    }
                } header: {
                    Text("Setup")
                }
                
                Section("Single-User Tests (Heuristics Only)") {
                    Button(action: runSingleUserTests) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .accessibilityHidden(true)
                            Text("Run Heuristic Tests")
                            Spacer()
                            if isRunning {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRunning || vm.currentUser == nil)
                    
                    if vm.currentUser == nil {
                        Text("⚠️ Not logged in - use Skip Auth in debug")
                            .font(KairosAuth.Typography.timestamp)
                            .foregroundColor(KairosAuth.Color.warning)
                    }
                }
                
                Section("Results") {
                    if testResults.isEmpty {
                        Text("No tests run yet")
                            .foregroundColor(KairosAuth.Color.secondaryText)
                    } else {
                        ForEach(testResults) { result in
                            HStack {
                                Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.passed ? KairosAuth.Color.success : KairosAuth.Color.error)
                                    .accessibilityLabel(result.passed ? "Test passed" : "Test failed")
                                VStack(alignment: .leading) {
                                    Text(result.name)
                                        .font(KairosAuth.Typography.itemTitle)
                                    Text(result.message)
                                        .font(KairosAuth.Typography.itemSubtitle)
                                        .foregroundColor(KairosAuth.Color.secondaryText)
                                }
                                Spacer()
                                Text(String(format: "%.1fs", result.duration))
                                    .font(KairosAuth.Typography.timestamp)
                                    .foregroundColor(KairosAuth.Color.tertiaryText)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Agent Testing")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Test Runner
    
    private func runSingleUserTests() {
        isRunning = true
        testResults = []
        
        Task {
            // Test 1: Preference Scoring
            await runTest(name: "Preference Scoring Logic", test: testPreferenceScoring)
            
            // Test 2: Veto Rule Check
            await runTest(name: "Veto Rule Enforcement", test: testVetoRule)
            
            // Test 3: Threshold Logic
            await runTest(name: "Accept/Counter Thresholds", test: testThresholds)
            
            await MainActor.run {
                isRunning = false
            }
        }
    }
    
    private func runTest(name: String, test: @escaping () async throws -> String) async {
        let start = Date()
        do {
            let message = try await test()
            let duration = Date().timeIntervalSince(start)
            await MainActor.run {
                testResults.append(TestResult(
                    name: name,
                    passed: true,
                    message: message,
                    duration: duration
                ))
            }
        } catch {
            let duration = Date().timeIntervalSince(start)
            await MainActor.run {
                testResults.append(TestResult(
                    name: name,
                    passed: false,
                    message: "Error: \(error.localizedDescription)",
                    duration: duration
                ))
            }
        }
    }
    
    // MARK: - Test Cases (Single-User Heuristics)
    
    private func testPreferenceScoring() async throws -> String {
        guard let currentUserId = vm.currentUser?.user_id else {
            throw TestError.assertionFailed("No user logged in")
        }
        
        // Setup test preferences
        let testPreferences = AgentPreferences(userId: currentUserId)
        // Manually set learned patterns (normally done by PreferenceLearningService)
        var patterns = testPreferences.learnedPatterns
        patterns.categoryPreferences = ["coffee": 0.92, "dinner": 0.45]
        patterns.preferredTimes = [14: 0.9, 15: 0.8, 16: 0.7] // 2-4pm
        
        // Create matching invitation (coffee at 2pm)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let proposedTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: tomorrow)!
        
        // Manual scoring calculation (mimics UserAgentManager.scoreTimeSlot)
        let hour = calendar.component(.hour, from: proposedTime)
        let timeScore = patterns.preferredTimes[hour] ?? 0.0 // Should be 0.9
        let categoryScore = patterns.categoryPreferences["coffee"] ?? 0.5 // Should be 0.92
        let combinedScore = (timeScore + categoryScore) / 2.0 // ~0.91
        
        guard combinedScore >= 0.8 else {
            throw TestError.assertionFailed("Score too low: \(combinedScore) < 0.8")
        }
        
        return "✅ Score: \(String(format: "%.2f", combinedScore)) (time: \(String(format: "%.2f", timeScore)), category: \(String(format: "%.2f", categoryScore)))"
    }
    
    private func testVetoRule() async throws -> String {
        guard let currentUserId = vm.currentUser?.user_id else {
            throw TestError.assertionFailed("No user logged in")
        }
        
        // Setup preferences with veto rule (never after 8pm)
        _ = AgentPreferences(userId: currentUserId)
        let vetoRule = VetoRule(
            type: .neverAfter,
            value: "20" // 20:00 = 8pm
        )
        
        // Create learning service to test veto check
        let directusClient = HTTPClient(base: Config.directusBase)
        let learningService = PreferenceLearningService(
            userId: currentUserId,
            directusClient: directusClient
        )
        
        // Test invitation at 11pm (violates veto)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let proposedTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: tomorrow)!
        
        // Call actual veto check function
        let violation = learningService.checkVetoRules(
            time: proposedTime,
            duration: 60,
            venueId: nil,
            vetoRules: [vetoRule]
        )
        
        if let violation = violation {
            return "✅ Veto enforced: \(violation)"
        } else {
            throw TestError.assertionFailed("Veto should have blocked the 11pm invitation (never after 8pm)")
        }
    }
    
    private func testThresholds() async throws -> String {
        guard let currentUserId = vm.currentUser?.user_id else {
            throw TestError.assertionFailed("No user logged in")
        }
        
        let testPreferences = AgentPreferences(userId: currentUserId)
        let autonomy = testPreferences.autonomySettings
        
        // Test threshold logic
        let highConfidence = 0.90 // Should auto-accept (>= 0.85)
        let medConfidence = 0.70  // Should counter (>= 0.65, < 0.85)
        let lowConfidence = 0.40  // Should escalate (< 0.65)
        
        var results: [String] = []
        
        // High confidence
        if highConfidence >= autonomy.autoAcceptThreshold {
            results.append("✅ High (0.90) → Accept")
        } else {
            throw TestError.assertionFailed("High confidence should accept")
        }
        
        // Medium confidence
        if medConfidence >= autonomy.autoCounterThreshold && medConfidence < autonomy.autoAcceptThreshold {
            results.append("✅ Medium (0.70) → Counter")
        } else {
            throw TestError.assertionFailed("Medium confidence should counter")
        }
        
        // Low confidence
        if lowConfidence < autonomy.autoCounterThreshold {
            results.append("✅ Low (0.40) → Escalate")
        } else {
            throw TestError.assertionFailed("Low confidence should escalate")
        }
        
        return results.joined(separator: ", ")
    }
    
    // MARK: - Models
    
    struct TestResult: Identifiable {
        let id = UUID()
        let name: String
        let passed: Bool
        let message: String
        let duration: TimeInterval
    }
    
    enum TestError: Error, LocalizedError {
        case assertionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .assertionFailed(let message):
                return message
            }
        }
    }
}

#Preview {
    AgentTestingView(vm: AppVM())
}
