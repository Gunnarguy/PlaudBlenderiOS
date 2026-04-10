import SwiftUI

struct NotionView: View {
    @Environment(NotionViewModel.self) private var viewModel
    @Environment(XRayViewModel.self) private var xray
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.authStatus == nil && viewModel.status == nil {
                    LoadingView(message: "Checking Notion...")
                } else if !viewModel.isAuthenticated {
                    disconnectedView
                } else if viewModel.shouldShowDatabasePicker {
                    databaseSelectionView
                } else if let status = viewModel.status, status.isConnected {
                    connectedView(status)
                } else {
                    disconnectedView
                }
            }
            .navigationTitle("Notion")
            .refreshable { await viewModel.loadAll() }
            .task { await viewModel.loadAll() }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await viewModel.refreshAfterAuthorization() }
            }
        }
    }

    private var disconnectedView: some View {
        VStack(spacing: 18) {
            EmptyStateView(
                icon: "link.badge.plus",
                title: "Connect Notion",
                message: "Authorize Notion, choose the database you want Chronos to watch, then import unmatched pages."
            )

            VStack(spacing: 10) {
                Button {
                    startOAuthFlow()
                } label: {
                    Label(viewModel.isAuthorizing ? "Authorizing..." : "Connect Notion", systemImage: "person.badge.key")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isAuthorizing)
            }
            .padding(.horizontal)

            if let error = viewModel.error {
                ErrorBanner(message: error)
            }
        }
    }

    private var databaseSelectionView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let error = viewModel.error {
                    ErrorBanner(message: error)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Workspace", systemImage: "building.columns")
                        .font(.headline)
                    Text(viewModel.workspaceName ?? "Authenticated with Notion")
                        .font(.subheadline)
                    Text(viewModel.authModeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Pick the database Chronos should sync from. This is the step that actually connects Notion content into the app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        startOAuthFlow()
                    } label: {
                        Label(viewModel.usesOAuth ? "Reconnect OAuth" : "Connect with OAuth", systemImage: "person.badge.key")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isAuthorizing)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Available Databases")
                            .font(.headline)
                        Spacer()
                        Button("Refresh") {
                            Task { await viewModel.loadDatabases() }
                        }
                        .font(.caption)
                    }

                    if viewModel.databases.isEmpty {
                        Text("No accessible databases found yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(viewModel.databases) { database in
                        Button {
                            Task { _ = await viewModel.selectDatabase(dbId: database.id) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(database.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(database.id)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    if let pageCount = database.pageCount {
                                        Text("\(pageCount) pages")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if viewModel.selectedDatabaseId == database.id {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(12)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private func connectedView(_ status: NotionStatus) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                if let error = viewModel.error {
                    ErrorBanner(message: error)
                }

                // Connection info
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading) {
                        Text("Connected")
                            .font(.headline)
                        Text(viewModel.authModeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let db = status.databaseTitle {
                            Text(db)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let workspace = viewModel.workspaceName {
                            Text(workspace)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("\(status.totalPages) pages")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            startOAuthFlow()
                        } label: {
                            Text(viewModel.usesOAuth ? "Reconnect OAuth" : "Connect OAuth")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(viewModel.isAuthorizing)
                    }
                }
                .padding()
                .background(.green.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

                HStack(spacing: 12) {
                    statCard(title: "Ready", value: "\(viewModel.unmatchedCount)", color: .orange)
                    statCard(title: "Imported", value: "\(viewModel.importedCount)", color: .green)
                    statCard(title: "Total", value: "\(status.totalPages)")
                }
                .padding(.horizontal)

                notionSnapshotSection(status)
                    .padding(.horizontal)

                // Coverage calendar
                if let coverage = viewModel.coverage, let calendar = coverage.calendar, !calendar.isEmpty {
                    coverageCalendarSection(coverage)
                }

                // Import section
                VStack(alignment: .leading, spacing: 8) {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .font(.headline)
                    Button {
                        Task { _ = await viewModel.startImport() }
                    } label: {
                        Label(viewModel.isImporting ? "Import Running" : "Import Unmatched Pages", systemImage: viewModel.isImporting ? "hourglass" : "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isImporting)

                    Text("The backend currently imports unmatched pages in batch. If you only have one unmatched entry, this effectively behaves like a one-item sync.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let progress = viewModel.importProgress {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(progress.status.capitalized)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(progress.imported)/\(progress.total)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(value: progress.total > 0 ? Double(progress.imported) / Double(progress.total) : 0)

                            if let currentTitle = progress.currentTitle {
                                Text("Current: \(currentTitle)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            HStack {
                                Text("Pending \(progress.pending)")
                                Spacer()
                                Text("Skipped \(progress.skipped)")
                                Spacer()
                                Text("Failed \(progress.failed)")
                                    .foregroundStyle(progress.failed > 0 ? .red : .secondary)
                            }
                            .font(.caption)

                            if let firstError = progress.errors.first {
                                Text(firstError)
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                if !xray.notionEvents.isEmpty {
                    notionLiveFeedSection
                }

                // Recordings list
                if !viewModel.recordings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Notion Pages")
                                .font(.headline)
                            Spacer()
                            Text("\(viewModel.recordings.count) of \(viewModel.totalRecordings)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        ForEach(viewModel.recordings) { rec in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(rec.title)
                                            .font(.subheadline.weight(.semibold))
                                        if let date = rec.date ?? rec.createdTime {
                                            Text(date)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    pageStatusBadge(for: rec)
                                }

                                if let summary = rec.summary, !summary.isEmpty {
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                HStack(spacing: 10) {
                                    if let category = rec.category {
                                        CategoryPill(category: category)
                                    }
                                    if let duration = rec.duration {
                                        Text(duration)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let urlString = rec.url, let url = URL(string: urlString) {
                                        Spacer()
                                        Link(destination: url) {
                                            Label("Open", systemImage: "arrow.up.right.square")
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                            .padding(10)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onAppear {
                                if rec.id == viewModel.recordings.last?.id {
                                    Task { await viewModel.loadMoreRecordings() }
                                }
                            }
                        }
                        if viewModel.isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private func coverageCalendarSection(_ coverage: NotionCoverageResponse) -> some View {
        let days = coverage.calendar ?? []

        return VStack(alignment: .leading, spacing: 10) {
            Label("Coverage Calendar", systemImage: "calendar")
                .font(.headline)

            HStack(spacing: 16) {
                if let cn = coverage.totalChronos {
                    VStack {
                        Text("\(cn)").font(.title3.bold()).monospacedDigit()
                        Text("Chronos").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if let nn = coverage.totalNotion {
                    VStack {
                        Text("\(nn)").font(.title3.bold()).monospacedDigit()
                        Text("Notion").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            // Legend
            HStack(spacing: 12) {
                legendDot(.green, "Both")
                legendDot(.blue, "Chronos only")
                legendDot(.orange, "Notion only")
                legendDot(.secondary.opacity(0.2), "Neither")
            }
            .font(.caption2)

            // Calendar grid (last 30 days, 7 cols)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(days.suffix(35), id: \.date) { day in
                    let color: Color = {
                        if day.hasChronos && day.hasNotion { return .green }
                        if day.hasChronos { return .blue }
                        if day.hasNotion { return .orange }
                        return .secondary.opacity(0.15)
                    }()
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(height: 16)
                        .overlay {
                            Text(String(day.date.suffix(2)))
                                .font(.system(size: 7))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    private func startOAuthFlow() {
        Task {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
                  let window = scene.windows.first else { return }
            await viewModel.startOAuthFlow(anchor: window)
        }
    }

    private func statCard(title: String, value: String, color: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func pageStatusBadge(for recording: NotionRecording) -> some View {
        Group {
            if recording.isImportedToChronos {
                Label("Imported", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("Ready", systemImage: "arrow.down.circle")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
    }

    private func notionSnapshotSection(_ status: NotionStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Server Snapshot")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                statCard(title: "Workspace", value: viewModel.workspaceName ?? "Unknown")
                statCard(title: "Database", value: status.databaseTitle ?? "Selected")
                statCard(title: "Ready To Import", value: "\(viewModel.unmatchedCount)", color: .orange)
                statCard(title: "Import State", value: viewModel.isImporting ? "Running" : "Idle", color: viewModel.isImporting ? .green : .primary)
            }
        }
    }

    private var notionLiveFeedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Live Notion Feed", systemImage: "bolt.horizontal.circle")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(xray.isLiveUpdating ? .green : .secondary)
                    .frame(width: 8, height: 8)
                Text(xray.isLiveUpdating ? "Live" : "Paused")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("Includes recent Notion-related activity pulled from server history, even from before the app was opened.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Array(xray.notionEvents.prefix(6))) { event in
                HStack(alignment: .top, spacing: 10) {
                    Text(event.source.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 54, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.message)
                            .font(.caption)
                            .lineLimit(2)
                        HStack(spacing: 8) {
                            Text(event.op)
                            Spacer()
                            Text(event.date.timeString)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}
