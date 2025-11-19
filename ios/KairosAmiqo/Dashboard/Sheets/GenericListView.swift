//
//  GenericListView.swift
//  KairosAmiqo
//
//  Reusable full-screen list view for dashboard navigation destinations
//  Consolidates UpcomingEventsListView, ActiveInvitationsListView, PastEventsListView
//  PHASE 2: Navigation Consolidation (Nov 8, 2025)
//

import SwiftUI

/// Generic full-screen list view with modal presentation
/// - Use for Events, Plans, or any card-based list
/// - Handles navigation toolbar, modals, blur effects automatically
struct GenericListView<Item: Identifiable, RowContent: View, ModalContent: View>: View {
    // MARK: - Required Properties
    let title: String
    let items: [Item]
    let rowContent: (Item, @escaping () -> Void) -> RowContent
    let modalContent: (Item, Binding<Bool>) -> ModalContent
    let onSelectItem: (Item) -> Void
    
    // MARK: - Modal State
    @State private var selectedItem: Item?
    @State private var isModalPresented = false
    
    var body: some View {
        ZStack {
            // Main content
            ScrollView {
                VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                    ForEach(items) { item in
                        rowContent(item) {
                            // Handle row tap
                            selectedItem = item
                            isModalPresented = true
                            onSelectItem(item)
                        }
                    }
                }
                .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                .padding(.vertical, KairosAuth.Spacing.large)
            }
            .blur(radius: isModalPresented ? 8 : 0)
            .scaleEffect(isModalPresented ? 0.95 : 1.0)
            .animation(.spring(response: 0.55, dampingFraction: 0.75), value: isModalPresented)
            
            // Dark overlay when modal presented
            if isModalPresented {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KairosAuth.Color.scrim, ignoresSafeAreaEdges: .all)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            dismissModal()
                        }
                    }
            }
            
            // Modal overlay
            if isModalPresented, let item = selectedItem {
                HeroExpansionModal(isPresented: $isModalPresented) {
                    modalContent(item, $isModalPresented)
                }
            }
        }
        .background(
            KairosAuth.Color.backgroundGradient(),
            ignoresSafeAreaEdges: .all
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(KairosAuth.Typography.screenTitle)
                    .foregroundColor(KairosAuth.Color.white)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    // TODO: Show profile sheet
                    print("Profile tapped from \(title)")
                }) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.profileButton))
                        .foregroundColor(KairosAuth.Color.accent)
                }
                .accessibilityLabel("Open profile")
                .accessibilityHint("Opens your profile options")
            }
        }
    }
    
    // MARK: - Helper Methods
    private func dismissModal() {
        isModalPresented = false
        selectedItem = nil
    }
}

// MARK: - Preview
#Preview("Upcoming Events") {
    NavigationStack {
        GenericListView(
            title: "Upcoming Events",
            items: [
                EventDTO(
                    id: UUID(),
                    title: "Team Lunch",
                    starts_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
                    ends_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7200)),
                    status: "confirmed",
                    date_created: nil,
                    date_updated: nil,
                    owner: UUID(),
                    ics_url: nil,
                    negotiation_id: nil,
                    venue: EventDTO.VenueInfo(id: UUID(), name: "The Bistro", address: "123 Main St", lat: nil, lon: nil),
                    participants: nil,
                    calendar_synced: false
                )
            ],
            rowContent: { event, action in
                Button(action: action) {
                    HStack {
                        Text(event.title)
                            .font(KairosAuth.Typography.itemTitle)
                            .foregroundColor(KairosAuth.Color.primaryText)
                        Spacer()
                    }
                    .padding()
                    .background(KairosAuth.Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card))
                }
            },
            modalContent: { event, isPresented in
                VStack {
                    Text(event.title)
                        .font(KairosAuth.Typography.cardTitle)
                    Text("Event Details")
                        .font(KairosAuth.Typography.body)
                }
                .padding()
            },
            onSelectItem: { event in
                print("Selected: \(event.title)")
            }
        )
    }
}
