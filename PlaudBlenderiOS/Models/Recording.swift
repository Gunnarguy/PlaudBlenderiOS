import Foundation

/// Matches `RecordingSummaryOut` from the FastAPI backend.
struct RecordingSummary: Codable, Identifiable, Hashable, Sendable {
    let recordingId: String
    let startTime: String?
    let endTime: String?
    let durationSeconds: Int
    let durationFormatted: String?
    let topCategory: String
    let eventCount: Int
    let timeRangeFormatted: String?
    let timeIsEstimated: Bool?
    let timeEstimateReason: String?
    let title: String?
    let plaudAiSummary: String?
    let cloudStatus: String?

    var id: String { recordingId }

    enum CodingKeys: String, CodingKey {
        case recordingId = "recording_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case durationSeconds = "duration_seconds"
        case durationFormatted = "duration_formatted"
        case topCategory = "top_category"
        case eventCount = "event_count"
        case timeRangeFormatted = "time_range_formatted"
        case timeIsEstimated = "time_is_estimated"
        case timeEstimateReason = "time_estimate_reason"
        case title
        case plaudAiSummary = "plaud_ai_summary"
        case cloudStatus = "cloud_status"
    }
}

/// Matches `RecordingDetailOut` from the FastAPI backend.
struct RecordingDetail: Codable, Sendable {
    let summary: RecordingSummary
    let events: [Event]
    let categoryPercentages: [String: Double]?
    let transcript: String?
    let aiSummary: String?
    let extractedData: [String: JSONValue]?
    let workflowStatus: [String: JSONValue]?
    let plaudTranscript: String?

    enum CodingKeys: String, CodingKey {
        case summary, events
        case categoryPercentages = "category_percentages"
        case transcript
        case aiSummary = "ai_summary"
        case extractedData = "extracted_data"
        case workflowStatus = "workflow_status"
        case plaudTranscript = "plaud_transcript"
    }
}
