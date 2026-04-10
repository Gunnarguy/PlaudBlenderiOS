import SwiftUI

/// Compact horizontal bar showing all 6 integration statuses at a glance.
/// Tappable to expand into a detail view with per-service info.
struct ServiceStatusBar: View {
    let systemStatus: SystemStatus?
    let isLoading: Bool
    var onRefresh: (() async -> Void)?

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Compact bar — always visible
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                compactBar
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded, let sys = systemStatus {
                expandedDetail(sys)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var compactBar: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .controlSize(.mini)
                Text("Checking services…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if let sys = systemStatus {
                // Service dots
                HStack(spacing: 5) {
                    serviceDot("DB", ok: sys.database?.ok == true)
                    serviceDot("Qdrant", ok: sys.qdrant?.ok == true)
                    serviceDot("Gemini", ok: sys.gemini?.isUp == true)
                    serviceDot("OpenAI", ok: sys.openai?.ok == true)
                    serviceDot("Plaud", ok: sys.plaud?.isUp == true)
                    serviceDot("Notion", ok: sys.notion?.isUp == true)
                }

                Spacer()

                // Summary
                let healthy = healthyCount(sys)
                Text("\(healthy)/6")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(healthy == 6 ? .green : (healthy >= 3 ? .yellow : .red))

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("No status")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func expandedDetail(_ sys: SystemStatus) -> some View {
        VStack(spacing: 6) {
            Divider().padding(.horizontal, 12)

            serviceRow("Database", icon: "cylinder", ok: sys.database?.ok == true,
                       detail: sys.database?.error ?? sys.database?.url)
            serviceRow("Qdrant", icon: "circle.hexagongrid", ok: sys.qdrant?.ok == true,
                       detail: sys.qdrant?.error ?? qdrantDetail(sys.qdrant))
            serviceRow("Gemini", icon: "sparkle", ok: sys.gemini?.isUp == true,
                       detail: sys.gemini?.error ?? (sys.gemini?.isUp == true ? "Configured" : "Not configured"))
            serviceRow("OpenAI", icon: "brain.head.profile", ok: sys.openai?.ok == true,
                       detail: sys.openai?.error ?? sys.openai?.detail)
            serviceRow("Plaud", icon: "mic.fill", ok: sys.plaud?.isUp == true,
                       detail: sys.plaud?.error ?? (sys.plaud?.isUp == true ? "Authenticated" : "Not connected"))
            serviceRow("Notion", icon: "doc.text", ok: sys.notion?.isUp == true,
                       detail: notionDetail(sys.notion))

            if let onRefresh {
                Button {
                    Task { await onRefresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .padding(.top, 4)
            }
        }
        .padding(.bottom, 8)
    }

    private func serviceDot(_ name: String, ok: Bool) -> some View {
        VStack(spacing: 2) {
            Circle()
                .fill(ok ? .green : .red)
                .frame(width: 8, height: 8)
            Text(name)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func serviceRow(_ name: String, icon: String, ok: Bool, detail: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(ok ? .green : .red)

            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(name)
                .font(.caption.weight(.medium))

            Spacer()

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(ok ? "OK" : "Down")
                    .font(.caption2)
                    .foregroundStyle(ok ? .green : .red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    private func qdrantDetail(_ q: SystemStatus.QdrantCheck?) -> String? {
        guard let q else { return nil }
        if let c = q.collections {
            return "\(c) collection\(c == 1 ? "" : "s")"
        }
        return q.url
    }

    private func healthyCount(_ sys: SystemStatus) -> Int {
        var count = 0
        if sys.database?.ok == true { count += 1 }
        if sys.qdrant?.ok == true { count += 1 }
        if sys.gemini?.isUp == true { count += 1 }
        if sys.openai?.ok == true { count += 1 }
        if sys.plaud?.isUp == true { count += 1 }
        if sys.notion?.isUp == true { count += 1 }
        return count
    }

    private func notionDetail(_ notion: SystemStatus.ServiceFlag?) -> String? {
        guard let notion else { return nil }
        if let error = notion.error, !error.isEmpty {
            return error
        }
        if let workspaceName = notion.workspaceName, !workspaceName.isEmpty {
            return workspaceName
        }
        if notion.isAuthenticated == true {
            return "Connected"
        }
        if notion.hasCredentials == true {
            return "Integration token configured"
        }
        if notion.hasAccessToken == true {
            return "OAuth token present"
        }
        return notion.isUp ? "Configured" : "Not connected"
    }
}
