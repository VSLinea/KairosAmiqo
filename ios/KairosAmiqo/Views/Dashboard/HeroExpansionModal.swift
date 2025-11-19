//
//  HeroExpansionModal.swift
//  KairosAmiqo
//
//  Modal that expands from tap point with glassmorphic overlay
//  Provides spatial continuity and elegant presentation
//

import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

/// Generic hero expansion modal for plan/event details
/// Expands from tapped subcard with spatial depth effect
struct HeroExpansionModal<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    init(
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 20) // Minimal space from top (~0.5cm from nav bar)
                
                // Modal content - full width, scrollable
                VStack(spacing: 0) {
                    content
                }
                .frame(maxWidth: geometry.size.width - 32) // Full width minus margins
                .frame(maxHeight: geometry.size.height - 140) // Max height: screen - top space - safe area
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.modal)
                        .fill(KairosAuth.Color.modalSolidBackground) // Colored modal background for readability
                        .overlay(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.modal)
                                .stroke(KairosAuth.Color.modalBorder, lineWidth: 1) // Prominent modal border (0.40 opacity)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.modal)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),  // Enhanced top rim (Level 3 modal)
                                    Color.white.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5  // Thicker edge for modals
                        )
                )
                .shadow(color: KairosAuth.Color.shadowModal, radius: 50, x: 0, y: 20)
                .scaleEffect(scale)
                .opacity(opacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            withAnimation(KairosAuth.Animation.modalPresent) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }

    func dismiss() {
        withAnimation(KairosAuth.Animation.modalDismiss) {
            scale = 0.5
            opacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isPresented = false
        }
    }
}

/// Plan detail view - Negotiation Status Hub
/// Shows participant status, proposed options, and one clear action
struct PlanDetailModal: View {
    let plan: Negotiation
    @Binding var isPresented: Bool
    @ObservedObject var vm: AppVM // Changed from @EnvironmentObject for reliability
    
    // Counter sheet state (Task 13)
    @State private var showCounterSheet = false
    @State private var showResponsesSheet = false
    @State private var isLoadingResponses = false
    @State private var isPreparingFinalize = false
    @State private var responsesSummary: AppVM.NegotiationResponsesEnvelope.ResponseData?
    @State private var responsesError: String?
    @State private var showFinalizeSheet = false
    @State private var finalizeSlotIndex = 0
    @State private var finalizeVenueIndex = 0
    
    // Phase 3: Ownership check
    private var isOwner: Bool {
        guard let currentUserId = vm.currentUser?.user_id else { return false }
        // Compare UUIDs directly
        return plan.owner == currentUserId
    }

    private var associatedEvent: EventDTO? {
        vm.events.first { $0.negotiation_id == plan.id }
    }

    private var invitationHeaderTitle: String {
        plan.title ?? "Invitation Details"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // STICKY HEADER: Title + Status + Close button
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(invitationHeaderTitle)
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundColor(KairosAuth.Color.white)

                        if let status = plan.status {
                            HStack(spacing: KairosAuth.Spacing.small) {
                                Image(systemName: "chart.bar.fill")
                                    .font(KairosAuth.Typography.statusBadge)
                                    .foregroundColor(KairosAuth.Color.accent)
                                    .accessibilityHidden(true)
                                Text(status.capitalized)
                                    .font(KairosAuth.Typography.cardSubtitle)
                                    .foregroundColor(KairosAuth.Color.tertiaryText)
                            }
                        }
                    }

                    Spacer()

                    Button(action: {
                        withAnimation(KairosAuth.Animation.modalDismiss) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: KairosAuth.IconSize.cardIcon))
                            .foregroundColor(KairosAuth.Color.tertiaryText)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Close details")
                    .accessibilityHint("Dismisses the invitation details view.")
                }
                .padding(.horizontal, KairosAuth.Spacing.cardPadding)
                .padding(.top, KairosAuth.Spacing.cardPadding)
                .padding(.bottom, KairosAuth.Spacing.medium)

                // Divider
                Rectangle()
                    .fill(KairosAuth.Color.cardBorder)
                    .frame(height: 1)
            }
            .background(KairosAuth.Color.cardBackground)

            // SCROLLABLE CONTENT: Everything below the divider
            ScrollView {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {

            // Participants with status
            if let participants = plan.participants, !participants.isEmpty {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                    Text("PARTICIPANTS")
                        .font(KairosAuth.Typography.statusBadge)
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                        .tracking(0.3)

                    VStack(spacing: KairosAuth.Spacing.small) {
                        ForEach(participants, id: \.user_id) { participant in
                            HStack(spacing: KairosAuth.Spacing.small) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: KairosAuth.IconSize.badge))
                                    .foregroundColor(KairosAuth.Color.accent)
                                    .accessibilityHidden(true)

                                Text(participant.name)
                                    .font(KairosAuth.Typography.itemTitle)
                                    .foregroundColor(KairosAuth.Color.primaryText)

                                Spacer()
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(participant.name). Status: \(participantStatusLabel(for: participant.status))")
                        }
                    }
                }
            }

            // Proposed time slots
            if let slots = plan.proposed_slots, !slots.isEmpty {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                    Text("PROPOSED TIMES")
                        .font(KairosAuth.Typography.statusBadge)
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                        .tracking(0.3)

                    // Task 12: Use ProposalCard with accept action for participants
                    let showAcceptButton = !isOwner && (plan.state?.lowercased() == "awaiting_replies" || plan.state?.lowercased() == "proposed")
                    
                    VStack(spacing: KairosAuth.Spacing.medium) {
                        ForEach(Array(slots.prefix(3).enumerated()), id: \.offset) { index, slot in
                            let venue = plan.proposed_venues?[safe: index]
                            
                            ProposalCard(
                                slot: slot,
                                venue: venue,
                                isSelected: false,  // TODO: Track user's selection
                                votes: nil,  // TODO: Track who accepted this combo
                                onTap: {
                                    print("📌 Proposal tapped: \(slot.time)")
                                },
                                onAccept: showAcceptButton ? {
                                    // Task 12: Wire accept button to AppVM with indices
                                    print("🔵 [UI] Accept button tapped - plan: \(plan.id), slot: \(index)")
                                    Task {
                                        await vm.acceptProposal(
                                            planId: plan.id,
                                            slotIndex: index,
                                            venueIndex: index  // Using same index (slot+venue are paired)
                                        )
                                    }
                                } : nil
                            )
                        }
                    }
                }
            }

            // Proposed venues (hide if already shown in ProposalCards above)
            // Only show standalone venues if no slots exist
            if (plan.proposed_slots == nil || plan.proposed_slots!.isEmpty),
               let venues = plan.proposed_venues, !venues.isEmpty {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                    Text("PROPOSED VENUES")
                        .font(KairosAuth.Typography.statusBadge)
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                        .tracking(0.3)

                    VStack(spacing: KairosAuth.Spacing.small) {
                        ForEach(Array(venues.prefix(3)), id: \.id) { venue in
                            HStack(spacing: KairosAuth.Spacing.small) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: KairosAuth.IconSize.badge))
                                    .foregroundColor(KairosAuth.Color.accent)
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(venue.name)
                                        .font(KairosAuth.Typography.itemTitle)
                                        .foregroundColor(KairosAuth.Color.primaryText)
                                    if let address = venue.address, !address.isEmpty {
                                        Text(address)
                                            .font(KairosAuth.Typography.itemSubtitle)
                                            .foregroundColor(KairosAuth.Color.tertiaryText)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()
                            }
                        }
                    }
                }
            }

            // Divider before actions
            Rectangle()
                .fill(KairosAuth.Color.cardBorder)
                .frame(height: 1)

            // State-aware action buttons (Phase 1 Quick Fix)
            actionButtons
                }
                .padding(.horizontal, KairosAuth.Spacing.cardPadding)
                .padding(.vertical, KairosAuth.Spacing.medium)
            }
        }
    }
    
    /// Format time for compact display (auto-localized)
    ///
    /// **Apple Docs:** Uses Date.FormatStyle for automatic localization
    private func formatTime(_ isoString: String) -> String {
        guard let date = DateFormatting.parseISO8601(isoString) else {
            return isoString
        }
        
        return DateFormatting.formatEventDateTime(date)
    }

    private func participantStatusLabel(for status: String?) -> String {
        guard let status else { return "Invited" }
        switch status.lowercased() {
        case "accepted":
            return "Accepted"
        case "countered":
            return "Countered"
        case "declined", "rejected":
            return "Declined"
        case "pending", "awaiting_replies", "awaiting_invites":
            return "Pending"
        case "invited":
            return "Invited"
        default:
            return status.capitalized
        }
    }

    // State-aware action buttons (Phase 3 - Full ownership + state matrix)
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: KairosAuth.Spacing.small) {
            // Use plan.state for negotiation state machine
            let state = plan.state?.lowercased() ?? plan.status?.lowercased() ?? "pending"

            switch state {
            case "awaiting_invites":
                if isOwner {
                    Button(action: {
                        vm.beginEditing(plan: plan)
                        withAnimation(KairosAuth.Animation.modalDismiss) {
                            isPresented = false
                        }
                    }) {
                        HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                            Image(systemName: "pencil.circle")
                                .font(.system(size: KairosAuth.IconSize.itemIcon))
                                .accessibilityHidden(true)
                            Text("Edit Invitation")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.kairosSecondary) // Changed from primary - edit is secondary action

                    Button(action: {
                        guard !vm.isCancellingPlan else { return }
                        Task {
                            await vm.cancelPlan(planId: plan.id)
                        }
                    }) {
                        if vm.isCancellingPlan {
                            ProgressView()
                                .tint(KairosAuth.Color.tertiaryText)
                        } else {
                            Text("Cancel Invitation")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.kairosTertiary)
                    .foregroundColor(KairosAuth.Color.statusDeclined)
                    .disabled(vm.isCancellingPlan)

                    if let message = vm.cancelPlanError, !message.isEmpty {
                        errorMessageView(message)
                    }
                } else {
                    Button(action: {
                        showCounterSheet = true
                    }) {
                        HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: KairosAuth.IconSize.itemIcon))
                                .accessibilityHidden(true)
                            Text("Respond to Invitation")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.kairosPrimary)

                    Button(action: {
                        Task {
                            await vm.declinePlan(planId: plan.id)
                        }
                    }) {
                        HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                            if vm.isDeclining {
                                ProgressView()
                                    .tint(KairosAuth.Color.tertiaryText)
                            } else {
                                Text("Decline")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.kairosTertiary)
                    .foregroundColor(KairosAuth.Color.statusDeclined)
                    .disabled(vm.isDeclining)

                    if let message = vm.declineError, !message.isEmpty {
                        errorMessageView(message)
                    }
                }

            case "awaiting_replies":
                if isOwner {
                    Button(action: {
                        guard !isLoadingResponses else { return }
                        responsesError = nil
                        isLoadingResponses = true
                        Task {
                            do {
                                let summary = try await vm.fetchResponses(planId: plan.id)
                                await MainActor.run {
                                    responsesSummary = summary
                                    showResponsesSheet = true
                                    isLoadingResponses = false
                                }
                            } catch {
                                let message = vm.mapError(error)
                                await MainActor.run {
                                    responsesError = message
                                    isLoadingResponses = false
                                }
                            }
                        }
                    }) {
                        HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: KairosAuth.IconSize.itemIcon))
                                .accessibilityHidden(true)
                            if isLoadingResponses {
                                ProgressView()
                                    .tint(KairosAuth.Color.accent)
                            } else {
                                Text("View Responses")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.kairosSecondary) // Changed from primary - viewing is informational
                    .disabled(isLoadingResponses)

                    Button(action: {
                        responsesError = nil

                        guard let slots = plan.proposed_slots, !slots.isEmpty else {
                            responsesError = "Add at least one time slot before finalizing."
                            return
                        }

                        let slotCount = slots.count
                        finalizeSlotIndex = min(finalizeSlotIndex, max(slotCount - 1, 0))

                        let venueCount = plan.proposed_venues?.count ?? slotCount
                        finalizeVenueIndex = min(finalizeVenueIndex, max(venueCount - 1, 0))

                        if responsesSummary != nil {
                            showFinalizeSheet = true
                            return
                        }

                        guard !isPreparingFinalize else { return }
                        isPreparingFinalize = true

                        Task {
                            do {
                                let summary = try await vm.fetchResponses(planId: plan.id)
                                await MainActor.run {
                                    responsesSummary = summary
                                    showFinalizeSheet = true
                                    isPreparingFinalize = false
                                }
                            } catch {
                                let message = vm.mapError(error)
                                await MainActor.run {
                                    responsesError = message
                                    isPreparingFinalize = false
                                }
                            }
                        }
                    }) {
                        if isPreparingFinalize || vm.isFinalizing {
                            ProgressView()
                                .tint(KairosAuth.Color.accent)
                        } else {
                            Text("Finalize Invitation")
                        }
                    }
                    .buttonStyle(.kairosSecondary)
                    .disabled(isPreparingFinalize || vm.isFinalizing)

                    Button(action: {
                        guard !vm.isCancellingPlan else { return }
                        Task {
                            await vm.cancelPlan(planId: plan.id)
                        }
                    }) {
                        HStack(spacing: KairosAuth.Spacing.small) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: KairosAuth.IconSize.button))
                                .accessibilityHidden(true)
                            if vm.isCancellingPlan {
                                ProgressView()
                                    .tint(KairosAuth.Color.tertiaryText)
                            } else {
                                Text("Cancel Invitation")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.kairosTertiary)
                    .foregroundColor(KairosAuth.Color.statusDeclined)
                    .disabled(vm.isCancellingPlan)

                    if let message = vm.finalizeError, !message.isEmpty {
                        errorMessageView(message)
                    }
                    if let message = vm.cancelPlanError, !message.isEmpty {
                        errorMessageView(message)
                    }
                    if let message = responsesError, !message.isEmpty {
                        errorMessageView(message)
                    }
                } else {
                    // Side-by-side buttons: Edit + Withdraw
                    HStack(spacing: KairosAuth.Spacing.small) {
                        Button(action: {
                            showCounterSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil.circle")
                                    .font(.system(size: KairosAuth.IconSize.button))
                                    .accessibilityHidden(true)
                                Text("Edit")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.kairosSecondary)

                        Button(action: {
                            Task {
                                await vm.declinePlan(planId: plan.id, reason: "withdraw")
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: KairosAuth.IconSize.button))
                                    .accessibilityHidden(true)
                                if vm.isDeclining {
                                    ProgressView()
                                        .tint(KairosAuth.Color.statusDeclined)
                                } else {
                                    Text("Withdraw")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.kairosSecondary)
                        .foregroundColor(KairosAuth.Color.statusDeclined)
                        .disabled(vm.isDeclining)
                    }

                    if let message = vm.declineError, !message.isEmpty {
                        errorMessageView(message)
                    }
                }

            case "confirmed":
                Button(action: {
                    openMessagesApp()
                }) {
                    HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: KairosAuth.IconSize.itemIcon))
                            .accessibilityHidden(true)
                        Text("Message Participants")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.kairosSecondary) // Changed from primary - messaging is secondary

                if isOwner {
                    Button(action: {
                        print("✏️ Edit event")
                        // TODO: Navigate to EditEventView when ready
                    }) {
                        Text("Edit Event")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.kairosSecondary)

                    Rectangle()
                        .fill(KairosAuth.Color.cardBorder)
                        .frame(height: 1)

                    if let event = associatedEvent {
                        Button(action: {
                            guard !vm.isCancellingEvent else { return }
                            Task {
                                await vm.cancelEvent(eventId: event.id)
                            }
                        }) {
                            if vm.isCancellingEvent {
                                ProgressView()
                                    .tint(KairosAuth.Color.tertiaryText)
                            } else {
                                Text("Cancel Event")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.kairosTertiary)
                        .foregroundColor(KairosAuth.Color.statusDeclined)
                        .disabled(vm.isCancellingEvent)

                        if let message = vm.cancelEventError, !message.isEmpty {
                            errorMessageView(message)
                        }
                    } else {
                        Text("Event details syncing…")
                            .font(KairosAuth.Typography.bodySmall)
                            .foregroundColor(KairosAuth.Color.tertiaryText)
                    }
                } else {
                    Rectangle()
                        .fill(KairosAuth.Color.cardBorder)
                        .frame(height: 1)

                    if let event = associatedEvent {
                        Button(action: {
                            guard !vm.isLeavingEvent else { return }
                            Task {
                                await vm.leaveEvent(eventId: event.id)
                            }
                        }) {
                            if vm.isLeavingEvent {
                                ProgressView()
                                    .tint(KairosAuth.Color.statusDeclined)
                            } else {
                                Text("Leave Event")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.kairosTertiary)
                        .foregroundColor(KairosAuth.Color.statusDeclined)
                        .disabled(vm.isLeavingEvent)

                        if let message = vm.leaveEventError, !message.isEmpty {
                            errorMessageView(message)
                        }
                    } else {
                        Text("Event details syncing…")
                            .font(KairosAuth.Typography.bodySmall)
                            .foregroundColor(KairosAuth.Color.tertiaryText)
                    }
                }

            case "cancelled", "expired", "rejected": // "rejected" kept for backward compatibility
                Button(action: {
                    guard !vm.isDeletingPlan else { return }
                    Task {
                        await vm.delete(item: plan)
                        if vm.deletePlanError == nil {
                            await MainActor.run {
                                isPresented = false
                            }
                        }
                    }
                }) {
                    HStack(spacing: KairosAuth.Spacing.small) {
                        Image(systemName: "trash")
                            .font(.system(size: KairosAuth.IconSize.button))
                            .accessibilityHidden(true)
                        if vm.isDeletingPlan {
                            ProgressView()
                                .tint(KairosAuth.Color.statusDeclined)
                        } else {
                            Text("Delete Invitation")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.kairosSecondary)
                .foregroundColor(KairosAuth.Color.statusDeclined)
                .disabled(vm.isDeletingPlan)

                if let message = vm.deletePlanError, !message.isEmpty {
                    errorMessageView(message)
                }

            default:
                // Safety net: Check if initiator even for unknown states
                if isOwner {
                    Button(action: {
                        vm.beginEditing(plan: plan)
                        withAnimation(KairosAuth.Animation.modalDismiss) {
                            isPresented = false
                        }
                    }) {
                        HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                            Image(systemName: "pencil.circle")
                                .font(.system(size: KairosAuth.IconSize.itemIcon))
                                .accessibilityHidden(true)
                            Text("Edit Invitation")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.kairosSecondary)
                } else {
                    Button(action: {
                        showCounterSheet = true
                    }) {
                        HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: KairosAuth.IconSize.itemIcon))
                                .accessibilityHidden(true)
                            Text("Respond to Invitation")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.kairosPrimary)
                }
            }
        }
        .sheet(isPresented: $showCounterSheet) {
            CounterSheet(vm: vm, plan: plan, isPresented: $showCounterSheet)
        }
        .sheet(isPresented: $showResponsesSheet) {
            if let summary = responsesSummary {
                ResponsesSheet(invitation: plan, summary: summary)
            }
        }
        .sheet(isPresented: $showFinalizeSheet) {
            FinalizeInvitationSheet(
                plan: plan,
                summary: responsesSummary,
                slotIndex: $finalizeSlotIndex,
                venueIndex: $finalizeVenueIndex,
                vm: vm,
                isPresented: $showFinalizeSheet
            )
        }
        // Confirmation sheet (Task 14 - shown when consensus reached)
        .sheet(isPresented: $vm.showConfirmationSheet) {
            if let event = vm.confirmedEvent {
                PlanConfirmedSheet(vm: vm, isPresented: $vm.showConfirmationSheet, event: event)
            }
        }
    }
    
    @ViewBuilder
    private func errorMessageView(_ message: String) -> some View {
        Text(message)
            .font(KairosAuth.Typography.bodySmall)
            .foregroundColor(KairosAuth.Color.statusDeclined)
            .multilineTextAlignment(.center)
            .padding(.top, KairosAuth.Spacing.small)
    }
    
    // Phase 3: Open native Messages app (Option A - quick implementation)
    private func openMessagesApp() {
        guard let participants = plan.participants else { return }
        
        // Collect phone numbers
        let phoneNumbers = participants.compactMap { $0.phone }.joined(separator: ",")
        
        guard !phoneNumbers.isEmpty else {
            print("⚠️ No phone numbers available for messaging")
            return
        }
        
        // Open Messages app with pre-filled recipients
        if let url = URL(string: "sms://open?addresses=\(phoneNumbers)") {
            #if !targetEnvironment(simulator)
            // Real device only - simulator doesn't support SMS
            UIApplication.shared.open(url)
            #else
            print("💬 Would open Messages with: \(phoneNumbers)")
            #endif
        }
    }
}

private struct ResponsesSheet: View {
    let invitation: Negotiation
    let summary: AppVM.NegotiationResponsesEnvelope.ResponseData

    @Environment(\.dismiss) private var dismiss

    private var stats: [(title: String, value: Int, color: Color)] {
        [
            ("Accepted", summary.stats.accepted, KairosAuth.Color.statusConfirmed),
            ("Countered", summary.stats.countered, KairosAuth.Color.accent),
            ("Declined", summary.stats.declined, KairosAuth.Color.statusDeclined),
            ("Pending", summary.stats.pending, KairosAuth.Color.statusPending)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.large) {
                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                        Text(invitation.title ?? "Invitation Responses")
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundColor(KairosAuth.Color.white)

                        Text("Round \(summary.round ?? 1) • \(summary.stats.total) invited")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundColor(KairosAuth.Color.tertiaryText)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: KairosAuth.Spacing.medium) {
                        ForEach(stats, id: \.title) { stat in
                            VStack(spacing: KairosAuth.Spacing.small) {
                                Text("\(stat.value)")
                                    .font(KairosAuth.Typography.cardTitle)
                                    .foregroundColor(stat.color)

                                Text(stat.title.uppercased())
                                    .font(KairosAuth.Typography.statusBadge)
                                    .foregroundColor(KairosAuth.Color.tertiaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(KairosAuth.Spacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                                    .fill(KairosAuth.Color.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                                    .stroke(KairosAuth.Color.cardBorder.opacity(0.6), lineWidth: 1)
                            )
                        }
                    }

                    Rectangle()
                        .fill(KairosAuth.Color.cardBorder)
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                        ForEach(summary.responses) { response in
                            responseRow(for: response)
                        }
                    }
                }
                .padding(KairosAuth.Spacing.cardPadding)
            }
            .navigationTitle("Invitation Responses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(KairosAuth.Typography.buttonLabel)
                }
            }
        }
    }

    private func responseRow(for response: AppVM.NegotiationResponsesEnvelope.ResponseData.ParticipantResponse) -> some View {
        let info = statusInfo(for: response.status)
        let accessibilityLabel: String = {
            var components: [String] = [response.name, "Status: \(info.label)"]
            if let slotIndex = response.selected_slot {
                components.append("Chose option number \(slotIndex + 1)")
            }
            return components.joined(separator: ". ")
        }()

        return HStack(spacing: KairosAuth.Spacing.rowSpacing) {
            Image(systemName: info.icon)
                .font(.system(size: KairosAuth.IconSize.badge))
                .foregroundColor(info.color)
                .frame(width: KairosAuth.IconSize.itemIcon)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                Text(response.name)
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundColor(KairosAuth.Color.primaryText)

                if let slotIndex = response.selected_slot {
                    Text("Chose option #\(slotIndex + 1)")
                        .font(KairosAuth.Typography.statusBadge)
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                }
            }

            Spacer()

            Text(info.label)
                .font(KairosAuth.Typography.statusBadge)
                .foregroundColor(info.color)
        }
        .padding(.vertical, KairosAuth.Spacing.small)
        .padding(.horizontal, KairosAuth.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.item)
                .fill(KairosAuth.Color.itemBackground)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func statusInfo(for status: String) -> (icon: String, label: String, color: Color) {
        switch status.lowercased() {
        case "accepted":
            return ("checkmark.circle.fill", "Accepted", KairosAuth.Color.statusConfirmed)
        case "countered":
            return ("arrow.triangle.2.circlepath", "Countered", KairosAuth.Color.accent)
        case "declined":
            return ("xmark.circle.fill", "Declined", KairosAuth.Color.statusDeclined)
        default:
            return ("clock.fill", "Pending", KairosAuth.Color.statusPending)
        }
    }
}

private struct FinalizeInvitationSheet: View {
    let plan: Negotiation
    let summary: AppVM.NegotiationResponsesEnvelope.ResponseData?
    @Binding var slotIndex: Int
    @Binding var venueIndex: Int
    @ObservedObject var vm: AppVM
    @Binding var isPresented: Bool

    @Environment(\.dismiss) private var dismiss

    private var slots: [ProposedSlot] { plan.proposed_slots ?? [] }
    private var venues: [VenueInfo] { plan.proposed_venues ?? [] }
    private var canFinalize: Bool { !slots.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.large) {
                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                        Text("Finalize Invitation")
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundColor(KairosAuth.Color.white)

                        Text("Choose the confirmed time and venue for everyone.")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundColor(KairosAuth.Color.tertiaryText)
                    }

                    slotSelection

                    if venues.count > 1 {
                        venueSelection
                    }

                    if let summary {
                        selectionSummary(summary)
                    }

                    Button(action: finalizeAction) {
                        if vm.isFinalizing {
                            ProgressView()
                                .tint(KairosAuth.Color.buttonText)
                        } else {
                            Text("Finalize and Notify")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.kairosPrimary)
                    .disabled(!canFinalize || vm.isFinalizing)

                    if let message = vm.finalizeError, !message.isEmpty {
                        Text(message)
                            .font(KairosAuth.Typography.bodySmall)
                            .foregroundColor(KairosAuth.Color.statusDeclined)
                            .padding(.top, KairosAuth.Spacing.small)
                    }
                }
                .padding(KairosAuth.Spacing.cardPadding)
            }
            .navigationTitle("Finalize Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                        dismiss()
                    }
                    .font(KairosAuth.Typography.buttonLabel)
                }
            }
            .onAppear {
                guard !slots.isEmpty else { return }
                slotIndex = min(slotIndex, max(slots.count - 1, 0))
                if venues.isEmpty {
                    venueIndex = slotIndex
                } else {
                    venueIndex = min(venueIndex, max(venues.count - 1, 0))
                }
            }
        }
    }

    @ViewBuilder
    private var slotSelection: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
            Text("SELECT TIME")
                .font(KairosAuth.Typography.statusBadge)
                .foregroundColor(KairosAuth.Color.tertiaryText)
                .tracking(0.3)

            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                Button(action: {
                    slotIndex = index
                    if venues.isEmpty {
                        venueIndex = index
                    }
                }) {
                    selectionCard(
                        title: formattedSlot(slot),
                        subtitle: slot.venue?.name,
                        isSelected: index == slotIndex
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var venueSelection: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
            Text("SELECT VENUE")
                .font(KairosAuth.Typography.statusBadge)
                .foregroundColor(KairosAuth.Color.tertiaryText)
                .tracking(0.3)

            ForEach(Array(venues.enumerated()), id: \.offset) { index, venue in
                Button(action: { venueIndex = index }) {
                    selectionCard(
                        title: venue.name,
                        subtitle: venue.address,
                        isSelected: index == venueIndex
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func selectionCard(title: String, subtitle: String?, isSelected: Bool) -> some View {
        HStack(alignment: .top, spacing: KairosAuth.Spacing.rowSpacing) {
            VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                Text(title)
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundColor(KairosAuth.Color.primaryText)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(KairosAuth.Typography.itemSubtitle)
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: KairosAuth.IconSize.itemIcon))
                .foregroundColor(isSelected ? KairosAuth.Color.accent : KairosAuth.Color.tertiaryText)
                .accessibilityHidden(true)
        }
        .padding(KairosAuth.Spacing.medium)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.item)
                .fill(isSelected ? KairosAuth.Color.selectedBackground : KairosAuth.Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.item)
                .stroke(isSelected ? KairosAuth.Color.accent.opacity(0.6) : KairosAuth.Color.cardBorder.opacity(0.6), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selectionAccessibilityLabel(title: title, subtitle: subtitle))
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private func selectionAccessibilityLabel(title: String, subtitle: String?) -> String {
        if let subtitle, !subtitle.isEmpty {
            return "\(title). \(subtitle)"
        }
        return title
    }

    private func selectionSummary(_ summary: AppVM.NegotiationResponsesEnvelope.ResponseData) -> some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
            Text("Response Snapshot")
                .font(KairosAuth.Typography.statusBadge)
                .foregroundColor(KairosAuth.Color.tertiaryText)

            Text("Accepted: \(summary.stats.accepted)  •  Countered: \(summary.stats.countered)  •  Pending: \(summary.stats.pending)")
                .font(KairosAuth.Typography.itemSubtitle)
                .foregroundColor(KairosAuth.Color.tertiaryText)
        }
        .padding(.vertical, KairosAuth.Spacing.small)
    }

    private func formattedSlot(_ slot: ProposedSlot) -> String {
        if let date = DateFormatting.parseISO8601(slot.time) {
            return DateFormatting.formatEventDateTime(date)
        }
        return slot.time
    }

    private func finalizeAction() {
        guard canFinalize else { return }

        let safeSlotIndex = min(slotIndex, max(slots.count - 1, 0))
        let safeVenueIndex: Int
        if venues.isEmpty {
            safeVenueIndex = safeSlotIndex
        } else {
            safeVenueIndex = min(venueIndex, max(venues.count - 1, 0))
        }

        Task {
            await vm.finalizePlan(planId: plan.id, slotIndex: safeSlotIndex, venueIndex: safeVenueIndex)
            if vm.finalizeError == nil {
                await MainActor.run {
                    isPresented = false
                    dismiss()
                }
            }
        }
    }
}

// OLD EventDetailModal removed - see line 341 for new version with action closures

/// Compact info row for event modal
private struct EventInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: KairosAuth.Spacing.rowSpacing) {
            Image(systemName: icon)
                .font(.system(size: KairosAuth.IconSize.itemIcon))
                .foregroundColor(KairosAuth.Color.accent)
                .frame(width: KairosAuth.IconSize.itemIcon)
                .accessibilityHidden(true)

            Text(text)
                .font(KairosAuth.Typography.itemTitle)
                .foregroundColor(KairosAuth.Color.primaryText)

            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// Action button for event modal
private struct EventActionButtonModal: View {
    enum Style { case primary, secondary }

    let title: String
    let icon: String
    let style: Style
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        if style == .primary {
            Button(action: action) {
                HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                    Image(systemName: icon)
                        .font(.system(size: KairosAuth.IconSize.badge))
                        .accessibilityHidden(true)

                    Text(title)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.kairosPrimary)
            .opacity(isEnabled ? 1.0 : 0.5)
            .accessibilityLabel(title)
        } else {
            Button(action: action) {
                HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                    Image(systemName: icon)
                        .font(.system(size: KairosAuth.IconSize.badge))
                        .accessibilityHidden(true)

                    Text(title)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.kairosSecondary)
            .opacity(isEnabled ? 1.0 : 0.5)
            .accessibilityLabel(title)
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

/// Participant status row
private struct ParticipantStatusRow: View {
    let name: String
    let status: ParticipantStatus
    let isYou: Bool

    enum ParticipantStatus {
        case confirmed, pending, declined

        var icon: String {
            switch self {
            case .confirmed: return "checkmark.circle.fill"
            case .pending: return "clock.fill"
            case .declined: return "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .confirmed: return KairosAuth.Color.statusConfirmed  // Brand teal, not system green
            case .pending: return KairosAuth.Color.statusPending      // Brand teal
            case .declined: return KairosAuth.Color.statusDeclined    // Red
            }
        }

        var label: String {
            switch self {
            case .confirmed: return "Confirmed"
            case .pending: return "Pending"
            case .declined: return "Declined"
            }
        }
    }

    var body: some View {
        HStack(spacing: KairosAuth.Spacing.rowSpacing) {
            // Status icon
            Image(systemName: status.icon)
                .font(.system(size: KairosAuth.IconSize.badge))
                .foregroundColor(status.color)
                .frame(width: KairosAuth.IconSize.itemIcon)
                .accessibilityHidden(true)

            // Name
            Text(name)
                .font(KairosAuth.Typography.body)
                .foregroundColor(KairosAuth.Color.white)

            Spacer()

            // Status label
            Text(status.label)
                .font(KairosAuth.Typography.statusBadge)
                .foregroundColor(status.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.item)
                .fill(KairosAuth.Color.itemBackground) // Elevated background (0.12 opacity)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name). Status: \(status.label)")
    }
}

/// Proposed option row
private struct ProposedOptionRow: View {
    let time: String
    let location: String
    let confirmedCount: Int
    let totalCount: Int
    let isRecommended: Bool

    var body: some View {
        HStack(spacing: KairosAuth.Spacing.rowSpacing) {
            // Recommendation indicator
            if isRecommended {
                Image(systemName: "star.fill")
                    .font(.system(size: KairosAuth.IconSize.badge))
                    .foregroundColor(KairosAuth.Color.accent)
                    .accessibilityHidden(true)
            } else {
                Circle()
                    .fill(KairosAuth.Color.tertiaryText)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                // Time
                Text(time)
                    .font(KairosAuth.Typography.buttonIcon)
                    .foregroundColor(KairosAuth.Color.white)

                // Location
                HStack(spacing: KairosAuth.Spacing.xs) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.badge))
                        .foregroundColor(KairosAuth.Color.accent)
                        .accessibilityHidden(true)
                    Text(location)
                        .font(KairosAuth.Typography.itemSubtitle)
                        .foregroundColor(KairosAuth.Color.tertiaryText) // Subtle close button
                }
            }

            Spacer()

            // Vote count
            Text("\(confirmedCount)/\(totalCount)")
                .font(KairosAuth.Typography.body)
                .foregroundColor(isRecommended ? KairosAuth.Color.accent : KairosAuth.Color.tertiaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.item)
                .fill(isRecommended ? KairosAuth.Color.selectedBackground : KairosAuth.Color.itemBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.item)
                        .stroke(isRecommended ? KairosAuth.Color.teal.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityValue(isRecommended ? "Recommended" : "Option")
    }

    private var accessibilitySummary: String {
        var components: [String] = [time]
        if !location.isEmpty {
            components.append("Location: \(location)")
        }
        components.append("Votes: \(confirmedCount) of \(totalCount)")
        return components.joined(separator: ". ")
    }
}

/// Event detail view for hero expansion modal
/// Context-aware actions based on event timing and venue
struct EventDetailModal: View {
    let event: EventDTO
    @Binding var isPresented: Bool
    let onAddToCalendar: () -> Void
    let onNavigate: () -> Void
    let onShare: () -> Void

    private var timeString: String {
        guard let startDate = event.startDate else { return "—" }
        return startDate.formatted(date: .abbreviated, time: .shortened)
    }

    /// Format time range (auto-localized to 12/24-hour)
    private var rangeString: String {
        guard let startDate = event.startDate, let endDate = event.endDate else { return "" }
        let start = DateFormatting.formatTimeOnly(startDate)
        let end = DateFormatting.formatTimeOnly(endDate)
        return "\(start) – \(end)"
    }

    private var calendarAccessibilityLabel: String {
        let schedule = rangeString.isEmpty ? timeString : rangeString
        if event.calendar_synced == true {
            return "\(event.title) is already in your calendar for \(schedule)."
        }
        return "Add \(event.title) to your calendar for \(schedule)."
    }

    private var calendarAccessibilityHint: String {
        event.calendar_synced == true ? "Double-tap to refresh the calendar entry." : "Adds this event to your calendar."
    }

    private func locationAccessibilityLabel(for venue: EventDTO.VenueInfo) -> String {
        if venue.address.isEmpty {
            return "Get directions to \(venue.name)."
        }
        return "Get directions to \(venue.name) at \(venue.address)."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.large) {
            // Header with close button
            HStack {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                    Text(event.title)
                        .font(KairosAuth.Typography.cardTitle)
                        .foregroundColor(KairosAuth.Color.white)

                    // Confirmed badge
                    if event.status == "confirmed" {
                        HStack(spacing: KairosAuth.Spacing.small) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(KairosAuth.Typography.buttonIcon)
                                .foregroundColor(KairosAuth.Color.statusConfirmed)
                                .accessibilityHidden(true)
                            Text("Confirmed & Scheduled")
                                .font(KairosAuth.Typography.itemSubtitle)
                                .foregroundColor(KairosAuth.Color.tertiaryText)
                        }
                    }
                }

                Spacer()

                Button(action: {
                    withAnimation(KairosAuth.Animation.modalDismiss) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("Close details")
                .accessibilityHint("Dismisses the event details view.")
            }

            // Divider
            Rectangle()
                .fill(KairosAuth.Color.cardBorder)
                .frame(height: 1)

            // Date & Time
            Button(action: {
                onAddToCalendar()
                withAnimation { isPresented = false }
            }) {
                HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                    Image(systemName: "calendar.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                        .foregroundColor(KairosAuth.Color.accent)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(rangeString.isEmpty ? timeString : rangeString)
                            .font(KairosAuth.Typography.buttonLabel)
                            .foregroundColor(KairosAuth.Color.white)

                        Text(event.calendar_synced == true ? "Synced to calendar" : "Tap to add to calendar")
                            .font(KairosAuth.Typography.statusBadge)
                            .foregroundColor(event.calendar_synced == true ? KairosAuth.Color.statusConfirmed : KairosAuth.Color.tertiaryText)
                    }

                    Spacer()

                    if event.calendar_synced == true {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: KairosAuth.IconSize.profileButton))
                            .foregroundColor(KairosAuth.Color.statusConfirmed)
                            .accessibilityHidden(true)
                    }
                }
                .padding(KairosAuth.Spacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.item)
                        .fill(KairosAuth.Color.fieldBackground.opacity(0.3))
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(calendarAccessibilityLabel)
            .accessibilityHint(calendarAccessibilityHint)

            // Location - if available
            if let venue = event.venue, !venue.name.isEmpty {
                Button(action: {
                    onNavigate()
                    withAnimation { isPresented = false }
                }) {
                    HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: KairosAuth.IconSize.cardIcon))
                            .foregroundColor(KairosAuth.Color.accent)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(venue.name)
                                .font(KairosAuth.Typography.buttonLabel)
                                .foregroundColor(KairosAuth.Color.white)

                            if !venue.address.isEmpty {
                                Text(venue.address)
                                    .font(KairosAuth.Typography.statusBadge)
                                    .foregroundColor(KairosAuth.Color.tertiaryText)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: KairosAuth.IconSize.profileButton))
                            .foregroundColor(KairosAuth.Color.accent)
                            .accessibilityHidden(true)
                    }
                    .padding(KairosAuth.Spacing.medium)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.item)
                            .fill(KairosAuth.Color.fieldBackground.opacity(0.3))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(locationAccessibilityLabel(for: venue))
                .accessibilityHint("Opens Maps with directions to the venue.")
            }

            // Divider
            if event.participants != nil {
                Rectangle()
                    .fill(KairosAuth.Color.cardBorder)
                    .frame(height: 1)
            }

            // Participants
            if let participants = event.participants, !participants.isEmpty {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.rowSpacing) {
                    Text("\(participants.count) ATTENDING")
                        .font(KairosAuth.Typography.statusBadge)
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                        .tracking(0.5)

                    VStack(spacing: KairosAuth.Spacing.small) {
                        ForEach(Array(participants.prefix(5)), id: \.user_id) { participant in
                            HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [KairosAuth.Color.teal.opacity(0.6), KairosAuth.Color.accent.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(KairosAuth.Typography.buttonIcon)
                                            .foregroundColor(KairosAuth.Color.white)
                                            .accessibilityHidden(true)
                                    )

                                Text(participant.name)
                                    .font(KairosAuth.Typography.itemTitle)
                                    .foregroundColor(KairosAuth.Color.primaryText)

                                Spacer()
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(participant.name) is attending.")
                        }

                        if participants.count > 5 {
                            HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                                Circle()
                                    .fill(KairosAuth.Color.fieldBackground)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text("+\(participants.count - 5)")
                                            .font(KairosAuth.Typography.statusBadge)
                                            .foregroundColor(KairosAuth.Color.accent)
                                    )

                                Text("\(participants.count - 5) more")
                                    .font(KairosAuth.Typography.itemSubtitle)
                                    .foregroundColor(KairosAuth.Color.tertiaryText)

                                Spacer()
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(participants.count - 5) additional participants are attending.")
                        }
                    }
                }
            }

            // Primary CTA - Navigate
            Button(action: {
                onNavigate()
                withAnimation { isPresented = false }
            }) {
                HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                    Image(systemName: "map.fill")
                        .font(.system(size: KairosAuth.IconSize.itemIcon))
                        .accessibilityHidden(true)
                    Text("Get Directions")
                        .font(KairosAuth.Typography.buttonLabel)
                }
                .foregroundColor(KairosAuth.Color.buttonText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.item)
                        .fill(KairosAuth.Color.teal)
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens Maps with directions to the venue.")
        }
    }
}

/// Past event detail view - Memory + Re-engagement
/// Status-aware celebration or empathy, focused on re-planning action
struct PastEventDetailModal: View {
    let event: EventDTO
    let onReschedule: () -> Void
    @Binding var isPresented: Bool

    private var dateString: String {
        guard let startDate = event.startDate else { return "—" }
        return startDate.formatted(date: .abbreviated, time: .omitted)
    }

    private var wasCancelled: Bool {
        event.status?.lowercased() == "cancelled"
    }

    private var participantAccessibilitySummary: String {
        guard let participants = event.participants, !participants.isEmpty else {
            return "No participant information available."
        }

        let names = participants.map(\.name)
        if names.count <= 5 {
            return "Participants: \(names.joined(separator: ", "))."
        }

        let primary = names.prefix(5).joined(separator: ", ")
        let remaining = names.count - 5
        return "Participants: \(primary), plus \(remaining) more."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.large) {
            // Header with close button
            HStack {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                    Text(event.title)
                        .font(KairosAuth.Typography.cardTitle)
                        .foregroundColor(KairosAuth.Color.white)

                    Text(dateString)
                        .font(KairosAuth.Typography.cardSubtitle)
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                }

                Spacer()

                Button(action: {
                    withAnimation(KairosAuth.Animation.modalDismiss) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("Close details")
                .accessibilityHint("Dismisses the past event summary.")
            }

            // Divider
            Rectangle()
                .fill(KairosAuth.Color.cardBorder)
                .frame(height: 1)

            // Status-aware message section
            if !wasCancelled {
                // Subtle nostalgia indicator for completed events
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                    HStack(spacing: KairosAuth.Spacing.medium) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: KairosAuth.IconSize.cardIcon))
                            .foregroundColor(KairosAuth.Color.teal)
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                            Text("Completed Event")
                                .font(KairosAuth.Typography.itemTitle)
                                .foregroundColor(KairosAuth.Color.primaryText)
                            
                            Text("This event took place in the past")
                                .font(KairosAuth.Typography.itemSubtitle)
                                .foregroundColor(KairosAuth.Color.tertiaryText)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(KairosAuth.Spacing.cardContentPadding)
                .background(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.item)
                        .fill(KairosAuth.Color.teal.opacity(0.15))
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Completed event. This invitation took place in the past.")
            } else {
                // Empathy for cancelled events
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                    HStack(spacing: KairosAuth.Spacing.medium) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: KairosAuth.IconSize.cardIcon))
                            .foregroundColor(KairosAuth.Color.tertiaryText)
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                            Text("Cancelled")
                                .font(KairosAuth.Typography.itemTitle)
                                .foregroundColor(KairosAuth.Color.primaryText)
                            
                            Text("This event didn't happen")
                                .font(KairosAuth.Typography.itemSubtitle)
                                .foregroundColor(KairosAuth.Color.tertiaryText)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(KairosAuth.Spacing.cardContentPadding)
                .background(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.item)
                        .fill(KairosAuth.Color.tertiaryText.opacity(0.1))
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Cancelled event. This invitation did not take place.")
            }

            // Divider
            if event.participants != nil {
                Rectangle()
                    .fill(KairosAuth.Color.cardBorder)
                    .frame(height: 1)
            }

            // Participants section (muted design for past events)
            if let participants = event.participants, !participants.isEmpty {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.rowSpacing) {
                    Text("\(participants.count) ATTENDED")
                        .font(KairosAuth.Typography.statusBadge)
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                        .tracking(0.5)

                    HStack(spacing: -8) {
                        ForEach(0..<min(participants.count, 5), id: \.self) { _ in
                            Circle()
                                .fill(KairosAuth.Color.mutedBackground)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: KairosAuth.IconSize.badge))
                                        .foregroundColor(KairosAuth.Color.mutedText)
                                        .accessibilityHidden(true)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(KairosAuth.Color.cardBackground, lineWidth: 2.5)
                                )
                        }

                        if participants.count > 5 {
                            Circle()
                                .fill(KairosAuth.Color.fieldBackground.opacity(0.5))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text("+\(participants.count - 5)")
                                        .font(KairosAuth.Typography.itemSubtitle)
                                        .foregroundColor(KairosAuth.Color.mutedText)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(KairosAuth.Color.cardBackground, lineWidth: 2.5)
                                )
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(participantAccessibilitySummary)
                }
            }

            // Primary CTA - Invite Again (teal accent matches app design)
            Button(action: {
                isPresented = false
                onReschedule()
            }) {
                HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: KairosAuth.IconSize.itemIcon))
                        .accessibilityHidden(true)
                    Text("Invite Again")
                        .font(KairosAuth.Typography.buttonLabel)
                }
                .foregroundColor(KairosAuth.Color.buttonText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.item)
                        .fill(wasCancelled ? KairosAuth.Color.purple : KairosAuth.Color.teal)
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Starts planning a new invitation with the same participants.")
            .accessibilityLabel("Invite Again")
        }
    }
}

#Preview("Invitation Detail Modal") {
    HeroExpansionModal(isPresented: .constant(true)) {
        PlanDetailModal(
            plan: Negotiation(
                id: UUID(),
                title: "Coffee with Sarah",
                status: "active",
                intent_category: "coffee",
                participants: [
                    PlanParticipant(user_id: UUID(), name: "Sarah", status: "accepted"),
                    PlanParticipant(user_id: UUID(), name: "Mike", status: "pending"),
                    PlanParticipant(user_id: UUID(), name: "You", status: "accepted")
                ]
            ),
            isPresented: .constant(true),
            vm: AppVM()
        )
    }
}

#Preview("Event Detail Modal") {
    let formatter = ISO8601DateFormatter()
    HeroExpansionModal(isPresented: .constant(true)) {
        EventDetailModal(
            event: EventDTO(
                id: UUID(),
                title: "Team Lunch",
                starts_at: formatter.string(from: Date()),
                ends_at: nil,
                status: "confirmed",
                date_created: nil,
                date_updated: nil,
                owner: nil,
                ics_url: nil,
                negotiation_id: nil,
                venue: nil,
                participants: nil,
                calendar_synced: nil
            ),
            isPresented: .constant(true),
            onAddToCalendar: { print("Add to Calendar tapped") },
            onNavigate: { print("Navigate tapped") },
            onShare: { print("Share tapped") }
        )
    }
}
