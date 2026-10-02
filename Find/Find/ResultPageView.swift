import SwiftUI
import NaturalLanguage

/// One page of Find's multi-result answer view, computed entirely from an
/// explicit `pageIndex` rather than "whatever is currently selected" - the
/// same shape as Network iOS's `ContactCardView(card:)`. That's what lets
/// `FindResultPagerView`'s `UIPageViewController` data source pre-build
/// the neighboring "before"/"after" pages for a real swipe,
/// independent of which page is on screen.
struct ResultPageView: View {
    let response: FindSearchResponse
    let pageIndex: Int
    let screenWidth: CGFloat
    let feedbackStore: FindFeedbackStore
    /// Advances to the next page (the headline "Next" preview card).
    var onNext: (() -> Void)?

    @Environment(\.openURL) private var openURL
    @State private var ownImageFailed = false

    private enum ImageState { case own, fallback, none }

    var body: some View {
        ScrollView(showsIndicators: false) {
            Group {
                if let movie = response.movie {
                    movieContent(movie)
                } else {
                    standardContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(width: screenWidth)
            .padding(.bottom, 150)
        }
    }

    private var standardContent: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Image rule: the result's own image takes the hero spot,
                // Find's default artwork is only ever a small thumbnail, and
                // with no image the text takes the width.
                if imageState == .own, let ownImageURL {
                    resultLink {
                        heroImageView(url: ownImageURL)
                    }
                }

                if response.isHeadline {
                    headlineHeader
                } else {
                    if imageState == .fallback, let fallbackImageURL {
                        thumbnail(url: fallbackImageURL)
                    }
                    sourceRow
                }

                resultLink {
                    Text(businessName)
                        .font(Theme.font(response.isHeadline ? 30 : 32, weight: .bold))
                        .tracking(-0.9)
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !businessAddress.isEmpty {
                    Text(businessAddress)
                        .font(Theme.font(14))
                        .foregroundStyle(Theme.muted)
                }

                if !businessMeta.isEmpty, let urlString = result?.url, let url = URL(string: urlString) {
                    HStack(spacing: 12) {
                        ForEach(businessMeta, id: \.self) { item in
                            Link(item, destination: url)
                                .font(Theme.font(12, weight: .semibold))
                                .foregroundStyle(Theme.blueInk)
                        }
                    }
                }

                if !response.isHeadline, !actions.isEmpty {
                    FindActionTiles(actions: actions)
                }

                if let hours = businessHours {
                    hoursCard(hours)
                }

                if !hoursFromSummary {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(answerParagraphs, id: \.self) { paragraph in
                            Text(paragraph)
                                .font(Theme.font(16))
                                .foregroundStyle(Theme.text)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if response.isHeadline, !actions.isEmpty {
                    FindActionTiles(actions: actions)
                }

                if response.isHeadline, let next = response.results[safe: pageIndex + 1] {
                    nextPreview(next)
                }

                referencesSection

                FindFeedbackRow(
                    store: feedbackStore,
                    query: response.query,
                    queryType: response.queryType,
                    meta: response.isHeadline ? response.headlineAttribution : resultMetaText
                )
                .padding(.top, 8)
            }
    }

    // MARK: - Movie (2f, phone)

    /// Poster in the hero spot (image rule), then year · rating · runtime,
    /// title, rating pills, plot, director / starring, and IMDb / Copy link.
    private func movieContent(_ movie: FindMovieRatings) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let posterURL = moviePosterURL(movie) {
                AsyncImage(url: posterURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color.clear.onAppear { ownImageFailed = true }
                    default:
                        Theme.surface2
                    }
                }
                .frame(width: 200, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityLabel("\(movie.title) poster")
            }

            let eyebrow = [movie.year, movie.rated, movie.runtime].compactMap { $0 }.filter { !$0.isEmpty }
            if !eyebrow.isEmpty {
                FindTag(text: eyebrow.joined(separator: " · "), background: Theme.tViolet, foreground: Theme.tVioletFg)
            }

            Text(movie.title)
                .font(Theme.font(32, weight: .bold))
                .tracking(-0.9)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)

            let ratings = movieRatingPills(movie)
            if !ratings.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ratings, id: \.source) { rating in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(rating.source)
                                    .font(Theme.font(12, weight: .bold))
                                    .foregroundStyle(Theme.muted)
                                Text(rating.score)
                                    .font(Theme.font(18, weight: .bold))
                                    .foregroundStyle(Theme.text)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Theme.surface, in: Capsule())
                        }
                    }
                }
            }

            if let plot = movie.plot, !plot.isEmpty {
                Text(plot)
                    .font(Theme.font(16))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                movieFact("Director", movie.director)
                movieFact("Starring", movie.actors)
                movieFact("Genre", movie.genre)
            }

            let movieActions = movieActions(movie)
            if !movieActions.isEmpty {
                FindActionTiles(actions: movieActions)
            }

            FindFeedbackRow(
                store: feedbackStore,
                query: response.query,
                queryType: response.queryType,
                meta: "Ratings via OMDb (IMDb, Rotten Tomatoes, Metacritic)"
            )
            .padding(.top, 8)
        }
    }

    private func moviePosterURL(_ movie: FindMovieRatings) -> URL? {
        guard !ownImageFailed, let poster = movie.posterUrl, poster.hasPrefix("http") else { return nil }
        return URL(string: poster)
    }

    private func movieRatingPills(_ movie: FindMovieRatings) -> [(source: String, score: String)] {
        [
            movie.imdbRating.map { ("IMDb", "\($0)/10") },
            movie.rottenTomatoesScore.map { ("Rotten Tomatoes", $0) },
            movie.metascore.map { ("Metacritic", "\($0)/100") },
        ].compactMap { $0 }.filter { !$0.1.isEmpty }
    }

    @ViewBuilder
    private func movieFact(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label.uppercased())
                    .font(Theme.font(12, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
                    .frame(width: 84, alignment: .leading)
                Text(value)
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func movieActions(_ movie: FindMovieRatings) -> [FindAction] {
        guard let id = movie.imdbId, !id.isEmpty,
              let url = URL(string: "https://www.imdb.com/title/\(id)/") else { return [] }
        return [
            FindAction(id: "imdb", shortLabel: "IMDb", systemImage: "arrow.up.right.square", kind: .open(url)),
            FindAction(id: "copy-link", shortLabel: "Copy", systemImage: "doc.on.doc", kind: .copy(url.absoluteString)),
        ]
    }

    // MARK: - This page's result

    private var result: FindRankedResult? {
        response.results[safe: pageIndex]
    }

    // Page -1 is a dedicated leading slide for the backend's own generated
    // answer - see FindResultPagerView's `hasLeadingAnswer` - so it never
    // co-opts a real ranked result's slot; page 0..<results.count always
    // shows that result's own title/summary/source, same as the grid does.
    private var isGroundedAnswerSlide: Bool {
        pageIndex == -1
    }

    // Same as the web card and the grid tiles: Find takes you to the thing
    // you found. The grounded-answer slide has no `result`, so it renders
    // unlinked.
    private var resultURL: URL? {
        guard !isGroundedAnswerSlide, let urlString = result?.url, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }

    @ViewBuilder
    private func resultLink<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        if let url = resultURL {
            Button {
                openURL(url)
            } label: {
                label()
            }
            .buttonStyle(.plain)
        } else {
            label()
        }
    }

    // MARK: - Source row / headline header

    private static let trustLabels: [FindSourceType: String] = [
        .government: "Verified government site",
        .official: "Verified official site",
        .medical: "Verified medical source",
        .academic: "Verified academic source",
        .encyclopedia: "Encyclopedia",
    ]

    @ViewBuilder
    private var sourceRow: some View {
        if isGroundedAnswerSlide {
            FindTag(text: answerTagText, background: Theme.tGreen, foreground: Theme.tGreenFg)
        } else if let result {
            resultLink {
                HStack(spacing: 10) {
                    if result.isFirstParty {
                        FindTag(text: "Official Taliferro result", background: Theme.tBlue, foreground: Theme.tBlueFg)
                    } else if let trust = Self.trustLabels[result.sourceType] {
                        FindTag(text: "✓ \(trust)", background: Theme.tBlue, foreground: Theme.tBlueFg)
                    }
                    if !result.displayUrl.isEmpty {
                        Text(result.displayUrl)
                            .font(Theme.font(14))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var answerTagText: String {
        let count = response.answer?.references.count ?? 0
        return count > 0 ? "Answer · from \(count) sources" : "Answer"
    }

    /// Thumbnail (when there's no article image) beside the tag and "source · time".
    private var headlineHeader: some View {
        HStack(spacing: 14) {
            if imageState == .fallback, let fallbackImageURL {
                thumbnail(url: fallbackImageURL)
            }
            VStack(alignment: .leading, spacing: 4) {
                if response.isNewsHeadline {
                    FindTag(text: "News", background: Theme.tPink, foreground: Theme.tPinkFg, small: true)
                } else {
                    FindTag(text: "Sports", background: Theme.tCyan, foreground: Theme.tCyanFg, small: true)
                }
                (Text(headlineSource).font(Theme.font(14, weight: .bold)).foregroundColor(Theme.text)
                    + Text(FindFormat.relativeTime(result?.publishedAt).map { " · \($0)" } ?? "")
                    .font(Theme.font(14)).foregroundColor(Theme.muted))
                    .lineLimit(1)
            }
        }
    }

    private var headlineSource: String {
        let source = result?.rssSource?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return source.isEmpty ? (result?.displayUrl ?? "") : source
    }

    private func nextPreview(_ next: FindRankedResult) -> some View {
        Button {
            onNext?()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text((["Next", next.rssSource ?? "", FindFormat.relativeTime(next.publishedAt) ?? ""])
                    .filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.muted)
                Text(next.title)
                    .font(Theme.font(15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    /// Only actions whose data exists. Any result with a link gets Site + Copy;
    /// a place (hours, address, phone, or a local search) also gets Apple Maps
    /// first, plus Call when there's a phone number - Go · Call · Site · Copy.
    private var actions: [FindAction] {
        guard !isGroundedAnswerSlide, let result else { return [] }
        let urlString = result.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: urlString)

        if response.isHeadline {
            guard let url else { return [] }
            return [
                FindAction(id: "read", shortLabel: "Read", systemImage: "arrow.up.right.square", kind: .open(url)),
                FindAction(id: "copy-link", shortLabel: "Copy", systemImage: "doc.on.doc", kind: .copy(urlString)),
            ]
        }

        var actions: [FindAction] = []
        if isPlace, let mapsURL = appleMapsURL {
            actions.append(FindAction(id: "maps", shortLabel: "Go", systemImage: "location.fill", kind: .open(mapsURL)))
        }
        if let phoneURL {
            actions.append(FindAction(id: "call", shortLabel: "Call", systemImage: "phone", kind: .open(phoneURL)))
        }
        if let url, url.scheme?.hasPrefix("http") == true {
            actions.append(FindAction(id: "site", shortLabel: "Site", systemImage: "globe", kind: .open(url)))
            actions.append(FindAction(id: "copy-link", shortLabel: "Copy", systemImage: "doc.on.doc", kind: .copy(urlString)))
        }
        return actions
    }

    private var placeAddress: String {
        let address = result?.address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return address.isEmpty ? businessAddress : address
    }

    private var placePhone: String {
        result?.phone?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var isPlace: Bool {
        response.queryType == .local || businessHours != nil || !placeAddress.isEmpty || !placePhone.isEmpty
    }

    private var phoneURL: URL? {
        let digits = placePhone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
    }

    /// Directions to the address when there is one; otherwise an Apple Maps
    /// search for the place name plus any "City, ST" in the page title.
    private var appleMapsURL: URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        if !placeAddress.isEmpty {
            components?.queryItems = [URLQueryItem(name: "daddr", value: placeAddress)]
        } else {
            let query = mapsSearchQuery
            guard !query.isEmpty else { return nil }
            components?.queryItems = [URLQueryItem(name: "q", value: query)]
        }
        return components?.url
    }

    /// "Young's Restaurant | Seattle, WA | View and Order Online" -> "Young's Restaurant Seattle, WA".
    private var mapsSearchQuery: String {
        let segments = (result?.title ?? "")
            .components(separatedBy: CharacterSet(charactersIn: "|–—"))
            .flatMap { $0.components(separatedBy: " - ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let name = segments.first else { return "" }
        let city = segments.dropFirst().first { $0.range(of: #"^[A-Za-z .'-]+, [A-Z]{2}$"#, options: .regularExpression) != nil }
        return [name, city].compactMap { $0 }.joined(separator: " ")
    }

    // MARK: - Image rule

    private var imageState: ImageState {
        if ownImageURL != nil { return .own }
        if fallbackImageURL != nil { return .fallback }
        return .none
    }

    private var rawImage: String {
        let image = isGroundedAnswerSlide ? response.answer?.imageUrl : result?.imageUrl
        return (image ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The result's own image, when it has one that isn't Find's default artwork.
    private var ownImageURL: URL? {
        guard !ownImageFailed, !rawImage.isEmpty, !Self.isFindFallback(rawImage) else { return nil }
        return URL(string: rawImage)
    }

    /// Find's default artwork for this result - only ever a thumbnail.
    private var fallbackImageURL: URL? {
        if Self.isFindFallback(rawImage) { return URL(string: rawImage) }
        let name: String
        if response.isHeadline {
            name = response.isNewsHeadline ? "find-news.png" : "find-sports.png"
        } else {
            let searchText = [response.query, response.normalizedQuery, response.answer?.text, result?.title]
                .compactMap { $0 }.joined(separator: " ").lowercased()
            guard searchText.range(of: #"\b(sports?|nfl|nba|wnba|mlb|nhl|soccer|football|basketball|baseball|hockey)\b"#, options: .regularExpression) != nil else {
                return nil
            }
            name = "find-sports.png"
        }
        return URL(string: "https://find.taliferro.tech/fallback/\(name)")
    }

    private static func isFindFallback(_ image: String) -> Bool {
        guard let url = URL(string: image) else { return false }
        return url.host == "find.taliferro.tech" && url.path.hasPrefix("/fallback/")
    }

    /// 190pt photo with rounded corners. Cropped, never stretched: the crop
    /// sits 25% down (like CSS `object-position: 50% 25%`) so faces stay in frame.
    private func heroImageView(url: URL) -> some View {
        let width = min(screenWidth, 720) - 32
        let height: CGFloat = screenWidth >= 600 ? 320 : 190
        return Color.clear
            .frame(width: width, height: height)
            .overlay(alignment: Alignment(horizontal: .center, vertical: .heroFocus)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(minWidth: width, minHeight: height)
                    case .failure:
                        Color.clear.onAppear { ownImageFailed = true }
                    default:
                        Rectangle().fill(Theme.surface2)
                            .frame(width: width, height: height)
                    }
                }
                .alignmentGuide(.heroFocus) { $0.height * 0.25 }
            }
            .clipped()
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func thumbnail(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Theme.surface
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityHidden(true)
    }

    // MARK: - References (grounded-answer page only)

    @ViewBuilder
    private var referencesSection: some View {
        if isGroundedAnswerSlide, let references = response.answer?.references, !references.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("REFERENCES")
                    .font(Theme.font(13, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)

                ForEach(references) { reference in
                    Button {
                        if let url = URL(string: reference.url) {
                            openURL(url)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reference.displayUrl)
                                .font(Theme.font(12))
                                .foregroundStyle(Theme.muted)
                            Text(reference.title)
                                .font(Theme.font(15, weight: .semibold))
                                .foregroundStyle(Theme.text)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Result meta line

    private var resultMetaText: String? {
        guard let timings = response.timings else { return nil }

        var parts = [String(format: "%.1fs total", Double(timings.totalMs) / 1000)]
        if timings.candidateCount > 0 {
            parts.append("\(timings.candidateCount) candidates")
        }
        if timings.enrichedCount > 0 {
            parts.append("\(timings.enrichedCount) pages checked")
        }

        if result?.isFirstParty == true {
            parts.append("official Taliferro knowledge")
        } else if let answer = result?.answer, !answer.isEmpty,
                  result?.isFirstParty != true,
                  response.queryType != .question {
            parts.append("TODD summary")
        } else if response.queryType == .question {
            parts.append(isGroundedAnswerSlide ? "grounded answer" : "supporting result")
        }

        return parts.joined(separator: " · ")
    }

    // MARK: - Answer text

    private var answerParagraphs: [String] {
        let candidates: [String?] = isGroundedAnswerSlide ?
            [response.answer?.text] :
            [result?.answer, result?.summary]
        let text = (candidates.compactMap { $0 }.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ) ?? "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return [] }

        let explicit = text.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if explicit.count > 1 { return explicit }

        let sentences = sentenceTokenize(text)
        if sentences.count < 4 { return [text] }

        var paragraphs: [String] = []
        var chunk: [String] = []
        for sentence in sentences {
            chunk.append(sentence)
            if chunk.count == 2 {
                paragraphs.append(chunk.joined(separator: " "))
                chunk.removeAll()
            }
        }
        if !chunk.isEmpty {
            paragraphs.append(chunk.joined(separator: " "))
        }
        return paragraphs
    }

    // NLTokenizer understands sentence-ending punctuation vs. abbreviation
    // periods (e.g. "U.S.", "Dr.") correctly, unlike a naive split on ".".
    private func sentenceTokenize(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }
        return sentences
    }

    // MARK: - Business title / address / hours

    private var title: String {
        if isGroundedAnswerSlide {
            return response.query.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return (result?.title ?? response.query).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var businessName: String {
        businessTitleParts.name.isEmpty ? title : businessTitleParts.name
    }

    private var businessAddress: String {
        businessTitleParts.address
    }

    private var businessMeta: [String] {
        businessTitleParts.meta
    }

    private static let streetAddressPattern = #"^\d{1,6}\s+[\w .'#-]*\b(St|Street|Ave|Avenue|Rd|Road|Blvd|Boulevard|Way|Dr|Drive|Ln|Lane|Pl|Place|Hwy|Highway|Pkwy|Parkway|Ct|Court|Ter|Terrace|Cir|Circle|Sq|Square)\b\.?(\s+(N|S|E|W|NE|NW|SE|SW))?$"#

    private var businessTitleParts: (name: String, address: String, meta: [String]) {
        let fullTitle = (result?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let segments = fullTitle.components(separatedBy: " - ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        // A street address segment: "123 Main St, Seattle, WA", or just
        // "9413 16th Ave SW" when the city comes in its own later segment
        // ("... - Seattle, WA - ..."), as on listing sites like EverOut.
        guard segments.count > 1,
              let addressIndex = segments.firstIndex(where: { segment in
                  guard let first = segment.first, first.isNumber else { return false }
                  return segment.contains(",") || segment.range(of: Self.streetAddressPattern, options: [.regularExpression, .caseInsensitive]) != nil
              }), addressIndex > 0 else {
            return (fullTitle, "", [])
        }

        var address = segments[addressIndex]
        if !address.contains(","),
           let city = segments[(addressIndex + 1)...].first(where: { $0.range(of: #"^[A-Za-z .'-]+, [A-Z]{2}( \d{5})?$"#, options: .regularExpression) != nil }) {
            address += ", \(city)"
        }

        let metadata = segments[segments.index(after: segments.startIndex)..<addressIndex]
            .flatMap { $0.components(separatedBy: " & ") }
            .filter { item in
                item.range(of: "updated|photos?|reviews?", options: [.caseInsensitive, .regularExpression]) != nil
            }
        return (segments[0], address, metadata)
    }

    private var businessHours: FindBusinessHours? {
        if let hours = result?.hours, !hours.days.isEmpty {
            return hours
        }

        // The backend may place provider text in either `answer` or
        // `summary`, depending on which result/enrichment path produced the
        // card. Try both, plus the top-level answer, so this matches the
        // structured-hours fallback used elsewhere in Find.
        let candidates = [result?.answer, result?.summary, response.answer?.text]
        for candidate in candidates {
            if let parsed = parsedHours(from: candidate ?? ""), !parsed.days.isEmpty {
                return parsed
            }
        }
        return nil
    }

    private var hoursFromSummary: Bool {
        result?.hours == nil && businessHours != nil
    }

    private func hoursCard(_ hours: FindBusinessHours) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("HOURS")
                    .font(Theme.font(12, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
                Spacer()
                if let statusText = hours.statusText, !statusText.isEmpty {
                    Text(statusText)
                        .font(Theme.font(12, weight: .bold))
                        .foregroundStyle(hours.isOpenNow == true ? Theme.tGreenFg : .red)
                } else if let isOpenNow = hours.isOpenNow {
                    Text(isOpenNow ? "Open now" : "Closed now")
                        .font(Theme.font(12, weight: .bold))
                        .foregroundStyle(isOpenNow ? Theme.tGreenFg : .red)
                } else if let status = currentHoursStatus(hours) {
                    Text(status.text)
                        .font(Theme.font(12, weight: .bold))
                        .foregroundStyle(status.isOpen ? Theme.tGreenFg : .red)
                }
            }
            .padding(.bottom, 8)

            ForEach(Array(hours.days.enumerated()), id: \.offset) { _, day in
                HStack(alignment: .top, spacing: 10) {
                    Text(day.day)
                        .font(Theme.font(14, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .frame(width: 92, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        if day.isClosed == true {
                            Text("Closed")
                        } else if day.isTwentyFourHours == true {
                            Text("Open 24 hours")
                        } else if day.periods.isEmpty {
                            Text("Hours unavailable")
                        } else {
                            ForEach(Array(day.periods.enumerated()), id: \.offset) { _, period in
                                Text("\(period.open) – \(period.close)")
                            }
                        }
                    }
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.subtext)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 9)
                .padding(.horizontal, 10)
                .background(isToday(day.day) ? Theme.bg : .clear, in: Capsule())
            }

            ForEach(hours.holidayNotes ?? [], id: \.self) { note in
                Text(note)
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.subtext)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func isToday(_ day: String) -> Bool {
        let today = Calendar.current.weekdaySymbols[Calendar.current.component(.weekday, from: Date()) - 1]
        return day.lowercased() == today.lowercased() || day.lowercased() == String(today.prefix(3)).lowercased()
    }

    private func currentHoursStatus(_ hours: FindBusinessHours) -> (text: String, isOpen: Bool)? {
        let today = Calendar.current.weekdaySymbols[Calendar.current.component(.weekday, from: Date()) - 1]
        guard let day = hours.days.first(where: { $0.day.lowercased() == today.lowercased() || $0.day.lowercased() == String(today.prefix(3)).lowercased() }) else { return nil }
        if day.isClosed == true { return ("Closed now", false) }
        if day.isTwentyFourHours == true { return ("Open now", true) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        let nowComponents = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let now = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
        let open = day.periods.contains { period in
            guard let start = formatter.date(from: period.open), let end = formatter.date(from: period.close) else { return false }
            let startComponents = Calendar.current.dateComponents([.hour, .minute], from: start)
            let endComponents = Calendar.current.dateComponents([.hour, .minute], from: end)
            let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
            let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
            return endMinutes < startMinutes ? now >= startMinutes || now <= endMinutes : now >= startMinutes && now <= endMinutes
        }
        return (open ? "Open now" : "Closed now", open)
    }

    private func parsedHours(from text: String) -> FindBusinessHours? {
        let source = text.replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-")
        guard let dayRegex = try? NSRegularExpression(pattern: "(?i)\\b(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun)\\b\\s*[-:]", options: []) else { return nil }
        let nsSource = source as NSString
        let matches = dayRegex.matches(in: source, range: NSRange(location: 0, length: nsSource.length))
        guard !matches.isEmpty else { return nil }

        let timeRegex = try? NSRegularExpression(pattern: "(?i)(\\d{1,2}(?::\\d{2})?\\s*[AP]M)\\s*-\\s*(\\d{1,2}(?::\\d{2})?\\s*[AP]M)", options: [])
        let days: [FindBusinessHoursDay] = matches.enumerated().compactMap { index, match in
            let dayValue = nsSource.substring(with: match.range(at: 1))
            let start = match.range.location + match.range.length
            let end = index + 1 < matches.count ? matches[index + 1].range.location : nsSource.length
            let segment = nsSource.substring(with: NSRange(location: start, length: max(0, end - start)))
            if segment.range(of: "closed", options: .caseInsensitive) != nil {
                return FindBusinessHoursDay(day: normalizedDay(dayValue), periods: [], isClosed: true, isTwentyFourHours: false)
            }
            if segment.range(of: "24 hours", options: .caseInsensitive) != nil || segment.range(of: "open 24", options: .caseInsensitive) != nil {
                return FindBusinessHoursDay(day: normalizedDay(dayValue), periods: [], isClosed: false, isTwentyFourHours: true)
            }
            let periods = timeRegex?.matches(in: segment, range: NSRange(location: 0, length: (segment as NSString).length)).compactMap { periodMatch -> FindBusinessHoursPeriod? in
                guard periodMatch.numberOfRanges >= 3 else { return nil }
                return FindBusinessHoursPeriod(open: (segment as NSString).substring(with: periodMatch.range(at: 1)).replacingOccurrences(of: "  ", with: " "), close: (segment as NSString).substring(with: periodMatch.range(at: 2)).replacingOccurrences(of: "  ", with: " "))
            } ?? []
            return periods.isEmpty ? nil : FindBusinessHoursDay(day: normalizedDay(dayValue), periods: periods, isClosed: false, isTwentyFourHours: false)
        }
        guard !days.isEmpty else { return nil }
        return FindBusinessHours(timezone: nil, isOpenNow: nil, statusText: nil, days: days, holidayNotes: nil, sourceUrl: nil)
    }

    private func normalizedDay(_ value: String) -> String {
        switch value.lowercased().prefix(3) {
        case "mon": return "Monday"
        case "tue": return "Tuesday"
        case "wed": return "Wednesday"
        case "thu": return "Thursday"
        case "fri": return "Friday"
        case "sat": return "Saturday"
        case "sun": return "Sunday"
        default: return value
        }
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension VerticalAlignment {
    /// Lines up the point 25% down the hero photo with the point 25% down
    /// its frame, so the overflow is cropped 25% from the top, 75% from the
    /// bottom.
    private enum HeroFocus: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context.height * 0.25
        }
    }

    static let heroFocus = VerticalAlignment(HeroFocus.self)
}
