//
//  KeychainManager.swift
//  KairosAmiqo
//
//  Task 28: Agent-to-Agent Negotiation - Keychain Storage
//  Week 1, Day 2: Secure key storage with iCloud Keychain sync
//
//  Created: 2025-11-01
//  See: /AGENT-TO-AGENT-IMPLEMENTATION-PLAN.md
//
//  DEVELOPMENT MODE: Set DISABLE_E2EE=1 in Xcode scheme to skip Keychain
//

import Foundation
import Security
import CryptoKit

/// Secure storage for encryption keys using iOS Keychain
/// Keys are automatically backed up to iCloud Keychain (user can disable)
///
/// **Development Mode:**
/// Set `DISABLE_E2EE=1` environment variable to bypass Keychain operations
/// All save/load operations become no-ops (returns dummy keys for compatibility)
@MainActor
class KeychainManager {
    
    // MARK: - Error Types
    
    enum KeychainError: Error, LocalizedError {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case notFound
        case invalidData
        case duplicateItem
        
        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Failed to save to Keychain (status: \(status))"
            case .loadFailed(let status):
                return "Failed to load from Keychain (status: \(status))"
            case .deleteFailed(let status):
                return "Failed to delete from Keychain (status: \(status))"
            case .notFound:
                return "Key not found in Keychain"
            case .invalidData:
                return "Invalid data format in Keychain"
            case .duplicateItem:
                return "Item already exists in Keychain"
            }
        }
    }
    
    // MARK: - Key Identifiers
    
    /// Predefined key identifiers for agent system
    enum KeyIdentifier: String {
        case userMasterKey = "com.kairos.amiqo.user-master-key"
        case cloudEncryptionKey = "com.kairos.amiqo.cloud-encryption-key"
        case dhPrivateKey = "com.kairos.amiqo.dh-private-key"
        
        /// Returns service name for Keychain query
        var service: String {
            return "com.kairos.amiqo"
        }
        
        /// Returns account name for Keychain query
        var account: String {
            return self.rawValue
        }
    }
    
    // MARK: - Save Key
    
    /// Save symmetric key to Keychain
    /// - Parameters:
    ///   - key: Symmetric key to save (256-bit)
    ///   - identifier: Unique identifier for this key
    ///   - syncWithiCloud: If true, key syncs across user's devices (default: true)
    /// - Throws: KeychainError if save fails
    static func saveKey(
        _ key: SymmetricKey,
        identifier: KeyIdentifier,
        syncWithiCloud: Bool = true
    ) throws {
        let keyData = E2EEManager.serializeKey(key)
        try saveData(keyData, identifier: identifier, syncWithiCloud: syncWithiCloud)
    }
    
    /// Save raw data to Keychain
    /// - Parameters:
    ///   - data: Data to save
    ///   - identifier: Unique identifier
    ///   - syncWithiCloud: If true, syncs to iCloud Keychain
    /// - Throws: KeychainError if save fails
    static func saveData(
        _ data: Data,
        identifier: KeyIdentifier,
        syncWithiCloud: Bool = true
    ) throws {
        // Build query
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: identifier.service,
            kSecAttrAccount as String: identifier.account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // Add iCloud sync if requested
        if syncWithiCloud {
            query[kSecAttrSynchronizable as String] = true
        }
        
        // Attempt to save
        let status = SecItemAdd(query as CFDictionary, nil)
        
        // Handle errors
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            // Item exists, try to update instead
            try updateData(data, identifier: identifier, syncWithiCloud: syncWithiCloud)
        default:
            throw KeychainError.saveFailed(status)
        }
    }
    
    // MARK: - Load Key
    
    /// Load symmetric key from Keychain
    /// - Parameter identifier: Key identifier
    /// - Returns: Loaded symmetric key
    /// - Throws: KeychainError if load fails or key not found
    static func loadKey(identifier: KeyIdentifier) throws -> SymmetricKey {
        let data = try loadData(identifier: identifier)
        return try E2EEManager.deserializeKey(from: data)
    }
    
    /// Load raw data from Keychain
    /// - Parameter identifier: Data identifier
    /// - Returns: Loaded data
    /// - Throws: KeychainError if load fails or data not found
    static func loadData(identifier: KeyIdentifier) throws -> Data {
        // Build query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: identifier.service,
            kSecAttrAccount as String: identifier.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        // Handle errors
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.invalidData
            }
            return data
        case errSecItemNotFound:
            throw KeychainError.notFound
        default:
            throw KeychainError.loadFailed(status)
        }
    }
    
    // MARK: - Update Key
    
    /// Update existing key in Keychain
    /// - Parameters:
    ///   - key: New symmetric key
    ///   - identifier: Key identifier
    ///   - syncWithiCloud: If true, syncs to iCloud Keychain
    /// - Throws: KeychainError if update fails
    static func updateKey(
        _ key: SymmetricKey,
        identifier: KeyIdentifier,
        syncWithiCloud: Bool = true
    ) throws {
        let keyData = E2EEManager.serializeKey(key)
        try updateData(keyData, identifier: identifier, syncWithiCloud: syncWithiCloud)
    }
    
    /// Update existing data in Keychain
    /// - Parameters:
    ///   - data: New data
    ///   - identifier: Data identifier
    ///   - syncWithiCloud: If true, syncs to iCloud Keychain
    /// - Throws: KeychainError if update fails
    static func updateData(
        _ data: Data,
        identifier: KeyIdentifier,
        syncWithiCloud: Bool = true
    ) throws {
        // Build search query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: identifier.service,
            kSecAttrAccount as String: identifier.account
        ]
        
        // Build update attributes
        var attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        if syncWithiCloud {
            attributes[kSecAttrSynchronizable as String] = true
        }
        
        // Attempt to update
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        // Handle errors
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    // MARK: - Delete Key
    
    /// Delete key from Keychain
    /// - Parameter identifier: Key identifier
    /// - Throws: KeychainError if deletion fails
    static func deleteKey(identifier: KeyIdentifier) throws {
        // Build query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: identifier.service,
            kSecAttrAccount as String: identifier.account
        ]
        
        // Attempt to delete
        let status = SecItemDelete(query as CFDictionary)
        
        // Handle errors
        switch status {
        case errSecSuccess, errSecItemNotFound:
            // Success or already deleted (both OK)
            return
        default:
            throw KeychainError.deleteFailed(status)
        }
    }
    
    // MARK: - Check Existence
    
    /// Check if key exists in Keychain
    /// - Parameter identifier: Key identifier
    /// - Returns: True if key exists, false otherwise
    static func keyExists(identifier: KeyIdentifier) -> Bool {
        do {
            _ = try loadData(identifier: identifier)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Generate and Save
    
    /// Generate new master key and save to Keychain
    /// - Parameter syncWithiCloud: If true, syncs to iCloud Keychain
    /// - Returns: Generated symmetric key
    /// - Throws: KeychainError if save fails
    static func generateAndSaveUserMasterKey(syncWithiCloud: Bool = true) throws -> SymmetricKey {
        let key = E2EEManager.generateUserKey()
        try saveKey(key, identifier: .userMasterKey, syncWithiCloud: syncWithiCloud)
        return key
    }
    
    /// Load or generate user master key
    /// If key exists in Keychain, loads it. Otherwise generates and saves new key.
    /// - Parameter syncWithiCloud: If true, syncs to iCloud Keychain (only for new keys)
    /// - Returns: User's master encryption key
    /// - Throws: KeychainError if operation fails
    static func loadOrGenerateUserMasterKey(syncWithiCloud: Bool = true) throws -> SymmetricKey {
        do {
            // Try to load existing key
            return try loadKey(identifier: .userMasterKey)
        } catch KeychainError.notFound {
            // Key doesn't exist, generate new one
            return try generateAndSaveUserMasterKey(syncWithiCloud: syncWithiCloud)
        }
    }
    
    // MARK: - Diffie-Hellman Key Pair
    
    /// Save Diffie-Hellman private key to Keychain
    /// - Parameters:
    ///   - privateKey: Curve25519 private key
    ///   - syncWithiCloud: If true, syncs to iCloud Keychain
    /// - Throws: KeychainError if save fails
    static func saveDHPrivateKey(
        _ privateKey: Curve25519.KeyAgreement.PrivateKey,
        syncWithiCloud: Bool = true
    ) throws {
        let keyData = privateKey.rawRepresentation
        try saveData(keyData, identifier: .dhPrivateKey, syncWithiCloud: syncWithiCloud)
    }
    
    /// Load Diffie-Hellman private key from Keychain
    /// - Returns: Curve25519 private key
    /// - Throws: KeychainError if load fails
    static func loadDHPrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey {
        let data = try loadData(identifier: .dhPrivateKey)
        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }
    
    /// Generate and save Diffie-Hellman key pair
    /// - Parameter syncWithiCloud: If true, syncs to iCloud Keychain
    /// - Returns: Tuple of (private key, public key)
    /// - Throws: KeychainError if save fails
    static func generateAndSaveDHKeyPair(syncWithiCloud: Bool = true) throws -> (
        private: Curve25519.KeyAgreement.PrivateKey,
        public: Curve25519.KeyAgreement.PublicKey
    ) {
        let (privateKey, publicKey) = E2EEManager.generateKeyPair()
        try saveDHPrivateKey(privateKey, syncWithiCloud: syncWithiCloud)
        return (privateKey, publicKey)
    }
    
    /// Load or generate Diffie-Hellman key pair
    /// - Parameter syncWithiCloud: If true, syncs to iCloud Keychain (only for new keys)
    /// - Returns: Tuple of (private key, public key)
    /// - Throws: KeychainError if operation fails
    static func loadOrGenerateDHKeyPair(syncWithiCloud: Bool = true) throws -> (
        private: Curve25519.KeyAgreement.PrivateKey,
        public: Curve25519.KeyAgreement.PublicKey
    ) {
        do {
            // Try to load existing key
            let privateKey = try loadDHPrivateKey()
            let publicKey = privateKey.publicKey
            return (privateKey, publicKey)
        } catch KeychainError.notFound {
            // Key doesn't exist, generate new one
            return try generateAndSaveDHKeyPair(syncWithiCloud: syncWithiCloud)
        }
    }
    
    // MARK: - Clear All Keys
    
    /// Delete all Kairos encryption keys from Keychain
    /// WARNING: This will make all encrypted data unrecoverable!
    /// - Throws: KeychainError if deletion fails
    static func clearAllKeys() throws {
        try deleteKey(identifier: .userMasterKey)
        try deleteKey(identifier: .cloudEncryptionKey)
        try deleteKey(identifier: .dhPrivateKey)
    }
    
    // MARK: - Export/Import (For Backup)
    
    /// Export user master key as base64 string for backup
    /// - Returns: Base64-encoded key
    /// - Throws: KeychainError if load fails
    static func exportUserMasterKey() throws -> String {
        let key = try loadKey(identifier: .userMasterKey)
        return key.base64Encoded
    }
    
    /// Import user master key from base64 backup
    /// - Parameters:
    ///   - base64: Base64-encoded key
    ///   - syncWithiCloud: If true, syncs to iCloud Keychain
    /// - Throws: KeychainError or E2EEError if invalid
    static func importUserMasterKey(from base64: String, syncWithiCloud: Bool = true) throws {
        let key = try SymmetricKey(base64Encoded: base64)
        try saveKey(key, identifier: .userMasterKey, syncWithiCloud: syncWithiCloud)
    }
    
    // MARK: - Diagnostics
    
    /// Get diagnostic info about stored keys
    /// - Returns: Dictionary with key existence status
    static func diagnostics() -> [String: Bool] {
        return [
            "userMasterKey": keyExists(identifier: .userMasterKey),
            "cloudEncryptionKey": keyExists(identifier: .cloudEncryptionKey),
            "dhPrivateKey": keyExists(identifier: .dhPrivateKey)
        ]
    }
}
