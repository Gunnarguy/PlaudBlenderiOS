import SwiftUI

struct SettingsView: View {
    @Environment(NotionViewModel.self) private var notion
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                // Server connection
                Section("Server") {
                    TextField("Server URL", text: $viewModel.serverURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { viewModel.saveServerURL() }

                    HStack {
                        Image(systemName: viewModel.isServerReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(viewModel.isServerReachable ? .green : .red)
                        Text(viewModel.isServerReachable ? "Connected" : "Unreachable")
                            .font(.subheadline)
                        Spacer()
                        if viewModel.isCheckingServer {
                            ProgressView()
                        } else {
                            Button("Test") { Task { await viewModel.checkServer() } }
                                .font(.caption)
                        }
                    }

                    Button("Save URL") { viewModel.saveServerURL() }
                }

                // Authentication
                Section("Authentication") {
                    SecureField("API Token", text: $viewModel.apiToken)
                        .textContentType(.password)

                    Button("Save Token") { viewModel.saveToken() }
                        .disabled(viewModel.apiToken.isEmpty)
                }

                if let error = viewModel.error, !error.isEmpty {
                    Section("Last Error") {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }

                // Plaud auth status
                Section("Plaud Connection") {
                    if let status = viewModel.plaudStatus {
                        HStack {
                            Image(systemName: status.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(status.isAuthenticated ? .green : .red)
                            Text(status.isAuthenticated ? "Authenticated" : "Not Connected")
                        }
                        if status.hasAccessToken, !status.isAuthenticated {
                            Text("Access token exists, but the current Plaud session is not authenticated.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let expires = status.expiresAt {
                            Text("Expires: \(expires)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Connect opens Plaud in Safari. The Raspberry Pi completes the token exchange and stores the Plaud tokens on the server.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            startPlaudOAuth()
                        } label: {
                            Label(status.isAuthenticated ? "Reconnect Plaud" : "Connect Plaud", systemImage: "mic.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isAuthorizingPlaud)
                    } else {
                        Text("Status unknown")
                            .foregroundStyle(.secondary)
                        Text("Connect opens Plaud in Safari. The Raspberry Pi completes the token exchange and stores the Plaud tokens on the server.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            startPlaudOAuth()
                        } label: {
                            Label("Connect Plaud", systemImage: "mic.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isAuthorizingPlaud)
                    }
                }

                // Notion auth status
                Section("Notion Connection") {
                    if let status = viewModel.notionAuthStatus {
                        HStack {
                            Image(systemName: status.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(status.isAuthenticated ? .green : .red)
                            Text(status.isAuthenticated ? "Connected" : "Not Connected")
                        }
                        if let authMode = status.extra?["auth_mode"]?.stringValue {
                            Text(authMode == "integration_token" ? "Using server integration token" : "Connected via OAuth")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let ws = status.workspaceName {
                            Text("Workspace: \(ws)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            startNotionOAuth()
                        } label: {
                            Label(notion.usesOAuth ? "Reconnect OAuth" : "Connect with OAuth", systemImage: "person.badge.key")
                        }
                        .buttonStyle(.bordered)
                        .disabled(notion.isAuthorizing)
                    } else {
                        Text("Status unknown")
                            .foregroundStyle(.secondary)

                        Button {
                            startNotionOAuth()
                        } label: {
                            Label("Connect with OAuth", systemImage: "person.badge.key")
                        }
                        .buttonStyle(.bordered)
                        .disabled(notion.isAuthorizing)
                    }
                }

                // System health — deep connectivity check (unified bar)
                Section("System Health") {
                    ServiceStatusBar(
                        systemStatus: viewModel.systemStatus,
                        isLoading: viewModel.isLoadingSystemStatus
                    ) {
                        await viewModel.loadSystemStatus()
                    }
                }

                Section("Server Config") {
                    if viewModel.isLoadingServerConfig {
                        HStack {
                            ProgressView()
                            Text("Loading server settings…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("These values write directly to the Chronos server .env.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Models") {
                    configField("Processing Provider", text: $viewModel.processingProvider)
                    configField("Cleaning Model", text: $viewModel.cleaningModel)
                    configField("Analyst Model", text: $viewModel.analystModel)
                    configField("Embedding Model", text: $viewModel.embeddingModel)
                    configField("OpenAI Model", text: $viewModel.openAIModel)
                    configField("Thinking Level", text: $viewModel.thinkingLevel)
                }

                Section("Runtime") {
                    configField("OpenAI Temperature", text: $viewModel.openAITemperature, keyboard: .decimalPad)
                    configField("Embedding Dimension", text: $viewModel.embeddingDim, keyboard: .numberPad)
                    configField("Plaud Language", text: $viewModel.plaudLanguage)
                    Toggle("Plaud Diarization", isOn: $viewModel.plaudDiarization)
                    configField("Log Level", text: $viewModel.logLevel)
                }

                Section("Categories And Notion") {
                    configField("Custom Categories", text: $viewModel.customCategories)
                    configField("Weekday Start", text: $viewModel.notionWeekdayStart)
                    configField("Weekend Start", text: $viewModel.notionWeekendStart)
                }

                Section("Vector DB") {
                    // Live status inline
                    if let qdrant = viewModel.systemStatus?.qdrant {
                        HStack(spacing: 6) {
                            Image(systemName: qdrant.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(qdrant.ok ? .green : .red)
                                .font(.caption)
                            Text(qdrant.ok ? "Connected" : "Not connected")
                                .font(.caption.weight(.medium))
                            if let c = qdrant.collections {
                                Text("· \(c) collection\(c == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let error = qdrant.error {
                                Text(error)
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                                    .lineLimit(1)
                            }
                        }
                    }
                    configField("Qdrant URL", text: $viewModel.qdrantURL, keyboard: .URL)
                    configField("Collection", text: $viewModel.qdrantCollectionName)
                }

                Section("Credential Status") {
                    credentialRow("Gemini API Key", present: viewModel.hasGeminiAPIKey)
                    credentialRow("OpenAI API Key", present: viewModel.hasOpenAIAPIKey)

                    // Qdrant API key is optional for local instances — show connection status too
                    HStack {
                        Image(systemName: qdrantEffectiveStatus ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(qdrantEffectiveStatus ? .green : .red)
                        Text("Qdrant")
                        Spacer()
                        if viewModel.systemStatus?.qdrant?.ok == true {
                            Text("Connected")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else if viewModel.hasQdrantAPIKey {
                            Text("Key present · Not connected")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else {
                            Text("No API key (ok for local)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    credentialRow("Notion Token", present: viewModel.hasNotionToken)
                    credentialRow("Notion OAuth", present: viewModel.hasNotionOAuth)
                }

                Section("Save Server Config") {
                    Button {
                        Task { await viewModel.saveServerSettings() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isSavingServerConfig {
                                ProgressView()
                            } else {
                                Label("Save To Server", systemImage: "externaldrive.badge.checkmark")
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isSavingServerConfig || viewModel.isLoadingServerConfig)

                    if let serverConfigMessage = viewModel.serverConfigMessage {
                        Text(serverConfigMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundStyle(.secondary)
                    }
                }

                // Developer tools
                Section("Developer") {
                    NavigationLink {
                        XRayView()
                    } label: {
                        Label("Server Activity", systemImage: "dot.radiowaves.left.and.right")
                    }
                }

                // Danger zone
                Section("Account") {
                    Button("Sign Out", role: .destructive) { viewModel.logout() }
                }
            }
            .navigationTitle("Settings")
            .task { await viewModel.loadAll() }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await viewModel.refreshAfterPlaudAuthorization() }
            }
        }
    }

    /// Qdrant is "ok" if either the health check passed OR the API key is present
    /// (local Qdrant doesn't need an API key, so missing key ≠ disconnected)
    private var qdrantEffectiveStatus: Bool {
        viewModel.systemStatus?.qdrant?.ok == true || viewModel.hasQdrantAPIKey
    }

    private func systemHealthRow(_ name: String, ok: Bool, detail: String?) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red)
            Text(name)
                .font(.subheadline)
            Spacer()
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(ok ? "OK" : "Down")
                    .font(.caption)
                    .foregroundStyle(ok ? .green : .red)
            }
        }
    }

    private func configField(
        _ title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
        }
    }

    private func credentialRow(_ title: String, present: Bool) -> some View {
        HStack {
            Image(systemName: present ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(present ? .green : .red)
            Text(title)
            Spacer()
            Text(present ? "Present" : "Missing")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func startNotionOAuth() {
        Task {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
                  let window = scene.windows.first else { return }
            await notion.startOAuthFlow(anchor: window)
        }
    }

    private func startPlaudOAuth() {
        Task {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
                  let window = scene.windows.first else { return }
            await viewModel.startPlaudOAuthFlow(anchor: window)
        }
    }
}
