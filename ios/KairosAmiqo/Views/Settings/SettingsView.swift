//
//  SettingsView.swift
//  KairosAmiqo
//
//  Settings screen for app preferences
//  Notifications, calendar sync, privacy, appearance
//

import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

/// Settings view - App preferences and configuration
struct SettingsView: View {
    @ObservedObject var vm: AppVM
    @State private var notificationsEnabled = true
    @State private var calendarSyncEnabled = false
    @State private var locationEnabled = true

    // Modal state tracking
    @State private var isAnyModalPresented = false
    
    // Task 29: Paywall state
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: KairosAuth.Spacing.cardSpacing) {
                        // Notifications Card
                        DashboardCard {
                            VStack(spacing: KairosAuth.Spacing.large) {
                                HStack {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                                        .foregroundColor(KairosAuth.Color.accent)
                                        .accessibilityHidden(true)

                                    Text("Notifications")
                                        .font(KairosAuth.Typography.cardTitle)
                                        .foregroundColor(KairosAuth.Color.primaryText)

                                    Spacer()
                                }

                                SettingsToggle(
                                    title: "Push Notifications",
                                    subtitle: "Get alerts for invitation updates",
                                    isOn: $notificationsEnabled
                                )
                            }
                        }
                        .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)

                        // Task 29: Subscription Card
                        DashboardCard {
                            VStack(spacing: KairosAuth.Spacing.large) {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                                        .foregroundColor(KairosAuth.Color.accent)
                                        .accessibilityHidden(true)

                                    Text("Subscription")
                                        .font(KairosAuth.Typography.cardTitle)
                                        .foregroundColor(KairosAuth.Color.primaryText)

                                    Spacer()
                                }

                                // Current subscription display
                                HStack {
                                    Text("Current Subscription")
                                        .font(KairosAuth.Typography.itemTitle)
                                        .foregroundColor(KairosAuth.Color.primaryText)
                                    Spacer()
                                    Text(vm.storeManager.subscriptionStatus.displayName)
                                        .font(KairosAuth.Typography.itemSubtitle)
                                        .foregroundColor(KairosAuth.Color.accent)
                                }
                                
                                // Task 29: AI Counter usage (free tier only)
                                if !vm.isPlusUser {
                                    Divider()
                                        .background(KairosAuth.Color.cardBorder)
                                    
                                    HStack {
                                        Image(systemName: "brain.fill")
                                            .font(.system(size: KairosAuth.IconSize.itemIcon))
                                            .foregroundColor(KairosAuth.Color.accent)
                                            .accessibilityHidden(true)
                                        
                                        VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                                            Text("AI Counters This Month")
                                                .font(KairosAuth.Typography.itemTitle)
                                                .foregroundColor(KairosAuth.Color.primaryText)
                                            Text("Use AI to propose alternatives")
                                                .font(KairosAuth.Typography.itemSubtitle)
                                                .foregroundColor(KairosAuth.Color.secondaryText)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(vm.getAICountersUsedThisMonth())/\(vm.getAICounterLimit())")
                                            .font(KairosAuth.Typography.itemTitle)
                                            .foregroundColor(
                                                vm.getAICountersUsedThisMonth() >= vm.getAICounterLimit() ? KairosAuth.Color.warning : KairosAuth.Color.accent
                                            )
                                    }
                                }

                                if !vm.isPlusUser {
                                    // Upgrade button for free users
                                    Button {
                                        showPaywall = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "star.fill")
                                                .foregroundColor(KairosAuth.Color.accent)
                                                .accessibilityHidden(true)
                                            Text("Upgrade to Plus")
                                                .font(KairosAuth.Typography.itemTitle)
                                                .foregroundColor(KairosAuth.Color.primaryText)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(KairosAuth.Color.tertiaryText)
                                                .accessibilityHidden(true)
                                        }
                                        .padding(KairosAuth.Spacing.medium)
                                        .background(
                                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                                                .fill(KairosAuth.Color.accent.opacity(0.1))
                                        )
                                    }
                                } else {
                                    // Manage subscription for Plus users
                                    Button {
                                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                            #if canImport(UIKit)
                                            UIApplication.shared.open(url)
                                            #endif
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "gearshape.fill")
                                                .foregroundColor(KairosAuth.Color.accent)
                                                .accessibilityHidden(true)
                                            Text("Manage Subscription")
                                                .font(KairosAuth.Typography.itemTitle)
                                                .foregroundColor(KairosAuth.Color.primaryText)
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .foregroundColor(KairosAuth.Color.tertiaryText)
                                                .accessibilityHidden(true)
                                        }
                                        .padding(KairosAuth.Spacing.medium)
                                        .background(
                                            RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                                                .fill(KairosAuth.Color.cardBackground)
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)

                    // Calendar Sync Card
                    DashboardCard {
                        VStack(spacing: KairosAuth.Spacing.large) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: KairosAuth.IconSize.cardIcon))
                                    .foregroundColor(KairosAuth.Color.accent)
                                    .accessibilityHidden(true)

                                Text("Calendar Integration")
                                    .font(KairosAuth.Typography.cardTitle)
                                    .foregroundColor(KairosAuth.Color.primaryText)

                                Spacer()
                            }

                            SettingsToggle(
                                title: "Sync with Calendar",
                                subtitle: "Auto-add confirmed events",
                                isOn: $calendarSyncEnabled
                            )
                        }
                    }
                    .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)

                    // Calendar Sync Card
                    DashboardCard {
                        VStack(spacing: KairosAuth.Spacing.large) {
                            HStack {
                                Image(systemName: "wand.and.stars.fill")
                                    .font(.system(size: KairosAuth.IconSize.cardIcon))
                                    .foregroundColor(KairosAuth.Color.accent)
                                    .accessibilityHidden(true)

                                Text("Appearance")
                                    .font(KairosAuth.Typography.cardTitle)
                                    .foregroundColor(KairosAuth.Color.primaryText)

                                Spacer()
                            }

                            // Theme Picker
                            NavigationLink(destination: ThemePickerView()) {
                                HStack {
                                    Image(systemName: "paintpalette.fill")
                                        .font(.system(size: KairosAuth.IconSize.itemIcon))
                                        .accessibilityHidden(true)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Theme")
                                            .font(KairosAuth.Typography.itemTitle)
                                        Text(KairosAuth.activeTheme.displayName)
                                            .font(KairosAuth.Typography.itemSubtitle)
                                            .foregroundColor(KairosAuth.Color.secondaryText)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(KairosAuth.Typography.itemSubtitle)
                                        .foregroundColor(KairosAuth.Color.tertiaryText)
                                        .accessibilityHidden(true)
                                }
                                .foregroundColor(KairosAuth.Color.primaryText)
                                .padding(KairosAuth.Spacing.medium)
                                .background(
                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                                        .fill(KairosAuth.Color.cardBackground)
                                )
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Theme. \(KairosAuth.activeTheme.displayName) selected")
                            .accessibilityHint("Double tap to customize the app appearance")

                            Divider()
                                .background(KairosAuth.Color.cardBorder)

                            SettingsToggle(
                                title: "Motion Effects",
                                subtitle: "Parallax animations (disable if sensitive to motion)",
                                isOn: Binding(
                                    get: { KairosAuth.Motion.isEnabled },
                                    set: { KairosAuth.Motion.isEnabled = $0 }
                                )
                            )
                        }
                    }
                    .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)

                    // Developer Card (DEBUG - Clear Cache + Agent Testing)
                    DashboardCard {
                        VStack(spacing: KairosAuth.Spacing.large) {
                            HStack {
                                Image(systemName: "hammer.fill")
                                    .font(.system(size: KairosAuth.IconSize.cardIcon))
                                    .foregroundColor(KairosAuth.Color.warning)
                                    .accessibilityHidden(true)

                                Text("Developer")
                                    .font(KairosAuth.Typography.cardTitle)
                                    .foregroundColor(KairosAuth.Color.primaryText)

                                Spacer()
                            }

                            // Agent Testing
                            NavigationLink(destination: AgentTestingView(vm: vm)) {
                                HStack {
                                    Image(systemName: "brain.fill")
                                        .font(.system(size: KairosAuth.IconSize.itemIcon))
                                        .accessibilityHidden(true)
                                    Text("Agent Testing")
                                        .font(KairosAuth.Typography.buttonLabel)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(KairosAuth.Typography.itemSubtitle)
                                        .foregroundColor(KairosAuth.Color.tertiaryText)
                                        .accessibilityHidden(true)
                                }
                                .foregroundColor(KairosAuth.Color.accent)
                                .padding(KairosAuth.Spacing.medium)
                                .background(
                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                                        .fill(KairosAuth.Color.accent.opacity(0.1))
                                )
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Agent testing tools")
                            .accessibilityHint("Opens developer tools for agent workflows")

                            Divider()
                                .background(KairosAuth.Color.cardBorder)

                            Button(action: {
                                vm.clearCachedPlans()
                            }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: KairosAuth.IconSize.itemIcon))
                                        .accessibilityHidden(true)
                                    Text("Clear Cached Invitations")
                                        .font(KairosAuth.Typography.buttonLabel)
                                    Spacer()
                                }
                                .foregroundColor(KairosAuth.Color.warning)
                                .padding(KairosAuth.Spacing.medium)
                                .background(
                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                                        .fill(KairosAuth.Color.warning.opacity(0.15))
                                )
                            }
                            
                            Divider()
                                .background(KairosAuth.Color.cardBorder)
                            
                            // Task 29 Testing: Generate test plans
                            Button(action: {
                                vm.generateTestPlans(count: 10)
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: KairosAuth.IconSize.itemIcon))
                                        .accessibilityHidden(true)
                                    Text("Generate 10 Test Invitations")
                                        .font(KairosAuth.Typography.buttonLabel)
                                    Spacer()
                                }
                                .foregroundColor(KairosAuth.Color.accent)
                                .padding(KairosAuth.Spacing.medium)
                                .background(
                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                                        .fill(KairosAuth.Color.accent.opacity(0.1))
                                )
                            }
                            
                            Button(action: {
                                vm.generateTestPlans(count: 20)
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: KairosAuth.IconSize.itemIcon))
                                        .accessibilityHidden(true)
                                    Text("Generate 20 Test Invitations")
                                        .font(KairosAuth.Typography.buttonLabel)
                                    Spacer()
                                }
                                .foregroundColor(KairosAuth.Color.accent)
                                .padding(KairosAuth.Spacing.medium)
                                .background(
                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                                        .fill(KairosAuth.Color.purple.opacity(0.15))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)

                    // Privacy Card
                    DashboardCard {
                        VStack(spacing: KairosAuth.Spacing.large) {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: KairosAuth.IconSize.cardIcon))
                                    .foregroundColor(KairosAuth.Color.accent)
                                    .accessibilityHidden(true)

                                Text("Privacy")
                                    .font(KairosAuth.Typography.cardTitle)
                                    .foregroundColor(KairosAuth.Color.primaryText)

                                Spacer()
                            }

                            SettingsToggle(
                                title: "Location Services",
                                subtitle: "Suggest nearby places",
                                isOn: $locationEnabled
                            )

                            Divider()
                                .background(KairosAuth.Color.cardBorder)

                            SettingsButton(
                                icon: "hand.raised.fill",
                                title: "Privacy Policy",
                                subtitle: "How we protect your data",
                                action: {
                                    print("🔒 Privacy Policy tapped")
                                    // TODO: Open Privacy Policy
                                }
                            )
                        }
                    }
                    .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)

                    // About Card
                    DashboardCard {
                        VStack(spacing: KairosAuth.Spacing.large) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: KairosAuth.IconSize.cardIcon))
                                    .foregroundColor(KairosAuth.Color.accent)
                                    .accessibilityHidden(true)

                                Text("About")
                                    .font(KairosAuth.Typography.cardTitle)
                                    .foregroundColor(KairosAuth.Color.primaryText)

                                Spacer()
                            }

                            SettingsButton(
                                icon: "doc.text.fill",
                                title: "Terms of Service",
                                subtitle: "Legal information",
                                action: {
                                    print("📄 Terms tapped")
                                    // TODO: Open Terms
                                }
                            )

                            Divider()
                                .background(KairosAuth.Color.cardBorder)

                            HStack {
                                VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                                    Text("Version")
                                        .font(KairosAuth.Typography.itemTitle)
                                        .foregroundColor(KairosAuth.Color.primaryText)

                                    Text("Phase 0 - v0.1.0")
                                        .font(KairosAuth.Typography.itemSubtitle)
                                        .foregroundColor(KairosAuth.Color.secondaryText)
                                }

                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                    .padding(.bottom, 100)  // Adequate space above tab bar
                    } // Close VStack
                .padding(.top, KairosAuth.Spacing.small)
                } // Close ScrollView
                .blur(radius: isAnyModalPresented ? 8 : 0)
                .scaleEffect(isAnyModalPresented ? 0.95 : 1.0)
                .animation(KairosAuth.Animation.modalPresent, value: isAnyModalPresented)

            } // Close ZStack
            .overlay {
                if isAnyModalPresented {
                    Color.clear
                        .contentShape(Rectangle())
                        .background(KairosAuth.Color.scrim, ignoresSafeAreaEdges: .all)
                        .onTapGesture {
                            withAnimation(KairosAuth.Animation.modalDismiss) {
                                isAnyModalPresented = false
                            }
                        }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(KairosAuth.Typography.screenTitle)
                        .foregroundColor(KairosAuth.Color.primaryText)
                        .shadow(color: KairosAuth.Color.brandTextShadow, radius: 8, x: 0, y: 2)
                        .shadow(color: KairosAuth.Color.brandTextShadow.opacity(0.4), radius: 4, x: 0, y: 1)
                }
            }
            .sheet(isPresented: $showPaywall) {
                // Task 29: Plus tier paywall
                PlusPaywallView(
                    storeManager: vm.storeManager,
                    reason: "Upgrade to Plus for unlimited invitations and priority support"
                )
            }
        }
        .tint(KairosAuth.Color.white) // Apply tint to NavigationStack for all Back buttons
        .background(KairosAuth.Color.backgroundGradient(), ignoresSafeAreaEdges: .all)
    }
}

/// Settings toggle row
private struct SettingsToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                Text(title)
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundColor(KairosAuth.Color.primaryText)

                Text(subtitle)
                    .font(KairosAuth.Typography.itemSubtitle)
                    .foregroundColor(KairosAuth.Color.secondaryText)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(KairosAuth.Color.accent)
                .accessibilityLabel(title)
                .accessibilityHint(subtitle)
        }
    }
}

/// Settings button row
private struct SettingsButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KairosAuth.Spacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: KairosAuth.IconSize.itemIcon))
                    .foregroundColor(KairosAuth.Color.secondaryText)
                    .frame(width: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                    Text(title)
                        .font(KairosAuth.Typography.itemTitle)
                        .foregroundColor(KairosAuth.Color.primaryText)

                    Text(subtitle)
                        .font(KairosAuth.Typography.itemSubtitle)
                        .foregroundColor(KairosAuth.Color.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(KairosAuth.Typography.buttonIcon)
                    .foregroundColor(KairosAuth.Color.tertiaryText)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

// MARK: - Preview

#Preview {
    SettingsView(vm: AppVM(forPreviews: true))
}
