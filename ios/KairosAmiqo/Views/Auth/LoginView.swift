//
//  LoginView.swift
//  KairosAmiqo
//
//  Full-screen login matching Android's "Welcome Back" design

import SwiftUI

struct LoginView: View {
    @ObservedObject var vm: AppVM
    @Environment(\.dismiss) private var dismiss

    @State private var email: String
    @State private var password: String
    @State private var showingForgotPassword = false
    @State private var errorMessage: String?

    init(vm: AppVM) {
        self.vm = vm
        _email = State(initialValue: vm.defaultEmail)
        _password = State(initialValue: vm.defaultPassword)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 32)
                // Branding
                VStack(spacing: KairosAuth.Spacing.large) {
                    Image("AmiqoAppIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: KairosAuth.IconSize.brandingIcon, height: KairosAuth.IconSize.brandingIcon)
                        .scaledToFit()
                        .shadow(color: KairosAuth.Color.shadowMedium, radius: 12, y: 4)
                        .accessibilityHidden(true)
                    Text("Kairos")
                        .font(KairosAuth.Typography.brandName)
                        .foregroundColor(KairosAuth.Color.brandTextColor)
                        .shadow(color: KairosAuth.Color.brandTextShadow, radius: 8, x: 0, y: 2)
                    Text("Amiqo")
                        .font(KairosAuth.Typography.appName)
                        .foregroundColor(KairosAuth.Color.brandTextColor)
                        .padding(.top, -6)
                        .shadow(color: KairosAuth.Color.brandTextShadow, radius: 8, x: 0, y: 2)
                    Text("Sign in with Email")
                        .font(KairosAuth.Typography.cardTitle)
                        .foregroundColor(KairosAuth.Color.primaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.bottom, 24)

                Spacer().frame(height: 12)

                // Login card (less blur, solid background, rounded corners)
                VStack(spacing: KairosAuth.Spacing.large) {
                    // Close button at top of card
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(KairosAuth.Typography.buttonIcon)
                                .foregroundColor(KairosAuth.Color.tertiaryText)
                        }
                        .accessibilityLabel("Close login")
                        .accessibilityHint("Returns to the previous screen")
                    }
                    .padding(.top, -8)
                    .padding(.trailing, -8)

                    emailField()
                    passwordField()
                    if let error = errorMessage {
                        Text(error)
                            .font(KairosAuth.Typography.body)
                            .foregroundColor(KairosAuth.Color.error)
                            .padding(.top, 4)
                    }
                    signInButton()

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(KairosAuth.Color.fieldBorder)
                            .frame(height: 1)
                        Text("or")
                            .font(KairosAuth.Typography.bodySmall)
                            .foregroundColor(KairosAuth.Color.tertiaryText)
                            .padding(.horizontal, 12)
                        Rectangle()
                            .fill(KairosAuth.Color.fieldBorder)
                            .frame(height: 1)
                    }
                    .padding(.top, 8)

                    // Sign up link - more prominent
                    Button {
                        // Dismiss login and navigate back to onboarding
                        dismiss()
                        vm.launchPhase = .onboarding
                    } label: {
                        VStack(spacing: KairosAuth.Spacing.xs) {
                            Text("Don't have an account?")
                                .font(KairosAuth.Typography.itemSubtitle)
                                .foregroundColor(KairosAuth.Color.secondaryText)
                            Text("Sign up")
                                .font(KairosAuth.Typography.buttonLabel)
                                .foregroundColor(KairosAuth.Color.accent)
                        }
                    }
                    .accessibilityHint("Opens onboarding to create a new account")
                    .padding(.top, 4)
                    
                    #if DEBUG
                    // Development bypass - skip auth and go to dashboard
                    Button {
                        vm.jwt = "dev-bypass-token" // Fake token for dev
                        vm.items = [] // Clear items to prevent loading
                        vm.itemsState = .empty // Set empty state
                        vm.events = [] // Clear events
                        vm.eventsState = .empty
                        vm.completeOnboarding()
                        print("✅ [DEBUG] Auth bypassed - going to dashboard with empty state")
                    } label: {
                        Text("⚡️ Skip Auth (Debug)")
                            .font(KairosAuth.Typography.itemSubtitle)
                            .foregroundColor(KairosAuth.Color.warning)
                    }
                    .accessibilityLabel("Skip authentication debug option")
                    .accessibilityHint("Immediately opens the dashboard with mock data")
                    .padding(.top, 8)
                    #endif
                }
                .padding(KairosAuth.Spacing.cardPadding)
                .background(
                    KairosAuth.Color.cardBackground
                        .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.modal, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.modal, style: .continuous)
                        .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.modal, style: .continuous)
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
                    color: KairosAuth.Shadow.cardColor,
                    radius: KairosAuth.Shadow.cardRadius,
                    y: KairosAuth.Shadow.cardY
                )
                .padding(.horizontal, 28)
                .padding(.bottom, 32)

                Spacer()
            }
        }
        .background(
            KairosAuth.Color.backgroundGradient(),
            ignoresSafeAreaEdges: .all
        )
        .alert("Forgot Password", isPresented: $showingForgotPassword) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Password reset functionality coming soon. Please contact support.")
        }
    }

    // MARK: - Helper Views

    private func emailField() -> some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
            Text("Email")
                .font(KairosAuth.Typography.fieldLabel)
                .foregroundColor(KairosAuth.Color.secondaryText)
            TextField("", text: $email)
                .padding()
                .background(KairosAuth.Color.fieldBackground
                    .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)))
                .overlay(RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                    .stroke(KairosAuth.Color.fieldBorder, lineWidth: 1))
                .foregroundColor(KairosAuth.Color.fieldTextColor)
                .font(KairosAuth.Typography.fieldInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
        }
    }

    private func passwordField() -> some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
            Text("Password")
                .font(KairosAuth.Typography.fieldLabel)
                .foregroundColor(KairosAuth.Color.secondaryText)
            SecureField("", text: $password)
                .padding()
                .background(KairosAuth.Color.fieldBackground
                    .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)))
                .overlay(RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                    .stroke(KairosAuth.Color.fieldBorder, lineWidth: 1))
                .foregroundColor(KairosAuth.Color.fieldTextColor)
                .font(KairosAuth.Typography.fieldInput)
        }
    }

    private func signInButton() -> some View {
        Button {
            Task {
                vm.busy = true
                errorMessage = nil
                await performLogin()
                vm.busy = false
                // If login succeeded (jwt is set), dismiss
                if vm.jwt != nil {
                    dismiss()
                }
            }
        } label: {
            Text(vm.busy ? "Signing In..." : "Sign In")
                .font(KairosAuth.Typography.buttonLabelLarge)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: KairosAuth.Radius.button, style: .continuous)
                        .fill(KairosAuth.Color.accent)
                )
                .foregroundColor(KairosAuth.Color.buttonText)
        }
        .disabled(vm.busy)
    }

    // MARK: - Actions

    private func performLogin() async {
        errorMessage = nil
        await vm.login(email: email, password: password)

        // Check if login failed
        if vm.jwt == nil, !vm.busy {
            errorMessage = "Invalid email or password"
        }
    }
}

// Custom text field style with design system colors
struct KairosTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.small, style: .continuous)
                    .strokeBorder(KairosAuth.Color.cardBackground, lineWidth: 1)
            )
            .foregroundColor(KairosAuth.Color.primaryText)
            .tint(KairosAuth.Color.accent)
    }
}

#Preview {
    NavigationStack {
        LoginView(vm: AppVM())
    }
}
