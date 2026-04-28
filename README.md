# PlaudBlenderiOS

Native SwiftUI client for [Chronos](https://github.com/gunnarhostetler/PlaudBlender) — a knowledge timeline built from Plaud voice recordings.

## Architecture

- **SwiftUI** with `@Observable` MVVM pattern
- **URLSession** async/await networking — no external dependencies
- **Bottom navigation**: Timeline, Search, Stats, Graph, Data, System, Settings
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
3. Ensure the Pi-hosted Chronos backend is running and reachable
4. Build and run on simulator or device
5. In Settings, only override the server URL if you intentionally want a different Pi or private network endpoint. The app prefers the Pi over Tailscale when available, then falls back to the public ngrok API, then the Pi LAN IP.

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
    System/        → Native runtime diagnostics and backend health
    Notion/        → Notion import and sync
    Settings/      → Server config, auth, about
    XRay/          → Live telemetry monitor
    More/          → Secondary navigation hub
  Components/      → Reusable UI: CategoryPill, ConfidenceBadge, LoadingView
  Extensions/      → Color+Chronos (category colors), Date+Formatting
```

## API Backend

The app connects to the Chronos FastAPI backend (55 routes) built in the PlaudBlender repo under `api/`. Key endpoints:

| Area       | Endpoints                                                                      |
| ---------- | ------------------------------------------------------------------------------ |
| Timeline   | `GET /api/days`, `GET /api/days/{date}`                                        |
| Recordings | `GET /api/recordings/{id}`                                                     |
| Search     | `POST /api/search`, `POST /api/search/ask`                                     |
| Topics     | `GET /api/topics`, `GET /api/topics/{name}/timeline`                           |
| Graph      | `GET /api/graph`                                                               |
| Stats      | `GET /api/stats`                                                               |
| Sync       | `POST /api/sync/run`, `GET /api/sync/status`                                   |
| System     | `GET /api/status`, `GET /api/xray/events`, `GET /api/admin/runtime` (optional) |
| Costs      | `GET /api/costs/session`, `GET /api/costs/history`                             |
| Auth       | `GET /api/auth/plaud/status`, `GET /api/auth/notion/status`                    |

## Runtime Diagnostics Contract

The native System screen works today with `GET /api/status` plus `GET /api/xray/events`, and it becomes richer still when the backend also exposes `GET /api/admin/runtime` with these top-level keys:

- `runtime_health`: summary, pass or warn or fail counts, overall ok flag
- `runtime_manager`: manager name, mode, watchdog state, last verification timestamp
- `services`: runtime-managed service states with names, display names, enabled flags, health, unit names, and detail text
- `ports`: core ports with port number, protocol, reachability, URL, and detail text
- `signals`: recent operational events from watchdog, sync, or service monitors
- `plaud_auth`: Plaud auth state and detail
- `notes`: optional plain-text operator notes
