import Foundation
import Observation

@Observable
final class StatsViewModel {
    var stats: Stats?
    var sessionCost: SessionCost?
    var costHistory: CostHistory?
    var modelPricing: ModelPricing?
    var isLoading = false
    var error: String?

    private(set) var api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func loadStats() async {
        isLoading = true
        error = nil
        do {
            stats = try await api.get("/api/stats")
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadSessionCost() async {
        do {
            sessionCost = try await api.get("/api/costs/session")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadCostHistory(days: Int = 30) async {
        do {
            let query = ["days": "\(days)"]
            costHistory = try await api.get("/api/costs/history", query: query)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadPricing() async {
        do {
            modelPricing = try await api.get("/api/costs/pricing")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadAll() async {
        await loadStats()
        await loadSessionCost()
        await loadCostHistory()
        await loadPricing()
    }

    func refresh() async {
        await loadAll()
    }
}
