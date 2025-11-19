//
//  ActiveInvitationsListView.swift
//  KairosAmiqo
//
//  Full list view for Active Invitations
//  Navigated to from Dashboard card tap (horizontal slide)
//  REFACTORED: Phase 2 - Now uses GenericListView (Nov 8, 2025)
//

import SwiftUI

/// Full list view for Active Invitations (navigation destination)
/// Uses GenericListView for shared navigation/modal pattern
struct ActiveInvitationsListView: View {
    let invitations: [Negotiation]
    let onSelectInvitation: (Negotiation) -> Void
    let onCreateNew: () -> Void
    @ObservedObject var vm: AppVM

    var body: some View {
        GenericListView(
            title: "Active Invitations",
            items: invitations,
            rowContent: { invitation, action in
                ActiveInvitationFullRow(invitation: invitation, action: action)
            },
            modalContent: { invitation, isPresented in
                PlanDetailModal(plan: invitation, isPresented: isPresented, vm: vm)
            },
            onSelectItem: onSelectInvitation
        )
    }
}

/// Full-sized invitation row for list view
private struct ActiveInvitationFullRow: View {
    let invitation: Negotiation
    let action: () -> Void

    // Map intent_category to icon (same logic as ActiveInvitationsCard)
    private var iconName: String {
        switch invitation.intent_category?.lowercased() {
        case "coffee": return "cup.and.saucer.fill"
        case "lunch": return "fork.knife"
        case "dinner": return "fork.knife"
        case "drinks": return "wineglass.fill"
        case "gym": return "figure.run"
        case "movie": return "popcorn.fill"
        default: return "calendar"
        }
    }

    private var accessibilitySummary: String {
        let title = invitation.title?.isEmpty == false ? invitation.title! : "Untitled invitation"
        let status = invitation.status?.capitalized ?? "Draft"
        let participantCount = invitation.participants?.count ?? 0
        let participantSummary = participantCount == 1 ? "1 participant" : "\(participantCount) participants"
        let slotsCount = invitation.proposed_slots?.count ?? 0
        let slotsSummary: String
        if slotsCount == 0 {
            slotsSummary = "No times proposed yet"
        } else if slotsCount == 1 {
            slotsSummary = "1 proposed time"
        } else {
            slotsSummary = "\(slotsCount) proposed times"
        }

        return "\(title), status \(status), \(participantSummary), \(slotsSummary)"
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                HStack(spacing: KairosAuth.Spacing.medium) {
                    // Icon
                    Image(systemName: iconName)
                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                        .foregroundColor(KairosAuth.Color.teal)
                        .frame(width: 48, height: 48)
                        .background(
                            KairosAuth.Color.teal.opacity(0.15)
                                .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button))
                        )
                        .accessibilityHidden(true)

                    // Content
                    VStack(alignment: .leading, spacing: 6) {
                        Text(invitation.title ?? "Untitled Invitation")
                            .font(KairosAuth.Typography.itemTitle)
                            .foregroundColor(KairosAuth.Color.primaryText)
                            .lineLimit(2)

                        HStack(spacing: 12) {
                            // Participants
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(KairosAuth.Typography.buttonIcon)
                                    .accessibilityHidden(true)
                                Text("\(invitation.participants?.count ?? 0)")
                                    .font(KairosAuth.Typography.itemSubtitle)
                            }
                            .foregroundColor(KairosAuth.Color.teal)

                            // Status
                            Text(invitation.status?.capitalized ?? "Draft")
                                .font(KairosAuth.Typography.itemSubtitle)
                                .foregroundColor(KairosAuth.Color.secondaryText)
                        }

                        // Proposed slots count (if available)
                        if let slotsCount = invitation.proposed_slots?.count, slotsCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(KairosAuth.Typography.buttonIcon)
                                    .accessibilityHidden(true)
                                Text("\(slotsCount) time\(slotsCount == 1 ? "" : "s") proposed")
                                    .font(KairosAuth.Typography.buttonIcon)
                            }
                            .foregroundColor(KairosAuth.Color.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                KairosAuth.Color.accent.opacity(0.15)
                                    .clipShape(Capsule())
                            )
                        }
                    }

                    Spacer()

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(KairosAuth.Typography.buttonIcon)
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                        .accessibilityHidden(true)
                }
            }
            .padding(KairosAuth.Spacing.large)
            .background(
                KairosAuth.Color.cardBackground
                    .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card))
            )
            .overlay(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                    .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Opens invitation details")
    }
}

// MARK: - Preview

#if DEBUG
struct ActiveInvitationsListViewPreview: View {
    let mockInvitations = [
        Negotiation(
            id: UUID(),
            title: "Coffee with Sarah & Mike",
            status: "active",
            intent_category: "coffee",
            participants: [
                PlanParticipant(user_id: UUID(), name: "You", status: "accepted"),
                PlanParticipant(user_id: UUID(), name: "Sarah", status: "pending"),
                PlanParticipant(user_id: UUID(), name: "Mike", status: "pending")
            ],
            proposed_slots: [
                ProposedSlot(time: "2025-10-20T10:00:00Z", venue: nil),
                ProposedSlot(time: "2025-10-20T14:00:00Z", venue: nil)
            ]
        ),
        Negotiation(
            id: UUID(),
            title: "Team Lunch Meeting",
            status: "pending",
            intent_category: "lunch",
            participants: [
                PlanParticipant(user_id: UUID(), name: "You", status: "accepted")
            ],
            proposed_slots: nil
        ),
        Negotiation(
            id: UUID(),
            title: "Weekend Hike",
            status: "started",
            intent_category: "workout",
            participants: [
                PlanParticipant(user_id: UUID(), name: "You", status: "accepted")
            ],
            proposed_slots: nil
        )
    ]

    var body: some View {
        ActiveInvitationsListView(
            invitations: mockInvitations,
            onSelectInvitation: { invitation in
                print("Selected: \(invitation.title ?? "Untitled")")
            },
            onCreateNew: {
                print("Create new invitation")
            },
            vm: AppVM()
        )
    }
}

struct ActiveInvitationsListViewPreview_Previews: PreviewProvider {
    static var previews: some View {
        ActiveInvitationsListViewPreview()
    }
}
#endif
