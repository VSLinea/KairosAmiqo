//  OnboardingView.swift
//  KairosAmiqo
//
//  Single-page onboarding with Sign In/Sign Up/Demo options

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var vm: AppVM
    @State private var showSessionWarning = false

    var body: some View {
        ZStack {
            // Main onboarding content
            onboardingContent

            // Full-screen loading overlay when connecting with Apple
            if vm.isConnectingWithApple {
                ConnectingView(provider: .apple, onCancel: nil)
                    .transition(.opacity)
            }
        }
        .alert("Apple Sign-In Error", isPresented: .constant(vm.appleSignInError != nil)) {
            Button("OK") {
                vm.appleSignInError = nil
            }
        } message: {
            if let error = vm.appleSignInError {
                Text(error)
            }
        }
        .alert("Session Warning", isPresented: $showSessionWarning) {
            Button("OK") { }
        } message: {
            Text("You are continuing without an account. Nothing will be saved after you close the app.")
        }
    }

    // MARK: - Onboarding Content

    private var onboardingContent: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()

                // Branding section using KairosAuth component
                KairosAuth.BrandingSection(subtitle: "Your AI buddy for effortless invites")

                Spacer()

                // Button card using KairosAuth components
                KairosAuth.Card {
                    KairosAuth.SecondaryButton(
                        icon: "applelogo",
                        label: "Sign in with Apple"
                    ) {
                        Task {
                            await vm.signInWithApple()
                        }
                    }

                    KairosAuth.SecondaryButton(
                        icon: "globe",
                        label: "Sign in with Google"
                    ) {
                        // TODO(Phase 4): Implement Google Sign-In
                        // See /docs/google-signin-setup.md for configuration
                        // See /docs/CRITICAL-AUTH-ARCHITECTURE-QA.md for backend integration
                        vm.showLoginSheet = true
                    }

                    KairosAuth.SecondaryButton(
                        icon: "envelope.fill",
                        label: "Sign in with Email"
                    ) {
                        vm.showLoginSheet = true
                    }

                    KairosAuth.SecondaryButton(
                        icon: nil,
                        label: "Continue without account",
                        action: {
                            vm.completeOnboarding()
                            showSessionWarning = true
                        },
                        outlined: true
                    )
                }
                .padding(.bottom, 32)

                // Privacy motto - consistent with splash screen
                Text("Private conversations with your AI invite partner")
                    .font(KairosAuth.Typography.legalText)
                    .foregroundColor(KairosAuth.Color.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
        }
        .background(
            KairosAuth.Color.backgroundGradient(),
            ignoresSafeAreaEdges: .all
        )
    }
}

// ...existing code...

// ...existing code...

// ...existing code...
// NOTE: ParallaxStack moved to KairosAuth.swift (centralized design system)
// Use KairosAuth.ParallaxStack instead

// Liquid Glass Button component
struct LiquidGlassButton: View {
    let icon: String?
    let label: String
    let action: () -> Void
    var outlined: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                if let icon {
                    Image(systemName: icon)
                        .font(KairosAuth.Typography.buttonIcon)
                        .foregroundColor(KairosAuth.Color.secondaryText)
                        .accessibilityHidden(true)
                }
                Text(label)
                    .font(KairosAuth.Typography.buttonLabel)
                    .foregroundColor(KairosAuth.Color.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if outlined {
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                            .stroke(KairosAuth.Color.fieldBorder, lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                    .fill(KairosAuth.Color.cardBackground)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                            .fill(KairosAuth.Color.fieldBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                                    .stroke(KairosAuth.Color.fieldBorder, lineWidth: 1)
                            )
                    }
                }
            )
        }
        .padding(.horizontal, 0)
    }
}

// VisualEffectBlur helper for glassmorphism
import UIKit
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

#Preview {
    OnboardingView(vm: AppVM())
}
