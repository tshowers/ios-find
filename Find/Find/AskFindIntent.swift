import AppIntents
import Foundation
import SwiftUI
import UIKit

/// "Ask Find" for Siri and Shortcuts: runs a Find search, speaks the answer
/// and shows it as a card, without opening the app. Uses the same answer
/// types as the app (instant answers, conversions, results summaries, the
/// top result). The answer is remembered so "Save that to Knowledge" can
/// save it.
struct AskFindIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Find"
    static var description = IntentDescription("Get Find's answer to a question.")

    @Parameter(title: "Question", requestValueDialog: "What do you want to find?")
    var question: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ask Find \(\.$question)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> & ShowsSnippetView {
        let response = try await FindAPIClient(config: .fromBundle()).search(query: question, maxResults: 3)
        let answer = FindSiriAnswer(response: response)
        answer?.remember()
        let spoken = answer?.spoken ?? "Find didn't get a result for that."
        return .result(
            value: spoken,
            dialog: IntentDialog(stringLiteral: spoken),
            view: FindSiriAnswerCard(answer: answer)
        )
    }
}

/// "Save that to Knowledge": opens Docs' /knowledge/save with the last
/// answer Ask Find gave. Opens the app first because the save happens in
/// the browser, where Docs can sign the person in.
struct SaveLastFindIntent: AppIntent {
    static var title: LocalizedStringResource = "Save Find's Answer to Knowledge"
    static var description = IntentDescription("Saves the last answer Find gave you to Knowledge.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let answer = FindSiriAnswer.last(), let url = answer.knowledgeSaveURL else {
            return .result(dialog: "There's nothing to save yet. Ask Find something first.")
        }
        await UIApplication.shared.open(url)
        return .result(dialog: IntentDialog(stringLiteral: "Saving \(answer.title) to Knowledge."))
    }
}

/// Puts "Ask Find" and "Save that to Knowledge" in Siri and Spotlight with
/// no setup.
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
        AppShortcut(
            intent: SaveLastFindIntent(),
            phrases: [
                "Save that to Knowledge in \(.applicationName)",
                "Save that with \(.applicationName)",
                "Save the last \(.applicationName) answer",
            ],
            shortTitle: "Save to Knowledge",
            systemImageName: "books.vertical"
        )
    }
}

/// One Siri answer: what's spoken, what the card shows, and what "Save
/// that to Knowledge" saves.
struct FindSiriAnswer: Codable {
    let query: String
    /// Small caps label above the headline ("Conversion", a source, ...).
    let label: String
    let title: String
    let detail: String
    let spoken: String
    let sourceURL: String
    let sourceName: String
    let keywords: [String]

    init?(response: FindSearchResponse) {
        query = response.query
        if let instant = response.instant {
            label = instant.label
            title = instant.value
            detail = [instant.title, instant.detail].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
            spoken = "\(instant.value). \(instant.title)."
            sourceURL = ""
            sourceName = ""
            keywords = []
        } else if let conversion = response.conversion {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            let output = formatter.string(from: NSNumber(value: conversion.outputAmount)) ?? String(conversion.outputAmount)
            let input = formatter.string(from: NSNumber(value: conversion.inputAmount)) ?? String(conversion.inputAmount)
            let inputLabel = conversion.inputUnitLabel ?? conversion.inputUnit
            let outputLabel = conversion.outputUnitLabel ?? conversion.outputUnit
            label = "Conversion"
            title = "\(output) \(outputLabel)"
            detail = "\(input) \(inputLabel)"
            spoken = "\(input) \(inputLabel) is \(output) \(outputLabel)."
            sourceURL = ""
            sourceName = conversion.source ?? ""
            keywords = []
        } else if let block = response.answer, !block.text.isEmpty {
            label = "Answer"
            title = response.query
            detail = block.text
            spoken = block.text
            sourceURL = block.references.first?.url ?? ""
            sourceName = block.references.first?.displayUrl ?? ""
            keywords = []
        } else if let top = response.results.first {
            let text = top.answer ?? top.summary
            label = top.rssSource ?? "Top result"
            title = top.title
            detail = text
            spoken = text.isEmpty ? "The top result is \(top.title), from \(top.displayUrl)." : "\(top.title). \(text)"
            sourceURL = top.url
            sourceName = top.displayUrl
            keywords = top.pills
        } else {
            return nil
        }
    }

    var knowledgeSaveURL: URL? {
        KnowledgeSaveLink.url(query: query, title: title, answer: detail.isEmpty ? spoken : detail, sourceURL: sourceURL, keywords: keywords)
    }

    private static let defaultsKey = "find.siri.lastAnswer"

    func remember() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    static func last() -> FindSiriAnswer? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(FindSiriAnswer.self, from: data)
    }
}

/// The card Siri shows under the spoken answer.
struct FindSiriAnswerCard: View {
    let answer: FindSiriAnswer?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let answer {
                Text(answer.label.uppercased())
                    .font(Theme.font(11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.blueInk)
                Text(answer.title)
                    .font(Theme.font(20, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(3)
                if !answer.detail.isEmpty {
                    Text(answer.detail)
                        .font(Theme.font(15))
                        .foregroundStyle(Theme.text)
                        .lineLimit(5)
                }
                if !answer.sourceName.isEmpty {
                    Text(answer.sourceName)
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.muted)
                }
            } else {
                Text("Find didn't get a result for that.")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}
