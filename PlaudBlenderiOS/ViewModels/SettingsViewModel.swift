import Foundation
import Observation

@Observable
final class SettingsViewModel {
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
}
