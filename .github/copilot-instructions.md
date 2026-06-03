# Developer Assistant Instructions: PlaudBlenderiOS

You are an expert AI development assistant specializing in native Swift, iOS system architecture, and reactive SwiftUI design. Read these instructions before modifying any files in the workspace.

---

## 1. Project Identity

**PlaudBlenderiOS** is a native SwiftUI companion client for the **Chronos** audio knowledge extraction pipeline. It connects to a self-hosted FastAPI backend to display daily recording timelines, render entity graphs via a WKWebView Cytoscape bridge, manage cloud backup operations, and stream real-time JSON telemetry via WebSockets into an X-Ray view.

---

## 2. Prime Directives

- **Do Not Invent Abstractions**: Work with the existing codebase structure. Do not assume or create new files, APIs, models, or views unless explicitly requested.
- **Maintain Observability**: Keep logging and telemetry pipelines working. Do not comment out OSLog statements or strip diagnostic parameters.
- **Verify Build and Tests**: Every change must compile cleanly and pass unit tests in the `PlaudBlenderiOSTests` target.
- **Update Documentation**: If you modify api interfaces, routing, or state patterns, update [README.md](README.md) and [ARCHITECTURE.md](ARCHITECTURE.md) to keep documentation in sync with code.

---

## 3. Architecture Rules

### SwiftUI & MVVM-S Model
- Use `@Observable` macro objects for ViewModel implementations.
- Inject services (like `APIClient` and `AuthManager`) using SwiftUI's `.environment()` system, avoiding singletons.
- Instantiate ViewModels using the `ViewModelCache` pattern in [ContentView.swift](PlaudBlenderiOS/ContentView.swift) to prevent state re-evaluation loops.

### Concurrency Patterns
- Decorate ViewModels with `@MainActor` to ensure UI state modifications are executed on the main thread.
- Bind asynchronous tasks to the SwiftUI view lifecycle using the `.task { ... }` block to ensure execution cancels automatically when views disappear.

---

## 4. Key Files by Concern

- **Network Routing**: [APIClient.swift](PlaudBlenderiOS/Services/APIClient.swift)
- **Token Storage**: [AuthManager.swift](PlaudBlenderiOS/Services/AuthManager.swift)
- **Telemetry Loop**: [WebSocketManager.swift](PlaudBlenderiOS/Services/WebSocketManager.swift)
- **Sync Operations**: [SyncViewModel.swift](PlaudBlenderiOS/ViewModels/SyncViewModel.swift)
- **Graph Bridging**: [GraphContainerView.swift](PlaudBlenderiOS/Views/Graph/GraphContainerView.swift)

---

## 5. Build and Test Commands

To validate target changes from the command-line, run:

```bash
# Compile and build the main application scheme
xcodebuild -project PlaudBlenderiOS.xcodeproj -scheme PlaudBlenderiOS -destination 'platform=iOS Simulator,name=iPhone 15' build

# Execute the unit testing scheme
xcodebuild -project PlaudBlenderiOS.xcodeproj -scheme PlaudBlenderiOS -destination 'platform=iOS Simulator,name=iPhone 15' test
```

---

## 6. Logging and Security Conventions

- Use `os.Logger` with specific categories (`App`, `APIClient`, `WebSocket`, `Auth`).
- Redact header tokens like `Authorization` inside the telemetry filters before logging payloads.
- Store sensitive tokens solely inside Keychain Services; never log raw keys or cache them in plaintext files.
