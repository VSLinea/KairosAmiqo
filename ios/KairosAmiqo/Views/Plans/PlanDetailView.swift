import SwiftUI

// MARK: - Plan Detail View

struct PlanDetailView: View {
    let plan: Negotiation
    @ObservedObject var vm: AppVM
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTimes: Set<String> = []
    @State private var selectedVenues: Set<String> = []

    private var isOwner: Bool {
        guard let currentUserId = vm.currentUser?.user_id else { return false }
        return plan.owner == currentUserId
    }

    var body: some View {     
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: KairosAuth.Spacing.large) {
                        headerSection
                        whenSection
                        whereSection
                        activityTimeline
                        actionButtons
                    }
                    .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
                    .padding(.top, KairosAuth.Spacing.medium)
                    .padding(.bottom, 100)
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Invitation Details")
                        .font(KairosAuth.Typography.screenTitle)
                        .foregroundStyle(KairosAuth.Color.white)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(KairosAuth.Color.accent)
                }
            }
        }
        .background(KairosAuth.Color.backgroundGradient(), ignoresSafeAreaEdges: .all)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
            HStack(spacing: KairosAuth.Spacing.small) {
                Text("☕️")
                    .font(.system(size: KairosAuth.IconSize.heroIcon))

                VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                    Text(plan.title ?? "Untitled Invitation")
                        .font(KairosAuth.Typography.cardTitle)
                        .foregroundStyle(KairosAuth.Color.primaryText)

                    if let startedAt = plan.started_at {
                        Text(formatDate(startedAt))
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundStyle(KairosAuth.Color.tertiaryText)
                    }
                }

                Spacer()

                KairosAuth.StatusBadge(text: plan.status?.uppercased() ?? "PENDING")
            }

            HStack(spacing: KairosAuth.Spacing.small) {
                Image(systemName: "person.2.fill")
                    .font(KairosAuth.Typography.buttonIcon)
                    .foregroundStyle(KairosAuth.Color.accent)
                    .accessibilityHidden(true)

                Text("\(plan.participants?.count ?? 0) invited")
                    .font(KairosAuth.Typography.itemSubtitle)
                    .foregroundStyle(KairosAuth.Color.secondaryText)
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

    // MARK: - WHEN Section

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
            HStack(spacing: KairosAuth.Spacing.small) {
                Image(systemName: "clock.fill")
                    .font(KairosAuth.Typography.buttonIcon)
                    .foregroundStyle(KairosAuth.Color.accent)
                    .accessibilityHidden(true)

                Text("When")
                    .font(KairosAuth.Typography.cardTitle)
                    .foregroundStyle(KairosAuth.Color.primaryText)
            }

            if let timeSlots = plan.proposed_slots, !timeSlots.isEmpty {
                VStack(spacing: KairosAuth.Spacing.small) {
                    ForEach(timeSlots, id: \.time) { slot in
                        TimeOptionRow(
                            slot: slot,
                            isSelected: selectedTimes.contains(slot.time),
                            voteCount: isOwner ? Int.random(in: 1...3) : nil,
                            onToggle: {
                                if selectedTimes.contains(slot.time) {
                                    selectedTimes.remove(slot.time)
                                } else {
                                    selectedTimes.insert(slot.time)
                                }
                            }
                        )
                    }
                }
            } else {
                Text("No time options yet")
                    .font(KairosAuth.Typography.itemSubtitle)
                    .foregroundStyle(KairosAuth.Color.tertiaryText)
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

    // MARK: - WHERE Section

    private var whereSection: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
            HStack(spacing: KairosAuth.Spacing.small) {
                Image(systemName: "mappin.circle.fill")
                    .font(KairosAuth.Typography.buttonIcon)
                    .foregroundStyle(KairosAuth.Color.accent)
                    .accessibilityHidden(true)

                Text("Where")
                    .font(KairosAuth.Typography.cardTitle)
                    .foregroundStyle(KairosAuth.Color.primaryText)
            }

            if let venues = plan.proposed_venues, !venues.isEmpty {
                VStack(spacing: KairosAuth.Spacing.small) {
                    ForEach(venues, id: \.name) { venue in
                        VenueDetailCard(
                            venue: venue,
                            isSelected: selectedVenues.contains(venue.name),
                            voteCount: isOwner ? Int.random(in: 1...3) : nil,
                            onToggle: {
                                if selectedVenues.contains(venue.name) {
                                    selectedVenues.remove(venue.name)
                                } else {
                                    selectedVenues.insert(venue.name)
                                }
                            }
                        )
                    }
                }
            } else {
                Text("No venue options yet")
                    .font(KairosAuth.Typography.itemSubtitle)
                    .foregroundStyle(KairosAuth.Color.tertiaryText)
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

    // MARK: - Activity Timeline

    private var activityTimeline: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
            HStack(spacing: KairosAuth.Spacing.small) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(KairosAuth.Typography.buttonIcon)
                    .foregroundStyle(KairosAuth.Color.accent)
                    .accessibilityHidden(true)

                Text("Activity")
                    .font(KairosAuth.Typography.cardTitle)
                    .foregroundStyle(KairosAuth.Color.primaryText)
            }

            VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                TimelineEntry(
                    icon: "person.badge.plus",
                    text: "You created this invitation",
                    timestamp: plan.started_at ?? ""
                )

                TimelineEntry(
                    icon: "paperplane.fill",
                    text: "Invites sent to \(plan.participants?.count ?? 0) people",
                    timestamp: plan.started_at ?? ""
                )
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

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: KairosAuth.Spacing.medium) {
            if isOwner {
                Button(action: { /* TODO: Resend invites */ }) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                            .accessibilityHidden(true)
                        Text("Resend")
                    }
                    .font(KairosAuth.Typography.buttonLabel)
                    .foregroundStyle(KairosAuth.Color.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                            .fill(KairosAuth.Color.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                    .stroke(KairosAuth.Color.accent, lineWidth: 1.5)
                            )
                    )
                }

                Button(action: { /* TODO: Edit invitation */ }) {
                    Text("Edit")
                        .font(KairosAuth.Typography.buttonLabel)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [KairosAuth.Color.accent, KairosAuth.Color.accent.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
            } else {
                Button(action: { /* TODO: Decline */ }) {
                    Text("Decline")
                        .font(KairosAuth.Typography.buttonLabel)
                        .foregroundStyle(KairosAuth.Color.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                .fill(KairosAuth.Color.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                        .stroke(KairosAuth.Color.cardBorder, lineWidth: 1.5)
                                )
                        )
                }

                Button(action: { /* TODO: Accept */ }) {
                    Text("Accept")
                        .font(KairosAuth.Typography.buttonLabel)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [KairosAuth.Color.accent, KairosAuth.Color.accent.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                .disabled(selectedTimes.isEmpty || selectedVenues.isEmpty)
                .opacity((selectedTimes.isEmpty || selectedVenues.isEmpty) ? 0.5 : 1.0)
            }
        }
    }

    // MARK: - Helper Methods

    private func formatDate(_ isoString: String) -> String {
        guard let date = DateFormatting.parseISO8601(isoString) else {
            return isoString
        }

        return DateFormatting.formatEventDateTime(date)
    }
}

// MARK: - Supporting Components

struct TimeOptionRow: View {
    let slot: ProposedSlot
    let isSelected: Bool
    let voteCount: Int?
    let onToggle: () -> Void

    private var formattedDate: String {
        guard let date = slot.date else { return slot.time }
        return DateFormatting.formatEventDateTime(date)
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: KairosAuth.Spacing.medium) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(KairosAuth.Color.accent)
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(KairosAuth.Typography.buttonIcon)
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                    } else {
                        Circle()
                            .stroke(KairosAuth.Color.tertiaryText, lineWidth: 2)
                            .frame(width: 28, height: 28)
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedDate)
                        .font(KairosAuth.Typography.itemTitle)
                        .foregroundStyle(KairosAuth.Color.primaryText)

                    if let count = voteCount {
                        Text("\(count) picked this")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundStyle(KairosAuth.Color.accent)
                    }
                }

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

struct VenueDetailCard: View {
    let venue: VenueInfo
    let isSelected: Bool
    let voteCount: Int?
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: KairosAuth.Spacing.medium) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: KairosAuth.IconSize.cardIcon))
                    .foregroundStyle(KairosAuth.Color.accent)
                    .accessibilityHidden(true)

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

                    HStack(spacing: KairosAuth.Spacing.small) {
                        if let priceBand = venue.price_band {
                            Text(String(repeating: "$", count: priceBand))
                                .font(.system(size: KairosAuth.IconSize.badge, weight: .semibold))
                                .foregroundStyle(KairosAuth.Color.secondaryText)
                        }

                        if let count = voteCount {
                            Text("\(count) picked this")
                                .font(KairosAuth.Typography.itemSubtitle)
                                .foregroundStyle(KairosAuth.Color.accent)
                        }
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: KairosAuth.IconSize.cardIcon))
                    .foregroundStyle(isSelected ? KairosAuth.Color.accent : KairosAuth.Color.tertiaryText)
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

struct TimelineEntry: View {
    let icon: String
    let text: String
    let timestamp: String

    private var formattedTime: String {
        guard let date = DateFormatting.parseISO8601(timestamp) else {
            return "Just now"
        }

        return DateFormatting.formatEventDateTime(date)
    }

    var body: some View {
        HStack(alignment: .top, spacing: KairosAuth.Spacing.medium) {
            Image(systemName: icon)
                .font(KairosAuth.Typography.itemSubtitle)
                .foregroundStyle(KairosAuth.Color.accent)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(KairosAuth.Color.accent.opacity(0.15))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundStyle(KairosAuth.Color.primaryText)

                Text(formattedTime)
                    .font(KairosAuth.Typography.itemSubtitle)
                    .foregroundStyle(KairosAuth.Color.tertiaryText)
            }

            Spacer()
        }
    }
}
