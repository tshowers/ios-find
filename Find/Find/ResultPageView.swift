import SwiftUI
import NaturalLanguage

/// One page of Find's multi-result answer view, computed entirely from an
/// explicit `pageIndex` rather than "whatever is currently selected" - the
/// same shape as Network iOS's `ContactCardView(card:)`. That's what lets
/// `FindResultPageCurlView`'s `UIPageViewController` data source pre-build
/// the neighboring "before"/"after" pages for a real page-curl swipe,
/// independent of which page is on screen.
struct ResultPageView: View {
    let response: FindSearchResponse
    let pageIndex: Int
    let screenWidth: CGFloat

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if let heroURL = heroImageURL {
                    heroImageView(url: heroURL)
                }

                VStack(alignment: .leading, spacing: 18) {
                    Text(eyebrow)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Theme.accent)

                    Text(businessName)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Theme.text)

                    if !businessAddress.isEmpty {
                        Text(businessAddress)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.subtext)
                    }

                    if !businessMeta.isEmpty, let urlString = result?.url, let url = URL(string: urlString) {
                        HStack(spacing: 12) {
                            ForEach(businessMeta, id: \.self) { item in
                                Link(item, destination: url)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }

                    if let sourceURL = sourceDisplayURL {
                        Text(sourceURL)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.subtext)
                    }

                    if let hours = businessHours {
                        hoursCard(hours)
                    }

                    if !hoursFromSummary {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(answerParagraphs, id: \.self) { paragraph in
                                Text(paragraph)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.subtext)
                                    .lineSpacing(6)
                            }
                        }
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 18)
                .offset(y: heroImageURL == nil ? 18 : -8)

                referencesSection
                    .padding(.top, heroImageURL == nil ? 18 : -8)

                if let resultMetaText {
                    Text(resultMetaText)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subtext)
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                }

                Spacer(minLength: 18)
            }
            .frame(width: screenWidth)
            .padding(.bottom, 150)
        }
    }

    // MARK: - This page's result

    private var result: FindRankedResult? {
        response.results[safe: pageIndex]
    }

    // Page -1 is a dedicated leading slide for the backend's own generated
    // answer - see FindResultPageCurlView's `hasLeadingAnswer` - so it never
    // co-opts a real ranked result's slot; page 0..<results.count always
    // shows that result's own title/summary/source, same as the grid does.
    private var isGroundedAnswerSlide: Bool {
        pageIndex == -1
    }

    private var eyebrow: String {
        isGroundedAnswerSlide ? "ANSWER" : "RESULT \(pageIndex + 1)"
    }

    private var sourceDisplayURL: String? {
        guard !isGroundedAnswerSlide else { return nil }
        let displayUrl = result?.displayUrl ?? ""
        return displayUrl.isEmpty ? nil : displayUrl
    }

    // MARK: - Hero image

    private var heroImageURL: URL? {
        if let fallback = fallbackHeroImageURL {
            return fallback
        }
        if isGroundedAnswerSlide {
            if let image = response.answer?.imageUrl, !image.isEmpty, let url = URL(string: image) {
                return url
            }
            return nil
        }
        if let image = result?.imageUrl, !image.isEmpty, let url = URL(string: image) {
            return url
        }
        if let image = response.answer?.imageUrl, !image.isEmpty, let url = URL(string: image) {
            return url
        }
        return nil
    }

    private var fallbackHeroImageURL: URL? {
        let searchText = [response.query, response.normalizedQuery, response.answer?.text, result?.title]
            .compactMap { $0 }.joined(separator: " ").lowercased()
        guard searchText.range(of: #"\b(sports?|nfl|nba|wnba|mlb|nhl|soccer|football|basketball|baseball|hockey)\b"#, options: .regularExpression) != nil else {
            return nil
        }
        return URL(string: "https://find.taliferro.tech/fallback/find-sports.png")
    }

    private func heroImageView(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            default:
                Rectangle()
                    .fill(Theme.surface)
            }
        }
        .frame(maxWidth: screenWidth, maxHeight: UIScreen.main.bounds.height * 0.42)
        .frame(width: screenWidth)
        .background(Theme.surface)
    }

    // MARK: - References (grounded-answer page only)

    @ViewBuilder
    private var referencesSection: some View {
        if isGroundedAnswerSlide, let references = response.answer?.references, !references.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("References")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text("\(references.count) SOURCES")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.subtext)
                }

                VStack(spacing: 10) {
                    ForEach(references) { reference in
                        Button {
                            if let url = URL(string: reference.url) {
                                openURL(url)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reference.displayUrl)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.accent)
                                Text(reference.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
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

    private var businessTitleParts: (name: String, address: String, meta: [String]) {
        let fullTitle = (result?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let segments = fullTitle.components(separatedBy: " - ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard segments.count > 1,
              let addressIndex = segments.firstIndex(where: { segment in
                  guard let first = segment.first else { return false }
                  return first.isNumber && segment.contains(",")
              }), addressIndex > 0 else {
            return (fullTitle, "", [])
        }

        let metadata = segments[segments.index(after: segments.startIndex)..<addressIndex]
            .flatMap { $0.components(separatedBy: " & ") }
            .filter { item in
                item.range(of: "updated|photos?|reviews?", options: [.caseInsensitive, .regularExpression]) != nil
            }
        return (segments[0], segments[addressIndex], metadata)
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
                Text("Hours")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.text)
                Spacer()
                if let statusText = hours.statusText, !statusText.isEmpty {
                    Text(statusText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(hours.isOpenNow == true ? .green : .red)
                } else if let isOpenNow = hours.isOpenNow {
                    Text(isOpenNow ? "Open now" : "Closed now")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isOpenNow ? .green : .red)
                } else if let status = currentHoursStatus(hours) {
                    Text(status.text)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(status.isOpen ? .green : .red)
                }
            }
            .padding(.bottom, 8)

            ForEach(Array(hours.days.enumerated()), id: \.offset) { index, day in
                HStack(alignment: .top, spacing: 10) {
                    Text(day.day)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle( isToday(day.day) ? Theme.accent : Theme.text )
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
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.subtext)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 9)
                .background(isToday(day.day) ? Theme.accent.opacity(0.08) : .clear)
                .overlay(alignment: .top) {
                    if index > 0 { Rectangle().fill(Theme.border).frame(height: 1) }
                }
            }

            ForEach(hours.holidayNotes ?? [], id: \.self) { note in
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.subtext)
                    .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.vertical, 4)
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
