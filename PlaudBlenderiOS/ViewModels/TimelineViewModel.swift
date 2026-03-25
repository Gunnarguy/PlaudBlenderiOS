import Foundation
import Observation

@Observable
final class TimelineViewModel {
    var days: [DaySummary] = []
    var selectedDate: String?
    var isLoading = false
    var isLoadingMore = false
    var hasMorePages = true
    var error: String?

    private let api: APIClient
    private let pageSize = 50

    init(api: APIClient) {
        self.api = api
    }

    func loadDays(limit: Int = 50, offset: Int = 0) async {
        isLoading = true
        error = nil
        do {
            let query = ["limit": "\(limit)", "offset": "\(offset)"]
            let response: DaysResponse = try await api.get("/api/timeline/days-filled", query: query)
            if offset == 0 {
                days = response.days
            } else {
                days.append(contentsOf: response.days)
            }
            hasMorePages = response.days.count >= limit
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore, !isLoading, hasMorePages else { return }
        isLoadingMore = true
        do {
            let query = ["limit": "\(pageSize)", "offset": "\(days.count)"]
            let response: DaysResponse = try await api.get("/api/timeline/days-filled", query: query)
            let existingIds = Set(days.map(\.id))
            let newDays = response.days.filter { !existingIds.contains($0.id) }
            days.append(contentsOf: newDays)
            hasMorePages = response.days.count >= pageSize
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingMore = false
    }

    func loadFilledDays(startDate: String, endDate: String) async {
        isLoading = true
        error = nil
        do {
            let query = ["start_date": startDate, "end_date": endDate]
            let response: DaysResponse = try await api.get("/api/timeline/days-filled", query: query)
            days = response.days
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        await loadDays()
    }
}
