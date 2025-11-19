//
//  LearnedLocationsView.swift
//  KairosAmiqo
//
//  Created by Copilot on 2025-10-25.
//  Phase 5 - Task 24: Learned Locations Management
//
//  Apple Documentation References:
//  - MapKit MKLocalSearchCompleter: /docs/apple-index.md → "MKLocalSearchCompleter" (iOS 9.3+)
//  - CoreLocation CLGeocoder: /docs/apple-index.md → "CLGeocoder" (iOS 5.0+)
//  - SwiftUI List & Form: /docs/apple-index.md → "List", "Form" (iOS 13.0+)
//

import SwiftUI
import MapKit
import CoreLocation

/// Learned Locations management view
/// See: /docs/01-data-model.md for data structure
/// See: /docs/UX-SPECIFICATION-PLANS-EVENTS-AMIQO.md §Places
struct LearnedLocationsView: View {
    @ObservedObject var vm: AppVM
    @State private var showAddLocation = false
    @State private var editingLocation: LearnedPlace?
    @State private var showDeleteConfirm = false
    @State private var locationToDelete: LearnedPlace?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            if vm.learnedPlaces.isEmpty {
                // Empty state
                EmptyLearnedPlacesState(onAdd: { showAddLocation = true })
            } else {
                VStack(spacing: KairosAuth.Spacing.medium) {
                    // Section header (outside list)
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
                    }
                    .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                    .padding(.top, KairosAuth.Spacing.medium)
                    
                    // List with swipe-to-delete
                    List {
                        ForEach(vm.learnedPlaces) { place in
                            LearnedLocationRow(place: place)
                                .listRowBackground(KairosAuth.Color.cardBackground)
                                .listRowSeparator(.hidden)
                                .onTapGesture {
                                    editingLocation = place
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        locationToDelete = place
                                        showDeleteConfirm = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(height: CGFloat(vm.learnedPlaces.count) * 80) // Approximate row height
                    .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                            .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
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
                Text("Your Places")
                    .font(KairosAuth.Typography.screenTitle)
                    .foregroundStyle(KairosAuth.Color.primaryText)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddLocation = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.profileButton))
                        .foregroundColor(KairosAuth.Color.accent)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("Add a saved place")
                .accessibilityHint("Opens the add location form")
            }
        }
        .sheet(isPresented: $showAddLocation) {
            AddEditLocationSheet(vm: vm, location: nil)
        }
        .sheet(item: $editingLocation) { location in
            AddEditLocationSheet(vm: vm, location: location)
        }
        .alert("Delete \(locationToDelete?.label ?? "location")?", isPresented: $showDeleteConfirm, presenting: locationToDelete) { location in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await vm.deleteLearnedPlace(location)
                }
            }
        } message: { location in
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - Learned Location Row

private struct LearnedLocationRow: View {
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
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Privacy indicator & visit count
            VStack(alignment: .trailing, spacing: 4) {
                if place.isPrivate {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: KairosAuth.IconSize.badge))
                            .foregroundColor(KairosAuth.Color.tertiaryText)
                            .accessibilityHidden(true)
                        
                        Text("Private")
                            .font(KairosAuth.Typography.statusBadge)
                            .foregroundColor(KairosAuth.Color.tertiaryText)
                    }
                }
                
                Text("\(place.visitCount) visits")
                    .font(KairosAuth.Typography.timestamp)
                    .foregroundColor(KairosAuth.Color.tertiaryText)
            }
        }
        .padding(.horizontal, KairosAuth.Spacing.cardPadding)
        .padding(.vertical, KairosAuth.Spacing.small)
        .contentShape(Rectangle()) // Make entire row tappable
    }
}

// MARK: - Empty State

private struct EmptyLearnedPlacesState: View {
    let onAdd: () -> Void
    
    var body: some View {
        VStack(spacing: KairosAuth.Spacing.large) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: KairosAuth.IconSize.heroIcon))
                .foregroundColor(KairosAuth.Color.accent)
                .accessibilityHidden(true)
            
            Text("No Places Yet")
                .font(KairosAuth.Typography.cardTitle)
                .foregroundColor(KairosAuth.Color.primaryText)
            
            Text("Add your frequently visited locations like Home and Work to help the app suggest better venues.")
                .font(KairosAuth.Typography.itemSubtitle)
                .foregroundColor(KairosAuth.Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
            
            Button {
                onAdd()
            } label: {
                HStack(spacing: KairosAuth.Spacing.small) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.button))
                        .accessibilityHidden(true)
                    
                    Text("Add Your First Place")
                        .font(KairosAuth.Typography.buttonLabel)
                }
                .foregroundColor(KairosAuth.Color.buttonText)
                .padding(.vertical, KairosAuth.Spacing.buttonVertical)
                .padding(.horizontal, KairosAuth.Spacing.cardPadding)
                .background(KairosAuth.Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button))
            }
        }
        .padding(.top, 100)
    }
}

// MARK: - Add/Edit Location Sheet

struct AddEditLocationSheet: View {
    @ObservedObject var vm: AppVM
    let location: LearnedPlace? // nil = add, non-nil = edit
    @Environment(\.dismiss) var dismiss
    
    @State private var label: String
    @State private var selectedIcon: String
    @State private var address: String
    @State private var isPrivate: Bool
    
    @StateObject private var searchViewModel = AddressSearchViewModel()
    @State private var selectedCoordinates: CLLocationCoordinate2D?
    @State private var showingSearchResults = false
    @State private var isSaving = false
    
    init(vm: AppVM, location: LearnedPlace?) {
        self.vm = vm
        self.location = location
        
        // Initialize state from existing location or defaults
        _label = State(initialValue: location?.label ?? "")
        _selectedIcon = State(initialValue: location?.icon ?? "mappin.circle.fill")
        _address = State(initialValue: location?.address ?? "")
        _isPrivate = State(initialValue: location?.isPrivate ?? false)
        
        if let location = location {
            _selectedCoordinates = State(initialValue: CLLocationCoordinate2D(latitude: location.lat, longitude: location.lon))
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Label section
                Section {
                    TextField("e.g., Home, Work, Gym", text: $label)
                        .font(KairosAuth.Typography.fieldInput)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                } header: {
                    Text("Label")
                        .font(KairosAuth.Typography.fieldLabel)
                        .foregroundColor(KairosAuth.Color.secondaryText)
                }
                .listRowBackground(KairosAuth.Color.fieldBackground)
                    
                    // Icon picker section
                    Section {
                        IconPicker(selectedIcon: $selectedIcon)
                    } header: {
                        Text("Icon")
                            .font(KairosAuth.Typography.fieldLabel)
                            .foregroundColor(KairosAuth.Color.secondaryText)
                    }
                    .listRowBackground(Color.clear)
                    
                    // Address search section
                    Section {
                        VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                            TextField("Search address...", text: $address)
                                .font(KairosAuth.Typography.fieldInput)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled(false)
                                .onChange(of: address) { _, newValue in
                                    searchViewModel.search(query: newValue)
                                    showingSearchResults = !newValue.isEmpty
                                }
                            
                            if showingSearchResults && !searchViewModel.searchResults.isEmpty {
                                ForEach(searchViewModel.searchResults, id: \.self) { result in
                                    Button {
                                        selectSearchResult(result)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(result.title)
                                                .font(KairosAuth.Typography.itemTitle)
                                                .foregroundColor(KairosAuth.Color.primaryText)
                                            
                                            Text(result.subtitle)
                                                .font(KairosAuth.Typography.itemSubtitle)
                                                .foregroundColor(KairosAuth.Color.secondaryText)
                                        }
                                        .padding(.vertical, KairosAuth.Spacing.small)
                                    }
                                    
                                    Divider()
                                }
                            }
                        }
                    } header: {
                        Text("Address")
                            .font(KairosAuth.Typography.fieldLabel)
                            .foregroundColor(KairosAuth.Color.secondaryText)
                    }
                    .listRowBackground(KairosAuth.Color.fieldBackground)
                    
                    // Privacy toggle section
                    Section {
                        Toggle(isOn: $isPrivate) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Private Location")
                                    .font(KairosAuth.Typography.itemTitle)
                                    .foregroundColor(KairosAuth.Color.primaryText)
                                
                                Text("Private locations are not shared in invitations")
                                    .font(KairosAuth.Typography.itemSubtitle)
                                    .foregroundColor(KairosAuth.Color.secondaryText)
                            }
                        }
                        .tint(KairosAuth.Color.accent)
                    }
                    .listRowBackground(KairosAuth.Color.fieldBackground)
            }
            .scrollContentBackground(.hidden)
            .background(
                KairosAuth.Color.backgroundGradient(),
                ignoresSafeAreaEdges: .all
            )
            .navigationTitle(location == nil ? "Add Location" : "Edit Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(KairosAuth.Color.accent)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveLocation()
                        }
                    }
                    .foregroundColor(KairosAuth.Color.accent)
                    .disabled(!isValid || isSaving)
                }
            }
        }
    }
    
    // MARK: - Validation
    
    private var isValid: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty &&
        !address.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedCoordinates != nil
    }
    
    // MARK: - Actions
    
    private func selectSearchResult(_ result: MKLocalSearchCompletion) {
        address = "\(result.title), \(result.subtitle)"
        showingSearchResults = false
        
        // Geocode the selected address to get coordinates
        Task {
            if let coordinates = await geocodeAddress(address) {
                selectedCoordinates = coordinates
            }
        }
    }
    
    private func geocodeAddress(_ addressString: String) async -> CLLocationCoordinate2D? {
        // See: /docs/apple-index.md → "CLGeocoder" (iOS 5.0+)
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(addressString)
            return placemarks.first?.location?.coordinate
        } catch {
            print("[Geocoding] ❌ Failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func saveLocation() async {
        guard let coordinates = selectedCoordinates else { return }
        
        isSaving = true
        
        if let existingLocation = location {
            // Update existing location
            await vm.updateLearnedPlace(
                id: existingLocation.id,
                label: label,
                address: address,
                lat: coordinates.latitude,
                lon: coordinates.longitude,
                icon: selectedIcon,
                isPrivate: isPrivate
            )
        } else {
            // Add new location
            await vm.addLearnedPlace(
                label: label,
                address: address,
                lat: coordinates.latitude,
                lon: coordinates.longitude,
                icon: selectedIcon,
                isPrivate: isPrivate
            )
        }
        
        isSaving = false
        dismiss()
    }
}

// MARK: - Icon Picker

private struct IconPicker: View {
    @Binding var selectedIcon: String
    
    private let availableIcons = [
        "house.fill",
        "briefcase.fill",
        "heart.fill",
        "star.fill",
        "cup.and.saucer.fill",
        "dumbbell.fill",
        "figure.run",
        "cart.fill",
        "airplane",
        "building.2.fill",
        "graduationcap.fill",
        "mappin.circle.fill"
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: KairosAuth.Spacing.medium) {
                ForEach(availableIcons, id: \.self) { icon in
                    Button {
                        selectedIcon = icon
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: KairosAuth.IconSize.cardIcon))
                            .foregroundColor(selectedIcon == icon ? KairosAuth.Color.buttonText : KairosAuth.Color.primaryText)
                            .accessibilityHidden(true)
                            .frame(width: 50, height: 50)
                            .background(selectedIcon == icon ? KairosAuth.Color.accent : KairosAuth.Color.fieldBackground)
                            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button))
                            .overlay(
                                RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                                    .stroke(selectedIcon == icon ? KairosAuth.Color.accent : KairosAuth.Color.fieldBorder, lineWidth: 1)
                            )
                    }
                    .accessibilityLabel(iconAccessibilityLabel(icon))
                    .accessibilityHint("Use this icon for the saved place")
                }
            }
        }
    }

    private func iconAccessibilityLabel(_ icon: String) -> String {
        switch icon {
        case "house.fill":
            return "House icon"
        case "briefcase.fill":
            return "Work icon"
        case "heart.fill":
            return "Heart icon"
        case "star.fill":
            return "Star icon"
        case "cup.and.saucer.fill":
            return "Cafe icon"
        case "dumbbell.fill":
            return "Gym icon"
        case "figure.run":
            return "Running icon"
        case "cart.fill":
            return "Shopping cart icon"
        case "airplane":
            return "Airplane icon"
        case "building.2.fill":
            return "Building icon"
        case "graduationcap.fill":
            return "Graduation cap icon"
        case "mappin.circle.fill":
            return "Map pin icon"
        default:
            return icon.replacingOccurrences(of: ".", with: " ")
        }
    }
}

// MARK: - Address Search View Model
/// MapKit address search using MKLocalSearchCompleter
/// See: /docs/apple-index.md → "MKLocalSearchCompleter" (iOS 9.3+)
class AddressSearchViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchResults: [MKLocalSearchCompletion] = []
    private let searchCompleter = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = .address
    }
    
    func search(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        searchCompleter.queryFragment = query
    }
    
    // MKLocalSearchCompleterDelegate
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchResults = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("[Address Search] ❌ Error: \(error.localizedDescription)")
        searchResults = []
    }
}
