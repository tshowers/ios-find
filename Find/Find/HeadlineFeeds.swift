import Foundation

/// News/Sports headlines from feeds that block Find's cloud servers (so the
/// backend's hourly RSS job can't read them), fetched on the phone and
/// merged into the backend's RSS headlines (searchFindRss in todd-backend
/// findRss.service.js; the web's headline-feeds.service.ts does the same
/// for ESPN). Any failure just means no extra headlines.
actor HeadlineFeeds {
    enum Section {
        case news
        case sports
    }

    private struct Feed {
        let source: String
        let url: URL
    }

    static let shared = HeadlineFeeds()

    private static let feeds: [Section: [Feed]] = [
        .sports: [
            Feed(source: "ESPN", url: URL(string: "https://www.espn.com/espn/rss/news")!),
            Feed(source: "ESPN", url: URL(string: "https://www.espn.com/espn/rss/nfl/news")!),
            Feed(source: "ESPN", url: URL(string: "https://www.espn.com/espn/rss/mlb/news")!),
            Feed(source: "NPR", url: URL(string: "https://feeds.npr.org/1055/rss.xml")!),
        ],
        .news: [
            Feed(source: "NPR", url: URL(string: "https://feeds.npr.org/1001/rss.xml")!),
        ],
    ]

    private static let fetchTimeout: TimeInterval = 4
    private static let cacheSeconds: TimeInterval = 10 * 60
    // Same as the backend's MAX_ARTICLE_AGE_MS and its 20-headline page.
    private static let maxAge: TimeInterval = 7 * 24 * 60 * 60
    private static let maxHeadlines = 20
    // ESPN posts so often it would fill all 20; each added source gets its 6 newest.
    private static let maxPerAddedSource = 6
    // Added stories without a photo go last, and take at most 6 of the 20.
    private static let maxWithoutPhoto = 6

    private var cache: [Section: (at: Date, items: [FindRankedResult])] = [:]

    /// The backend's rssSectionForQuery: which queries are served as headlines.
    static func section(for query: String) -> Section? {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: #"[?.!]+$"#, with: "", options: .regularExpression)
        if normalized == "news" || normalized.range(of: #"^(today'?s|latest|current) news$"#, options: .regularExpression) != nil {
            return .news
        }
        if normalized.range(of: #"^(sports?|sports news)$"#, options: .regularExpression) != nil {
            return .sports
        }
        return nil
    }

    /// Headlines for this section from the on-device feeds (cached 10 minutes).
    func extraHeadlines(for section: Section?) async -> [FindRankedResult] {
        guard let section, let feeds = Self.feeds[section] else { return [] }
        if let cached = cache[section], Date().timeIntervalSince(cached.at) < Self.cacheSeconds {
            return cached.items
        }
        let items = await withTaskGroup(of: [FindRankedResult].self) { group in
            for feed in feeds {
                group.addTask { await Self.fetch(feed) }
            }
            var all: [FindRankedResult] = []
            for await list in group { all += list }
            return all
        }
        // Don't keep an empty result (e.g. offline) for the full 10 minutes.
        if !items.isEmpty { cache[section] = (Date(), items) }
        return items
    }

    /// Backend headlines plus extra ones (6 newest per source): no duplicate
    /// links, newest first, 20 at most. Added stories without a photo
    /// (ESPN's feeds have none) go after the ones with photos.
    static func merge(_ response: FindSearchResponse, extra: [FindRankedResult]) -> FindSearchResponse {
        guard !extra.isEmpty else { return response }
        // Drop duplicates first: ESPN's top and NFL feeds share stories.
        var seen = Set(response.results.map(\.url))
        var perSource: [String: Int] = [:]
        let added = extra
            .filter { seen.insert($0.url).inserted }
            .sorted { ($0.publishedAt ?? "") > ($1.publishedAt ?? "") }
            .filter { result in
                let count = perSource[result.rssSource ?? "", default: 0]
                perSource[result.rssSource ?? ""] = count + 1
                return count < maxPerAddedSource
            }
        let cutoff = Date().addingTimeInterval(-maxAge)
        func newestFirst(_ list: [FindRankedResult]) -> [FindRankedResult] {
            list
                .filter { result in
                    guard let published = result.publishedAt.flatMap(isoDate) else { return true }
                    return published >= cutoff
                }
                .sorted { ($0.publishedAt ?? "") > ($1.publishedAt ?? "") }
        }
        let last = Array(newestFirst(added.filter { $0.imageUrl.isEmpty }).prefix(maxWithoutPhoto))
        let first = newestFirst(response.results + added.filter { !$0.imageUrl.isEmpty })
            .prefix(max(0, maxHeadlines - last.count))
        let results = (Array(first) + last)
            .prefix(maxHeadlines)
            .enumerated()
            .map { index, result in result.withRank(index + 1) }

        var merged = FindSearchResponse(
            success: response.success,
            query: response.query,
            normalizedQuery: response.normalizedQuery,
            queryType: response.queryType,
            handoff: response.handoff,
            answer: response.answer,
            weather: response.weather,
            conversion: response.conversion,
            movieRatings: response.movieRatings,
            results: Array(results),
            selectedIndex: 0,
            timings: response.timings,
            rssBacked: response.rssBacked
        )
        merged.instant = response.instant
        return merged
    }

    private static func fetch(_ feed: Feed) async -> [FindRankedResult] {
        var request = URLRequest(url: feed.url, timeoutInterval: fetchTimeout)
        request.setValue("application/rss+xml, application/atom+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              !data.isEmpty else { return [] }
        return FeedParser(source: feed.source).parse(data)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func isoDate(_ string: String) -> Date? {
        isoFormatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    static func isoString(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }
}

/// RSS/Atom items as headline results, like the backend's parseFeed.
private final class FeedParser: NSObject, XMLParserDelegate {
    private let source: String
    private var results: [FindRankedResult] = []
    private var item: [String: String]?
    private var text = ""

    init(source: String) {
        self.source = source
    }

    func parse(_ data: Data) -> [FindRankedResult] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { return results }
        return results
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String] = [:]) {
        let name = Self.localName(elementName)
        if name == "item" || name == "entry" {
            item = [:]
            return
        }
        guard item != nil else { return }
        text = ""
        if name == "link", let href = attributes["href"], item?["link"] == nil {
            item?["link"] = href
        }
        if ["content", "thumbnail", "enclosure"].contains(name), item?["image"] == nil,
           let url = attributes["url"] ?? attributes["href"],
           name != "enclosure" || (attributes["type"] ?? "image/").hasPrefix("image/"),
           !Self.isTrackingPixel(url) {
            item?["image"] = url
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(data: CDATABlock, encoding: .utf8) ?? ""
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = Self.localName(elementName)
        guard var current = item else { return }
        if name == "item" || name == "entry" {
            if let result = makeResult(current) { results.append(result) }
            item = nil
            return
        }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty, current[name] == nil {
            current[name] = value
        }
        item = current
        text = ""
    }

    private func makeResult(_ fields: [String: String]) -> FindRankedResult? {
        let title = Self.stripMarkup(fields["title"] ?? "")
        let url = fields["link"] ?? ""
        guard !title.isEmpty, url.lowercased().hasPrefix("http") else { return nil }
        let published = [fields["pubDate"], fields["published"], fields["updated"], fields["date"]]
            .compactMap { $0 }
            .lazy
            .compactMap(Self.parseDate)
            .first ?? Date()
        let markup = fields["encoded"] ?? fields["description"] ?? ""
        let image = fields["image"] ?? Self.firstImage(in: markup) ?? ""
        return FindRankedResult(
            headlineTitle: title,
            summary: Self.stripMarkup(fields["description"] ?? fields["summary"] ?? ""),
            url: url,
            imageUrl: image,
            source: source,
            publishedAt: HeadlineFeeds.isoString(published)
        )
    }

    private static func localName(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }

    /// NPR's only <img> is a tracking pixel.
    private static func isTrackingPixel(_ url: String) -> Bool {
        url.contains("/tracking/") || url.contains("rss-pixel")
    }

    private static func firstImage(in markup: String) -> String? {
        guard let range = markup.range(of: #"<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["']"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let tag = String(markup[range])
        guard let src = tag.range(of: #"(?<=src=["'])[^"']+"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let url = String(tag[src])
        return isTrackingPixel(url) ? nil : url
    }

    private static func stripMarkup(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let rfc822Formats = [
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "EEE, d MMM yyyy HH:mm:ss zzz",
        "EEE, d MMM yyyy HH:mm:ss Z",
    ].map { format -> DateFormatter in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    private static func parseDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let iso = HeadlineFeeds.isoDate(trimmed) { return iso }
        return rfc822Formats.lazy.compactMap { $0.date(from: trimmed) }.first
    }
}
