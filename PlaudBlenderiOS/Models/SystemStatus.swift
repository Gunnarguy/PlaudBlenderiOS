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
        let error: String?

        var isUp: Bool {
            ok ?? configured ?? isAuthenticated ?? false
        }

        enum CodingKeys: String, CodingKey {
            case configured, ok, error
            case isAuthenticated = "is_authenticated"
        }
    }
}
