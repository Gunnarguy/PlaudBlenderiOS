//
//  ContentView.swift
//  PlaudBlenderiOS
//
//  Created by Gunnar Hostetler on 3/21/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(APIClient.self) private var api
    @Environment(AuthManager.self) private var authManager
    @Environment(NotionViewModel.self) private var notion
    @Environment(SyncViewModel.self) private var sync
    @Environment(XRayViewModel.self) private var xray
    @State private var selectedTab: AppTab = .timeline
    @State private var loadedTabs: Set<AppTab> = [.timeline]
    @State private var hasAutoFocusedRunningPipeline = false
    @AppStorage("tabCustomization") private var tabCustomization: TabViewCustomization

    // Plain class (not @Observable) so SwiftUI doesn't track internal mutations —
    // safe to populate during body evaluation without "modifying state during view update".
    @State private var vmCache = ViewModelCache()

    var body: some View {
        TabView(selection: $selectedTab) {
            TabSection("Core") {
                Tab("Timeline", systemImage: "calendar.day.timeline.leading", value: AppTab.timeline) {
                    tabContent(for: .timeline)
                }
                .customizationID("nav.timeline")

                Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
                    tabContent(for: .search)
                }
                .customizationID("nav.search")
            }
            .customizationID("section.core")

            TabSection("Analysis") {
                Tab("Stats", systemImage: "chart.bar.xaxis", value: AppTab.stats) {
                    tabContent(for: .stats)
                }
                .customizationID("nav.stats")

                Tab("Graph", systemImage: "point.3.connected.trianglepath.dotted", value: AppTab.graph) {
                    tabContent(for: .graph)
                }
                .customizationID("nav.graph")
            }
            .customizationID("section.analysis")

            TabSection("Manage") {
                Tab("Data", systemImage: "arrow.triangle.2.circlepath", value: AppTab.data) {
                    tabContent(for: .data)
                }
                .badge(dataTabBadge.map(Text.init))
                .customizationID("nav.data")

                Tab("Settings", systemImage: "gear", value: AppTab.settings) {
                    tabContent(for: .settings)
                }
                .badge(settingsTabBadge.map(Text.init))
                .customizationID("nav.settings")
            }
            .customizationID("section.manage")
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($tabCustomization)
        .onChange(of: selectedTab) { _, newValue in
            loadedTabs.insert(newValue)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !api.isServerReachable {
                ConnectionBanner(api: api)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 4)
                    .padding(.bottom, 4)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomStatusStack
        }
        .animation(.easeInOut(duration: 0.3), value: api.isServerReachable)
        .animation(.easeInOut(duration: 0.3), value: sync.shouldShowGlobalBanner)
        .onAppear {
            autoFocusRunningPipelineIfNeeded()
        }
        .onChange(of: sync.isRunning) { _, newValue in
            autoFocusRunningPipelineIfNeeded()
            xray.isPipelineActive = newValue
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        if loadedTabs.contains(tab) {
            switch tab {
            case .timeline:
                TimelineView(viewModel: vmCache.timeline(api: api))
            case .search:
                SearchView(viewModel: vmCache.search(api: api))
            case .stats:
                StatsView(viewModel: vmCache.stats(api: api))
            case .graph:
                GraphContainerView(viewModel: vmCache.graph(api: api))
            case .data:
                DataView()
            case .settings:
                SettingsView(viewModel: vmCache.settings(api: api, auth: authManager))
            }
        } else {
            Color.clear
        }
    }

    private func autoFocusRunningPipelineIfNeeded() {
        guard !hasAutoFocusedRunningPipeline, sync.hasVisibleWorkInProgress else {
            return
        }

        hasAutoFocusedRunningPipeline = true
        loadedTabs.insert(.data)
        selectedTab = .data
    }



    @ViewBuilder
    private var bottomStatusStack: some View {
        if sync.shouldShowGlobalBanner && selectedTab != .data {
            SyncActivityBanner(sync: sync) {
                loadedTabs.insert(.data)
                selectedTab = .data
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var dataTabBadge: String? {
        // Sync badge takes priority
        if sync.isRunning {
            let pending = sync.dbStats?.pending ?? 0
            if pending > 0 { return "\(pending)" }
            return "!"
        }
        // Notion badge
        if notion.isImporting {
            let pending = notion.importProgress?.pending ?? 0
            if pending > 0 { return "\(pending)" }
            return "!"
        }
        if notion.unmatchedCount > 0 {
            return "\(notion.unmatchedCount)"
        }
        return nil
    }

    private var settingsTabBadge: String? {
        guard xray.isLiveUpdating, selectedTab != .settings else { return nil }
        let count = xray.activityHighlights.count
        return count > 0 ? "\(count)" : nil
    }

}

private enum AppTab: String, Hashable {
    case timeline
    case search
    case stats
    case graph
    case data
    case settings
}

/// Plain class (NOT @Observable) that caches view models.
/// Because SwiftUI doesn't observe its internals, mutating properties here
/// during body evaluation is safe — no "modifying state during view update" crash.
private final class ViewModelCache {
    private var _timeline: TimelineViewModel?
    private var _search: SearchViewModel?
    private var _stats: StatsViewModel?
    private var _graph: GraphViewModel?
    private var _settings: SettingsViewModel?

    func timeline(api: APIClient) -> TimelineViewModel {
        if let vm = _timeline { return vm }
        let vm = TimelineViewModel(api: api)
        _timeline = vm
        return vm
    }

    func search(api: APIClient) -> SearchViewModel {
        if let vm = _search { return vm }
        let vm = SearchViewModel(api: api)
        _search = vm
        return vm
    }

    func stats(api: APIClient) -> StatsViewModel {
        if let vm = _stats { return vm }
        let vm = StatsViewModel(api: api)
        _stats = vm
        return vm
    }

    func graph(api: APIClient) -> GraphViewModel {
        if let vm = _graph { return vm }
        let vm = GraphViewModel(api: api)
        _graph = vm
        return vm
    }

    func settings(api: APIClient, auth: AuthManager) -> SettingsViewModel {
        if let vm = _settings { return vm }
        let vm = SettingsViewModel(api: api, authManager: auth)
        _settings = vm
        return vm
    }
}

struct SyncActivityBanner: View {
    let sync: SyncViewModel
    let onOpen: () -> Void

    @State private var isExpanded = false

    var body: some View {
        Button(action: {
            if isExpanded {
                onOpen()
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded = true
                }
                // Auto-collapse after 4 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(isExpanded ? .body : .title3)
                    .symbolEffect(.rotate, options: .repeating, value: sync.isRunning)
                    .foregroundStyle(.green)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(sync.globalBannerTitle)
                            .font(.caption.bold())
                        Text(sync.globalBannerDetail)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, isExpanded ? 12 : 0)
            .padding(.vertical, 8)
            .frame(width: isExpanded ? nil : 44, height: 44)
            .background(.ultraThinMaterial)
            .background(Color.green.opacity(0.12))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 16)
        .padding(.bottom, 4)
    }
}

/// Persistent banner shown when the API server is unreachable.
struct ConnectionBanner: View {
    let api: APIClient
    @State private var isRetrying = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .font(.subheadline.bold())
            VStack(alignment: .leading, spacing: 2) {
                Text("Server Unreachable")
                    .font(.subheadline.bold())
                Text(api.lastError ?? "Cannot connect to \(api.authManager.serverURL)")
                    .font(.caption2)
                    .lineLimit(1)
            }
            Spacer()
            if isRetrying {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Retry") {
                    isRetrying = true
                    Task {
                        _ = await api.healthCheck()
                        isRetrying = false
                    }
                }
                .font(.caption.bold())
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .background(Color.red.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 4)
    }
}

#Preview {
    let authManager = AuthManager()
    let apiClient = APIClient(authManager: authManager)
    ContentView()
        .environment(apiClient)
        .environment(authManager)
        .environment(NotionViewModel(api: apiClient))
        .environment(SyncViewModel(api: apiClient))
        .environment(XRayViewModel(api: apiClient))
}
