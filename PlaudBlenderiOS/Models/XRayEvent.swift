import Foundation

/// Matches `XRayEventOut` from the FastAPI backend.
struct XRayEvent: Codable, Identifiable, Sendable {
    let seq: Int
    let ts: Double
    let source: String
    let op: String
    let message: String
    let durationMs: Double?
    let detail: String?
    let level: String

    var id: Int { seq }

    var date: Date {
        Date(timeIntervalSince1970: ts)
    }

    enum CodingKeys: String, CodingKey {
        case seq, ts, source, op, message
        case durationMs = "duration_ms"
        case detail, level
    }
}

/// Wrapper for `/api/xray/events` response.
struct XRayEventsResponse: Codable, Sendable {
    let events: [XRayEvent]
    let latestSeq: Int

    enum CodingKeys: String, CodingKey {
        case events
        case latestSeq = "latest_seq"
    }
}

/// Throughput response from `/api/xray/throughput`.
struct XRayThroughput: Codable, Sendable {
    let buckets: [Int]
}
