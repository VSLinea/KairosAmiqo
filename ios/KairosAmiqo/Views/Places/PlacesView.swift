//
//  PlacesView.swift
//  KairosAmiqo
//
//  Created by Copilot on 2025-10-25.
//  Phase 5: Places Tab - Learned locations and POI discovery
//

import SwiftUI
import CoreLocation

/// Navigation destinations for Places tab flows
enum PlacesDestination: Hashable {
    case learnedLocations
}

/// Places tab - Learned locations, favorites, and POI exploration
/// See: /docs/00-CANONICAL/core-data-model.md §poi, §poi_ratings
struct PlacesView: View {
    @ObservedObject var vm: AppVM
    var onScrollOffsetChange: ((CGFloat) -> Void)? = nil // Tab bar auto-hide callback
    @State private var selectedCategory: POICategory = .all
    @State private var searchText: String = ""
    @State private var showNearbyOnly: Bool = false
    @State private var sortByDistance: Bool = false
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ScrollView {
                    VStack(spacing: KairosAuth.Spacing.large) {
                        // Scroll tracking anchor
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .global).minY
                            )
                        }
                        .frame(height: 0)
                        
                        // Search bar at top
                        SearchBarPlaceholder(text: $searchText)
                            .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                            .padding(.top, KairosAuth.Spacing.medium)
                        
                        // Section 1: Your Places (Learned locations)
                        if !vm.learnedPlaces.isEmpty {
                            VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                                // Section header with "View All" button
                                HStack(spacing: KairosAuth.Spacing.medium) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: KairosAuth.IconSize.cardIcon))
                                            .foregroundColor(KairosAuth.Color.accent)
                                            .accessibilityHidden(true)
                                        
                                        Text("\(vm.learnedPlaces.count)")
                                            .font(KairosAuth.Typography.cardTitle)
                                            .foregroundColor(KairosAuth.Color.accent)
                                    }
                                    
                                    Text("Your Places")
                                        .font(KairosAuth.Typography.cardTitle)
                                        .foregroundColor(KairosAuth.Color.primaryText)
                                    
                                    Spacer()
                                    
                                    // "View All" button (always show to allow management)
                                    Button {
                                        navigationPath.append(PlacesDestination.learnedLocations)
                                    } label: {
                                        Text("View All")
                                            .font(KairosAuth.Typography.linkPrimary)
                                            .foregroundColor(KairosAuth.Color.accent)
                                    }
                                }
                                .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                                
                                // Card wrapper for learned places (show max 3)
                                DashboardCard {
                                    VStack(spacing: KairosAuth.Spacing.small) {
                                        ForEach(vm.learnedPlaces.prefix(3), id: \.id) { place in
                                            Button {
                                                navigationPath.append(PlacesDestination.learnedLocations)
                                            } label: {
                                                LearnedPlaceRow(place: place)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                            }
                        }
                        
                        // Section 2: Explore (POI with filters)
                        VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                            // Section header
                            HStack(spacing: KairosAuth.Spacing.medium) {
                                HStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                                        .foregroundColor(KairosAuth.Color.accent)
                                        .accessibilityHidden(true)
                                    
                                    Text("\(filteredPOIs.count)")
                                        .font(KairosAuth.Typography.cardTitle)
                                        .foregroundColor(KairosAuth.Color.accent)
                                }
                                
                                Text("Explore")
                                    .font(KairosAuth.Typography.cardTitle)
                                    .foregroundColor(KairosAuth.Color.primaryText)
                                
                                Spacer()
                            }
                            .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                            
                            // Category filter chips
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: KairosAuth.Spacing.small) {
                                    ForEach(POICategory.allCases, id: \.self) { category in
                                        CategoryChip(
                                            category: category,
                                            isSelected: selectedCategory == category,
                                            onTap: { selectedCategory = category }
                                        )
                                    }
                                }
                                .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                            }
                            
                            // Near Me and Sort controls (Phase 5 - Task 25)
                            HStack(spacing: KairosAuth.Spacing.small) {
                                // Near Me toggle button
                                Button {
                                    if vm.userLocation == nil {
                                        vm.requestLocation()
                                    }
                                    showNearbyOnly.toggle()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: showNearbyOnly ? "location.fill" : "location")
                                            .font(.system(size: KairosAuth.IconSize.button))
                                            .accessibilityHidden(true)
                                        
                                        Text("Near Me")
                                            .font(KairosAuth.Typography.buttonLabel)
                                    }
                                    .foregroundColor(showNearbyOnly ? KairosAuth.Color.buttonText : KairosAuth.Color.accent)
                                    .padding(.horizontal, KairosAuth.Spacing.cardPadding)
                                    .padding(.vertical, KairosAuth.Spacing.small)
                                    .background(showNearbyOnly ? KairosAuth.Color.accent : KairosAuth.Color.fieldBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button))
                                }
                                
                                // Sort by distance button (only show when location available)
                                if vm.userLocation != nil {
                                    Button {
                                        sortByDistance.toggle()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: sortByDistance ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                                                .font(.system(size: KairosAuth.IconSize.button))
                                                .accessibilityHidden(true)
                                            
                                            Text("Sort: \(sortByDistance ? "Distance" : "Default")")
                                                .font(KairosAuth.Typography.buttonLabel)
                                        }
                                        .foregroundColor(KairosAuth.Color.accent)
                                        .padding(.horizontal, KairosAuth.Spacing.cardPadding)
                                        .padding(.vertical, KairosAuth.Spacing.small)
                                        .background(KairosAuth.Color.fieldBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button))
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                            .padding(.vertical, KairosAuth.Spacing.small)
                            
                            // Card wrapper for POIs
                            DashboardCard {
                                VStack(spacing: KairosAuth.Spacing.small) {
                                    if filteredPOIs.isEmpty {
                                        // Empty state - differentiate between search and general empty
                                        if !searchText.isEmpty {
                                            // Empty search results
                                            VStack(spacing: KairosAuth.Spacing.medium) {
                                                Image(systemName: "magnifyingglass")
                                                    .font(.system(size: KairosAuth.IconSize.heroIcon))
                                                    .foregroundColor(KairosAuth.Color.tertiaryText)
                                                    .accessibilityHidden(true)
                                                
                                                Text("No places found")
                                                    .font(KairosAuth.Typography.cardTitle)
                                                    .foregroundColor(KairosAuth.Color.primaryText)
                                                
                                                Text("Try a different search term")
                                                    .font(KairosAuth.Typography.itemSubtitle)
                                                    .foregroundColor(KairosAuth.Color.secondaryText)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 60)
                                        } else {
                                            // General empty state (no POIs available)
                                            EmptyPOIState(searchText: searchText)
                                                .padding(.vertical, KairosAuth.Spacing.large)
                                        }
                                    } else {
                                        ForEach(filteredPOIs.prefix(10), id: \.id) { poi in
                                            POICard(
                                                poi: poi,
                                                distanceText: distanceString(to: poi)
                                            )
                                                .onTapGesture {
                                                    vm.selectedPOI = poi
                                                    navigationPath.append(poi)
                                                }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                        }
                    }
                    .padding(.bottom, 100)  // Adequate space above tab bar
                }
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    onScrollOffsetChange?(offset)
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
                    Text("Places")
                        .font(KairosAuth.Typography.screenTitle)
                        .foregroundStyle(KairosAuth.Color.primaryText)
                }
                
                // Profile button (consistent with other screens)
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: vm.openProfile) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: KairosAuth.IconSize.profileButton))
                            .foregroundColor(KairosAuth.Color.accent)
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel("Profile")
                    .accessibilityHint("View your profile, settings, and help")
                }
            }
            .navigationDestination(for: PlacesDestination.self) { destination in
                switch destination {
                case .learnedLocations:
                    LearnedLocationsView(vm: vm)
                }
            }
            .navigationDestination(for: POI.self) { poi in
                POIDetailView(poi: poi, vm: vm)
            }
        }
        .task {
            await vm.loadPlacesData()
        }
    }
    
    /// Filter POIs by category, search text, nearby, and sort
    /// Phase 5 - Task 25: Real-time search + location-based filtering
    /// See: /docs/apple-index.md → "CLLocation" (iOS 2.0+)
    private var filteredPOIs: [POI] {
        var result = vm.pois
        
        // Category filter
        if selectedCategory != .all {
            result = result.filter { $0.type == selectedCategory.rawValue }
        }
        
        // Search filter (name, category, address)
        if !searchText.isEmpty {
            result = result.filter { poi in
                poi.name.localizedCaseInsensitiveContains(searchText) ||
                poi.type.localizedCaseInsensitiveContains(searchText) ||
                poi.address.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply nearby filter (5km radius)
        /// See: /docs/apple-index.md → "CLLocation.distance(from:)" (iOS 2.0+)
        if showNearbyOnly, let userLoc = vm.userLocation {
            result = result.filter { poi in
                let poiLocation = CLLocation(latitude: poi.lat, longitude: poi.lon)
                let userLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                let distance = userLocation.distance(from: poiLocation) // meters
                return distance <= 5000 // 5km radius
            }
        }
        
        // Sort by distance if enabled
        /// See: /docs/apple-index.md → "CLLocation.distance(from:)" (iOS 2.0+)
        if sortByDistance, let userLoc = vm.userLocation {
            result.sort { poi1, poi2 in
                let loc1 = CLLocation(latitude: poi1.lat, longitude: poi1.lon)
                let loc2 = CLLocation(latitude: poi2.lat, longitude: poi2.lon)
                let userLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                return userLocation.distance(from: loc1) < userLocation.distance(from: loc2)
            }
        }
        
        return result
    }
    
    /// Calculate distance from user to POI
    /// See: /docs/apple-index.md → "CLLocation.distance(from:)" (iOS 2.0+)
    private func distanceString(to poi: POI) -> String? {
        guard let userLoc = vm.userLocation else { return nil }
        
        let poiLocation = CLLocation(latitude: poi.lat, longitude: poi.lon)
        let userLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let distanceMeters = userLocation.distance(from: poiLocation)
        
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters))m away"
        } else {
            let km = distanceMeters / 1000.0
            return String(format: "%.1fkm away", km)
        }
    }
}



// MARK: - Search Bar Placeholder

private struct SearchBarPlaceholder: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: KairosAuth.Spacing.medium) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: KairosAuth.IconSize.itemIcon))
                .foregroundColor(KairosAuth.Color.tertiaryText)
                .accessibilityHidden(true)
            
            TextField("Search places...", text: $text)
                .font(KairosAuth.Typography.fieldInput)
                .foregroundColor(KairosAuth.Color.primaryText)
                .tint(KairosAuth.Color.accent)
                .autocorrectionDisabled()
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.itemIcon))
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("Clear search text")
            }
        }
        .padding(KairosAuth.Spacing.cardPadding)
        .background(KairosAuth.Color.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card))
    }
}

// MARK: - Learned Place Row

private struct LearnedPlaceRow: View {
    let place: LearnedPlace
    
    var body: some View {
        HStack(spacing: KairosAuth.Spacing.medium) {
            // Icon
            Image(systemName: place.icon)
                .font(.system(size: KairosAuth.IconSize.cardIcon))
                .foregroundColor(KairosAuth.Color.accent)
                .accessibilityHidden(true)
                .frame(width: 40, height: 40)
            
            // Name and address
            VStack(alignment: .leading, spacing: 4) {
                Text(place.label)
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundColor(KairosAuth.Color.primaryText)
                
                Text(place.address)
                    .font(KairosAuth.Typography.itemSubtitle)
                    .foregroundColor(KairosAuth.Color.secondaryText)
            }
            
            Spacer()
            
            // Privacy indicator
            if place.isPrivate {
                Image(systemName: "lock.fill")
                    .font(.system(size: KairosAuth.IconSize.badge))
                    .foregroundColor(KairosAuth.Color.tertiaryText)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, KairosAuth.Spacing.small)
    }
}

// MARK: - Category Chips & POI Cards

private struct CategoryChip: View {
    let category: POICategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(KairosAuth.Typography.itemSubtitle)
                    .accessibilityHidden(true)
                Text(category.displayName)
                    .font(KairosAuth.Typography.statusBadge)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? KairosAuth.Color.accent : KairosAuth.Color.cardBackground)
            .foregroundColor(isSelected ? KairosAuth.Color.buttonText : KairosAuth.Color.primaryText)
            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button))
            .overlay(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                    .stroke(isSelected ? Color.clear : KairosAuth.Color.cardBorder, lineWidth: 1)
            )
        }
    }
}

private struct POICard: View {
    let poi: POI
    let distanceText: String? // Task 25: Distance from user location
    
    var body: some View {
        HStack(spacing: KairosAuth.Spacing.medium) {
            // Icon
            Image(systemName: poi.categoryIcon)
                .font(.system(size: KairosAuth.IconSize.cardIcon))
                .foregroundColor(KairosAuth.Color.accent)
                .accessibilityHidden(true)
                .frame(width: 40, height: 40)
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(poi.name)
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundColor(KairosAuth.Color.primaryText)
                
                HStack(spacing: 8) {
                    // Rating
                    if poi.rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(KairosAuth.Typography.tabBarLabel)
                                .foregroundColor(KairosAuth.Color.warning)
                                .accessibilityHidden(true)
                            Text(String(format: "%.1f", poi.rating))
                                .font(KairosAuth.Typography.itemSubtitle)
                        }
                    }
                    
                    // Price range
                    Text(String(repeating: "$", count: poi.price_range))
                        .font(KairosAuth.Typography.itemSubtitle)
                    
                    // Distance fallback
                    if distanceText == nil {
                        Text("• \(poi.formattedDistance)")
                            .font(KairosAuth.Typography.itemSubtitle)
                    }
                }
                .foregroundColor(KairosAuth.Color.secondaryText)
                
                // Task 25: Real-time distance when location available
                /// See: /docs/apple-index.md → "CLLocation.distance(from:)" (iOS 2.0+)
                if let distance = distanceText {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: KairosAuth.IconSize.badge))
                            .foregroundColor(KairosAuth.Color.accent)
                            .accessibilityHidden(true)
                        
                        Text(distance)
                            .font(KairosAuth.Typography.timestamp)
                            .foregroundColor(KairosAuth.Color.accent)
                    }
                }
                
                Text(poi.address)
                    .font(KairosAuth.Typography.timestamp)
                    .foregroundColor(KairosAuth.Color.tertiaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(KairosAuth.Typography.statusBadge)
                .foregroundColor(KairosAuth.Color.tertiaryText)
                .accessibilityHidden(true)
        }
        .padding(KairosAuth.Spacing.cardContentPadding)
        .background(
            KairosAuth.Color.itemBackground
                .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
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
    }
}

private struct EmptyPOIState: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: KairosAuth.Spacing.medium) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: KairosAuth.IconSize.heroIcon))
                .foregroundColor(KairosAuth.Color.tertiaryText)
                .accessibilityHidden(true)
            
            Text(searchText.isEmpty ? "No places nearby" : "No results for '\(searchText)'")
                .font(KairosAuth.Typography.cardTitle)
                .foregroundColor(KairosAuth.Color.secondaryText)
            
            Text(searchText.isEmpty ? "Try exploring a different area" : "Try a different search")
                .font(KairosAuth.Typography.itemSubtitle)
                .foregroundColor(KairosAuth.Color.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(KairosAuth.Spacing.extraLarge)
    }
}

// MARK: - POI Detail View

private struct POIDetailView: View {
    let poi: POI
    @ObservedObject var vm: AppVM
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KairosAuth.Spacing.cardSpacing) {
                // Header
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                    Text(poi.name)
                        .font(KairosAuth.Typography.screenTitle)
                        .foregroundColor(KairosAuth.Color.primaryText)
                    
                    HStack(spacing: 12) {
                        if poi.rating > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(KairosAuth.Color.warning)
                                    .accessibilityHidden(true)
                                Text(String(format: "%.1f", poi.rating))
                                    .font(KairosAuth.Typography.itemTitle)
                                    .foregroundColor(KairosAuth.Color.primaryText)
                            }
                        }
                        
                        Text(String(repeating: "$", count: poi.price_range))
                            .font(KairosAuth.Typography.itemTitle)
                            .foregroundColor(KairosAuth.Color.secondaryText)
                        
                        Text("• \(poi.formattedDistance)")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundColor(KairosAuth.Color.secondaryText)
                    }
                }
                .padding()
                
                // Address
                InfoRow(icon: "mappin.circle.fill", label: "Address", value: poi.address)
                
                // Hours
                InfoRow(icon: "clock.fill", label: "Hours", value: poi.hours ?? "Hours not available")
                
                // TODO: Add map view, user ratings, photos
                
                Spacer(minLength: 60)
            }
            .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
        }
        .background(
            KairosAuth.Color.backgroundGradient(),
            ignoresSafeAreaEdges: .all
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await vm.toggleFavorite(poi: poi)
                    }
                } label: {
                    Image(systemName: vm.isFavorite(poi: poi) ? "heart.fill" : "heart")
                        .font(.system(size: KairosAuth.IconSize.button))
                        .foregroundColor(vm.isFavorite(poi: poi) ? .red : KairosAuth.Color.primaryText)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel(vm.isFavorite(poi: poi) ? "Remove place from favorites" : "Add place to favorites")
            }
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: KairosAuth.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: KairosAuth.IconSize.itemIcon))
                .foregroundColor(KairosAuth.Color.accent)
                .accessibilityHidden(true)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(KairosAuth.Typography.statusBadge)
                    .foregroundColor(KairosAuth.Color.tertiaryText)
                
                Text(value)
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundColor(KairosAuth.Color.primaryText)
            }
            
            Spacer()
        }
        .padding(KairosAuth.Spacing.cardPadding)
        .background(KairosAuth.Color.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card))
        .padding(.horizontal)
    }
}

// MARK: - Supporting Types

enum POICategory: String, CaseIterable {
    case all = "all"
    case cafe = "cafe"
    case restaurant = "restaurant"
    case bar = "bar"
    case gym = "gym"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .cafe: return "Cafés"
        case .restaurant: return "Restaurants"
        case .bar: return "Bars"
        case .gym: return "Gyms"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .cafe: return "cup.and.saucer.fill"
        case .restaurant: return "fork.knife"
        case .bar: return "wineglass.fill"
        case .gym: return "dumbbell.fill"
        }
    }
}

#Preview {
    PlacesView(vm: AppVM())
}
