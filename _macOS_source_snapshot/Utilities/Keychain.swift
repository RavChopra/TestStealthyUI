//
//  Keychain.swift
//  StealthyAI-macOS
//
//  Created by Claude on 2025-09-30.
//

#if os(macOS)
import Foundation
import Security

enum KeychainError: Error {
    case notFound
    case unexpected
    case osStatus(OSStatus)
}

struct Keychain {
    private static let serviceName = "app.stealthyai.pairing"
    private static let accountName = "app.pairing.secret"

    /// Retrieves the app pairing secret from Keychain, creating it if missing
    static func appPairingSecret() throws -> Data {
        // Try to read existing secret
        if let existing = try? read() {
            return existing
        }

        // Generate new secret
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard result == errSecSuccess else {
            throw KeychainError.osStatus(result)
        }

        let secret = Data(bytes)
        try save(secret)
        return secret
    }

    /// Deletes the app pairing secret; next read will recreate
    static func resetAppPairingSecret() throws {
        try delete()
    }

    // MARK: - Private Helpers

    private static func read() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw status == errSecItemNotFound ? KeychainError.notFound : KeychainError.osStatus(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.unexpected
        }

        return data
    }

    private static func save(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.osStatus(status)
        }
    }

    private static func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.osStatus(status)
        }
    }
}
#endif
