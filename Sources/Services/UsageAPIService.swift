import Foundation

actor UsageAPIService {
    static let shared = UsageAPIService()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    struct Organization: Codable {
        let uuid: String
        let name: String
    }

    func fetchOrganizations(sessionKey: String) async throws -> [Organization] {
        let url = URL(string: "https://claude.ai/api/organizations")!
        var request = URLRequest(url: url)
        applyHeaders(&request, sessionKey: sessionKey)
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try JSONDecoder().decode([Organization].self, from: data)
    }

    func fetchUsage(sessionKey: String, orgId: String) async throws -> UsageData {
        let url = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage")!
        var request = URLRequest(url: url)
        applyHeaders(&request, sessionKey: sessionKey)
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try JSONDecoder().decode(UsageData.self, from: data)
    }

    private func applyHeaders(_ request: inout URLRequest, sessionKey: String) {
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://claude.ai", forHTTPHeaderField: "Referer")
        request.setValue("claude.ai", forHTTPHeaderField: "Origin")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
    }

    private func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        switch http.statusCode {
        case 200...299: return
        case 401: throw APIError.unauthorized
        case 403:
            let body = String(data: data.prefix(200), encoding: .utf8) ?? ""
            throw APIError.forbidden(body)
        case 429: throw APIError.rateLimited
        default: throw APIError.httpError(http.statusCode)
        }
    }
}

extension APIError {
    var isForbidden: Bool {
        if case .forbidden = self { return true }
        return false
    }
}

enum APIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case forbidden(String)
    case rateLimited
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response"
        case .unauthorized: return "Session expired"
        case .forbidden(let detail):
            if detail.lowercased().contains("cloudflare") || detail.contains("cf-") {
                return "Blocked by Cloudflare"
            }
            return "Forbidden (403)"
        case .rateLimited: return "Rate limited"
        case .httpError(let code): return "HTTP \(code)"
        }
    }
}
