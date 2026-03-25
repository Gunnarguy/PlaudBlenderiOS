import SwiftUI

/// Unified data hub — merges Sync and Notion into a single tab with a segmented toggle.
struct DataView: View {
    @Environment(NotionViewModel.self) private var notion

    @State private var section: DataSection = .sync

    var body: some View {
        Group {
            switch section {
            case .sync:
                SyncDashboardView()
            case .notion:
                NotionView()
                    .environment(notion)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Section", selection: $section) {
                ForEach(DataSection.allCases, id: \.self) { s in
                    Label(s.title, systemImage: s.icon).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}

private enum DataSection: String, CaseIterable {
    case sync
    case notion

    var title: String {
        switch self {
        case .sync: "Sync"
        case .notion: "Notion"
        }
    }

    var icon: String {
        switch self {
        case .sync: "arrow.triangle.2.circlepath"
        case .notion: "link"
        }
    }
}
