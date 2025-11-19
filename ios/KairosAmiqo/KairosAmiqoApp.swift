//  KairosAmiqoApp.swift
//  KairosAmiqo
//
//  App entry. Uses an internal RootTabView to avoid 'cannot find ContentView' issues.

import SwiftUI
import os.log
// TODO: Uncomment after adding GoogleSignIn SDK via SPM
// import GoogleSignIn

@main
struct KairosAmiqoApp: App {
    init() {
        // Suppress noisy Simulator network warnings (SO_NOWAKEFROMSLEEP)
        #if targetEnvironment(simulator)
        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        setenv("OS_ACTIVITY_MODE", "disable", 1)
        setenv("IDEPreferLogStreaming", "YES", 1)
        #endif
        
        // Print API configuration on app launch (DEBUG only)
        #if DEBUG
        Config.printConfiguration()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            RootCoordinatorView()
                .onOpenURL { url in
                    // Handle deep links (kairos://plan/{id} or https://kairos.app/p/{token})
                    // The AppVM instance in RootCoordinatorView will handle the URL
                    NotificationCenter.default.post(name: NSNotification.Name("DeepLinkReceived"), object: url)
                }
                // TODO: Uncomment after adding GoogleSignIn SDK
                // .onOpenURL { url in
                //     GIDSignIn.sharedInstance.handle(url)
                // }
        }
    }
}

/// Root coordinator handles splash → onboarding → dashboard → tabs flow
private struct RootCoordinatorView: View {
    @StateObject private var vm = AppVM()

    var body: some View {
        ZStack {
            if vm.launchPhase == .ready {
                RootTabView(vm: vm)
                    .transition(.opacity)
            }

            if vm.launchPhase == .dashboard {
                DashboardView(vm: vm)
                    .transition(.opacity)
            }

            if vm.launchPhase == .onboarding {
                OnboardingView(vm: vm)
                    .transition(.opacity)
            }

            if vm.launchPhase == .initializing {
                SplashView(vm: vm)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: vm.launchPhase)
        .sheet(isPresented: $vm.showLoginSheet) {
            LoginView(vm: vm)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeepLinkReceived"))) { notification in
            if let url = notification.object as? URL {
                vm.handleDeepLink(url: url)
            }
        }
    }
}

/// iOS 18 liquid glass tab bar with separate floating Amiqo button
@available(iOS 18.0, *)
private struct RootTabView: View {
    @ObservedObject var vm: AppVM
    
    // Tab bar auto-hide state
    @State private var scrollOffset: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0
    @State private var tabBarOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content views
            Group {
                switch vm.primaryTab {
                case .dashboard:
                    DashboardView(vm: vm, onScrollOffsetChange: handleScrollOffsetChange)
                        .profileToolbar(vm: vm)
                        .transition(.opacity)
                case .proposals:
                    PlansView(vm: vm, onScrollOffsetChange: handleScrollOffsetChange)
                        .profileToolbar(vm: vm)
                        .transition(.opacity)
                case .events:
                    EventsView(vm: vm, onScrollOffsetChange: handleScrollOffsetChange)
                        .profileToolbar(vm: vm)
                        .transition(.opacity)
                case .places:
                    PlacesView(vm: vm, onScrollOffsetChange: handleScrollOffsetChange)
                        .profileToolbar(vm: vm)
                        .transition(.opacity)
                case .amiqo:
                    AmiqoView(vm: vm)
                        .profileToolbar(vm: vm)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom tab bar area with capsule + floating button
            HStack(spacing: 12) {
                // Main tab bar capsule (5 tabs - no Amiqo)
                LiquidGlassTabBar(selectedTab: $vm.primaryTab)
                    .frame(height: 60)
                
                // Floating Amiqo button (same blur as tab bar)
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        vm.primaryTab = .amiqo
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)  // Match tab bar blur
                        
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        KairosAuth.Color.primaryText.opacity(0.15),
                                        KairosAuth.Color.primaryText.opacity(0.05),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(vm.primaryTab == .amiqo ? KairosAuth.Color.accent : KairosAuth.Color.primaryText.opacity(0.70))
                            .accessibilityHidden(true)
                    }
                    .frame(width: 60, height: 60)
                    .shadow(
                        color: KairosAuth.Color.shadowHeavy,
                        radius: 24,
                        x: 0,
                        y: -8
                    )
                }
                .accessibilityLabel("Open Amiqo assistant")
                .accessibilityHint("Opens the Amiqo assistant to chat and coordinate")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .offset(y: tabBarOffset)
            .zIndex(999) // Ensure tab bar stays on top of all content
        }
        .ignoresSafeArea(.keyboard)
        // ✨ CENTRALIZED PROFILE PRESENTATION - Single source of truth
        .sheet(isPresented: $vm.showingProfile) {
            ProfileView(vm: vm)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(false)
        }
    }
    
    private func handleScrollOffsetChange(_ offset: CGFloat) {
        let delta = offset - lastScrollOffset
        
        #if DEBUG
        print("📊 Scroll: offset=\(offset), lastOffset=\(lastScrollOffset), delta=\(delta), tabBarOffset=\(tabBarOffset)")
        #endif
        
        lastScrollOffset = offset
        
        // Scrolling DOWN: offset becomes more negative → delta is negative → HIDE tab bar
        // Scrolling UP: offset becomes less negative → delta is positive → SHOW tab bar
        if delta < -5 {
            // Scrolling down - hide tab bar
            #if DEBUG
            print("🔽 Hiding tab bar")
            #endif
            withAnimation(KairosAuth.Animation.uiUpdate) {
                tabBarOffset = 100
            }
        } else if delta > 5 {
            // Scrolling up - show tab bar
            #if DEBUG
            print("🔼 Showing tab bar")
            #endif
            withAnimation(KairosAuth.Animation.uiUpdate) {
                tabBarOffset = 0
            }
        } else if offset >= 0 {
            // At top of scroll - always show tab bar
            #if DEBUG
            print("⬆️ At top - showing tab bar")
            #endif
            withAnimation(KairosAuth.Animation.uiUpdate) {
                tabBarOffset = 0
            }
        }
    }
}

/// Custom liquid glass tab bar (iOS 18 .ultraThinMaterial)
@available(iOS 18.0, *)
private struct LiquidGlassTabBar: View {
    @Binding var selectedTab: AppVM.PrimaryTab
    
    private let tabs: [AppVM.PrimaryTab] = [.dashboard, .proposals, .events, .places]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 0) {
                        Image(systemName: iconName(for: tab))
                            .font(.system(size: 28))  // Increased from 22 to 28 (≈30% larger)
                            .foregroundColor(selectedTab == tab ? KairosAuth.Color.accent : KairosAuth.Color.primaryText.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            KairosAuth.Color.primaryText.opacity(0.15),
                            KairosAuth.Color.primaryText.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(
            color: KairosAuth.Color.shadowHeavy,
            radius: 24,
            x: 0,
            y: -8
        )
    }
    
    private func iconName(for tab: AppVM.PrimaryTab) -> String {
        switch tab {
        case .dashboard: return selectedTab == tab ? "house.fill" : "house"
        case .proposals: return selectedTab == tab ? "envelope.badge.fill" : "envelope.badge"
        case .events: return selectedTab == tab ? "calendar.badge.clock.fill" : "calendar.badge.clock"
        case .places: return selectedTab == tab ? "mappin.circle.fill" : "mappin.circle"
        case .amiqo: return "sparkles"
        }
    }
}

// MARK: - Scroll Offset Tracking (kept for future use)

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ModalVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}

#Preview {
    RootCoordinatorView()
}
