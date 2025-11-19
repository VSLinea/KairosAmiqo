//
//  ActiveInvitationsCard.swift
//  KairosAmiqo
//
//  Hero card for returning users
//  Shows active invitations with actions
//

import SwiftUI

/// Hero card for returning users - Active Invitations
/// Now uses real Negotiation data from Directus
struct ActiveInvitationsCard: View {
    let invitations: [Negotiation]
    let onSelectInvitation: (Negotiation) -> Void
    let onCreateNew: () -> Void
    let onTapBackground: () -> Void
    @Binding var isExpanded: Bool

    private var displayedInvitations: [Negotiation] {
        isExpanded ? Array(invitations.prefix(5)) : Array(invitations.prefix(2))
    }

    private var invitationCountText: String {
        invitations.count == 1 ? "1 invite in progress" : "\(invitations.count) invites in progress"
    }

    var body: some View {
        KairosAuth.ParallaxStack(intensity: KairosAuth.Motion.cardIntensity) {
            DashboardCard {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.large) {
                    // Header
                    HStack(spacing: KairosAuth.Spacing.medium) {
                        KairosAuth.ParallaxStack(intensity: KairosAuth.Motion.iconIntensity) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: KairosAuth.IconSize.heroIcon))
                                .foregroundColor(KairosAuth.Color.accent)
                                .accessibilityHidden(true)
                        }

                        VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                            Text("Active Invites")
                                .font(KairosAuth.Typography.cardTitle)
                                .foregroundColor(KairosAuth.Color.primaryText)

                            Text(invitationCountText)
                                .font(KairosAuth.Typography.cardSubtitle)
                                .foregroundColor(KairosAuth.Color.secondaryText)
                        }

                        Spacer()

                        // View All button
                        Button(action: onTapBackground) {
                            Text("View All")
                                .font(KairosAuth.Typography.itemSubtitle)
                                .foregroundColor(KairosAuth.Color.accent)
                        }
                    }

                    // Invitation items
                    VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                        ForEach(displayedInvitations) { invitation in
                            InvitationRow(invitation: invitation) {
                                onSelectInvitation(invitation)
                            }
                        }
                    }

                    // Show More / Show Less toggle
                    if invitations.count > 2 {
                        Button(action: { isExpanded.toggle() }) {
                            HStack {
                                let remainingCount = min(invitations.count - 2, 3) // Max 3 more items (5 total - 2 shown)
                                Text(isExpanded ? "Show Less" : "Show \(remainingCount) More")
                                    .font(KairosAuth.Typography.itemSubtitle)
                                    .foregroundColor(KairosAuth.Color.accent)

                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(KairosAuth.Typography.statusBadge)
                                    .foregroundColor(KairosAuth.Color.accent)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, KairosAuth.Spacing.small)
                        }
                        .accessibilityLabel(isExpanded ? "Show fewer invitations" : "Show more invitations")
                        .accessibilityHint("Adjusts how many active invitations are visible in the dashboard card.")
                        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                    }
                }
            }
        } // Close ParallaxStack
    }
}

/// Individual invitation row - uses real Negotiation data
private struct InvitationRow: View {
    let invitation: Negotiation
    let action: () -> Void

    private var invitationIcon: String {
        // Map intent_category to icon, or default to calendar
        switch invitation.intent_category?.lowercased() {
        case "coffee": return "cup.and.saucer.fill"
        case "lunch", "dinner", "brunch": return "fork.knife"
        case "drinks": return "wineglass.fill"
        case "gym", "workout": return "figure.run"
        case "walk": return "figure.walk"
        case "movie": return "popcorn.fill"
        case "concert", "music": return "music.note"
        case "study": return "book.fill"
        case "game": return "gamecontroller.fill"
        default: return "calendar"
        }
    }

    private var participantCount: Int {
        invitation.participants?.count ?? 0
    }

    private var statusText: String {
        switch invitation.status?.lowercased() {
        case "active", "started":
            return "Active"
        case "pending":
            return "Pending"
        case "confirmed":
            return "Confirmed"
        case "countered":
            return "Countered"
        default:
            return "Inviting"
        }
    }
    
    private var statusIcon: String {
        switch invitation.status?.lowercased() {
        case "active", "started": return "arrow.triangle.2.circlepath"
        case "pending": return "clock.fill"
        case "confirmed": return "checkmark.circle.fill"
        case "countered": return "arrow.left.arrow.right"
        default: return "ellipsis.circle"
        }
    }
    
    // MARK: - Countdown Logic
    
    private var countdownText: String? {
        guard let expiresAtString = invitation.expires_at else { return nil }
        
        // Parse ISO8601 timestamp
        let isoFormatter = ISO8601DateFormatter()
        guard let expiryDate = isoFormatter.date(from: expiresAtString) else { return nil }
        
        let now = Date()
        let timeInterval = expiryDate.timeIntervalSince(now)
        
        // Already expired
        if timeInterval <= 0 { return nil }
        
        let hours = Int(timeInterval / 3600)
        
        // Less than 1 hour
        if hours < 1 {
            return "<1h"
        }
        
        // Hour precision (e.g., "2h", "5h")
        return "\(hours)h"
    }
    
    private var isCountdownUrgent: Bool {
        guard let expiresAtString = invitation.expires_at else { return false }
        
        let isoFormatter = ISO8601DateFormatter()
        guard let expiryDate = isoFormatter.date(from: expiresAtString) else { return false }
        
        let timeInterval = expiryDate.timeIntervalSince(Date())
        let hours = timeInterval / 3600
        
        return hours < 1 && hours > 0 // Red badge when <1 hour remaining
    }

    private var invitationTitle: String {
        invitation.title ?? "Untitled Invitation"
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: KairosAuth.Spacing.medium) {
                    // Icon - standardized teal color for all invitations
                    Image(systemName: invitationIcon)
                        .font(.system(size: KairosAuth.IconSize.itemIcon))
                        .foregroundColor(KairosAuth.Color.accent)
                        .frame(width: 32, height: 32)
                        .background(
                            KairosAuth.Color.teal.opacity(0.15)
                                .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.small))
                        )
                        .accessibilityHidden(true)

                // Content
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                    Text(invitationTitle)
                        .font(KairosAuth.Typography.itemTitle)
                        .foregroundColor(KairosAuth.Color.primaryText)
                        .lineLimit(1)

                    HStack(spacing: KairosAuth.Spacing.small) {
                        // Participants badge
                        if participantCount > 0 {
                            HStack(spacing: KairosAuth.Spacing.xs) {
                                Image(systemName: "person.2.fill")
                                    .font(KairosAuth.Typography.statusBadge)
                                    .accessibilityHidden(true)
                                Text("\(participantCount)")
                                    .font(KairosAuth.Typography.statusBadge)
                            }
                            .foregroundColor(KairosAuth.Color.accent)
                        }

                        // Status badge
                        Text(statusText)
                            .font(KairosAuth.Typography.statusBadge)
                            .foregroundColor(KairosAuth.Color.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                KairosAuth.Color.teal.opacity(0.2)
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
                .padding(KairosAuth.Spacing.medium)
                
                // Countdown badge (top-right overlay)
                if let countdown = countdownText {
                    Text(countdown)
                        .font(KairosAuth.Typography.statusBadge)
                        .fontWeight(.semibold)
                        .foregroundColor(KairosAuth.Color.buttonText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Circle()
                                .fill(isCountdownUrgent ? KairosAuth.Color.statusDeclined : KairosAuth.Color.teal)
                        )
                        .offset(x: -8, y: 8) // Position in top-right corner
                }
            }
            .padding(KairosAuth.Spacing.medium)
            .background(
                KairosAuth.Color.itemBackground
                    .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.item))
            )
            .overlay(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.item)
                    .stroke(KairosAuth.Color.cardBorder.opacity(0.5), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.item)
                    .stroke(
                        LinearGradient(
                            colors: [
                                KairosAuth.Color.white.opacity(0.08),  // Subtle top rim (Level 2)
                                KairosAuth.Color.white.opacity(0.04),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: KairosAuth.Shadow.itemColor,
                radius: KairosAuth.Shadow.itemRadius,
                y: KairosAuth.Shadow.itemY
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(invitation.title ?? "Untitled invite"). \(participantCount) participants. Status: \(statusText)")
        .accessibilityHint("Double tap to view details.")
    }
}

// MARK: - Preview

#if DEBUG
struct ActiveInvitationsCardPreview: View {
    @State private var isExpanded = false

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
            proposed_slots: nil
        ),
        Negotiation(
            id: UUID(),
            title: "Team Lunch",
            status: "pending",
            intent_category: "lunch",
            participants: [
                PlanParticipant(user_id: UUID(), name: "You", status: "accepted")
            ],
            proposed_slots: nil
        ),
        Negotiation(
            id: UUID(),
            title: "Gym Session",
            status: "confirmed",
            intent_category: "gym",
            participants: [
                PlanParticipant(user_id: UUID(), name: "You", status: "accepted")
            ],
            proposed_slots: nil
        )
    ]

    var body: some View {
        ZStack {
            ScrollView {
                ActiveInvitationsCard(
                    invitations: mockInvitations,
                    onSelectInvitation: { invitation in
                            let title = invitation.title ?? "Unknown"
                            print("Selected: \(title)")
                    },
                    onCreateNew: {
                        print("Create new invitation")
                    },
                    onTapBackground: {
                        print("Tapped background - show full list")
                    },
                    isExpanded: $isExpanded
                )
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

struct ActiveInvitationsCardPreview_Previews: PreviewProvider {
    static var previews: some View {
        ActiveInvitationsCardPreview()
    }
}
#endif
