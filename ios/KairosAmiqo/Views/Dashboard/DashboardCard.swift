//
//  DashboardCard.swift
//  KairosAmiqo
//
//  Base card component for Dashboard
//  Liquid Glass styling on Blue-Cyan gradient background
//

import SwiftUI

/// Base card wrapper for all Dashboard cards
/// Provides consistent Liquid Glass styling
struct DashboardCard<Content: View>: View {
    let content: () -> Content
    var padding: CGFloat = KairosAuth.Spacing.cardContentPadding

    init(padding: CGFloat = KairosAuth.Spacing.cardContentPadding, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(padding)
        .background(
            KairosAuth.Color.cardBackground
                .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),   // Top rim light
                            Color.white.opacity(0.05),  // Mid fade
                            Color.clear                 // Bottom transparent
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: KairosAuth.Shadow.cardColor,
            radius: KairosAuth.Shadow.cardRadius,
            y: KairosAuth.Shadow.cardY
        )
    }
}

// MARK: - Preview

#if DEBUG
struct DashboardCardPreview: View {
    var body: some View {
        ZStack {
            VStack(spacing: KairosAuth.Spacing.cardSpacing) {
                DashboardCard {
                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
                        Text("Card Title")
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundColor(KairosAuth.Color.primaryText)

                        Text("This is example card content with Liquid Glass styling on Blue-Cyan gradient.")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundColor(KairosAuth.Color.secondaryText)
                    }
                }

                DashboardCard(padding: 16) {
                    Text("Custom padding card")
                        .font(KairosAuth.Typography.itemTitle)
                        .foregroundColor(KairosAuth.Color.primaryText)
                }
            }
            .padding(.horizontal, KairosAuth.Spacing.dashboardHorizontal)
        }
        .background(
            KairosAuth.Color.backgroundGradient(),
            ignoresSafeAreaEdges: .all
        )
    }
}

struct DashboardCardPreview_Previews: PreviewProvider {
    static var previews: some View {
        DashboardCardPreview()
    }
}
#endif
