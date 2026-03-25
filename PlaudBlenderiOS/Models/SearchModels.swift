import Foundation

// MARK: - Search Request / Response

/// Matches `SearchRequest` from the FastAPI backend.
struct SearchRequest: Codable, Sendable {
    let query: String
    var limit: Int = 50
    var categories: [String]?
    var startDate: String?
    var endDate: String?

    enum CodingKeys: String, CodingKey {
        case query, limit, categories
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

/// Matches `SearchResultOut` from the FastAPI backend.
struct SearchResult: Codable, Identifiable, Sendable {
    let event: Event
    let score: Double
    let contextBefore: String?
    let contextAfter: String?

    var id: String { event.id }

    enum CodingKeys: String, CodingKey {
        case event, score
        case contextBefore = "context_before"
        case contextAfter = "context_after"
    }
}

/// Matches `SearchResponse` from the FastAPI backend.
struct SearchResponse: Codable, Sendable {
    let results: [SearchResult]
    let aiAnswer: AIAnswer?
    let total: Int

    enum CodingKeys: String, CodingKey {
        case results
        case aiAnswer = "ai_answer"
        case total
    }
}

/// Matches `AIAnswerOut` from the FastAPI backend.
struct AIAnswer: Codable, Sendable {
    let answer: String
    let model: String
    let responseId: String?
    let usage: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case answer, model
        case responseId = "response_id"
        case usage
    }
}

/// Matches `AskRequest` from the FastAPI backend.
struct AskRequest: Codable, Sendable {
    let question: String
    var reasoning: String?
}
