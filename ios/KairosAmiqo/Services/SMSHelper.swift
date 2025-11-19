import SwiftUI
import MessageUI

/// Helper for sending SMS invites to participants without the Kairos app.
/// Uses native iOS MFMessageComposeViewController for SMS with pre-filled content.
/// See /docs/00-CANONICAL/ios-amiqo.md §Invite Routing
struct SMSHelper {
    
    /// Check if device can send SMS
    static func canSendSMS() -> Bool {
        return MFMessageComposeViewController.canSendText()
    }
    
    /// Generate SMS invite message with plan details and web link
    /// - Parameters:
    ///   - planTitle: Title of the plan (e.g., "Coffee with Alex")
    ///   - inviterName: Name of person sending invite
    ///   - token: Unique token for web app link
    /// - Returns: Pre-filled message string
    static func generateInviteMessage(planTitle: String, inviterName: String, token: String) -> String {
        let webLink = "https://kairos.app/p/\(token)"
        
        return """
        \(inviterName) invited you to: \(planTitle)
        
        Respond here: \(webLink)
        
        Or download Kairos to join: https://kairos.app/download
        """
    }
    
    /// Generate unique token for web app link (mock implementation)
    /// Phase 4: Backend will generate real tokens from /items/invite_tokens
    static func generateToken(for negotiationId: UUID) -> String {
        // Mock: Use shortened UUID
        return negotiationId.uuidString.prefix(8).lowercased()
    }
}

/// SwiftUI wrapper for MFMessageComposeViewController
struct SMSComposeView: UIViewControllerRepresentable {
    let recipients: [String] // Phone numbers
    let body: String // Pre-filled message
    var onFinish: ((MessageComposeResult) -> Void)? = nil
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {
        // No updates needed
    }
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var parent: SMSComposeView
        
        init(_ parent: SMSComposeView) {
            self.parent = parent
        }
        
        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            parent.onFinish?(result)
            controller.dismiss(animated: true)
        }
    }
}
