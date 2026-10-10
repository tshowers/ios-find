import SwiftUI

/// Colors the words of `query` red inside `text`. Port of the web app's
/// `highlightTerms()` in find-home.component.ts: case-insensitive, only query
/// words longer than 2 characters count, and whole words only, so
/// "RunningShoeGeeks" isn't partly lit. A trailing "s"/"es" is optional
/// either way: "shoes" also lights "shoe".
func highlighted(_ text: String, query: String) -> AttributedString {
    var attributed = AttributedString(text)
    let stems = query.split(whereSeparator: \.isWhitespace)
        .map(String.init)
        .filter { $0.count > 2 }
        .map { $0.hasSuffix("s") || $0.hasSuffix("S") ? String($0.dropLast()) : $0 }
    guard !stems.isEmpty else { return attributed }

    let alternatives = stems.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
    guard let regex = try? NSRegularExpression(pattern: "\\b(?:\(alternatives))(?:e?s)?\\b", options: .caseInsensitive) else {
        return attributed
    }
    for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
        guard let stringRange = Range(match.range, in: text),
              let range = Range(stringRange, in: attributed) else { continue }
        attributed[range].foregroundColor = Theme.highlightRed
        attributed[range].inlinePresentationIntent = .stronglyEmphasized
    }
    return attributed
}
