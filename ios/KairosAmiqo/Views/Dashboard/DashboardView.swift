import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

/// Navigation destination for Dashboard full lists
enum DashboardDestination: Hashable {
    case activeInvitationsList
    case upcomingEventsList
    case pastEventsList
}

/// New Dashboard with Blue-Cyan design system
/// Shows greeting, smart hero card, upcoming events, and recent invitations
struct DashboardView: View {
    @ObservedObject var vm: AppVM
    var onScrollOffsetChange: ((CGFloat) -> Void)? = nil // Tab bar auto-hide callback
    
    @State private var showingTutorial = false
    @State private var isRefreshing = false
    @State private var showActiveInvitationsHint = DashboardHintHelper.shouldShow(.activePlansExplainer)
    @State private var showUpcomingEventsHint = DashboardHintHelper.shouldShow(.upcomingEventsExplainer)

    // Navigation state for horizontal slide navigation
    @State private var navigationPath = NavigationPath()

    // Global modal state - only ONE modal at a time
    @State private var isAnyModalPresented = false

    // Modal content state - stored at DashboardView level (uses real API types)
    enum ModalContent {
        case invitation(Negotiation)
        case event(EventDTO)
        case pastEvent(EventDTO) // Past events are also EventDTO
    }
    @State private var modalContent: ModalContent?

    // MARK: - Data Filters (from real mock server data)

    /// Active invitations from backend (vm.items filtered by state)
    /// Note: Uses 'state' field (negotiation lifecycle) not 'status' (participant-level)
    var activeInvitations: [Negotiation] {
        vm.items.filter { negotiation in
            let state = negotiation.state?.lowercased() ?? ""
            return state == "awaiting_invites" || state == "awaiting_replies"
        }
    }

    /// Upcoming events from mock server (vm.events filtered by future date + confirmed/pending)
    private var upcomingEvents: [EventDTO] {
        let now = Date()
        return vm.events.filter { event in
            guard let startDate = event.startDate else { return false }
            let status = event.status?.lowercased() ?? ""
            return startDate > now && (status == "confirmed" || status == "pending")
        }
        .sorted { ($0.startDate ?? Date()) < ($1.startDate ?? Date()) }
    }

    /// Past events from mock server (vm.events filtered by past date)
    private var pastEvents: [EventDTO] {
        let now = Date()
        return vm.events.filter { event in
            guard let startDate = event.startDate else { return false }
            return startDate <= now
        }
        .sorted { ($0.startDate ?? Date()) > ($1.startDate ?? Date()) }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: KairosAuth.Spacing.cardSpacing) {
                            // Scroll tracking anchor
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: geo.frame(in: .global).minY
                                )
                            }
                            .frame(height: 0)
                            
                            // Greeting subtitle (below nav bar title)
                            Text("Ready to send invites?")
                        .font(KairosAuth.Typography.cardTitle)
                        .foregroundColor(KairosAuth.Color.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                        .padding(.top, KairosAuth.Spacing.small)

                    // Smart Hero Card: Create Invitation vs Active Invites
                    if activeInvitations.isEmpty {
                        // First-time user: Create new invitation
                        HeroCreateCard(
                            vm: vm,
                            onSelectTemplate: { template in
                                // Dashboard template shortcut → open CreateProposalFlow with pre-selected template
                                vm.selectedTemplate = template
                                vm.showingCreateProposal = true
                            },
                            onDismissTutorialHint: {
                                vm.dismissTutorialHint()
                            },
                            showTutorialHint: !vm.hasSeenTutorialHint
                        )
                        .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                    } else {
                        // Returning user: Active invites
                        VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                            // Hint: What are Active Invites?
                            if showActiveInvitationsHint {
                                DashboardHint(
                                    icon: "info.circle.fill",
                                    message: "Invites are live—coordinate times with friends until everyone agrees.",
                                    accentColor: KairosAuth.Color.accent,
                                    onDismiss: {
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            showActiveInvitationsHint = false
                                            DashboardHintHelper.markAsDismissed(.activePlansExplainer)
                                        }
                                    }
                                )
                            }
                            ActiveInvitationsCard(
                                invitations: activeInvitations,
                                onSelectInvitation: { invitation in
                                    modalContent = .invitation(invitation)
                                    isAnyModalPresented = true
                                },
                                onCreateNew: {
                                    // Use unified flow (same as template tiles)
                                    vm.selectedTemplate = nil
                                    vm.showingCreateProposal = true
                                },
                                onTapBackground: {
                                    navigationPath.append(DashboardDestination.activeInvitationsList)
                                },
                                isExpanded: Binding(
                                    get: { vm.isCardExpanded("active-invitations") },
                                    set: { newValue in
                                        vm.toggleCardExpansion("active-invitations")
                                        if newValue {
                                            withAnimation(.easeOut(duration: 0.4)) {
                                                scrollProxy.scrollTo("active-invitations", anchor: .top)
                                            }
                                        }
                                    }
                                )
                            )
                            .id("active-invitations")

                            // Quick Create Templates (compact row for returning users)
                            compactTemplateShortcuts
                        }
                        .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                    }

                    // Upcoming Events Card
                    VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                        // Hint: What are Upcoming Events? (only show if user has events)
                        if showUpcomingEventsHint && !upcomingEvents.isEmpty {
                            DashboardHint(
                                icon: "calendar.badge.checkmark",
                                message: "Events are confirmed and scheduled—ready to happen! No action needed.",
                                accentColor: KairosAuth.Color.teal,
                                onDismiss: {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        showUpcomingEventsHint = false
                                        DashboardHintHelper.markAsDismissed(.upcomingEventsExplainer)
                                    }
                                }
                            )
                        }

                        UpcomingEventsCard(
                            events: upcomingEvents,
                            onSelectEvent: { event in
                                modalContent = .event(event)
                                isAnyModalPresented = true
                            },
                            onTapBackground: {
                                navigationPath.append(DashboardDestination.upcomingEventsList)
                            },
                            isExpanded: Binding(
                                get: { vm.isCardExpanded("upcoming-events") },
                                set: { newValue in
                                    vm.toggleCardExpansion("upcoming-events")
                                    if newValue {
                                        withAnimation(.easeOut(duration: 0.4)) {
                                            scrollProxy.scrollTo("upcoming-events", anchor: .top)
                                        }
                                    }
                                }
                            )
                        )
                        .id("upcoming-events")
                    }
                    .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)

                    // Past Events Card (collapsed by default)
                    if !pastEvents.isEmpty {
                        PastEventsCard(
                            events: pastEvents,
                            onSelectEvent: { event in
                                modalContent = .pastEvent(event)
                                isAnyModalPresented = true
                            },
                            onReschedule: { event in
                                print("🔄 Reschedule: \(event.title)")
                                // TODO: Open Create Invitation flow with pre-filled data
                            },
                            onTapBackground: {
                                navigationPath.append(DashboardDestination.pastEventsList)
                            },
                            isExpanded: Binding(
                                get: { vm.isCardExpanded("past-events") },
                                set: { newValue in
                                    vm.toggleCardExpansion("past-events")
                                    if newValue {
                                        withAnimation(.easeOut(duration: 0.4)) {
                                            scrollProxy.scrollTo("past-events", anchor: .top)
                                        }
                                    }
                                }
                            )
                        )
                        .id("past-events")
                        .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                        }
                        } // Close VStack
                        .padding(.bottom, 80) // Extra padding for tab bar space
                    } // Close ScrollView
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        onScrollOffsetChange?(offset)
                    }
            .task {
                // Load data on initial appearance
                await refreshDashboard()
            }
            .refreshable {
                await refreshDashboard()
            }
            // Spatial depth effect - blur and scale back when modal presented
            .blur(radius: isAnyModalPresented ? 8 : 0)
            .scaleEffect(isAnyModalPresented ? 0.95 : 1.0)
            .animation(KairosAuth.Animation.modalPresent, value: isAnyModalPresented)
            } // Close ScrollViewReader
            .background(
                KairosAuth.Color.backgroundGradient(),
                ignoresSafeAreaEdges: .all
            )

            // Dark overlay when modal presented - lets blurred content show through
            if isAnyModalPresented {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KairosAuth.Color.scrim, ignoresSafeAreaEdges: .all)
                    .onTapGesture {
                        withAnimation(KairosAuth.Animation.modalDismiss) {
                            isAnyModalPresented = false
                            modalContent = nil
                        }
                    }
            }

            // Modal - rendered at top level, outside blurred ScrollView
            if isAnyModalPresented, let content = modalContent {
                HeroExpansionModal(isPresented: Binding(
                    get: { isAnyModalPresented },
                    set: { newValue in
                        isAnyModalPresented = newValue
                        if !newValue {
                            modalContent = nil
                        }
                    }
                )) {
                    switch content {
                    case .invitation(let invitation):
                        PlanDetailModal(plan: invitation, isPresented: Binding(
                            get: { isAnyModalPresented },
                            set: { newValue in
                                isAnyModalPresented = newValue
                                if !newValue {
                                    modalContent = nil
                                }
                            }
                        ), vm: vm) // Pass vm directly as parameter
                    case .event(let event):
                        EventDetailModal(
                            event: event,
                            isPresented: Binding(
                                get: { isAnyModalPresented },
                                set: { newValue in
                                    isAnyModalPresented = newValue
                                    if !newValue {
                                        modalContent = nil
                                    }
                                }
                            ),
                            onAddToCalendar: {
                                Task { await vm.addEventToCalendar(event) }
                            },
                            onNavigate: {
                                guard let venue = event.venue else { return }
                                let query = "\(venue.name), \(venue.address)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                if let url = URL(string: "http://maps.apple.com/?q=\(query)") {
                                    UIApplication.shared.open(url)
                                }
                            },
                            onShare: {
                                // TODO(Task 14): Implement .ics file sharing
                                // guard let ics = event.ics_url else { return }
                                // Share .ics file via UIActivityViewController
                                print("📤 Share event: \(event.title)")
                            }
                        )
                    case .pastEvent(let event):
                        PastEventDetailModal(
                            event: event,
                            onReschedule: {
                                // TODO: Handle reschedule
                                isAnyModalPresented = false
                                modalContent = nil
                            },
                            isPresented: Binding(
                                get: { isAnyModalPresented },
                                set: { newValue in
                                    isAnyModalPresented = newValue
                                    if !newValue {
                                        modalContent = nil
                                    }
                                }
                            )
                        )
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(greetingText)
                    .font(KairosAuth.Typography.screenTitle)
                    .foregroundStyle(KairosAuth.Color.primaryText)
            }
            
            // Profile button (consistent with other screens)
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: vm.openProfile) {
                    Image(systemName: "person.circle.fill")
                        .font(Font.system(size: KairosAuth.IconSize.profileButton))
                        .foregroundColor(KairosAuth.Color.accent)
                }
                .accessibilityLabel("Profile")
                .accessibilityHint("View your profile, settings, and help")
            }
        }
        .navigationDestination(for: DashboardDestination.self) { destination in
            switch destination {
            case .activeInvitationsList:
                ActiveInvitationsListView(
                    invitations: activeInvitations,
                    onSelectInvitation: { invitation in
                        print("📋 Selected invite from list: \(invitation.title ?? "Untitled")")
                        modalContent = .invitation(invitation)
                        isAnyModalPresented = true
                    },
                    onCreateNew: {
                        print("➕ Create new invite from list")
                        // TODO: Navigate to Create Invitation flow
                    },
                    vm: vm
                )

            case .upcomingEventsList:
                UpcomingEventsListView(
                    events: upcomingEvents,
                    onSelectEvent: { event in
                        modalContent = .event(event)
                        isAnyModalPresented = true
                    }
                )

            case .pastEventsList:
                PastEventsListView(
                    events: pastEvents,
                    onSelectEvent: { event in
                        modalContent = .pastEvent(event)
                        isAnyModalPresented = true
                    },
                    onReschedule: { event in
                        print("🔄 Reschedule from list: \(event.title)")
                        // TODO: Open Create Plan flow with pre-filled data
                    }
                )
            }
        }
        .sheet(isPresented: $showingTutorial) {
            TutorialView(onDismiss: {
                showingTutorial = false
            })
        }
        .sheet(isPresented: Binding(
            get: { vm.showingCreateProposal },
            set: { vm.showingCreateProposal = $0 }
        )) {
            CreateProposalFlow(vm: vm, template: vm.selectedTemplate)
        }
        .sheet(isPresented: $vm.showDeepLinkedPlan) {
            // Deep linked plan modal (Task 16)
            if let planId = vm.selectedDeepLinkedPlanId,
               let plan = vm.items.first(where: { $0.id == planId }) {
                HeroExpansionModal(isPresented: $vm.showDeepLinkedPlan) {
                    PlanDetailModal(plan: plan, isPresented: $vm.showDeepLinkedPlan, vm: vm)
                }
            } else {
                                // Fallback if plan not found (shouldn't happen in normal flow)
                EmptyView()
            }
        }
        .preference(key: ModalVisibilityPreferenceKey.self, value: isAnyModalPresented)
    }  // Close NavigationStack
    }  // Close body

    // MARK: - Helpers
    
    /// Compact template shortcuts for returning users (horizontal row)
    private var compactTemplateShortcuts: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
            // Section header
            HStack {
                Image(systemName: "sparkles")
                    .font(Font.system(size: KairosAuth.IconSize.badge))
                    .foregroundStyle(KairosAuth.Color.accent)
                    .accessibilityHidden(true)
                Text("Quick Create")
                    .font(KairosAuth.Typography.cardSubtitle)
                    .foregroundStyle(KairosAuth.Color.secondaryText)
            }
            .padding(.horizontal, KairosAuth.Spacing.cardPadding)
            
            // Horizontal scrollable template row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: KairosAuth.Spacing.small) {
                    ForEach(vm.intentTemplates.prefix(8)) { template in
                        Button(action: {
                            vm.selectedTemplate = template
                            vm.showingCreateProposal = true
                        }) {
                            VStack(spacing: KairosAuth.Spacing.xs) {
                                // SF Symbol with theme-aware color
                                Image(systemName: template.iconName)
                                    .font(Font.system(size: 32))
                                    .foregroundColor(template.iconColor)
                                    .accessibilityHidden(true)
                                Text(template.name)
                                    .font(KairosAuth.Typography.statusBadge)
                                    .foregroundStyle(KairosAuth.Color.primaryText)
                                    .lineLimit(1)
                            }
                            .frame(width: 72, height: 72)
                            .background(KairosAuth.Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button))
                        }
                    }
                }
                .padding(.horizontal, KairosAuth.Spacing.cardPadding)
            }
        }
        .padding(.vertical, KairosAuth.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                .fill(KairosAuth.Color.cardBackground.opacity(0.5))
        )
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good Morning"
        case 12..<17:
            return "Good Afternoon"
        default:
            return "Good Evening"
        }
    }

    private func refreshDashboard() async {
        isRefreshing = true
        // Fetch real data from mock server (Phase 0-3) or Directus (Phase 4+)
        do {
            try await vm.fetchNegotiations()
        } catch {
            // Log error but don't block UI - dashboard can still show events
            print("⚠️ Failed to fetch negotiations: \(error)")
        }
        await vm.fetchEvents()
        await MainActor.run {
            isRefreshing = false
        }
    }
}

// MARK: - Previews

#Preview("Dashboard - First Time User") {
    @Previewable @State var vm: AppVM = {
        let vm = AppVM(forPreviews: true)
        vm.jwt = "PREVIEW_TOKEN"
        vm.items = [] // Empty = first-time user
        vm.hasSeenTutorialHint = false
        return vm
    }()
    DashboardView(vm: vm)
}

#Preview("Dashboard - Returning User") {
    @Previewable @State var vm: AppVM = {
        let vm = AppVM(forPreviews: true)
        vm.jwt = "PREVIEW_TOKEN"
        // Load sample data for preview
        vm.items = [
            Negotiation(id: UUID(), title: "Coffee with Alice", status: "active"),
            Negotiation(id: UUID(), title: "Team Lunch", status: "pending")
        ]
        vm.events = [
            EventDTO(
                id: UUID(),
                title: "Design Review",
                starts_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400)),
                status: "confirmed"
            )
        ]
        return vm
    }()
    DashboardView(vm: vm)
}
