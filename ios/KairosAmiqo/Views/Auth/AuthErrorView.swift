//
//  AuthErrorView.swift
//  KairosAmiqo
//
//  Error screen shown when authentication fails
//  Uses KairosAuth design system

import SwiftUI

struct AuthErrorView: View {
    let provider: AuthProvider
    let errorMessage: String
    let onRetry: () -> Void
    let onCancel: () -> Void

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

                // Error card
                VStack(spacing: KairosAuth.Spacing.extraLarge) {
                    // Error icon with animation
                    ZStack {
                        // Error glow
                        Circle()
                            .fill(KairosAuth.Color.errorBackground)
                            .frame(width: 140, height: 140)
                            .blur(radius: 20)
                            .scaleEffect(errorScale)

                        // Exclamation mark
                        ZStack {
                            Circle()
                                .fill(KairosAuth.Color.error)
                                .frame(width: KairosAuth.IconSize.errorIcon, height: KairosAuth.IconSize.errorIcon)

                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: KairosAuth.IconSize.heroIcon))
                                .foregroundColor(KairosAuth.Color.white)
                        }
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)
                    }
                    .padding(.top, 8)
                    .accessibilityHidden(true)

                    // Error message
                    VStack(spacing: KairosAuth.Spacing.rowSpacing) {
                        Text("Sign in Failed")
                            .font(KairosAuth.Typography.screenTitle)
                            .foregroundColor(KairosAuth.Color.white)
                            .multilineTextAlignment(.center)

                        Text(errorMessage)
                            .font(KairosAuth.Typography.body)
                            .foregroundColor(KairosAuth.Color.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Provider: \(provider.displayName)")
                            .font(KairosAuth.Typography.bodySmall)
                            .foregroundColor(KairosAuth.Color.tertiaryText)
                            .multilineTextAlignment(.center)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(errorAccessibilitySummary)

                    // Action buttons
                    VStack(spacing: KairosAuth.Spacing.medium) {
                        KairosAuth.PrimaryButton(label: "Try Again") {
                            onRetry()
                        }

                        Button {
                            onCancel()
                        } label: {
                            Text("Back to Sign In")
                                .font(KairosAuth.Typography.buttonLabel)
                                .foregroundColor(KairosAuth.Color.tertiaryText)
                                .padding(.vertical, 8)
                        }
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
            animateError()
        }
    }

    // MARK: - Animation State

    @State private var errorScale: CGFloat = 0.8
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0.0

    private func animateError() {
        // Animate glow
        withAnimation(KairosAuth.Animation.successBounce) {
            errorScale = 1.2
        }

        // Animate icon with shake effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(KairosAuth.Animation.errorShake) {
                iconScale = 1.0
                iconOpacity = 1.0
            }

            // Shake animation
            withAnimation(.default.repeatCount(3)) {
                iconScale = 1.05
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    iconScale = 1.0
                }
            }
        }
    }

    private var errorAccessibilitySummary: String {
        "Sign in failed. \(errorMessage). Provider: \(provider.displayName)."
    }
}

// MARK: - Preview

#if DEBUG
struct AuthErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AuthErrorView(
                provider: .apple,
                errorMessage: "Sign in with Apple failed. Please try again."
            ) {
                print("Retry tapped")
            } onCancel: {
                print("Cancel tapped")
            }
            .previewDisplayName("Apple Error")

            AuthErrorView(
                provider: .google,
                errorMessage: "Unable to connect to Google. Please check your internet connection."
            ) {
                print("Retry tapped")
            } onCancel: {
                print("Cancel tapped")
            }
            .previewDisplayName("Google Error - Long Message")

            AuthErrorView(
                provider: .email,
                errorMessage: "Invalid email or password."
            ) {
                print("Retry tapped")
            } onCancel: {
                print("Cancel tapped")
            }
            .previewDisplayName("Email Error")
        }
    }
}
#endif
