//
//  PastEventsListView.swift
//  KairosAmiqo
//
//  Full list view for Past Events
//  Navigated to from Dashboard card tap (horizontal slide)
//  REFACTORED: Phase 2 - Now uses GenericListView (Nov 8, 2025)
//

import SwiftUI

/// Full list view for Past Events (navigation destination)
/// Uses GenericListView for shared navigation/modal pattern
struct PastEventsListView: View {
    let events: [EventDTO]
    let onSelectEvent: (EventDTO) -> Void
    let onReschedule: (EventDTO) -> Void

    private var dateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }

    var body: some View {
        GenericListView(
            title: "Past Events",
            items: events,
            rowContent: { event, action in
                PastEventFullRow(
                    event: event,
                    dateFormatter: dateFormatter,
                    onSelect: action,
                    onReschedule: {
                        onReschedule(event)
                    }
                )
            },
            modalContent: { event, isPresented in
                PastEventDetailModal(
                    event: event,
                    onReschedule: {
                        isPresented.wrappedValue = false
                        onReschedule(event)
                    },
                    isPresented: isPresented
                )
            },
            onSelectItem: onSelectEvent
        )
    }
}

/// Full-sized past event row for list view
private struct PastEventFullRow: View {
    let event: EventDTO
    let dateFormatter: RelativeDateTimeFormatter
    let onSelect: () -> Void
    let onReschedule: () -> Void

    private var iconName: String {
        "calendar"
    }

    private var accessibilitySummary: String {
        var parts: [String] = []
        parts.append(event.title)

        if let status = event.status, !status.isEmpty {
            parts.append("Status \(status)")
        }

        if let startDate = event.startDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            parts.append("Happened \(formatter.localizedString(for: startDate, relativeTo: Date()))")
        }

        if let participantCount = event.participants?.count, participantCount > 0 {
            parts.append(participantCount == 1 ? "1 participant" : "\(participantCount) participants")
        }

        if let venueName = event.venue?.name, !venueName.isEmpty {
            parts.append("Location \(venueName)")
        }

        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 10) {
            // Main event info button
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 10) {
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
                            // Title with status badge
                            HStack(spacing: 8) {
                                Text(event.title)
                                    .font(KairosAuth.Typography.itemTitle)
                                    .foregroundColor(KairosAuth.Color.primaryText)
                                    .lineLimit(2)

                                // Status badge (if status exists)
                                if let status = event.status {
                                    Text(status.uppercased())
                                        .font(KairosAuth.Typography.statusBadge)
                                        .foregroundColor(KairosAuth.Color.buttonText)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            KairosAuth.Color.teal
                                                .clipShape(Capsule())
                                        )
                                }
                            }

                            // Date
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(KairosAuth.Typography.buttonIcon)
                                    .accessibilityHidden(true)
                                Text(event.startDate.map { dateFormatter.localizedString(for: $0, relativeTo: Date()) } ?? "Date unknown")
                                    .font(KairosAuth.Typography.itemSubtitle)
                            }
                            .foregroundColor(KairosAuth.Color.teal)

                            // Participants and Location
                            HStack(spacing: 12) {
                                // Participants
                                if let participants = event.participants, !participants.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person.2.fill")
                                            .font(KairosAuth.Typography.buttonIcon)
                                            .accessibilityHidden(true)
                                        Text("\(participants.count)")
                                            .font(KairosAuth.Typography.itemSubtitle)
                                    }
                                    .foregroundColor(KairosAuth.Color.teal)
                                }

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
            .accessibilityHint("Opens past event details")

            // Reschedule CTA (for cancelled events only)
            if event.status == "cancelled" || event.status == "declined" {
                Button(action: onReschedule) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(KairosAuth.Typography.buttonIcon)
                            .accessibilityHidden(true)
                        Text("Reschedule This Event")
                            .font(KairosAuth.Typography.buttonLabel)
                    }
                    .foregroundColor(KairosAuth.Color.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        KairosAuth.Color.accent.opacity(0.15)
                            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                            .stroke(KairosAuth.Color.accent.opacity(0.3), lineWidth: 1)
                    )
                }
                .accessibilityHint("Create a new invitation for this event")
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PastEventsListViewPreview: View {
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
            venue: nil,
            participants: nil,
            calendar_synced: nil
        )
    ]

    var body: some View {
        PastEventsListView(
            events: mockEvents,
            onSelectEvent: { event in
                print("Selected: \(event.title)")
            },
            onReschedule: { event in
                print("Reschedule: \(event.title)")
            }
        )
    }
}

struct PastEventsListViewPreview_Previews: PreviewProvider {
    static var previews: some View {
        PastEventsListViewPreview()
    }
}
#endif
