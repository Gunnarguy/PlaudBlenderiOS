import Foundation
import AuthenticationServices
import Observation

@MainActor
@Observable
final class NotionViewModel: NSObject {
    var authStatus: TokenStatus?
    var status: NotionStatus?
    var databases: [NotionDatabase] = []
    var recordings: [NotionRecording] = []
    var importProgress: NotionImportProgress?
    var isLoading = false
    var isLoadingMore = false
    var isAuthorizing = false
    var isImporting = false
    var selectedDatabaseId: String?
    var error: String?
    var lastMessage: String?
    var totalRecordings = 0
    var hasMoreRecordings = false

    private let pageSize = 100

    private let api: APIClient
    @ObservationIgnored private var importMonitorTask: Task<Void, Never>?
    @ObservationIgnored private var stableImportPollCount = 0
    @ObservationIgnored private var lastImportSignature = ""
    /// Anchor for ASWebAuthenticationSession presentation
    @ObservationIgnored private var presentationAnchor: ASPresentationAnchor?

    init(api: APIClient) {
        self.api = api
        super.init()
    }

    deinit {
        importMonitorTask?.cancel()
    }

    var isAuthenticated: Bool {
        authStatus?.isAuthenticated == true
    }

    var workspaceName: String? {
        authStatus?.workspaceName ?? authStatus?.extra?["workspace_name"]?.stringValue
    }

    var hasSelectedDatabase: Bool {
        status?.isConnected == true
    }

    var unmatchedCount: Int {
        recordings.filter { !$0.isImportedToChronos }.count
    }

    var importedCount: Int {
        recordings.filter(\.isImportedToChronos).count
    }

    var shouldShowDatabasePicker: Bool {
        isAuthenticated && !hasSelectedDatabase
    }

    var notionStatusSummary: String {
        if let status, status.isConnected {
            return "\(status.totalPages) page\(status.totalPages == 1 ? "" : "s") in \(status.databaseTitle ?? "selected database")"
        }
        if let workspaceName {
            return workspaceName
        }
        return "Not connected"
    }

    func loadAuthStatus() async {
        do {
            authStatus = try await api.get("/api/auth/notion/status")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadStatus() async {
        do {
            status = try await api.get("/api/notion/status")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadDatabases() async {
        do {
            databases = try await api.get("/api/notion/databases")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func selectDatabase(dbId: String) async -> Bool {
        do {
            selectedDatabaseId = dbId
            let body = NotionDatabaseSelectRequest(dbId: dbId)
            let _: SuccessResponse = try await api.post("/api/notion/databases/select", body: body)
            await loadStatus()
            await loadRecordings()
            lastMessage = "Notion database selected"
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func loadRecordings() async {
        do {
            let response: NotionRecordingsResponse = try await api.get(
                "/api/notion/recordings",
                query: ["limit": "\(pageSize)", "offset": "0"]
            )
            recordings = response.recordings
            totalRecordings = response.total
            hasMoreRecordings = response.hasMore
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadMoreRecordings() async {
        guard !isLoadingMore, hasMoreRecordings else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let response: NotionRecordingsResponse = try await api.get(
                "/api/notion/recordings",
                query: ["limit": "\(pageSize)", "offset": "\(recordings.count)"]
            )
            recordings.append(contentsOf: response.recordings)
            totalRecordings = response.total
            hasMoreRecordings = response.hasMore
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startImport(process: Bool = true, index: Bool = true) async -> Bool {
        Haptics.impact()
        isImporting = true
        do {
            let body = NotionImportRequest(process: process, index: index)
            let response: SuccessResponse = try await api.post("/api/notion/import", body: body)
            lastMessage = response.message
            startImportMonitoring()
            return response.success
        } catch {
            self.error = error.localizedDescription
            isImporting = false
            return false
        }
    }

    func loadImportProgress() async {
        do {
            importProgress = try await api.get("/api/notion/import/progress")
            updateImportingState()
        } catch {
            importProgress = nil
        }
    }

    func loadAll() async {
        isLoading = true
        error = nil
        await loadAuthStatus()
        await loadStatus()
        if shouldShowDatabasePicker {
            await loadDatabases()
        }
        if hasSelectedDatabase {
            await loadRecordings()
            await loadImportProgress()
        }
        isLoading = false
    }

    func startOAuthFlow(anchor: ASPresentationAnchor) async {
        isAuthorizing = true
        error = nil
        defer { isAuthorizing = false }

        do {
            // 1. Get the authorize URL from backend (mobile mode → redirect goes through our callback)
            let response: AuthURLResponse = try await api.get("/api/auth/notion/authorize", query: ["mobile": "true"])
            guard let authURL = URL(string: response.authUrl) else {
                error = "Invalid authorization URL"
                return
            }

            // 2. Open ASWebAuthenticationSession — it catches the plaudblender:// redirect
            presentationAnchor = anchor
            let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                let session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: "plaudblender"
                ) { url, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: URLError(.cancelled))
                    }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                session.start()
            }

            // 3. Parse the callback — the backend already exchanged the code
            let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
            let queryItems = (components?.queryItems ?? []).compactMap { item -> (String, String)? in
                guard let value = item.value else { return nil }
                return (item.name, value)
            }
            let params: [String: String] = Dictionary(uniqueKeysWithValues: queryItems)

            if let callbackError = params["error"] {
                error = "Notion authorization failed: \(callbackError)"
            } else {
                // Success — backend exchanged the token, refresh our status
                lastMessage = "Notion connected!"
                await loadAll()
            }
        } catch let err as ASWebAuthenticationSessionError where err.code == .canceledLogin {
            // User cancelled — not an error
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshAfterAuthorization() async {
        await loadAll()
    }

    private func updateImportingState() {
        let status = importProgress?.status.lowercased() ?? "idle"
        isImporting = status == "running" || status == "paused"
        if isImporting {
            startImportMonitoring()
        } else {
            stopImportMonitoring()
        }
    }

    private func startImportMonitoring() {
        guard importMonitorTask == nil else { return }
        stableImportPollCount = 0
        lastImportSignature = importProgressSignature
        importMonitorTask = Task { [weak self] in
            guard let self else { return }
            await self.monitorImportProgress()
        }
    }

    private func stopImportMonitoring() {
        importMonitorTask?.cancel()
        importMonitorTask = nil
        stableImportPollCount = 0
        lastImportSignature = ""
    }

    private var importProgressSignature: String {
        [
            importProgress?.status ?? "-",
            "\(importProgress?.total ?? -1)",
            "\(importProgress?.completed ?? -1)",
            "\(importProgress?.failed ?? -1)",
            "\(importProgress?.skipped ?? -1)",
            importProgress?.currentTitle ?? "-"
        ].joined(separator: "|")
    }

    private func nextImportPollDelayNanoseconds() -> UInt64 {
        switch stableImportPollCount {
        case 0:
            return 750_000_000
        case 1:
            return 1_500_000_000
        default:
            return 3_000_000_000
        }
    }

    private func monitorImportProgress() async {
        defer { importMonitorTask = nil }

        while !Task.isCancelled {
            await loadImportProgress()

            if isImporting {
                let signature = importProgressSignature
                if signature == lastImportSignature {
                    stableImportPollCount = min(stableImportPollCount + 1, 2)
                } else {
                    stableImportPollCount = 0
                    lastImportSignature = signature
                }

                try? await Task.sleep(nanoseconds: nextImportPollDelayNanoseconds())
            } else {
                await loadRecordings()
                break
            }
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension NotionViewModel: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            if let anchor = presentationAnchor { return anchor }
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first!
            return scene.windows.first ?? UIWindow(windowScene: scene)
        }
    }
}
