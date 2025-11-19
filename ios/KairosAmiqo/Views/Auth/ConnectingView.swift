//
//  ConnectingView.swift
//  KairosAmiqo
//
//  Reusable loading screen for authentication flows
//  Uses KairosAuth design system

import SwiftUI

struct ConnectingView: View {
    let provider: AuthProvider
    let onCancel: (() -> Void)?

    enum AuthProvider {
        case apple
        case google
        case email

        var displayName: String {
            switch self {
            case .apple: return "Apple"
            case .google: return "Google"
            case .email: return "Email"
            }
        }

        var icon: String {
            switch self {
            case .apple: return "applelogo"
            case .google: return "globe"
            case .email: return "envelope.fill"
            }
        }
    }

    init(provider: AuthProvider, onCancel: (() -> Void)? = nil) {
        self.provider = provider
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(KairosAuth.Color.overlay, ignoresSafeAreaEdges: .all)

            VStack(spacing: 0) {
                Spacer()

                // Main card
                VStack(spacing: KairosAuth.Spacing.extraLarge) {
                    // App icon with animated glow
                    ZStack {
                        // Glow rings
                        Circle()
                            .fill(KairosAuth.Color.accent.opacity(0.3))
                            .frame(width: 140, height: 140)
                            .blur(radius: 20)
                            .scaleEffect(pulseScale)
                            .animation(
                                KairosAuth.Animation.pulse,
                                value: pulseScale
                            )

                        // App icon
                        Image("AmiqoAppIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: KairosAuth.IconSize.successIcon, height: KairosAuth.IconSize.successIcon)
                            .shadow(
                                color: KairosAuth.Color.accent.opacity(0.6),
                                radius: 30
                            )
                            .accessibilityHidden(true)
                    }
                    .padding(.top, 8)

                    // Provider icon with glow
                    ZStack {
                        Circle()
                            .fill(KairosAuth.Color.accent.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .blur(radius: 15)

                        Image(systemName: provider.icon)
                            .font(.system(size: KairosAuth.IconSize.cardIcon))
                            .foregroundColor(KairosAuth.Color.white)
                            .frame(width: KairosAuth.IconSize.providerIcon, height: KairosAuth.IconSize.providerIcon)
                            .background(
                                Circle()
                                    .fill(KairosAuth.Color.fieldBackground)
                            )
                            .overlay(
                                Circle()
                                    .stroke(KairosAuth.Color.fieldBorder, lineWidth: 1)
                            )
                            .accessibilityLabel(Text("\(provider.displayName) sign-in icon"))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Connecting with \(provider.displayName)")

                    // Loading message
                    VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                        Text("Connecting with \(provider.displayName)...")
                            .font(KairosAuth.Typography.screenTitle)
                            .foregroundColor(KairosAuth.Color.white)
                            .multilineTextAlignment(.center)

                        Text("This may take a few moments")
                            .font(KairosAuth.Typography.bodySmall)
                            .foregroundColor(KairosAuth.Color.secondaryText)
                            .multilineTextAlignment(.center)

                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: KairosAuth.Color.white))
                            .scaleEffect(1.2)
                            .padding(.top, 4)
                            .accessibilityLabel("Connection in progress")
                            .accessibilityHint("Please wait until authentication completes")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(connectingAccessibilitySummary)

                    // Optional cancel button
                    if let onCancel {
                        Button {
                            onCancel()
                        } label: {
                            Text("Cancel")
                                .font(KairosAuth.Typography.buttonLabel)
                                .foregroundColor(KairosAuth.Color.tertiaryText)
                                .padding(.vertical, 12)
                        }
                        .accessibilityHint("Stops signing in with \(provider.displayName)")
                    }
                }
                .padding(KairosAuth.Spacing.cardPadding)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                        .fill(KairosAuth.Color.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                                .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.card, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),  // Enhanced top rim (Level 3 modal)
                                    Color.white.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(
                    color: KairosAuth.Shadow.cardColor.opacity(0.3),
                    radius: 20,
                    y: 10
                )
                .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)

                Spacer()
            }
        }
        .background(
            KairosAuth.Color.backgroundGradient(),
            ignoresSafeAreaEdges: .all
        )
        .onAppear {
            startPulseAnimation()
        }
    }

    // MARK: - Animation State

    @State private var pulseScale: CGFloat = 1.0

    private func startPulseAnimation() {
        pulseScale = 1.2
    }

    private var connectingAccessibilitySummary: String {
        "Connecting with \(provider.displayName). This may take a few moments."
    }
}

// MARK: - Preview

#if DEBUG
struct ConnectingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConnectingView(provider: .apple) {
                print("Canceled")
            }
            .previewDisplayName("Apple - With Cancel")

            ConnectingView(provider: .google)
                .previewDisplayName("Google - No Cancel")

            ConnectingView(provider: .email, onCancel: nil)
                .previewDisplayName("Email")
        }
    }
}
#endif
