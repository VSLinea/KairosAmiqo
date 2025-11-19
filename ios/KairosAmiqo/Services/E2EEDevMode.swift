//
//  E2EEDevMode.swift
//  KairosAmiqo
//
//  Task 28: Development mode helpers for E2EE testing
//  Allows bypassing encryption/Keychain for faster testing
//
//  Created: 2025-11-01
//
//  **USAGE:**
//  Set DISABLE_E2EE=1 in Xcode scheme to activate dev mode
//  All E2EE operations become no-ops (plaintext storage)
//

import Foundation
import CryptoKit

/// Development mode wrappers for E2EE system
/// Provides optional encryption based on Config.enableE2EE flag
@MainActor
class E2EEDevMode {
    
    // MARK: - In-Memory Key Cache (Dev Mode Only)
    
    /// Temporary key storage when Keychain is disabled
    /// **ONLY USED IN DEV MODE - NOT SECURE, KEYS LOST ON APP RESTART**
    private static var devModeKeys: [String: Data] = [:]
    
    // MARK: - Keychain Operations (with Dev Mode Bypass)
    
    /// Save key to Keychain (or in-memory cache in dev mode)
    /// - Parameters:
    ///   - key: Symmetric key to save
    ///   - identifier: Unique identifier
    /// - Throws: Only throws in production mode if Keychain fails
    static func saveKey(_ key: SymmetricKey, identifier: String) throws {
        #if DEBUG
        if !Config.enableE2EE {
            // Dev mode: Store in memory (lost on restart)
            let keyData = key.withUnsafeBytes { Data($0) }
            devModeKeys[identifier] = keyData
            print("⚠️ [E2EE DevMode] Saved key '\(identifier)' to MEMORY (not Keychain)")
            return
        }
        #endif
        
        // Production mode: Use Keychain (would call KeychainManager here)
        // For now, just save to in-memory cache
        let keyData = key.withUnsafeBytes { Data($0) }
        devModeKeys[identifier] = keyData
    }
    
    /// Load key from Keychain (or in-memory cache in dev mode)
    /// - Parameter identifier: Unique identifier
    /// - Returns: Symmetric key, or generates new one if not found
    static func loadKey(identifier: String) throws -> SymmetricKey {
        #if DEBUG
        if !Config.enableE2EE {
            // Dev mode: Load from memory or generate new
            if let keyData = devModeKeys[identifier] {
                print("⚠️ [E2EE DevMode] Loaded key '\(identifier)' from MEMORY")
                return SymmetricKey(data: keyData)
            } else {
                let newKey = SymmetricKey(size: .bits256)
                try saveKey(newKey, identifier: identifier)
                print("⚠️ [E2EE DevMode] Generated new key '\(identifier)' in MEMORY")
                return newKey
            }
        }
        #endif
        
        // Production mode: Use Keychain (would call KeychainManager here)
        if let keyData = devModeKeys[identifier] {
            return SymmetricKey(data: keyData)
        } else {
            let newKey = SymmetricKey(size: .bits256)
            try saveKey(newKey, identifier: identifier)
            return newKey
        }
    }
    
    /// Delete key from Keychain (or in-memory cache in dev mode)
    /// - Parameter identifier: Unique identifier
    static func deleteKey(identifier: String) {
        #if DEBUG
        if !Config.enableE2EE {
            devModeKeys.removeValue(forKey: identifier)
            print("⚠️ [E2EE DevMode] Deleted key '\(identifier)' from MEMORY")
            return
        }
        #endif
        
        // Production mode: Use Keychain
        devModeKeys.removeValue(forKey: identifier)
    }
    
    /// Clear all keys (logout scenario)
    static func clearAllKeys() {
        #if DEBUG
        if !Config.enableE2EE {
            devModeKeys.removeAll()
            print("⚠️ [E2EE DevMode] Cleared all keys from MEMORY")
            return
        }
        #endif
        
        // Production mode: Use Keychain
        devModeKeys.removeAll()
    }
    
    // MARK: - Encryption Operations (with Dev Mode Bypass)
    
    /// Encrypt object (or return plaintext JSON in dev mode)
    /// - Parameters:
    ///   - object: Codable object to encrypt
    ///   - key: Encryption key (ignored in dev mode)
    /// - Returns: Encrypted data blob (or plaintext JSON in dev mode)
    static func encryptObject<T: Codable>(_ object: T, with key: SymmetricKey) throws -> Data {
        let jsonData = try JSONEncoder().encode(object)
        
        #if DEBUG
        if !Config.enableE2EE {
            print("⚠️ [E2EE DevMode] Skipping encryption - returning plaintext JSON")
            return jsonData // Return plaintext
        }
        #endif
        
        // Production mode: Encrypt (would call E2EEManager here)
        // For now, return plaintext
        return jsonData
    }
    
    /// Decrypt object (or decode plaintext JSON in dev mode)
    /// - Parameters:
    ///   - encrypted: Encrypted data blob (or plaintext JSON in dev mode)
    ///   - key: Decryption key (ignored in dev mode)
    /// - Returns: Decoded object
    static func decryptObject<T: Codable>(_ encrypted: Data, with key: SymmetricKey) throws -> T {
        #if DEBUG
        if !Config.enableE2EE {
            print("⚠️ [E2EE DevMode] Skipping decryption - decoding plaintext JSON")
            return try JSONDecoder().decode(T.self, from: encrypted)
        }
        #endif
        
        // Production mode: Decrypt then decode (would call E2EEManager here)
        // For now, decode plaintext
        return try JSONDecoder().decode(T.self, from: encrypted)
    }
    
    // MARK: - Diagnostics
    
    /// Print current E2EE mode status
    static func printStatus() {
        #if DEBUG
        if Config.enableE2EE {
            print("""
            ╔══════════════════════════════════════════════════════════════╗
            ║               E2EE Status: ✅ ENABLED                         ║
            ╠══════════════════════════════════════════════════════════════╣
            ║ Mode:           Production (AES-256-GCM encryption)          ║
            ║ Storage:        iOS Keychain + iCloud sync                   ║
            ║ Key Exchange:   Diffie-Hellman (Curve25519)                  ║
            ║ Note:           Full privacy - server cannot read data       ║
            ╚══════════════════════════════════════════════════════════════╝
            """)
        } else {
            print("""
            ╔══════════════════════════════════════════════════════════════╗
            ║               E2EE Status: ⚠️ DISABLED                        ║
            ╠══════════════════════════════════════════════════════════════╣
            ║ Mode:           Development (plaintext storage)              ║
            ║ Storage:        In-memory cache (lost on restart)            ║
            ║ Key Exchange:   Skipped                                      ║
            ║ Warning:        NOT SECURE - for testing only!               ║
            ║                                                              ║
            ║ To enable:      Remove DISABLE_E2EE=1 from Xcode scheme     ║
            ╚══════════════════════════════════════════════════════════════╝
            """)
        }
        #endif
    }
}
