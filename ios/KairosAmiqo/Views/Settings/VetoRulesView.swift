//
//  VetoRulesView.swift
//  KairosAmiqo
//
//  Task 28: Agent-to-Agent Negotiation - Veto Rules UI
//  Week 1, Day 5: Settings screen for user-defined hard constraints
//
//  Created: 2025-11-01
//  See: /AGENT-TO-AGENT-IMPLEMENTATION-PLAN.md
//  See: /.github/apple-docs-grounded-mode.md (SwiftUI.View iOS 13.0+, SwiftUI.Toggle iOS 13.0+)
//

import SwiftUI

/// Veto Rules management screen
/// Allows users to define hard constraints that agent must never violate
///
/// **Available Rule Types:**
/// - Never Before: No invites before specified hour (e.g., 9am)
/// - Never After: No invites after specified hour (e.g., 10pm)
/// - Never On Days: Block specific weekdays (e.g., never on Mondays)
/// - Max Duration: Cap invite length (e.g., max 2 hours)
/// - Respect Calendar: Check calendar for conflicts
///
/// **Design:**
/// - KairosAuth design system (100% token usage)
/// - Liquid Glass cards with Mint/Teal accents
/// - Inline editing (no separate modal)
/// - Swipe-to-delete for removal
///
/// @available(iOS 15.0, *)
struct VetoRulesView: View {
    @ObservedObject var vm: AppVM
    @State private var showingAddRuleSheet = false
    @State private var editingRule: VetoRule?
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: KairosAuth.Spacing.cardSpacing) {
                        // Header Card
                        DashboardCard {
                            VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                                HStack {
                                    Image(systemName: "hand.raised.fill")
                                        .accessibilityHidden(true)
                                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                                        .foregroundColor(KairosAuth.Color.accent)
                                    
                                    Text("Veto Rules")
                                        .font(KairosAuth.Typography.cardTitle)
                                        .foregroundColor(KairosAuth.Color.primaryText)
                                    
                                    Spacer()
                                }
                                
                                Text("Hard constraints your agent will never violate. Add rules to protect your time and preferences.")
                                    .font(KairosAuth.Typography.itemSubtitle)
                                    .foregroundColor(KairosAuth.Color.secondaryText)
                            }
                        }
                        .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                        
                        // Active Rules
                        if let preferences = vm.agentPreferences,
                           !preferences.vetoRules.isEmpty {
                            VStack(spacing: KairosAuth.Spacing.small) {
                                ForEach(preferences.vetoRules) { rule in
                                    VetoRuleCard(rule: rule, vm: vm)
                                }
                            }
                            .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                        } else {
                            // Empty state
                            DashboardCard {
                                VStack(spacing: KairosAuth.Spacing.medium) {
                                    Image(systemName: "checkmark.shield.fill")
                                        .accessibilityHidden(true)
                                        .font(.system(size: KairosAuth.IconSize.heroIcon))
                                        .foregroundColor(KairosAuth.Color.teal.opacity(0.5))
                                    
                                    Text("No Veto Rules Yet")
                                        .font(KairosAuth.Typography.cardTitle)
                                        .foregroundColor(KairosAuth.Color.primaryText)
                                    
                                    Text("Tap + to add your first rule")
                                        .font(KairosAuth.Typography.itemSubtitle)
                                        .foregroundColor(KairosAuth.Color.secondaryText)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, KairosAuth.Spacing.large)
                            }
                            .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                        }
                        
                        // Add Rule Button
                        Button {
                            showingAddRuleSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .accessibilityHidden(true)
                                    .font(.system(size: KairosAuth.IconSize.button))
                                Text("Add Veto Rule")
                                    .font(KairosAuth.Typography.buttonLabel)
                            }
                            .foregroundColor(KairosAuth.Color.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, KairosAuth.Spacing.buttonVertical)
                            .background(KairosAuth.Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button))
                            .overlay(
                                RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                                    .stroke(KairosAuth.Color.accent, lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                        .padding(.top, KairosAuth.Spacing.medium)
                        .accessibilityHint("Adds a new veto rule for your agent")
                    }
                    .padding(.top, KairosAuth.Spacing.dashboardVertical)
                    .padding(.bottom, 100) // Tab bar clearance
                }
            }
            .navigationTitle("Veto Rules")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddRuleSheet) {
                AddVetoRuleSheet(vm: vm, isPresented: $showingAddRuleSheet)
            }
        }
        .background(KairosAuth.Color.backgroundGradient(), ignoresSafeAreaEdges: .all)
    }
}

// MARK: - Veto Rule Card

struct VetoRuleCard: View {
    let rule: VetoRule
    @ObservedObject var vm: AppVM
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        DashboardCard {
            HStack(spacing: KairosAuth.Spacing.medium) {
                // Icon
                Image(systemName: iconForRuleType(rule.type))
                    .accessibilityHidden(true)
                    .font(.system(size: KairosAuth.IconSize.itemIcon))
                    .foregroundColor(rule.isActive ? KairosAuth.Color.accent : KairosAuth.Color.secondaryText)
                    .frame(width: 32)
                
                // Rule description
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleForRule(rule))
                        .font(KairosAuth.Typography.itemTitle)
                        .foregroundColor(KairosAuth.Color.primaryText)
                    
                    Text(descriptionForRule(rule))
                        .font(KairosAuth.Typography.itemSubtitle)
                        .foregroundColor(KairosAuth.Color.secondaryText)
                }
                
                Spacer()
                
                // Toggle
                Toggle("", isOn: Binding(
                    get: { rule.isActive },
                    set: { newValue in
                        vm.toggleVetoRule(id: rule.id, isActive: newValue)
                    }
                ))
                .labelsHidden()
                .tint(KairosAuth.Color.accent)
                .accessibilityLabel(titleForRule(rule))
                .accessibilityHint(rule.isActive ? "Double tap to disable this rule" : "Double tap to enable this rule")
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Delete Veto Rule?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                vm.deleteVetoRule(id: rule.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This rule will be permanently removed.")
        }
    }
    
    // MARK: - Helpers
    
    private func iconForRuleType(_ type: VetoRuleType) -> String {
        switch type {
        case .neverBefore: return "sunrise.fill"
        case .neverAfter: return "sunset.fill"
        case .neverOnDays: return "calendar.badge.minus"
        case .neverAtVenue: return "location.slash.fill"
        case .respectCalendar: return "calendar.badge.clock"
        case .maxDuration: return "hourglass"
        case .neverInvite: return "person.crop.circle.badge.xmark"
        case .custom: return "gearshape.fill"
        }
    }
    
    private func titleForRule(_ rule: VetoRule) -> String {
        switch rule.type {
        case .neverBefore:
            if let hour = Int(rule.value) {
                return "Never Before \(formatHour(hour))"
            }
            return "Never Before"
            
        case .neverAfter:
            if let hour = Int(rule.value) {
                return "Never After \(formatHour(hour))"
            }
            return "Never After"
            
        case .neverOnDays:
            if let data = rule.value.data(using: .utf8),
               let days = try? JSONDecoder().decode([String].self, from: data) {
                let formatted = days.map { $0.capitalized }.joined(separator: ", ")
                return "Never On \(formatted)"
            }
            return "Never On Days"
            
        case .maxDuration:
            if let minutes = Int(rule.value) {
                let hours = minutes / 60
                let mins = minutes % 60
                if hours > 0 && mins > 0 {
                    return "Max \(hours)h \(mins)m"
                } else if hours > 0 {
                    return "Max \(hours) Hour\(hours > 1 ? "s" : "")"
                } else {
                    return "Max \(mins) Minutes"
                }
            }
            return "Max Duration"
            
        case .respectCalendar:
            return "Respect Calendar: \(rule.value)"
            
        case .neverAtVenue:
            return "Never At Venue"
            
        case .neverInvite:
            return "Never Invite Person"
            
        case .custom:
            return "Custom Rule"
        }
    }
    
    private func descriptionForRule(_ rule: VetoRule) -> String {
        switch rule.type {
        case .neverBefore:
            return "Agent won't send invites before this time"
        case .neverAfter:
            return "Agent won't send invites after this time"
        case .neverOnDays:
            return "Agent won't schedule on these days"
        case .maxDuration:
            return "Invites cannot exceed this length"
        case .respectCalendar:
            return "Check calendar for conflicts"
        case .neverAtVenue:
            return "Agent won't suggest this venue"
        case .neverInvite:
            return "Agent won't include this person"
        case .custom:
            return "Custom constraint"
        }
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a" // e.g., "9 AM"
        
        var components = DateComponents()
        components.hour = hour
        
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        
        return "\(hour):00"
    }
}

// MARK: - Add Veto Rule Sheet

struct AddVetoRuleSheet: View {
    @ObservedObject var vm: AppVM
    @Binding var isPresented: Bool
    
    @State private var selectedType: VetoRuleType = .neverBefore
    @State private var neverBeforeHour: Int = 9
    @State private var neverAfterHour: Int = 22
    @State private var blockedDays: Set<String> = []
    @State private var maxDurationHours: Int = 2
    @State private var maxDurationMinutes: Int = 0
    @State private var calendarName: String = "Work"
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: KairosAuth.Spacing.cardSpacing) {
                        // Rule Type Picker
                        DashboardCard {
                            VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                                Text("Rule Type")
                                    .font(KairosAuth.Typography.cardTitle)
                                    .foregroundColor(KairosAuth.Color.primaryText)
                                
                                Picker("Type", selection: $selectedType) {
                                    Text("Never Before").tag(VetoRuleType.neverBefore)
                                    Text("Never After").tag(VetoRuleType.neverAfter)
                                    Text("Never On Days").tag(VetoRuleType.neverOnDays)
                                    Text("Max Duration").tag(VetoRuleType.maxDuration)
                                    Text("Respect Calendar").tag(VetoRuleType.respectCalendar)
                                }
                                .pickerStyle(.wheel)
                                .labelsHidden()
                                .accessibilityLabel("Rule type")
                            }
                        }
                        .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                        
                        // Rule Value Input
                        DashboardCard {
                            ruleValueInput
                        }
                        .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                        
                        // Add Button
                        Button {
                            addRule()
                        } label: {
                            Text("Add Rule")
                                .font(KairosAuth.Typography.buttonLabel)
                                .foregroundColor(KairosAuth.Color.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, KairosAuth.Spacing.buttonVertical)
                                .background(KairosAuth.Color.accent)
                                .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button))
                        }
                        .accessibilityHint("Saves the veto rule with the selected settings")
                        .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                    }
                    .padding(.top, KairosAuth.Spacing.dashboardVertical)
                }
            }
            .navigationTitle("Add Veto Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(KairosAuth.Color.accent)
                }
            }
        }
        .background(KairosAuth.Color.backgroundGradient(), ignoresSafeAreaEdges: .all)
    }
    
    @ViewBuilder
    private var ruleValueInput: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
            switch selectedType {
            case .neverBefore:
                Text("Don't schedule before:")
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundColor(KairosAuth.Color.primaryText)
                
                Picker("Hour", selection: $neverBeforeHour) {
                    ForEach(0..<24) { hour in
                        Text(formatHour(hour)).tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .accessibilityLabel("Don't schedule before hour")
                
            case .neverAfter:
                Text("Don't schedule after:")
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundColor(KairosAuth.Color.primaryText)
                
                Picker("Hour", selection: $neverAfterHour) {
                    ForEach(0..<24) { hour in
                        Text(formatHour(hour)).tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .accessibilityLabel("Don't schedule after hour")
                
            case .neverOnDays:
                Text("Block these days:")
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundColor(KairosAuth.Color.primaryText)
                
                VStack(spacing: KairosAuth.Spacing.small) {
                    ForEach(["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"], id: \.self) { day in
                        Toggle(day.capitalized, isOn: Binding(
                            get: { blockedDays.contains(day) },
                            set: { isOn in
                                if isOn {
                                    blockedDays.insert(day)
                                } else {
                                    blockedDays.remove(day)
                                }
                            }
                        ))
                        .font(KairosAuth.Typography.itemTitle)
                        .foregroundColor(KairosAuth.Color.primaryText)
                        .tint(KairosAuth.Color.accent)
                    }
                }
                
            case .maxDuration:
                Text("Maximum invitation duration:")
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundColor(KairosAuth.Color.primaryText)
                
                HStack(spacing: KairosAuth.Spacing.medium) {
                    VStack {
                        Picker("Hours", selection: $maxDurationHours) {
                            ForEach(0..<12) { hour in
                                Text("\(hour)h").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .accessibilityLabel("Maximum hours")
                    }
                    
                    VStack {
                        Picker("Minutes", selection: $maxDurationMinutes) {
                            ForEach([0, 15, 30, 45], id: \.self) { min in
                                Text("\(min)m").tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .accessibilityLabel("Additional minutes")
                    }
                }
                
            case .respectCalendar:
                Text("Calendar to check:")
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundColor(KairosAuth.Color.primaryText)
                
                TextField("Calendar name", text: $calendarName)
                    .font(KairosAuth.Typography.fieldInput)
                    .foregroundColor(KairosAuth.Color.primaryText)
                    .padding(KairosAuth.Spacing.cardPadding)
                    .background(KairosAuth.Color.fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.small))
                
                Text("Agent will check this calendar for conflicts")
                    .font(KairosAuth.Typography.itemSubtitle)
                    .foregroundColor(KairosAuth.Color.secondaryText)
                
            default:
                Text("This rule type is not yet implemented")
                    .font(KairosAuth.Typography.itemSubtitle)
                    .foregroundColor(KairosAuth.Color.secondaryText)
            }
        }
    }
    
    private func addRule() {
        let value: String
        
        switch selectedType {
        case .neverBefore:
            value = String(neverBeforeHour)
        case .neverAfter:
            value = String(neverAfterHour)
        case .neverOnDays:
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(Array(blockedDays)),
               let json = String(data: data, encoding: .utf8) {
                value = json
            } else {
                value = "[]"
            }
        case .maxDuration:
            value = String(maxDurationHours * 60 + maxDurationMinutes)
        case .respectCalendar:
            value = calendarName
        default:
            value = ""
        }
        
        vm.addVetoRule(type: selectedType, value: value)
        isPresented = false
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        
        var components = DateComponents()
        components.hour = hour
        
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        
        return "\(hour):00"
    }
}

// MARK: - Preview

#Preview {
    VetoRulesView(vm: AppVM())
}
