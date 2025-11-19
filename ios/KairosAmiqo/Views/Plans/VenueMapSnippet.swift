//
//  VenueMapSnippet.swift
//  KairosAmiqo
//
//  Created by Copilot on 2025-10-19.
//  Phase 3 - Task 11.5: MapKit preview for venue locations
//

import SwiftUI
import MapKit

/// Compact map preview showing a single venue location
/// Used in PlanDetailModal and ProposalCard to provide visual context
///
/// Design: Uses KairosAuth design system tokens exclusively (100% compliance)
struct VenueMapSnippet: View {
    // MARK: - Properties
    
    let venue: VenueInfo
    let height: CGFloat = 120  // Fixed height for consistency
    
    @State private var region: MKCoordinateRegion
    
    // Helper struct for MapAnnotation (VenueInfo needs Identifiable)
    private struct MapVenue: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }
    
    private var mapVenue: MapVenue? {
        guard let lat = venue.lat, let lon = venue.lon else { return nil }
        return MapVenue(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }
    
    // MARK: - Initialization
    
    init(venue: VenueInfo) {
        self.venue = venue
        
        // Initialize region centered on venue
        // Use venue coordinates or default to San Francisco if missing
        let centerLat = venue.lat ?? 37.7749
        let centerLon = venue.lon ?? -122.4194
        
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: centerLat,
                longitude: centerLon
            ),
            span: MKCoordinateSpan(
                latitudeDelta: 0.01,   // ~1km zoom
                longitudeDelta: 0.01
            )
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Map view
            if let mapVenue = mapVenue {
                Map(position: .constant(.region(region))) {
                    Marker(venue.name, coordinate: mapVenue.coordinate)
                        .tint(KairosAuth.Color.teal)
                }
                .mapStyle(.standard)
                .frame(height: height)
                .disabled(true)  // Prevent interaction in snippet mode
            } else {
                // Fallback for venues without coordinates
                Rectangle()
                    .fill(KairosAuth.Color.cardBackground.opacity(0.3))
                    .frame(height: height)
                    .overlay(
                        Text("No location data")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundColor(KairosAuth.Color.tertiaryText)
                    )
            }
            
            // Venue info overlay (bottom)
            HStack(spacing: KairosAuth.Spacing.small) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: KairosAuth.IconSize.badge))
                    .foregroundColor(KairosAuth.Color.accent)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(venue.name)
                        .font(KairosAuth.Typography.itemSubtitle)
                        .foregroundColor(KairosAuth.Color.primaryText)
                        .lineLimit(1)
                    
                    if let address = venue.address, !address.isEmpty {
                        Text(address)
                            .font(KairosAuth.Typography.timestamp)
                            .foregroundColor(KairosAuth.Color.secondaryText)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Navigation hint
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: KairosAuth.IconSize.badge))
                    .foregroundColor(KairosAuth.Color.tertiaryText)
                    .accessibilityHidden(true)
            }
            .padding(KairosAuth.Spacing.small)
            .background(
                KairosAuth.Color.cardBackground
                    .opacity(0.95)  // Semi-transparent overlay
            )
            .accessibilityElement(children: .combine)
        }
        .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Interactive Map View (Full Screen)

/// Full-screen interactive map for venue navigation
/// Can be presented as a sheet from VenueMapSnippet tap
struct VenueMapFullView: View {
    let venue: VenueInfo
    @Environment(\.dismiss) private var dismiss
    
    @State private var region: MKCoordinateRegion
    
    // Helper struct for MapAnnotation
    private struct MapVenue: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }
    
    private var mapVenue: MapVenue? {
        guard let lat = venue.lat, let lon = venue.lon else { return nil }
        return MapVenue(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }
    
    init(venue: VenueInfo) {
        self.venue = venue
        let centerLat = venue.lat ?? 37.7749
        let centerLon = venue.lon ?? -122.4194
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: centerLat,
                longitude: centerLon
            ),
            span: MKCoordinateSpan(
                latitudeDelta: 0.01,
                longitudeDelta: 0.01
            )
        ))
    }
    
    var body: some View {
        NavigationView {
            if let mapVenue = mapVenue {
                Map(position: .constant(.region(region))) {
                    Marker(venue.name, coordinate: mapVenue.coordinate)
                        .tint(KairosAuth.Color.teal)
                }
                .mapStyle(.standard)
                .navigationTitle(venue.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: KairosAuth.IconSize.close))
                                .foregroundColor(KairosAuth.Color.tertiaryText)
                                .accessibilityHidden(true)
                        }
                        .accessibilityLabel("Close")
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: openInMaps) {
                            HStack(spacing: KairosAuth.Spacing.small) {
                                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                    .font(.system(size: KairosAuth.IconSize.badge))
                                    .accessibilityHidden(true)
                                Text("Navigate")
                                    .font(KairosAuth.Typography.buttonLabel)
                            }
                            .foregroundColor(KairosAuth.Color.accent)
                        }
                        .accessibilityLabel("Navigate in Maps")
                        .accessibilityHint("Opens this venue in Apple Maps")
                    }
                }
            } else {
                // Fallback for venues without coordinates
                Text("No location available")
                    .font(KairosAuth.Typography.itemSubtitle)
                    .foregroundColor(KairosAuth.Color.tertiaryText)
                    .navigationTitle(venue.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: KairosAuth.IconSize.close))
                                    .foregroundColor(KairosAuth.Color.tertiaryText)
                                    .accessibilityHidden(true)
                            }
                            .accessibilityLabel("Close")
                        }
                    }
            }
        }
    }
    
    /// Open venue in Apple Maps for navigation
    private func openInMaps() {
        guard let lat = venue.lat, let lon = venue.lon else { return }
        let coordinate = CLLocationCoordinate2D(
            latitude: lat,
            longitude: lon
        )
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = venue.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// MARK: - Preview

#if DEBUG
struct VenueMapSnippet_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: KairosAuth.Spacing.medium) {
            // Snippet view
            VenueMapSnippet(
                venue: VenueInfo(
                    id: UUID(),
                    name: "Cafe Verona",
                    lat: 37.7749,
                    lon: -122.4194,
                    address: "123 Main St, San Francisco, CA",
                    category: "cafe",
                    price_band: 2
                )
            )
            
            // Different venue
            VenueMapSnippet(
                venue: VenueInfo(
                    id: UUID(),
                    name: "Blue Moon Coffee",
                    lat: 37.8044,
                    lon: -122.2712,
                    address: "456 Oak Ave, Oakland, CA",
                    category: "cafe",
                    price_band: 1
                )
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
