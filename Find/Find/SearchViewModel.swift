import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var searchResponse: FindSearchResponse?
    @Published var selectedResult: FindRankedResult?
    @Published var summaryText = ""
    @Published var isSummarizing = false
    @Published var searchHistory: [String] = []

    private let apiClient: FindAPIClient
    private let historyKey = "find-history"

    init(apiClient: FindAPIClient) {
        self.apiClient = apiClient
        loadHistory()
    }

    func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = ""
        summaryText = ""

        do {
            let response = try await apiClient.search(query: trimmed)
            searchResponse = response
            selectedResult = response.results.indices.contains(response.selectedIndex)
                ? response.results[response.selectedIndex]
                : response.results.first
            addToHistory(trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func select(_ result: FindRankedResult) {
        selectedResult = result
        summaryText = ""
    }

    func summarizeSelected() async {
        guard let selectedResult else { return }

        isSummarizing = true
        errorMessage = ""

        do {
            summaryText = try await apiClient.summarize(
                query: searchResponse?.query ?? query,
                url: selectedResult.url,
                title: selectedResult.title
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isSummarizing = false
    }

    func runHistorySearch(_ term: String) async {
        query = term
        await runSearch()
    }

    func runDrillDown(from baseQuery: String, pill: String) async {
        let base = baseQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPill = pill.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty, !normalizedPill.isEmpty else { return }

        let loweredWords = base
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).lowercased() }
        let nextQuery = loweredWords.last == normalizedPill.lowercased()
            ? base
            : "\(base) \(normalizedPill)"

        query = nextQuery
        await runSearch()
    }

    func clearHistory() {
        searchHistory = []
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    func resetSearch() {
        query = ""
        isLoading = false
        errorMessage = ""
        searchResponse = nil
        selectedResult = nil
        summaryText = ""
        isSummarizing = false
    }

    private func loadHistory() {
        let values = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
        searchHistory = values
    }

    private func addToHistory(_ term: String) {
        var next = searchHistory.filter { $0.caseInsensitiveCompare(term) != .orderedSame }
        next.insert(term, at: 0)
        searchHistory = Array(next.prefix(20))
        UserDefaults.standard.set(searchHistory, forKey: historyKey)
    }
}
