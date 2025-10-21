//
//  PairingService.swift
//  StealthyAI-macOS
//
//  Created by Claude on 2025-09-30.
//

#if os(macOS)
import Foundation
import CryptoKit

struct PairingToken {
    let uuid: UUID
    let expiresAt: Date
}

protocol PairingService {
    func generateToken(ttl: TimeInterval) throws -> PairingToken
    func deepLink(for token: PairingToken) throws -> URL
    func verify(signature: Data, for tokenPayload: Data, using secret: Data) -> Bool
}

struct DefaultPairingService: PairingService {
    func generateToken(ttl: TimeInterval) throws -> PairingToken {
        let uuid = UUID()
        let expiresAt = Date().addingTimeInterval(ttl)
        return PairingToken(uuid: uuid, expiresAt: expiresAt)
    }

    func deepLink(for token: PairingToken) throws -> URL {
        let secret = try Keychain.appPairingSecret()

        let version = 1
        let tokenString = token.uuid.uuidString
        let exp = Int(token.expiresAt.timeIntervalSince1970)

        // Create HMAC signature
        let payload = "\(version).\(tokenString).\(exp)"
        guard let payloadData = payload.data(using: .utf8) else {
            throw PairingError.invalidPayload
        }

        let signature = HMAC<SHA256>.authenticationCode(for: payloadData, using: SymmetricKey(data: secret))
        let signatureBase64URL = Data(signature).base64URLEncoded()

        // Build deep link
        var components = URLComponents()
        components.scheme = "stealthyai"
        components.host = "pair"
        components.queryItems = [
            URLQueryItem(name: "v", value: "\(version)"),
            URLQueryItem(name: "token", value: tokenString),
            URLQueryItem(name: "exp", value: "\(exp)"),
            URLQueryItem(name: "sig", value: signatureBase64URL)
        ]

        guard let url = components.url else {
            throw PairingError.invalidURL
        }

        return url
    }

    func verify(signature: Data, for tokenPayload: Data, using secret: Data) -> Bool {
        let key = SymmetricKey(data: secret)
        return HMAC<SHA256>.isValidAuthenticationCode(signature, authenticating: tokenPayload, using: key)
    }
}

enum PairingError: Error {
    case invalidPayload
    case invalidURL
}

// MARK: - Base64URL Encoding

extension Data {
    func base64URLEncoded() -> String {
        let base64 = self.base64EncodedString()
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded: String) {
        var base64 = base64URLEncoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        guard let data = Data(base64Encoded: base64) else {
            return nil
        }

        self = data
    }
}
#endif
