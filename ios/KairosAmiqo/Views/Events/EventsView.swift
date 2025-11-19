import SwiftUI
import UIKit

/// Navigation destination for Events full lists (matches Dashboard pattern)
enum EventsDestination: Hashable {
    case todayList
    case thisWeekList
    case laterList
    case pastList // Separate destination for past events
}

/// Events tab — chronological view of confirmed plans
/// Rebuilt per EVENTS-TAB-IMPLEMENTATION-SPEC.md
struct EventsView: View {
    @ObservedObject var vm: AppVM
    var onScrollOffsetChange: ((CGFloat) -> Void)? = nil // Tab bar auto-hide callback
    
    @State private var expandedEventID: UUID?

    // Navigation state for horizontal slide (matches Dashboard)
    @State private var navigationPath = NavigationPath()

    // Modal state (matches Dashboard + Plans pattern)
    @State private var isModalPresented = false
    @State private var selectedEvent: EventDTO?

    @State private var alertMessage: AlertMessage?

    private var buckets: [EventBucket] { vm.eventBuckets }

    private var shouldShowPermissionCard: Bool {
        switch vm.calendarPermissionStatus {
        case .authorized, .fullAccess:
            return false
        default:
            return true
        }
    }

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
                        
                        if shouldShowPermissionCard {
                            CalendarPermissionCard(status: vm.calendarPermissionStatus) {
                                // TODO(Task 14): Request calendar permission
                                print("📅 Request calendar access")
                            }
                        }

                        content

                        Spacer(minLength: KairosAuth.Spacing.tabBarHeight * 1.25)
                    }
                    .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
                    .padding(.top, KairosAuth.Spacing.medium)
                    .padding(.bottom, 100)  // Adequate space above tab bar
                } // Close ScrollView
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    onScrollOffsetChange?(offset)
                }
                // Spatial depth effect - blur and scale back when modal presented (matches Dashboard)
                .blur(radius: isModalPresented ? 8 : 0)
                .scaleEffect(isModalPresented ? 0.95 : 1.0)
                .animation(KairosAuth.Animation.modalPresent, value: isModalPresented)

                // Dark overlay when modal presented (matches Dashboard)
                if isModalPresented {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(KairosAuth.Color.scrim, ignoresSafeAreaEdges: .all)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(KairosAuth.Animation.modalDismiss) {
                                isModalPresented = false
                                selectedEvent = nil
                            }
                        }
                }

                // Modal - rendered at top level (matches Dashboard + Plans pattern)
                if isModalPresented, let event = selectedEvent {
                    HeroExpansionModal(isPresented: $isModalPresented) {
                        EventDetailModal(
                            event: event,
                            isPresented: $isModalPresented,
                            onAddToCalendar: { handleAddToCalendar(for: event) },
                            onNavigate: { handleNavigate(for: event) },
                            onShare: { handleShare(event) }
                        )
                    }
                }
            } // Close ZStack
            .background(
                KairosAuth.Color.backgroundGradient(),
                ignoresSafeAreaEdges: .all
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Events")
                        .font(KairosAuth.Typography.screenTitle)
                        .foregroundColor(KairosAuth.Color.primaryText)
                        .shadow(color: KairosAuth.Color.brandTextShadow, radius: 8, x: 0, y: 2)
                        .shadow(color: KairosAuth.Color.brandTextShadow.opacity(0.4), radius: 4, x: 0, y: 1)
                }
                
                // Profile button (consistent with other screens)
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: vm.openProfile) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: KairosAuth.IconSize.profileButton))
                            .foregroundColor(KairosAuth.Color.accent)
                    }
                    .accessibilityLabel("Profile")
                    .accessibilityHint("View your profile, settings, and help")
                }
            }
            .navigationDestination(for: EventsDestination.self) { destination in
                switch destination {
                case .todayList:
                    // Show events from "today" bucket
                    TodayEventsListView(events: buckets.first(where: { $0.kind == .today })?.events ?? [], vm: vm)
                case .thisWeekList:
                    // Show events from "tomorrow" + "thisWeek" buckets combined
                    let tomorrowEvents = buckets.first(where: { $0.kind == .tomorrow })?.events ?? []
                    let thisWeekEvents = buckets.first(where: { $0.kind == .thisWeek })?.events ?? []
                    ThisWeekEventsListView(events: tomorrowEvents + thisWeekEvents, vm: vm)
                case .laterList:
                    // Show events from "upcoming" + "later" buckets combined (not "past")
                    let upcomingEvents = buckets.first(where: { $0.kind == .upcoming })?.events ?? []
                    let laterEvents = buckets.first(where: { $0.kind == .later })?.events ?? []
                    LaterEventsListView(events: upcomingEvents + laterEvents, vm: vm)
                case .pastList:
                    // Show events from "past" bucket
                    EventsPastListView(events: buckets.first(where: { $0.kind == .past })?.events ?? [], vm: vm)
                }
            }
            .task {
                if case .idle = vm.eventsState {
                    await vm.fetchEvents()
                }
                // Calendar permission checked on-demand when user taps "Add to Calendar"
            }
            .refreshable { await vm.fetchEvents() }
            .alert(item: $alertMessage) { message in
                Alert(title: Text(message.title), message: Text(message.body), dismissButton: .default(Text("OK")))
            }
        } // Close NavigationStack
        .tint(KairosAuth.Color.white) // Apply tint to NavigationStack for all Back buttons
    }

    @ViewBuilder
    private var content: some View {
        switch vm.eventsState {
        case .idle, .loading:
            ProgressView("Loading events…")
                .progressViewStyle(.circular)
                .foregroundStyle(KairosAuth.Color.primaryText)
                .padding(.top, KairosAuth.Spacing.large)
        case .empty:
            emptyState
        case let .error(message):
            errorState(message: message)
        case .loaded:
            if buckets.isEmpty {
                emptyState
            } else {
                VStack(spacing: KairosAuth.Spacing.extraLarge) {
                    ForEach(buckets) { bucket in
                        EventSection(
                            kind: bucket.kind,
                            count: bucket.events.count,
                            onViewAll: !bucket.events.isEmpty ? {
                                // Navigate based on bucket kind
                                switch bucket.kind {
                                case .today:
                                    navigationPath.append(EventsDestination.todayList)
                                case .tomorrow:
                                    navigationPath.append(EventsDestination.thisWeekList) // Same as thisWeek
                                case .thisWeek:
                                    navigationPath.append(EventsDestination.thisWeekList)
                                case .later:
                                    navigationPath.append(EventsDestination.laterList)
                                case .upcoming:
                                    navigationPath.append(EventsDestination.laterList) // Group with later
                                case .past:
                                    navigationPath.append(EventsDestination.pastList) // Past events get their own list
                                }
                            } : nil
                        ) {
                            // Show first 3 events only in collapsed view
                            ForEach(Array(bucket.events.prefix(3)), id: \.id) { event in
                                Button(action: {
                                    selectedEvent = event
                                    isModalPresented = true
                                }) {
                                    EventListItemCard(event: event)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No events yet",
            systemImage: "calendar.badge.plus",
            description: Text("Confirmed invitations will show up here once they're scheduled.")
        )
        .foregroundStyle(KairosAuth.Color.secondaryText)
        .padding(.top, KairosAuth.Spacing.extraLarge)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: KairosAuth.Spacing.medium) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(KairosAuth.Typography.itemTitle)
                .foregroundStyle(KairosAuth.Color.error)

            Button("Retry") {
                Task { await vm.fetchEvents() }
            }
            .buttonStyle(.kairosPrimary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                .fill(KairosAuth.Color.itemBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                        .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                )
        )
    }

    private func handleToggle(for event: EventDTO) {
        withAnimation(KairosAuth.Animation.uiUpdate) {
            if expandedEventID == event.id {
                expandedEventID = nil
            } else {
                expandedEventID = event.id
            }
        }
    }

    private func handleAddToCalendar(for event: EventDTO) {
        switch vm.calendarPermissionStatus {
        case .authorized, .fullAccess:
            Task {
                await vm.addEventToCalendar(event)
                await MainActor.run {
                    if vm.calendarError == nil {
                        alertMessage = AlertMessage(title: "Added to Calendar", body: "\(event.title) is now on your calendar.")
                    } else {
                        alertMessage = AlertMessage(title: "Calendar Error", body: vm.calendarError ?? "Unknown error")
                    }
                }
            }
        case .writeOnly:
            alertMessage = AlertMessage(
                title: "Limited Access",
                body: "Calendar access is write-only. Update permissions in Settings for best results."
            )
        default:
            // TODO(Task 14): Request calendar permission
            alertMessage = AlertMessage(
                title: "Calendar Permission Required",
                body: "Please enable calendar access in Settings to add events."
            )
        }
    }

    private func handleNavigate(for event: EventDTO) {
        let query = event.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "maps://?q=\(query)") else {
            alertMessage = AlertMessage(title: "Navigation Error", body: "Unable to open Maps for this event.")
            return
        }
        UIApplication.shared.open(url)
    }

    private func handleShare(_ event: EventDTO) {
        guard let ics = event.ics_url, !ics.isEmpty else {
            alertMessage = AlertMessage(title: "Unavailable", body: "This event does not include an ICS link yet.")
            return
        }
        // TODO(Task 14): Implement .ics file sharing
        print("📤 Share event: \(event.title)")
    }

    private struct AlertMessage: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }
}

// MARK: - Calendar Permission Card

private struct CalendarPermissionCard: View {
    let status: AppVM.CalendarAccessStatus
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
            Text(title)
                .font(KairosAuth.Typography.cardTitle)
                .foregroundStyle(KairosAuth.Color.primaryText)

            Text(message)
                .font(KairosAuth.Typography.itemSubtitle)
                .foregroundStyle(KairosAuth.Color.secondaryText)

            Button(buttonTitle) {
                switch status {
                case .denied, .writeOnly:
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                default:
                    action()
                }
            }
            .buttonStyle(.kairosPrimary)
        }
        .padding(KairosAuth.Spacing.cardContentPadding)
        .background(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                .fill(KairosAuth.Color.modalBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                        .stroke(KairosAuth.Color.modalBorder, lineWidth: 1)
                )
        )
    }

    private var title: String {
        switch status {
        case .notDetermined:
            return "Allow Calendar Access"
        case .denied:
            return "Calendar Access Required"
        case .restricted:
            return "Calendar Access Restricted"
        case .writeOnly:
            return "Limited Calendar Access"
        case .authorized, .fullAccess:
            return ""
        }
    }

    private var message: String {
        switch status {
        case .notDetermined:
            return "Enable calendar access so confirmed invitations auto-appear on your calendar."
        case .denied:
            return "Calendar access was denied. Enable it in Settings to save events."
        case .restricted:
            return "Calendar access is restricted by device settings or policies."
        case .writeOnly:
            return "Write-only access is active. Update permissions to manage events seamlessly."
        case .authorized, .fullAccess:
            return ""
        }
    }

    private var buttonTitle: String {
        switch status {
        case .denied, .writeOnly:
            return "Open Settings"
        default:
            return "Allow Access"
        }
    }
}

// MARK: - Section Header

private struct EventSection<Content: View>: View {
    let kind: EventBucket.Kind
    let count: Int
    let onViewAll: (() -> Void)? // Optional callback for "View All" button
    @ViewBuilder let content: Content

    @State private var isExpanded: Bool = false

    private var countText: String {
        if count == 0 {
            return "No events"
        } else if count == 1 {
            return "1 event"
        } else {
            return "\(count) events"
        }
    }

    private var emptyMessage: String {
        switch kind {
        case .today:
            return "No events scheduled for today. Enjoy your free time!"
        case .tomorrow:
            return "No events scheduled for tomorrow yet."
        case .thisWeek:
            return "No events this week. Time to send some invitations!"
        case .later:
            return "No future events scheduled."
        case .upcoming:
            return "No upcoming events at the moment."
        case .past:
            return "No past events to show."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card - always visible, tappable to expand/collapse
            Button(action: {
                withAnimation(KairosAuth.Animation.uiUpdate) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                    // Icon in circle (32pt icon, 48×48pt container)
                    Image(systemName: icon)
                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                        .foregroundStyle(accent)
                        .frame(width: 48, height: 48)
                        .background(accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityHidden(true)

                    // Title + subtitle
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title)
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundStyle(KairosAuth.Color.primaryText)

                        Text(subtitle)
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundStyle(KairosAuth.Color.secondaryText)
                    }

                    Spacer()

                    // Count badge
                    Text("\(count)")
                        .font(KairosAuth.Typography.cardTitle)
                        .foregroundColor(accent)
                        .frame(minWidth: 32, minHeight: 32)
                        .padding(.horizontal, 8)
                        .background(
                            Circle()
                                .fill(accent.opacity(0.15))
                        )

                    // Expand/collapse chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(KairosAuth.Typography.buttonIcon)
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                        .accessibilityHidden(true)
                }
                .padding(KairosAuth.Spacing.cardContentPadding)
                .background(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                        .fill(KairosAuth.Color.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                                .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                        )
                )
                .shadow(
                    color: KairosAuth.Shadow.cardColor,
                    radius: KairosAuth.Shadow.cardRadius,
                    y: KairosAuth.Shadow.cardY
                )
            }
            .buttonStyle(.plain)

            // Expanded content - scrollable list of events (max 3 visible)
            if isExpanded {
                VStack(spacing: KairosAuth.Spacing.medium) {
                    if count > 0 {
                        // Show up to 3 events, then "View All" if more
                        content
                            .padding(.top, KairosAuth.Spacing.medium)

                        // View All button at bottom if there are more than 3 items
                        if count > 3, let onViewAll = onViewAll {
                            Button(action: onViewAll) {
                                HStack {
                                    Text("View All \(count) Events")
                                        .font(KairosAuth.Typography.buttonLabel)
                                        .foregroundColor(accent)
                                    Image(systemName: "arrow.right")
                                        .font(KairosAuth.Typography.buttonIcon)
                                        .foregroundColor(accent)
                                        .accessibilityHidden(true)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                        .fill(accent.opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                                .stroke(accent.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        // Empty state message
                        VStack(spacing: KairosAuth.Spacing.small) {
                            Text(emptyMessage)
                                .font(KairosAuth.Typography.body)
                                .foregroundStyle(KairosAuth.Color.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, KairosAuth.Spacing.medium)
                                .padding(.vertical, KairosAuth.Spacing.large)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var subtitle: String {
        switch kind {
        case .today: return "Happening today"
        case .tomorrow: return "Tomorrow's events"
        case .thisWeek: return "This week"
        case .later: return "Further ahead"
        case .upcoming: return "Coming soon"
        case .past: return "Previous events"
        }
    }

    private var icon: String {
        switch kind {
        case .today: return "calendar.badge.clock"
        case .tomorrow: return "calendar"
        case .thisWeek: return "calendar.day.timeline.left"
        case .later: return "calendar.circle"
        case .upcoming: return "calendar"
        case .past: return "clock.arrow.circlepath"
        }
    }

    private var accent: Color {
        switch kind {
        case .today: return KairosAuth.Color.accent
        case .tomorrow: return KairosAuth.Color.teal
        case .thisWeek: return KairosAuth.Color.purple
        case .later: return KairosAuth.Color.secondaryText
        case .upcoming: return KairosAuth.Color.teal
        case .past: return KairosAuth.Color.tertiaryText
        }
    }
}

// MARK: - Event Card

private struct EventCard: View {
    let event: EventDTO
    let isExpanded: Bool
    let calendarStatus: AppVM.CalendarAccessStatus
    let onToggle: () -> Void
    let onAddToCalendar: () -> Void
    let onOpenDetail: () -> Void
    let onNavigate: () -> Void
    let onShare: () -> Void

    private var startDate: Date? { event.startDate }
    private var endDate: Date? { event.endDate }

    /// Time string (auto-localized to 12/24-hour)
    private var timeString: String {
        guard let startDate else { return "—" }
        return DateFormatting.formatTimeOnly(startDate)
    }

    /// Time range string (auto-localized to 12/24-hour)
    private var rangeString: String {
        guard let startDate, let endDate else { return "" }
        let start = DateFormatting.formatTimeOnly(startDate)
        let end = DateFormatting.formatTimeOnly(endDate)
        return "\(start) – \(end)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
            Button(action: onToggle) {
                collapsedRow
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .padding(KairosAuth.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                .fill(KairosAuth.Color.itemBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                        .stroke(KairosAuth.Color.cardBorder.opacity(0.5), lineWidth: 1)
                )
        )
        // Glassmorphic floating card with depth shadows
        .shadow(
            color: KairosAuth.Shadow.cardColor,
            radius: KairosAuth.Shadow.cardRadius,
            x: 0,
            y: KairosAuth.Shadow.cardY
        )
        // Subtle inner highlight for liquid glass effect
        .overlay(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.item, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var collapsedRow: some View {
        HStack(spacing: KairosAuth.Spacing.medium) {
            // Category icon (matches Dashboard pattern: 24pt in 32×32 container)
            Image(systemName: categoryIcon)
                .font(.system(size: KairosAuth.IconSize.itemIcon)) // 24pt
                .foregroundColor(KairosAuth.Color.accent)
                .frame(width: 32, height: 32)
                .background(
                    KairosAuth.Color.teal.opacity(0.15)
                        .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.small))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                // Title
                Text(event.title)
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundStyle(KairosAuth.Color.primaryText)
                    .lineLimit(1)

                // Metadata chips row (horizontal like Dashboard)
                HStack(spacing: KairosAuth.Spacing.small) {
                    // Time chip
                    HStack(spacing: KairosAuth.Spacing.xs) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: KairosAuth.IconSize.badge))
                            .accessibilityHidden(true)
                        Text(timeString)
                            .font(KairosAuth.Typography.statusBadge)
                    }
                    .foregroundColor(KairosAuth.Color.accent)

                    // Venue chip (if available)
                    if let venue = event.venue, !venue.name.isEmpty {
                        HStack(spacing: KairosAuth.Spacing.xs) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: KairosAuth.IconSize.badge))
                                .accessibilityHidden(true)
                            Text(venue.name)
                                .font(KairosAuth.Typography.statusBadge)
                                .lineLimit(1)
                        }
                        .foregroundColor(KairosAuth.Color.accent)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.down")
                .font(.system(size: KairosAuth.IconSize.badge))
                .foregroundColor(KairosAuth.Color.tertiaryText)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .accessibilityHidden(true)
        }
    }

    // Map event title to SF Symbol (matches PlanItemCard logic)
    private var categoryIcon: String {
        let title = event.title.lowercased()

        if title.contains("coffee") || title.contains("café") { return "cup.and.saucer.fill" }
        if title.contains("lunch") || title.contains("dinner") || title.contains("brunch") { return "fork.knife" }
        if title.contains("gym") || title.contains("workout") { return "figure.run" }
        if title.contains("drinks") || title.contains("bar") { return "wineglass.fill" }
        if title.contains("study") || title.contains("work") { return "book.fill" }
        if title.contains("movie") || title.contains("film") { return "popcorn.fill" }
        if title.contains("walk") || title.contains("hike") { return "figure.walk" }
        if title.contains("standup") || title.contains("meeting") { return "person.3.fill" }

        return "calendar" // Default
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
            Divider()
                .overlay(KairosAuth.Color.cardBorder)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                // Time range
                InfoRow(icon: "clock.fill", text: rangeString.isEmpty ? timeString : rangeString)

                // Venue (if available)
                if let venue = event.venue, !venue.name.isEmpty {
                    InfoRow(icon: "mappin.and.ellipse", text: "\(venue.name) · \(venue.address)")
                } else {
                    InfoRow(icon: "mappin.and.ellipse", text: "Location to be announced")
                }

                // Participants (if available)
                if let participants = event.participants, !participants.isEmpty {
                    InfoRow(icon: "person.2.fill", text: "\(participants.count) participant\(participants.count == 1 ? "" : "s")")
                } else {
                    InfoRow(icon: "person.2.fill", text: "Participants to be added")
                }

                // Calendar sync status
                if event.calendar_synced == true {
                    InfoRow(icon: "checkmark.circle.fill", text: "Synced to calendar")
                }
            }

            KairosAuth.StatusBadge(text: (event.status ?? "draft").uppercased())

            VStack(spacing: KairosAuth.Spacing.small) {
                EventActionButton(title: "Event Details", icon: "info.circle", style: .secondary, action: onOpenDetail)
                EventActionButton(title: "Add to Calendar", icon: "calendar.badge.plus", style: .secondary, action: onAddToCalendar)
                    .disabled(!calendarStatus.allowsWrite)
                EventActionButton(title: "Navigate", icon: "map", style: .primary, action: onNavigate)
                EventActionButton(title: "Share", icon: "square.and.arrow.up", style: .secondary, action: onShare)
            }
        }
    }
}

private extension AppVM.CalendarAccessStatus {
    var allowsWrite: Bool {
        switch self {
        case .authorized, .fullAccess, .writeOnly:
            return true
        default:
            return false
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: KairosAuth.Spacing.small) {
            Image(systemName: icon)
                .font(KairosAuth.Typography.statusBadge)
                .foregroundStyle(KairosAuth.Color.teal)
                .accessibilityHidden(true)
            Text(text)
                .font(KairosAuth.Typography.itemSubtitle)
                .foregroundStyle(KairosAuth.Color.secondaryText)
                .lineLimit(2)
        }
    }
}

private struct EventActionButton: View {
    enum Style { case primary, secondary }

    let title: String
    let icon: String
    let style: Style
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: KairosAuth.Spacing.small) {
                Image(systemName: icon)
                    .accessibilityHidden(true)
                Text(title)
            }
            .font(KairosAuth.Typography.buttonLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                    .fill(background)
            )
            .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
    }

    private var background: Color {
        switch style {
        case .primary: return KairosAuth.Color.accent
        case .secondary: return KairosAuth.Color.cardBackground
        }
    }

    private var foreground: Color {
        switch style {
        case .primary: return KairosAuth.Color.buttonText
        case .secondary: return KairosAuth.Color.primaryText
        }
    }
}

// MARK: - Event Detail Sheet

private struct EventDetailSheet: View {
    let event: EventDTO
    @Environment(\.dismiss) private var dismiss

    private var startDate: Date? { event.startDate }
    private var endDate: Date? { event.endDate }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: KairosAuth.Spacing.large) {
                        header
                        whenSection
                        whereSection
                        activitySection
                    }
                    .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
                    .padding(.top, KairosAuth.Spacing.large)
                    .padding(.bottom, KairosAuth.Spacing.large)
                }
            }
            .background(
                KairosAuth.Color.backgroundGradient(),
                ignoresSafeAreaEdges: .all
            )
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Event Details")
                        .font(KairosAuth.Typography.screenTitle)
                        .foregroundStyle(KairosAuth.Color.white)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(KairosAuth.Color.accent)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
            HStack(spacing: KairosAuth.Spacing.small) {
                Text("📅") // TODO(Kairos): Replace with intent emoji metadata — see EVENTS-TAB-IMPLEMENTATION-SPEC.md §3.1
                    .font(.system(size: KairosAuth.IconSize.heroIcon))

                VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                    Text(event.title)
                        .font(KairosAuth.Typography.cardTitle)
                        .foregroundStyle(KairosAuth.Color.primaryText)

                    if let startDate {
                        Text(startDate.formatted(date: .abbreviated, time: .shortened))
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundStyle(KairosAuth.Color.tertiaryText)
                    }
                }

                Spacer()

                KairosAuth.StatusBadge(text: (event.status ?? "draft").uppercased())
            }
        }
        .padding(KairosAuth.Spacing.cardContentPadding)
        .background(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                .fill(KairosAuth.Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                        .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                )
        )
    }

    private var whenSection: some View {
        KairosAuth.Card {
            VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                Text("When")
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundStyle(KairosAuth.Color.primaryText)

                if let startDate {
                    Text(startDate.formatted(date: .abbreviated, time: .shortened))
                        .font(KairosAuth.Typography.itemSubtitle)
                        .foregroundStyle(KairosAuth.Color.secondaryText)
                }

                if let endDate {
                    Text("Ends at \(endDate.formatted(date: .omitted, time: .shortened))")
                        .font(KairosAuth.Typography.timestamp)
                        .foregroundStyle(KairosAuth.Color.tertiaryText)
                }
            }
        }
    }

    private var whereSection: some View {
        KairosAuth.Card {
            VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                Text("Where")
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundStyle(KairosAuth.Color.primaryText)

                Text("Location details coming soon")
                    .font(KairosAuth.Typography.itemSubtitle)
                    .foregroundStyle(KairosAuth.Color.secondaryText)
            }
        }
    }

    private var activitySection: some View {
        KairosAuth.Card {
            VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                Text("Invitation History")
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundStyle(KairosAuth.Color.primaryText)

                Text("Timeline and participant activity will appear here once invitation history is wired up.")
                    .font(KairosAuth.Typography.itemSubtitle)
                    .foregroundStyle(KairosAuth.Color.secondaryText)
            }
        }
    }
}

// MARK: - Destination List Views (Matches Dashboard Pattern)

struct TodayEventsListView: View {
    let events: [EventDTO]
    @ObservedObject var vm: AppVM

    // Modal state
    @State private var isModalPresented = false
    @State private var selectedEvent: EventDTO?

    var body: some View {
        ZStack {
            if events.isEmpty {
                // Empty state
                ContentUnavailableView(
                    "No Events Today",
                    systemImage: "calendar.badge.clock",
                    description: Text("You're all clear! No events scheduled for today.")
                )
                .foregroundStyle(KairosAuth.Color.secondaryText)
            } else {
                ScrollView {
                    VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                        ForEach(events, id: \.id) { event in
                            EventListItemCard(event: event)
                                .onTapGesture {
                                    selectedEvent = event
                                    isModalPresented = true
                                }
                        }
                    }
                    .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                    .padding(.vertical, KairosAuth.Spacing.large)
                }
                .blur(radius: isModalPresented ? 8 : 0)
                .scaleEffect(isModalPresented ? 0.95 : 1.0)
                .animation(KairosAuth.Animation.modalPresent, value: isModalPresented)
            }

            // Dark overlay when modal presented (matches Dashboard)
            if isModalPresented {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KairosAuth.Color.scrim, ignoresSafeAreaEdges: .all)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(KairosAuth.Animation.modalDismiss) {
                            isModalPresented = false
                            selectedEvent = nil
                        }
                    }
            }

            // Modal overlay
            if isModalPresented, let event = selectedEvent {
                HeroExpansionModal(isPresented: $isModalPresented) {
                    EventDetailModal(
                        event: event,
                        isPresented: $isModalPresented,
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
                            print("📤 Share event: \(event.title)")
                        }
                    )
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Today")
                    .font(KairosAuth.Typography.screenTitle)
                    .foregroundColor(KairosAuth.Color.white)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    // TODO: Show profile sheet
                    print("Profile tapped from Today")
                }) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.profileButton))
                        .foregroundColor(KairosAuth.Color.accent)
                }
                .accessibilityLabel("Profile")
                .accessibilityHint("View your profile, settings, and help")
            }
        }
        .background(
            KairosAuth.Color.backgroundGradient(),
            ignoresSafeAreaEdges: .all
        )
    }
}

struct ThisWeekEventsListView: View {
    let events: [EventDTO]
    @ObservedObject var vm: AppVM

    // Modal state
    @State private var isModalPresented = false
    @State private var selectedEvent: EventDTO?

    var body: some View {
        ZStack {
            if events.isEmpty {
                // Empty state
                ContentUnavailableView(
                    "No Events This Week",
                    systemImage: "calendar.day.timeline.left",
                    description: Text("Your week is wide open! Time to send some invitations.")
                )
                .foregroundStyle(KairosAuth.Color.secondaryText)
            } else {
                ScrollView {
                    VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                        ForEach(events, id: \.id) { event in
                            EventListItemCard(event: event)
                                .onTapGesture {
                                    selectedEvent = event
                                    isModalPresented = true
                                }
                        }
                    }
                    .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                    .padding(.vertical, KairosAuth.Spacing.large)
                }
                .blur(radius: isModalPresented ? 8 : 0)
                .scaleEffect(isModalPresented ? 0.95 : 1.0)
                .animation(KairosAuth.Animation.modalPresent, value: isModalPresented)
            }

            // Dark overlay when modal presented (matches Dashboard)
            if isModalPresented {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KairosAuth.Color.scrim, ignoresSafeAreaEdges: .all)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(KairosAuth.Animation.modalDismiss) {
                            isModalPresented = false
                            selectedEvent = nil
                        }
                    }
            }

            // Modal overlay
            if isModalPresented, let event = selectedEvent {
                HeroExpansionModal(isPresented: $isModalPresented) {
                    EventDetailModal(
                        event: event,
                        isPresented: $isModalPresented,
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
                            print("📤 Share event: \(event.title)")
                        }
                    )
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("This Week")
                    .font(KairosAuth.Typography.screenTitle)
                    .foregroundColor(KairosAuth.Color.white)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    // TODO: Show profile sheet
                    print("Profile tapped from This Week")
                }) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.profileButton))
                        .foregroundColor(KairosAuth.Color.accent)
                }
                .accessibilityLabel("Profile")
                .accessibilityHint("View your profile, settings, and help")
            }
        }
        .background(
            KairosAuth.Color.backgroundGradient(),
            ignoresSafeAreaEdges: .all
        )
    }
}

struct LaterEventsListView: View {
    let events: [EventDTO]
    @ObservedObject var vm: AppVM

    // Modal state
    @State private var isModalPresented = false
    @State private var selectedEvent: EventDTO?

    var body: some View {
        ZStack {
            if events.isEmpty {
                // Empty state
                ContentUnavailableView(
                    "No Upcoming Events",
                    systemImage: "calendar.circle",
                    description: Text("Nothing scheduled yet. Send a new invitation to fill your calendar!")
                )
                .foregroundStyle(KairosAuth.Color.secondaryText)
            } else {
                ScrollView {
                    VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                        ForEach(events, id: \.id) { event in
                            EventListItemCard(event: event)
                                .onTapGesture {
                                    selectedEvent = event
                                    isModalPresented = true
                                }
                        }
                    }
                    .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                    .padding(.vertical, KairosAuth.Spacing.large)
                }
                .blur(radius: isModalPresented ? 8 : 0)
                .scaleEffect(isModalPresented ? 0.95 : 1.0)
                .animation(KairosAuth.Animation.modalPresent, value: isModalPresented)
            }

            // Dark overlay when modal presented (matches Dashboard)
            if isModalPresented {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KairosAuth.Color.scrim, ignoresSafeAreaEdges: .all)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(KairosAuth.Animation.modalDismiss) {
                            isModalPresented = false
                            selectedEvent = nil
                        }
                    }
            }

            // Modal overlay
            if isModalPresented, let event = selectedEvent {
                HeroExpansionModal(isPresented: $isModalPresented) {
                    EventDetailModal(
                        event: event,
                        isPresented: $isModalPresented,
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
                            print("📤 Share event: \(event.title)")
                        }
                    )
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Later")
                    .font(KairosAuth.Typography.screenTitle)
                    .foregroundColor(KairosAuth.Color.white)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    // TODO: Show profile sheet
                    print("Profile tapped from Later")
                }) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.profileButton))
                        .foregroundColor(KairosAuth.Color.accent)
                }
                .accessibilityLabel("Profile")
                .accessibilityHint("View your profile, settings, and help")
            }
        }
        .background(
            KairosAuth.Color.backgroundGradient(),
            ignoresSafeAreaEdges: .all
        )
    }
}

// Events-specific past events list (renamed to avoid conflict with Dashboard's PastEventsListView)
private struct EventsPastListView: View {
    let events: [EventDTO]
    @ObservedObject var vm: AppVM

    // Modal state
    @State private var isModalPresented = false
    @State private var selectedEvent: EventDTO?

    var body: some View {
        ZStack {
            if events.isEmpty {
                // Empty state
                ContentUnavailableView(
                    "No Past Events",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Your event history will appear here once you've attended some events.")
                )
                .foregroundStyle(KairosAuth.Color.secondaryText)
            } else {
                ScrollView {
                    VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                        ForEach(events, id: \.id) { event in
                            EventListItemCard(event: event)
                                .onTapGesture {
                                    selectedEvent = event
                                    isModalPresented = true
                                }
                        }
                    }
                    .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                    .padding(.vertical, KairosAuth.Spacing.large)
                }
                .blur(radius: isModalPresented ? 8 : 0)
                .scaleEffect(isModalPresented ? 0.95 : 1.0)
                .animation(KairosAuth.Animation.modalPresent, value: isModalPresented)
            }

            // Dark overlay when modal presented (matches Dashboard)
            if isModalPresented {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KairosAuth.Color.scrim, ignoresSafeAreaEdges: .all)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(KairosAuth.Animation.modalDismiss) {
                            isModalPresented = false
                            selectedEvent = nil
                        }
                    }
            }

            // Modal overlay
            if isModalPresented, let event = selectedEvent {
                HeroExpansionModal(isPresented: $isModalPresented) {
                    EventDetailModal(
                        event: event,
                        isPresented: $isModalPresented,
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
                            print("📤 Share event: \(event.title)")
                        }
                    )
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Past Events")
                    .font(KairosAuth.Typography.screenTitle)
                    .foregroundColor(KairosAuth.Color.white)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    // TODO: Show profile sheet
                    print("Profile tapped from Past Events")
                }) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.profileButton))
                        .foregroundColor(KairosAuth.Color.accent)
                }
                .accessibilityLabel("Profile")
                .accessibilityHint("View your profile, settings, and help")
            }
        }
        .background(
            KairosAuth.Color.backgroundGradient(),
            ignoresSafeAreaEdges: .all
        )
    }
}

// Simple card for list views
private struct EventListItemCard: View {
    let event: EventDTO

    private var categoryIcon: String {
        let title = event.title.lowercased()
        if title.contains("coffee") || title.contains("café") { return "cup.and.saucer.fill" }
        if title.contains("lunch") || title.contains("dinner") || title.contains("brunch") { return "fork.knife" }
        if title.contains("gym") || title.contains("workout") { return "figure.run" }
        if title.contains("drinks") || title.contains("bar") { return "wineglass.fill" }
        if title.contains("study") || title.contains("work") { return "book.fill" }
        if title.contains("movie") || title.contains("film") { return "popcorn.fill" }
        if title.contains("walk") || title.contains("hike") { return "figure.walk" }
        if title.contains("standup") || title.contains("meeting") { return "person.3.fill" }
        return "calendar"
    }

    var body: some View {
        HStack(spacing: KairosAuth.Spacing.medium) {
            Image(systemName: categoryIcon)
                .font(.system(size: KairosAuth.IconSize.itemIcon))
                .foregroundColor(KairosAuth.Color.accent)
                .frame(width: 32, height: 32)
                .background(
                    KairosAuth.Color.teal.opacity(0.15)
                        .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.small))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                Text(event.title)
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundStyle(KairosAuth.Color.primaryText)

                if let venue = event.venue {
                    Text(venue.name)
                        .font(KairosAuth.Typography.itemSubtitle)
                        .foregroundStyle(KairosAuth.Color.secondaryText)
                }
            }

            Spacer()

            if let startDate = event.startDate {
                Text(startDate.formatted(date: .omitted, time: .shortened))
                    .font(KairosAuth.Typography.itemSubtitle)
                    .foregroundStyle(KairosAuth.Color.tertiaryText)
            }

            // Chevron indicator (matches Plans/Dashboard pattern)
            Image(systemName: "chevron.right")
                .font(KairosAuth.Typography.buttonIcon)
                .foregroundColor(KairosAuth.Color.tertiaryText.opacity(0.6))
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
    }
}

#Preview("Loading") {
    let vm = AppVM(forPreviews: true)
    vm.eventsState = .loading
    return EventsView(vm: vm)
}

#Preview("Populated") {
    let vm = AppVM(forPreviews: true)
    vm.events = [
        EventDTO(id: UUID(), title: "Coffee with Alex", starts_at: ISO8601DateFormatter().string(from: .now.addingTimeInterval(3600)), status: "confirmed", date_created: nil, date_updated: nil, owner: nil, ics_url: nil)
    ]
    vm.eventsState = .loaded
    return EventsView(vm: vm)
}
