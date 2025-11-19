//
//  UpcomingEventsCard.swift
//  KairosAmiqo
//
//  Upcoming Events card for Dashboard
//  Shows next 7 days events with Coral accent
//

import SwiftUI

/// Upcoming Events card - Next 7 days
/// Now uses real EventDTO data from mock server
struct UpcomingEventsCard: View {
    let events: [EventDTO]
    let onSelectEvent: (EventDTO) -> Void
    let onTapBackground: () -> Void
    @Binding var isExpanded: Bool
    
    private var displayedEvents: [EventDTO] {
        isExpanded ? Array(events.prefix(5)) : Array(events.prefix(2))
    }
    
    var body: some View {
        KairosAuth.ParallaxStack(intensity: KairosAuth.Motion.cardIntensity) {
            DashboardCard {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.large) {
                    // Header
                    HStack(spacing: KairosAuth.Spacing.medium) {
                        // Only show header icon when there ARE events
                        if !events.isEmpty {
                            KairosAuth.ParallaxStack(intensity: KairosAuth.Motion.iconIntensity) {
                                Image(systemName: "calendar")
                                    .font(.system(size: KairosAuth.IconSize.heroIcon))
                                    .foregroundColor(KairosAuth.Color.accent)
                                    .accessibilityHidden(true)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                            Text("Upcoming Events")
                                .font(KairosAuth.Typography.cardTitle)
                                .foregroundColor(KairosAuth.Color.primaryText)
                            
                            Text("\(events.count) this week")
                                .font(KairosAuth.Typography.itemSubtitle)
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
                    
                    // Event items
                        if events.isEmpty {
                            // Empty state - Encouraging CTA
                            VStack(spacing: KairosAuth.Spacing.medium) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: KairosAuth.IconSize.cardIcon))
                                    .foregroundColor(KairosAuth.Color.accent)
                                    .accessibilityHidden(true)
                                
                                VStack(spacing: KairosAuth.Spacing.xs) {
                                    Text("No upcoming events")
                                        .font(KairosAuth.Typography.itemTitle)
                                        .foregroundColor(KairosAuth.Color.primaryText)
                                    
                                    Text("Send an invitation to get started")
                                        .font(KairosAuth.Typography.itemSubtitle)
                                        .foregroundColor(KairosAuth.Color.secondaryText)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, KairosAuth.Spacing.extraLarge)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("No upcoming events. Send an invitation to get started.")
                            .accessibilityHint("Double tap to open the full events list and create a new invitation.")
                            .onTapGesture {
                                // Empty state tap = background tap (open full list)
                                onTapBackground()
                            }
                        } else {
                            VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                                ForEach(displayedEvents) { event in
                                    EventRow(event: event, action: {
                                        onSelectEvent(event)
                                    })
                                }
                            }
                            
                            // Show More / Show Less toggle
                            if events.count > 2 {
                                Button(action: { isExpanded.toggle() }) {
                                    HStack {
                                        let remainingCount = min(events.count - 2, 3) // Max 3 more items (5 total - 2 shown)
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
                                .accessibilityLabel(isExpanded ? "Show fewer events" : "Show more events")
                                .accessibilityHint("Adjusts how many upcoming events are visible in the dashboard card.")
                                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                            }
                        }
                    } // Close main VStack
                } // Close DashboardCard
            } // Close ParallaxStack
        } // Close body
    } // Close struct UpcomingEventsCard
    
    /// Individual event row
    private struct EventRow: View {
        let event: EventDTO
        let action: () -> Void
        
        private var eventIcon: String {
            // Default to calendar icon for now
            "calendar"
        }
        
        private var participantCount: Int {
            event.participants?.count ?? 0
        }
        
        private var locationName: String? {
            event.venue?.name
        }
        
        private var isSynced: Bool {
            event.calendar_synced ?? false
        }
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: KairosAuth.Spacing.medium) {
                    // Icon
                    Image(systemName: eventIcon)
                        .font(.system(size: KairosAuth.IconSize.itemIcon))
                        .foregroundColor(KairosAuth.Color.accent)
                        .frame(width: 32, height: 32)
                        .background(
                            KairosAuth.Color.teal.opacity(0.15)
                                .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.small))
                        )
                        .accessibilityHidden(true)
                    
                    // Content
                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                        // Title
                        Text(event.title)
                            .font(KairosAuth.Typography.itemTitle)
                            .foregroundColor(KairosAuth.Color.primaryText)
                            .lineLimit(1)
                        
                        // Metadata row: Participants + Location
                        HStack(spacing: KairosAuth.Spacing.small) {
                            // Participants
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
                            
                            // Location
                            if let location = locationName {
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
                        }
                        
                        // Status row (dedicated line)
                        Text(isSynced ? "In calendar" : "Not synced")
                            .font(KairosAuth.Typography.statusBadge)
                            .foregroundColor(KairosAuth.Color.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                KairosAuth.Color.teal.opacity(0.2)
                                    .clipShape(Capsule())
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Date badge - moved to the right
                    VStack(spacing: 2) {
                        if let startDate = event.startDate {
                            Text(DateFormatting.formatDateOnly(startDate))
                                .font(KairosAuth.Typography.statusBadge)
                                .foregroundColor(KairosAuth.Color.accent)
                            
                            Text(DateFormatting.formatTimeOnly(startDate))
                                .font(KairosAuth.Typography.timestamp)
                                .foregroundColor(KairosAuth.Color.tertiaryText)
                        } else {
                            Text("TBD")
                                .font(KairosAuth.Typography.statusBadge)
                                .foregroundColor(KairosAuth.Color.tertiaryText)
                        }
                    }
                    .frame(width: 56)
                    .padding(.vertical, 10)
                    .background(
                        KairosAuth.Color.teal.opacity(0.15)
                            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.small))
                    )
                    
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(KairosAuth.Typography.buttonIcon)
                        .foregroundColor(KairosAuth.Color.tertiaryText)
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
        }

        private var accessibilityLabel: String {
            var components: [String] = [event.title]

            if let startDate = event.startDate {
                let dateText = DateFormatting.formatEventDateTime(startDate)
                components.append("Starts \(dateText)")
            }

            if participantCount > 0 {
                components.append("\(participantCount) participants")
            }

            if let location = locationName {
                components.append("Location: \(location)")
            }

            components.append(isSynced ? "In calendar" : "Not synced")

            return components.joined(separator: ". ")
        }
    }
    
    // MARK: - Preview
    
#if DEBUG
    struct UpcomingEventsCardPreview: View {
        @State private var isExpanded = false
        
        let mockEvents = [
            EventDTO(
                id: UUID(),
                title: "Coffee with Sarah",
                starts_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400)),
                ends_at: nil,
                status: "confirmed",
                date_created: nil,
                date_updated: nil,
                owner: nil,
                ics_url: nil,
                negotiation_id: nil,
                venue: EventDTO.VenueInfo(id: UUID(), name: "Blue Bottle", address: "", lat: nil, lon: nil),
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
                owner: nil,
                ics_url: nil,
                negotiation_id: nil,
                venue: EventDTO.VenueInfo(id: UUID(), name: "Chipotle", address: "", lat: nil, lon: nil),
                participants: nil,
                calendar_synced: true
            ),
            EventDTO(
                id: UUID(),
                title: "Movie Night",
                starts_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(259200)),
                ends_at: nil,
                status: "pending",
                date_created: nil,
                date_updated: nil,
                owner: nil,
                ics_url: nil,
                negotiation_id: nil,
                venue: EventDTO.VenueInfo(id: UUID(), name: "AMC Theater", address: "", lat: nil, lon: nil),
                participants: nil,
                calendar_synced: false
            )
        ]
        
        var body: some View {
            ZStack {
                ScrollView {
                    VStack(spacing: KairosAuth.Spacing.cardSpacing) {
                        UpcomingEventsCard(
                            events: mockEvents,
                            onSelectEvent: { event in
                                print("Selected: \(event.title)")
                            },
                            onTapBackground: {
                                print("Tapped background - show full list")
                            },
                            isExpanded: $isExpanded
                        )

                        // Empty state preview
                        UpcomingEventsCard(
                            events: [],
                            onSelectEvent: { _ in },
                            onTapBackground: {},
                            isExpanded: .constant(false)
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
    
    struct UpcomingEventsCardPreview_Previews: PreviewProvider {
        static var previews: some View {
            UpcomingEventsCardPreview()
        }
    }
#endif
