import SwiftUI

/// Container that owns the RecordingDetailViewModel and loads data.
struct RecordingDetailContainerView: View {
    let recordingId: String
    @Environment(APIClient.self) private var api
    @State private var viewModel: RecordingDetailViewModel?

    var body: some View {
        Group {
            if let viewModel, let detail = viewModel.detail {
                RecordingDetailView(detail: detail, viewModel: viewModel)
            } else if let viewModel, let error = viewModel.error {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Error Loading",
                    message: error,
                    actionTitle: "Retry",
                    action: { Task { await viewModel.loadDetail(recordingId: recordingId) } }
                )
            } else {
                LoadingView(message: "Loading recording...")
            }
        }
        .task {
            let vm = RecordingDetailViewModel(api: api)
            viewModel = vm
            await vm.loadDetail(recordingId: recordingId)
        }
    }
}

// MARK: - Recording Detail

struct RecordingDetailView: View {
    let detail: RecordingDetail
    let viewModel: RecordingDetailViewModel
    @State private var selectedTab = 0
    @State private var isShowingWorkflowSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                headerSection

                if let plaudSummary = detail.summary.plaudAiSummary, !plaudSummary.isEmpty {
                    plaudAISummarySection(plaudSummary)
                }

                // AI Summary
                if let summary = detail.aiSummary, !summary.isEmpty {
                    chronosSummarySection(summary)
                }

                // Category breakdown
                if let pcts = detail.categoryPercentages, !pcts.isEmpty {
                    categoryBar(pcts)
                }

                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Events").tag(0)
                    Text("Transcript").tag(1)
                    Text("Plaud AI").tag(2)
                    if detail.extractedData != nil || detail.workflowStatus != nil {
                        Text("Data").tag(3)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Tab content
                switch selectedTab {
                case 0: eventsTab
                case 1: transcriptTab
                case 2: plaudAITab
                case 3: extractedDataTab
                default: eventsTab
                }
            }
        }
        .navigationTitle(detail.summary.title ?? "Recording")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingWorkflowSheet = true
                } label: {
                    Label("Run AI", systemImage: "wand.and.stars")
                }
            }
        }
        .sheet(isPresented: $isShowingWorkflowSheet) {
            RunWorkflowSheet(recordingId: detail.summary.recordingId, viewModel: viewModel)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let timeRange = detail.summary.timeRangeFormatted {
                    Label(timeRange, systemImage: "clock")
                        .font(.subheadline)
                }
                Spacer()
                CategoryPill(category: detail.summary.topCategory)
            }

            HStack(spacing: 16) {
                Label(
                    detail.summary.durationFormatted ?? "\(detail.summary.durationSeconds)s",
                    systemImage: "timer"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Label("\(detail.events.count) events", systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if detail.summary.timeIsEstimated == true {
                    Label("Estimated", systemImage: "questionmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let reason = detail.summary.timeEstimateReason, !reason.isEmpty {
                    Label(reason, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal)
    }

    private func plaudAISummarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Plaud AI Summary", systemImage: "brain")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(summary)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.pink.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    private func chronosSummarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Chronos Summary", systemImage: "sparkles")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(summary)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.purple.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    private func categoryBar(_ percentages: [String: Double]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                ForEach(percentages.sorted(by: { $0.value > $1.value }), id: \.key) { cat, pct in
                    Rectangle()
                        .fill(Color.forCategory(cat))
                        .frame(height: 6)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(x: pct, anchor: .leading)
                }
            }
            .clipShape(Capsule())

            HStack(spacing: 8) {
                ForEach(percentages.sorted(by: { $0.value > $1.value }).prefix(4), id: \.key) { cat, pct in
                    HStack(spacing: 3) {
                        Circle().fill(Color.forCategory(cat)).frame(width: 6, height: 6)
                        Text("\(cat.capitalized) \(Int(pct * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var eventsTab: some View {
        LazyVStack(spacing: 8) {
            ForEach(detail.events) { event in
                EventCardView(event: event, onCategoryChange: { newCat in
                    Task { _ = await viewModel.overrideCategory(eventId: event.id, newCategory: newCat) }
                })
            }
        }
        .padding(.horizontal)
    }

    private var transcriptTab: some View {
        Group {
            if let transcript = detail.transcript, !transcript.isEmpty {
                Text(transcript)
                    .font(.body)
                    .padding()
            } else {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Transcript",
                    message: "Transcript not available for this recording."
                )
            }
        }
    }

    private var plaudAITab: some View {
        Group {
            if (detail.summary.plaudAiSummary?.isEmpty == false) || (detail.plaudTranscript?.isEmpty == false) {
                VStack(alignment: .leading, spacing: 12) {
                    if let plaudSummary = detail.summary.plaudAiSummary, !plaudSummary.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Plaud AI Summary", systemImage: "brain")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(plaudSummary)
                                .font(.body)
                        }
                    }

                    if let plaudTranscript = detail.plaudTranscript, !plaudTranscript.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Plaud AI Transcript", systemImage: "waveform")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(plaudTranscript)
                                .font(.body)
                        }
                    }
                }
                .padding()
            } else {
                EmptyStateView(
                    icon: "brain",
                    title: "No Plaud AI Data",
                    message: "Tap the wand icon to run a Plaud AI workflow."
                )
            }
        }
    }

    private var extractedDataTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let workflowStatus = detail.workflowStatus, !workflowStatus.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Workflow Status", systemImage: "gearshape.2")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    ForEach(workflowStatus.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(alignment: .top) {
                            Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .leading)
                            Text(value.displayString)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if let extractedData = detail.extractedData, !extractedData.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Extracted Data", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    ForEach(extractedData.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Text(value.displayString)
                                .font(.subheadline)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if detail.extractedData == nil && detail.workflowStatus == nil {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "No Extracted Data",
                    message: "Run a workflow to extract structured data from this recording."
                )
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Run Workflow Sheet

struct RunWorkflowSheet: View {
    let recordingId: String
    let viewModel: RecordingDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedModel = "gemini"
    @State private var selectedTemplate: String? = nil
    @State private var isRunning = false
    @State private var resultMessage: String?

    private let models = ["gemini", "openai"]
    private let templates = [
        ("meeting_notes", "Meeting Notes"),
        ("action_items", "Action Items"),
        ("key_decisions", "Key Decisions"),
        ("executive_summary", "Executive Summary"),
        ("daily_standup", "Daily Standup"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Run a Plaud AI workflow on this recording to generate enhanced analysis.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Model picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Model")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Model", selection: $selectedModel) {
                        ForEach(models, id: \.self) { model in
                            Text(model.capitalized).tag(model)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Template picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Template (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button {
                                selectedTemplate = nil
                            } label: {
                                Text("Default")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(selectedTemplate == nil ? Color.accentPrimary.opacity(0.3) : Color.clear)
                                    .overlay(Capsule().stroke(Color.accentPrimary.opacity(0.5), lineWidth: 1))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            ForEach(templates, id: \.0) { id, label in
                                Button {
                                    selectedTemplate = id
                                } label: {
                                    Text(label)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(selectedTemplate == id ? Color.accentPrimary.opacity(0.3) : Color.clear)
                                        .overlay(Capsule().stroke(Color.accentPrimary.opacity(0.5), lineWidth: 1))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Run button
                Button {
                    isRunning = true
                    Task {
                        let success = await viewModel.runWorkflow(
                            recordingId: recordingId,
                            templateId: selectedTemplate,
                            model: selectedModel
                        )
                        isRunning = false
                        resultMessage = success ? "Workflow submitted" : (viewModel.error ?? "Failed")
                        if success {
                            try? await Task.sleep(nanoseconds: 800_000_000)
                            dismiss()
                        }
                    }
                } label: {
                    if isRunning {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Run Workflow", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)

                if let msg = resultMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(msg == "Workflow submitted" ? .green : .red)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Run Workflow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Event Card

struct EventCardView: View {
    let event: Event
    var onCategoryChange: ((String) -> Void)?
    @State private var showCategoryPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.startTs.iso8601Date?.timeString ?? event.startTs)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                Button { showCategoryPicker.toggle() } label: {
                    CategoryPill(category: event.category)
                }
                .buttonStyle(.plain)

                if let confidence = event.categoryConfidence {
                    ConfidenceBadge(confidence: confidence)
                }
            }

            Text(event.cleanText)
                .font(.subheadline)

            HStack(spacing: 12) {
                if let sentiment = event.sentiment {
                    Label(String(format: "%.1f", sentiment), systemImage: sentimentIcon(sentiment))
                        .font(.caption2)
                        .foregroundStyle(sentimentColor(sentiment))
                }

                if !event.keywords.isEmpty {
                    Text(event.keywords.prefix(3).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(TimeInterval(event.durationSeconds).durationFormatted)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.category.capitalized) event: \(event.cleanText.prefix(80))")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.category.capitalized) event: \(event.cleanText.prefix(80))")
        .confirmationDialog("Change Category", isPresented: $showCategoryPicker) {
            ForEach(EventCategory.allCases, id: \.rawValue) { cat in
                Button(cat.rawValue.capitalized) {
                    onCategoryChange?(cat.rawValue)
                }
            }
        }
    }

    private func sentimentIcon(_ value: Double) -> String {
        switch value {
        case 0.3...: return "face.smiling"
        case -0.3..<0.3: return "face.dashed"
        default: return "face.dashed.fill"
        }
    }

    private func sentimentColor(_ value: Double) -> Color {
        switch value {
        case 0.3...: return .green
        case -0.3..<0.3: return .secondary
        default: return .red
        }
    }
}
