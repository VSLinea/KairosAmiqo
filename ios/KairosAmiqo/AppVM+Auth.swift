import Foundation
import SwiftUI
import AuthenticationServices

// MARK: - Authentication Extension

extension AppVM {
    
    // MARK: - Email/Password Auth
    
    func login(email: String, password: String) async {
        print("🔐 [AUTH] Starting login for: \(email)")
        error = nil; busy = true
        defer { busy = false }
        do {
            var req = URLRequest(url: url("/auth/login", jsonMode: true))
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            struct Body: Codable { let email: String; let password: String }
            req.httpBody = try JSONEncoder().encode(Body(email: email, password: password))
            
            print("🔐 [AUTH] Sending auth request to: \(req.url?.absoluteString ?? "unknown")")
            let (data, resp) = try await URLSession.shared.data(for: req)
            print("🔐 [AUTH] Got response, status: \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
            
            guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? -1
                print("❌ [AUTH] Login failed with status \(statusCode): \(body)")
                throw NSError(
                    domain: "Auth",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Login failed \(body)"]
                )
            }
            
            print("🔐 [AUTH] Decoding JWT response...")
            let env = try JSONDecoder().decode(LoginEnvelope.self, from: data)
            jwt = env.data.access_token
            KeychainHelper.saveJWT(env.data.access_token)
            if let rt = env.data.refresh_token { KeychainHelper.saveRefresh(rt) }
            error = nil
            
            print("🔐 [AUTH] Login successful! Now fetching plans...")
            try await fetchNegotiations()
            
            print("🔐 [AUTH] Plans fetched, completing onboarding...")
            // Mark onboarding complete and transition to dashboard
            await MainActor.run {
                self.completeOnboarding()
            }
            print("✅ [AUTH] Login complete!")
        } catch { 
            print("❌ [AUTH] Login error: \(error.localizedDescription)")
            self.error = error.localizedDescription 
        }
    }
    
    // MARK: - Sign in with Apple
    
    /// Initiates Sign in with Apple flow
    /// Apple will present their native modal with Face ID/Touch ID/Passcode authentication
    func signInWithApple() async {
        await MainActor.run {
            self.isConnectingWithApple = true
            self.appleSignInError = nil
        }

        defer {
            Task { @MainActor in
                self.isConnectingWithApple = false
            }
        }

        do {
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            // Perform the authorization request
            // This will trigger Apple's native modal UI
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let coordinator = AppleSignInCoordinator()
            controller.delegate = coordinator
            controller.presentationContextProvider = coordinator

            // Wait for authorization to complete
            let authorization = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
                coordinator.continuation = continuation
                controller.performRequests()
            }

            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid Apple ID credential"])
            }

            // Extract user info
            let userIdentifier = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email
            let identityToken = appleIDCredential.identityToken

            guard let tokenData = identityToken,
                  let tokenString = String(data: tokenData, encoding: .utf8) else {
                throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Failed to get identity token"])
            }

            // TODO: Send token to backend for verification
            // For now, we'll treat this as successful authentication
            print("✅ Apple Sign-In successful")
            print("User ID: \(userIdentifier)")
            if let email = email { print("Email: \(email)") }
            if let fullName = fullName {
                print("Name: \(fullName.givenName ?? "") \(fullName.familyName ?? "")")
            }
            print("Token: \(tokenString.prefix(50))...")

            // Store Apple user identifier in Keychain for future sessions
            KeychainHelper.saveAppleUserID(userIdentifier)

            // TODO(Kairos): Integrate with backend Apple auth endpoint
            // See /docs/backend-apis.md for POST /auth/apple
            // For now, complete onboarding to unblock UI flow
            await MainActor.run {
                self.completeOnboarding()
            }

        } catch let error as ASAuthorizationError {
            await MainActor.run {
                // Handle user cancellation separately (not an error)
                if error.code == .canceled {
                    self.appleSignInError = nil
                    return
                }

                // Map all error codes to user-friendly messages
                let message: String
                switch error.code {
                case .failed:
                    message = "Sign in with Apple failed. Please try again."
                case .invalidResponse:
                    message = "Invalid response from Apple. Please try again."
                case .notHandled:
                    message = "Unable to handle request. Please try again."
                case .notInteractive:
                    message = "Sign in not available. Please try again later."
                case .matchedExcludedCredential:
                    message = "This credential is not available. Please try another method."
                case .credentialImport:
                    message = "Unable to import credential. Please try again."
                case .credentialExport:
                    message = "Unable to export credential. Please try again."
                case .unknown, .canceled:
                    message = "An error occurred. Please try again."
                @unknown default:
                    message = "Sign in with Apple failed. Please try again."
                }
                self.appleSignInError = message
            }
        } catch {
            await MainActor.run {
                self.appleSignInError = "Sign in with Apple failed: \(error.localizedDescription)"
            }
        }
    }

    /// Check if user previously signed in with Apple
    func checkAppleSignInStatus() async {
        guard let userID = KeychainHelper.loadAppleUserID() else { return }

        let provider = ASAuthorizationAppleIDProvider()
        do {
            let credentialState = try await provider.credentialState(forUserID: userID)
            switch credentialState {
            case .authorized:
                print("✅ Apple Sign-In still valid")
                // User is still authorized, auto-sign in
                await MainActor.run {
                    self.completeOnboarding()
                }
            case .revoked:
                print("⚠️ Apple Sign-In revoked")
                KeychainHelper.deleteAppleUserID()
            case .notFound:
                print("⚠️ Apple Sign-In credential not found")
                KeychainHelper.deleteAppleUserID()
            case .transferred:
                print("ℹ️ Apple Sign-In transferred to another device")
            @unknown default:
                print("⚠️ Unknown Apple Sign-In credential state")
            }
        } catch {
            print("❌ Error checking Apple Sign-In status: \(error)")
        }
    }
    
    // MARK: - Token Management
    
    func refreshToken() async throws {
        guard let rt = KeychainHelper.loadRefresh() else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No refresh token"])
        }
        var req = URLRequest(url: url("/auth/refresh", jsonMode: true))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        struct Body: Codable { let refresh_token: String }
        req.httpBody = try JSONEncoder().encode(Body(refresh_token: rt))
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(
                domain: "Auth",
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Refresh failed \(body)"]
            )
        }
        let env = try JSONDecoder().decode(LoginEnvelope.self, from: data)
        jwt = env.data.access_token
        KeychainHelper.saveJWT(env.data.access_token)
        if let newRT = env.data.refresh_token { KeychainHelper.saveRefresh(newRT) }
        error = nil
    }
    
    // MARK: - Session Management
    
    func signOut() {
        clearAllState()
        // Return to onboarding flow after sign out
        launchPhase = .onboarding
    }

    @MainActor
    func clearAllState() {
        KeychainHelper.deleteAll()
        jwt = nil
        items = []
        lastCreated = nil
        error = nil
        events = []
        errorMessage = nil
        eventsState = .idle
        itemsState = .idle
    }

    func bootstrapSession() async {
        // Ensure splash screen shows for minimum duration for branding visibility
        let splashStartTime = Date()

        let savedJWT = KeychainHelper.loadJWT()
        let savedRefresh = KeychainHelper.loadRefresh()
        
        print("🚀 [DEBUG] bootstrapSession: JWT exists: \(savedJWT != nil), Refresh exists: \(savedRefresh != nil)")
        
        // Phase 3: ALWAYS load current user (even without JWT for mock testing)
        await loadCurrentUser()

        if let token = savedJWT, savedRefresh != nil {
            print("🔐 [DEBUG] Using authenticated path")
            await MainActor.run { self.jwt = token }
            
            do {
                // Sync pending plans first (offline → online)
                await syncPendingPlans()
                
                // Then fetch from server
                try await fetchNegotiations()
                
                // Fetch events (Task 23-25 dashboard events cards)
                await fetchEvents()
            } catch {
                let message = mapError(error)
                await MainActor.run { self.error = message }
                print("❌ [DEBUG] Authenticated fetch error: \(message)")
            }
        } else {
            print("🔓 [DEBUG] Using mock/unauthenticated path")
            await MainActor.run { self.clearAllState() }
            
            // Phase 0-3: Fetch plans even without auth (mock server doesn't require JWT)
            do {
                try await fetchNegotiations()
                
                // Fetch events (Task 23-25 dashboard events cards)
                await fetchEvents()
            } catch {
                let message = mapError(error)
                await MainActor.run { self.error = message }
                print("❌ [DEBUG] Mock fetch error: \(message)")
            }
        }

        // Ensure minimum 3 seconds for splash branding visibility
        let elapsedTime = Date().timeIntervalSince(splashStartTime)
        let minimumSplashDuration: TimeInterval = 3.0
        if elapsedTime < minimumSplashDuration {
            try? await Task.sleep(nanoseconds: UInt64((minimumSplashDuration - elapsedTime) * 1_000_000_000))
        }

        // Check if user has completed onboarding
        await MainActor.run {
            let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            self.hasCompletedOnboarding = completed

            if completed {
                // Show main tabs after splash (signed in or out)
                self.markLaunchReady()
            } else {
                // First time user - show onboarding
                self.launchPhase = .onboarding
            }
        }
    }
}
