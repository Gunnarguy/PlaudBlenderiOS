# PlaudBlenderiOS

Native SwiftUI client for [Chronos](https://github.com/gunnarhostetler/PlaudBlender) — a knowledge timeline built from Plaud voice recordings.

## Architecture

- **SwiftUI** with `@Observable` MVVM pattern
- **URLSession** async/await networking — no external dependencies
- **TabView** navigation: Timeline, Topics, Search, Graph, Stats, More
- **Cytoscape.js** knowledge graph rendered in WKWebView
- **Swift Charts** for stats visualization
- **Security framework** Keychain for token storage

## Requirements

- Xcode 26.3+
- iOS 26.2+ deployment target
- Running [Chronos FastAPI backend](https://github.com/gunnarhostetler/PlaudBlender) (`api/`)

## Setup

1. Clone the repo
2. Open `PlaudBlenderiOS.xcodeproj` in Xcode
3. Start the Chronos backend: `cd ../PlaudBlender && python -m uvicorn api.main:app --port 8000`
4. Build and run on simulator or device
5. In Settings, configure the server URL (default: `http://localhost:8000`)

## Project Structure

```
PlaudBlenderiOS/
  Models/          → Codable structs matching FastAPI response schemas
  Services/        → APIClient, AuthManager, KeychainService, WebSocketManager
  ViewModels/      → @Observable view models (one per feature)
  Views/           → SwiftUI views organized by feature
    Timeline/      → Day list, day cards, recording cards
    RecordingDetail/ → Full recording detail with events/transcript tabs
    Search/        → Semantic search with category filters
    Topics/        → Topic grid and timeline drill-down
    Graph/         → Cytoscape.js knowledge graph (WKWebView)
    Stats/         → Charts, stat cards, cost tracking
    Sync/          → Pipeline dashboard, workflow controls
    Notion/        → Notion import and sync
    Settings/      → Server config, auth, about
    XRay/          → Live telemetry monitor
    More/          → Secondary navigation hub
  Components/      → Reusable UI: CategoryPill, ConfidenceBadge, LoadingView
  Extensions/      → Color+Chronos (category colors), Date+Formatting
```

## API Backend

The app connects to the Chronos FastAPI backend (55 routes) built in the PlaudBlender repo under `api/`. Key endpoints:

| Area       | Endpoints                                                   |
| ---------- | ----------------------------------------------------------- |
| Timeline   | `GET /api/days`, `GET /api/days/{date}`                     |
| Recordings | `GET /api/recordings/{id}`                                  |
| Search     | `POST /api/search`, `POST /api/search/ask`                  |
| Topics     | `GET /api/topics`, `GET /api/topics/{name}/timeline`        |
| Graph      | `GET /api/graph`                                            |
| Stats      | `GET /api/stats`                                            |
| Sync       | `POST /api/sync/run`, `GET /api/sync/status`                |
| Costs      | `GET /api/costs/session`, `GET /api/costs/history`          |
| Auth       | `GET /api/auth/plaud/status`, `GET /api/auth/notion/status` |
