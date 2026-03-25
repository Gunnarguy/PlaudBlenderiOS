import SwiftUI
import WebKit

/// Knowledge graph rendered via WKWebView with Cytoscape.js.
struct GraphContainerView: View {
    let viewModel: GraphViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Layout picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.availableLayouts, id: \.self) { layout in
                            Button {
                                viewModel.selectedLayout = layout
                                Task { await viewModel.loadGraph(layout: layout) }
                            } label: {
                                Text(layout.capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(viewModel.selectedLayout == layout ? Color.accentPrimary.opacity(0.2) : Color.clear)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.accentPrimary.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }

                // Graph content
                if viewModel.isLoading {
                    LoadingView(message: "Building knowledge graph...")
                } else if viewModel.nodes.isEmpty {
                    EmptyStateView(
                        icon: "point.3.connected.trianglepath.dotted",
                        title: "No Graph Data",
                        message: "Run the pipeline with --graph to build the knowledge graph.",
                        actionTitle: "Refresh",
                        action: { Task { await viewModel.refresh() } }
                    )
                } else {
                    graphWebView
                }
            }
            .navigationTitle("Knowledge Graph")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Text("\(viewModel.nodes.count) nodes")
                        Text("·")
                        Text("\(viewModel.edges.count) edges")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .task { await viewModel.loadGraph() }
        }
    }

    private var graphWebView: some View {
        CytoscapeWebView(
            nodes: viewModel.nodes,
            edges: viewModel.edges,
            layout: viewModel.selectedLayout
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Cytoscape WKWebView

struct CytoscapeWebView: UIViewRepresentable {
    let nodes: [GraphNode]
    let edges: [GraphEdge]
    let layout: String

    class Coordinator {
        var lastNodeCount = 0
        var lastEdgeCount = 0
        var lastLayout = ""
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only reload if data actually changed
        let c = context.coordinator
        guard nodes.count != c.lastNodeCount || edges.count != c.lastEdgeCount || layout != c.lastLayout else {
            return
        }
        c.lastNodeCount = nodes.count
        c.lastEdgeCount = edges.count
        c.lastLayout = layout

        let html = buildCytoscapeHTML()
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func buildCytoscapeHTML() -> String {
        let nodesJSON = nodes.map { node in
            """
            { data: { id: "\(escapeJS(node.id))", label: "\(escapeJS(node.label))", type: "\(escapeJS(node.type))", size: \(node.size) } }
            """
        }.joined(separator: ",\n")

        let edgesJSON = edges.map { edge in
            """
            { data: { source: "\(escapeJS(edge.source))", target: "\(escapeJS(edge.target))", label: "\(escapeJS(edge.label ?? ""))", weight: \(edge.weight) } }
            """
        }.joined(separator: ",\n")

        return """
        <!DOCTYPE html>
        <html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <script src="https://unpkg.com/cytoscape@3.28.1/dist/cytoscape.min.js"></script>
        <style>body{margin:0;background:transparent}#cy{width:100%;height:100vh}</style>
        </head><body>
        <div id="cy"></div>
        <script>
        const cy = cytoscape({
            container: document.getElementById('cy'),
            elements: {
                nodes: [\(nodesJSON)],
                edges: [\(edgesJSON)]
            },
            style: [
                { selector: 'node', style: {
                    'label': 'data(label)',
                    'background-color': '#0969da',
                    'width': 'data(size)', 'height': 'data(size)',
                    'font-size': '10px', 'color': '#e6edf3',
                    'text-outline-color': '#0d1117', 'text-outline-width': 1
                }},
                { selector: 'edge', style: {
                    'width': 'data(weight)',
                    'line-color': '#30363d',
                    'curve-style': 'bezier',
                    'opacity': 0.6
                }}
            ],
            layout: { name: '\(layout)', animate: true, animationDuration: 500 }
        });
        </script>
        </body></html>
        """
    }

    private func escapeJS(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
    }
}
