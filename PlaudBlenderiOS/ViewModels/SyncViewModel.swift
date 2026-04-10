import Foundation
import Observation

@MainActor
@Observable
final class SyncViewModel {
    var pipelineStatus: PipelineStatus?
    var dbStats: RecordingDbStats?
    var workflowStats: WorkflowStats?
    var uploadCandidates: [UploadCandidate] = []
    var isLoading = false
    var isRunning = false
    var error: String?
    var lastMessage: String?
    var lastUpdated: Date?
    var hasBootstrapped = false
    var showBatchWorkflowSheet = false

    private let api: APIClient
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    @ObservationIgnored private var stablePollCount = 0
    @ObservationIgnored private var lastMonitorSignature = ""

    init(api: APIClient) {
        self.api = api
    }

    deinit {
        monitorTask?.cancel()
    }

    var currentStageTitle: String {
        let stage = pipelineStatus?.currentPhase ?? pipelineStatus?.activePhase?.name ?? pipelineStatus?.status ?? "idle"
        return stage
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    var progressEntries: [(key: String, value: String)] {
        guard let status = pipelineStatus, let activePhase = status.activePhase else {
            return []
        }

        var entries: [(key: String, value: String)] = []

        if activePhase.totalItems > 0 {
            entries.append(("Completed", "\(activePhase.completedItems)/\(activePhase.totalItems)"))
        }

        if !activePhase.currentStep.isEmpty {
            entries.append(("Step", activePhase.currentStep))
        }

        if !activePhase.currentItem.isEmpty {
            entries.append(("Item", activePhase.currentItem))
        }

        if activePhase.elapsedSeconds > 0 {
            entries.append(("Phase Time", TimeInterval(activePhase.elapsedSeconds).durationFormatted))
        }

        if let elapsedSeconds = status.elapsedSeconds, elapsedSeconds > 0 {
            entries.append(("Run Time", TimeInterval(elapsedSeconds).durationFormatted))
        }

        if let trigger = status.trigger, !trigger.isEmpty {
            entries.append(("Trigger", trigger.capitalized))
        }

        return entries
    }

    var globalBannerTitle: String {
        isRunning ? "Pipeline In Progress" : "Sync Idle"
    }

    var globalBannerDetail: String {
        if isRunning {
            if let dbStats {
                return "\(currentStageTitle) · \(dbStats.processing) running · \(dbStats.pending) pending · \(dbStats.completed) done"
            }
            if let lead = progressEntries.first {
                return "\(currentStageTitle) · \(lead.key): \(lead.value)"
            }
            return currentStageTitle
        }

        if let updated = lastUpdated {
            return "Last updated \(updated.relativeString)"
        }

        return lastMessage ?? "No active sync"
    }

    var shouldShowGlobalBanner: Bool {
        isRunning || hasVisibleWorkInProgress
    }

    var hasVisibleWorkInProgress: Bool {
        guard isRunning else { return false }
        return (dbStats?.processing ?? 0) > 0
            || (dbStats?.pending ?? 0) > 0
            || !progressEntries.isEmpty
    }

    func bootstrap() async {
        hasBootstrapped = true
        await loadAll()
    }

    func bootstrapIfNeeded() async {
        guard !hasBootstrapped else { return }
        await bootstrap()
    }

    func loadStatus(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        do {
            let status: PipelineStatus = try await api.get("/api/sync/status")
            pipelineStatus = status
            lastUpdated = Date()
            updateRunningState(from: status)
        } catch {
            self.error = error.localizedDescription
            if showLoading {
                isLoading = false
            }
            stopMonitoring()
            return
        }

        if showLoading {
            isLoading = false
        }
    }

    func loadDbStats() async {
        do {
            dbStats = try await api.get("/api/sync/db-stats")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadWorkflowStats() async {
        do {
            workflowStats = try await api.get("/api/stats/workflows")
        } catch {
            workflowStats = nil
        }
    }

    func runPipeline(stage: String = "full") async {
        Haptics.impact()
        isRunning = true
        error = nil
        lastMessage = "Starting \(stage.replacingOccurrences(of: "_", with: " ")) sync..."
        do {
            let body = PipelineRunRequest(stage: stage)
            let response: PipelineRunResponse = try await api.post("/api/sync/run", body: body)
            lastMessage = response.message
            startMonitoring()
            await loadAll()
        } catch {
            self.error = error.localizedDescription
            isRunning = false
            stopMonitoring()
        }
    }

    func resetStuck() async {
        do {
            let response: SuccessResponse = try await api.post("/api/sync/reset-stuck")
            lastMessage = response.message
            await loadAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func submitWorkflows(daysBack: Int = 7, limit: Int = 3, templateId: String? = nil) async {
        do {
            let body = WorkflowSubmitRequest(
                daysBack: daysBack,
                limit: limit,
                templateId: templateId
            )
            let response: SuccessResponse = try await api.post(
                "/api/sync/workflows/submit",
                body: body
            )
            lastMessage = response.message
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshWorkflows() async {
        do {
            let body = WorkflowRefreshRequest()
            let response: SuccessResponse = try await api.post(
                "/api/sync/workflows/refresh",
                body: body
            )
            lastMessage = response.message
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadUploadCandidates() async {
        do {
            let response: UploadCandidatesResponse = try await api.get("/api/sync/upload-candidates")
            uploadCandidates = response.recordings
        } catch {
            uploadCandidates = []
        }
    }

    func refreshCache() async {
        do {
            let response: SuccessResponse = try await api.post("/api/sync/refresh-cache")
            lastMessage = response.message
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadAll() async {
        isLoading = true
        error = nil
        await loadStatus(showLoading: false)
        await loadDbStats()
        await loadWorkflowStats()
        await loadUploadCandidates()
        isLoading = false
    }

    func refresh() async {
        await loadAll()
    }

    private func updateRunningState(from status: PipelineStatus) {
        let normalizedStatus = status.status.lowercased()
        if ["idle", "completed", "failed"].contains(normalizedStatus) {
            isRunning = false
            stopMonitoring()
            return
        }

        let running = status.running
            || normalizedStatus.contains("running")
            || normalizedStatus.contains("processing")
            || normalizedStatus.contains("queued")
            || status.activePhase?.status.lowercased() == "running"

        isRunning = running

        if running {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        guard monitorTask == nil else { return }
        stablePollCount = 0
        lastMonitorSignature = monitorSignature

        monitorTask = Task { [weak self] in
            guard let self else { return }
            await self.monitorLoop()
        }
    }

    private func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        stablePollCount = 0
        lastMonitorSignature = ""
    }

    private var monitorSignature: String {
        let activePhase = pipelineStatus?.activePhase
        let runId = pipelineStatus?.runId ?? "-"
        let status = pipelineStatus?.status ?? "-"
        let currentPhase = pipelineStatus?.currentPhase ?? "-"
        let activePhaseStatus = activePhase?.status ?? "-"
        let completedItems = String(activePhase?.completedItems ?? -1)
        let currentStep = activePhase?.currentStep ?? "-"
        let currentItem = activePhase?.currentItem ?? "-"
        let pendingCount = String(dbStats?.pending ?? -1)
        let processingCount = String(dbStats?.processing ?? -1)
        let completedCount = String(dbStats?.completed ?? -1)
        let failedCount = String(dbStats?.failed ?? -1)

        let signatureParts = [
            runId,
            status,
            currentPhase,
            activePhaseStatus,
            completedItems,
            currentStep,
            currentItem,
            pendingCount,
            processingCount,
            completedCount,
            failedCount
        ]

        return signatureParts.joined(separator: "|")
    }

    private func nextMonitorDelayNanoseconds() -> UInt64 {
        switch stablePollCount {
        case 0:
            return 750_000_000
        case 1:
            return 1_500_000_000
        case 2:
            return 3_000_000_000
        default:
            return 5_000_000_000
        }
    }

    private func monitorLoop() async {
        defer { monitorTask = nil }

        while !Task.isCancelled {
            await loadStatus(showLoading: false)

            if isRunning {
                await loadDbStats()
            } else {
                break
            }

            let signature = monitorSignature
            if signature == lastMonitorSignature {
                stablePollCount = min(stablePollCount + 1, 3)
            } else {
                stablePollCount = 0
                lastMonitorSignature = signature
            }

            if Task.isCancelled {
                break
            }

            try? await Task.sleep(nanoseconds: nextMonitorDelayNanoseconds())
        }
    }
}
