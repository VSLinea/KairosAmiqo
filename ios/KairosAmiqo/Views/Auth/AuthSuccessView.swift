//
//  AuthSuccessView.swift
//  KairosAmiqo
//
//  Success screen shown after successful authentication
//  Uses KairosAuth design system

import SwiftUI

struct AuthSuccessView: View {
    let userName: String?
    let provider: AuthProvider
    let onContinue: () -> Void

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

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()

                // Success card
                VStack(spacing: KairosAuth.Spacing.extraLarge) {
                    // Success icon with animation
                    ZStack {
                        // Success glow
                        Circle()
                            .fill(KairosAuth.Color.errorBackground)
                            .frame(width: 140, height: 140)
                            .blur(radius: 20)
                            .scaleEffect(successScale)

                        // Checkmark
                        ZStack {
                            Circle()
                                .fill(KairosAuth.Color.success)
                                .frame(width: KairosAuth.IconSize.successIcon, height: KairosAuth.IconSize.successIcon)

                            Image(systemName: "checkmark")
                                .font(.system(size: KairosAuth.IconSize.heroIcon))
                                .foregroundColor(KairosAuth.Color.white)
                        }
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                    }
                    .padding(.top, 8)
                    .accessibilityHidden(true)

                    // Success message
                    VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                        Text("Welcome\(userName.map { ", \($0)" } ?? "")!")
                            .font(KairosAuth.Typography.appName.weight(.semibold))
                            .foregroundColor(KairosAuth.Color.white)
                            .multilineTextAlignment(.center)

                        Text("Signed in with \(provider.displayName)")
                            .font(KairosAuth.Typography.body)
                            .foregroundColor(KairosAuth.Color.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(successAccessibilitySummary)

                    // Continue button
                    KairosAuth.PrimaryButton(label: "Continue to Dashboard") {
                        onContinue()
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
            animateSuccess()
        }
    }

    // MARK: - Animation State

    @State private var successScale: CGFloat = 0.8
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var checkmarkOpacity: Double = 0.0

    private func animateSuccess() {
        // Animate glow
        withAnimation(KairosAuth.Animation.successBounce) {
            successScale = 1.2
        }

        // Animate checkmark with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(KairosAuth.Animation.successBounce) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }
        }
    }

    private var successAccessibilitySummary: String {
        let greeting = userName.map { "Welcome, \($0)!" } ?? "Welcome!"
        return "\(greeting) Signed in with \(provider.displayName)."
    }
}

// MARK: - Preview

#if DEBUG
struct AuthSuccessView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AuthSuccessView(
                userName: "John",
                provider: .apple
            ) {
                print("Continue tapped")
            }
            .previewDisplayName("With Name")

            AuthSuccessView(
                userName: nil,
                provider: .google
            ) {
                print("Continue tapped")
            }
            .previewDisplayName("Without Name")
        }
    }
}
#endif
