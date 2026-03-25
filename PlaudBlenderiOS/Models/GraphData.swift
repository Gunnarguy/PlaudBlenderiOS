import Foundation

/// Matches `GraphDataOut` from the FastAPI backend.
struct GraphData: Codable, Sendable {
    let nodes: [[String: JSONValue]]
    let edges: [[String: JSONValue]]
}

/// Parsed graph node for display.
struct GraphNode: Identifiable, Sendable {
    let id: String
    let label: String
    let type: String
    let size: Double
    let color: String?
    let count: Int?

    init(from dict: [String: JSONValue]) {
        self.id = dict["id"]?.stringValue ?? UUID().uuidString
        self.label = dict["label"]?.stringValue ?? "?"
        self.type = dict["type"]?.stringValue ?? "unknown"
        self.size = dict["size"]?.doubleValue ?? 20
        self.color = dict["color"]?.stringValue
        self.count = dict["count"]?.intValue
    }
}

/// Parsed graph edge for display.
struct GraphEdge: Identifiable, Sendable {
    let id: String
    let source: String
    let target: String
    let label: String?
    let weight: Double

    init(from dict: [String: JSONValue]) {
        self.source = dict["source"]?.stringValue ?? ""
        self.target = dict["target"]?.stringValue ?? ""
        self.label = dict["label"]?.stringValue
        self.weight = dict["weight"]?.doubleValue ?? 1.0
        self.id = "\(source)-\(target)"
    }
}
