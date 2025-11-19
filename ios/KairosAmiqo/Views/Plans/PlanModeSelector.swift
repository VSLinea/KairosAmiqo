//
//  PlanModeSelector.swift
//  KairosAmiqo
//
//  Dual-path entry point for plan creation
//  User chooses: Ask Amiqo (AI assistant) vs Plan Manually (wizard)
//  See: /HANDOVER-CONVERSATIONAL-AI-IMPLEMENTATION.md Phase 1
//

import SwiftUI

/// Mode selector  plan creation - AI assistant vs Manual wizard
/// Respects user preference (ask every time, AI default, manual default)
struct PlanModeSelector: View {
    @ObservedObject var vm: AppVM
    @Environment(\.dismiss) private var dismiss
    
    /// Selected mode (triggers navigation)
    @State private var selectedMode: PlanMode?
    
    /// Plan creation modes
    enum PlanMode: String, Codable {
        case conversationalAI  // Chat-based AI assistant (Plus only)
        case manual            // Step-by-step wizard (Free + Plus)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: KairosAuth.Spacing.large) {
                    Spacer()
                    
                    // Header
                    VStack(spacing: KairosAuth.Spacing.small) {
                        Text("How do you want to invite?")
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundStyle(KairosAuth.Color.primaryText)
                        
                        Text("Choose how you want to coordinate")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundStyle(KairosAuth.Color.secondaryText)
                    }
                    .padding(.bottom, KairosAuth.Spacing.medium)
                    
                    // AI Mode Card (Development: Unlocked for testing)
                    ModeCard(
                        icon: "sparkles",
                        iconSize: KairosAuth.IconSize.heroIcon,
                        title: "Ask Amiqo to Help",
                        subtitle: "Chat with AI assistant",
                        badge: nil,  // Remove "Plus" badge for testing
                        locked: false,  // Unlocked for development
                        action: {
                            selectedMode = .conversationalAI
                        }
                    )
                    
                    // Manual Mode Card (Always available)
                    ModeCard(
                        icon: "slider.horizontal.3",
                        iconSize: KairosAuth.IconSize.heroIcon,
                        title: "Create Manually",
                        subtitle: "Step-by-step invite wizard",
                        badge: nil,
                        locked: false,
                        action: {
                            selectedMode = .manual
                        }
                    )
                    
                    Spacer()
                    
                    // Preference hint
                    Button(action: {
                        // TODO: Navigate to Settings > Agent Preferences
                        // For now, just dismiss
                        dismiss()
                    }) {
                        Text("Set a default in Settings")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundStyle(KairosAuth.Color.tertiaryText)
                    }
                    .padding(.bottom, KairosAuth.Spacing.medium)
                }
                .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
            }
            .background(
                KairosAuth.Color.backgroundGradient(),
                ignoresSafeAreaEdges: .all
            )
            .navigationTitle("Create Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(KairosAuth.Color.accent)
                }
            }
            .fullScreenCover(item: $selectedMode) { mode in
                switch mode {
                case .conversationalAI:
                    // Phase 2: Conversational AI planning interface
                    ConversationalPlanFlow(vm: vm)
                    
                case .manual:
                    // Existing manual wizard (unchanged)
                    CreateProposalFlow(vm: vm, template: vm.selectedTemplate)
                }
            }
        }
    }
}

// MARK: - Mode Card Component

/// Card for selecting planning mode
private struct ModeCard: View {
    let icon: String
    let iconSize: CGFloat
    let title: String
    let subtitle: String
    let badge: String?
    let locked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: KairosAuth.Spacing.medium) {
                // Icon
                ZStack {
                    Circle()
                        .fill(locked ? KairosAuth.Color.cardBackground : KairosAuth.Color.accent.opacity(0.2))
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)
                    
                    Image(systemName: locked ? "lock.fill" : icon)
                        .font(Font.system(size: iconSize))
                        .foregroundStyle(locked ? KairosAuth.Color.tertiaryText : KairosAuth.Color.accent)
                        .accessibilityHidden(true)
                }
                
                // Text
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                    HStack(spacing: KairosAuth.Spacing.small) {
                        Text(title)
                            .font(KairosAuth.Typography.itemTitle)
                            .foregroundStyle(locked ? KairosAuth.Color.secondaryText : KairosAuth.Color.primaryText)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(KairosAuth.Typography.statusBadge)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(KairosAuth.Color.accent)
                                )
                        }
                    }
                    
                    Text(subtitle)
                        .font(KairosAuth.Typography.itemSubtitle)
                        .foregroundStyle(KairosAuth.Color.secondaryText)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(Font.system(size: KairosAuth.IconSize.itemIcon))
                    .foregroundStyle(KairosAuth.Color.tertiaryText)
                    .accessibilityHidden(true)
            }
            .padding(KairosAuth.Spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                    .fill(KairosAuth.Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                            .stroke(locked ? KairosAuth.Color.cardBorder : KairosAuth.Color.accent.opacity(0.3), lineWidth: locked ? 1 : 2)
                    )
            )
            .shadow(
                color: KairosAuth.Shadow.cardColor,
                radius: KairosAuth.Shadow.cardRadius,
                y: KairosAuth.Shadow.cardY
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Identifiable Conformance

extension PlanModeSelector.PlanMode: Identifiable {
    var id: String { rawValue }
}

// MARK: - Preview

#Preview("Mode Selector - Free User") {
    PlanModeSelector(vm: {
        let vm = AppVM()
        // Mock free user by setting store manager status
        vm.storeManager.subscriptionStatus = .free
        return vm
    }())
}

#Preview("Mode Selector - Plus User") {
    PlanModeSelector(vm: {
        let vm = AppVM()
        // Mock Plus user by setting store manager status
        vm.storeManager.subscriptionStatus = .plus(period: .monthly)
        return vm
    }())
}
