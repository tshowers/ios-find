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
            let resolvedResponse = response.applyingLocalConversionFallback(to: trimmed)
            searchResponse = resolvedResponse
            selectedResult = resolvedResponse.results.indices.contains(resolvedResponse.selectedIndex)
                ? resolvedResponse.results[resolvedResponse.selectedIndex]
                : resolvedResponse.results.first
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

private extension FindSearchResponse {
    func applyingLocalConversionFallback(to query: String) -> FindSearchResponse {
        guard queryType != .conversion, conversion == nil,
              let localConversion = LocalConversionParser.parse(query, answerText: answer?.text ?? "") else {
            return self
        }

        return FindSearchResponse(
            success: success,
            query: query,
            normalizedQuery: query,
            queryType: .conversion,
            handoff: handoff,
            answer: answer,
            weather: weather,
            conversion: localConversion,
            results: [],
            selectedIndex: 0,
            timings: timings
        )
    }
}

private enum LocalConversionParser {
    private struct Unit {
        let category: FindConversionCategory
        let unit: String
        let label: String
        let factor: Double?
    }

    static func parse(_ query: String, answerText: String) -> FindConversionResult? {
        let parts = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)

        guard let connectorIndex = parts.firstIndex(where: { $0 == "to" || $0 == "in" || $0 == "into" }),
              connectorIndex > 0,
              connectorIndex + 1 < parts.count,
              connectorIndex + 2 == parts.count else { return nil }

        let left = Array(parts[..<connectorIndex])
        guard left.count <= 2 else { return nil }

        let amount: Double
        let inputToken: String
        if left.count == 2 {
            guard let parsedAmount = Double(left[0]) else { return nil }
            amount = parsedAmount
            inputToken = left[1]
        } else {
            amount = 1
            inputToken = left[0]
        }

        guard let input = unit(for: inputToken),
              let output = unit(for: parts[connectorIndex + 1]),
              input.category == output.category,
              amount.isFinite else { return nil }

        let outputAmount: Double
        let rate: Double?
        if input.category == .temperature {
            outputAmount = input.unit == output.unit
                ? amount
                : input.unit == "fahrenheit"
                    ? (amount - 32) * 5 / 9
                    : amount * 9 / 5 + 32
            rate = nil
        } else if input.category == .currency {
            guard let answerAmount = currencyAnswerAmount(in: answerText, excluding: amount, targetUnit: output.unit) else { return nil }
            outputAmount = answerAmount
            rate = amount == 0 ? nil : answerAmount / amount
        } else {
            outputAmount = amount * (input.factor ?? 1) / (output.factor ?? 1)
            rate = nil
        }

        return FindConversionResult(
            category: input.category,
            inputAmount: amount,
            inputUnit: input.unit,
            inputUnitLabel: input.label,
            outputAmount: outputAmount,
            outputUnit: output.unit,
            outputUnitLabel: output.label,
            rate: rate,
            rateUpdatedAt: nil,
            source: input.category == .currency ? "Find answer" : "Find local conversion"
        )
    }

    private static func currencyAnswerAmount(in answer: String, excluding inputAmount: Double, targetUnit: String) -> Double? {
        let targetTerms: [String: String] = [
            "USD": #"(?:us\s*)?dollars?|usd"#, "CAD": #"canadian\s*dollars?|cad"#,
            "EUR": #"euros?|eur"#, "GBP": #"pounds?|gbp"#, "JPY": #"(?:japanese\s*)?yen|jpy"#,
            "AUD": #"australian\s*dollars?|aud"#, "CNY": #"(?:chinese\s*)?(?:yuan|renminbi)|cny"#,
            "CHF": #"swiss\s*francs?|chf"#, "MXN": #"mexican\s*pesos?|mxn"#
        ]
        if let target = targetTerms[targetUnit],
           let expression = try? NSRegularExpression(pattern: #"([-+]?\d[\d,]*(?:\.\d+)?)\s*(?:"# + target + #")"#, options: [.caseInsensitive]) {
            let range = NSRange(answer.startIndex..<answer.endIndex, in: answer)
            if let match = expression.firstMatch(in: answer, range: range),
               let matchRange = Range(match.range(at: 1), in: answer),
               let targeted = Double(answer[matchRange].replacingOccurrences(of: ",", with: "")),
               abs(targeted - inputAmount) > Double.ulpOfOne {
                return targeted
            }
        }

        let pattern = #"[-+]?\d[\d,]*(?:\.\d+)?"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(answer.startIndex..<answer.endIndex, in: answer)
        let values = expression.matches(in: answer, range: range).compactMap { match -> Double? in
            guard let matchRange = Range(match.range, in: answer) else { return nil }
            return Double(answer[matchRange].replacingOccurrences(of: ",", with: ""))
        }
        return values.reversed().first { abs($0 - inputAmount) > Double.ulpOfOne }
    }

    private static func unit(for value: String) -> Unit? {
        switch value {
        case "f", "fahrenheit": return Unit(category: .temperature, unit: "fahrenheit", label: "Fahrenheit", factor: nil)
        case "c", "celsius": return Unit(category: .temperature, unit: "celsius", label: "Celsius", factor: nil)
        case "usd", "dollar", "dollars": return Unit(category: .currency, unit: "USD", label: "US Dollar (USD)", factor: nil)
        case "cad": return Unit(category: .currency, unit: "CAD", label: "Canadian Dollar (CAD)", factor: nil)
        case "eur", "euro", "euros": return Unit(category: .currency, unit: "EUR", label: "Euro (EUR)", factor: nil)
        case "gbp": return Unit(category: .currency, unit: "GBP", label: "British Pound (GBP)", factor: nil)
        case "jpy", "yen": return Unit(category: .currency, unit: "JPY", label: "Japanese Yen (JPY)", factor: nil)
        case "aud": return Unit(category: .currency, unit: "AUD", label: "Australian Dollar (AUD)", factor: nil)
        case "cny", "yuan": return Unit(category: .currency, unit: "CNY", label: "Chinese Yuan (CNY)", factor: nil)
        case "chf": return Unit(category: .currency, unit: "CHF", label: "Swiss Franc (CHF)", factor: nil)
        case "mxn": return Unit(category: .currency, unit: "MXN", label: "Mexican Peso (MXN)", factor: nil)
        case "mi", "mile", "miles": return Unit(category: .distance, unit: "miles", label: "Miles", factor: 1.609344)
        case "km", "kilometer", "kilometers": return Unit(category: .distance, unit: "kilometers", label: "Kilometers", factor: 1)
        case "lb", "lbs", "pound", "pounds": return Unit(category: .weight, unit: "pounds", label: "Pounds", factor: 0.45359237)
        case "kg", "kilogram", "kilograms": return Unit(category: .weight, unit: "kilograms", label: "Kilograms", factor: 1)
        case "in", "inch", "inches": return Unit(category: .length, unit: "inches", label: "Inches", factor: 0.0254)
        case "ft", "foot", "feet": return Unit(category: .length, unit: "feet", label: "Feet", factor: 0.3048)
        case "m", "meter", "meters": return Unit(category: .length, unit: "meters", label: "Meters", factor: 1)
        case "l", "liter", "liters": return Unit(category: .volume, unit: "liters", label: "Liters", factor: 1)
        case "gal", "gallon", "gallons": return Unit(category: .volume, unit: "gallons", label: "Gallons", factor: 3.785411784)
        default: return nil
        }
    }
}
