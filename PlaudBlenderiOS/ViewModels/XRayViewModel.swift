import Foundation
import Observation

@MainActor
@Observable
final class XRayViewModel {
    var events: [XRayEvent] = []
    var throughputBuckets: [Int] = []
    var latestSeq: Int = 0
    var selectedSource: String?
    var isLoading = false
    var isLiveUpdating = false
    var hasBootstrapped = false
    var error: String?
    var isPipelineActive = false
    let sessionStartTime = Date()

    private let api: APIClient
    @ObservationIgnored private var liveTask: Task<Void, Never>?
    @ObservationIgnored private let initialHistoryLimit = 250
    @ObservationIgnored private let maxEventCount = 800
    @ObservationIgnored private var quietPollCount = 0
    @ObservationIgnored private var livePollIteration = 0

    let sources = [
        "ingest", "gemini", "embed", "qdrant", "graph",
        "search", "data", "nav", "pipeline", "detail", "day", "sync"
    ]

    init(api: APIClient) {
        self.api = api
    }

    var filteredEvents: [XRayEvent] {
        guard let source = selectedSource else { return events }
        return events.filter { $0.source == source }
    }

    var syncEvents: [XRayEvent] {
        events.filter { event in
            ["pipeline", "ingest", "gemini", "embed", "qdrant", "sync", "data"].contains(event.source)
                || event.op.localizedCaseInsensitiveContains("notion")
        }
    }

    var notionEvents: [XRayEvent] {
        events.filter { event in
            event.op.localizedCaseInsensitiveContains("notion")
                || event.message.localizedCaseInsensitiveContains("notion")
                || event.detail?.localizedCaseInsensitiveContains("notion") == true
        }
    }

    var activityHighlights: [XRayEvent] {
        Array(
            events
                .filter { event in
                    ["pipeline", "ingest", "gemini", "embed", "qdrant", "sync", "data"].contains(event.source)
                        || event.op.localizedCaseInsensitiveContains("notion")
                        || event.message.localizedCaseInsensitiveContains("notion")
                }
                .prefix(8)
        )
    }

    var latestActivity: XRayEvent? {
        activityHighlights.first
    }

    var peakThroughput: Int {
        throughputBuckets.max() ?? 0
    }

    func timelineEvents(for recordingToken: String?, limit: Int = 8) -> [XRayEvent] {
        let trimmedToken = recordingToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let relevantEvents = syncEvents.filter { event in
            guard !trimmedToken.isEmpty else { return true }
            return event.detail?.localizedCaseInsensitiveContains(trimmedToken) == true
                || event.message.localizedCaseInsensitiveContains(trimmedToken)
        }

        if !relevantEvents.isEmpty {
            return Array(relevantEvents.prefix(limit))
        }

        return Array(syncEvents.prefix(limit))
    }

    deinit {
        liveTask?.cancel()
    }

    func loadEvents(sinceSeq: Int? = nil, limit: Int = 100) async {
        if sinceSeq == nil {
            isLoading = true
            error = nil
        }
        do {
            var query = ["limit": "\(limit)"]
            if let sinceSeq { query["since_seq"] = "\(sinceSeq)" }
            let response: XRayEventsResponse = try await api.get("/api/xray/events", query: query)
            if sinceSeq != nil {
                let newEvents = response.events.filter { event in
                    !events.contains(where: { $0.seq == event.seq })
                }
                events.insert(contentsOf: newEvents, at: 0)
            } else {
                events = response.events
            }
            if events.count > maxEventCount {
                events = Array(events.prefix(maxEventCount))
            }
            latestSeq = response.latestSeq
        } catch {
            self.error = error.localizedDescription
        }
        if sinceSeq == nil {
            isLoading = false
        }
    }

    func bootstrapIfNeeded() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        await loadEvents(limit: initialHistoryLimit)
        await loadThroughput()
        startLiveUpdates()
    }

    func startLiveUpdates() {
        guard liveTask == nil else { return }
        isLiveUpdating = true
        quietPollCount = 0
        liveTask = Task { [weak self] in
            guard let self else { return }
            await self.liveLoop()
        }
    }

    func stopLiveUpdates() {
        liveTask?.cancel()
        liveTask = nil
        isLiveUpdating = false
    }

    func refresh() async {
        await loadEvents()
        await loadThroughput()
    }

    func loadThroughput() async {
        do {
            let response: XRayThroughput = try await api.get("/api/xray/throughput", query: ["buckets": "24"])
            throughputBuckets = response.buckets
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadIncrementalEvents(limit: Int = 80) async -> Int {
        do {
            let previousLatestSeq = latestSeq
            let query = [
                "limit": "\(limit)",
                "since_seq": "\(latestSeq)"
            ]
            let response: XRayEventsResponse = try await api.get("/api/xray/events", query: query)

            let newEvents = response.events.filter { event in
                !events.contains(where: { $0.seq == event.seq })
            }

            if !newEvents.isEmpty {
                events.insert(contentsOf: newEvents, at: 0)
                if events.count > maxEventCount {
                    events = Array(events.prefix(maxEventCount))
                }
            }

            latestSeq = max(previousLatestSeq, response.latestSeq)
            return newEvents.count
        } catch {
            self.error = error.localizedDescription
            return 0
        }
    }

    private func nextLivePollDelayNanoseconds() -> UInt64 {
        if isPipelineActive {
            switch quietPollCount {
            case 0: return 300_000_000
            case 1: return 500_000_000
            default: return 1_000_000_000
            }
        }
        switch quietPollCount {
        case 0:
            return 500_000_000
        case 1:
            return 1_000_000_000
        case 2:
            return 2_000_000_000
        default:
            return 4_000_000_000
        }
    }

    private func liveLoop() async {
        defer {
            liveTask = nil
            isLiveUpdating = false
        }

        while !Task.isCancelled {
            livePollIteration += 1
            let newEventCount = await loadIncrementalEvents(limit: 80)

            if newEventCount > 0 || livePollIteration % 4 == 0 {
                await loadThroughput()
            }

            if newEventCount > 0 {
                quietPollCount = 0
            } else {
                quietPollCount = min(quietPollCount + 1, 3)
            }

            if Task.isCancelled {
                break
            }

            try? await Task.sleep(nanoseconds: nextLivePollDelayNanoseconds())
        }
    }
}
