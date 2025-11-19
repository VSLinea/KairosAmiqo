//
//  KeychainManagerTests.swift
//  KairosAmiqoTests
//
//  Task 28: Agent-to-Agent Negotiation - Keychain Tests
//  Week 1, Day 2: Verify secure key storage works correctly
//
//  Created: 2025-11-01
//

import XCTest
import CryptoKit
@testable import KairosAmiqo

final class KeychainManagerTests: XCTestCase {
    
    // MARK: - Setup/Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        // Clear Keychain before each test
        try? await KeychainManager.clearAllKeys()
    }
    
    override func tearDown() async throws {
        // Clean up after each test
        try? await KeychainManager.clearAllKeys()
        try await super.tearDown()
    }
    
    // MARK: - Save and Load Tests
    
    func testSaveAndLoadKey() async throws {
        // Given: A symmetric key
        let originalKey = E2EEManager.generateUserKey()
        
        // When: Save and load
        try await KeychainManager.saveKey(originalKey, identifier: .userMasterKey)
        let loadedKey = try await KeychainManager.loadKey(identifier: .userMasterKey)
        
        // Then: Loaded key can decrypt data encrypted with original key
        let testData = "Test message".data(using: .utf8)!
        let encrypted = try E2EEManager.encrypt(testData, with: originalKey)
        let decrypted = try E2EEManager.decrypt(encrypted, with: loadedKey)
        
        XCTAssertEqual(decrypted, testData)
    }
    
    func testSaveAndLoadData() async throws {
        // Given: Raw data
        let originalData = Data([1, 2, 3, 4, 5])
        
        // When: Save and load
        try await KeychainManager.saveData(originalData, identifier: .cloudEncryptionKey)
        let loadedData = try await KeychainManager.loadData(identifier: .cloudEncryptionKey)
        
        // Then: Data matches
        XCTAssertEqual(loadedData, originalData)
    }
    
    func testLoadNonexistentKeyThrows() async {
        // When/Then: Loading nonexistent key throws notFound error
        do {
            _ = try await KeychainManager.loadKey(identifier: .userMasterKey)
            XCTFail("Expected KeychainError.notFound")
        } catch KeychainManager.KeychainError.notFound {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Update Tests
    
    func testUpdateKey() async throws {
        // Given: Saved key
        let originalKey = E2EEManager.generateUserKey()
        try await KeychainManager.saveKey(originalKey, identifier: .userMasterKey)
        
        // When: Update with new key
        let newKey = E2EEManager.generateUserKey()
        try await KeychainManager.updateKey(newKey, identifier: .userMasterKey)
        
        // Then: Loaded key is the new one
        let loadedKey = try await KeychainManager.loadKey(identifier: .userMasterKey)
        
        let testData = "Test".data(using: .utf8)!
        let encrypted = try E2EEManager.encrypt(testData, with: newKey)
        let decrypted = try E2EEManager.decrypt(encrypted, with: loadedKey)
        
        XCTAssertEqual(decrypted, testData)
    }
    
    func testSaveDuplicateUpdatesInstead() async throws {
        // Given: Saved key
        let originalKey = E2EEManager.generateUserKey()
        try await KeychainManager.saveKey(originalKey, identifier: .userMasterKey)
        
        // When: Save again with same identifier (should update, not throw)
        let newKey = E2EEManager.generateUserKey()
        try await KeychainManager.saveKey(newKey, identifier: .userMasterKey)
        
        // Then: Loaded key is the new one
        let loadedKey = try await KeychainManager.loadKey(identifier: .userMasterKey)
        
        let testData = "Test".data(using: .utf8)!
        let encrypted = try E2EEManager.encrypt(testData, with: newKey)
        let decrypted = try E2EEManager.decrypt(encrypted, with: loadedKey)
        
        XCTAssertEqual(decrypted, testData)
    }
    
    // MARK: - Delete Tests
    
    func testDeleteKey() async throws {
        // Given: Saved key
        let key = E2EEManager.generateUserKey()
        try await KeychainManager.saveKey(key, identifier: .userMasterKey)
        
        // When: Delete key
        try await KeychainManager.deleteKey(identifier: .userMasterKey)
        
        // Then: Key no longer exists
        XCTAssertFalse(await KeychainManager.keyExists(identifier: .userMasterKey))
    }
    
    func testDeleteNonexistentKeyDoesNotThrow() async throws {
        // When/Then: Deleting nonexistent key doesn't throw
        try await KeychainManager.deleteKey(identifier: .userMasterKey)
        // No error = success
    }
    
    // MARK: - Key Existence Tests
    
    func testKeyExists() async throws {
        // Given: No key saved
        XCTAssertFalse(await KeychainManager.keyExists(identifier: .userMasterKey))
        
        // When: Save key
        let key = E2EEManager.generateUserKey()
        try await KeychainManager.saveKey(key, identifier: .userMasterKey)
        
        // Then: Key exists
        XCTAssertTrue(await KeychainManager.keyExists(identifier: .userMasterKey))
    }
    
    // MARK: - Generate and Save Tests
    
    func testGenerateAndSaveUserMasterKey() async throws {
        // When: Generate and save
        let key = try await KeychainManager.generateAndSaveUserMasterKey()
        
        // Then: Key is saved and can be loaded
        XCTAssertTrue(await KeychainManager.keyExists(identifier: .userMasterKey))
        
        let loadedKey = try await KeychainManager.loadKey(identifier: .userMasterKey)
        
        // Verify they're the same key
        let testData = "Test".data(using: .utf8)!
        let encrypted = try E2EEManager.encrypt(testData, with: key)
        let decrypted = try E2EEManager.decrypt(encrypted, with: loadedKey)
        
        XCTAssertEqual(decrypted, testData)
    }
    
    func testLoadOrGenerateUserMasterKey() async throws {
        // When: Load or generate (key doesn't exist)
        let key1 = try await KeychainManager.loadOrGenerateUserMasterKey()
        
        // Then: Key was generated and saved
        XCTAssertTrue(await KeychainManager.keyExists(identifier: .userMasterKey))
        
        // When: Load or generate again (key exists)
        let key2 = try await KeychainManager.loadOrGenerateUserMasterKey()
        
        // Then: Same key is loaded (not generated again)
        let testData = "Test".data(using: .utf8)!
        let encrypted1 = try E2EEManager.encrypt(testData, with: key1)
        let decrypted2 = try E2EEManager.decrypt(encrypted1, with: key2)
        
        XCTAssertEqual(decrypted2, testData)
    }
    
    // MARK: - Diffie-Hellman Tests
    
    func testSaveAndLoadDHPrivateKey() async throws {
        // Given: DH key pair
        let (privateKey, _) = E2EEManager.generateKeyPair()
        
        // When: Save and load private key
        try await KeychainManager.saveDHPrivateKey(privateKey)
        let loadedPrivateKey = try await KeychainManager.loadDHPrivateKey()
        
        // Then: Keys are the same (same public key)
        XCTAssertEqual(loadedPrivateKey.publicKey.rawRepresentation, privateKey.publicKey.rawRepresentation)
    }
    
    func testGenerateAndSaveDHKeyPair() async throws {
        // When: Generate and save
        let (privateKey, publicKey) = try await KeychainManager.generateAndSaveDHKeyPair()
        
        // Then: Private key is saved
        XCTAssertTrue(await KeychainManager.keyExists(identifier: .dhPrivateKey))
        
        // And: Keys are valid (public key matches private key)
        XCTAssertEqual(publicKey.rawRepresentation, privateKey.publicKey.rawRepresentation)
    }
    
    func testLoadOrGenerateDHKeyPair() async throws {
        // When: Load or generate (doesn't exist)
        let (privateKey1, publicKey1) = try await KeychainManager.loadOrGenerateDHKeyPair()
        
        // Then: Key pair was generated and saved
        XCTAssertTrue(await KeychainManager.keyExists(identifier: .dhPrivateKey))
        
        // When: Load or generate again (exists)
        let (privateKey2, publicKey2) = try await KeychainManager.loadOrGenerateDHKeyPair()
        
        // Then: Same key pair is loaded
        XCTAssertEqual(publicKey1.rawRepresentation, publicKey2.rawRepresentation)
        XCTAssertEqual(privateKey1.publicKey.rawRepresentation, privateKey2.publicKey.rawRepresentation)
    }
    
    // MARK: - Clear All Keys Tests
    
    func testClearAllKeys() async throws {
        // Given: Multiple keys saved
        try await KeychainManager.generateAndSaveUserMasterKey()
        try await KeychainManager.generateAndSaveDHKeyPair()
        
        XCTAssertTrue(await KeychainManager.keyExists(identifier: .userMasterKey))
        XCTAssertTrue(await KeychainManager.keyExists(identifier: .dhPrivateKey))
        
        // When: Clear all keys
        try await KeychainManager.clearAllKeys()
        
        // Then: All keys deleted
        XCTAssertFalse(await KeychainManager.keyExists(identifier: .userMasterKey))
        XCTAssertFalse(await KeychainManager.keyExists(identifier: .cloudEncryptionKey))
        XCTAssertFalse(await KeychainManager.keyExists(identifier: .dhPrivateKey))
    }
    
    // MARK: - Export/Import Tests
    
    func testExportAndImportUserMasterKey() async throws {
        // Given: Saved key
        let originalKey = try await KeychainManager.generateAndSaveUserMasterKey()
        
        // When: Export
        let exported = try await KeychainManager.exportUserMasterKey()
        
        // Then: Exported string is base64
        XCTAssertFalse(exported.isEmpty)
        XCTAssertNotNil(Data(base64Encoded: exported))
        
        // When: Delete and import
        try await KeychainManager.deleteKey(identifier: .userMasterKey)
        try await KeychainManager.importUserMasterKey(from: exported)
        
        // Then: Imported key works the same as original
        let importedKey = try await KeychainManager.loadKey(identifier: .userMasterKey)
        
        let testData = "Test".data(using: .utf8)!
        let encrypted = try E2EEManager.encrypt(testData, with: originalKey)
        let decrypted = try E2EEManager.decrypt(encrypted, with: importedKey)
        
        XCTAssertEqual(decrypted, testData)
    }
    
    // MARK: - Diagnostics Tests
    
    func testDiagnostics() async throws {
        // Given: No keys
        var diagnostics = await KeychainManager.diagnostics()
        XCTAssertFalse(diagnostics["userMasterKey"] ?? true)
        XCTAssertFalse(diagnostics["cloudEncryptionKey"] ?? true)
        XCTAssertFalse(diagnostics["dhPrivateKey"] ?? true)
        
        // When: Save some keys
        try await KeychainManager.generateAndSaveUserMasterKey()
        try await KeychainManager.generateAndSaveDHKeyPair()
        
        // Then: Diagnostics show correct status
        diagnostics = await KeychainManager.diagnostics()
        XCTAssertTrue(diagnostics["userMasterKey"] ?? false)
        XCTAssertFalse(diagnostics["cloudEncryptionKey"] ?? true)
        XCTAssertTrue(diagnostics["dhPrivateKey"] ?? false)
    }
    
    // MARK: - iCloud Sync Tests
    
    func testSaveWithiCloudSync() async throws {
        // When: Save with iCloud sync enabled
        let key = E2EEManager.generateUserKey()
        try await KeychainManager.saveKey(key, identifier: .userMasterKey, syncWithiCloud: true)
        
        // Then: Key is saved (iCloud sync flag is set in Keychain attributes)
        XCTAssertTrue(await KeychainManager.keyExists(identifier: .userMasterKey))
        
        // Note: Can't directly test iCloud sync in unit tests,
        // but we verify the flag is accepted without errors
    }
    
    func testSaveWithoutICloudSync() async throws {
        // When: Save with iCloud sync disabled
        let key = E2EEManager.generateUserKey()
        try await KeychainManager.saveKey(key, identifier: .userMasterKey, syncWithiCloud: false)
        
        // Then: Key is saved locally only
        XCTAssertTrue(await KeychainManager.keyExists(identifier: .userMasterKey))
    }
}
