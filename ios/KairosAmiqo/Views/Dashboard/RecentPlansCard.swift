//
//  RecentPlansCard.swift
//  KairosAmiqo
//
//  Recent Proposals card for Dashboard
//  Shows last 2 completed plans with muted styling
//

import SwiftUI

/// Mock recent proposal model for Dashboard
struct RecentInvitation: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let completedDate: Date
    let participants: Int
    let location: String?
}

/// Recent Proposals card - Last 2 completed
struct RecentInvitationsCard: View {
    let invitations: [RecentInvitation]
    let onSelectInvitation: (RecentInvitation) -> Void
    @Binding var isExpanded: Bool

    private var displayedInvitations: [RecentInvitation] {
        isExpanded ? invitations : Array(invitations.prefix(2))
    }

    private var dateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }

    var body: some View {
        KairosAuth.ParallaxStack(intensity: KairosAuth.Motion.cardIntensity) {
            DashboardCard {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.large) {
                    // Header
                    HStack(spacing: KairosAuth.Spacing.medium) {
                        KairosAuth.ParallaxStack(intensity: KairosAuth.Motion.iconIntensity) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: KairosAuth.IconSize.heroIcon))
                                .foregroundColor(KairosAuth.Color.accent)
                                .accessibilityHidden(true)
                        }

                        VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                            Text("Recent Invitations")
                                .font(KairosAuth.Typography.cardTitle)
                                .foregroundColor(KairosAuth.Color.primaryText)

                            Text("Your latest activity")
                                .font(KairosAuth.Typography.cardSubtitle)
                                .foregroundColor(KairosAuth.Color.secondaryText)
                        }

                        Spacer()

                        // Collapse/Expand toggle - filled circle style matching Active Proposals
                        Button(action: { isExpanded.toggle() }) {
                            Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                .font(.system(size: KairosAuth.IconSize.cardIcon))
                                .foregroundColor(KairosAuth.Color.accent)
                        }
                        .accessibilityLabel(isExpanded ? "Collapse recent invitations" : "Expand recent invitations")
                        .accessibilityHint(isExpanded ? "Hides the full list" : "Shows all recent invitations")
                    }

                // Invitation items (only show if expanded OR if it's default 2 items)
                if isExpanded || invitations.count <= 2 {
                    VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                        ForEach(displayedInvitations) { invitation in
                            InvitationRow(invitation: invitation, dateFormatter: dateFormatter, action: {
                                onSelectInvitation(invitation)
                            })
                        }
                    }

                    // Show More toggle (only if more than 2 invitations)
                    if invitations.count > 2 && isExpanded {
                        Button(action: { isExpanded = false }) {
                            HStack {
                                Text("Show Less")
                                    .font(KairosAuth.Typography.itemSubtitle)
                                    .foregroundColor(KairosAuth.Color.accent)

                                Image(systemName: "chevron.up")
                                    .font(KairosAuth.Typography.statusBadge)
                                    .foregroundColor(KairosAuth.Color.accent)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, KairosAuth.Spacing.small)
                        }
                    }
                }
            }
        }
        } // Close ParallaxStack
    }
}

/// Individual recent invitation row
private struct InvitationRow: View {
    let invitation: RecentInvitation
    let dateFormatter: RelativeDateTimeFormatter
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KairosAuth.Spacing.medium) {
                // Icon (muted)
                Image(systemName: invitation.icon)
                    .font(.system(size: KairosAuth.IconSize.itemIcon))
                    .foregroundColor(KairosAuth.Color.mutedText)
                    .accessibilityHidden(true)
                    .frame(width: 32, height: 32)
                    .background(
                        KairosAuth.Color.mutedBackground
                            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.small))
                    )

                // Content
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                    Text(invitation.title)
                        .font(KairosAuth.Typography.itemTitle)
                        .foregroundColor(KairosAuth.Color.secondaryText)
                        .lineLimit(1)

                    HStack(spacing: KairosAuth.Spacing.small) {
                        // Completed time
                        Text(dateFormatter.localizedString(for: invitation.completedDate, relativeTo: Date()))
                            .font(KairosAuth.Typography.timestamp)
                            .foregroundColor(KairosAuth.Color.mutedText)

                        // Location
                        if let location = invitation.location {
                            HStack(spacing: KairosAuth.Spacing.xs) {
                                Image(systemName: "location.fill")
                                    .font(KairosAuth.Typography.timestamp)
                                    .accessibilityHidden(true)
                                Text(location)
                                    .font(KairosAuth.Typography.timestamp)
                                    .lineLimit(1)
                            }
                            .foregroundColor(KairosAuth.Color.mutedText)
                        }

                        // Participants
                        HStack(spacing: KairosAuth.Spacing.xs) {
                            Image(systemName: "person.2.fill")
                                .font(KairosAuth.Typography.timestamp)
                                .accessibilityHidden(true)
                            Text("\(invitation.participants)")
                                .font(KairosAuth.Typography.timestamp)
                        }
                        .foregroundColor(KairosAuth.Color.mutedText)
                    }
                }

                Spacer()

                // Chevron (very subtle)
                Image(systemName: "chevron.right")
                    .font(KairosAuth.Typography.buttonIcon)
                    .foregroundColor(KairosAuth.Color.mutedText.opacity(0.5))
                    .accessibilityHidden(true)
            }
            .padding(KairosAuth.Spacing.medium)
            .background(
                KairosAuth.Color.mutedBackground
                    .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button))
            )
            .overlay(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                    .stroke(KairosAuth.Color.cardBorder.opacity(0.5), lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RecentInvitationsCardPreview: View {
    @State private var isExpanded = false

    let mockInvitations = [
        RecentInvitation(
            id: "1",
            title: "Coffee with Alex",
            icon: "cup.and.saucer.fill",
            completedDate: Date().addingTimeInterval(-86400), // Yesterday
            participants: 2,
            location: "Starbucks"
        ),
        RecentInvitation(
            id: "2",
            title: "Lunch with Team",
            icon: "fork.knife",
            completedDate: Date().addingTimeInterval(-172800), // 2 days ago
            participants: 5,
            location: "Chipotle"
        ),
        RecentInvitation(
            id: "3",
            title: "Gym Session",
            icon: "figure.run",
            completedDate: Date().addingTimeInterval(-259200), // 3 days ago
            participants: 2,
            location: nil
        ),
        RecentInvitation(
            id: "4",
            title: "Movie Night",
            icon: "popcorn.fill",
            completedDate: Date().addingTimeInterval(-345600), // 4 days ago
            participants: 4,
            location: "AMC Theater"
        )
    ]

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: KairosAuth.Spacing.cardSpacing) {
                    // Collapsed state
                    RecentInvitationsCard(
                        invitations: mockInvitations,
                        onSelectInvitation: { invitation in
                            print("Selected: \(invitation.title)")
                        },
                        isExpanded: $isExpanded
                    )
                }
                .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                .padding(.vertical, KairosAuth.Spacing.dashboardVertical)
            }
        }
        .background(
            KairosAuth.Color.backgroundGradient(),
            ignoresSafeAreaEdges: .all
        )
    }
}

struct RecentInvitationsCardPreview_Previews: PreviewProvider {
    static var previews: some View {
        RecentInvitationsCardPreview()
    }
}
#endif
