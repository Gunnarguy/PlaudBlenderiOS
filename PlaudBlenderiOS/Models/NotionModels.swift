import Foundation

/// Notion connection status.
struct NotionStatus: Decodable, Sendable {
    let isConnected: Bool
    let databaseId: String?
    let databaseTitle: String?
    let totalPages: Int
    let error: String?

    enum CodingKeys: String, CodingKey {
        case isConnected = "is_connected"
        case databaseId = "database_id"
        case databaseTitle = "database_title"
        case databaseName = "database_name"
        case totalPages = "total_pages"
        case pageCount = "page_count"
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isConnected = try container.decodeIfPresent(Bool.self, forKey: .isConnected) ?? false
        databaseId = try container.decodeIfPresent(String.self, forKey: .databaseId)
        databaseTitle = try container.decodeIfPresent(String.self, forKey: .databaseTitle)
            ?? container.decodeIfPresent(String.self, forKey: .databaseName)
        totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages)
            ?? container.decodeIfPresent(Int.self, forKey: .pageCount)
            ?? 0
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
}

/// A Notion database available for selection.
struct NotionDatabase: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let pageCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, title
        case pageCount = "page_count"
    }
}

/// Notion database select request.
struct NotionDatabaseSelectRequest: Codable, Sendable {
    let dbId: String

    enum CodingKeys: String, CodingKey {
        case dbId = "db_id"
    }
}

/// A Notion recording page.
struct NotionRecording: Codable, Identifiable, Sendable {
    let pageId: String
    let title: String
    let createdTime: String?
    let lastEditedTime: String?
    let url: String?
    let transcript: String?
    let summary: String?
    let date: String?
    let duration: String?
    let tags: [String]?
    let category: String?
    let matchedRecordingId: String?

    var id: String { pageId }

    var isImportedToChronos: Bool {
        matchedRecordingId != nil
    }

    enum CodingKeys: String, CodingKey {
        case pageId = "page_id"
        case title
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case url
        case transcript, summary, date, duration, tags, category
        case matchedRecordingId = "matched_recording_id"
    }
}

/// Paginated response wrapper for Notion recordings.
struct NotionRecordingsResponse: Decodable, Sendable {
    let recordings: [NotionRecording]
    let total: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case recordings, total
        case hasMore = "has_more"
    }
}

/// Import request body.
struct NotionImportRequest: Codable, Sendable {
    var process: Bool = true
    var index: Bool = true
}

/// Import progress from `/api/notion/import/progress`.
struct NotionImportProgress: Decodable, Sendable {
    let status: String
    let total: Int
    let completed: Int
    let failed: Int
    let skipped: Int
    let currentTitle: String?
    let errors: [String]

    var imported: Int { completed }

    var pending: Int {
        max(0, total - completed - failed - skipped)
    }

    enum CodingKeys: String, CodingKey {
        case status, total, completed, failed, skipped, errors
        case currentTitle = "current_title"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "idle"
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
        completed = try container.decodeIfPresent(Int.self, forKey: .completed)
            ?? container.decodeIfPresent(Int.self, forKey: .skipped)
            ?? 0
        failed = try container.decodeIfPresent(Int.self, forKey: .failed) ?? 0
        skipped = try container.decodeIfPresent(Int.self, forKey: .skipped) ?? 0
        currentTitle = try container.decodeIfPresent(String.self, forKey: .currentTitle)
        errors = try container.decodeIfPresent([String].self, forKey: .errors) ?? []
    }
}

/// Coverage calendar entry.
struct NotionCoverageDay: Codable, Identifiable, Sendable {
    let date: String
    let hasChronos: Bool
    let hasNotion: Bool

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date
        case hasChronos = "has_chronos"
        case hasNotion = "has_notion"
    }
}
