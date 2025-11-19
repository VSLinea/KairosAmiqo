//
//  DashboardHints.swift
//  KairosAmiqo
//
//  Dashboard contextual hints explaining Plans vs Events
//

import SwiftUI

/// Contextual hint banner for Dashboard cards
struct DashboardHint: View {
    let icon: String
    let message: String
    let accentColor: Color
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: KairosAuth.Spacing.rowSpacing) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: KairosAuth.IconSize.badge))
                .foregroundColor(accentColor)
                .accessibilityHidden(true)

            // Message
            Text(message)
                .font(KairosAuth.Typography.statusBadge)
                .foregroundColor(KairosAuth.Color.primaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: KairosAuth.IconSize.itemIcon))
                    .foregroundColor(KairosAuth.Color.tertiaryText)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("Dismiss hint")
            .accessibilityHint("Hides this dashboard tip")
        }
        .padding(KairosAuth.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                .fill(KairosAuth.Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: accentColor.opacity(0.1), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
    }
}

/// Hint preference keys for UserDefaults
enum DashboardHintKey: String {
    case activePlansExplainer = "hint_active_proposals_shown"
    case upcomingEventsExplainer = "hint_upcoming_events_shown"
    case scheduleTutorialShown = "hint_schedule_tutorial_shown"

    var userDefaultsKey: String { rawValue }
}

/// Hint helper for managing show/hide state
struct DashboardHintHelper {
    /// Check if hint should be shown
    static func shouldShow(_ key: DashboardHintKey) -> Bool {
        !UserDefaults.standard.bool(forKey: key.userDefaultsKey)
    }

    /// Mark hint as dismissed
    static func markAsDismissed(_ key: DashboardHintKey) {
        UserDefaults.standard.set(true, forKey: key.userDefaultsKey)
    }

    /// Reset all hints (for testing)
    static func resetAllHints() {
        UserDefaults.standard.removeObject(forKey: DashboardHintKey.activePlansExplainer.userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: DashboardHintKey.upcomingEventsExplainer.userDefaultsKey)
    }
}

// MARK: - Preview

#if DEBUG
struct DashboardHintPreview: View {
    @State private var showHint = true

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                if showHint {
                    DashboardHint(
                        icon: "info.circle.fill",
                        message: "Invitations are live coordination—suggest times and confirm together.",
                        accentColor: KairosAuth.Color.accent,
                        onDismiss: { showHint = false }
                    )
                    .padding(.horizontal)
                }

                DashboardHint(
                    icon: "calendar.badge.checkmark",
                    message: "Events are confirmed and scheduled—ready to happen!",
                    accentColor: KairosAuth.Color.teal,
                    onDismiss: {}
                )
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 60)
        }
        .background(
            KairosAuth.Color.backgroundGradient(),
            ignoresSafeAreaEdges: .all
        )
    }
}

#Preview {
    DashboardHintPreview()
}
#endif
