import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.gunndamental.PlaudBlenderiOS", category: "APIClient")

struct ClientNetworkEvent: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let kind: String
    let method: String
    let url: String
    let path: String
    let statusCode: Int?
    let durationMs: Int
    let requestBytes: Int
    let responseBytes: Int
    let requestHeaders: [String: String]
    let responseHeaders: [String: String]
    let requestPreview: String?
    let responsePreview: String?
    let errorMessage: String?
    let requestId: String

    var isError: Bool {
        if errorMessage != nil {
            return true
        }
        if let statusCode {
            return !(200..<300).contains(statusCode)
        }
        return false
    }
}

/// Central HTTP client for all Chronos API calls.
/// Uses async/await with URLSession. Adds Bearer token auth automatically.
///
/// All ViewModels pass paths like "/api/search" but the FastAPI backend
/// mounts routes at "/api/v1/...". This client rewrites `/api/` → `/api/v1/`
/// so callers don't need to know the versioned path.
@Observable
final class APIClient: Sendable {
    let authManager: AuthManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let session: URLSession

    /// Observable connectivity state — drives UI banners
    var isServerReachable: Bool = false
    var lastHealthCheck: Date?
    var lastError: String?
    var networkEvents: [ClientNetworkEvent] = []

    private let maxNetworkEvents = 300

    init(authManager: AuthManager) {
        self.authManager = authManager

        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = false  // fail fast so we see errors
        self.session = URLSession(configuration: config)

        logger.info("APIClient initialized — server: \(authManager.serverURL, privacy: .public)")
    }

    private var baseURL: URL {
        guard let url = URL(string: authManager.serverURL) else {
            // Fallback — should never happen if AuthManager validates
            logger.fault("Invalid server URL: \(self.authManager.serverURL, privacy: .public)")
            return URL(string: "http://localhost:8000")!
        }
        return url
    }

    /// Rewrites `/api/foo` → `/api/v1/foo` to match the FastAPI router prefixes.
    private func versionedPath(_ path: String) -> String {
        if path.hasPrefix("/api/") && !path.hasPrefix("/api/v1/") {
            return path.replacingOccurrences(of: "/api/", with: "/api/v1/", options: [], range: path.startIndex..<path.index(path.startIndex, offsetBy: min(5, path.count)))
        }
        return path
    }

    // MARK: - HTTP Methods

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        let request = try buildRequest(path: versionedPath(path), method: "GET", query: query)
        return try await execute(request)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path: versionedPath(path), method: "POST")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    func post<T: Decodable>(_ path: String) async throws -> T {
        let request = try buildRequest(path: versionedPath(path), method: "POST")
        return try await execute(request)
    }

    func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path: versionedPath(path), method: "PUT")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        let request = try buildRequest(path: versionedPath(path), method: "DELETE")
        return try await execute(request)
    }

    // MARK: - Health Check (no auth required)

    func healthCheck() async -> Bool {
        if await checkHealth(at: authManager.serverURL) {
            return true
        }

        logger.warning("🏥 Health check failed for configured server; probing fallbacks")
        return await bootstrapConnection()
    }

    @discardableResult
    func bootstrapConnection() async -> Bool {
        for candidate in authManager.candidateServerURLs() {
            if await checkHealth(at: candidate) {
                if candidate != authManager.serverURL {
                    do {
                        try authManager.setServerURL(candidate)
                        logger.info("✅ Updated server URL to \(candidate, privacy: .public)")
                    } catch {
                        logger.error("❌ Failed to persist server URL \(candidate, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                }
                return true
            }
        }

        isServerReachable = false
        lastHealthCheck = Date()
        lastError = "Could not connect to any local Chronos server"
        return false
    }

    // MARK: - Private

    private func buildRequest(
        path: String,
        method: String,
        query: [String: String] = [:]
    ) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL(path)
        }
        if !query.isEmpty {
            components.queryItems = query.map {
                URLQueryItem(name: $0.key, value: $0.value)
            }
        }

        guard let url = components.url else {
            throw APIError.invalidURL(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if let token = authManager.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let requestId = UUID().uuidString.prefix(8).lowercased()
        request.setValue("ios-\(requestId)", forHTTPHeaderField: "X-Request-ID")

        logger.debug("📡 \(method, privacy: .public) \(url.absoluteString, privacy: .public) [\(requestId, privacy: .public)]")
        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let urlString = request.url?.absoluteString ?? "?"
        let path = request.url?.path(percentEncoded: false) ?? urlString
        let method = request.httpMethod ?? "?"
        let start = CFAbsoluteTimeGetCurrent()
        let requestBody = request.httpBody

        do {
            let (data, response) = try await session.data(for: request)
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)

            guard let http = response as? HTTPURLResponse else {
                logger.error("❌ \(method) \(urlString) — no HTTP response (\(elapsed)ms)")
                throw APIError.invalidResponse
            }

            let statusCode = http.statusCode
            guard 200..<300 ~= statusCode else {
                let body = String(data: data, encoding: .utf8) ?? ""
                await recordNetworkEvent(
                    kind: "http",
                    method: method,
                    url: urlString,
                    path: path,
                    statusCode: statusCode,
                    durationMs: elapsed,
                    requestHeaders: sanitizedHeaders(from: request.allHTTPHeaderFields ?? [:]),
                    responseHeaders: sanitizedHeaders(from: http.allHeaderFields),
                    requestBody: requestBody,
                    responseData: data,
                    errorMessage: body
                )
                logger.error("❌ \(method) \(urlString) — HTTP \(statusCode) (\(elapsed)ms) body=\(body.prefix(300), privacy: .public)")
                isServerReachable = true  // server is reachable, just returned an error
                throw APIError.httpError(status: statusCode, body: body)
            }

            await recordNetworkEvent(
                kind: "http",
                method: method,
                url: urlString,
                path: path,
                statusCode: statusCode,
                durationMs: elapsed,
                requestHeaders: sanitizedHeaders(from: request.allHTTPHeaderFields ?? [:]),
                responseHeaders: sanitizedHeaders(from: http.allHeaderFields),
                requestBody: requestBody,
                responseData: data,
                errorMessage: nil
            )
            logger.info("✅ \(method) \(urlString) — HTTP \(statusCode) (\(elapsed)ms) \(data.count) bytes")
            isServerReachable = true

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                let snippet = String(data: data.prefix(500), encoding: .utf8) ?? "(binary)"
                logger.error("🔴 DECODE FAILED \(method) \(urlString): \(error) — body: \(snippet, privacy: .public)")
                throw APIError.decodingFailed(error)
            }
        } catch let error as APIError {
            throw error  // re-throw our own errors
        } catch {
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            await recordNetworkEvent(
                kind: "http",
                method: method,
                url: urlString,
                path: path,
                statusCode: nil,
                durationMs: elapsed,
                requestHeaders: sanitizedHeaders(from: request.allHTTPHeaderFields ?? [:]),
                responseHeaders: [:],
                requestBody: requestBody,
                responseData: nil,
                errorMessage: error.localizedDescription
            )
            logger.error("🔴 NETWORK ERROR \(method) \(urlString) (\(elapsed)ms): \(error.localizedDescription, privacy: .public)")
            isServerReachable = false
            lastError = error.localizedDescription
            throw error
        }
    }

    private func checkHealth(at serverURL: String) async -> Bool {
        guard let url = URL(string: serverURL)?.appendingPathComponent("/api/v1/health") else {
            return false
        }

        logger.info("🏥 Health check → \(url.absoluteString, privacy: .public)")

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 5

            let start = CFAbsoluteTimeGetCurrent()
            let (data, response) = try await session.data(for: request)
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "(empty)"
            await recordNetworkEvent(
                kind: "health",
                method: "GET",
                url: url.absoluteString,
                path: url.path(percentEncoded: false),
                statusCode: status,
                durationMs: elapsed,
                requestHeaders: sanitizedHeaders(from: request.allHTTPHeaderFields ?? [:]),
                responseHeaders: sanitizedHeaders(from: (response as? HTTPURLResponse)?.allHeaderFields ?? [:]),
                requestBody: nil,
                responseData: data,
                errorMessage: status == 200 ? nil : body
            )
            logger.info("🏥 Health check ← HTTP \(status) body=\(body.prefix(200), privacy: .public)")

            let ok = status == 200
            isServerReachable = ok
            lastHealthCheck = Date()
            lastError = ok ? nil : "HTTP \(status)"
            return ok
        } catch {
            await recordNetworkEvent(
                kind: "health",
                method: "GET",
                url: url.absoluteString,
                path: url.path(percentEncoded: false),
                statusCode: nil,
                durationMs: 0,
                requestHeaders: [:],
                responseHeaders: [:],
                requestBody: nil,
                responseData: nil,
                errorMessage: error.localizedDescription
            )
            logger.error("🏥 Health check FAILED: \(error.localizedDescription, privacy: .public)")
            isServerReachable = false
            lastHealthCheck = Date()
            lastError = error.localizedDescription
            return false
        }
    }

    private func recordNetworkEvent(
        kind: String,
        method: String,
        url: String,
        path: String,
        statusCode: Int?,
        durationMs: Int,
        requestHeaders: [String: String],
        responseHeaders: [String: String],
        requestBody: Data?,
        responseData: Data?,
        errorMessage: String?
    ) async {
        let requestId = requestHeaders["X-Request-ID"] ?? "-"
        let event = ClientNetworkEvent(
            timestamp: Date(),
            kind: kind,
            method: method,
            url: url,
            path: path,
            statusCode: statusCode,
            durationMs: durationMs,
            requestBytes: requestBody?.count ?? 0,
            responseBytes: responseData?.count ?? 0,
            requestHeaders: requestHeaders,
            responseHeaders: responseHeaders,
            requestPreview: previewString(from: requestBody),
            responsePreview: previewString(from: responseData),
            errorMessage: errorMessage,
            requestId: requestId
        )

        await MainActor.run {
            networkEvents.insert(event, at: 0)
            if networkEvents.count > maxNetworkEvents {
                networkEvents.removeLast(networkEvents.count - maxNetworkEvents)
            }
        }
    }

    private func previewString(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        let previewLimit = 600
        let prefix = data.prefix(previewLimit)
        let string = String(decoding: prefix, as: UTF8.self)
        if data.count > previewLimit {
            return string + "…"
        }
        return string
    }

    private func sanitizedHeaders(from headers: [AnyHashable: Any]) -> [String: String] {
        var sanitized: [String: String] = [:]

        for (key, value) in headers {
            let headerKey = String(describing: key)
            let lowercasedKey = headerKey.lowercased()
            if ["authorization", "cookie", "set-cookie", "x-api-key"].contains(lowercasedKey) {
                sanitized[headerKey] = "<redacted>"
            } else {
                sanitized[headerKey] = String(describing: value)
            }
        }

        return sanitized
    }
}

// MARK: - API Error

enum APIError: Error, LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case httpError(status: Int, body: String)
    case decodingFailed(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL(let path):
            return "Invalid URL: \(path)"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let status, let body):
            return "HTTP \(status): \(body.prefix(200))"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .unauthorized:
            return "Authentication required"
        }
    }
}
