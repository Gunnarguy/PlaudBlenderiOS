import Foundation

/// Matches `StatsOut` from the FastAPI backend.
struct Stats: Codable, Sendable {
    let totalRecordings: Int
    let totalEvents: Int
    let totalDays: Int
    let totalDurationHours: Double
    let categories: [String: Int]
    let sentimentAvg: Double?
    let topKeywords: [[String: JSONValue]]?
    let categoriesByHour: [String: JSONValue]?
    let sentimentDistribution: [String: Int]?
    let recentDays: [[String: JSONValue]]?
    let avgEventsPerRecording: Double?
    let avgRecordingDurationMin: Double?
    let mostProductiveDay: String?
    let mostProductiveHour: Int?
    let longestRecordingMin: Double?
    let pipelineCompletionRate: Double?
    let eventsByHour: [String: Int]?
    let eventsByDayOfWeek: [String: Int]?
    let plaudCloudStats: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case totalRecordings = "total_recordings"
        case totalEvents = "total_events"
        case totalDays = "total_days"
        case totalDurationHours = "total_duration_hours"
        case categories
        case sentimentAvg = "sentiment_avg"
        case topKeywords = "top_keywords"
        case categoriesByHour = "categories_by_hour"
        case sentimentDistribution = "sentiment_distribution"
        case recentDays = "recent_days"
        case avgEventsPerRecording = "avg_events_per_recording"
        case avgRecordingDurationMin = "avg_recording_duration_min"
        case mostProductiveDay = "most_productive_day"
        case mostProductiveHour = "most_productive_hour"
        case longestRecordingMin = "longest_recording_min"
        case pipelineCompletionRate = "pipeline_completion_rate"
        case eventsByHour = "events_by_hour"
        case eventsByDayOfWeek = "events_by_day_of_week"
        case plaudCloudStats = "plaud_cloud_stats"
    }

    // MARK: - Computed fallbacks (derive from existing data if backend doesn't send)

    var effectiveAvgEvents: Double {
        avgEventsPerRecording ?? (totalRecordings > 0 ? Double(totalEvents) / Double(totalRecordings) : 0)
    }

    var effectiveAvgDuration: Double {
        avgRecordingDurationMin ?? (totalRecordings > 0 ? totalDurationHours * 60.0 / Double(totalRecordings) : 0)
    }

    /// Derive events-by-hour from categoriesByHour if not provided directly
    var effectiveEventsByHour: [Int: Int] {
        if let direct = eventsByHour {
            return direct.reduce(into: [:]) { result, pair in
                if let h = Int(pair.key) { result[h] = pair.value }
            }
        }
        guard let byHour = categoriesByHour else { return [:] }
        return byHour.reduce(into: [:]) { result, pair in
            guard let h = Int(pair.key), let cats = pair.value.objectValue else { return }
            result[h] = cats.values.compactMap(\.intValue).reduce(0, +)
        }
    }

    /// Parse heatmap data: [hour][category] = count
    var heatmapData: [(hour: Int, category: String, count: Int)] {
        guard let byHour = categoriesByHour else { return [] }
        var rows: [(hour: Int, category: String, count: Int)] = []
        for (hourStr, catObj) in byHour {
            guard let h = Int(hourStr), let cats = catObj.objectValue else { continue }
            for (cat, val) in cats {
                if let c = val.intValue, c > 0 { rows.append((h, cat, c)) }
            }
        }
        return rows
    }
}

/// DB-level recording stats from `/api/sync/db-stats`.
struct RecordingDbStats: Decodable, Sendable {
    let total: Int
    let completed: Int
    let pending: Int
    let processing: Int
    let failed: Int
    let noTranscript: Int

    enum CodingKeys: String, CodingKey {
        case total, completed, pending, processing, failed
        case noTranscript = "no_transcript"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        completed = try container.decodeIfPresent(Int.self, forKey: .completed) ?? 0
        pending = try container.decodeIfPresent(Int.self, forKey: .pending) ?? 0
        processing = try container.decodeIfPresent(Int.self, forKey: .processing) ?? 0
        failed = try container.decodeIfPresent(Int.self, forKey: .failed) ?? 0
        noTranscript = try container.decodeIfPresent(Int.self, forKey: .noTranscript) ?? 0

        total = try container.decodeIfPresent(Int.self, forKey: .total)
            ?? completed + pending + processing + failed + noTranscript
    }
}

/// Workflow stats from `/api/sync/workflows/stats`.
struct WorkflowStats: Codable, Sendable {
    let recentRecordings: Int?
    let withAiSummary: Int?
    let missingAiSummary: Int?
    let readyForEnrichment: Int?
    let workflowPending: Int?
    let workflowFailed: Int?
    let workflowSuccess: Int?
    let lastSubmittedAt: String?
    let activeWorkflows: [JSONValue]?

    enum CodingKeys: String, CodingKey {
        case recentRecordings = "recent_recordings"
        case withAiSummary = "with_ai_summary"
        case missingAiSummary = "missing_ai_summary"
        case readyForEnrichment = "ready_for_enrichment"
        case workflowPending = "workflow_pending"
        case workflowFailed = "workflow_failed"
        case workflowSuccess = "workflow_success"
        case lastSubmittedAt = "last_submitted_at"
        case activeWorkflows = "active_workflows"
    }
}
