import Foundation
import CryptoKit

/// Privacy-preserving hashing utilities for analytics
struct HashingService {
    
    /// Hash user ID with SHA256 (privacy-preserving, no PII)
    /// - Parameter userID: User ID string (UUID format)
    /// - Returns: 64-character hex string (SHA256 hash)
    static func hashUserID(_ userID: String) -> String {
        let data = Data(userID.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Generate session ID (UUID v4, client-side)
    /// - Returns: UUID string for session tracking
    static func generateSessionID() -> String {
        UUID().uuidString
    }
    
    /// Verify hash format (64 hex characters)
    /// - Parameter hash: Hash string to validate
    /// - Returns: True if valid SHA256 format
    static func isValidHash(_ hash: String) -> Bool {
        guard hash.count == 64 else { return false }
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdef")
        return hash.lowercased().unicodeScalars.allSatisfy { hexCharacters.contains($0) }
    }
}

// MARK: - Testing Helpers

#if DEBUG
extension HashingService {
    /// Test data for unit tests
    static let testUserID = "550e8400-e29b-41d4-a716-446655440000"
    static let testHash = "c3ab8ff13720e8ad9047dd39466b3c8974e592c2fa383d4a3960714caef0c4f2"
    
    /// Verify hashing is deterministic
    static func testDeterminism() -> Bool {
        let hash1 = hashUserID(testUserID)
        let hash2 = hashUserID(testUserID)
        return hash1 == hash2 && isValidHash(hash1)
    }
}
#endif
