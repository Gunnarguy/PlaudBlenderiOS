import Foundation

/// Session cost from `/api/costs/session`.
struct SessionCost: Codable, Sendable {
    let totalCostUsd: Double
    let totalCalls: Int
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let byModel: [String: JSONValue]
    let byType: [String: JSONValue]
    let sessionMinutes: Double

    enum CodingKeys: String, CodingKey {
        case totalCostUsd = "total_cost_usd"
        case totalCalls = "total_calls"
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
        case byModel = "by_model"
        case byType = "by_type"
        case sessionMinutes = "session_minutes"
    }
}

/// Cost history from `/api/costs/history`.
struct CostHistory: Codable, Sendable {
    let days: Int
    let totalCostUsd: Double
    let totalCalls: Int
    let byModel: [String: JSONValue]
    let byDay: [[String: JSONValue]]?

    enum CodingKeys: String, CodingKey {
        case days
        case totalCostUsd = "total_cost_usd"
        case totalCalls = "total_calls"
        case byModel = "by_model"
        case byDay = "by_day"
    }
}

/// Model pricing table from `/api/costs/pricing`.
struct ModelPricing: Codable, Sendable {
    let models: [[String: JSONValue]]
}
