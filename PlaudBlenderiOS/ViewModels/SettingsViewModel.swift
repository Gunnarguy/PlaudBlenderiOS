import Foundation
import AuthenticationServices
import Observation
import UIKit

@MainActor
@Observable
final class SettingsViewModel: NSObject {
    var serverURL: String = ""
    var apiToken: String = ""
    var plaudStatus: TokenStatus?
    var notionAuthStatus: TokenStatus?
    var systemStatus: SystemStatus?
    var processingProvider = ""
    var cleaningModel = ""
    var analystModel = ""
    var embeddingModel = ""
    var openAIModel = ""
    var thinkingLevel = ""
    var openAITemperature = ""
    var embeddingDim = ""
    var plaudLanguage = ""
    var plaudDiarization = true
    var logLevel = ""
    var customCategories = ""
    var notionWeekdayStart = ""
    var notionWeekendStart = ""
    var qdrantURL = ""
    var qdrantCollectionName = ""
    var serverConfigMessage: String?
    var isLoadingServerConfig = false
    var isSavingServerConfig = false
    var hasGeminiAPIKey = false
    var hasOpenAIAPIKey = false
    var hasQdrantAPIKey = false
    var hasNotionToken = false
    var hasNotionOAuth = false
    var isServerReachable = false
    var isCheckingServer = false
    var isLoadingSystemStatus = false
    var isAuthorizingPlaud = false
    var error: String?

    private let api: APIClient
    private let authManager: AuthManager

    init(api: APIClient, authManager: AuthManager) {
        self.api = api
        self.authManager = authManager
        self.serverURL = authManager.serverURL
        super.init()
    }

    func checkServer() async {
        isCheckingServer = true
        isServerReachable = await api.healthCheck()
        isCheckingServer = false
    }

    func saveServerURL() {
        do {
            try authManager.setServerURL(serverURL)
            serverURL = authManager.serverURL
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

    func startPlaudOAuthFlow(anchor _: ASPresentationAnchor) async {
        isAuthorizingPlaud = true
        error = nil
        defer { isAuthorizingPlaud = false }

        do {
            let response: AuthURLResponse = try await api.get(
                "/api/auth/plaud/authorize",
                query: ["return_to": try plaudServerReturnURL().absoluteString]
            )
            guard let authURL = URL(string: response.authUrl) else {
                error = "Invalid Plaud authorization URL"
                return
            }
            if let redirectURL = plaudRedirectURL(from: authURL),
               isLocalhostCallback(redirectURL) {
                error = """
                Plaud auth is misconfigured on the server. It is still using a desktop localhost callback: \(redirectURL.absoluteString).
                Update the Pi backend to use the public API callback flow.
                """
                return
            }
            let opened = await openInSafari(authURL)
            if !opened {
                error = "Could not open Plaud authorization in Safari"
                return
            }
            error = "Finish Plaud sign-in in Safari. The Raspberry Pi will store the Plaud token and this screen will refresh when you return."
            await waitForPlaudAuthorization()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshAfterPlaudAuthorization() async {
        await loadPlaudStatus()
        await loadSystemStatus()
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

    func loadServerSettings() async {
        isLoadingServerConfig = true
        do {
            let settings: ServerSettings = try await api.get("/api/settings")
            processingProvider = settings.processingProvider
            cleaningModel = settings.cleaningModel
            analystModel = settings.analystModel
            embeddingModel = settings.embeddingModel
            openAIModel = settings.openAIModel
            thinkingLevel = settings.thinkingLevel
            openAITemperature = String(settings.openAITemperature)
            embeddingDim = String(settings.embeddingDim)
            plaudLanguage = settings.plaudLanguage
            plaudDiarization = settings.plaudDiarization
            logLevel = settings.logLevel
            customCategories = settings.customCategories
            notionWeekdayStart = settings.notionWeekdayStart
            notionWeekendStart = settings.notionWeekendStart
            qdrantURL = settings.qdrantURL
            qdrantCollectionName = settings.qdrantCollectionName
            hasGeminiAPIKey = settings.flags.hasGeminiAPIKey
            hasOpenAIAPIKey = settings.flags.hasOpenAIAPIKey
            hasQdrantAPIKey = settings.flags.hasQdrantAPIKey
            hasNotionToken = settings.flags.hasNotionToken
            hasNotionOAuth = settings.flags.hasNotionOAuth
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingServerConfig = false
    }

    func saveServerSettings() async {
        guard let openAITemperatureValue = Double(openAITemperature) else {
            error = "OpenAI temperature must be a number"
            return
        }
        guard let embeddingDimValue = Int(embeddingDim) else {
            error = "Embedding dimension must be a whole number"
            return
        }

        isSavingServerConfig = true
        error = nil
        serverConfigMessage = nil

        do {
            let body = ServerSettingsUpdateRequest(
                processingProvider: processingProvider,
                cleaningModel: cleaningModel,
                analystModel: analystModel,
                embeddingModel: embeddingModel,
                openAIModel: openAIModel,
                thinkingLevel: thinkingLevel,
                openAITemperature: openAITemperatureValue,
                embeddingDim: embeddingDimValue,
                plaudLanguage: plaudLanguage,
                plaudDiarization: plaudDiarization,
                logLevel: logLevel,
                customCategories: customCategories,
                notionWeekdayStart: notionWeekdayStart,
                notionWeekendStart: notionWeekendStart,
                qdrantURL: qdrantURL,
                qdrantCollectionName: qdrantCollectionName
            )
            let response: SuccessResponse = try await api.put("/api/settings", body: body)
            serverConfigMessage = response.message
            await loadServerSettings()
        } catch {
            self.error = error.localizedDescription
        }

        isSavingServerConfig = false
    }

    func loadAll() async {
        await checkServer()
        await loadPlaudStatus()
        await loadNotionStatus()
        await loadSystemStatus()
        await loadServerSettings()
    }

    private func plaudRedirectURL(from authURL: URL) -> URL? {
        guard let components = URLComponents(url: authURL, resolvingAgainstBaseURL: false),
              let redirectValue = components.queryItems?.first(where: { $0.name == "redirect_uri" })?.value
        else {
            return nil
        }

        return URL(string: redirectValue)
    }

    private func isLocalhostCallback(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1"
    }

    private func plaudServerReturnURL() throws -> URL {
        guard let base = URL(string: api.resolvedServerURL) else {
            throw APIError.invalidURL(api.resolvedServerURL)
        }
        return base.appendingPathComponent("api/v1/auth/plaud/status")
    }

    private func waitForPlaudAuthorization() async {
        for _ in 0..<45 {
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }

            await loadPlaudStatus()
            if plaudStatus?.isAuthenticated == true {
                error = nil
                await loadSystemStatus()
                return
            }
        }
    }

    private func openInSafari(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { opened in
                continuation.resume(returning: opened)
            }
        }
    }
}
