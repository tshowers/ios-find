import Combine
import Foundation
import UniformTypeIdentifiers

/// A trimmed-down Find search for the share extension. The extension is
/// its own process and can't use the app's FindAPIClient, so this repeats
/// the one call it needs (POST /find/search, as in FindAPIClient.swift) and
/// decodes only the fields it shows.
@MainActor
final class ShareModel: ObservableObject {
    @Published var query = ""
    @Published var isLoading = false
    @Published var answer: ShareAnswer?
    @Published var failed = false

    // Same backend and key as the app (AppConfig.fromBundle's defaults).
    private let apiBaseURL = URL(string: "https://api.taliferro.tech/api")!
    private let apiKey = "AIzaSyCAAgRd8tq9PXkPKE2zddseYtZ-Xx_P8mU"

    func start(with items: [NSExtensionItem]) async {
        query = await Self.sharedText(from: items)
        if !query.isEmpty { await search() }
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        failed = false
        defer { isLoading = false }
        var request = URLRequest(url: apiBaseURL.appending(path: "find/search"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "query": String(trimmed.prefix(200)),
            "maxResults": 3,
            "timeZone": TimeZone.current.identifier,
            "features": ["instant", "units"],
        ])
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(ShareSearchResponse.self, from: data) else {
            failed = true
            return
        }
        answer = ShareAnswer(decoded)
    }

    /// Selected text first; otherwise the shared page's title, then its URL.
    private static func sharedText(from items: [NSExtensionItem]) async -> String {
        for item in items {
            for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String,
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return String(text.prefix(200))
                }
            }
        }
        for item in items {
            if let title = item.attributedContentText?.string, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return String(title.prefix(200))
            }
            for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                    return url.host() ?? url.absoluteString
                }
            }
        }
        return ""
    }
}

/// What the sheet shows: a label, the big answer, and its source.
struct ShareAnswer {
    let label: String
    let headline: String
    let detail: String
    let source: String

    init(_ response: ShareSearchResponse) {
        let top = response.results.first
        if let instant = response.instant {
            label = instant.label
            headline = instant.value
            detail = [instant.title, instant.detail ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
            source = "Worked out by Find"
        } else if let conversion = response.conversion {
            label = "Conversion"
            headline = "\(Self.number(conversion.outputAmount)) \(conversion.outputUnit)"
            detail = "\(Self.number(conversion.inputAmount)) \(conversion.inputUnit)"
            source = conversion.source ?? "Find"
        } else if let text = response.answer?.text, !text.isEmpty {
            label = "Result"
            headline = response.query
            detail = text
            source = response.answer?.references.first?.displayUrl ?? ""
        } else {
            label = "Top result"
            headline = top?.title ?? response.query
            detail = top?.answer ?? top?.summary ?? ""
            source = top?.displayUrl ?? ""
        }
    }

    private static func number(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

struct ShareSearchResponse: Decodable {
    struct Instant: Decodable { let label: String; let value: String; let title: String; let detail: String? }
    struct Conversion: Decodable { let inputAmount: Double; let inputUnit: String; let outputAmount: Double; let outputUnit: String; let source: String? }
    struct Reference: Decodable { let displayUrl: String }
    struct Answer: Decodable { let text: String; let references: [Reference] }
    struct Result: Decodable { let title: String; let summary: String; let answer: String?; let displayUrl: String }

    let query: String
    let results: [Result]
    let answer: Answer?
    let instant: Instant?
    let conversion: Conversion?
}
