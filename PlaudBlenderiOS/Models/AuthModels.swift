import Foundation

// MARK: - Auth URL

/// Response from `/api/auth/plaud/authorize` or `/api/auth/notion/authorize`.
struct AuthURLResponse: Codable, Sendable {
    let authUrl: String
    let state: String

    enum CodingKeys: String, CodingKey {
        case authUrl = "auth_url"
        case state
    }
}

/// Request body for token exchange.
struct TokenExchangeRequest: Codable, Sendable {
    let code: String
    var state: String?
}

/// Response from `/api/auth/plaud/status` or `/api/auth/notion/status`.
struct TokenStatus: Codable, Sendable {
    let isAuthenticated: Bool
    let hasAccessToken: Bool
    let expiresAt: String?
    let workspaceName: String?
    let extra: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case isAuthenticated = "is_authenticated"
        case hasAccessToken = "has_access_token"
        case expiresAt = "expires_at"
        case workspaceName = "workspace_name"
        case extra
    }
}
