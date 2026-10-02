import Combine
import SwiftUI
import UIKit

// Shared pieces of the result-page redesign, ported from the web app's
// find-home component (see web-products/find
// docs/design_handoff_find_results/README.md, iPhone screens 2i-2k, 3i-3l).

// MARK: - Feedback

/// One-row "Right find?" feedback. Remembers which queries were rated this
/// session so the row turns into a thank-you instead of asking again.
@MainActor
final class FindFeedbackStore: ObservableObject {
    @Published private(set) var sentQueries: Set<String> = []
    private let apiClient: FindAPIClient

    init(apiClient: FindAPIClient) {
        self.apiClient = apiClient
    }

    func isSent(_ query: String) -> Bool {
        sentQueries.contains(Self.key(query))
    }

    func send(_ rating: FindFeedbackRating, query: String, queryType: FindQueryType) {
        let key = Self.key(query)
        guard !key.isEmpty, !sentQueries.contains(key) else { return }
        sentQueries.insert(key)
        let request = FindFeedbackRequest(rating: rating, comment: nil, query: query, queryType: queryType.rawString)
        Task { try? await apiClient.submitFeedback(request) }
    }

    private static func key(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct FindFeedbackRow: View {
    @ObservedObject var store: FindFeedbackStore
    let query: String
    let queryType: FindQueryType
    var meta: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if store.isSent(query) {
                    Text("Thanks for the feedback.")
                        .font(Theme.font(13))
                        .foregroundStyle(Theme.muted)
                } else {
                    Text("Right find?")
                        .font(Theme.font(13))
                        .foregroundStyle(Theme.muted)
                        .padding(.trailing, 4)
                    ForEach(FindFeedbackRating.allCases, id: \.self) { rating in
                        Button {
                            store.send(rating, query: query, queryType: queryType)
                        } label: {
                            Text(rating.label)
                                .font(Theme.font(13, weight: .semibold))
                                .foregroundStyle(Theme.text)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.surface, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if let meta, !meta.isEmpty {
                Text(meta)
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tag

struct FindTag: View {
    let text: String
    let background: Color
    let foreground: Color
    var small = false

    var body: some View {
        Text(text)
            .font(Theme.font(small ? 12 : 13, weight: .semibold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, small ? 10 : 12)
            .padding(.vertical, small ? 4 : 5)
            .background(background, in: Capsule())
    }
}

// MARK: - Action tiles

/// One quick action on a result. Phones show `shortLabel` under the icon.
struct FindAction: Identifiable {
    enum Kind {
        case open(URL)
        case copy(String)
    }

    let id: String
    let shortLabel: String
    let systemImage: String
    let kind: Kind
}

/// One row of equal tiles; the first action is primary (blue).
struct FindActionTiles: View {
    let actions: [FindAction]
    @State private var copiedID: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                let isPrimary = index == 0
                let copied = copiedID == action.id
                Button {
                    perform(action)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: copied ? "checkmark" : action.systemImage)
                            .font(.system(size: 22, weight: .regular))
                            .frame(height: 26)
                        Text(copied ? "Copied" : action.shortLabel)
                            .font(Theme.font(12, weight: .semibold))
                    }
                    .foregroundStyle(isPrimary ? Color.white : Theme.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 66)
                    .background(isPrimary ? Theme.blue : Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func perform(_ action: FindAction) {
        switch action.kind {
        case .open(let url):
            openURL(url)
        case .copy(let text):
            UIPasteboard.general.string = text
            copiedID = action.id
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                if copiedID == action.id { copiedID = nil }
            }
        }
    }
}

// MARK: - Pager pieces

/// 20-style progress segments: filled up to the current result, cycling the
/// logo colours; the current one is wider.
struct FindProgressSegments: View {
    let count: Int
    /// -1 when no ranked result is current (the leading answer slide).
    let current: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Theme.logoColors[index % Theme.logoColors.count] : Theme.surface2)
                    .frame(width: index == current ? 18 : 6, height: 6)
            }
        }
        .animation(.easeOut(duration: 0.2), value: current)
    }
}

struct FindPagerCircle: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.text)
            .frame(width: 44, height: 44)
            .background(Theme.surface, in: Circle())
    }
}

// MARK: - Helpers

enum FindFormat {
    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso = ISO8601DateFormatter()

    static func date(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return isoFractional.date(from: value) ?? iso.date(from: value)
    }

    /// "just now", "12m ago", "4h ago", "Yesterday", then a short date.
    static func relativeTime(_ value: String?, now: Date = Date()) -> String? {
        guard let date = date(value) else { return nil }
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func shortTime(_ value: String?) -> String? {
        date(value)?.formatted(date: .omitted, time: .shortened)
    }

    static func shortDateTime(_ value: String?) -> String? {
        date(value)?.formatted(date: .numeric, time: .shortened)
    }
}

/// SF Symbol and logo-colour tone for a weather condition.
func findWeatherSymbol(_ condition: String) -> (name: String, color: Color) {
    let text = condition.lowercased()
    func has(_ pattern: String) -> Bool { text.range(of: pattern, options: .regularExpression) != nil }
    if has("thunder|storm") { return ("cloud.bolt.rain.fill", Theme.blue) }
    if has("snow|sleet|flurr|ice|blizzard") { return ("snowflake", Theme.cyan) }
    if has("rain|shower|drizzle") { return ("cloud.rain.fill", Theme.blue) }
    if has("fog|haze|smoke|mist") { return ("cloud.fog.fill", Theme.muted) }
    if has("partly|mostly sunny|mostly clear") { return ("cloud.sun.fill", Theme.yellow) }
    if has("sun|clear|fair") { return ("sun.max.fill", Theme.yellow) }
    return ("cloud.fill", Theme.muted)
}

extension FindQueryType {
    var rawString: String {
        switch self {
        case .entity: return "entity"
        case .question: return "question"
        case .person: return "person"
        case .weather: return "weather"
        case .conversion: return "conversion"
        case .local: return "local"
        case .movie: return "movie"
        case .sports: return "sports"
        case .news: return "news"
        case .unknown(let raw): return raw
        }
    }
}

extension FindSearchResponse {
    var isHeadline: Bool {
        rssBacked == true || queryType == .sports || queryType == .news
    }

    /// A movie answer: OMDb details and no ranked results.
    var movie: FindMovieRatings? {
        queryType == .movie ? movieRatings : nil
    }

    var isNewsHeadline: Bool {
        queryType == .news
    }

    /// "From CBS Sports, BBC Sport and Sky Sports · updated hourly"
    var headlineAttribution: String {
        var seen = Set<String>()
        let sources = results.compactMap { $0.rssSource?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        guard let last = sources.last else { return "Updated hourly" }
        let list = sources.count == 1 ? last : sources.dropLast().joined(separator: ", ") + " and " + last
        return "From \(list) · updated hourly"
    }
}
