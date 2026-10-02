import SwiftUI

/// Colors the words of `query` red inside `text` - the original Find grid's
/// look. Port of the web app's `highlightTerms()` in find-home.component.ts:
/// case-insensitive, and only query words longer than 2 characters count.
func highlighted(_ text: String, query: String) -> AttributedString {
    var attributed = AttributedString(text)
    let words = query.split(whereSeparator: \.isWhitespace)
        .map(String.init)
        .filter { $0.count > 2 }
    guard !words.isEmpty else { return attributed }

    for word in words {
        var searchStart = attributed.startIndex
        while searchStart < attributed.endIndex,
              let range = attributed[searchStart...].range(of: word, options: .caseInsensitive) {
            attributed[range].foregroundColor = Theme.highlightRed
            searchStart = range.upperBound
        }
    }
    return attributed
}
