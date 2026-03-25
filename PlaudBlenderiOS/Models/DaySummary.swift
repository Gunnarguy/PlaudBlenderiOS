import Foundation

/// Matches `DaySummaryOut` from the FastAPI backend.
struct DaySummary: Codable, Identifiable, Sendable {
    let date: String
    let dateDisplay: String?
    let totalDurationSeconds: Double
    let recordingCount: Int
    let eventCount: Int
    let topCategory: String?
    let categoryPercentages: [String: Double]?
    let topKeywords: [String]?
    let aiSummary: String?
    let recordings: [RecordingSummary]?

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date
        case dateDisplay = "date_display"
        case totalDurationSeconds = "total_duration_seconds"
        case recordingCount = "recording_count"
        case eventCount = "event_count"
        case topCategory = "top_category"
        case categoryPercentages = "category_percentages"
        case topKeywords = "top_keywords"
        case aiSummary = "ai_summary"
        case recordings
    }
}

/// Wrapper for the `/api/days` and `/api/days/filled` responses.
struct DaysResponse: Codable, Sendable {
    let days: [DaySummary]
    let total: Int?
}
