import AppIntents
import Foundation

/// "Ask Find" for Siri and Shortcuts: runs a Find search and speaks the
/// answer, without opening the app. Uses the same answer types as the app
/// (instant answers, conversions, results summaries, the top result).
struct AskFindIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Find"
    static var description = IntentDescription("Get Find's answer to a question.")

    @Parameter(title: "Question", requestValueDialog: "What do you want to find?")
    var question: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ask Find \(\.$question)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let response = try await FindAPIClient(config: .fromBundle()).search(query: question, maxResults: 3)
        let answer = Self.spokenAnswer(for: response)
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }

    static func spokenAnswer(for response: FindSearchResponse) -> String {
        if let instant = response.instant {
            return "\(instant.value). \(instant.title)."
        }
        if let conversion = response.conversion {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            let output = formatter.string(from: NSNumber(value: conversion.outputAmount)) ?? String(conversion.outputAmount)
            let input = formatter.string(from: NSNumber(value: conversion.inputAmount)) ?? String(conversion.inputAmount)
            return "\(input) \(conversion.inputUnitLabel ?? conversion.inputUnit) is \(output) \(conversion.outputUnitLabel ?? conversion.outputUnit)."
        }
        if let text = response.answer?.text, !text.isEmpty {
            return text
        }
        if let top = response.results.first {
            let detail = top.answer ?? top.summary
            return detail.isEmpty ? "The top result is \(top.title), from \(top.displayUrl)." : "\(top.title). \(detail)"
        }
        return "Find didn't get a result for that."
    }
}

/// Puts "Ask Find" in Siri and Spotlight with no setup.
struct FindAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskFindIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Search \(.applicationName)",
            ],
            shortTitle: "Ask Find",
            systemImageName: "magnifyingglass"
        )
    }
}
