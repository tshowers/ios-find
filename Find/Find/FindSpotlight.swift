import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// Find in iPhone search (Spotlight): recent searches, each with its top
/// answer, and watched finds. Tapping one runs that search in Find
/// (SearchView's onContinueUserActivity). Everything stays on the device.
enum FindSpotlight {
    private static let searchDomain = "tech.taliferro.find.search"
    private static let watchDomain = "tech.taliferro.find.watch"
    private static let searchPrefix = "search:"
    private static let watchPrefix = "watch:"
    // IDs are lowercased: History treats "Coffee" and "coffee" as one search.

    /// A recent search, described by the same answer Siri's card shows.
    static func indexSearch(_ query: String, response: FindSearchResponse) {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = query
        if let answer = FindSiriAnswer(response: response) {
            let description = [answer.title, answer.detail].filter { !$0.isEmpty && $0 != query }.joined(separator: " · ")
            attributes.contentDescription = String(description.prefix(300))
            attributes.keywords = Array(answer.keywords.prefix(8))
        }
        let item = CSSearchableItem(uniqueIdentifier: searchPrefix + query.lowercased(), domainIdentifier: searchDomain, attributeSet: attributes)
        CSSearchableIndex.default().indexSearchableItems([item])
    }

    /// Searches that dropped out of History.
    static func removeSearches(_ queries: [String]) {
        guard !queries.isEmpty else { return }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: queries.map { searchPrefix + $0.lowercased() })
    }

    static func removeAllSearches() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [searchDomain])
    }

    private static var indexedWatches: [String] = []

    /// Replaces the watched finds in Spotlight with this list (skipping a
    /// refresh that changed nothing Spotlight shows).
    static func indexWatches(_ watches: [FindWatch]) {
        let current = watches.filter { !$0.expired }
        let signature = current.map { "\($0.id)|\($0.query)|\($0.title)|\($0.lastChange?.summary ?? "")" }
        guard signature != indexedWatches else { return }
        indexedWatches = signature
        let items = current.map { watch in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = watch.query
            attributes.contentDescription = ["Watching in Find", watch.title, watch.lastChange?.summary]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
            return CSSearchableItem(uniqueIdentifier: watchPrefix + watch.query.lowercased(), domainIdentifier: watchDomain, attributeSet: attributes)
        }
        let index = CSSearchableIndex.default()
        index.deleteSearchableItems(withDomainIdentifiers: [watchDomain]) { _ in
            if !items.isEmpty { index.indexSearchableItems(items) }
        }
    }

    /// The search to run for a tapped Spotlight result.
    static func query(for activity: NSUserActivity) -> String? {
        guard let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return nil }
        for prefix in [searchPrefix, watchPrefix] where id.hasPrefix(prefix) {
            let query = String(id.dropFirst(prefix.count))
            return query.isEmpty ? nil : query
        }
        return nil
    }
}
