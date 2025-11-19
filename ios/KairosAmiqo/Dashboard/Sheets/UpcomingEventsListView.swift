//
//  UpcomingEventsListView.swift
//  KairosAmiqo
//
//  Full list view for Upcoming Events
//  Navigated to from Dashboard card tap (horizontal slide)
//  REFACTORED: Phase 2 - Now uses GenericListView (Nov 8, 2025)
//

import SwiftUI

/// Full list view for Upcoming Events (navigation destination)
/// Uses GenericListView for shared navigation/modal pattern
struct UpcomingEventsListView: View {
    let events: [EventDTO]
    let onSelectEvent: (EventDTO) -> Void

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }

    var body: some View {
        GenericListView(
            title: "Upcoming Events",
            items: events,
            rowContent: { event, action in
                UpcomingEventFullRow(
                    event: event,
                    dateFormatter: dateFormatter,
                    action: action
                )
            },
            modalContent: { event, isPresented in
                EventDetailModal(
                    event: event,
                    isPresented: isPresented,
                    onAddToCalendar: {
                        // TODO: Add to calendar
                    },
                    onNavigate: {
                        // TODO: Open Maps
                    },
                    onShare: {
                        // TODO: Share sheet
                    }
                )
            },
            onSelectItem: onSelectEvent
        )
    }
}

/// Full-sized event row for list view
private struct UpcomingEventFullRow: View {
    let event: EventDTO
    let dateFormatter: DateFormatter
    let action: () -> Void

    private var iconName: String {
        // Simple default icon for events
        "calendar"
    }

    private var accessibilitySummary: String {
        var parts: [String] = []
        parts.append(event.title)

        if let startDate = event.startDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            parts.append("Starts \(formatter.string(from: startDate))")
        }

        let participantCount = event.participants?.count ?? 0
        if participantCount > 0 {
            let participantSummary = participantCount == 1 ? "1 participant" : "\(participantCount) participants"
            parts.append(participantSummary)
        }

        if let venueName = event.venue?.name, venueName.isEmpty == false {
            parts.append("Location \(venueName)")
        }

        return parts.joined(separator: ", ")
    }

    var body: some View {
        Button(action: action) {
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
                    Text(event.title)
                        .font(KairosAuth.Typography.itemTitle)
                        .foregroundColor(KairosAuth.Color.primaryText)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        // Date badge
                        if let startDate = event.startDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(KairosAuth.Typography.buttonIcon)
                                    .accessibilityHidden(true)
                                Text(dateFormatter.string(from: startDate))
                                    .font(KairosAuth.Typography.itemSubtitle)
                            }
                            .foregroundColor(KairosAuth.Color.teal)
                        }

                        // Time
                        if let startDate = event.startDate {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(KairosAuth.Typography.buttonIcon)
                                    .accessibilityHidden(true)
                                Text(formatTime(startDate))
                                    .font(KairosAuth.Typography.itemSubtitle)
                            }
                            .foregroundColor(KairosAuth.Color.teal)
                        }
                    }

                    // Participants and Location
                    HStack(spacing: 12) {
                        // Participants
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(KairosAuth.Typography.buttonIcon)
                                .accessibilityHidden(true)
                            Text("\(event.participants?.count ?? 0)")
                                .font(KairosAuth.Typography.itemSubtitle)
                        }
                        .foregroundColor(KairosAuth.Color.teal)

                        // Location
                        if let venueName = event.venue?.name {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(KairosAuth.Typography.buttonIcon)
                                    .accessibilityHidden(true)
                                Text(venueName)
                                    .font(KairosAuth.Typography.itemSubtitle)
                                    .lineLimit(1)
                            }
                            .foregroundColor(KairosAuth.Color.teal)
                        }
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(KairosAuth.Typography.buttonIcon)
                    .foregroundColor(KairosAuth.Color.tertiaryText)
                    .accessibilityHidden(true)
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
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Opens event details")
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#if DEBUG
struct UpcomingEventsListViewPreview: View {
    let mockEvents = [
        EventDTO(
            id: UUID(),
            title: "Coffee with Sarah",
            starts_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400)),
            ends_at: nil,
            status: "confirmed",
            date_created: nil,
            date_updated: nil,
            owner: UUID(),
            ics_url: nil,
            negotiation_id: nil,
            venue: EventDTO.VenueInfo(id: UUID(), name: "Blue Bottle", address: "123 Main St", lat: nil, lon: nil),
            participants: [
                EventDTO.ParticipantInfo(user_id: UUID(), name: "You"),
                EventDTO.ParticipantInfo(user_id: UUID(), name: "Sarah")
            ],
            calendar_synced: true
        ),
        EventDTO(
            id: UUID(),
            title: "Team Lunch",
            starts_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(172800)),
            ends_at: nil,
            status: "confirmed",
            date_created: nil,
            date_updated: nil,
            owner: UUID(),
            ics_url: nil,
            negotiation_id: nil,
            venue: EventDTO.VenueInfo(id: UUID(), name: "Chipotle", address: "456 Oak Ave", lat: nil, lon: nil),
            participants: nil,
            calendar_synced: false
        )
    ]

    var body: some View {
        UpcomingEventsListView(
            events: mockEvents,
            onSelectEvent: { event in
                print("Selected: \(event.title)")
            }
        )
    }
}

struct UpcomingEventsListViewPreview_Previews: PreviewProvider {
    static var previews: some View {
        UpcomingEventsListViewPreview()
    }
}
#endif
