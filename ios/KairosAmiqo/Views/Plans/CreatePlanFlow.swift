import SwiftUI
import MessageUI

/// Multi-step plan creation wizard matching UX spec §2.2
/// Steps: WHO (participants) → WHAT-WHEN (intent + times) → WHERE (venues) → Review
/// Auto-saves draft to UserDefaults on every change
/// Supports optional template pre-selection from Dashboard shortcuts
struct CreateProposalFlow: View {
    @ObservedObject var vm: AppVM
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    /// Optional template to pre-select (from Dashboard template tiles)
    let template: IntentTemplate?

    enum Step: Int, CaseIterable {
        case participants = 0
        case intentAndTimes = 1
        case venues = 2
        case review = 3

        var title: String {
            switch self {
            case .participants: return "Who's invited?"
            case .intentAndTimes: return "What & When?"
            case .venues: return "Where?"
            case .review: return "Review & Send"
            }
        }

        var icon: String {
            switch self {
            case .participants: return "person.2.fill"
            case .intentAndTimes: return "calendar.badge.clock"
            case .venues: return "mappin.and.ellipse"
            case .review: return "paperplane.fill"
            }
        }
    }

    @State private var currentStep: Step = .participants
    @State private var selectedParticipants: [PlanParticipant] = []
    @State private var selectedIntent: IntentTemplate?
    @State private var selectedTimes: [ProposedSlot] = []
    @State private var selectedVenues: [VenueInfo] = []
    @State private var showResumeDraftAlert = false
    
    // Success feedback state
    @State private var showSuccessToast = false
    @State private var showPlanDetailModal = false
    @State private var createdPlan: Negotiation?
    
    // Edit mode state (when editing from Review step)
    @State private var isEditingFromReview = false
    
    // SMS invite state
    @State private var showingSMSComposer = false
    @State private var smsRecipients: [String] = []
    @State private var smsBody: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    progressIndicator

                    ScrollView {
                        VStack(spacing: KairosAuth.Spacing.large) {
                            stepContent
                        }
                        .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
                        .padding(.top, KairosAuth.Spacing.large)
                        .padding(.bottom, KairosAuth.Spacing.tabBarHeight * 1.5)
                    }
                }
            }
            .background(
                KairosAuth.Color.backgroundGradient(),
                ignoresSafeAreaEdges: .all
            )
        }
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(currentStep.title)
                    .font(KairosAuth.Typography.screenTitle)
                    .foregroundStyle(KairosAuth.Color.white)
            }

            ToolbarItem(placement: .cancellationAction) {
                if currentStep != .participants {
                    // Back button for multi-step flow
                    Button(action: goBack) {
                        HStack(spacing: KairosAuth.Spacing.xs) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: KairosAuth.IconSize.button, weight: .semibold))
                                .accessibilityHidden(true)
                            Text("Back")
                        }
                        .font(KairosAuth.Typography.buttonLabel)
                        .foregroundStyle(KairosAuth.Color.accent)
                    }
                } else {
                    Button("Cancel") {
                        autosaveDraft() // Save before closing
                        dismiss()
                    }
                    .font(KairosAuth.Typography.buttonLabel)
                    .foregroundStyle(KairosAuth.Color.secondaryText)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                // Hide toolbar button on Review step (use in-content "Send Invites" button instead)
                if currentStep != .review {
                    Button(isEditingFromReview ? "Done" : "Next") {
                        if isEditingFromReview {
                            returnToReview()
                        } else {
                            advanceStep()
                        }
                    }
                    .font(KairosAuth.Typography.buttonLabel)
                    .foregroundStyle(canAdvance ? KairosAuth.Color.accent : KairosAuth.Color.tertiaryText)
                    .disabled(!canAdvance)
                }
            }
        }
        // Success toast overlay
        .overlay(alignment: .top) {
            if showSuccessToast {
                successToast
                    .padding(.top, 60) // Below status bar
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showSuccessToast)
            }
        }
        // Plan detail modal (shown after successful creation)
        .sheet(isPresented: $showPlanDetailModal) {
            if let plan = createdPlan {
                PlanDetailModal(plan: plan, isPresented: $showPlanDetailModal, vm: vm)
            }
        }
        .onAppear {
            // Template takes precedence over draft
            if let template = template {
                // Dashboard shortcut: pre-select template and start fresh
                selectedIntent = template
                DraftPlan.clear() // Clear any old draft when starting from template
            } else {
                // No template: check for interrupted draft
                loadDraftIfExists()
            }
        }
        .onChange(of: selectedParticipants) { _, _ in autosaveDraft() }
        .onChange(of: selectedIntent) { _, _ in autosaveDraft() }
        .onChange(of: selectedTimes) { _, _ in autosaveDraft() }
        .onChange(of: selectedVenues) { _, _ in autosaveDraft() }
        .onChange(of: currentStep) { _, _ in autosaveDraft() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                autosaveDraft()
            }
        }
        .alert("Resume Draft?", isPresented: $showResumeDraftAlert) {
            Button("Resume") {
                loadDraft()
            }
            Button("Start Fresh", role: .destructive) {
                DraftPlan.clear()
            }
        } message: {
            Text("You have an unsent invitation. Would you like to continue editing?")
        }
        .sheet(isPresented: $showingSMSComposer) {
            if SMSHelper.canSendSMS() {
                SMSComposeView(
                    recipients: smsRecipients,
                    body: smsBody,
                    onFinish: { result in
                        switch result {
                        case .sent:
                            print("✅ SMS sent successfully")
                        case .cancelled:
                            print("⏸️ User cancelled SMS")
                        case .failed:
                            print("❌ SMS send failed")
                        @unknown default:
                            break
                        }
                    }
                )
            }
        }
    }

    private func goBack() {
        guard let previousStep = Step(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation(KairosAuth.Animation.pageTransition) {
            currentStep = previousStep
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .participants:
            ParticipantsStep(vm: vm, selectedParticipants: $selectedParticipants)
        case .intentAndTimes:
            IntentAndTimesStep(vm: vm, selectedIntent: $selectedIntent, selectedTimes: $selectedTimes)
        case .venues:
            VenuesStep(selectedVenues: $selectedVenues, intent: selectedIntent)
        case .review:
            ReviewStep(
                vm: vm,
                participants: selectedParticipants,
                intent: selectedIntent,
                times: selectedTimes,
                venues: selectedVenues,
                onSend: sendInvites,
                onEdit: navigateToStepForEdit
            )
        }
    }

    private var progressIndicator: some View {
        VStack(spacing: KairosAuth.Spacing.xs) {
            HStack(spacing: KairosAuth.Spacing.small) {
                ForEach(Step.allCases, id: \.rawValue) { step in
                    ZStack {
                        Capsule()
                            .fill(KairosAuth.Color.cardBackground)
                            .frame(height: 4)

                        if step.rawValue <= currentStep.rawValue {
                            Capsule()
                                .fill(KairosAuth.Color.accent)
                                .frame(height: 4)
                        }
                    }
                }
            }

            HStack {
                Text("Step \(currentStep.rawValue + 1) of \(Step.allCases.count)")
                    .font(KairosAuth.Typography.statusBadge)
                    .foregroundStyle(KairosAuth.Color.secondaryText)
                Spacer()
                Text(currentStep.title)
                    .font(KairosAuth.Typography.statusBadge)
                    .foregroundStyle(KairosAuth.Color.secondaryText)
            }
        }
        .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
        .padding(.vertical, KairosAuth.Spacing.medium)
        .background(KairosAuth.Color.cardBackground.opacity(0.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(currentStep.rawValue + 1) of \(Step.allCases.count). \(currentStep.title)")
    }

    private var canAdvance: Bool {
        switch currentStep {
        case .participants:
            // Require at least one participant (creator is implicit, not selected)
            return !selectedParticipants.isEmpty
        case .intentAndTimes:
            return selectedIntent != nil && !selectedTimes.isEmpty
        case .venues:
            return !selectedVenues.isEmpty
        case .review:
            return true
        }
    }
    
    private var stepValidationMessage: String? {
        switch currentStep {
        case .participants where selectedParticipants.isEmpty:
            return "Please invite at least one person"
        case .intentAndTimes where selectedIntent == nil:
            return "Please select an activity"
        case .intentAndTimes where selectedTimes.isEmpty:
            return "Please pick at least one time option"
        case .venues where selectedVenues.isEmpty:
            return "Please choose at least one venue"
        default:
            return nil
        }
    }

    private func advanceStep() {
        guard let nextStep = Step(rawValue: currentStep.rawValue + 1) else { return }
        withAnimation(KairosAuth.Animation.pageTransition) {
            currentStep = nextStep
        }
    }
    
    private func navigateToStepForEdit(_ step: Step) {
        isEditingFromReview = true
        withAnimation(KairosAuth.Animation.pageTransition) {
            currentStep = step
        }
    }
    
    private func returnToReview() {
        isEditingFromReview = false
        withAnimation(KairosAuth.Animation.pageTransition) {
            currentStep = .review
        }
    }

    private func sendInvites() {
        guard let intent = selectedIntent else { return }

        Task {
            do {
                let created = try await vm.createProposal(
                    intent: intent,
                    participants: selectedParticipants,
                    times: selectedTimes,
                    venues: selectedVenues
                )

                DraftPlan.clear()
                createdPlan = created

                await routeInvites(for: created)

                await MainActor.run {
                    showSuccessToast = true
                }

                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    showSuccessToast = false
                }

                dismiss()

                try? await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run {
                    showPlanDetailModal = true
                }
            } catch {
                print("❌ Failed to create proposal: \(error)")
                // TODO: Surface user-visible error (alert/toast)
            }
        }
    }
    
    // MARK: - Invite Routing
    
    /// Routes invites to participants based on their contact info
    /// - Kairos users (no email/phone): Push notification (mock)
    /// - Phone contacts (has phone): SMS with web link
    /// - Email contacts (has email): Email (mock - Phase 3+)
    private func routeInvites(for plan: Negotiation) async {
        guard let planTitle = plan.title else { return }
        
        // Generate unique token for web app link
        let token = SMSHelper.generateToken(for: plan.id)
        
        // Separate participants by invite channel based on available contact info
        var smsParticipants: [PlanParticipant] = []
        var pushParticipants: [PlanParticipant] = []
        
        for participant in selectedParticipants {
            // Route based on contact info availability:
            // - Has phone → SMS
            // - No phone/email → Push (Kairos user)
            if participant.phone != nil {
                smsParticipants.append(participant)
            } else {
                pushParticipants.append(participant)
            }
        }
        
        print("📤 Invite routing: \(pushParticipants.count) push, \(smsParticipants.count) SMS")
        
        // Send push notifications (mock - Phase 4: real backend push)
        for participant in pushParticipants {
            print("📲 Push to \(participant.name): Plan '\(planTitle)' created")
        }
        
        // Send SMS invites if available
        if !smsParticipants.isEmpty && SMSHelper.canSendSMS() {
            await sendSMSInvites(
                to: smsParticipants,
                planTitle: planTitle,
                token: token
            )
        }
    }
    
    /// Send SMS invites to phone contacts and manual entries
    private func sendSMSInvites(to participants: [PlanParticipant], planTitle: String, token: String) async {
        await MainActor.run {
            // Collect phone numbers (filter out email-only participants)
            smsRecipients = participants.compactMap { $0.phone }
            
            // Generate invite message
            let inviterName = "You" // TODO: Get from vm.user?.name
            smsBody = SMSHelper.generateInviteMessage(
                planTitle: planTitle,
                inviterName: inviterName,
                token: token
            )
            
            // Show native SMS composer
            if !smsRecipients.isEmpty {
                showingSMSComposer = true
            }
        }
    }

    // MARK: - Auto-Save Logic

    private func loadDraftIfExists() {
        guard let draft = DraftPlan.load() else { return }

        // Only show resume alert if draft has meaningful content
        if draft.hasContent {
            showResumeDraftAlert = true
        }
    }

    private func loadDraft() {
        guard let draft = DraftPlan.load() else { return }

        selectedParticipants = draft.participants
        selectedIntent = draft.intent
        selectedTimes = draft.times
        selectedVenues = draft.venues
        currentStep = Step(rawValue: draft.currentStep) ?? .participants
    }

    private func autosaveDraft() {
        let draft = DraftPlan(
            participants: selectedParticipants,
            intent: selectedIntent,
            times: selectedTimes,
            venues: selectedVenues,
            currentStep: currentStep.rawValue
        )
        draft.save()
    }
    
    // MARK: - Success Toast
    
    private var successToast: some View {
        HStack(spacing: KairosAuth.Spacing.small) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: KairosAuth.IconSize.itemIcon))
                .foregroundStyle(KairosAuth.Color.white)
                .accessibilityHidden(true)
            
            Text("Invitation sent to \(selectedParticipants.count) \(selectedParticipants.count == 1 ? "person" : "people")")
                .font(KairosAuth.Typography.buttonLabel)
                .foregroundStyle(KairosAuth.Color.white)
        }
        .padding(.horizontal, KairosAuth.Spacing.medium)
        .padding(.vertical, KairosAuth.Spacing.small)
        .background(
            Capsule()
                .fill(KairosAuth.Color.accent)
                .shadow(
                    color: KairosAuth.Shadow.cardColor,
                    radius: KairosAuth.Shadow.cardRadius,
                    y: KairosAuth.Shadow.cardY
                )
        )
        .accessibilityElement(children: .combine)
    }

}


// TODO(Kairos): Restore SwiftUI previews once the Xcode build errors are resolved.

// Legacy alias: other files (and Xcode previews) may still reference the older
// CreatePlanFlow name. Keep this lightweight typealias so those callers continue
// to compile while the user-facing copy transitions to "invitation" language.
typealias CreatePlanFlow = CreateProposalFlow
