import SwiftUI

struct SyncDashboardView: View {
    @Environment(SyncViewModel.self) private var viewModel
    @Environment(XRayViewModel.self) private var xray
    @State private var showConsole = false
    @State private var consoleAutoScroll = true
    @State private var consoleEventLimit = 30
    @State private var showPhaseDetail = false
    @State private var selectedStage: PipelineStage = .full
    @State private var showBatchWorkflowSheet = false
    @State private var batchDaysBack = 7
    @State private var batchLimit = 5
    @State private var batchTemplateId = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // 1. Hero — status + actions + inline stats
                    heroCard

                    // 2. Phase stepper — compact progress tracker
                    if let status = viewModel.pipelineStatus, !status.phases.isEmpty {
                        phaseStepperCard(status)
                    }

                    // 3. Live console — terminal event stream
                    consoleCard

                    // 4. Stats — recordings + workflows unified
                    statsCard

                    // 5. Upload candidates
                    if !viewModel.uploadCandidates.isEmpty {
                        uploadCandidatesCard
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Sync")
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.bootstrapIfNeeded() }
            .task { await xray.bootstrapIfNeeded() }
            .sheet(isPresented: $showBatchWorkflowSheet) {
                batchWorkflowSheet
            }
        }
    }

    // MARK: - 1. Hero Card

    private var heroCard: some View {
        VStack(spacing: 12) {
            // Error / message banner (inline, not a separate card)
            if let error = viewModel.error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error).font(.caption).lineLimit(2)
                    Spacer()
                }
                .padding(10)
                .background(.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let msg = viewModel.lastMessage, viewModel.error == nil {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green).font(.caption)
                    Text(msg).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
            }

            // Main status row
            HStack(alignment: .center, spacing: 12) {
                // Left: status icon + labels
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        if viewModel.isRunning {
                            PulsingDot()
                        } else {
                            Image(systemName: idleStatusIcon)
                                .font(.caption)
                                .foregroundStyle(idleStatusColor)
                        }
                        Text(viewModel.isRunning ? "Running" : idleStatusLabel)
                            .font(.headline)
                    }

                    if viewModel.isRunning {
                        Text(viewModel.currentStageTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if let status = viewModel.pipelineStatus {
                        // Idle subtitle — last run info
                        VStack(alignment: .leading, spacing: 2) {
                            if let elapsed = status.elapsedSeconds {
                                Text("Last run took \(TimeInterval(elapsed).durationFormatted)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let updated = viewModel.lastUpdated {
                                Text(updated.relativeString)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } else if let updated = viewModel.lastUpdated {
                        Text(updated.relativeString)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Right: elapsed time when running, or completed count when idle
                if viewModel.isRunning,
                   let elapsed = viewModel.pipelineStatus?.elapsedSeconds {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TimeInterval(elapsed).durationFormatted)
                            .font(.title2.weight(.semibold).monospacedDigit())
                        Text("elapsed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else if !viewModel.isRunning, let db = viewModel.dbStats {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(db.completed)")
                            .font(.title2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.green)
                        Text("synced")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Inline DB counters (always visible)
            if let db = viewModel.dbStats {
                HStack(spacing: 0) {
                    counterChip("\(db.completed)", "done", .green)
                    counterChip("\(db.processing)", "running", .blue)
                    counterChip("\(db.pending)", "queued", .yellow)
                    counterChip("\(db.failed)", "failed", .red)
                }
            }

            // Stuck warning (inline)
            if !viewModel.isRunning, let db = viewModel.dbStats, db.processing > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.caption)
                    Text("\(db.processing) stuck — pipeline finished but these didn't complete")
                        .font(.caption)
                    Spacer()
                    Button("Fix") { Task { await viewModel.resetStuck() } }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .controlSize(.small)
                }
                .padding(8)
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Action buttons
            HStack(spacing: 10) {
                Button {
                    Task { await viewModel.runPipeline(stage: selectedStage.rawValue) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isRunning ? "hourglass" : selectedStage.icon)
                        Text(viewModel.isRunning ? "Syncing…" : selectedStage.displayName)
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(viewModel.isRunning)

                // Stage picker
                Menu {
                    ForEach(PipelineStage.allCases) { stage in
                        Button {
                            selectedStage = stage
                        } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(stage.displayName)
                                    Text(stage.description)
                                        .font(.caption2)
                                }
                            } icon: {
                                Image(systemName: stage.icon)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down.circle")
                        .font(.title3)
                }
                .buttonStyle(.bordered)

                Menu {
                    Button { Task { await viewModel.resetStuck() } } label: {
                        Label("Reset Stuck", systemImage: "arrow.counterclockwise")
                    }
                    Button { Task { await viewModel.refreshWorkflows() } } label: {
                        Label("Refresh Workflows", systemImage: "arrow.clockwise")
                    }
                    Button { Task { await viewModel.refreshCache() } } label: {
                        Label("Refresh Cache", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Divider()
                    Button { showBatchWorkflowSheet = true } label: {
                        Label("Batch Workflows", systemImage: "brain")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var idleStatusIcon: String {
        let status = viewModel.pipelineStatus?.status.lowercased() ?? "idle"
        switch status {
        case "completed": return "checkmark.circle.fill"
        case "failed": return "xmark.circle.fill"
        default: return "circle.fill"
        }
    }

    private var idleStatusColor: Color {
        let status = viewModel.pipelineStatus?.status.lowercased() ?? "idle"
        switch status {
        case "completed": return .green
        case "failed": return .red
        default: return viewModel.pipelineStatus != nil ? .green : .secondary
        }
    }

    private var idleStatusLabel: String {
        let status = viewModel.pipelineStatus?.status.lowercased() ?? "idle"
        switch status {
        case "completed": return "Completed"
        case "failed": return "Failed"
        default: return "Idle"
        }
    }

    private func counterChip(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - 2. Phase Stepper

    private func phaseStepperCard(_ status: PipelineStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Compact phase pills — always shown
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(status.phases) { phase in
                        phasePill(phase)
                    }
                }
                .padding(.horizontal)
            }

            // Expandable detail
            if showPhaseDetail {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(status.phases) { phase in
                        phaseDetailRow(phase)
                    }

                    // Progress entries (run metadata)
                    if !viewModel.progressEntries.isEmpty {
                        Divider()
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(viewModel.progressEntries, id: \.key) { entry in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.key).font(.caption2).foregroundStyle(.secondary)
                                    Text(entry.value).font(.caption.weight(.semibold)).monospacedDigit().lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    // Server run metadata
                    if let trigger = status.trigger {
                        HStack(spacing: 16) {
                            metaLabel("Trigger", trigger.capitalized)
                            if let runId = status.runId {
                                metaLabel("Run", String(runId.prefix(8)))
                            }
                            if let elapsed = status.elapsedSeconds {
                                metaLabel("Total", TimeInterval(elapsed).durationFormatted)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Toggle detail
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showPhaseDetail.toggle() }
            } label: {
                HStack {
                    Spacer()
                    Text(showPhaseDetail ? "Less" : "Details")
                        .font(.caption2.weight(.medium))
                    Image(systemName: showPhaseDetail ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func phasePill(_ phase: PipelinePhase) -> some View {
        let isActive = phase.status.lowercased() == "running"
        return HStack(spacing: 4) {
            Image(systemName: phaseIcon(for: phase.status))
                .font(.caption2)
                .foregroundStyle(phaseColor(for: phase.status))
            Text(phase.name.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.caption2.weight(isActive ? .bold : .regular))
            if isActive {
                PulsingDot()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? phaseColor(for: phase.status).opacity(0.12) : Color.clear)
        .background(.thinMaterial)
        .clipShape(Capsule())
    }

    private func phaseDetailRow(_ phase: PipelinePhase) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: phaseIcon(for: phase.status))
                    .foregroundStyle(phaseColor(for: phase.status))
                    .font(.caption)

                Text(phase.name.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption.weight(.semibold))

                Spacer()

                if phase.totalItems > 0 {
                    Text("\(phase.completedItems)/\(phase.totalItems)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if phase.elapsedSeconds > 0 {
                    Text(TimeInterval(phase.elapsedSeconds).durationFormatted)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(phase.status.capitalized)
                    .font(.caption2)
                    .foregroundStyle(phaseColor(for: phase.status))
            }

            if phase.totalItems > 0 {
                if phase.status.lowercased() == "running" && phase.completedItems == 0 {
                    ProgressView()
                        .tint(phaseColor(for: phase.status))
                } else {
                    ProgressView(
                        value: Double(phase.completedItems),
                        total: max(Double(phase.totalItems), 1)
                    )
                    .tint(phaseColor(for: phase.status))
                }
            }

            if !phase.currentStep.isEmpty {
                Text(phase.currentStep)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !phase.error.isEmpty {
                Text(phase.error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            if !phase.summary.isEmpty {
                Text(phase.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func metaLabel(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.tertiary)
            Text(value).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
        }
    }

    // MARK: - 3. Live Console

    private var consoleCard: some View {
        let consoleEvents = Array(xray.events.prefix(consoleEventLimit))
        let isActive = viewModel.isRunning

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showConsole.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .foregroundStyle(isActive ? .green : .secondary)

                    Text("Console")
                        .font(.subheadline.weight(.semibold))

                    if isActive { PulsingDot() }

                    Spacer()

                    if !xray.events.isEmpty {
                        Text("\(xray.events.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: showConsole ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if showConsole {
                // Toolbar
                HStack(spacing: 10) {
                    Toggle(isOn: $consoleAutoScroll) {
                        Label("Auto-scroll", systemImage: "arrow.down.to.line")
                            .font(.caption2)
                    }
                    .toggleStyle(.button)
                    .controlSize(.mini)

                    Spacer()

                    Picker("Limit", selection: $consoleEventLimit) {
                        Text("30").tag(30)
                        Text("60").tag(60)
                        Text("All").tag(200)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

                // Terminal output
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(consoleEvents.reversed().enumerated()), id: \.element.id) { index, event in
                                consoleRow(event, index: index)
                                    .id(event.id)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                    }
                    .frame(height: 240)
                    .background(.black.opacity(0.88))
                    .onChange(of: xray.events.first?.seq) { _, _ in
                        if consoleAutoScroll, let latest = consoleEvents.first {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(latest.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Summary bar
                if isActive, let db = viewModel.dbStats {
                    HStack(spacing: 14) {
                        inlineStat(.blue, "\(db.processing) run")
                        inlineStat(.yellow, "\(db.pending) queued")
                        inlineStat(.green, "\(db.completed) done")
                        Spacer()
                        if let elapsed = viewModel.pipelineStatus?.elapsedSeconds {
                            Text(TimeInterval(elapsed).durationFormatted)
                                .monospacedDigit()
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .onAppear {
            if viewModel.isRunning { showConsole = true }
        }
    }

    private func consoleRow(_ event: XRayEvent, index: Int) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Text(event.date.timeString)
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 50, alignment: .leading)

            Text(event.source.uppercased())
                .foregroundStyle(sourceColor(event.source))
                .fontWeight(.bold)
                .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.message)
                    .foregroundStyle(event.level == "error" ? .red : .white.opacity(0.88))
                    .lineLimit(2)

                if let detail = event.detail, !detail.isEmpty {
                    Text(detail.prefix(100))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 2)

            if let ms = event.durationMs {
                Text(formattedDuration(ms))
                    .foregroundStyle(durationColor(ms))
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .font(.caption2.monospaced())
        .padding(.vertical, 2)
        .background(index % 2 == 0 ? Color.white.opacity(0.03) : Color.clear)
    }

    private func inlineStat(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text)
        }
    }

    // MARK: - 4. Stats Card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Recordings
            if let db = viewModel.dbStats {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Recordings", systemImage: "cylinder")
                        .font(.subheadline.weight(.semibold))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                        miniStat("\(db.total)", "total")
                        miniStat("\(db.completed)", "done", .green)
                        miniStat("\(db.pending)", "pending", .yellow)
                        miniStat("\(db.processing)", "running", .blue)
                        miniStat("\(db.failed)", "failed", .red)
                        miniStat("\(db.noTranscript)", "no transcript", .orange)
                    }
                }
            }

            // Workflows
            if let wf = viewModel.workflowStats {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Label("Plaud AI Workflows", systemImage: "brain")
                        .font(.subheadline.weight(.semibold))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                        miniStat("\(wf.recentRecordings ?? 0)", "recordings")
                        miniStat("\(wf.workflowSuccess ?? 0)", "done", .green)
                        miniStat("\(wf.workflowPending ?? 0)", "pending", .yellow)
                        miniStat("\(wf.workflowFailed ?? 0)", "failed", .red)
                        miniStat("\(wf.withAiSummary ?? 0)", "summaries", .purple)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func miniStat(_ value: String, _ label: String, _ color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    // MARK: - 5. Upload Candidates

    private var uploadCandidatesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Upload Candidates", systemImage: "icloud.and.arrow.up")
                .font(.subheadline.weight(.semibold))

            Text("\(viewModel.uploadCandidates.count) recording\(viewModel.uploadCandidates.count == 1 ? "" : "s") eligible for Plaud cloud upload")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(viewModel.uploadCandidates.prefix(10)) { candidate in
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.title ?? candidate.recordingId)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        if let dur = candidate.durationSeconds {
                            Text(TimeInterval(dur).durationFormatted)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let status = candidate.status {
                        Text(status)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            if viewModel.uploadCandidates.count > 10 {
                Text("+ \(viewModel.uploadCandidates.count - 10) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Batch Workflow Sheet

    private var batchWorkflowSheet: some View {
        NavigationStack {
            Form {
                Section("Parameters") {
                    Stepper("Days Back: \(batchDaysBack)", value: $batchDaysBack, in: 1...90)
                    Stepper("Limit: \(batchLimit)", value: $batchLimit, in: 1...50)
                    TextField("Template ID (optional)", text: $batchTemplateId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Button {
                        Task {
                            await viewModel.submitWorkflows(
                                daysBack: batchDaysBack,
                                limit: batchLimit,
                                templateId: batchTemplateId.isEmpty ? nil : batchTemplateId
                            )
                            showBatchWorkflowSheet = false
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Submit Batch", systemImage: "brain")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Batch Workflows")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showBatchWorkflowSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Shared Helpers

    private func sourceColor(_ source: String) -> Color {
        switch source {
        case "pipeline": return .cyan
        case "ingest": return .green
        case "gemini": return .yellow
        case "embed": return .purple
        case "qdrant": return .orange
        case "sync": return .blue
        case "data": return .mint
        case "graph": return .indigo
        default: return .white.opacity(0.5)
        }
    }

    private func phaseIcon(for status: String) -> String {
        switch status.lowercased() {
        case "running": return "arrow.triangle.2.circlepath.circle.fill"
        case "completed": return "checkmark.circle.fill"
        case "failed": return "xmark.circle.fill"
        default: return "circle"
        }
    }

    private func phaseColor(for status: String) -> Color {
        switch status.lowercased() {
        case "running": return .green
        case "completed": return .blue
        case "failed": return .red
        default: return .secondary
        }
    }

    private func formattedDuration(_ ms: Double) -> String {
        if ms < 1000 { return String(format: "%.0fms", ms) }
        if ms < 60000 { return String(format: "%.1fs", ms / 1000) }
        return String(format: "%.0fm", ms / 60000)
    }

    private func durationColor(_ ms: Double) -> Color {
        switch ms {
        case ..<500: return .green
        case ..<3000: return .yellow
        case ..<10000: return .orange
        default: return .red
        }
    }
}

// MARK: - Pulsing Dot

private struct PulsingDot: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(.green)
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating ? 1.3 : 1.0)
            .opacity(isAnimating ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}
