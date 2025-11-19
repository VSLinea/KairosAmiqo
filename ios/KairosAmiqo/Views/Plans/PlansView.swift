//
//  PlansView.swift
//  KairosAmiqo
//
//  Proposals tab - Multi-step creation flow and sectioned proposal list
//  UX Spec §2: WHO → WHAT-WHEN → WHERE flow with proper visual hierarchy
//

import SwiftUI

/// Navigation destination for Proposals full lists (matches Dashboard pattern)
enum ProposalsDestination: Hashable {
    case waitingForYouList
    case waitingForOthersList
    case confirmedList
}

struct PlansView: View {
    @ObservedObject var vm: AppVM
    var onScrollOffsetChange: ((CGFloat) -> Void)? = nil // Tab bar auto-hide callback
    
    // REMOVED: Local @State for showingCreateProposal (now in AppVM)

    // Navigation state for horizontal slide (matches Dashboard)
    @State private var navigationPath = NavigationPath()

    // Modal state (matches Dashboard pattern)
    @State private var isAnyModalPresented = false
    enum ModalContent {
        case plan(Negotiation)
    }
    @State private var modalContent: ModalContent?
    
    // Task 29: Paywall state
    @State private var showPaywall = false
    @State private var paywallReason = ""

    // MARK: - Computed Properties for Sectioning

    private var waitingForYou: [Negotiation] {
        vm.items.filter { plan in
            let status = plan.status?.lowercased() ?? ""
            return status == "proposed" || status == "pending"
        }
        .sorted { ($0.started_at ?? "") > ($1.started_at ?? "") }
    }

    private var waitingForOthers: [Negotiation] {
        vm.items.filter { plan in
            let status = plan.status?.lowercased() ?? ""
            return status == "started" || status == "countered"
        }
        .sorted { ($0.started_at ?? "") > ($1.started_at ?? "") }
    }

    private var confirmed: [Negotiation] {
        vm.items.filter { plan in
            let status = plan.status?.lowercased() ?? ""
            return status == "confirmed"
        }
        .sorted { ($0.started_at ?? "") > ($1.started_at ?? "") }
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
                        
                        // Hero Create Card - Per UX Spec §2.1
                        // Note: Draft resume handled implicitly via CreateProposalFlow alert
                        HeroCreatePlanCard(action: {
                            // Task 29: Check free tier limits before showing create proposal flow
                            if vm.canCreatePlan() {
                                vm.selectedTemplate = nil // No template = generic create
                                vm.showingCreateProposal = true
                            } else {
                                paywallReason = vm.getPaywallReason()
                                showPaywall = true
                            }
                        })
                            .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
                            .padding(.top, KairosAuth.Spacing.medium)

                        // Plans List with Sections - Per UX Spec §2.3
                        switch vm.itemsState {
                        case .idle, .loading:
                            ProgressView("Loading invitations…")
                                .foregroundStyle(KairosAuth.Color.primaryText)
                                .padding()

                        case .empty:
                            ContentUnavailableView(
                                "No invitations yet",
                                systemImage: "calendar.badge.plus",
                                description: Text("Tap the card above to create your first invitation")
                            )
                            .foregroundStyle(KairosAuth.Color.secondaryText)
                            .padding()

                        case let .error(msg):
                            VStack(spacing: KairosAuth.Spacing.medium) {
                                Label(msg, systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(KairosAuth.Color.error)
                                Button("Retry") {
                                    Task { try? await vm.fetchPlans() }
                                }
                                .buttonStyle(.kairosPrimary)
                            }
                            .padding()

                        case .loaded:
                            VStack(spacing: KairosAuth.Spacing.extraLarge) {
                                // Section 1: Waiting for You (highest priority) - ALWAYS SHOWN
                                PlanSection(
                                    title: "Waiting for You",
                                    subtitle: "Respond to continue",
                                    icon: "clock.badge.exclamationmark",
                                    count: waitingForYou.count,
                                    highlightColor: KairosAuth.Color.accent,
                                    onViewAll: !waitingForYou.isEmpty ? {
                                        navigationPath.append(ProposalsDestination.waitingForYouList)
                                    } : nil
                                ) {
                                    // Show first 3 plans only in collapsed view
                                    ForEach(Array(waitingForYou.prefix(3)), id: \.id) { plan in
                                        PlanItemCard(plan: plan, vm: vm)
                                            .onTapGesture {
                                                modalContent = .plan(plan)
                                                isAnyModalPresented = true
                                            }
                                    }
                                }

                                // Section 2: Waiting for Others - ALWAYS SHOWN
                                PlanSection(
                                    title: "Waiting for Others",
                                    subtitle: "Awaiting responses",
                                    icon: "hourglass",
                                    count: waitingForOthers.count,
                                    highlightColor: KairosAuth.Color.accent,
                                    onViewAll: !waitingForOthers.isEmpty ? {
                                        navigationPath.append(ProposalsDestination.waitingForOthersList)
                                    } : nil
                                ) {
                                    // Show first 3 plans only in collapsed view
                                    ForEach(Array(waitingForOthers.prefix(3)), id: \.id) { plan in
                                        PlanItemCard(plan: plan, vm: vm)
                                            .onTapGesture {
                                                modalContent = .plan(plan)
                                                isAnyModalPresented = true
                                            }
                                    }
                                }

                                // Section 3: Confirmed - ALWAYS SHOWN
                                PlanSection(
                                    title: "Confirmed",
                                    subtitle: "Ready to go",
                                    icon: "checkmark.circle.fill",
                                    count: confirmed.count,
                                    highlightColor: KairosAuth.Color.accent,
                                    onViewAll: !confirmed.isEmpty ? {
                                        navigationPath.append(ProposalsDestination.confirmedList)
                                    } : nil
                                ) {
                                    // Show first 3 plans only in collapsed view
                                    ForEach(Array(confirmed.prefix(3)), id: \.id) { plan in
                                        PlanItemCard(plan: plan, vm: vm)
                                            .onTapGesture {
                                                modalContent = .plan(plan)
                                                isAnyModalPresented = true
                                            }
                                    }
                                }
                            }
                            .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
                        }

                        Spacer(minLength: KairosAuth.Spacing.tabBarHeight * 1.5)
                    } // Close VStack
                } // Close ScrollView
                .refreshable {
                    // Pull-to-refresh: Reload invitations from Directus
                    try? await vm.fetchPlans()
                }
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    onScrollOffsetChange?(offset)
                }
                // Spatial depth effect - blur and scale back when modal presented (matches Dashboard)
                .blur(radius: isAnyModalPresented ? 8 : 0)
                .scaleEffect(isAnyModalPresented ? 0.95 : 1.0)
                .animation(KairosAuth.Animation.modalPresent, value: isAnyModalPresented)

                // Modal - rendered at top level (matches Dashboard)
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
                        case .plan(let plan):
                            PlanDetailModal(plan: plan, isPresented: Binding(
                                get: { isAnyModalPresented },
                                set: { newValue in
                                    isAnyModalPresented = newValue
                                    if !newValue {
                                        modalContent = nil
                                    }
                                }
                            ), vm: vm) // Pass vm directly as parameter
                        }
                    }
                }

                // Waiting for others toast - Task 14: Multi-participant flow
                if vm.showWaitingMessage, let message = vm.waitingMessageText {
                    WaitingToast(message: message, isShowing: $vm.showWaitingMessage)
                        .zIndex(100)
                }
            } // Close ZStack
            .overlay {
                if isAnyModalPresented {
                    Color.clear
                        .contentShape(Rectangle())
                        .background(KairosAuth.Color.scrim, ignoresSafeAreaEdges: .all)
                        .onTapGesture {
                            withAnimation(KairosAuth.Animation.modalDismiss) {
                                isAnyModalPresented = false
                                modalContent = nil
                            }
                        }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Invitations")
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
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel("Profile")
                    .accessibilityHint("View your profile, settings, and help")
                }
            }
            .navigationDestination(for: ProposalsDestination.self) { destination in
                switch destination {
                case .waitingForYouList:
                    WaitingForYouListView(plans: waitingForYou, vm: vm)
                case .waitingForOthersList:
                    WaitingForOthersListView(plans: waitingForOthers, vm: vm)
                case .confirmedList:
                    ConfirmedListView(plans: confirmed, vm: vm)
                }
            }
            .sheet(isPresented: Binding(
                get: { vm.showingCreateProposal },
                set: { vm.showingCreateProposal = $0 }
            )) {
                // Phase 1: Show mode selector (AI vs Manual)
                // Respects user preference (ask every time, AI default, manual default)
                PlanModeSelector(vm: vm)
            }
            .sheet(isPresented: Binding(
                get: { vm.showConversationalPlanFlow },
                set: { vm.showConversationalPlanFlow = $0 }
            )) {
                ConversationalPlanFlow(vm: vm)
            }
            .sheet(isPresented: $vm.showDeepLinkedPlan) {
                // Deep linked plan modal (Task 16: kairos://plan/{id})
                if let planId = vm.selectedDeepLinkedPlanId,
                   let plan = vm.items.first(where: { $0.id == planId }) {
                    HeroExpansionModal(isPresented: $vm.showDeepLinkedPlan) {
                        PlanDetailModal(plan: plan, isPresented: $vm.showDeepLinkedPlan, vm: vm)
                    }
                } else {
                    // Fallback if plan not found
                    EmptyView()
                }
            }
            .sheet(isPresented: $vm.showGuestResponseSheet) {
                // Guest response flow (Task 16: https://kairos.app/p/{token})
                if let token = vm.guestResponseToken {
                    GuestResponseView(token: token, vm: vm)
                } else {
                    EmptyView()
                }
            }
            .sheet(isPresented: $showPaywall) {
                // Task 29: Plus tier paywall (free tier limits)
                PlusPaywallView(
                    storeManager: vm.storeManager,
                    reason: paywallReason
                )
            }
            .task {
                if case .idle = vm.itemsState {
                    do {
                        try await vm.fetchPlans()
                    } catch {
                        print("❌ [PlansView] Initial fetch failed: \(error)")
                        // State is already set to .error in fetchPlans()
                    }
                }
            }
            .refreshable {
                do {
                    try await vm.fetchPlans()
                } catch {
                    print("❌ [PlansView] Refresh failed: \(error)")
                    // State is already set to .error in fetchPlans()
                }
            }
        } // Close NavigationStack
        .tint(KairosAuth.Color.white) // Apply tint to NavigationStack for all Back buttons
        .background(KairosAuth.Color.backgroundGradient(), ignoresSafeAreaEdges: .all)
    }
}

// MARK: - Hero Create Card

struct HeroCreatePlanCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KairosAuth.Spacing.medium) {
                // Small sparkle icon - subtle and elegant (increased by 50%)
                ZStack {
                    Circle()
                        .fill(KairosAuth.Color.accent.opacity(0.15))

                    Image(systemName: "sparkles")
                        .font(.system(size: KairosAuth.IconSize.heroIcon))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [KairosAuth.Color.accent, KairosAuth.Color.accent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .accessibilityHidden(true)
                }
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

                // Text content
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                    Text("Create New Invitation")
                        .font(KairosAuth.Typography.cardTitle)
                        .foregroundStyle(KairosAuth.Color.primaryText)

                    Text("Coordinate with friends in 3 quick steps")
                        .font(KairosAuth.Typography.cardSubtitle)
                        .foregroundStyle(KairosAuth.Color.secondaryText)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(KairosAuth.Typography.buttonIcon)
                    .foregroundStyle(KairosAuth.Color.accent)
                    .accessibilityHidden(true)
            }
            .padding(KairosAuth.Spacing.cardContentPadding)
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                    .fill(KairosAuth.Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        KairosAuth.Color.accent.opacity(0.3),
                                        KairosAuth.Color.accent.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),  // Hero section enhanced edge glow
                                Color.white.opacity(0.06),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: KairosAuth.Color.accent.opacity(0.1), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Create a new invitation")
        .accessibilityHint("Opens the invitation creation flow")
    }
}

// MARK: - Plan Section Header (Aligned to Design System Standard)

struct PlanSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let count: Int
    let highlightColor: Color
    let onViewAll: (() -> Void)? // Optional callback for "View All" button
    @ViewBuilder let content: Content

    @State private var isExpanded: Bool = false

    private var countText: String {
        if count == 0 {
            return "No invitations"
        } else if count == 1 {
            return "1 invitation"
        } else {
            return "\(count) invitations"
        }
    }

    private var emptyMessage: String {
        switch title {
        case "Waiting for You":
            return "All caught up! No invitations need your attention right now."
        case "Waiting for Others":
            return "No invitations awaiting responses. Start a new invitation to coordinate with friends."
        case "Confirmed":
            return "No confirmed invitations yet. Once everyone agrees, they'll appear here."
        default:
            return "No invitations in this category at the moment."
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
                        .font(Font.system(size: KairosAuth.IconSize.cardIcon))
                        .foregroundStyle(highlightColor)
                        .frame(width: 48, height: 48)
                        .background(highlightColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityHidden(true)

                    // Title + subtitle
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundStyle(KairosAuth.Color.primaryText)

                        Text(subtitle ?? countText)
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundStyle(KairosAuth.Color.secondaryText)
                    }

                    Spacer()

                    // Count badge
                    Text("\(count)")
                        .font(KairosAuth.Typography.cardTitle)
                        .foregroundColor(highlightColor)
                        .frame(minWidth: 32, minHeight: 32)
                        .padding(.horizontal, 8)
                        .background(
                            Circle()
                                .fill(highlightColor.opacity(0.15))
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) section")
            .accessibilityValue(subtitle ?? countText)
            .accessibilityHint(isExpanded ? "Double tap to collapse." : "Double tap to expand.")

            // Expanded content - scrollable list of plans (max 5 visible)
            if isExpanded {
                VStack(spacing: KairosAuth.Spacing.medium) {
                    if count > 0 {
                        // Show up to 5 plans, then "View All" if more
                        content
                            .padding(.top, KairosAuth.Spacing.medium)

                        // View All button at bottom if there are items
                        if count > 3, let onViewAll = onViewAll {
                            Button(action: onViewAll) {
                                HStack {
                                    Text("View All \(count) Invitations")
                                        .font(KairosAuth.Typography.buttonLabel)
                                        .foregroundColor(highlightColor)
                                    Image(systemName: "arrow.right")
                                        .font(KairosAuth.Typography.buttonIcon)
                                        .foregroundColor(highlightColor)
                                        .accessibilityHidden(true)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                        .fill(highlightColor.opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                                .stroke(highlightColor.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("View all \(count) invitations")
                            .accessibilityHint("Opens the full list of \(title.lowercased()) invitations")
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
}

// MARK: - Plan Item Card (Aligned to Dashboard Pattern)

struct PlanItemCard: View {
    let plan: Negotiation
    @ObservedObject var vm: AppVM

    var body: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
            // Header with icon + title
            HStack(spacing: KairosAuth.Spacing.medium) {
                // Icon in standardized container (matches Dashboard EventRow/PlanRow)
                Image(systemName: categoryIcon)
                    .font(.system(size: KairosAuth.IconSize.itemIcon)) // 24pt
                    .foregroundColor(KairosAuth.Color.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        KairosAuth.Color.accent.opacity(0.15)
                            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.small))
                    )
                    .accessibilityHidden(true)

                // Content
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                    Text(plan.title ?? "Untitled Invitation")
                        .font(KairosAuth.Typography.itemTitle)
                        .foregroundStyle(KairosAuth.Color.primaryText)
                        .lineLimit(1)

                    // Metadata chips row (horizontal layout like Dashboard)
                    HStack(spacing: KairosAuth.Spacing.small) {
                        // Participants badge
                        HStack(spacing: KairosAuth.Spacing.xs) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: KairosAuth.IconSize.badge))
                                .accessibilityHidden(true)
                            Text("\(plan.participants?.count ?? 3)")
                                .font(KairosAuth.Typography.statusBadge)
                        }
                        .foregroundColor(KairosAuth.Color.accent)

                        // Status badge
                        Text(plan.status?.uppercased() ?? "PENDING")
                            .font(KairosAuth.Typography.statusBadge)
                            .foregroundColor(KairosAuth.Color.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                KairosAuth.Color.accent.opacity(0.2)
                                    .clipShape(Capsule())
                            )
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(KairosAuth.Typography.buttonIcon)
                    .foregroundColor(KairosAuth.Color.tertiaryText)
                    .accessibilityHidden(true)
            }
        }
        .padding(KairosAuth.Spacing.medium) // Match Dashboard item padding
        .background(
            KairosAuth.Color.itemBackground
                .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.item))
        )
        .overlay(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.item)
                .stroke(KairosAuth.Color.cardBorder.opacity(0.5), lineWidth: 1)
        )
        .shadow(
            color: KairosAuth.Shadow.itemColor,
            radius: KairosAuth.Shadow.itemRadius,
            y: KairosAuth.Shadow.itemY
        )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(plan.title ?? "Untitled invitation"). \(plan.participants?.count ?? 0) participants. Status: \(plan.status ?? "unknown")")
        .accessibilityHint("Double tap to view details.")
    }

    // Map plan category to SF Symbol
    private var categoryIcon: String {
        guard let title = plan.title?.lowercased() else { return "calendar.badge.clock" }

        if title.contains("coffee") || title.contains("café") { return "cup.and.saucer.fill" }
        if title.contains("lunch") || title.contains("dinner") || title.contains("brunch") { return "fork.knife" }
        if title.contains("gym") || title.contains("workout") { return "figure.run" }
        if title.contains("drinks") || title.contains("bar") { return "wineglass.fill" }
        if title.contains("study") || title.contains("work") { return "book.fill" }
        if title.contains("movie") || title.contains("film") { return "popcorn.fill" }
        if title.contains("walk") || title.contains("hike") { return "figure.walk" }

        return "calendar.badge.clock" // Default
    }
}

#Preview {
    PlansView(vm: AppVM())
        .preferredColorScheme(.dark)
}
