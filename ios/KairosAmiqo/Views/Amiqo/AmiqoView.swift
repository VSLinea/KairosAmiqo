import SwiftUI

/// Placeholder Amiqo assistant surface until full conversational UI lands.
/// Mirrors UX specification section §4 so engineering can stage implementation incrementally.
struct AmiqoView: View {
    @ObservedObject var vm: AppVM

    // Modal state tracking
    @State private var isAnyModalPresented = false

    private struct Message: Identifiable {
        let id = UUID()
        let isAmiqo: Bool
        let title: String
        let body: String
        let timestamp: String
    }

    private let sampleMessages: [Message] = [
    Message(isAmiqo: true, title: "Welcome back!", body: "Want me to suggest a quick coffee with Alice this weekend?", timestamp: "2 min ago"),
    Message(isAmiqo: false, title: "Let's coordinate dinner", body: "Find a dinner slot on Friday with the usual crew.", timestamp: "2 min ago"),
    Message(isAmiqo: true, title: "Done!", body: "I drafted an invitation with three times and two venues. Review and send it when you're ready.", timestamp: "Just now")
    ]

    private let quickActions: [String] = [
        "Start an invitation",
        "Check conflicts",
        "Suggest venues",
        "Review notifications"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.large) {
                    header
                    quickActionsRow
                    conversationFeed
                    Spacer(minLength: KairosAuth.Spacing.extraLarge)
                    inputStub
                }
                .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
                .padding(.top, KairosAuth.Spacing.extraLarge)
                .padding(.bottom, KairosAuth.Spacing.tabBarHeight * 1.4)
                .blur(radius: isAnyModalPresented ? 8 : 0)
                .scaleEffect(isAnyModalPresented ? 0.95 : 1.0)
                .animation(KairosAuth.Animation.modalPresent, value: isAnyModalPresented)

                // Dark overlay when modal presented
                if isAnyModalPresented {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(KairosAuth.Color.scrim, ignoresSafeAreaEdges: .all)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(KairosAuth.Animation.modalDismiss) {
                                isAnyModalPresented = false
                            }
                        }
                }
            }
            .background(
                KairosAuth.Color.backgroundGradient(),
                ignoresSafeAreaEdges: .all
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Amiqo")
                        .font(KairosAuth.Typography.screenTitle)
                        .foregroundColor(KairosAuth.Color.primaryText)
                        .shadow(color: KairosAuth.Color.brandTextShadow, radius: 8, x: 0, y: 2)
                        .shadow(color: KairosAuth.Color.brandTextShadow.opacity(0.4), radius: 4, x: 0, y: 1)
                }
            }
        }
        .tint(KairosAuth.Color.white) // Apply tint to NavigationStack for all Back buttons
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
            HStack(spacing: KairosAuth.Spacing.small) {
                Image(systemName: "sparkles")
                    .font(.system(size: KairosAuth.IconSize.heroIcon))
                    .foregroundStyle(KairosAuth.Color.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                    Text("Amiqo Assistant")
                        .font(KairosAuth.Typography.screenTitle)
                        .foregroundStyle(KairosAuth.Color.primaryText)
                    Text("Ask Amiqo to coordinate invitations, check schedules, or adjust events.")
                        .font(KairosAuth.Typography.body)
                        .foregroundStyle(KairosAuth.Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var quickActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: KairosAuth.Spacing.small) {
                ForEach(quickActions, id: \.self) { action in
                    Text(action)
                        .font(KairosAuth.Typography.itemSubtitle)
                        .foregroundStyle(KairosAuth.Color.primaryText)
                        .padding(.vertical, KairosAuth.Spacing.small)
                        .padding(.horizontal, KairosAuth.Spacing.large)
                        .background(
                            Capsule()
                                .fill(KairosAuth.Color.cardBackground)
                                .overlay(
                                    Capsule()
                                        .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                                )
                        )
                }
            }
            .padding(.vertical, KairosAuth.Spacing.small)
        }
    }

    private var conversationFeed: some View {
        ScrollView {
            VStack(spacing: KairosAuth.Spacing.cardSpacing) {
                ForEach(sampleMessages) { message in
                    VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
                        HStack(alignment: .firstTextBaseline, spacing: KairosAuth.Spacing.xs) {
                            Label(message.isAmiqo ? "Amiqo" : "You", systemImage: message.isAmiqo ? "sparkles" : "person.fill")
                                .labelStyle(.titleAndIcon)
                                .font(KairosAuth.Typography.timestamp)
                                .foregroundStyle(message.isAmiqo ? KairosAuth.Color.accent : KairosAuth.Color.secondaryText)
                            Text(message.timestamp)
                                .font(KairosAuth.Typography.timestamp)
                                .foregroundStyle(KairosAuth.Color.tertiaryText)
                        }

                        Text(message.title)
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundStyle(KairosAuth.Color.primaryText)

                        Text(message.body)
                            .font(KairosAuth.Typography.body)
                            .foregroundStyle(KairosAuth.Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(KairosAuth.Spacing.cardContentPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                            .fill(KairosAuth.Color.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                                    .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.top, KairosAuth.Spacing.small)
            .padding(.bottom, KairosAuth.Spacing.extraLarge)
        }
    }

    private var inputStub: some View {
        HStack(spacing: KairosAuth.Spacing.small) {
            Image(systemName: "mic.fill")
                .font(.system(size: KairosAuth.IconSize.button, weight: .medium))
                .foregroundStyle(KairosAuth.Color.accent)
                .accessibilityHidden(true)
                .padding()
                .background(
                    Circle()
                        .fill(KairosAuth.Color.cardBackground)
                        .overlay(
                            Circle().stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                        )
                )

            Text("Tap the mic or start typing to talk to Amiqo...")
                .font(KairosAuth.Typography.body)
                .foregroundStyle(KairosAuth.Color.secondaryText)
                .padding(.vertical, KairosAuth.Spacing.medium)
                .padding(.horizontal, KairosAuth.Spacing.large)
                .background(
                    Capsule()
                        .fill(KairosAuth.Color.cardBackground)
                        .overlay(
                            Capsule().stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                        )
                )
        }
    }
}

#Preview {
    AmiqoView(vm: AppVM())
        .preferredColorScheme(.dark)
}
