import Foundation
import Observation

@Observable
final class SearchViewModel {
    var query = ""
    var results: [SearchResult] = []
    var aiAnswer: AIAnswer?
    var total: Int = 0
    var isSearching = false
    var isAskingAI = false
    var error: String?

    var selectedCategories: Set<String> = []
    var startDate: Date?
    var endDate: Date?

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Haptics.tap()
        isSearching = true
        error = nil
        do {
            var request = SearchRequest(query: query)
            if !selectedCategories.isEmpty {
                request.categories = Array(selectedCategories)
            }
            if let startDate {
                request.startDate = startDate.iso8601String
            }
            if let endDate {
                request.endDate = endDate.iso8601String
            }
            let response: SearchResponse = try await api.post("/api/search", body: request)
            results = response.results
            aiAnswer = response.aiAnswer
            total = response.total
        } catch {
            self.error = error.localizedDescription
        }
        isSearching = false
    }

    func askAI(question: String, reasoning: String? = nil) async {
        Haptics.impact()
        isAskingAI = true
        error = nil
        do {
            let request = AskRequest(question: question, reasoning: reasoning)
            let response: AIAnswer = try await api.post("/api/search/ask", body: request)
            aiAnswer = response
        } catch {
            self.error = error.localizedDescription
        }
        isAskingAI = false
    }

    func clear() {
        query = ""
        results = []
        aiAnswer = nil
        total = 0
        selectedCategories = []
        startDate = nil
        endDate = nil
    }
}
