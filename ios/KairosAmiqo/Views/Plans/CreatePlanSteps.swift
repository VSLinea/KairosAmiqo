import SwiftUI
import Contacts

/// Step 1: WHO - Select participants (Kairos users, contacts, manual entry)
/// Uses PlanParticipant from Models.swift (matches backend schema)
struct ParticipantsStep: View {
    @ObservedObject var vm: AppVM
    @Binding var selectedParticipants: [PlanParticipant]
    @State private var searchText = ""
    @State private var showingContactsPicker = false
    @State private var showingManualEntry = false
    
    // Contacts integration
    @State private var phoneContacts: [PlanParticipant] = []
    @State private var contactsHelper = ContactsHelper()
    @State private var contactsPermissionStatus: CNAuthorizationStatus = .notDetermined

    var body: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.large) {
            sectionHeader(title: "Invite friends", icon: "person.2.fill")

            // Selected chips
            if !selectedParticipants.isEmpty {
                selectedChips
            }

            // "Ask Amiqo" button
            amiqoSuggestionButton

            // Search field
            searchField

            // Kairos Friends section
            kairosFriendsList

            // Phone Contacts section
            phoneContactsSection

            // Manual add
            manualAddButton
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualParticipantSheet(selectedParticipants: $selectedParticipants)
        }
    }

    private var selectedChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: KairosAuth.Spacing.small) {
                ForEach(selectedParticipants) { participant in
                    HStack(spacing: KairosAuth.Spacing.xs) {
                        Text(participant.name)
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundStyle(KairosAuth.Color.primaryText)

                        Button(action: { removeParticipant(participant) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: KairosAuth.IconSize.badge))
                                .foregroundStyle(KairosAuth.Color.tertiaryText)
                        }
                        .accessibilityLabel("Remove \(participant.name)")
                        .accessibilityHint("Double tap to remove this participant")
                    }
                    .padding(.vertical, KairosAuth.Spacing.small)
                    .padding(.horizontal, KairosAuth.Spacing.medium)
                    .background(
                        Capsule()
                            .fill(KairosAuth.Color.selectedBackground)
                            .overlay(
                                Capsule()
                                    .stroke(KairosAuth.Color.accent.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.vertical, KairosAuth.Spacing.small)
        }
    }

    private var amiqoSuggestionButton: some View {
        Button(action: {
            // TODO: Wire to Amiqo suggestion API
            print("🤖 Ask Amiqo for suggestions")
        }) {
            HStack(spacing: KairosAuth.Spacing.small) {
                Image(systemName: "sparkles")
                    .font(.system(size: KairosAuth.IconSize.itemIcon))
                    .accessibilityHidden(true)
                Text("Ask Amiqo to pick group")
                    .font(KairosAuth.Typography.buttonLabel)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(KairosAuth.Typography.buttonIcon)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(KairosAuth.Color.accent)
            .padding(KairosAuth.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                    .fill(KairosAuth.Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                            .stroke(KairosAuth.Color.accent.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    private var searchField: some View {
        HStack(spacing: KairosAuth.Spacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(KairosAuth.Color.tertiaryText)
                .accessibilityHidden(true)
            TextField("Search friends...", text: $searchText)
                .font(KairosAuth.Typography.body)
                .foregroundStyle(KairosAuth.Color.primaryText)
                .textInputAutocapitalization(.words)
        }
        .padding(KairosAuth.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                .fill(KairosAuth.Color.fieldBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                        .stroke(KairosAuth.Color.fieldBorder, lineWidth: 1)
                )
        )
    }

    private var kairosFriendsList: some View {
        VStack(spacing: KairosAuth.Spacing.small) {
            // Section header
            HStack {
                Text("KAIROS FRIENDS")
                    .font(KairosAuth.Typography.statusBadge)
                    .foregroundStyle(KairosAuth.Color.tertiaryText)
                Spacer()
            }
            .padding(.top, KairosAuth.Spacing.small)
            
            if vm.friends.isEmpty {
                // Loading state or empty state
                HStack {
                    ProgressView("Loading friends...")
                        .font(KairosAuth.Typography.itemSubtitle)
                        .foregroundStyle(KairosAuth.Color.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(KairosAuth.Spacing.large)
                .task {
                    do {
                        try await vm.fetchFriends()
                    } catch {
                        print("❌ Failed to load friends: \(error)")
                    }
                }
            } else {
                ForEach(filteredKairosFriends) { friend in
                    participantRow(friend, source: "Kairos user")
                }
            }
        }
    }
    
    private var phoneContactsSection: some View {
        VStack(spacing: KairosAuth.Spacing.small) {
            // Section header with permission button
            HStack {
                Text("YOUR CONTACTS")
                    .font(KairosAuth.Typography.statusBadge)
                    .foregroundStyle(KairosAuth.Color.tertiaryText)
                Spacer()
                
                if contactsPermissionStatus == .notDetermined || contactsPermissionStatus == .denied {
                    Button(action: { Task { await requestContactsAccess() } }) {
                        Text(contactsPermissionStatus == .denied ? "Enable in Settings" : "Connect")
                            .font(KairosAuth.Typography.statusBadge)
                            .foregroundStyle(KairosAuth.Color.accent)
                    }
                }
            }
            .padding(.top, KairosAuth.Spacing.small)
            
            if contactsPermissionStatus == .authorized {
                if phoneContacts.isEmpty {
                    HStack {
                        ProgressView("Loading contacts...")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundStyle(KairosAuth.Color.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(KairosAuth.Spacing.large)
                } else {
                    ForEach(filteredPhoneContacts) { contact in
                        participantRow(contact, source: "Contact")
                    }
                }
            } else if contactsPermissionStatus == .denied {
                HStack(spacing: KairosAuth.Spacing.small) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: KairosAuth.IconSize.badge))
                        .foregroundStyle(KairosAuth.Color.teal)
                        .accessibilityHidden(true)
                    Text("Enable contacts access in Settings to invite from your address book")
                        .font(KairosAuth.Typography.bodySmall)
                        .foregroundStyle(KairosAuth.Color.secondaryText)
                }
                .padding(KairosAuth.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                        .fill(KairosAuth.Color.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                                .stroke(KairosAuth.Color.teal.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    /// Reusable participant row (works for both Kairos friends and contacts)
    private func participantRow(_ participant: PlanParticipant, source: String) -> some View {
        Button(action: { toggleParticipant(participant) }) {
            HStack(spacing: KairosAuth.Spacing.medium) {
                // Avatar placeholder
                Circle()
                    .fill(KairosAuth.Color.accent.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(participant.name.prefix(1)))
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundStyle(KairosAuth.Color.accent)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(participant.name)
                        .font(KairosAuth.Typography.itemTitle)
                        .foregroundStyle(KairosAuth.Color.primaryText)

                    Text(source)
                        .font(KairosAuth.Typography.timestamp)
                        .foregroundStyle(KairosAuth.Color.tertiaryText)
                }

                Spacer()

                // Checkmark circle (filled when selected)
                ZStack {
                    if selectedParticipants.contains(where: { $0.user_id == participant.user_id }) {
                        Circle()
                            .fill(KairosAuth.Color.accent)
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .stroke(KairosAuth.Color.tertiaryText, lineWidth: 2)
                            .frame(width: 28, height: 28)
                    }
                }
                .accessibilityHidden(true)
            }
            .padding(KairosAuth.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                    .fill(selectedParticipants.contains(where: { $0.user_id == participant.user_id }) ? KairosAuth.Color.selectedBackground : KairosAuth.Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                            .stroke(selectedParticipants.contains(where: { $0.user_id == participant.user_id }) ? KairosAuth.Color.accent.opacity(0.3) : KairosAuth.Color.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(selectedParticipants.contains(where: { $0.user_id == participant.user_id }) ? "Selected" : "Not selected")
    }

    private var manualAddButton: some View {
        Button(action: {
            showingManualEntry = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: KairosAuth.IconSize.itemIcon))
                    .accessibilityHidden(true)
                Text("Add by email or phone")
                    .font(KairosAuth.Typography.buttonLabel)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(KairosAuth.Typography.buttonIcon)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(KairosAuth.Color.secondaryText)
            .padding(KairosAuth.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                    .fill(KairosAuth.Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                            .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Filtered Lists
    
    private var filteredKairosFriends: [PlanParticipant] {
        // CRITICAL: Hardcoded current user UUID must match mock-server/data/users.json
        // TODO: Replace with actual auth.currentUserId when auth is implemented
        let currentUserId = UUID(uuidString: "660e8400-e29b-41d4-a716-446655440001")!
        
        // Convert KairosFriend to PlanParticipant
        // Filter out current user as safety measure (backend should already exclude)
        let participants = vm.friends
            .filter { $0.user_id != currentUserId }
            .map { friend in
                PlanParticipant(user_id: friend.user_id, name: friend.name, status: "invited")
            }
        
        if searchText.isEmpty {
            return participants
        } else {
            return participants.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var filteredPhoneContacts: [PlanParticipant] {
        if searchText.isEmpty {
            return phoneContacts
        } else {
            return phoneContacts.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.email?.localizedCaseInsensitiveContains(searchText) == true ||
                $0.phone?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func requestContactsAccess() async {
        contactsPermissionStatus = contactsHelper.authorizationStatus
        
        if contactsPermissionStatus == .notDetermined {
            let granted = await contactsHelper.requestPermission()
            contactsPermissionStatus = granted ? .authorized : .denied
            
            if granted {
                await loadContacts()
            }
        }
    }
    
    private func loadContacts() async {
        do {
            let contactInfos = try await contactsHelper.fetchContacts()
            // Convert ContactInfo to PlanParticipant
            phoneContacts = contactInfos.map { contact in
                PlanParticipant(
                    user_id: UUID(), // Temp UUID for non-Kairos users
                    name: contact.name,
                    email: contact.email,
                    phone: contact.phone
                )
            }
            print("✅ Loaded \(phoneContacts.count) phone contacts")
        } catch {
            print("❌ Failed to load contacts: \(error)")
        }
    }

    private func toggleParticipant(_ participant: PlanParticipant) {
        // Check by user_id to prevent duplicates
        if let index = selectedParticipants.firstIndex(where: { $0.user_id == participant.user_id }) {
            selectedParticipants.remove(at: index)
        } else {
            selectedParticipants.append(participant)
        }
    }

    private func removeParticipant(_ participant: PlanParticipant) {
        selectedParticipants.removeAll { $0.id == participant.id }
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: KairosAuth.Spacing.small) {
            Image(systemName: icon)
                .font(.system(size: KairosAuth.IconSize.cardIcon))
                .foregroundStyle(KairosAuth.Color.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(KairosAuth.Typography.cardTitle)
                .foregroundStyle(KairosAuth.Color.primaryText)
        }
    }
}

// MARK: - Step 2: Intent & Times

/// Step 2: WHAT-WHEN - Select intent template and time slots
struct IntentAndTimesStep: View {
    @ObservedObject var vm: AppVM
    @Binding var selectedIntent: IntentTemplate?
    @Binding var selectedTimes: [ProposedSlot]
    
    /// Tracks whether intent grid is expanded (true) or collapsed (false)
    /// - Starts expanded for generic create (no template)
    /// - Starts collapsed when template pre-selected (Dashboard shortcuts)
    /// - Collapses automatically after user selects intent
    @State private var intentGridExpanded = true
    
    // Date/time picker state
    @State private var showingDatePicker = false
    @State private var selectedDate = Date()

    // Mock time options - will be replaced with Amiqo suggestions + custom picker
    private let mockTimeOptions: [ProposedSlot] = [
        ProposedSlot(time: "2025-10-16T16:00:00Z", venue: nil),
        ProposedSlot(time: "2025-10-16T18:00:00Z", venue: nil),
        ProposedSlot(time: "2025-10-17T12:00:00Z", venue: nil),
        ProposedSlot(time: "2025-10-17T19:00:00Z", venue: nil)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.large) {
            // Section 1: Intent Selection (adaptive - expanded or collapsed)
            intentSelectionSection

            Divider()
                .background(KairosAuth.Color.cardBorder)
                .padding(.vertical, KairosAuth.Spacing.small)

            // Section 2: Time selection (always visible)
            timeSelectionSection
        }
        .onAppear {
            // If template already selected (Dashboard shortcut), start collapsed
            if selectedIntent != nil {
                intentGridExpanded = false
            }
        }
        .onChange(of: selectedIntent) { oldValue, newValue in
            // Collapse grid when user selects an intent
            if newValue != nil && oldValue != newValue {
                withAnimation(KairosAuth.Animation.uiUpdate) {
                    intentGridExpanded = false
                }
            }
        }
    }
    
    // MARK: - Intent Selection Section (Adaptive)
    
    @ViewBuilder
    private var intentSelectionSection: some View {
        if intentGridExpanded {
            // Expanded: Full grid of templates
            expandedIntentGrid
        } else if let selected = selectedIntent {
            // Collapsed: Confirmation card with "Change" button
            collapsedIntentCard(selected: selected)
        }
    }
    
    private var expandedIntentGrid: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
            sectionHeader(title: "What are you proposing?", icon: "calendar.badge.clock")

            // Intent template grid
            if vm.intentTemplates.isEmpty {
                // Loading placeholder
                ProgressView("Loading templates...")
                    .font(KairosAuth.Typography.itemSubtitle)
                    .foregroundStyle(KairosAuth.Color.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(KairosAuth.Spacing.large)
                    .task {
                        do {
                            try await vm.fetchIntentTemplates()
                        } catch {
                            print("❌ Failed to load intent templates: \(error)")
                        }
                    }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: KairosAuth.Spacing.medium) {
                    ForEach(vm.intentTemplates) { template in
                        IntentTemplateButton(
                            template: template,
                            isSelected: selectedIntent?.id == template.id,
                            action: { selectedIntent = template }
                        )
                    }
                }
            }
        }
    }
    
    private func collapsedIntentCard(selected: IntentTemplate) -> some View {
        Button(action: {
            withAnimation(KairosAuth.Animation.uiUpdate) {
                intentGridExpanded = true
            }
        }) {
            HStack(spacing: KairosAuth.Spacing.medium) {
                // Checkmark icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: KairosAuth.IconSize.cardIcon))
                    .foregroundStyle(KairosAuth.Color.accent)
                    .accessibilityHidden(true)
                
                // Selected template emoji + name
                HStack(spacing: KairosAuth.Spacing.small) {
                    Text(selected.emoji)
                        .font(.system(size: 32))  // Emoji needs larger size than SF Symbols
                    
                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                        Text(selected.name)
                            .font(KairosAuth.Typography.itemTitle)
                            .foregroundStyle(KairosAuth.Color.primaryText)
                        
                        Text("Tap to change invitation type")
                            .font(KairosAuth.Typography.statusBadge)
                            .foregroundStyle(KairosAuth.Color.secondaryText)
                    }
                }
                
                Spacer()
                
                // Change chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: KairosAuth.IconSize.itemIcon, weight: .semibold))
                    .foregroundStyle(KairosAuth.Color.tertiaryText)
                    .accessibilityHidden(true)
            }
            .padding(KairosAuth.Spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                    .fill(KairosAuth.Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                            .stroke(KairosAuth.Color.accent.opacity(0.3), lineWidth: 1.5)
                    )
            )
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Time Selection Section (Always Visible)
    
    private var timeSelectionSection: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
            sectionHeader(title: "When works for you?", icon: "clock.fill")

            // Add custom time button
            Button(action: {
                showingDatePicker = true
            }) {
                HStack(spacing: KairosAuth.Spacing.small) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.itemIcon))
                        .accessibilityHidden(true)
                    Text("Add your time")
                        .font(KairosAuth.Typography.buttonLabel)
                }
                .foregroundStyle(KairosAuth.Color.accent)
                .frame(maxWidth: .infinity)
                .padding(KairosAuth.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                        .fill(KairosAuth.Color.accent.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                .stroke(KairosAuth.Color.accent, lineWidth: 1.5)
                        )
                )
            }
            .sheet(isPresented: $showingDatePicker) {
                CustomTimePicker(selectedDate: $selectedDate, onSave: addCustomTime)
            }

            // Divider with label
            HStack(spacing: KairosAuth.Spacing.small) {
                Rectangle()
                    .fill(KairosAuth.Color.cardBorder)
                    .frame(height: 1)
                
                Text("Suggested")
                    .font(KairosAuth.Typography.statusBadge)
                    .foregroundStyle(KairosAuth.Color.tertiaryText)
                
                Rectangle()
                    .fill(KairosAuth.Color.cardBorder)
                    .frame(height: 1)
            }

            VStack(spacing: KairosAuth.Spacing.small) {
                ForEach(mockTimeOptions, id: \.time) { timeSlot in
                    TimeSlotCheckbox(
                        timeSlot: timeSlot,
                        isSelected: selectedTimes.contains(where: { $0.time == timeSlot.time }),
                        onToggle: {
                            if let index = selectedTimes.firstIndex(where: { $0.time == timeSlot.time }) {
                                selectedTimes.remove(at: index)
                            } else {
                                selectedTimes.append(timeSlot)
                            }
                        }
                    )
                }
            }
        }
    }
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: KairosAuth.Spacing.small) {
            Image(systemName: icon)
                .font(.system(size: KairosAuth.IconSize.cardIcon))
                .foregroundStyle(KairosAuth.Color.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(KairosAuth.Typography.cardTitle)
                .foregroundStyle(KairosAuth.Color.primaryText)
        }
    }
    
    // MARK: - Helper: Add Custom Time
    
    private func addCustomTime() {
        // Convert selected Date to ISO8601 string
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone.current
        let isoString = isoFormatter.string(from: selectedDate)
        
        // Create ProposedSlot with custom time
        let newSlot = ProposedSlot(time: isoString, venue: nil)
        
        // Avoid duplicates
        if !selectedTimes.contains(where: { $0.time == newSlot.time }) {
            selectedTimes.insert(newSlot, at: 0) // Add to top of list
        }
        
        // Reset picker for next use
        selectedDate = Date()
    }
}

// MARK: - Custom Time Picker Sheet

/// Modal sheet for picking custom date/time
private struct CustomTimePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    let onSave: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: KairosAuth.Spacing.large) {
                    // Instructions
                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                        Text("Pick a time that works for you")
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundStyle(KairosAuth.Color.primaryText)
                        
                        Text("You can add multiple options to give everyone flexibility")
                            .font(KairosAuth.Typography.body)
                            .foregroundStyle(KairosAuth.Color.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
                    
                    // Date Picker
                    DatePicker(
                        "Select Date & Time",
                        selection: $selectedDate,
                        in: Date()..., // Only future dates
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .tint(KairosAuth.Color.accent)
                    .padding(KairosAuth.Spacing.cardPadding)
                    .background(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                            .fill(KairosAuth.Color.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                                    .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
                    
                    // Preview of selected time
                    VStack(spacing: KairosAuth.Spacing.small) {
                        Text("You're suggesting:")
                            .font(KairosAuth.Typography.statusBadge)
                            .foregroundStyle(KairosAuth.Color.tertiaryText)
                        
                        Text(formatPreviewDate(selectedDate))
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundStyle(KairosAuth.Color.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(KairosAuth.Spacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                            .fill(KairosAuth.Color.accent.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                    .stroke(KairosAuth.Color.accent, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
                    
                    Spacer()
                }
                .padding(.top, KairosAuth.Spacing.extraLarge)
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
                    Text("Add Time")
                        .font(KairosAuth.Typography.screenTitle)
                        .foregroundColor(KairosAuth.Color.white)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(KairosAuth.Color.accent)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave()
                        dismiss()
                    }
                    .foregroundColor(KairosAuth.Color.accent)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func formatPreviewDate(_ date: Date) -> String {
        return DateFormatting.formatConfirmationDateTime(date)
    }
}

// MARK: - Step 3: Venues

/// Step 3: WHERE - Select venue options
struct VenuesStep: View {
    @Binding var selectedVenues: [VenueInfo]
    let intent: IntentTemplate?

    // Mock venue options - will be replaced with POI search + Amiqo suggestions
    // CRITICAL: Use fixed UUIDs so selection state works correctly
    // TODO(Phase 4 - POI Integration):
    //   - Replace with: await vm.searchPOI(query: searchText, category: intent.venue_types, userLocation)
    //   - Venue IDs will be real POI database UUIDs (from /items/poi collection)
    //   - These UUIDs are shared references: Alice's app, Bob's web app, and backend FSM all use same POI IDs
    //   - Backend can look up venue details: GET /items/poi/{uuid}
    //   - See: /docs/01-data-model.md for POI structure
    private static let mockVenues: [VenueInfo] = [
        VenueInfo(id: UUID(uuidString: "880e8400-e29b-41d4-a716-446655440001")!, name: "Philz Coffee", lat: 37.7749, lon: -122.4194, address: "201 Berry St", category: "cafe", price_band: 2),
        VenueInfo(id: UUID(uuidString: "880e8400-e29b-41d4-a716-446655440002")!, name: "Blue Bottle Coffee", lat: 37.7858, lon: -122.4064, address: "66 Mint St", category: "cafe", price_band: 3),
        VenueInfo(id: UUID(uuidString: "880e8400-e29b-41d4-a716-446655440003")!, name: "Sightglass Coffee", lat: 37.7735, lon: -122.4042, address: "270 7th St", category: "cafe", price_band: 2)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.large) {
            // Section header
            HStack(spacing: KairosAuth.Spacing.small) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: KairosAuth.IconSize.cardIcon))
                    .foregroundStyle(KairosAuth.Color.accent)
                    .accessibilityHidden(true)
                Text("Where should you meet?")
                    .font(KairosAuth.Typography.cardTitle)
                    .foregroundStyle(KairosAuth.Color.primaryText)
            }

            Text("Select all venues that work")
                .font(KairosAuth.Typography.itemSubtitle)
                .foregroundStyle(KairosAuth.Color.secondaryText)

            // Venue cards
            VStack(spacing: KairosAuth.Spacing.medium) {
                ForEach(Self.mockVenues, id: \.id) { venue in
                    VenueOptionCard(
                        venue: venue,
                        isSelected: selectedVenues.contains(where: { $0.id == venue.id }),
                        onToggle: {
                            if let index = selectedVenues.firstIndex(where: { $0.id == venue.id }) {
                                selectedVenues.remove(at: index)
                            } else {
                                selectedVenues.append(venue)
                            }
                        }
                    )
                }
            }

            // Amiqo suggestion button
            Button(action: {}) {
                HStack(spacing: KairosAuth.Spacing.small) {
                    Image(systemName: "sparkles")
                        .font(.system(size: KairosAuth.IconSize.itemIcon))
                        .accessibilityHidden(true)
                    Text("Ask Amiqo for venue suggestions")
                        .font(KairosAuth.Typography.buttonLabel)
                }
                .foregroundStyle(KairosAuth.Color.accent)
                .frame(maxWidth: .infinity)
                .padding(KairosAuth.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                        .fill(KairosAuth.Color.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                .stroke(KairosAuth.Color.accent.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
}

// MARK: - Step 4: Review

/// Step 4: REVIEW - Summary and send invitations
struct ReviewStep: View {
    @ObservedObject var vm: AppVM
    let participants: [PlanParticipant]
    let intent: IntentTemplate?
    let times: [ProposedSlot]
    let venues: [VenueInfo]
    let onSend: () -> Void
    let onEdit: (CreateProposalFlow.Step) -> Void  // NEW: Callback to navigate to step for editing
    
    // Validation: Ensure all required fields are filled
    private var canSendPlan: Bool {
        !participants.isEmpty &&
        intent != nil &&
        !times.isEmpty &&
        !venues.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
            // Header
            HStack(spacing: KairosAuth.Spacing.small) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: KairosAuth.IconSize.cardIcon))
                    .foregroundStyle(KairosAuth.Color.accent)
                    .accessibilityHidden(true)
                Text("Review & Send")
                    .font(KairosAuth.Typography.cardTitle)
                    .foregroundStyle(KairosAuth.Color.primaryText)
            }

            // Editable summary cards
            VStack(spacing: KairosAuth.Spacing.small) {
                // WHO Card
                ReviewCard(
                    icon: "person.2.fill",
                    title: "WHO",
                    summary: participantsSummary,
                    details: participantsDetails
                ) {
                    onEdit(.participants)
                }
                
                // WHAT Card
                if let intent = intent {
                    ReviewCard(
                        emoji: intent.emoji,
                        title: "WHAT",
                        summary: intent.name,
                        details: "\(intent.duration_minutes) minutes"
                    ) {
                        onEdit(.intentAndTimes)
                    }
                }
                
                // WHEN Card
                ReviewCard(
                    icon: "clock.fill",
                    title: "WHEN",
                    summary: timesSummary,
                    details: timesDetails
                ) {
                    onEdit(.intentAndTimes)
                }
                
                // WHERE Card
                ReviewCard(
                    icon: "mappin.circle.fill",
                    title: "WHERE",
                    summary: venuesSummary,
                    details: venuesDetails
                ) {
                    onEdit(.venues)
                }
            }

            Spacer()
            
            // AI Suggestions Section (Task 28 - Plus tier feature)
            aiSuggestionsSection

            // Send button (disabled if validation fails)
            Button(action: onSend) {
                HStack {
                    Image(systemName: "paperplane.fill")
                        .accessibilityHidden(true)
                    Text("Send Invites")
                        .font(KairosAuth.Typography.buttonLabel)
                }
                .foregroundStyle(canSendPlan ? KairosAuth.Color.buttonText : KairosAuth.Color.tertiaryText)
                .frame(maxWidth: .infinity)
                .padding(KairosAuth.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                        .fill(canSendPlan ? KairosAuth.Color.accent : KairosAuth.Color.cardBackground)
                )
            }
            .disabled(!canSendPlan)
            .opacity(canSendPlan ? 1.0 : 0.6)
            .shadow(color: canSendPlan ? KairosAuth.Color.shadowMedium : .clear, radius: 8, y: 4)
        }
    }
    
    // MARK: - Summary Formatters
    
    private var participantsSummary: String {
        "\(participants.count) \(participants.count == 1 ? "person" : "people")"
    }
    
    private var participantsDetails: String {
        participants.map(\.name).joined(separator: "\n")
    }
    
    private var timesSummary: String {
        "\(times.count) time \(times.count == 1 ? "option" : "options")"
    }
    
    private var timesDetails: String {
        guard !times.isEmpty else { return "No times selected" }
        
        return times.compactMap { slot in
            guard let date = slot.date else { return nil }
            return DateFormatting.formatEventDateTime(date)
        }.joined(separator: "\n")
    }
    
    private var venuesSummary: String {
        "\(venues.count) \(venues.count == 1 ? "venue" : "venues")"
    }
    
    private var venuesDetails: String {
        guard !venues.isEmpty else { return "No venues selected" }
        return venues.map(\.name).joined(separator: "\n")
    }
    
    // MARK: - AI Suggestions (Task 28)
    
    @ViewBuilder
    private var aiSuggestionsSection: some View {
        if vm.isPlusUser {
            // Plus user: Show AI button
            Button(action: generateAISuggestions) {
                HStack(spacing: KairosAuth.Spacing.small) {
                    if vm.isLoadingAI {
                        ProgressView()
                            .tint(KairosAuth.Color.accent)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: KairosAuth.IconSize.button))
                            .accessibilityHidden(true)
                    }
                    
                    Text(vm.isLoadingAI ? "Generating suggestions..." : "✨ Get AI Suggestions")
                        .font(KairosAuth.Typography.buttonLabel)
                }
                .foregroundStyle(vm.isLoadingAI ? KairosAuth.Color.secondaryText : KairosAuth.Color.accent)
                .frame(maxWidth: .infinity)
                .padding(KairosAuth.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                        .fill(KairosAuth.Color.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                .stroke(KairosAuth.Color.accent.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .disabled(vm.isLoadingAI || !canSendPlan)
        } else {
            // Free user: Show paywall teaser
            VStack(spacing: KairosAuth.Spacing.small) {
                HStack(spacing: KairosAuth.Spacing.small) {
                    Image(systemName: "sparkles")
                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                        .foregroundStyle(KairosAuth.Color.accent)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("✨ AI-Powered Suggestions")
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundStyle(KairosAuth.Color.primaryText)
                        
                        Text("Get smart time & venue recommendations")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundStyle(KairosAuth.Color.secondaryText)
                    }
                    
                    Spacer()
                }
                
                Button(action: { vm.showPaywall = true }) {
                    Text("Upgrade to Plus")
                        .font(KairosAuth.Typography.buttonLabel)
                        .foregroundStyle(KairosAuth.Color.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KairosAuth.Spacing.small)
                        .background(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                .fill(KairosAuth.Color.accent.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                        .stroke(KairosAuth.Color.accent.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            }
            .padding(KairosAuth.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                    .fill(KairosAuth.Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                            .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                    )
            )
        }
    }
    
    private func generateAISuggestions() {
        // Create draft plan from current selections
        let draft = DraftPlan(
            participants: participants,
            intent: intent,  // Already IntentTemplate?
            times: times,
            venues: venues
        )
        
        Task {
            await vm.generateAIProposal(for: draft)
        }
    }
}

// MARK: - Supporting Components

/// Intent template button for grid
struct IntentTemplateButton: View {
    let template: IntentTemplate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: KairosAuth.Spacing.small) {
                // SF Symbol icon with theme-aware color
                Image(systemName: template.iconName)
                    .font(.system(size: KairosAuth.IconSize.cardIcon))
                    .foregroundColor(isSelected ? .white : template.iconColor)
                    .accessibilityHidden(true)

                // Title
                Text(template.name)
                    .font(KairosAuth.Typography.statusBadge)
                    .foregroundStyle(isSelected ? .white : KairosAuth.Color.primaryText)
                
                // Duration (optional metadata)
                if !isSelected {
                    Text(template.durationText)
                        .font(KairosAuth.Typography.timestamp)
                        .foregroundStyle(KairosAuth.Color.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                    .fill(isSelected ? KairosAuth.Color.accent : KairosAuth.Color.itemBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                            .stroke(isSelected ? KairosAuth.Color.accent : KairosAuth.Color.cardBorder, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Manual Participant Entry Sheet

struct ManualParticipantSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedParticipants: [PlanParticipant]
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var note = ""
    @State private var showingValidationError = false
    @State private var validationMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: KairosAuth.Spacing.large) {
                Text("Add someone by email or phone number. They'll get an invite link even if they don't have the app yet.")
                    .font(KairosAuth.Typography.body)
                    .foregroundStyle(KairosAuth.Color.secondaryText)
                    .padding(.bottom, KairosAuth.Spacing.small)
                
                // Name field
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                    Text("Name")
                        .font(KairosAuth.Typography.fieldLabel)
                        .foregroundStyle(KairosAuth.Color.primaryText)
                    
                    TextField("Full name", text: $name)
                        .font(KairosAuth.Typography.fieldInput)
                        .foregroundStyle(KairosAuth.Color.primaryText)
                        .padding(KairosAuth.Spacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                .fill(KairosAuth.Color.fieldBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                        .stroke(KairosAuth.Color.fieldBorder, lineWidth: 1)
                                )
                        )
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                }
                
                // Email field
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                    Text("Email")
                        .font(KairosAuth.Typography.fieldLabel)
                        .foregroundStyle(KairosAuth.Color.primaryText)
                    
                    TextField("email@example.com", text: $email)
                        .font(KairosAuth.Typography.fieldInput)
                        .foregroundStyle(KairosAuth.Color.primaryText)
                        .padding(KairosAuth.Spacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                .fill(KairosAuth.Color.fieldBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                        .stroke(KairosAuth.Color.fieldBorder, lineWidth: 1)
                                )
                        )
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                
                // Phone field
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                    HStack {
                        Text("Phone")
                            .font(KairosAuth.Typography.fieldLabel)
                            .foregroundStyle(KairosAuth.Color.primaryText)
                        Text("(instead of email)")
                            .font(KairosAuth.Typography.timestamp)
                            .foregroundStyle(KairosAuth.Color.tertiaryText)
                    }
                    
                    TextField("+1 (555) 123-4567", text: $phone)
                        .font(KairosAuth.Typography.fieldInput)
                        .foregroundStyle(KairosAuth.Color.primaryText)
                        .padding(KairosAuth.Spacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                .fill(KairosAuth.Color.fieldBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                        .stroke(KairosAuth.Color.fieldBorder, lineWidth: 1)
                                )
                        )
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }
                
                // Validation error
                if showingValidationError {
                    HStack(spacing: KairosAuth.Spacing.small) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: KairosAuth.IconSize.badge))
                            .foregroundStyle(KairosAuth.Color.teal)
                            .accessibilityHidden(true)
                        Text(validationMessage)
                            .font(KairosAuth.Typography.bodySmall)
                            .foregroundStyle(KairosAuth.Color.secondaryText)
                    }
                    .padding(KairosAuth.Spacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                            .fill(KairosAuth.Color.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                                    .stroke(KairosAuth.Color.teal.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                Spacer()
            }
            .padding(KairosAuth.Spacing.horizontalPadding)
            .navigationTitle("Add Participant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(KairosAuth.Color.secondaryText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addParticipant()
                    }
                    .foregroundStyle(KairosAuth.Color.accent)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func addParticipant() {
        // Validate
        guard !name.isEmpty else {
            showValidation("Please enter a name")
            return
        }
        
        guard !email.isEmpty || !phone.isEmpty else {
            showValidation("Please enter either an email or phone number")
            return
        }
        
        if !email.isEmpty && !isValidEmail(email) {
            showValidation("Please enter a valid email address")
            return
        }
        
        // Create participant
        let participant = PlanParticipant(
            user_id: UUID(), // Generate temp UUID for non-Kairos users
            name: name,
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone
        )
        
        selectedParticipants.append(participant)
        dismiss()
    }
    
    private func showValidation(_ message: String) {
        validationMessage = message
        showingValidationError = true
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showingValidationError = false
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}

/// Time slot checkbox row
struct TimeSlotCheckbox: View {
    let timeSlot: ProposedSlot
    let isSelected: Bool
    let onToggle: () -> Void

    private var formattedDate: String {
        guard let date = timeSlot.date else { return timeSlot.time }
        return DateFormatting.formatEventDateTime(date)
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: KairosAuth.Spacing.medium) {
                // Checkbox (filled circle when selected)
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(KairosAuth.Color.accent)
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .stroke(KairosAuth.Color.tertiaryText, lineWidth: 2)
                            .frame(width: 28, height: 28)
                    }
                }
                .accessibilityHidden(true)

                // Time text
                Text(formattedDate)
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundStyle(KairosAuth.Color.primaryText)

                Spacer()
            }
            .padding(KairosAuth.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                    .fill(isSelected ? KairosAuth.Color.selectedBackground : KairosAuth.Color.itemBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                            .stroke(isSelected ? KairosAuth.Color.accent.opacity(0.3) : KairosAuth.Color.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

/// Venue option card with toggle
struct VenueOptionCard: View {
    let venue: VenueInfo
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: KairosAuth.Spacing.medium) {
                // Venue info
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                    Text(venue.name)
                        .font(KairosAuth.Typography.itemTitle)
                        .foregroundStyle(KairosAuth.Color.primaryText)

                    if let address = venue.address {
                        Text(address)
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundStyle(KairosAuth.Color.tertiaryText)
                            .lineLimit(1)
                    }

                    // Distance & rating row
                    HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                        HStack(spacing: KairosAuth.Spacing.xs) {
                            Image(systemName: "location.fill")
                                .font(KairosAuth.Typography.statusBadge)
                                .foregroundStyle(KairosAuth.Color.teal)
                                .accessibilityHidden(true)
                            Text("0.3 mi")
                                .font(KairosAuth.Typography.statusBadge)
                                .foregroundStyle(KairosAuth.Color.teal)
                        }

                        if let priceBand = venue.price_band {
                            Text(String(repeating: "$", count: priceBand))
                                .font(KairosAuth.Typography.statusBadge)
                                .foregroundStyle(KairosAuth.Color.secondaryText)
                        }
                    }
                }

                Spacer()

                // Selection indicator (matches TimeSlotCheckbox pattern)
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(KairosAuth.Color.accent)
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .stroke(KairosAuth.Color.tertiaryText, lineWidth: 2)
                            .frame(width: 28, height: 28)
                    }
                }
                .accessibilityHidden(true)
            }
            .padding(KairosAuth.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                    .fill(isSelected ? KairosAuth.Color.selectedBackground : KairosAuth.Color.itemBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                            .stroke(isSelected ? KairosAuth.Color.accent.opacity(0.3) : KairosAuth.Color.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

/// Summary section for review step
struct SummarySection: View {
    let title: String
    let icon: String
    let content: String

    var body: some View {
        HStack(spacing: KairosAuth.Spacing.medium) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: KairosAuth.IconSize.itemIcon))
                .foregroundStyle(KairosAuth.Color.teal)
                .frame(width: 32)
                .accessibilityHidden(true)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(KairosAuth.Typography.statusBadge)
                    .foregroundStyle(KairosAuth.Color.tertiaryText)

                Text(content)
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundStyle(KairosAuth.Color.primaryText)
            }

            Spacer()
        }
        .padding(KairosAuth.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                .fill(KairosAuth.Color.itemBackground)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Editable card for Review step - tappable to navigate back and edit
struct ReviewCard: View {
    let icon: String?
    let emoji: String?
    let title: String
    let summary: String
    let details: String?
    let onChange: () -> Void
    
    // Init for SF Symbol icon
    init(icon: String, title: String, summary: String, details: String? = nil, onChange: @escaping () -> Void) {
        self.icon = icon
        self.emoji = nil
        self.title = title
        self.summary = summary
        self.details = details
        self.onChange = onChange
    }
    
    // Init for emoji icon
    init(emoji: String, title: String, summary: String, details: String? = nil, onChange: @escaping () -> Void) {
        self.icon = nil
        self.emoji = emoji
        self.title = title
        self.summary = summary
        self.details = details
        self.onChange = onChange
    }
    
    var body: some View {
        Button(action: onChange) {
            HStack(spacing: KairosAuth.Spacing.small) {
                // Icon/Emoji (32pt width for tighter alignment)
                if let emoji = emoji {
                    Text(emoji)
                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                        .frame(width: 32, alignment: .center)
                        .accessibilityHidden(true)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: KairosAuth.IconSize.itemIcon))
                        .foregroundStyle(KairosAuth.Color.teal)
                        .frame(width: 32, alignment: .center)
                        .accessibilityHidden(true)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(KairosAuth.Typography.statusBadge)
                        .foregroundStyle(KairosAuth.Color.tertiaryText)
                    
                    Text(summary)
                        .font(KairosAuth.Typography.itemTitle)
                        .foregroundStyle(KairosAuth.Color.primaryText)
                        .lineLimit(1)
                    
                    if let details = details, !details.isEmpty {
                        Text(details)
                            .font(KairosAuth.Typography.statusBadge)
                            .foregroundStyle(KairosAuth.Color.secondaryText)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                // Change indicator (text + chevron)
                HStack(spacing: 4) {
                    Text("Change")
                        .font(KairosAuth.Typography.buttonLabel)
                        .foregroundStyle(KairosAuth.Color.accent)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: KairosAuth.IconSize.badge, weight: .semibold))
                        .foregroundStyle(KairosAuth.Color.accent)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, KairosAuth.Spacing.medium)
            .padding(.vertical, KairosAuth.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                    .fill(KairosAuth.Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                            .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain) // Prevent default button styling that would override our design
        .accessibilityHint("Double tap to edit \(title.lowercased()) details")
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selected: [PlanParticipant] = []
        var body: some View {
            ParticipantsStep(vm: AppVM.forPreviews, selectedParticipants: $selected)
                .padding()
                .background(
                    KairosAuth.Color.backgroundGradient(),
                    ignoresSafeAreaEdges: .all
                )
        }
    }
    return PreviewWrapper()
        .preferredColorScheme(.dark)
}
