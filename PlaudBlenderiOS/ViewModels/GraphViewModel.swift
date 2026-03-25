import Foundation
import Observation

@Observable
final class GraphViewModel {
    var graphData: GraphData?
    var nodes: [GraphNode] = []
    var edges: [GraphEdge] = []
    var isLoading = false
    var error: String?
    var selectedLayout = "cose"

    let availableLayouts = ["cose", "dagre", "circle", "grid", "concentric", "breadthfirst"]

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func loadGraph(layout: String? = nil) async {
        isLoading = true
        error = nil
        do {
            var query: [String: String] = [:]
            if let layout { query["layout"] = layout }
            let data: GraphData = try await api.get("/api/graph", query: query)
            graphData = data
            nodes = data.nodes.map { GraphNode(from: $0) }
            edges = data.edges.map { GraphEdge(from: $0) }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        await loadGraph(layout: selectedLayout)
    }
}
