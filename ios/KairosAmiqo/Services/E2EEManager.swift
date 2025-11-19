//
//  E2EEManager.swift
//  KairosAmiqo
//
//  Task 28: Agent-to-Agent Negotiation - E2EE Foundation
//  Week 1, Day 1: End-to-End Encryption with AES-256-GCM
//
//  Created: 2025-11-01
//  See: /AGENT-TO-AGENT-IMPLEMENTATION-PLAN.md
//
//  DEVELOPMENT MODE: Set DISABLE_E2EE=1 in Xcode scheme to skip encryption
//

import Foundation
import CryptoKit

/// End-to-End Encryption Manager using AES-256-GCM
/// Provides client-side encryption/decryption for agent preferences and messages
/// Server stores encrypted blobs, cannot read plaintext content
///
/// **Development Mode:**
/// Set `DISABLE_E2EE=1` environment variable to bypass encryption (plaintext mode)
/// Useful for testing without Keychain complexity
@MainActor
class E2EEManager {
    
    // MARK: - Error Types
    
    enum E2EEError: Error, LocalizedError {
        case encryptionFailed(String)
        case decryptionFailed(String)
        case invalidKey
        case invalidData
        case keyGenerationFailed
        
        var errorDescription: String? {
            switch self {
            case .encryptionFailed(let reason):
                return "Encryption failed: \(reason)"
            case .decryptionFailed(let reason):
                return "Decryption failed: \(reason)"
            case .invalidKey:
                return "Invalid encryption key"
            case .invalidData:
                return "Invalid encrypted data format"
            case .keyGenerationFailed:
                return "Failed to generate encryption key"
            }
        }
    }
    
    // MARK: - Encryption (with Dev Mode Bypass)
    
    /// Encrypt data using AES-256-GCM (or return plaintext in dev mode)
    /// - Parameters:
    ///   - data: Plaintext data to encrypt
    ///   - key: 256-bit symmetric key
    /// - Returns: Combined encrypted data (nonce + ciphertext + authentication tag)
    /// - Throws: E2EEError if encryption fails
    static func encrypt(_ data: Data, with key: SymmetricKey) throws -> Data {
        // DEV MODE: Skip encryption if disabled
        if !Config.enableE2EE {
            #if DEBUG
            print("⚠️ [E2EE] Encryption DISABLED - returning plaintext (DISABLE_E2EE=1)")
            #endif
            return data // Return plaintext
        }
        
        guard key.bitCount == 256 else {
            throw E2EEError.invalidKey
        }
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            
            // Return combined data: nonce (12 bytes) + ciphertext + tag (16 bytes)
            // This format is compatible with standard AES-GCM implementations
            guard let combined = sealedBox.combined else {
                throw E2EEError.encryptionFailed("Failed to create combined sealed box")
            }
            
            return combined
        } catch {
            throw E2EEError.encryptionFailed(error.localizedDescription)
        }
    }
    
    /// Encrypt Codable object to JSON and encrypt
    /// - Parameters:
    ///   - object: Codable object to encrypt
    ///   - key: 256-bit symmetric key
    /// - Returns: Encrypted data blob
    /// - Throws: E2EEError or encoding errors
    static func encryptObject<T: Codable>(_ object: T, with key: SymmetricKey) throws -> Data {
        let jsonData = try JSONEncoder().encode(object)
        return try encrypt(jsonData, with: key)
    }
    
    // MARK: - Decryption (with Dev Mode Bypass)
    
    /// Decrypt data using AES-256-GCM (or return plaintext in dev mode)
    /// - Parameters:
    ///   - encrypted: Combined encrypted data (nonce + ciphertext + tag)
    ///   - key: 256-bit symmetric key (must match encryption key)
    /// - Returns: Decrypted plaintext data
    /// - Throws: E2EEError if decryption fails (wrong key, tampered data, etc.)
    static func decrypt(_ encrypted: Data, with key: SymmetricKey) throws -> Data {
        // DEV MODE: Skip decryption if disabled
        if !Config.enableE2EE {
            #if DEBUG
            print("⚠️ [E2EE] Decryption DISABLED - returning plaintext (DISABLE_E2EE=1)")
            #endif
            return encrypted // Treat as plaintext
        }
        
        guard key.bitCount == 256 else {
            throw E2EEError.invalidKey
        }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encrypted)
            let decrypted = try AES.GCM.open(sealedBox, using: key)
            return decrypted
        } catch {
            throw E2EEError.decryptionFailed(error.localizedDescription)
        }
    }
    
    /// Decrypt data and decode to Codable object
    /// - Parameters:
    ///   - encrypted: Encrypted data blob
    ///   - key: 256-bit symmetric key
    /// - Returns: Decoded object
    /// - Throws: E2EEError or decoding errors
    static func decryptObject<T: Codable>(_ encrypted: Data, with key: SymmetricKey) throws -> T {
        let decrypted = try decrypt(encrypted, with: key)
        return try JSONDecoder().decode(T.self, from: decrypted)
    }
    
    // MARK: - Key Generation
    
    /// Generate new 256-bit symmetric key for AES-GCM
    /// - Returns: New symmetric key (store securely in Keychain)
    static func generateUserKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    // MARK: - Diffie-Hellman Key Exchange
    
    /// Generate Curve25519 key pair for Diffie-Hellman exchange
    /// - Returns: Tuple of (private key, public key)
    /// - Note: Private key stored in Keychain, public key uploaded to server
    static func generateKeyPair() -> (private: Curve25519.KeyAgreement.PrivateKey, public: Curve25519.KeyAgreement.PublicKey) {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey
        return (privateKey, publicKey)
    }
    
    /// Derive shared secret from Diffie-Hellman exchange
    /// - Parameters:
    ///   - myPrivateKey: This user's private key (from Keychain)
    ///   - theirPublicKey: Other user's public key (from server)
    /// - Returns: Shared 256-bit symmetric key (both parties compute same key)
    /// - Throws: E2EEError if key derivation fails
    static func deriveSharedKey(
        myPrivateKey: Curve25519.KeyAgreement.PrivateKey,
        theirPublicKey: Curve25519.KeyAgreement.PublicKey
    ) throws -> SymmetricKey {
        do {
            let sharedSecret = try myPrivateKey.sharedSecretFromKeyAgreement(with: theirPublicKey)
            
            // Derive symmetric key using HKDF (HMAC-based Key Derivation Function)
            let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: Data(),  // No salt (could add for extra security)
                sharedInfo: Data(),  // No additional context
                outputByteCount: 32  // 256 bits
            )
            
            return symmetricKey
        } catch {
            throw E2EEError.keyGenerationFailed
        }
    }
    
    // MARK: - Key Serialization
    
    /// Convert symmetric key to Data for storage
    /// - Parameter key: Symmetric key
    /// - Returns: Raw key data (32 bytes for 256-bit key)
    static func serializeKey(_ key: SymmetricKey) -> Data {
        return key.withUnsafeBytes { Data($0) }
    }
    
    /// Convert Data back to symmetric key
    /// - Parameter data: Raw key data (must be 32 bytes)
    /// - Returns: Symmetric key
    /// - Throws: E2EEError if data is invalid
    static func deserializeKey(from data: Data) throws -> SymmetricKey {
        guard data.count == 32 else {
            throw E2EEError.invalidKey
        }
        return SymmetricKey(data: data)
    }
    
    /// Convert public key to base64 string for server storage
    /// - Parameter publicKey: Curve25519 public key
    /// - Returns: Base64-encoded string
    static func serializePublicKey(_ publicKey: Curve25519.KeyAgreement.PublicKey) -> String {
        return publicKey.rawRepresentation.base64EncodedString()
    }
    
    /// Convert base64 string back to public key
    /// - Parameter base64: Base64-encoded public key
    /// - Returns: Curve25519 public key
    /// - Throws: E2EEError if string is invalid
    static func deserializePublicKey(from base64: String) throws -> Curve25519.KeyAgreement.PublicKey {
        guard let data = Data(base64Encoded: base64) else {
            throw E2EEError.invalidData
        }
        
        do {
            return try Curve25519.KeyAgreement.PublicKey(rawRepresentation: data)
        } catch {
            throw E2EEError.invalidKey
        }
    }
    
    // MARK: - Utilities
    
    /// Verify data integrity after encryption/decryption roundtrip
    /// - Parameters:
    ///   - original: Original plaintext data
    ///   - key: Encryption key
    /// - Returns: True if roundtrip successful, false otherwise
    static func verifyRoundtrip(original: Data, key: SymmetricKey) -> Bool {
        do {
            let encrypted = try encrypt(original, with: key)
            let decrypted = try decrypt(encrypted, with: key)
            return original == decrypted
        } catch {
            return false
        }
    }
}

// MARK: - Convenience Extensions

extension SymmetricKey {
    /// Create symmetric key from base64-encoded string
    /// - Parameter base64: Base64-encoded key data
    /// - Throws: E2EEError if string is invalid
    init(base64Encoded base64: String) throws {
        guard let data = Data(base64Encoded: base64) else {
            throw E2EEManager.E2EEError.invalidData
        }
        guard data.count == 32 else {
            throw E2EEManager.E2EEError.invalidKey
        }
        self.init(data: data)
    }
    
    /// Convert key to base64 string
    var base64Encoded: String {
        return withUnsafeBytes { Data($0).base64EncodedString() }
    }
}
