import Foundation
import CryptoKit
import Network

/// Performs OAuth PKCE flow using an existing session cookie to obtain
/// access + refresh tokens compatible with Claude Code.
actor OAuthService {
    static let shared = OAuthService()

    private let clientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private let authorizeURL = "https://claude.ai/oauth/authorize"
    private let tokenURL = "https://platform.claude.com/v1/oauth/token"
    private let scopes = "user:inference user:profile user:sessions:claude_code user:mcp_servers"

    struct OAuthTokens {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Int64
        let subscriptionType: String?
        let rateLimitTier: String?
    }

    /// Exchange a session cookie for OAuth tokens via PKCE flow.
    /// Opens a temporary local server, redirects through claude.ai/oauth/authorize,
    /// and exchanges the resulting code for tokens.
    func getTokens(sessionKey: String) async throws -> OAuthTokens {
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        let port = try await findAvailablePort()
        let redirectURI = "http://localhost:\(port)/callback"

        let authCode = try await getAuthorizationCode(
            sessionKey: sessionKey,
            codeChallenge: codeChallenge,
            redirectURI: redirectURI,
            port: port
        )

        return try await exchangeCodeForTokens(
            code: authCode,
            codeVerifier: codeVerifier,
            redirectURI: redirectURI
        )
    }

    // MARK: - PKCE

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncoded()
    }

    // MARK: - Authorization code via local server

    private func getAuthorizationCode(
        sessionKey: String,
        codeChallenge: String,
        redirectURI: String,
        port: UInt16
    ) async throws -> String {
        // Build authorize URL
        var components = URLComponents(string: authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        let authURL = components.url!

        // Use URLSession with session cookie to hit the authorize endpoint.
        // If the user already authorized Claude Code, this auto-redirects to callback.
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        let session = URLSession(configuration: config)

        // Set the session cookie
        let cookie = HTTPCookie(properties: [
            .name: "sessionKey",
            .value: sessionKey,
            .domain: "claude.ai",
            .path: "/",
            .secure: "TRUE",
        ])!
        session.configuration.httpCookieStorage?.setCookie(cookie)

        // Start local HTTP server to catch the callback
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let code = try await startCallbackServer(port: port, timeout: 30)
                    continuation.resume(returning: code)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            // Make the request to the authorize URL — follow redirects
            Task {
                var request = URLRequest(url: authURL)
                request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
                request.setValue(
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
                    forHTTPHeaderField: "User-Agent"
                )
                // Just hit it — the redirect will be caught by our local server
                _ = try? await session.data(for: request)
            }
        }
    }

    private func startCallbackServer(port: UInt16, timeout: TimeInterval) async throws -> String {
        let serverFD = socket(AF_INET, SOCK_STREAM, 0)
        guard serverFD >= 0 else { throw OAuthError.serverFailed }

        var opt: Int32 = 1
        setsockopt(serverFD, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { close(serverFD); throw OAuthError.serverFailed }
        listen(serverFD, 1)

        // Set non-blocking for timeout
        fcntl(serverFD, F_SETFL, O_NONBLOCK)

        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let clientFD = accept(serverFD, nil, nil)
            if clientFD >= 0 {
                defer { close(clientFD) }
                var buffer = [UInt8](repeating: 0, count: 4096)
                let bytesRead = read(clientFD, &buffer, buffer.count)
                if bytesRead > 0 {
                    let request = String(bytes: buffer.prefix(bytesRead), encoding: .utf8) ?? ""
                    // Parse GET /callback?code=xxx
                    if let codeLine = request.split(separator: "\r\n").first,
                       let path = codeLine.split(separator: " ").dropFirst().first,
                       let components = URLComponents(string: String(path)),
                       let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                        // Send success response
                        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<html><body><h2>Success!</h2><p>You can close this tab.</p></body></html>"
                        _ = response.utf8.withContiguousStorageIfAvailable { write(clientFD, $0.baseAddress!, $0.count) }
                        close(serverFD)
                        return code
                    }
                }
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        close(serverFD)
        throw OAuthError.timeout
    }

    // MARK: - Token exchange

    private func exchangeCodeForTokens(
        code: String,
        codeVerifier: String,
        redirectURI: String
    ) async throws -> OAuthTokens {
        let url = URL(string: tokenURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: String] = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": codeVerifier,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OAuthError.tokenExchangeFailed
        }

        struct TokenResponse: Codable {
            let access_token: String
            let refresh_token: String
            let expires_in: Int?
            let subscription_type: String?
            let rate_limit_tier: String?
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let expiresAt = Int64(Date().timeIntervalSince1970 * 1000) + Int64((tokenResponse.expires_in ?? 3600) * 1000)

        return OAuthTokens(
            accessToken: tokenResponse.access_token,
            refreshToken: tokenResponse.refresh_token,
            expiresAt: expiresAt,
            subscriptionType: tokenResponse.subscription_type,
            rateLimitTier: tokenResponse.rate_limit_tier
        )
    }

    // MARK: - Helpers

    private func findAvailablePort() async throws -> UInt16 {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw OAuthError.serverFailed }
        defer { close(fd) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0 // OS picks a port
        addr.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { throw OAuthError.serverFailed }

        var boundAddr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        getsockname(fd, withUnsafeMutablePointer(to: &boundAddr) {
            UnsafeMutableRawPointer($0).assumingMemoryBound(to: sockaddr.self)
        }, &len)

        return UInt16(bigEndian: boundAddr.sin_port)
    }
}

enum OAuthError: Error, LocalizedError {
    case serverFailed
    case timeout
    case tokenExchangeFailed
    case noTokens

    var errorDescription: String? {
        switch self {
        case .serverFailed: return "Failed to start auth server"
        case .timeout: return "OAuth timed out"
        case .tokenExchangeFailed: return "Token exchange failed"
        case .noTokens: return "No OAuth tokens available"
        }
    }
}

extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
