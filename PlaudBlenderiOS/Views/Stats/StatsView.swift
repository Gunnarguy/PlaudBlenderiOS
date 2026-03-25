import SwiftUI
import Charts

struct StatsView: View {
    let viewModel: StatsViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.stats == nil {
                    LoadingView(message: "Loading stats...")
                } else if let stats = viewModel.stats {
                    statsContent(stats)
                } else {
                    EmptyStateView(
                        icon: "chart.bar",
                        title: "No Stats Available",
                        actionTitle: "Refresh",
                        action: { Task { await viewModel.refresh() } }
                    )
                }
            }
            .navigationTitle("Stats")
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.loadAll() }
        }
    }

    // MARK: - Main Content

    private func statsContent(_ stats: Stats) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                if let error = viewModel.error {
                    ErrorBanner(message: error)
                }

                // Primary stat cards (2x2)
                primaryStatCards(stats)

                // Derived stat cards (2x2)
                derivedStatCards(stats)

                // Sentiment distribution bar
                if let dist = stats.sentimentDistribution, !dist.isEmpty {
                    sentimentDistributionBar(dist)
                }

                // Category distribution chart
                if !stats.categories.isEmpty {
                    categoryChart(stats.categories)
                }

                // Hour × Category heatmap
                if stats.categoriesByHour != nil {
                    heatmapChart(stats)
                }

                // Activity by hour
                let hourly = stats.effectiveEventsByHour
                if !hourly.isEmpty {
                    activityByHourChart(hourly)
                }

                // Day of week
                if let dow = stats.eventsByDayOfWeek, !dow.isEmpty {
                    dayOfWeekChart(dow)
                }

                // Top keywords
                if let keywords = stats.topKeywords, !keywords.isEmpty {
                    keywordsCloud(keywords)
                }

                // Insights
                insightsSection(stats)

                // Plaud Cloud stats
                if let cloud = stats.plaudCloudStats, !cloud.isEmpty {
                    plaudCloudCard(cloud)
                }

                // Per-model cost breakdown
                if let cost = viewModel.sessionCost {
                    modelCostBreakdown(cost)
                }

                // Session costs summary
                if let cost = viewModel.sessionCost {
                    costCard(cost)
                }

                // Cost history chart
                if let history = viewModel.costHistory, let byDay = history.byDay, !byDay.isEmpty {
                    costHistoryChart(byDay, totalCost: history.totalCostUsd, totalCalls: history.totalCalls, days: history.days)
                }

                // Topics link
                NavigationLink {
                    TopicsGridView(viewModel: TopicsViewModel(api: viewModel.api))
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "tag")
                            .font(.title3)
                            .frame(width: 32)
                            .foregroundStyle(Color.accentPrimary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Topics")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Clusters and recurring themes across your recordings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Primary Stat Cards

    private func primaryStatCards(_ stats: Stats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Recordings", value: "\(stats.totalRecordings)", icon: "waveform")
            StatCard(title: "Events", value: "\(stats.totalEvents)", icon: "list.bullet")
            StatCard(title: "Days", value: "\(stats.totalDays)", icon: "calendar")
            StatCard(title: "Hours", value: String(format: "%.1f", stats.totalDurationHours), icon: "clock")
        }
        .padding(.horizontal)
    }

    // MARK: - Derived Stat Cards

    private func derivedStatCards(_ stats: Stats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Avg Events/Rec", value: String(format: "%.1f", stats.effectiveAvgEvents), icon: "number")
            StatCard(title: "Avg Duration", value: String(format: "%.0fm", stats.effectiveAvgDuration), icon: "timer")
            if let sentiment = stats.sentimentAvg {
                StatCard(
                    title: "Sentiment",
                    value: String(format: "%+.2f", sentiment),
                    icon: sentiment > 0.3 ? "face.smiling" : sentiment < -0.3 ? "face.dashed.fill" : "face.dashed"
                )
            }
            if let rate = stats.pipelineCompletionRate {
                StatCard(title: "Pipeline", value: String(format: "%.0f%%", rate * 100), icon: "checkmark.circle")
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Sentiment Distribution Bar

    private func sentimentDistributionBar(_ dist: [String: Int]) -> some View {
        let pos = dist["positive"] ?? 0
        let neu = dist["neutral"] ?? 0
        let neg = dist["negative"] ?? 0
        let total = max(pos + neu + neg, 1)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Sentiment Distribution")
                .font(.headline)

            GeometryReader { geo in
                HStack(spacing: 0) {
                    if pos > 0 {
                        Rectangle()
                            .fill(Color.accentGreen)
                            .frame(width: geo.size.width * CGFloat(pos) / CGFloat(total))
                    }
                    if neu > 0 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: geo.size.width * CGFloat(neu) / CGFloat(total))
                    }
                    if neg > 0 {
                        Rectangle()
                            .fill(Color.accentRed)
                            .frame(width: geo.size.width * CGFloat(neg) / CGFloat(total))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 20)

            HStack(spacing: 16) {
                Label("\(pos) positive", systemImage: "circle.fill")
                    .font(.caption2).foregroundStyle(Color.accentGreen)
                Label("\(neu) neutral", systemImage: "circle.fill")
                    .font(.caption2).foregroundStyle(.secondary)
                Label("\(neg) negative", systemImage: "circle.fill")
                    .font(.caption2).foregroundStyle(Color.accentRed)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Category Chart

    private func categoryChart(_ categories: [String: Int]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categories")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(categories.sorted(by: { $0.value > $1.value }), id: \.key) { cat, count in
                    BarMark(
                        x: .value("Count", count),
                        y: .value("Category", cat.capitalized)
                    )
                    .foregroundStyle(Color.forCategory(cat))
                    .annotation(position: .trailing) {
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(categories.count * 36))
            .padding(.horizontal)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Heatmap (Hour × Category)

    private func heatmapChart(_ stats: Stats) -> some View {
        let data = stats.heatmapData
        guard !data.isEmpty else { return AnyView(EmptyView()) }

        // Get top 6 categories by total count
        var catTotals: [String: Int] = [:]
        for d in data { catTotals[d.category, default: 0] += d.count }
        let topCats = catTotals.sorted { $0.value > $1.value }.prefix(6).map(\.key)
        let filtered = data.filter { topCats.contains($0.category) }
        let maxCount = filtered.map(\.count).max() ?? 1

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Activity Heatmap")
                    .font(.headline)
                Text("Hour of day × Category")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Header (hours)
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 2) {
                        // Hour labels
                        HStack(spacing: 2) {
                            Text("")
                                .frame(width: 70, alignment: .leading)
                            ForEach(0..<24, id: \.self) { h in
                                Text(h % 6 == 0 ? "\(h)" : "")
                                    .font(.system(size: 8))
                                    .frame(width: 14, alignment: .center)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Category rows
                        ForEach(topCats, id: \.self) { cat in
                            HStack(spacing: 2) {
                                Text(cat.capitalized)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .frame(width: 70, alignment: .leading)

                                ForEach(0..<24, id: \.self) { h in
                                    let count = filtered.first(where: { $0.hour == h && $0.category == cat })?.count ?? 0
                                    let intensity = maxCount > 0 ? Double(count) / Double(maxCount) : 0
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.forCategory(cat).opacity(count > 0 ? 0.15 + intensity * 0.85 : 0.05))
                                        .frame(width: 14, height: 14)
                                        .overlay {
                                            if count > 0 {
                                                Text("\(count)")
                                                    .font(.system(size: 6))
                                                    .foregroundStyle(.white.opacity(intensity > 0.4 ? 1 : 0))
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        )
    }

    // MARK: - Activity by Hour

    private func activityByHourChart(_ hourly: [Int: Int]) -> some View {
        let maxVal = hourly.values.max() ?? 1
        let entries = (0..<24).map { h in
            (hour: h, count: hourly[h] ?? 0)
        }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Activity by Hour")
                .font(.headline)

            Chart(entries, id: \.hour) { entry in
                BarMark(
                    x: .value("Hour", entry.hour),
                    y: .value("Events", entry.count)
                )
                .foregroundStyle(
                    Color.accentPrimary.opacity(entry.count > 0 ? 0.3 + 0.7 * Double(entry.count) / Double(maxVal) : 0.1)
                )
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: 3)) { value in
                    AxisValueLabel {
                        if let h = value.as(Int.self) {
                            Text(h == 0 ? "12a" : h < 12 ? "\(h)a" : h == 12 ? "12p" : "\(h-12)p")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel().font(.caption2)
                }
            }
            .frame(height: 140)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Day of Week

    private func dayOfWeekChart(_ dow: [String: Int]) -> some View {
        let order = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let short = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let entries = order.enumerated().compactMap { i, day -> (label: String, count: Int, index: Int)? in
            let count = dow[day] ?? dow[day.lowercased()] ?? dow[short[i]] ?? dow[short[i].lowercased()] ?? 0
            return (short[i], count, i)
        }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Activity by Day")
                .font(.headline)

            Chart(entries, id: \.index) { entry in
                BarMark(
                    x: .value("Day", entry.label),
                    y: .value("Events", entry.count)
                )
                .foregroundStyle(Color.accentPurple.opacity(0.7))
                .annotation(position: .top) {
                    if entry.count > 0 {
                        Text("\(entry.count)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().font(.caption2) }
            }
            .chartYAxis(.hidden)
            .frame(height: 140)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Keywords Cloud

    private func keywordsCloud(_ keywords: [[String: JSONValue]]) -> some View {
        let parsed: [(word: String, count: Int)] = keywords.compactMap { dict in
            guard let word = dict["keyword"]?.stringValue,
                  let count = dict["count"]?.intValue else { return nil }
            return (word, count)
        }.prefix(20).map { $0 }

        let maxCount = parsed.map(\.count).max() ?? 1

        return VStack(alignment: .leading, spacing: 8) {
            Text("Top Keywords")
                .font(.headline)

            FlowLayout(spacing: 6) {
                ForEach(parsed, id: \.word) { item in
                    let scale = 0.7 + 0.6 * Double(item.count) / Double(maxCount)
                    Text(item.word)
                        .font(.system(size: 13 * scale, weight: scale > 1.0 ? .semibold : .regular))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentPrimary.opacity(0.08 + 0.12 * Double(item.count) / Double(maxCount)))
                        .clipShape(Capsule())
                        .foregroundStyle(Color.accentPrimary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Insights

    private func insightsSection(_ stats: Stats) -> some View {
        let hourly = stats.effectiveEventsByHour
        let peakHour = hourly.max(by: { $0.value < $1.value })

        let hasInsight = stats.mostProductiveDay != nil || peakHour != nil || stats.longestRecordingMin != nil

        return Group {
            if hasInsight {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Insights")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        if let day = stats.mostProductiveDay {
                            InsightCard(icon: "star.fill", color: .accentYellow, label: "Best Day", value: day)
                        }
                        if let peak = peakHour {
                            let h = peak.key
                            let label = h == 0 ? "12 AM" : h < 12 ? "\(h) AM" : h == 12 ? "12 PM" : "\(h-12) PM"
                            InsightCard(icon: "bolt.fill", color: .accentOrange, label: "Peak Hour", value: label)
                        }
                        if let longest = stats.longestRecordingMin {
                            InsightCard(icon: "record.circle", color: .accentRed, label: "Longest Rec", value: String(format: "%.0fm", longest))
                        }
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Plaud Cloud Stats

    private func plaudCloudCard(_ cloud: [String: JSONValue]) -> some View {
        let count = cloud["total_count"]?.intValue ?? 0
        let hours = cloud["total_duration_hours"]?.doubleValue ?? 0
        let avgMin = cloud["avg_duration_minutes"]?.doubleValue ?? 0
        let earliest = cloud["date_range"]?.objectValue?["earliest"]?.stringValue
        let latest = cloud["date_range"]?.objectValue?["latest"]?.stringValue

        return VStack(alignment: .leading, spacing: 8) {
            Label("Plaud Cloud", systemImage: "cloud.fill")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                VStack {
                    Text("\(count)").font(.title3).fontWeight(.bold).monospacedDigit()
                    Text("Recordings").font(.caption2).foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.1f", hours)).font(.title3).fontWeight(.bold).monospacedDigit()
                    Text("Hours").font(.caption2).foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.0fm", avgMin)).font(.title3).fontWeight(.bold).monospacedDigit()
                    Text("Avg Duration").font(.caption2).foregroundStyle(.secondary)
                }
            }

            if let e = earliest, let l = latest {
                Text("\(e) — \(l)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Per-Model Cost Breakdown

    private func modelCostBreakdown(_ cost: SessionCost) -> some View {
        let models: [(name: String, calls: Int, cost: Double)] = cost.byModel.compactMap { key, val in
            guard let obj = val.objectValue,
                  let calls = obj["calls"]?.intValue,
                  let c = obj["cost_usd"]?.doubleValue else { return nil }
            return (key, calls, c)
        }.sorted { $0.cost > $1.cost }

        return Group {
            if !models.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Cost by Model", systemImage: "cpu")
                        .font(.headline)

                    ForEach(models, id: \.name) { model in
                        HStack {
                            Text(model.name)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text("\(model.calls) calls")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Text(String(format: "$%.4f", model.cost))
                                .font(.caption)
                                .fontWeight(.medium)
                                .monospacedDigit()
                                .frame(width: 70, alignment: .trailing)
                        }
                        if model.name != models.last?.name {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Cost Card

    private func costCard(_ cost: SessionCost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Session Costs", systemImage: "dollarsign.circle")
                .font(.headline)
            HStack(spacing: 20) {
                VStack {
                    Text(String(format: "$%.4f", cost.totalCostUsd))
                        .font(.title3).fontWeight(.bold).monospacedDigit()
                    Text("Total").font(.caption2).foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(cost.totalCalls)")
                        .font(.title3).fontWeight(.bold).monospacedDigit()
                    Text("API Calls").font(.caption2).foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.0fm", cost.sessionMinutes))
                        .font(.title3).fontWeight(.bold).monospacedDigit()
                    Text("Duration").font(.caption2).foregroundStyle(.secondary)
                }
            }

            if cost.totalInputTokens > 0 || cost.totalOutputTokens > 0 {
                Divider()
                HStack(spacing: 20) {
                    VStack {
                        Text(formatTokens(cost.totalInputTokens))
                            .font(.caption).fontWeight(.medium).monospacedDigit()
                        Text("Input Tokens").font(.caption2).foregroundStyle(.secondary)
                    }
                    VStack {
                        Text(formatTokens(cost.totalOutputTokens))
                            .font(.caption).fontWeight(.medium).monospacedDigit()
                        Text("Output Tokens").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Cost History Chart

    private func costHistoryChart(_ byDay: [[String: JSONValue]], totalCost: Double, totalCalls: Int, days: Int) -> some View {
        let entries = byDay.compactMap { dict -> CostDayEntry? in
            guard let dateStr = dict["date"]?.stringValue,
                  let cost = dict["cost"]?.doubleValue ?? dict["cost_usd"]?.doubleValue ?? dict["total_cost_usd"]?.doubleValue else {
                return nil
            }
            let calls = dict["calls"]?.intValue ?? dict["total_calls"]?.intValue ?? 0
            return CostDayEntry(date: dateStr, cost: cost, calls: calls)
        }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Cost History (\(days)d)", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                Spacer()
                Text(String(format: "$%.4f total", totalCost))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if !entries.isEmpty {
                Chart(entries) { entry in
                    AreaMark(
                        x: .value("Date", entry.date),
                        y: .value("Cost", entry.cost)
                    )
                    .foregroundStyle(Color.accentPrimary.opacity(0.15))

                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Cost", entry.cost)
                    )
                    .foregroundStyle(Color.accentPrimary)

                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("Cost", entry.cost)
                    )
                    .foregroundStyle(Color.accentPrimary)
                    .symbolSize(entry.cost > 0 ? 20 : 0)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "$%.3f", v))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 160)
            }

            HStack(spacing: 16) {
                Label("\(totalCalls) calls", systemImage: "arrow.up.arrow.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let maxEntry = entries.max(by: { $0.cost < $1.cost }) {
                    Label("Peak: \(maxEntry.date) ($\(String(format: "%.4f", maxEntry.cost)))", systemImage: "arrow.up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentPrimary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Flow Layout (for keyword cloud)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

// MARK: - Cost Day Entry

private struct CostDayEntry: Identifiable {
    let date: String
    let cost: Double
    let calls: Int
    var id: String { date }
}
