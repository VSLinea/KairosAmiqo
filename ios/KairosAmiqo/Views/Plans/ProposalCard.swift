//
//  ProposalCard.swift
//  KairosAmiqo
//
//  Created by Copilot on 2025-10-19.
//  Phase 3 - Task 11.3: Proposal card component for accept/counter flows
//

import SwiftUI

/// Proposal card showing a time + venue combination with vote tracking and accept action
/// Used in PlanDetailModal to display proposed options during negotiation
///
/// Design: Uses KairosAuth design system tokens exclusively (100% compliance)
struct ProposalCard: View {
    // MARK: - Properties
    
    let slot: ProposedSlot
    let venue: VenueInfo?
    let isSelected: Bool
    let votes: [UUID]?  // User IDs who accepted this combo
    let onTap: () -> Void
    let onAccept: (() -> Void)?  // Optional: Only show accept button if provided
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
            // Time section - PRIMARY (larger, prominent)
            HStack(spacing: KairosAuth.Spacing.small) {
                Image(systemName: "clock.fill")
                    .font(.system(size: KairosAuth.IconSize.itemIcon))
                    .foregroundColor(KairosAuth.Color.accent)
                    .accessibilityHidden(true)
                
                Text(formatDateTime(slot.time))
                    .font(KairosAuth.Typography.cardSubtitle) // Larger than itemTitle
                    .fontWeight(.semibold) // Make time stand out
                    .foregroundColor(KairosAuth.Color.primaryText)
            }
            .accessibilityElement(children: .combine)
            
            // Venue section - SECONDARY (smaller, indented, subtle background)
            if let venue = venue {
                HStack(spacing: KairosAuth.Spacing.small) {
                    // Indent spacer to show hierarchy
                    Spacer()
                        .frame(width: 8)
                    
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.badge)) // Smaller icon
                        .foregroundColor(KairosAuth.Color.accent)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(venue.name)
                            .font(KairosAuth.Typography.itemSubtitle) // Smaller font
                            .foregroundColor(KairosAuth.Color.primaryText)
                        
                        if let address = venue.address, !address.isEmpty {
                            Text(address)
                                .font(KairosAuth.Typography.timestamp) // Even smaller
                                .foregroundColor(KairosAuth.Color.tertiaryText)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, KairosAuth.Spacing.small)
                .background(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.small)
                        .fill(KairosAuth.Color.teal.opacity(0.08)) // Subtle teal tint
                )
            }
            
            // Vote indicators (show who accepted this option)
            if let votes = votes, !votes.isEmpty {
                HStack(spacing: KairosAuth.Spacing.small) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.badge))
                        .foregroundColor(KairosAuth.Color.accent)
                        .accessibilityHidden(true)
                    
                    Text("\(votes.count) accepted")
                        .font(KairosAuth.Typography.statusBadge)
                        .foregroundColor(KairosAuth.Color.secondaryText)
                }
                .accessibilityElement(children: .combine)
            }
            
            // Accept button (only shown if onAccept is provided)
            if let acceptAction = onAccept {
                Button(action: acceptAction) {
                    HStack(spacing: KairosAuth.Spacing.small) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: KairosAuth.IconSize.button))
                            .accessibilityHidden(true)
                        Text("Accept This Option")
                    }
                }
                .buttonStyle(.kairosPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // Force equal width
        .padding(KairosAuth.Spacing.cardPadding)
        .background(KairosAuth.Color.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                .stroke(
                    isSelected ? KairosAuth.Color.accent : KairosAuth.Color.cardBorder,
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card))
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Helpers
    
    /// Format ISO8601 time string to user-friendly display (auto-localized)
    ///
    /// **Output examples:**
    /// - US: "Fri, Oct 17 at 10:30 AM"
    /// - EU: "ven. 17 oct. à 10:30"
    ///
    /// **Apple Docs:** Uses Date.FormatStyle for automatic localization
    /// - Ref: https://developer.apple.com/documentation/foundation/date/formatstyle
    private func formatDateTime(_ isoString: String) -> String {
        guard let date = DateFormatting.parseISO8601(isoString) else {
            return isoString
        }
        
        return DateFormatting.formatEventDateTime(date)
    }
}

// MARK: - Preview

#if DEBUG
struct ProposalCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: KairosAuth.Spacing.medium) {
            // Unselected card without votes
            ProposalCard(
                slot: ProposedSlot(
                    time: "2025-10-13T18:00:00Z",
                    venue: VenueInfo(
                        id: UUID(),
                        name: "Cafe Verona",
                        lat: 37.7749,
                        lon: -122.4194,
                        address: "123 Main St, San Francisco",
                        category: "cafe",
                        price_band: 2
                    )
                ),
                venue: VenueInfo(
                    id: UUID(),
                    name: "Cafe Verona",
                    lat: 37.7749,
                    lon: -122.4194,
                    address: "123 Main St, San Francisco",
                    category: "cafe",
                    price_band: 2
                ),
                isSelected: false,
                votes: nil,
                onTap: { print("Card tapped") },
                onAccept: { print("Accepted") }
            )
            
            // Selected card with votes
            ProposalCard(
                slot: ProposedSlot(
                    time: "2025-10-14T19:00:00Z",
                    venue: VenueInfo(
                        id: UUID(),
                        name: "Blue Moon Coffee",
                        lat: 37.775,
                        lon: -122.419,
                        address: "456 Oak Ave",
                        category: "cafe",
                        price_band: 1
                    )
                ),
                venue: VenueInfo(
                    id: UUID(),
                    name: "Blue Moon Coffee",
                    lat: 37.775,
                    lon: -122.419,
                    address: "456 Oak Ave",
                    category: "cafe",
                    price_band: 1
                ),
                isSelected: true,
                votes: [UUID(), UUID()],
                onTap: { print("Card tapped") },
                onAccept: nil  // No accept button
            )
            
            // Card without venue (time only)
            ProposalCard(
                slot: ProposedSlot(
                    time: "2025-10-15T20:00:00Z",
                    venue: nil
                ),
                venue: nil,
                isSelected: false,
                votes: [UUID()],
                onTap: { print("Card tapped") },
                onAccept: { print("Accepted") }
            )
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
