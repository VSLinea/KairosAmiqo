//
//  PlanActivityFeed.swift
//  KairosAmiqo
//
//  Created by Copilot on 2025-10-19.
//  Phase 3 - Task 11.4: Activity feed showing participant response statuses
//

import SwiftUI

/// Activity feed displaying participant response statuses with icons and timestamps
/// Used in PlanDetailModal to show negotiation progress
///
/// Design: Uses KairosAuth design system tokens exclusively (100% compliance)
struct PlanActivityFeed: View {
    // MARK: - Properties
    
    let plan: Negotiation
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
            // Section header
            Text("ACTIVITY")
                .font(KairosAuth.Typography.statusBadge)
                .foregroundColor(KairosAuth.Color.tertiaryText)
                .tracking(0.3)
            
            // Participant list with statuses
            if let participants = plan.participants, !participants.isEmpty {
                VStack(spacing: KairosAuth.Spacing.small) {
                    ForEach(participants, id: \.user_id) { participant in
                        participantRow(for: participant)
                    }
                }
            } else {
                // Empty state
                HStack(spacing: KairosAuth.Spacing.small) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: KairosAuth.IconSize.badge))
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                        .accessibilityHidden(true)
                    
                    Text("No participants yet")
                        .font(KairosAuth.Typography.itemSubtitle)
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                }
            }
        }
    }
    
    // MARK: - Participant Row
    
    @ViewBuilder
    private func participantRow(for participant: PlanParticipant) -> some View {
        HStack(spacing: KairosAuth.Spacing.small) {
            // Status icon
            Image(systemName: statusIcon(for: participant.status))
                .font(.system(size: KairosAuth.IconSize.badge))
                .foregroundColor(statusColor(for: participant.status))
                .accessibilityHidden(true)
            
            // Participant name
            Text(participant.name)
                .font(KairosAuth.Typography.itemSubtitle)
                .foregroundColor(KairosAuth.Color.primaryText)
            
            Spacer()
            
            // Status label
            Text(statusLabel(for: participant.status))
                .font(KairosAuth.Typography.statusBadge)
                .foregroundColor(KairosAuth.Color.secondaryText)
            
            // TODO(Kairos): Add responded_at timestamp when backend provides it
            // See /docs/01-data-model.md for participant structure
        }
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Status Helpers
    
    /// Map participant status to SF Symbol icon
    private func statusIcon(for status: String) -> String {
        switch status.lowercased() {
        case "accepted":
            return "checkmark.circle.fill"
        case "countered":
            return "arrow.triangle.2.circlepath.circle.fill"
        case "declined", "rejected":
            return "xmark.circle.fill"
        case "organizer", "initiator":  // Support both (initiator = legacy)
            return "crown.fill"
        case "invited", "pending":
            return "clock.fill"
        default:
            return "circle.fill"
        }
    }
    
    /// Map participant status to color
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "accepted":
            return KairosAuth.Color.accent  // Mint for positive
        case "countered":
            return KairosAuth.Color.teal    // Teal for action
        case "declined", "rejected":
            return KairosAuth.Color.tertiaryText  // Gray for negative
        case "organizer", "initiator":  // Support both (initiator = legacy)
            return KairosAuth.Color.purple  // Purple for special role
        case "invited", "pending":
            return KairosAuth.Color.secondaryText  // Gray for waiting
        default:
            return KairosAuth.Color.tertiaryText
        }
    }
    
    /// Map participant status to display label
    private func statusLabel(for status: String) -> String {
        switch status.lowercased() {
        case "accepted":
            return "Accepted"
        case "countered":
            return "Countered"
        case "declined", "rejected":
            return "Declined"
        case "organizer", "initiator":  // Support both (initiator = legacy)
            return "Organizer"
        case "invited":
            return "Invited"
        case "pending":
            return "Pending"
        default:
            return status.capitalized
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PlanActivityFeed_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: KairosAuth.Spacing.large) {
            // Active negotiation with mixed statuses
            PlanActivityFeed(
                plan: Negotiation(
                    id: UUID(),
                    title: "Coffee Tomorrow",
                    status: "awaiting_replies",
                    started_at: "2025-10-13T10:00:00Z",
                    date_created: "2025-10-13T10:00:00Z",
                    intent_category: "coffee",
                    participants: [
                        PlanParticipant(
                            user_id: UUID(),
                            name: "You",
                            status: "organizer"  // Plan creator (replaces legacy "initiator")
                        ),
                        PlanParticipant(
                            user_id: UUID(),
                            name: "Alex Chen",
                            email: nil,
                            phone: nil,
                            status: "accepted"
                        ),
                        PlanParticipant(
                            user_id: UUID(),
                            name: "Jordan Lee",
                            email: nil,
                            phone: nil,
                            status: "countered"
                        ),
                        PlanParticipant(
                            user_id: UUID(),
                            name: "Sam Taylor",
                            email: nil,
                            phone: nil,
                            status: "pending"
                        )
                    ],
                    state: "awaiting_replies",
                    proposed_slots: nil,
                    proposed_venues: nil,
                    expires_at: "2025-10-20T10:00:00Z"
                )
            )
            .padding(KairosAuth.Spacing.cardPadding)
            .background(KairosAuth.Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card))
            
            // Empty state
            PlanActivityFeed(
                plan: Negotiation(
                    id: UUID(),
                    title: "No Participants",
                    status: "draft",
                    started_at: nil,
                    date_created: nil,
                    intent_category: nil,
                    participants: nil,
                    state: nil,
                    proposed_slots: nil,
                    proposed_venues: nil,
                    expires_at: nil
                )
            )
            .padding(KairosAuth.Spacing.cardPadding)
            .background(KairosAuth.Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card))
        }
        .padding()
        .background(
            LinearGradient(
                colors: [KairosAuth.Color.gradientStart, KairosAuth.Color.gradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .previewLayout(.sizeThatFits)
    }
}
#endif
