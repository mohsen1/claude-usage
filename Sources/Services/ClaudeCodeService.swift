import Foundation
import Security

/// Switches Claude Code's active account by writing OAuth credentials
/// to its Keychain entry and updating ~/.claude/.claude.json.
actor ClaudeCodeService {
    static let shared = ClaudeCodeService()

    private let keychainService = "Claude Code-credentials"
    private let claudeJsonPath = NSHomeDirectory() + "/.claude/.claude.json"

    /// Switch Claude Code to use the given account's session.
    func switchAccount(sessionKey: String, organizationId: String, organizationName: String) async throws {
        let tokens = try await OAuthService.shared.getTokens(sessionKey: sessionKey)
        try writeCredentials(tokens: tokens)
        try updateClaudeJson(
            organizationId: organizationId,
            organizationName: organizationName
        )
    }

    // MARK: - Keychain

    private func writeCredentials(tokens: OAuthService.OAuthTokens) throws {
        struct Credentials: Encodable {
            let claudeAiOauth: OAuthData

            struct OAuthData: Encodable {
                let accessToken: String
                let refreshToken: String
                let expiresAt: Int64
                let scopes: [String]
                let subscriptionType: String?
                let rateLimitTier: String?
            }
        }

        let creds = Credentials(
            claudeAiOauth: .init(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                expiresAt: tokens.expiresAt,
                scopes: ["user:inference", "user:mcp_servers", "user:profile", "user:sessions:claude_code"],
                subscriptionType: tokens.subscriptionType,
                rateLimitTier: tokens.rateLimitTier
            )
        )

        let data = try JSONEncoder().encode(creds)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ClaudeCodeError.keychainWriteFailed
        }

        let account = NSUserName()

        // Delete existing entry
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
        ] as CFDictionary)

        // Add new entry
        let status = SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: json.data(using: .utf8)!,
        ] as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw ClaudeCodeError.keychainWriteFailed
        }
    }

    // MARK: - .claude.json

    private func updateClaudeJson(organizationId: String, organizationName: String) throws {
        let url = URL(fileURLWithPath: claudeJsonPath)

        var json: [String: Any] = [:]
        if let existingData = try? Data(contentsOf: url) {
            json = (try? JSONSerialization.jsonObject(with: existingData) as? [String: Any]) ?? [:]
        }

        // Update the oauthAccount with what we know.
        // Claude Code will re-fetch full account details on next launch.
        json["oauthAccount"] = [
            "organizationUuid": organizationId,
            "displayName": organizationName,
        ]

        let updatedData = try JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        )
        try updatedData.write(to: url, options: .atomic)
    }
}

enum ClaudeCodeError: Error, LocalizedError {
    case keychainWriteFailed
    case switchFailed(String)

    var errorDescription: String? {
        switch self {
        case .keychainWriteFailed: return "Failed to write Claude Code credentials"
        case .switchFailed(let msg): return msg
        }
    }
}
