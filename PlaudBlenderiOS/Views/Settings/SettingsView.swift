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
}
