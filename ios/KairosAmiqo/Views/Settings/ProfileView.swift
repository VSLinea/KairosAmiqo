//
//  ProfileView.swift
//  KairosAmiqo
//
//  Profile screen placeholder
//  Avatar, settings, help, sign out
//

import SwiftUI

/// Profile view - User info, settings, and account management
/// Consolidates profile + settings into one sheet (replaces Settings tab)
struct ProfileView: View {
    @ObservedObject var vm: AppVM
    @Environment(\.dismiss) private var dismiss
    @State private var showingTutorial = false
    @State private var showPaywall = false
    
    // Settings state
    @State private var notificationsEnabled = true
    @State private var calendarSyncEnabled = false
    @State private var locationEnabled = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: KairosAuth.Spacing.cardSpacing) {
                        // Avatar and user info card
                        DashboardCard {
                            VStack(spacing: KairosAuth.Spacing.large) {
                                // Avatar
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: KairosAuth.IconSize.tutorialIcon))
                                    .foregroundColor(KairosAuth.Color.accent)
                                    .accessibilityHidden(true)
                                
                                VStack(spacing: KairosAuth.Spacing.xs) {
                                    Text(vm.currentUser?.name ?? "Kairos User")
                                        .font(KairosAuth.Typography.cardTitle)
                                        .foregroundColor(KairosAuth.Color.primaryText)
                                    
                                    Text(vm.currentUser?.username ?? vm.defaultEmail)
                                        .font(KairosAuth.Typography.itemSubtitle)
                                        .foregroundColor(KairosAuth.Color.secondaryText)
                                }
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
                        
                        // Settings Card
                        DashboardCard {
                            VStack(spacing: KairosAuth.Spacing.large) {
                                // Header
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                                        .foregroundColor(KairosAuth.Color.accent)
                                        .accessibilityHidden(true)
                                    
                                    Text("Settings")
                                        .font(KairosAuth.Typography.cardTitle)
                                        .foregroundColor(KairosAuth.Color.primaryText)
                                    
                                    Spacer()
                                }
                                
                                // Settings Items
                                VStack(spacing: 0) {
                                    ProfileMenuItem(
                                        icon: "bell.fill",
                                        title: "Notifications",
                                        subtitle: "Push alerts for invitation updates",
                                        accentColor: KairosAuth.Color.accent,
                                        action: {
                                            notificationsEnabled.toggle()
                                        },
                                        trailingContent: {
                                            Toggle("", isOn: $notificationsEnabled)
                                                .labelsHidden()
                                                .tint(KairosAuth.Color.accent)
                                                .accessibilityLabel("Notifications")
                                                .accessibilityHint("Toggle push alerts for invitation updates")
                                        }
                                    )
                                    
                                    Divider()
                                        .background(KairosAuth.Color.cardBorder)
                                        .padding(.vertical, KairosAuth.Spacing.small)
                                    
                                    ProfileMenuItem(
                                        icon: "calendar.badge.clock",
                                        title: "Calendar Sync",
                                        subtitle: "Auto-add confirmed events",
                                        accentColor: KairosAuth.Color.teal,
                                        action: {
                                            calendarSyncEnabled.toggle()
                                        },
                                        trailingContent: {
                                            Toggle("", isOn: $calendarSyncEnabled)
                                                .labelsHidden()
                                                .tint(KairosAuth.Color.accent)
                                                .accessibilityLabel("Calendar sync")
                                                .accessibilityHint("Toggle automatically adding confirmed events to your calendar")
                                        }
                                    )
                                    
                                    Divider()
                                        .background(KairosAuth.Color.cardBorder)
                                        .padding(.vertical, KairosAuth.Spacing.small)
                                    
                                    NavigationLink(destination: ThemePickerView()) {
                                        HStack(spacing: KairosAuth.Spacing.medium) {
                                            // Icon
                                            Image(systemName: "paintpalette.fill")
                                                .font(.system(size: KairosAuth.IconSize.cardIcon))
                                                .foregroundColor(KairosAuth.Color.purple)
                                                .accessibilityHidden(true)
                                                .frame(width: 40, height: 40)
                                                .background(
                                                    KairosAuth.Color.purple.opacity(0.15)
                                                        .clipShape(Circle())
                                                )
                                            
                                            // Content
                                            VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                                                Text("Theme")
                                                    .font(KairosAuth.Typography.itemTitle)
                                                    .foregroundColor(KairosAuth.Color.primaryText)
                                                
                                                Text(KairosAuth.activeTheme.displayName)
                                                    .font(KairosAuth.Typography.itemSubtitle)
                                                    .foregroundColor(KairosAuth.Color.secondaryText)
                                            }
                                            
                                            Spacer()
                                            
                                            // Chevron
                                            Image(systemName: "chevron.right")
                                                .font(KairosAuth.Typography.buttonIcon)
                                                .foregroundColor(KairosAuth.Color.tertiaryText)
                                                .accessibilityHidden(true)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                            
                            // Help & Info Card
                            DashboardCard {
                                VStack(spacing: 0) {
                                    ProfileMenuItem(
                                        icon: "lightbulb.fill",
                                        title: "Tutorial",
                                        subtitle: "Learn how to use Kairos",
                                        accentColor: KairosAuth.Color.accent,
                                        action: {
                                            showingTutorial = true
                                        }
                                    )
                                    
                                    Divider()
                                        .background(KairosAuth.Color.cardBorder)
                                        .padding(.vertical, KairosAuth.Spacing.small)
                                    
                                    ProfileMenuItem(
                                        icon: "questionmark.circle.fill",
                                        title: "Help & Support",
                                        subtitle: "FAQs and contact us",
                                        accentColor: KairosAuth.Color.teal,
                                        action: {
                                            if let url = URL(string: "https://kairos.app/help") {
#if canImport(UIKit)
                                                UIApplication.shared.open(url)
#endif
                                            }
                                        }
                                    )
                                    
                                    Divider()
                                        .background(KairosAuth.Color.cardBorder)
                                        .padding(.vertical, KairosAuth.Spacing.small)
                                    
                                    ProfileMenuItem(
                                        icon: "doc.text.fill",
                                        title: "Privacy Policy",
                                        subtitle: "How we protect your data",
                                        accentColor: KairosAuth.Color.purple,
                                        action: {
                                            if let url = URL(string: "https://kairos.app/privacy") {
#if canImport(UIKit)
                                                UIApplication.shared.open(url)
#endif
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                            
                            // Sign out button
                            Button(action: {
                                // Dismiss profile sheet FIRST
                                dismiss()
                                
                                // Small delay to let sheet animation complete
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    vm.signOut()
                                }
                            }) {
                                HStack(spacing: KairosAuth.Spacing.small) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: KairosAuth.IconSize.itemIcon))
                                        .accessibilityHidden(true)
                                    Text("Sign Out")
                                        .font(KairosAuth.Typography.buttonLabel)
                                }
                                .foregroundColor(KairosAuth.Color.mutedText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, KairosAuth.Spacing.buttonVertical)
                                .background(
                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                                        .fill(KairosAuth.Color.mutedBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                                        .stroke(KairosAuth.Color.cardBorder.opacity(0.5), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                            .padding(.bottom, KairosAuth.Spacing.dashboardVertical)
                            .accessibilityHint("Signs out of Kairos Amiqo")
                        }
                    }
                }
            }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Profile")
                    .font(KairosAuth.Typography.screenTitle)
                    .foregroundColor(KairosAuth.Color.primaryText)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.close))
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("Close profile")
            }
        }
        .sheet(isPresented: $showingTutorial) {
            TutorialView(onDismiss: {
                showingTutorial = false
            })
        }
        .sheet(isPresented: $showPaywall) {
            PlusPaywallView(
                storeManager: vm.storeManager,
                reason: "Upgrade to Plus for unlimited invitations and priority support"
            )
        }
        .background(KairosAuth.Color.backgroundGradient(), ignoresSafeAreaEdges: .all)
    }
}

// MARK: - Profile Menu Item

private struct ProfileMenuItem<TrailingContent: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    let action: () -> Void
    let trailingContent: (() -> TrailingContent)?
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        accentColor: Color,
        action: @escaping () -> Void,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.action = action
        self.trailingContent = trailingContent
    }

    init(
        icon: String,
        title: String,
        subtitle: String,
        accentColor: Color,
        action: @escaping () -> Void
    ) where TrailingContent == EmptyView {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.action = action
        self.trailingContent = nil
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: KairosAuth.Spacing.medium) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: KairosAuth.IconSize.cardIcon))
                    .foregroundColor(accentColor)
                    .accessibilityHidden(true)
                    .frame(width: 40, height: 40)
                    .background(
                        accentColor.opacity(0.15)
                            .clipShape(Circle())
                    )
                
                // Content
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                    Text(title)
                        .font(KairosAuth.Typography.itemTitle)
                        .foregroundColor(KairosAuth.Color.primaryText)
                    
                    Text(subtitle)
                        .font(KairosAuth.Typography.itemSubtitle)
                        .foregroundColor(KairosAuth.Color.secondaryText)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(title). \(subtitle)")
                
                Spacer()
                
                // Trailing content or chevron
                if let trailingContent = trailingContent {
                    trailingContent()
                } else {
                    Image(systemName: "chevron.right")
                        .font(KairosAuth.Typography.buttonIcon)
                        .foregroundColor(KairosAuth.Color.tertiaryText)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = AppVM(forPreviews: true)
        vm.jwt = "PREVIEW_TOKEN"
        return ProfileView(vm: vm)
    }
}
#endif

