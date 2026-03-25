import SwiftUI

struct SearchView: View {
    @Bindable var viewModel: SearchViewModel
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isAskFocused: Bool
    @State private var askQuestion = ""
    @State private var isShowingAskSheet = false
    @State private var isShowingDateFilter = false
    @State private var selectedReasoning: String? = nil

    private let reasoningLevels = ["low", "medium", "high"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Filter chips + date filter
                filterSection

                // Date range indicator
                if viewModel.startDate != nil || viewModel.endDate != nil {
                    dateRangeIndicator
                }

                // Results
                if viewModel.isSearching {
                    LoadingView(message: "Searching...")
                } else if viewModel.results.isEmpty && !viewModel.query.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Results",
                        message: "Try different search terms or adjust filters."
                    )
                } else if viewModel.results.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "Search Your Timeline",
                        message: "Semantic search across all your recordings and events."
                    )
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAskSheet = true
                    } label: {
                        Label("Ask Chronos", systemImage: "brain")
                    }
                }
            }
            .sheet(isPresented: $isShowingAskSheet) {
                AskChronosSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $isShowingDateFilter) {
                DateFilterSheet(
                    startDate: $viewModel.startDate,
                    endDate: $viewModel.endDate,
                    onApply: {
                        isShowingDateFilter = false
                        if !viewModel.query.isEmpty {
                            Task { await viewModel.search() }
                        }
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search recordings...", text: $viewModel.query)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit { Task { await viewModel.search() } }
            if !viewModel.query.isEmpty {
                Button { viewModel.clear() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
    }

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Date filter button
                Button { isShowingDateFilter = true } label: {
                    let hasDate = viewModel.startDate != nil || viewModel.endDate != nil
                    Label("Dates", systemImage: "calendar")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(hasDate ? Color.accentPrimary.opacity(0.3) : Color.clear)
                        .overlay(Capsule().stroke(Color.accentPrimary, lineWidth: 1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                ForEach(EventCategory.allCases, id: \.rawValue) { cat in
                    let isSelected = viewModel.selectedCategories.contains(cat.rawValue)
                    Button {
                        if isSelected {
                            viewModel.selectedCategories.remove(cat.rawValue)
                        } else {
                            viewModel.selectedCategories.insert(cat.rawValue)
                        }
                    } label: {
                        Text(cat.rawValue.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isSelected ? Color.forCategory(cat.rawValue).opacity(0.3) : Color.clear)
                            .overlay(Capsule().stroke(Color.forCategory(cat.rawValue), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private var dateRangeIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.caption2)
            if let start = viewModel.startDate {
                Text(start.shortDateString)
                    .font(.caption2)
            }
            if viewModel.startDate != nil && viewModel.endDate != nil {
                Text("–")
                    .font(.caption2)
            }
            if let end = viewModel.endDate {
                Text(end.shortDateString)
                    .font(.caption2)
            }
            Spacer()
            Button {
                viewModel.startDate = nil
                viewModel.endDate = nil
                if !viewModel.query.isEmpty {
                    Task { await viewModel.search() }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                // AI Answer
                if let answer = viewModel.aiAnswer {
                    AIAnswerCardView(answer: answer)
                }

                Text("\(viewModel.total) results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                ForEach(viewModel.results) { result in
                    SearchResultCardView(result: result)
                }
            }
            .padding()
        }
    }
}

// MARK: - Ask Chronos Sheet

struct AskChronosSheet: View {
    let viewModel: SearchViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var reasoning: String? = nil
    @FocusState private var isFocused: Bool

    private let reasoningLevels = ["low", "medium", "high"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Question input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ask anything about your recordings, events, or personal timeline.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("e.g. What did I work on last Tuesday?", text: $question, axis: .vertical)
                        .lineLimit(2...6)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .focused($isFocused)
                }

                // Reasoning level picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reasoning Depth")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Button {
                            reasoning = nil
                        } label: {
                            Text("Auto")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(reasoning == nil ? Color.accentPrimary.opacity(0.3) : Color.clear)
                                .overlay(Capsule().stroke(Color.accentPrimary.opacity(0.5), lineWidth: 1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        ForEach(reasoningLevels, id: \.self) { level in
                            Button {
                                reasoning = level
                            } label: {
                                Text(level.capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(reasoning == level ? Color.accentPrimary.opacity(0.3) : Color.clear)
                                    .overlay(Capsule().stroke(Color.accentPrimary.opacity(0.5), lineWidth: 1))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Submit
                Button {
                    let q = question
                    let r = reasoning
                    Task {
                        await viewModel.askAI(question: q, reasoning: r)
                        dismiss()
                    }
                } label: {
                    if viewModel.isAskingAI {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Ask Chronos", systemImage: "brain")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isAskingAI)

                // Previous answer
                if let answer = viewModel.aiAnswer {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Last Answer", systemImage: "brain")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.purple)
                        Text(answer.answer)
                            .font(.subheadline)
                        Text(answer.model)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.purple.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Ask Chronos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { isFocused = true }
        }
    }
}

// MARK: - Date Filter Sheet

struct DateFilterSheet: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    let onApply: () -> Void

    @State private var localStart: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var localEnd: Date = Date()
    @State private var hasStartDate = false
    @State private var hasEndDate = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Start Date", isOn: $hasStartDate)
                    if hasStartDate {
                        DatePicker("From", selection: $localStart, displayedComponents: .date)
                    }
                }
                Section {
                    Toggle("End Date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("To", selection: $localEnd, displayedComponents: .date)
                    }
                }
                Section {
                    HStack {
                        Button("Last 7 Days") {
                            hasStartDate = true
                            hasEndDate = true
                            localStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                            localEnd = Date()
                        }
                        .font(.caption)
                        Spacer()
                        Button("Last 30 Days") {
                            hasStartDate = true
                            hasEndDate = true
                            localStart = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                            localEnd = Date()
                        }
                        .font(.caption)
                        Spacer()
                        Button("Clear") {
                            hasStartDate = false
                            hasEndDate = false
                        }
                        .font(.caption)
                    }
                }
            }
            .navigationTitle("Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        startDate = hasStartDate ? localStart : nil
                        endDate = hasEndDate ? localEnd : nil
                        onApply()
                    }
                }
            }
            .onAppear {
                if let s = startDate {
                    localStart = s
                    hasStartDate = true
                }
                if let e = endDate {
                    localEnd = e
                    hasEndDate = true
                }
            }
        }
    }
}

// MARK: - AI Answer Card

struct AIAnswerCardView: View {
    let answer: AIAnswer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI Answer", systemImage: "brain")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.purple)

            Text(answer.answer)
                .font(.subheadline)

            HStack {
                Text(answer.model)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(.purple.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Search Result Card

struct SearchResultCardView: View {
    let result: SearchResult

    var body: some View {
        NavigationLink(value: result.event.recordingId) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    CategoryPill(category: result.event.category)
                    Spacer()
                    Text(String(format: "%.0f%%", result.score * 100))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text(result.event.cleanText)
                    .font(.subheadline)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                HStack {
                    Text(result.event.startTs.iso8601Date?.shortDateString ?? result.event.startTs)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if !result.event.keywords.isEmpty {
                        Text("· " + result.event.keywords.prefix(3).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
