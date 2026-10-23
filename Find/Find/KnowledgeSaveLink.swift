import Foundation

/// "Save to Knowledge" (saveToKnowledgeAction in find-home.component.ts):
/// Docs' /knowledge/save with a result filled in. Docs signs the person in
/// if needed and saves it free; editing it needs Docs. Shared by the Save
/// tile on result pages and the "Save that to Knowledge" Siri intent.
enum KnowledgeSaveLink {
    static func url(query: String, title: String, answer: String, sourceURL: String, keywords: [String]) -> URL? {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        let answer = answer
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let keywords = keywords
            .filter { $0.lowercased() != query.lowercased() && $0.range(of: #"^\d+(\.\d+)?\s*mi$|^★"#, options: .regularExpression) == nil }
            .prefix(8)
        var link = URLComponents(string: "https://docs.taliferro.tech/knowledge/save")!
        link.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "answer", value: String(answer.prefix(1500))),
            URLQueryItem(name: "url", value: sourceURL),
            URLQueryItem(name: "keywords", value: keywords.joined(separator: ",")),
        ]
        return link.url
    }
}
