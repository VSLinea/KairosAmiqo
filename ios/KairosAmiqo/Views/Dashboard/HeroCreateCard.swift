//
//  HeroCreateCard.swift
//  KairosAmiqo
//
//  Hero card for first-time users
//  Shows intent templates + tutorial hints
//

import SwiftUI

/// Hero card for first-time users - Create new invitation
/// Uses IntentTemplate from Models.swift
struct HeroCreateCard: View {
    @ObservedObject var vm: AppVM
    let onSelectTemplate: (IntentTemplate) -> Void
    let onDismissTutorialHint: () -> Void
    var showTutorialHint: Bool = true

    @State private var selectedTemplate: IntentTemplate?
    @State private var showingTemplatePicker = false  // NEW: Sheet state

    var body: some View {
        KairosAuth.ParallaxStack(intensity: KairosAuth.Motion.cardIntensity) {
            DashboardCard {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.large) {
                    // Header with icon
                    HStack(spacing: KairosAuth.Spacing.medium) {
                        KairosAuth.ParallaxStack(intensity: KairosAuth.Motion.iconIntensity) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: KairosAuth.IconSize.heroIcon))
                                .foregroundColor(KairosAuth.Color.accent)
                                .accessibilityHidden(true)
                        }

                        VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                            Text("Start Inviting")
                                .font(KairosAuth.Typography.cardTitle)
                                .foregroundColor(KairosAuth.Color.primaryText)

                            Text("Create your first invitation")
                                .font(KairosAuth.Typography.cardSubtitle)
                                .foregroundColor(KairosAuth.Color.secondaryText)
                        }

                        Spacer()
                    }

                    Spacer()
                    }

                    // "Choose Template" button - replaces template grid

                // "Choose Template" button - replaces template grid
                Button(action: {
                    showingTemplatePicker = true
                }) {
                    HStack(spacing: KairosAuth.Spacing.medium) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: KairosAuth.IconSize.itemIcon))
                            .foregroundColor(KairosAuth.Color.accent)
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Choose Template")
                                .font(KairosAuth.Typography.itemTitle)
                                .foregroundColor(KairosAuth.Color.primaryText)
                            
                            Text("\(vm.intentTemplates.count) options available")
                                .font(KairosAuth.Typography.itemSubtitle)
                                .foregroundColor(KairosAuth.Color.secondaryText)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundColor(KairosAuth.Color.tertiaryText)
                            .accessibilityHidden(true)
                    }
                    .padding(KairosAuth.Spacing.medium)
                    .background(
                        KairosAuth.Color.itemBackground
                            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Choose invitation template")
                .accessibilityHint("Opens the template picker with available invitation types")
                .task {
                    // Load templates if empty
                    if vm.intentTemplates.isEmpty {
                        do {
                            try await vm.fetchIntentTemplates()
                        } catch {
                            print("❌ Failed to load intent templates: \(error)")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingTemplatePicker) {
            TemplatePickerSheet(
                vm: vm,
                onSelectTemplate: { template in
                    selectedTemplate = template
                    onSelectTemplate(template)
                    showingTemplatePicker = false
                }
            )
        }
    }
}

// MARK: - Template Picker Sheet
struct TemplatePickerSheet: View {
    @ObservedObject var vm: AppVM
    @Environment(\.dismiss) private var dismiss
    let onSelectTemplate: (IntentTemplate) -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: KairosAuth.Spacing.small),
                        GridItem(.flexible(), spacing: KairosAuth.Spacing.small),
                        GridItem(.flexible(), spacing: KairosAuth.Spacing.small),
                        GridItem(.flexible(), spacing: KairosAuth.Spacing.small)
                    ],
                    spacing: KairosAuth.Spacing.small
                ) {
                    ForEach(vm.intentTemplates) { template in
                        TemplateButton(template: template) {
                            onSelectTemplate(template)
                        }
                    }
                }
                .padding(KairosAuth.Spacing.horizontalPadding)
            }
            .background(KairosAuth.Color.backgroundGradient())
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(KairosAuth.Color.cardBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(KairosAuth.Color.accent)
                }
            }
        }
        .presentationBackground(KairosAuth.Color.backgroundGradient())
    }
}

/// Individual template button
private struct TemplateButton: View {
    let template: IntentTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: KairosAuth.Spacing.small) {
                // SF Symbol icon with theme-aware semantic color
                Image(systemName: template.iconName)
                    .font(.system(size: KairosAuth.IconSize.cardIcon))
                    .foregroundColor(template.iconColor)
                    .accessibilityHidden(true)

                Text(template.name)
                    .font(KairosAuth.Typography.timestamp)
                    .foregroundColor(KairosAuth.Color.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                KairosAuth.Color.itemBackground
                    .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.small, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.small, style: .continuous)
                    .stroke(KairosAuth.Color.cardBorder.opacity(0.5), lineWidth: 1)
            )
        }
        .accessibilityLabel("\(template.name) template")
    }
}

// MARK: - Preview

#if DEBUG
struct HeroCreateCardPreview: View {
    @StateObject private var vm = AppVM()
    @State private var showHint = true

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: KairosAuth.Spacing.cardSpacing) {
                    HeroCreateCard(
                        vm: vm,
                        onSelectTemplate: { template in
                            print("Selected: \(template.name)")
                        },
                        onDismissTutorialHint: {
                            showHint = false
                        },
                        showTutorialHint: showHint
                    )
                }
                .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
                .padding(.vertical, KairosAuth.Spacing.dashboardVertical)
            }
        } // Close ParallaxStack
        .background(
            KairosAuth.Color.backgroundGradient(),
            ignoresSafeAreaEdges: .all
        )
    }
}

struct HeroCreateCardPreview_Previews: PreviewProvider {
    static var previews: some View {
        HeroCreateCardPreview()
    }
}
#endif
