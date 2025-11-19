//
//  E2EEManagerTests.swift
//  KairosAmiqoTests
//
//  Task 28: Agent-to-Agent Negotiation - E2EE Tests
//  Week 1, Day 1: Verify encryption/decryption works correctly
//
//  Created: 2025-11-01
//

import XCTest
import CryptoKit
@testable import KairosAmiqo

final class E2EEManagerTests: XCTestCase {
    
    // MARK: - Basic Encryption/Decryption
    
    func testEncryptDecryptRoundtrip() throws {
        // Given: Original data and encryption key
        let originalData = "Hello, Kairos Agent!".data(using: .utf8)!
        let key = E2EEManager.generateUserKey()
        
        // When: Encrypt and decrypt
        let encrypted = try E2EEManager.encrypt(originalData, with: key)
        let decrypted = try E2EEManager.decrypt(encrypted, with: key)
        
        // Then: Decrypted data matches original
        XCTAssertEqual(decrypted, originalData)
        XCTAssertEqual(String(data: decrypted, encoding: .utf8), "Hello, Kairos Agent!")
    }
    
    func testEncryptedDataIsDifferent() throws {
        // Given: Original data
        let originalData = "Secret message".data(using: .utf8)!
        let key = E2EEManager.generateUserKey()
        
        // When: Encrypt
        let encrypted = try E2EEManager.encrypt(originalData, with: key)
        
        // Then: Encrypted data is different from original (not plaintext)
        XCTAssertNotEqual(encrypted, originalData)
        XCTAssertGreaterThan(encrypted.count, originalData.count) // Includes nonce + tag
    }
    
    func testDecryptWithWrongKeyFails() throws {
        // Given: Data encrypted with one key
        let originalData = "Secret".data(using: .utf8)!
        let correctKey = E2EEManager.generateUserKey()
        let wrongKey = E2EEManager.generateUserKey()
        let encrypted = try E2EEManager.encrypt(originalData, with: correctKey)
        
        // When/Then: Decrypting with wrong key throws error
        XCTAssertThrowsError(try E2EEManager.decrypt(encrypted, with: wrongKey)) { error in
            XCTAssertTrue(error is E2EEManager.E2EEError)
        }
    }
    
    func testTamperedDataFails() throws {
        // Given: Encrypted data
        let originalData = "Important data".data(using: .utf8)!
        let key = E2EEManager.generateUserKey()
        var encrypted = try E2EEManager.encrypt(originalData, with: key)
        
        // When: Tamper with encrypted data (flip one bit)
        encrypted[5] ^= 0xFF
        
        // Then: Decryption fails (authentication tag mismatch)
        XCTAssertThrowsError(try E2EEManager.decrypt(encrypted, with: key)) { error in
            XCTAssertTrue(error is E2EEManager.E2EEError)
        }
    }
    
    // MARK: - Codable Object Encryption
    
    struct TestPreferences: Codable, Equatable {
        let favoriteVenues: [String]
        let preferredTimes: [Int]
        let autonomyLevel: Double
    }
    
    func testEncryptDecryptCodableObject() throws {
        // Given: Codable object
        let preferences = TestPreferences(
            favoriteVenues: ["Café A", "Café B"],
            preferredTimes: [14, 19, 20],
            autonomyLevel: 0.8
        )
        let key = E2EEManager.generateUserKey()
        
        // When: Encrypt and decrypt
        let encrypted = try E2EEManager.encryptObject(preferences, with: key)
        let decrypted: TestPreferences = try E2EEManager.decryptObject(encrypted, with: key)
        
        // Then: Decrypted object matches original
        XCTAssertEqual(decrypted, preferences)
        XCTAssertEqual(decrypted.favoriteVenues, ["Café A", "Café B"])
        XCTAssertEqual(decrypted.preferredTimes, [14, 19, 20])
        XCTAssertEqual(decrypted.autonomyLevel, 0.8)
    }
    
    // MARK: - Key Generation
    
    func testGenerateUserKeyCreates256BitKey() {
        // When: Generate key
        let key = E2EEManager.generateUserKey()
        
        // Then: Key is 256 bits
        XCTAssertEqual(key.bitCount, 256)
    }
    
    func testGeneratedKeysAreUnique() {
        // When: Generate two keys
        let key1 = E2EEManager.generateUserKey()
        let key2 = E2EEManager.generateUserKey()
        
        // Then: Keys are different
        let data1 = E2EEManager.serializeKey(key1)
        let data2 = E2EEManager.serializeKey(key2)
        XCTAssertNotEqual(data1, data2)
    }
    
    // MARK: - Diffie-Hellman Key Exchange
    
    func testDiffieHellmanKeyExchange() throws {
        // Given: Alice and Bob generate key pairs
        let (alicePrivate, alicePublic) = E2EEManager.generateKeyPair()
        let (bobPrivate, bobPublic) = E2EEManager.generateKeyPair()
        
        // When: Each derives shared secret
        let aliceShared = try E2EEManager.deriveSharedKey(myPrivateKey: alicePrivate, theirPublicKey: bobPublic)
        let bobShared = try E2EEManager.deriveSharedKey(myPrivateKey: bobPrivate, theirPublicKey: alicePublic)
        
        // Then: Both derive the same shared key
        let aliceData = E2EEManager.serializeKey(aliceShared)
        let bobData = E2EEManager.serializeKey(bobShared)
        XCTAssertEqual(aliceData, bobData)
    }
    
    func testDiffieHellmanCanEncryptDecrypt() throws {
        // Given: Alice and Bob exchange public keys and derive shared secret
        let (alicePrivate, alicePublic) = E2EEManager.generateKeyPair()
        let (bobPrivate, bobPublic) = E2EEManager.generateKeyPair()
        
        let sharedKey = try E2EEManager.deriveSharedKey(myPrivateKey: alicePrivate, theirPublicKey: bobPublic)
        
        // When: Alice encrypts with shared key, Bob decrypts with shared key
        let message = "Secret plan: Coffee at 3pm".data(using: .utf8)!
        let encrypted = try E2EEManager.encrypt(message, with: sharedKey)
        
        let bobSharedKey = try E2EEManager.deriveSharedKey(myPrivateKey: bobPrivate, theirPublicKey: alicePublic)
        let decrypted = try E2EEManager.decrypt(encrypted, with: bobSharedKey)
        
        // Then: Bob can read Alice's message
        XCTAssertEqual(decrypted, message)
        XCTAssertEqual(String(data: decrypted, encoding: .utf8), "Secret plan: Coffee at 3pm")
    }
    
    // MARK: - Key Serialization
    
    func testSerializeDeserializeSymmetricKey() throws {
        // Given: Symmetric key
        let originalKey = E2EEManager.generateUserKey()
        
        // When: Serialize and deserialize
        let data = E2EEManager.serializeKey(originalKey)
        let restoredKey = try E2EEManager.deserializeKey(from: data)
        
        // Then: Restored key works the same as original
        let testData = "Test".data(using: .utf8)!
        let encrypted = try E2EEManager.encrypt(testData, with: originalKey)
        let decrypted = try E2EEManager.decrypt(encrypted, with: restoredKey)
        XCTAssertEqual(decrypted, testData)
    }
    
    func testSerializeDeserializePublicKey() throws {
        // Given: Public key
        let (_, publicKey) = E2EEManager.generateKeyPair()
        
        // When: Serialize to base64 and deserialize
        let base64 = E2EEManager.serializePublicKey(publicKey)
        let restoredKey = try E2EEManager.deserializePublicKey(from: base64)
        
        // Then: Restored key has same raw representation
        XCTAssertEqual(restoredKey.rawRepresentation, publicKey.rawRepresentation)
    }
    
    func testSymmetricKeyBase64Extension() throws {
        // Given: Symmetric key
        let originalKey = E2EEManager.generateUserKey()
        
        // When: Convert to base64 and back
        let base64 = originalKey.base64Encoded
        let restoredKey = try SymmetricKey(base64Encoded: base64)
        
        // Then: Restored key works correctly
        let testData = "Test".data(using: .utf8)!
        let encrypted = try E2EEManager.encrypt(testData, with: originalKey)
        let decrypted = try E2EEManager.decrypt(encrypted, with: restoredKey)
        XCTAssertEqual(decrypted, testData)
    }
    
    // MARK: - Utilities
    
    func testVerifyRoundtrip() {
        // Given: Original data and key
        let data = "Test data".data(using: .utf8)!
        let key = E2EEManager.generateUserKey()
        
        // When/Then: Roundtrip verification succeeds
        XCTAssertTrue(E2EEManager.verifyRoundtrip(original: data, key: key))
    }
    
    func testVerifyRoundtripFailsWithWrongKey() {
        // Given: Data encrypted with one key, verified with another
        let data = "Test data".data(using: .utf8)!
        let correctKey = E2EEManager.generateUserKey()
        let wrongKey = E2EEManager.generateUserKey()
        
        // When/Then: Roundtrip verification fails
        XCTAssertFalse(E2EEManager.verifyRoundtrip(original: data, key: wrongKey))
    }
    
    // MARK: - Edge Cases
    
    func testEncryptEmptyData() throws {
        // Given: Empty data
        let emptyData = Data()
        let key = E2EEManager.generateUserKey()
        
        // When: Encrypt and decrypt
        let encrypted = try E2EEManager.encrypt(emptyData, with: key)
        let decrypted = try E2EEManager.decrypt(encrypted, with: key)
        
        // Then: Decrypted data is also empty
        XCTAssertEqual(decrypted, emptyData)
        XCTAssertTrue(decrypted.isEmpty)
    }
    
    func testEncryptLargeData() throws {
        // Given: Large data (1MB)
        let largeData = Data(repeating: 0x42, count: 1024 * 1024)
        let key = E2EEManager.generateUserKey()
        
        // When: Encrypt and decrypt
        let encrypted = try E2EEManager.encrypt(largeData, with: key)
        let decrypted = try E2EEManager.decrypt(encrypted, with: key)
        
        // Then: Decrypted data matches original
        XCTAssertEqual(decrypted, largeData)
    }
    
    func testInvalidKeySize() throws {
        // Given: Data and 128-bit key (invalid, should be 256-bit)
        let data = "Test".data(using: .utf8)!
        let invalidKey = SymmetricKey(size: .bits128)
        
        // When/Then: Encryption throws error
        XCTAssertThrowsError(try E2EEManager.encrypt(data, with: invalidKey)) { error in
            guard case E2EEManager.E2EEError.invalidKey = error else {
                XCTFail("Expected E2EEError.invalidKey, got \(error)")
                return
            }
        }
    }
}
