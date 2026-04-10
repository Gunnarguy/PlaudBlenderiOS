import Foundation
import Observation

@Observable
final class SettingsViewModel {
    var serverURL: String = ""
    var apiToken: String = ""
    var plaudStatus: TokenStatus?
    var notionAuthStatus: TokenStatus?
    var systemStatus: SystemStatus?
    var isServerReachable = false
    var isCheckingServer = false
    var isLoadingSystemStatus = false
    var error: String?

    private let api: APIClient
    private let authManager: AuthManager

    init(api: APIClient, authManager: AuthManager) {
        self.api = api
        self.authManager = authManager
        self.serverURL = authManager.serverURL
    }

    func checkServer() async {
        isCheckingServer = true
        isServerReachable = await api.healthCheck()
        isCheckingServer = false
    }

    func saveServerURL() {
        do {
            try authManager.setServerURL(serverURL)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func saveToken() {
        guard !apiToken.isEmpty else { return }
        do {
            try authManager.setToken(apiToken)
            apiToken = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    func logout() {
        authManager.logout()
    }

    func loadPlaudStatus() async {
        do {
            plaudStatus = try await api.get("/api/auth/plaud/status")
        } catch {
            plaudStatus = nil
        }
    }

    func loadNotionStatus() async {
        do {
            notionAuthStatus = try await api.get("/api/auth/notion/status")
        } catch {
            notionAuthStatus = nil
        }
    }

    func loadSystemStatus() async {
        isLoadingSystemStatus = true
        do {
            systemStatus = try await api.get("/api/status")
        } catch {
            systemStatus = nil
        }
        isLoadingSystemStatus = false
    }

    func loadAll() async {
        await checkServer()
        await loadPlaudStatus()
        await loadNotionStatus()
        await loadSystemStatus()
    }
}
