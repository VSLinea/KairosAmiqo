//
//  ThemePickerView.swift
//  KairosAmiqo
//
//  Theme selector for switching between Amiqo and Midnight Blue themes
//

import SwiftUI

struct ThemePickerView: View {
    @State private var selectedTheme: KairosAuth.Theme = KairosAuth.activeTheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(KairosAuth.Typography.closeIcon)
                            .foregroundColor(KairosAuth.Color.primaryText)
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel("Close")
                    .accessibilityHint("Dismiss appearance settings")
                    
                    Spacer()
                    
                    Text("Appearance")
                        .font(KairosAuth.Typography.screenTitle)
                        .foregroundColor(KairosAuth.Color.primaryText)
                    
                    Spacer()
                    
                    // Invisible spacer for balance
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
                .padding(.top, KairosAuth.Spacing.medium)
                
                ScrollView {
                    VStack(spacing: KairosAuth.Spacing.medium) {
                        // Theme Cards
                        ForEach(KairosAuth.Theme.allCases) { theme in
                            Button(action: {
                                withAnimation(KairosAuth.Animation.uiUpdate) {
                                    selectedTheme = theme
                                    KairosAuth.activeTheme = theme
                                }
                            }) {
                                ThemeCard(
                                    theme: theme,
                                    isSelected: selectedTheme == theme
                                )
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(theme.displayName) theme")
                                .accessibilityHint(selectedTheme == theme ? "Currently selected" : "Double tap to switch to this theme")
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Info Section
                        VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                            Text("About Themes")
                                .font(KairosAuth.Typography.itemTitle)
                                .foregroundColor(KairosAuth.Color.primaryText)
                            
                            Text("Themes change the color palette and visual style of the app. Your selection is saved and applied across all screens.")
                                .font(KairosAuth.Typography.itemSubtitle)
                                .foregroundColor(KairosAuth.Color.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(KairosAuth.Spacing.cardPadding)
                        .background(KairosAuth.Color.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                                .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card))
                    }
                    .padding(KairosAuth.Spacing.horizontalPadding)
                    .padding(.top, KairosAuth.Spacing.large)
                }
            }
        }
        .background(KairosAuth.Color.backgroundGradient(), ignoresSafeAreaEdges: .all)
    }
}

struct ThemeCard: View {
    let theme: KairosAuth.Theme
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
            // Theme Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.displayName)
                        .font(KairosAuth.Typography.cardTitle)
                        .foregroundColor(KairosAuth.Color.primaryText)
                    
                    Text(theme.description)
                        .font(KairosAuth.Typography.itemSubtitle)
                        .foregroundColor(KairosAuth.Color.secondaryText)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: KairosAuth.IconSize.cardIcon))
                        .foregroundColor(KairosAuth.Color.accent)
                        .accessibilityHidden(true)
                }
            }
            
            // Theme Preview
            ThemePreview(theme: theme)
        }
        .padding(KairosAuth.Spacing.cardPadding)
        .background(isSelected ? KairosAuth.Color.selectedBackground : KairosAuth.Color.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                .stroke(isSelected ? KairosAuth.Color.accent.opacity(0.5) : KairosAuth.Color.cardBorder, lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card))
        .shadow(
            color: isSelected ? KairosAuth.Color.accent.opacity(0.2) : .clear,
            radius: KairosAuth.Shadow.itemRadius,
            y: KairosAuth.Shadow.itemY
        )
    }
}

struct ThemePreview: View {
    let theme: KairosAuth.Theme
    
    var body: some View {
        VStack(spacing: KairosAuth.Spacing.small) {
            // Color swatches
            HStack(spacing: KairosAuth.Spacing.small) {
                ForEach(previewColors, id: \.self) { color in
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.small)
                        .fill(color)
                        .frame(height: 40)
                }
            }
            
            // Mini card preview
            HStack {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                    Text("Sample Card")
                        .font(KairosAuth.Typography.itemSubtitle)
                        .foregroundColor(previewTextColor)
                    
                    Text("Preview")
                        .font(KairosAuth.Typography.statusBadge)
                        .foregroundColor(previewTextColor.opacity(0.7))
                }
                
                Spacer()
                
                RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                    .fill(previewAccent)
                    .frame(width: 60, height: 24)
                    .overlay(
                        Text("Button")
                            .font(KairosAuth.Typography.statusBadge)
                            .foregroundColor(previewButtonTextColor)
                    )
            }
            .padding(KairosAuth.Spacing.rowSpacing)
            .background(previewCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.button)
                    .stroke(previewCardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button))
        }
        .accessibilityHidden(true)
    }
    
    // Theme-specific preview colors
    private var previewColors: [SwiftUI.Color] {
        KairosAuth.ThemePreviewPalette.swatches(for: theme)
    }

    private var previewAccent: SwiftUI.Color {
        KairosAuth.ThemePreviewPalette.accent(for: theme)
    }

    private var previewCardBackground: SwiftUI.Color {
        KairosAuth.ThemePreviewPalette.cardBackground(for: theme)
    }

    private var previewCardBorder: SwiftUI.Color {
        KairosAuth.ThemePreviewPalette.cardBorder(for: theme)
    }

    private var previewTextColor: SwiftUI.Color {
        KairosAuth.ThemePreviewPalette.text(for: theme)
    }

    private var previewButtonTextColor: SwiftUI.Color {
        KairosAuth.ThemePreviewPalette.buttonText(for: theme)
    }
}

#Preview {
    ThemePickerView()
}
