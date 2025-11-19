//
//  AgentSettingsView.swift
//  KairosAmiqo
//
//  Task 28: Agent-to-Agent Negotiation - Settings UI
//  Week 2, Day 10: Agent Settings Screen
//
//  Created: 2025-11-02
//  See: /AGENT-TO-AGENT-IMPLEMENTATION-PLAN.md (lines 621-650)
//
//  Features:
//  - Enable/disable agent mode
//  - Autonomy level slider (0.0-1.0)
//  - Display learned preferences (venues, times, categories)
//  - Reset learned data
//  - OpenAI API usage meter (if AgentDecisionService enabled)
//

import SwiftUI

/// Agent Settings - Configure autonomous negotiation behavior
struct AgentSettingsView: View {
    @ObservedObject var vm: AppVM
    @Environment(\.dismiss) var dismiss
    
    // Local state for unsaved changes
    @State private var agentModeEnabled: Bool = false
    @State private var autonomyLevel: Double = 0.5
    @State private var autoAcceptThreshold: Double = 0.85
    @State private var autoCounterThreshold: Double = 0.65
    @State private var maxRounds: Int = 5
    @State private var requireConfirmation: Bool = true
    
    // UI state
    @State private var showResetAlert = false
    @State private var isSaving = false
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: KairosAuth.Spacing.cardSpacing) {
                    // Agent Mode Toggle Card
                    DashboardCard {
                        VStack(spacing: KairosAuth.Spacing.large) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .accessibilityHidden(true)
                                    .font(.system(size: KairosAuth.IconSize.cardIcon))
                                    .foregroundColor(KairosAuth.Color.accent)
                                
                                Text("Auto-Negotiation Mode")
                                    .font(KairosAuth.Typography.cardTitle)
                                    .foregroundColor(KairosAuth.Color.primaryText)
                                
                                Spacer()
                                
                                Toggle("", isOn: $agentModeEnabled)
                                    .labelsHidden()
                                    .tint(KairosAuth.Color.accent)
                                    .accessibilityLabel("Auto-negotiation mode")
                                    .accessibilityHint("Enable to let your agent coordinate invitations automatically")
                            }
                            
                            if agentModeEnabled {
                                Text("Your agent can coordinate invitations on your behalf using learned preferences")
                                    .font(KairosAuth.Typography.itemSubtitle)
                                    .foregroundColor(KairosAuth.Color.secondaryText)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                    
                    // Autonomy Level Card
                    if agentModeEnabled {
                        DashboardCard {
                            VStack(spacing: KairosAuth.Spacing.large) {
                                HStack {
                                    Image(systemName: "gauge.with.dots.needle.67percent")
                                        .accessibilityHidden(true)
                                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                                        .foregroundColor(KairosAuth.Color.accent)
                                    
                                    Text("Autonomy Level")
                                        .font(KairosAuth.Typography.cardTitle)
                                        .foregroundColor(KairosAuth.Color.primaryText)
                                    
                                    Spacer()
                                }
                                
                                VStack(spacing: KairosAuth.Spacing.medium) {
                                    HStack {
                                        Text(autonomyLevelLabel)
                                            .font(KairosAuth.Typography.itemTitle)
                                            .foregroundColor(KairosAuth.Color.accent)
                                        
                                        Spacer()
                                        
                                        Text("\(Int(autonomyLevel * 100))%")
                                            .font(KairosAuth.Typography.itemTitle)
                                            .foregroundColor(KairosAuth.Color.primaryText)
                                    }
                                    
                                    Slider(value: $autonomyLevel, in: 0.0...1.0, step: 0.1)
                                        .tint(KairosAuth.Color.accent)
                                        .accessibilityLabel("Autonomy level")
                                        .accessibilityValue("\(Int(autonomyLevel * 100)) percent")
                                        .accessibilityHint("Adjust how independently the agent negotiates")
                                    
                                    HStack {
                                        Text("Always Ask")
                                            .font(KairosAuth.Typography.itemSubtitle)
                                            .foregroundColor(KairosAuth.Color.secondaryText)
                                        
                                        Spacer()
                                        
                                        Text("Full Auto")
                                            .font(KairosAuth.Typography.itemSubtitle)
                                            .foregroundColor(KairosAuth.Color.secondaryText)
                                    }
                                    
                                    Text(autonomyLevelDescription)
                                        .font(KairosAuth.Typography.bodySmall)
                                        .foregroundColor(KairosAuth.Color.tertiaryText)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Advanced Settings Card
                    if agentModeEnabled {
                        DashboardCard {
                            VStack(spacing: KairosAuth.Spacing.large) {
                                HStack {
                                    Image(systemName: "slider.horizontal.3")
                                        .accessibilityHidden(true)
                                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                                        .foregroundColor(KairosAuth.Color.accent)
                                    
                                    Text("Advanced Settings")
                                        .font(KairosAuth.Typography.cardTitle)
                                        .foregroundColor(KairosAuth.Color.primaryText)
                                    
                                    Spacer()
                                }
                                
                                // Auto-accept threshold
                                VStack(spacing: KairosAuth.Spacing.small) {
                                    HStack {
                                        Text("Auto-Accept Threshold")
                                            .font(KairosAuth.Typography.itemTitle)
                                            .foregroundColor(KairosAuth.Color.primaryText)
                                        
                                        Spacer()
                                        
                                        Text("\(Int(autoAcceptThreshold * 100))%")
                                            .font(KairosAuth.Typography.itemSubtitle)
                                            .foregroundColor(KairosAuth.Color.accent)
                                    }
                                    
                                    Slider(value: $autoAcceptThreshold, in: 0.6...1.0, step: 0.05)
                                        .tint(KairosAuth.Color.accent)
                                        .accessibilityLabel("Auto-accept threshold")
                                        .accessibilityValue("\(Int(autoAcceptThreshold * 100)) percent")
                                        .accessibilityHint("Invitations scoring above this value will be accepted automatically")
                                    
                                    Text("Invitations scoring above this are auto-accepted")
                                        .font(KairosAuth.Typography.bodySmall)
                                        .foregroundColor(KairosAuth.Color.tertiaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Divider()
                                    .background(KairosAuth.Color.cardBorder)
                                
                                // Auto-counter threshold
                                VStack(spacing: KairosAuth.Spacing.small) {
                                    HStack {
                                        Text("Auto-Counter Threshold")
                                            .font(KairosAuth.Typography.itemTitle)
                                            .foregroundColor(KairosAuth.Color.primaryText)
                                        
                                        Spacer()
                                        
                                        Text("\(Int(autoCounterThreshold * 100))%")
                                            .font(KairosAuth.Typography.itemSubtitle)
                                            .foregroundColor(KairosAuth.Color.accent)
                                    }
                                    
                                    Slider(value: $autoCounterThreshold, in: 0.3...0.9, step: 0.05)
                                        .tint(KairosAuth.Color.teal)
                                        .accessibilityLabel("Auto-counter threshold")
                                        .accessibilityValue("\(Int(autoCounterThreshold * 100)) percent")
                                        .accessibilityHint("Invitations above this value trigger an automatic counter offer")
                                    
                                    Text("Invitations below auto-accept but above this get countered")
                                        .font(KairosAuth.Typography.bodySmall)
                                        .foregroundColor(KairosAuth.Color.tertiaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Divider()
                                    .background(KairosAuth.Color.cardBorder)
                                
                                // Max negotiation rounds
                                VStack(spacing: KairosAuth.Spacing.small) {
                                    HStack {
                                        Text("Max Negotiation Rounds")
                                            .font(KairosAuth.Typography.itemTitle)
                                            .foregroundColor(KairosAuth.Color.primaryText)
                                        
                                        Spacer()
                                        
                                        Text("\(maxRounds)")
                                            .font(KairosAuth.Typography.itemSubtitle)
                                            .foregroundColor(KairosAuth.Color.accent)
                                    }
                                    
                                    Slider(value: Binding(
                                        get: { Double(maxRounds) },
                                        set: { maxRounds = Int($0) }
                                    ), in: 3...10, step: 1)
                                        .tint(KairosAuth.Color.purple)
                                        .accessibilityLabel("Maximum negotiation rounds")
                                        .accessibilityValue("\(maxRounds)")
                                        .accessibilityHint("Number of rounds before the agent asks for your input")
                                    
                                    Text("Agent escalates to you after this many rounds")
                                        .font(KairosAuth.Typography.bodySmall)
                                        .foregroundColor(KairosAuth.Color.tertiaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Divider()
                                    .background(KairosAuth.Color.cardBorder)
                                
                                // Require confirmation toggle
                                HStack {
                                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                                        Text("Require Final Confirmation")
                                            .font(KairosAuth.Typography.itemTitle)
                                            .foregroundColor(KairosAuth.Color.primaryText)
                                        
                                        Text("Ask before finalizing invitations")
                                            .font(KairosAuth.Typography.itemSubtitle)
                                            .foregroundColor(KairosAuth.Color.secondaryText)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $requireConfirmation)
                                        .labelsHidden()
                                        .tint(KairosAuth.Color.accent)
                                        .accessibilityLabel("Require final confirmation")
                                        .accessibilityHint("When enabled, the agent asks before finalizing invitations")
                                }
                            }
                        }
                        .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Learned Preferences Card
                    if agentModeEnabled, let prefs = vm.agentPreferences {
                        DashboardCard {
                            VStack(spacing: KairosAuth.Spacing.large) {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                        .accessibilityHidden(true)
                                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                                        .foregroundColor(KairosAuth.Color.accent)
                                    
                                    Text("Learned Preferences")
                                        .font(KairosAuth.Typography.cardTitle)
                                        .foregroundColor(KairosAuth.Color.primaryText)
                                    
                                    Spacer()
                                }
                                
                                // Category preferences
                                if !prefs.learnedPatterns.categoryPreferences.isEmpty {
                                    VStack(spacing: KairosAuth.Spacing.medium) {
                                        Text("Categories")
                                            .font(KairosAuth.Typography.itemTitle)
                                            .foregroundColor(KairosAuth.Color.primaryText)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        ForEach(sortedCategoryPreferences(prefs.learnedPatterns.categoryPreferences), id: \.key) { category, score in
                                            HStack {
                                                Text(category.capitalized)
                                                    .font(KairosAuth.Typography.itemSubtitle)
                                                    .foregroundColor(KairosAuth.Color.secondaryText)
                                                
                                                Spacer()
                                                
                                                // Progress bar
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.small)
                                                        .fill(KairosAuth.Color.cardBackground)
                                                        .frame(width: 100, height: 8)
                                                    
                                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.small)
                                                        .fill(KairosAuth.Color.accent)
                                                        .frame(width: 100 * score, height: 8)
                                                }
                                                
                                                Text("\(Int(score * 100))%")
                                                    .font(KairosAuth.Typography.statusBadge)
                                                    .foregroundColor(KairosAuth.Color.accent)
                                                    .frame(width: 40, alignment: .trailing)
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                        .background(KairosAuth.Color.cardBorder)
                                }
                                
                                // Preferred times
                                if !prefs.learnedPatterns.preferredTimes.isEmpty {
                                    VStack(spacing: KairosAuth.Spacing.medium) {
                                        Text("Preferred Times")
                                            .font(KairosAuth.Typography.itemTitle)
                                            .foregroundColor(KairosAuth.Color.primaryText)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        // Simple hour-based display
                                        HStack(spacing: 4) {
                                            ForEach(0..<24, id: \.self) { hour in
                                                let score = prefs.learnedPatterns.preferredTimes[hour] ?? 0.0
                                                VStack(spacing: 2) {
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .fill(score > 0.3 ? KairosAuth.Color.teal : KairosAuth.Color.cardBackground)
                                                        .frame(width: 8, height: max(4, score * 40))
                                                    
                                                    if hour % 6 == 0 {
                                                        Text("\(hour)")
                                                            .font(KairosAuth.Typography.timestamp)
                                                            .foregroundColor(KairosAuth.Color.tertiaryText)
                                                    }
                                                }
                                            }
                                        }
                                        
                                        Text("Peak hours: \(peakHoursLabel(prefs.learnedPatterns.preferredTimes))")
                                            .font(KairosAuth.Typography.bodySmall)
                                            .foregroundColor(KairosAuth.Color.secondaryText)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    
                                    Divider()
                                        .background(KairosAuth.Color.cardBorder)
                                }
                                
                                // Stats
                                HStack {
                                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                                        Text("Analyzed Negotiations")
                                            .font(KairosAuth.Typography.itemSubtitle)
                                            .foregroundColor(KairosAuth.Color.secondaryText)
                                        
                                        Text("\(prefs.learnedPatterns.negotiationCount)")
                                            .font(KairosAuth.Typography.itemTitle)
                                            .foregroundColor(KairosAuth.Color.accent)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: KairosAuth.Spacing.xs) {
                                        Text("Last Updated")
                                            .font(KairosAuth.Typography.itemSubtitle)
                                            .foregroundColor(KairosAuth.Color.secondaryText)
                                        
                                        Text(prefs.learnedPatterns.lastUpdated, style: .relative)
                                            .font(KairosAuth.Typography.itemTitle)
                                            .foregroundColor(KairosAuth.Color.accent)
                                    }
                                }
                                
                                // Reset button
                                Button(action: {
                                    showResetAlert = true
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise")
                                            .accessibilityHidden(true)
                                            .font(.system(size: KairosAuth.IconSize.itemIcon))
                                        
                                        Text("Reset All Learned Data")
                                            .font(KairosAuth.Typography.buttonLabel)
                                        
                                        Spacer()
                                    }
                                    .foregroundColor(KairosAuth.Color.error)
                                    .padding(KairosAuth.Spacing.medium)
                                    .background(
                                        RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                                            .fill(KairosAuth.Color.error.opacity(0.12))
                                    )
                                }
                                .accessibilityHint("Clears all preferences the agent has learned")
                            }
                        }
                        .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // OpenAI API Usage Card (if AI service enabled)
                    if agentModeEnabled, let usage = vm.getAIUsageStats() {
                        DashboardCard {
                            VStack(spacing: KairosAuth.Spacing.large) {
                                HStack {
                                    Image(systemName: "cpu.fill")
                                        .accessibilityHidden(true)
                                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                                        .foregroundColor(KairosAuth.Color.accent)
                                    
                                    Text("AI Decision Service")
                                        .font(KairosAuth.Typography.cardTitle)
                                        .foregroundColor(KairosAuth.Color.primaryText)
                                    
                                    Spacer()
                                }
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                                        Text("API Calls Today")
                                            .font(KairosAuth.Typography.itemSubtitle)
                                            .foregroundColor(KairosAuth.Color.secondaryText)
                                        
                                        Text("\(usage.used) / \(usage.limit)")
                                            .font(KairosAuth.Typography.itemTitle)
                                            .foregroundColor(usageColor(usage.used, limit: usage.limit))
                                    }
                                    
                                    Spacer()
                                    
                                    // Progress circle
                                    ZStack {
                                        Circle()
                                            .stroke(KairosAuth.Color.cardBorder, lineWidth: 4)
                                            .frame(width: 60, height: 60)
                                        
                                        Circle()
                                            .trim(from: 0, to: min(Double(usage.used) / Double(usage.limit), 1.0))
                                            .stroke(usageColor(usage.used, limit: usage.limit), lineWidth: 4)
                                            .frame(width: 60, height: 60)
                                            .rotationEffect(.degrees(-90))
                                        
                                        Text("\(Int(min(Double(usage.used) / Double(usage.limit), 1.0) * 100))%")
                                            .font(KairosAuth.Typography.statusBadge)
                                            .foregroundColor(KairosAuth.Color.primaryText)
                                    }
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("\(usage.used) of \(usage.limit) API calls used")
                                }
                                
                                if usage.used >= usage.limit {
                                    Text("⚠️ Daily limit reached. Agent using heuristic scoring only.")
                                        .font(KairosAuth.Typography.bodySmall)
                                        .foregroundColor(KairosAuth.Color.warning)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    Spacer(minLength: KairosAuth.Spacing.dashboardVertical)
                } // Close VStack
                .padding(.top, KairosAuth.Spacing.small)
            } // Close ScrollView
    } // Close ZStack
    .background(KairosAuth.Color.backgroundGradient(), ignoresSafeAreaEdges: .all)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Agent Settings")
                    .font(KairosAuth.Typography.screenTitle)
                    .foregroundColor(KairosAuth.Color.primaryText)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: saveSettings) {
                    if isSaving {
                        ProgressView()
                            .tint(KairosAuth.Color.primaryText)
                    } else {
                        Text("Save")
                            .font(KairosAuth.Typography.buttonLabel)
                            .foregroundColor(KairosAuth.Color.accent)
                    }
                }
                .disabled(isSaving)
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
        .alert("Reset Learned Data?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetLearnedData()
            }
        } message: {
            Text("This will clear all learned preferences (venues, times, categories). Your veto rules and autonomy settings will be preserved.")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Load current settings from AppVM
    private func loadCurrentSettings() {
        guard let prefs = vm.agentPreferences else {
            // Initialize with defaults if no preferences exist
            agentModeEnabled = false
            autonomyLevel = 0.5
            autoAcceptThreshold = 0.85
            autoCounterThreshold = 0.65
            maxRounds = 5
            requireConfirmation = true
            return
        }
        
        agentModeEnabled = prefs.autonomySettings.globalAutonomyLevel > 0.0
        autonomyLevel = prefs.autonomySettings.globalAutonomyLevel
        autoAcceptThreshold = prefs.autonomySettings.autoAcceptThreshold
        autoCounterThreshold = prefs.autonomySettings.autoCounterThreshold
        maxRounds = prefs.autonomySettings.maxNegotiationRounds
        requireConfirmation = prefs.autonomySettings.requireFinalConfirmation
    }
    
    /// Save settings to AppVM
    private func saveSettings() {
        isSaving = true
        
        Task {
            do {
                // Create or update autonomy settings
                var newSettings = AutonomySettings()
                newSettings.globalAutonomyLevel = agentModeEnabled ? autonomyLevel : 0.0
                newSettings.autoAcceptThreshold = autoAcceptThreshold
                newSettings.autoCounterThreshold = autoCounterThreshold
                newSettings.maxNegotiationRounds = maxRounds
                newSettings.requireFinalConfirmation = requireConfirmation
                
                // Update agent preferences
                if var prefs = vm.agentPreferences {
                    prefs.autonomySettings = newSettings
                    prefs.dateUpdated = Date()
                    await vm.saveAgentPreferences(prefs)
                } else {
                    // Create new preferences if none exist
                    guard let userId = vm.currentUser?.id else { return }
                    var newPrefs = AgentPreferences(userId: userId)
                    newPrefs.autonomySettings = newSettings
                    await vm.saveAgentPreferences(newPrefs)
                }
                
                await MainActor.run {
                    isSaving = false
                    print("✅ Agent settings saved")
                }
            }
        }
    }
    
    /// Reset all learned data
    private func resetLearnedData() {
        Task {
            await vm.resetLearnedPatterns()
            print("✅ Learned data reset")
        }
    }
    
    /// Get autonomy level label
    private var autonomyLevelLabel: String {
        if autonomyLevel < 0.3 {
            return "Conservative"
        } else if autonomyLevel < 0.7 {
            return "Balanced"
        } else {
            return "Aggressive"
        }
    }
    
    /// Get autonomy level description
    private var autonomyLevelDescription: String {
        if autonomyLevel < 0.3 {
            return "Agent rarely acts alone. You'll approve most decisions."
        } else if autonomyLevel < 0.7 {
            return "Agent handles routine negotiations. You'll see important ones."
        } else {
            return "Agent handles most negotiations independently."
        }
    }
    
    /// Sort category preferences by score
    private func sortedCategoryPreferences(_ prefs: [String: Double]) -> [(key: String, value: Double)] {
        prefs.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }
    
    /// Get peak hours label from preferred times
    private func peakHoursLabel(_ times: [Int: Double]) -> String {
        let peaks = times.filter { $0.value > 0.5 }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { "\($0.key):00" }
        
        return peaks.isEmpty ? "No data yet" : peaks.joined(separator: ", ")
    }
    
    /// Get usage color based on percentage
    private func usageColor(_ used: Int, limit: Int) -> Color {
        let percentage = Double(used) / Double(limit)
        if percentage < 0.7 {
            return KairosAuth.Color.accent
        } else if percentage < 0.9 {
            return KairosAuth.Color.warning
        } else {
            return KairosAuth.Color.error
        }
    }
}

// MARK: - Preview

struct AgentSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AgentSettingsView(vm: AppVM())
        }
    }
}
