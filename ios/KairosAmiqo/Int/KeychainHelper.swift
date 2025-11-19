//
//  KeychainHelper.swift
//  KairosAmiqo
//
//  Created by Lyra AI on 2025-10-04.
//

import Foundation
import Security

enum KeychainHelper {
    private static let service = "kairos.amiqo"
    private static let jwtAccount = "jwt"
    private static let refreshAccount = "refresh"
    private static let appleUserIDAccount = "appleUserID"
    // private static let googleUserIDAccount = "googleUserID" // Phase 4

    static func saveJWT(_ token: String) { save(data: Data(token.utf8), account: jwtAccount) }
    static func loadJWT() -> String? { load(account: jwtAccount) }

    static func saveRefresh(_ token: String) { save(data: Data(token.utf8), account: refreshAccount) }
    static func loadRefresh() -> String? { load(account: refreshAccount) }

    static func saveAppleUserID(_ userID: String) { save(data: Data(userID.utf8), account: appleUserIDAccount) }
    static func loadAppleUserID() -> String? { load(account: appleUserIDAccount) }
    static func deleteAppleUserID() { delete(account: appleUserIDAccount) }

    // Google Sign-In (SUSPENDED - Phase 4)
    // static func saveGoogleUserID(_ userID: String) { save(data: Data(userID.utf8), account: googleUserIDAccount) }
    // static func loadGoogleUserID() -> String? { load(account: googleUserIDAccount) }
    // static func deleteGoogleUserID() { delete(account: googleUserIDAccount) }

    static func deleteAll() {
        delete(account: jwtAccount)
        delete(account: refreshAccount)
        delete(account: appleUserIDAccount)
        // delete(account: googleUserIDAccount) // Phase 4
    }

    // MARK: - Internals

    private static func save(data: Data, account: String) {
        delete(account: account)
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemAdd(q as CFDictionary, nil)
    }

    private static func load(account: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else { return nil }
        return token
    }

    private static func delete(account: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(q as CFDictionary)
    }
}
