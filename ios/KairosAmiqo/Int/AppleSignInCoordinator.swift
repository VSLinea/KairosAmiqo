//
//  AppleSignInCoordinator.swift
//  KairosAmiqo
//
//  Coordinator for handling Apple Sign-In authorization flow
//  Bridges ASAuthorizationController delegate methods with async/await

import AuthenticationServices
import UIKit

/// Coordinator that handles Apple Sign-In authorization flow
/// Conforms to ASAuthorizationControllerDelegate and ASAuthorizationControllerPresentationContextProviding
class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    var continuation: CheckedContinuation<ASAuthorization, Error>?

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Return the key window for presenting the Apple Sign-In sheet
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            // Fallback to first window
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? UIWindow()
        }
        return window
    }
}
