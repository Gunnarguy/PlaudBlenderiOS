import Foundation

/// Deep system connectivity status from `GET /api/v1/status`.
struct SystemStatus: Decodable, Sendable {
    let database: ServiceCheck?
    let qdrant: QdrantCheck?
    let gemini: ServiceFlag?
    let openai: ServiceCheck?
    let plaud: ServiceFlag?
    let notion: ServiceFlag?

    struct ServiceCheck: Decodable, Sendable {
        let ok: Bool
        let url: String?
        let detail: String?
        let error: String?
    }

    struct QdrantCheck: Decodable, Sendable {
        let ok: Bool
        let url: String?
        let collections: Int?
        let error: String?
    }

    struct ServiceFlag: Decodable, Sendable {
        let configured: Bool?
        let ok: Bool?
        let isAuthenticated: Bool?
        let hasCredentials: Bool?
        let hasAccessToken: Bool?
        let workspaceName: String?
        let error: String?

        var isUp: Bool {
            ok == true
                || isAuthenticated == true
                || hasCredentials == true
                || hasAccessToken == true
                || configured == true
        }

        enum CodingKeys: String, CodingKey {
            case configured, ok, error
            case hasCredentials = "has_credentials"
            case hasAccessToken = "has_access_token"
            case workspaceName = "workspace_name"
            case isAuthenticated = "is_authenticated"
        }
    }
}
