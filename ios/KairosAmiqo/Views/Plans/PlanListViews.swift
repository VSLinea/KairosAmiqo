import SwiftUI

// MARK: - Destination List Views (Matches Dashboard Pattern)

struct WaitingForYouListView: View {
    let plans: [Negotiation]
    @ObservedObject var vm: AppVM

    @State private var isAnyModalPresented = false
    @State private var selectedPlan: Negotiation?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                    ForEach(plans, id: \.id) { plan in
                        PlanItemCard(plan: plan, vm: vm)
                            .onTapGesture {
                                selectedPlan = plan
                                isAnyModalPresented = true
                            }
                    }
                }
                .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                .padding(.vertical, KairosAuth.Spacing.large)
            }
            .blur(radius: isAnyModalPresented ? 8 : 0)
            .scaleEffect(isAnyModalPresented ? 0.95 : 1.0)
            .animation(KairosAuth.Animation.modalPresent, value: isAnyModalPresented)

            if isAnyModalPresented, let plan = selectedPlan {
                HeroExpansionModal(isPresented: $isAnyModalPresented) {
                    PlanDetailModal(plan: plan, isPresented: $isAnyModalPresented, vm: vm)
                }
            }

            if vm.showWaitingMessage, let message = vm.waitingMessageText {
                WaitingToast(message: message, isShowing: $vm.showWaitingMessage)
                    .zIndex(100)
            }
        }
        .overlay {
            if isAnyModalPresented {
                Color.clear
                    .contentShape(Rectangle())
                    .background(KairosAuth.Color.scrim, ignoresSafeAreaEdges: .all)
                    .onTapGesture {
                        withAnimation(KairosAuth.Animation.modalDismiss) {
                            isAnyModalPresented = false
                            selectedPlan = nil
                        }
                    }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Waiting for You")
                    .font(KairosAuth.Typography.screenTitle)
                    .foregroundColor(KairosAuth.Color.white)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    print("Profile tapped from Waiting for You")
                }) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.profileButton))
                        .foregroundColor(KairosAuth.Color.accent)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("Profile")
            }
        }
        .background(KairosAuth.Color.backgroundGradient(), ignoresSafeAreaEdges: .all)
    }
}

struct WaitingForOthersListView: View {
    let plans: [Negotiation]
    @ObservedObject var vm: AppVM

    @State private var isAnyModalPresented = false
    @State private var selectedPlan: Negotiation?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                    ForEach(plans, id: \.id) { plan in
                        PlanItemCard(plan: plan, vm: vm)
                            .onTapGesture {
                                selectedPlan = plan
                                isAnyModalPresented = true
                            }
                    }
                }
                .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                .padding(.vertical, KairosAuth.Spacing.large)
            }
            .blur(radius: isAnyModalPresented ? 8 : 0)
            .scaleEffect(isAnyModalPresented ? 0.95 : 1.0)
            .animation(KairosAuth.Animation.modalPresent, value: isAnyModalPresented)

            if isAnyModalPresented, let plan = selectedPlan {
                HeroExpansionModal(isPresented: $isAnyModalPresented) {
                    PlanDetailModal(plan: plan, isPresented: $isAnyModalPresented, vm: vm)
                }
            }

            if vm.showWaitingMessage, let message = vm.waitingMessageText {
                WaitingToast(message: message, isShowing: $vm.showWaitingMessage)
                    .zIndex(100)
            }
        }
        .overlay {
            if isAnyModalPresented {
                Color.clear
                    .contentShape(Rectangle())
                    .background(KairosAuth.Color.scrim, ignoresSafeAreaEdges: .all)
                    .onTapGesture {
                        withAnimation(KairosAuth.Animation.modalDismiss) {
                            isAnyModalPresented = false
                            selectedPlan = nil
                        }
                    }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Waiting for Others")
                    .font(KairosAuth.Typography.screenTitle)
                    .foregroundColor(KairosAuth.Color.white)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    print("Profile tapped from Waiting for Others")
                }) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.profileButton))
                        .foregroundColor(KairosAuth.Color.accent)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("Profile")
            }
        }
        .background(KairosAuth.Color.backgroundGradient(), ignoresSafeAreaEdges: .all)
    }
}

struct ConfirmedListView: View {
    let plans: [Negotiation]
    @ObservedObject var vm: AppVM

    @State private var isAnyModalPresented = false
    @State private var selectedPlan: Negotiation?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                    ForEach(plans, id: \.id) { plan in
                        PlanItemCard(plan: plan, vm: vm)
                            .onTapGesture {
                                selectedPlan = plan
                                isAnyModalPresented = true
                            }
                    }
                }
                .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                .padding(.vertical, KairosAuth.Spacing.large)
            }
            .blur(radius: isAnyModalPresented ? 8 : 0)
            .scaleEffect(isAnyModalPresented ? 0.95 : 1.0)
            .animation(KairosAuth.Animation.modalPresent, value: isAnyModalPresented)

            if isAnyModalPresented, let plan = selectedPlan {
                HeroExpansionModal(isPresented: $isAnyModalPresented) {
                    PlanDetailModal(plan: plan, isPresented: $isAnyModalPresented, vm: vm)
                }
            }

            if vm.showWaitingMessage, let message = vm.waitingMessageText {
                WaitingToast(message: message, isShowing: $vm.showWaitingMessage)
                    .zIndex(100)
            }
        }
        .overlay {
            if isAnyModalPresented {
                Color.clear
                    .contentShape(Rectangle())
                    .background(KairosAuth.Color.scrim, ignoresSafeAreaEdges: .all)
                    .onTapGesture {
                        withAnimation(KairosAuth.Animation.modalDismiss) {
                            isAnyModalPresented = false
                            selectedPlan = nil
                        }
                    }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Confirmed Invitations")
                    .font(KairosAuth.Typography.screenTitle)
                    .foregroundColor(KairosAuth.Color.white)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    print("Profile tapped from Confirmed Invitations")
                }) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.profileButton))
                        .foregroundColor(KairosAuth.Color.accent)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("Profile")
            }
        }
        .background(KairosAuth.Color.backgroundGradient(), ignoresSafeAreaEdges: .all)
    }
}
