import SwiftUI

struct SettingsView: View {
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

                // Plaud auth status
                Section("Plaud Connection") {
                    if let status = viewModel.plaudStatus {
                        HStack {
                            Image(systemName: status.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(status.isAuthenticated ? .green : .red)
                            Text(status.isAuthenticated ? "Authenticated" : "Not Connected")
                        }
                        if let expires = status.expiresAt {
                            Text("Expires: \(expires)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Status unknown")
                            .foregroundStyle(.secondary)
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
                        if let ws = status.workspaceName {
                            Text("Workspace: \(ws)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Status unknown")
                            .foregroundStyle(.secondary)
                    }
                }

                // System health — deep connectivity check
                Section("System Health") {
                    if viewModel.isLoadingSystemStatus {
                        HStack {
                            ProgressView()
                            Text("Checking services…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if let sys = viewModel.systemStatus {
                        systemHealthRow("Database", ok: sys.database?.ok ?? false, detail: sys.database?.error)
                        systemHealthRow("Qdrant", ok: sys.qdrant?.ok ?? false, detail: sys.qdrant?.error ?? (sys.qdrant?.collections.map { "\($0) collections" }))
                        systemHealthRow("Gemini", ok: sys.gemini?.isUp ?? false, detail: sys.gemini?.error)
                        systemHealthRow("OpenAI", ok: sys.openai?.ok ?? false, detail: sys.openai?.error)
                        systemHealthRow("Plaud", ok: sys.plaud?.isUp ?? false, detail: sys.plaud?.error)
                        systemHealthRow("Notion", ok: sys.notion?.isUp ?? false, detail: sys.notion?.error)
                        Button("Re-check") { Task { await viewModel.loadSystemStatus() } }
                            .font(.caption)
                    } else {
                        Button("Check System Health") { Task { await viewModel.loadSystemStatus() } }
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
        }
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
}
