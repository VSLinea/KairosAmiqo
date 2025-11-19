//
//  PlanConfirmedSheet.swift
//  KairosAmiqo
//
//  Created by Copilot on 2025-10-19.
//  Phase 3 - Task 14: Confirmation screen with calendar integration
//

import SwiftUI

/// Celebration sheet shown when plan is confirmed by all participants
/// Offers to add event to calendar and shows "You're all set!" message
///
/// Design: Uses KairosAuth design system tokens exclusively
struct PlanConfirmedSheet: View {
    @ObservedObject var vm: AppVM
    @Binding var isPresented: Bool
    let event: EventDTO
    
    @Environment(\.dismiss) private var dismiss
    @State private var hasAddedToCalendar = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: KairosAuth.Spacing.large) {
                    Spacer()
                    
                    // Success icon
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.successIcon))
                        .foregroundColor(KairosAuth.Color.accent)
                        .symbolEffect(.bounce, value: isPresented)
                        .accessibilityHidden(true)
                    
                    // Title
                    Text("You're all set!")
                        .font(KairosAuth.Typography.cardTitle)
                        .foregroundColor(KairosAuth.Color.primaryText)
                    
                    // Event details card
                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                        // Event title
                        Text(event.title)
                            .font(KairosAuth.Typography.itemTitle)
                            .foregroundColor(KairosAuth.Color.primaryText)
                        
                        // Time
                        HStack(spacing: KairosAuth.Spacing.small) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: KairosAuth.IconSize.itemIcon))
                                .foregroundColor(KairosAuth.Color.accent)
                                .accessibilityHidden(true)
                            
                            Text(formattedDateTime())
                                .font(KairosAuth.Typography.itemSubtitle)
                                .foregroundColor(KairosAuth.Color.secondaryText)
                        }
                        
                        // Location (if available)
                        if let venue = event.venue {
                            HStack(spacing: KairosAuth.Spacing.small) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: KairosAuth.IconSize.itemIcon))
                                    .foregroundColor(KairosAuth.Color.accent)
                                    .accessibilityHidden(true)
                                
                                Text(venue.name)
                                    .font(KairosAuth.Typography.itemSubtitle)
                                    .foregroundColor(KairosAuth.Color.secondaryText)
                            }
                        }
                    }
                    .padding(KairosAuth.Spacing.cardPadding)
                    .background(KairosAuth.Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                            .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                    )
                    
                Spacer()
                    
                    // Calendar button
                    if !hasAddedToCalendar {
                        Button(action: {
                            Task {
                                // Clear previous error before retrying
                                vm.calendarError = nil
                                await vm.addEventToCalendar(event)
                                // Only mark as added if no error occurred
                                if vm.calendarError == nil {
                                    hasAddedToCalendar = true
                                }
                            }
                        }) {
                            HStack(spacing: KairosAuth.Spacing.small) {
                                if vm.isAddingToCalendar {
                                    ProgressView()
                                        .tint(KairosAuth.Color.buttonText)
                                } else {
                                    Image(systemName: "calendar.badge.plus")
                                        .font(.system(size: KairosAuth.IconSize.button))
                                        .accessibilityHidden(true)
                                    Text("Add to Calendar")
                                        .font(KairosAuth.Typography.buttonLabel)
                                }
                            }
                            .foregroundColor(KairosAuth.Color.buttonText)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .padding(.vertical, KairosAuth.Spacing.buttonVertical)
                            .background(KairosAuth.Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button))
                        }
                        .accessibilityLabel("Add this event to your calendar")
                        .disabled(vm.isAddingToCalendar)
                    } else {
                        // Success state
                        HStack(spacing: KairosAuth.Spacing.small) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: KairosAuth.IconSize.button))
                                .accessibilityHidden(true)
                            Text("Added to calendar")
                                .font(KairosAuth.Typography.buttonLabel)
                        }
                        .foregroundColor(KairosAuth.Color.accent)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .padding(.vertical, KairosAuth.Spacing.buttonVertical)
                        .background(KairosAuth.Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button))
                        .accessibilityLabel("Event added to your calendar")
                    }
                    
                    // Error message (if any)
                    if let error = vm.calendarError {
                        VStack(spacing: KairosAuth.Spacing.small) {
                            Text(error)
                                .font(KairosAuth.Typography.itemSubtitle)
                                .foregroundColor(KairosAuth.Color.error)
                                .multilineTextAlignment(.center)
                            
                            // "Open Settings" button if permission denied
                            if error.contains("Settings") {
                                Button(action: {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Text("Open Settings")
                                        .font(KairosAuth.Typography.buttonLabel)
                                        .foregroundColor(KairosAuth.Color.accent)
                                }
                            }
                        }
                    }
                    
                    // Done button
                    Button(action: {
                        closeSheetAndNavigate()
                    }) {
                        Text("Done")
                            .font(KairosAuth.Typography.buttonLabel)
                            .foregroundColor(KairosAuth.Color.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .padding(.vertical, KairosAuth.Spacing.buttonVertical)
                            .background(KairosAuth.Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button))
                    }
                    .padding(KairosAuth.Spacing.horizontalPadding)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: closeSheet) {
                        Image(systemName: "xmark")
                            .font(.system(size: KairosAuth.IconSize.close))
                            .foregroundColor(KairosAuth.Color.tertiaryText)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Close")
                    .accessibilityHint("Dismisses confirmation details")
                }
            }
        }
        .background(KairosAuth.Color.backgroundGradient(), ignoresSafeAreaEdges: .all)
    }
    
    // MARK: - Helpers
    private func closeSheet() {
        withAnimation(KairosAuth.Animation.modalDismiss) {
            isPresented = false
        }
        dismiss()
    }

    private func closeSheetAndNavigate() {
        closeSheet()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            vm.primaryTab = .events
            // TODO: Show toast message "Event added to your calendar"
        }
    }
    
    /// Format event date/time for display (auto-localized)
    ///
    /// **Output examples:**
    /// - US: "Friday, October 17 at 10:30 AM"
    /// - EU: "vendredi 17 octobre à 10:30"
    ///
    /// **Apple Docs:** Uses Date.FormatStyle for automatic localization
    /// - Ref: https://developer.apple.com/documentation/foundation/date/formatstyle
    private func formattedDateTime() -> String {
        guard let startsAt = event.starts_at else {
            return "Time TBD"
        }
        
        guard let startDate = DateFormatting.parseISO8601(startsAt) else {
            return startsAt
        }
        
        return DateFormatting.formatConfirmationDateTime(startDate)
    }
}

// MARK: - Preview

#if DEBUG
struct PlanConfirmedSheet_Previews: PreviewProvider {
    static var previews: some View {
        PlanConfirmedSheet(
            vm: AppVM(),
            isPresented: .constant(true),
            event: EventDTO(
                id: UUID(),
                title: "Coffee with Sarah",
                starts_at: "2025-10-20T14:00:00Z",
                ends_at: "2025-10-20T15:00:00Z",
                status: "confirmed",
                date_created: nil,
                date_updated: nil,
                owner: UUID(),
                ics_url: nil,
                negotiation_id: UUID(),
                venue: EventDTO.VenueInfo(
                    id: UUID(),
                    name: "Blue Bottle Coffee",
                    address: "315 Linden St, San Francisco, CA 94102",
                    lat: 37.7749,
                    lon: -122.4194
                ),
                participants: nil,
                calendar_synced: false
            )
        )
    }
}
#endif
