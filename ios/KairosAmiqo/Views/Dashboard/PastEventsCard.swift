//
//  PastEventsCard.swift
//  KairosAmiqo
//
//  Past Events card for Dashboard
//  Shows events from last 7 days with status differentiation
//  Supports re-engagement for declined/cancelled events
//

import SwiftUI

/// Past Events card - Last 7 days
/// Now uses real EventDTO data from mock server
struct PastEventsCard: View {
    let events: [EventDTO]
    let onSelectEvent: (EventDTO) -> Void
    let onReschedule: (EventDTO) -> Void
    let onTapBackground: () -> Void
    @Binding var isExpanded: Bool

    private var displayedEvents: [EventDTO] {
        isExpanded ? Array(events.prefix(5)) : Array(events.prefix(2))
    }

    // Count completed vs cancelled
    private var completedCount: Int {
        events.filter { event in
            let status = event.status?.lowercased() ?? ""
            return status == "confirmed" || status == "completed"
        }.count
    }

    private var cancelledCount: Int {
        events.filter { event in
            event.status?.lowercased() == "cancelled"
        }.count
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
                            Text("Past Events")
                                .font(KairosAuth.Typography.cardTitle)
                                .foregroundColor(KairosAuth.Color.white)

                            // Dynamic subtitle with counts
                            if events.isEmpty {
                                Text("Last 7 days")
                                    .font(KairosAuth.Typography.cardSubtitle)
                                    .foregroundColor(KairosAuth.Color.secondaryText)
                            } else if cancelledCount == 0 {
                                Text("Last 7 days • \(completedCount) completed")
                                    .font(KairosAuth.Typography.cardSubtitle)
                                    .foregroundColor(KairosAuth.Color.secondaryText)
                            } else {
                                Text("Last 7 days • \(completedCount) completed, \(cancelledCount) cancelled")
                                    .font(KairosAuth.Typography.cardSubtitle)
                                    .foregroundColor(KairosAuth.Color.secondaryText)
                            }
                        }

                        Spacer()

                        // View All button
                        Button(action: onTapBackground) {
                            Text("View All")
                                .font(KairosAuth.Typography.itemSubtitle)
                                .foregroundColor(KairosAuth.Color.accent)
                        }
                    }

                    // Event items
                    if events.isEmpty {
                    // Empty state - Encouraging CTA
                    VStack(spacing: KairosAuth.Spacing.medium) {
                        Image(systemName: "sparkles")
                            .font(.system(size: KairosAuth.IconSize.cardIcon))
                            .foregroundColor(KairosAuth.Color.accent)
                            .accessibilityHidden(true)

                        VStack(spacing: KairosAuth.Spacing.xs) {
                            Text("No past events yet")
                                .font(KairosAuth.Typography.itemTitle)
                                .foregroundColor(KairosAuth.Color.primaryText)

                            Text("Your event history will appear here")
                                .font(KairosAuth.Typography.itemSubtitle)
                                .foregroundColor(KairosAuth.Color.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KairosAuth.Spacing.extraLarge)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No past events yet. Your event history will appear here once invitations are complete.")
                    .accessibilityHint("Double tap to open the past events list.")
                    .onTapGesture {
                        // Empty state tap = background tap (open full list)
                        onTapBackground()
                    }
                } else {
                    VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                        ForEach(displayedEvents) { event in
                            EventRow(
                                event: event,
                                dateFormatter: dateFormatter,
                                onSelect: {
                                    onSelectEvent(event)
                                },
                                onReschedule: { onReschedule(event) }
                            )
                        }
                    }

                    // Show More/Less toggle
                    if events.count > 2 {
                        Button(action: { isExpanded.toggle() }) {
                            HStack {
                                let remainingCount = min(events.count - 2, 3) // Max 3 more items (5 total - 2 shown)
                                Text(isExpanded ? "Show Less" : "Show \(remainingCount) More")
                                    .font(KairosAuth.Typography.itemSubtitle)
                                    .foregroundColor(KairosAuth.Color.accent)

                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: KairosAuth.IconSize.badge))
                                    .foregroundColor(KairosAuth.Color.accent)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, KairosAuth.Spacing.small)
                        }
                        .accessibilityLabel(isExpanded ? "Show fewer past events" : "Show more past events")
                        .accessibilityHint("Adjusts how many past events are visible in the dashboard card.")
                        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                    }
                }
            }
        }
        } // Close ParallaxStack
    }
}

/// Individual past event row with status differentiation
private struct EventRow: View {
    let event: EventDTO
    let dateFormatter: RelativeDateTimeFormatter
    let onSelect: () -> Void
    let onReschedule: () -> Void

    private var eventIcon: String {
        "calendar"
    }

    private var isCancelled: Bool {
        event.status?.lowercased() == "cancelled"
    }

    private var opacity: Double {
        isCancelled ? 0.6 : 1.0
    }

    private var statusBadge: String? {
        isCancelled ? "Cancelled" : nil
    }

    private var badgeColor: Color {
        isCancelled ? KairosAuth.Color.statusDeclined : KairosAuth.Color.statusConfirmed
    }

    private var showRescheduleAction: Bool {
        isCancelled
    }

    var body: some View {
        VStack(spacing: KairosAuth.Spacing.small) {
            // Main event info button
            Button(action: onSelect) {
                HStack(spacing: KairosAuth.Spacing.medium) {
                    // Icon
                    Image(systemName: eventIcon)
                        .font(.system(size: KairosAuth.IconSize.itemIcon))
                        .foregroundColor(KairosAuth.Color.accent)
                        .accessibilityHidden(true)
                        .frame(width: 32, height: 32)
                        .background(
                            KairosAuth.Color.teal.opacity(0.15)
                                .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.small))
                        )
                        .opacity(opacity)

                    // Content
                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                        // Title with status badge
                        HStack(spacing: KairosAuth.Spacing.small) {
                            Text(event.title)
                                .font(KairosAuth.Typography.itemTitle)
                                .foregroundColor(KairosAuth.Color.white)
                                .lineLimit(1)

                            // Status badge (if applicable)
                            if let badge = statusBadge {
                                Text(badge)
                                    .font(KairosAuth.Typography.statusBadge)
                                    .foregroundColor(KairosAuth.Color.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        badgeColor
                                            .clipShape(Capsule())
                                    )
                            }
                        }
                        .opacity(opacity)

                        // Metadata row
                        HStack(spacing: KairosAuth.Spacing.small) {
                            // Date
                            if let startDate = event.startDate {
                                Text(dateFormatter.localizedString(for: startDate, relativeTo: Date()))
                                    .font(KairosAuth.Typography.statusBadge)
                                    .foregroundColor(KairosAuth.Color.accent)
                            }

                            // Location
                            if let location = event.venue?.name {
                                HStack(spacing: KairosAuth.Spacing.xs) {
                                    Image(systemName: "location.fill")
                                        .font(KairosAuth.Typography.statusBadge)
                                        .accessibilityHidden(true)
                                    Text(location)
                                        .font(KairosAuth.Typography.statusBadge)
                                        .lineLimit(1)
                                }
                                .foregroundColor(KairosAuth.Color.accent)
                            }

                            // Participants
                            if let participantCount = event.participants?.count, participantCount > 0 {
                                HStack(spacing: KairosAuth.Spacing.xs) {
                                    Image(systemName: "person.2.fill")
                                        .font(KairosAuth.Typography.statusBadge)
                                        .accessibilityHidden(true)
                                    Text("\(participantCount)")
                                        .font(KairosAuth.Typography.statusBadge)
                                }
                                .foregroundColor(KairosAuth.Color.accent)
                            }
                        }
                        .opacity(opacity)
                    }

                    Spacer()

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(KairosAuth.Typography.buttonIcon)
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                        .opacity(opacity)
                        .accessibilityHidden(true)
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
                                    Color.white.opacity(0.08),  // Subtle top rim (Level 2)
                                    Color.white.opacity(0.04),
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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint("Double tap to view event details.")
            }

            // Reschedule CTA (for cancelled events)
            if showRescheduleAction {
                Button(action: onReschedule) {
                    HStack(spacing: KairosAuth.Spacing.small) {
                        Image(systemName: "arrow.clockwise")
                            .font(KairosAuth.Typography.buttonIcon)
                            .accessibilityHidden(true)
                        Text("Reschedule")
                            .font(KairosAuth.Typography.buttonIcon)
                    }
                    .foregroundColor(KairosAuth.Color.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        KairosAuth.Color.accent.opacity(0.15)
                            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.small))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.small)
                            .stroke(KairosAuth.Color.accent.opacity(0.3), lineWidth: 1)
                    )
                }
                .accessibilityLabel("Reschedule this event")
                .accessibilityHint("Creates a new invitation to revisit the cancelled plan.")
            }
        }
    }

    private var accessibilityLabel: String {
        var components: [String] = [event.title]

        if let startDate = event.startDate {
            let relative = dateFormatter.localizedString(for: startDate, relativeTo: Date())
            components.append(relative)
        }

        if let location = event.venue?.name {
            components.append("Location: \(location)")
        }

        if let participantCount = event.participants?.count, participantCount > 0 {
            components.append("\(participantCount) participants")
        }

        if let status = event.status?.capitalized {
            components.append("Status: \(status)")
        }

        return components.joined(separator: ". ")
    }
}

// MARK: - Preview

#if DEBUG
struct PastEventsCardPreview: View {
    @State private var isExpanded = false

    let mockEvents = [
        EventDTO(
            id: UUID(),
            title: "Coffee with Sarah",
            starts_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400)),
            ends_at: nil,
            status: "confirmed",
            date_created: nil,
            date_updated: nil,
            owner: nil,
            ics_url: nil,
            negotiation_id: nil,
            venue: EventDTO.VenueInfo(id: UUID(), name: "Blue Bottle", address: "", lat: nil, lon: nil),
            participants: nil,
            calendar_synced: nil
        ),
        EventDTO(
            id: UUID(),
            title: "Team Lunch",
            starts_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-172800)),
            ends_at: nil,
            status: "cancelled",
            date_created: nil,
            date_updated: nil,
            owner: nil,
            ics_url: nil,
            negotiation_id: nil,
            venue: EventDTO.VenueInfo(id: UUID(), name: "Chipotle", address: "", lat: nil, lon: nil),
            participants: nil,
            calendar_synced: nil
        ),
        EventDTO(
            id: UUID(),
            title: "Movie Night",
            starts_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-259200)),
            ends_at: nil,
            status: "cancelled",
            date_created: nil,
            date_updated: nil,
            owner: nil,
            ics_url: nil,
            negotiation_id: nil,
            venue: nil,
            participants: nil,
            calendar_synced: nil
        )
    ]

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: KairosAuth.Spacing.cardSpacing) {
                    PastEventsCard(
                        events: mockEvents,
                        onSelectEvent: { event in
                            print("Selected: \(event.title)")
                        },
                        onReschedule: { event in
                            print("Reschedule: \(event.title)")
                        },
                        onTapBackground: {
                            print("Tapped background - show full list")
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

struct PastEventsCardPreview_Previews: PreviewProvider {
    static var previews: some View {
        PastEventsCardPreview()
    }
}
#endif
