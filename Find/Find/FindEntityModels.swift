import Foundation

// Single-item results (web: find-experience.service.ts, "FindEntity" and the
// section interfaces). A query that names one thing - a team, a store, a
// restaurant, a local service, a 16Ahead Store shop, a country, state or
// city, a movie or a TV show - gets one card that fills in section by
// section. Every field is optional: a missing one hides its piece of the
// card, never the card.

struct FindEntity: Decodable, Equatable, Identifiable {
    let type: String
    let label: String?
    let id: String
    let name: String
    let logoUrl: String?
    let league: String?
    let abbr: String?
    let shortName: String?
    let links: FindEntityTeamLinks?
    let website: String?
    // 16Ahead Store shops: the shop's own colours.
    let tint: String?
    let tintFg: String?
    let tintDark: String?
    let tintFgDark: String?

    var isBusiness: Bool { ["store", "restaurant", "service"].contains(type) }
    var isRegion: Bool { ["country", "state", "city"].contains(type) }
    var isMedia: Bool { ["movie", "tv"].contains(type) }
    var isMusic: Bool { ["artist", "album", "song"].contains(type) }

    static func == (lhs: FindEntity, rhs: FindEntity) -> Bool {
        lhs.type == rhs.type && lhs.id == rhs.id
    }
}

struct FindEntityTeamLinks: Decodable {
    let espn: String?
    let schedule: String?
    let stats: String?
    let tickets: String?
    let site: String?
    let siteName: String?
}

struct FindEntityDetectRequest: Encodable {
    let query: String
}

struct FindEntityDetectResponse: Decodable {
    let entity: FindEntity?
}

struct FindEntitySectionRequest: Encodable {
    let type: String
    let league: String?
    let id: String
    let section: String
    let latitude: Double?
    let longitude: Double?
}

// MARK: Shared pieces

struct FindStatTile: Decodable, Hashable {
    let label: String
    let value: String
    let sub: String?
}

struct FindKeyFact: Decodable, Hashable {
    let value: String
    let label: String
}

struct FindEntityTag: Decodable, Hashable {
    let text: String
    let tone: String
}

/// A list row the backend has already worded: name left, value right.
struct FindListRow: Decodable, Hashable {
    let name: String
    let value: String?
    let sub: String?
    let url: String?
}

struct FindEntitySummary: Decodable {
    let text: String
    let sources: [String]?
}

// MARK: Teams (NFL, NBA, MLB, college)

struct FindSportsTeamSection: Decodable {
    let record: String?
    let standing: String?
    let division: FindSportsDivision?
    let tags: [FindEntityTag]?
    let tiles: [FindStatTile]?
    let keyFacts: [FindKeyFact]?
    let imageUrl: String?
    let imageAlt: String?
}

struct FindSportsDivision: Decodable {
    let division: String
    let place: Int?
    let rows: [FindSportsDivisionRow]
}

struct FindSportsDivisionRow: Decodable, Hashable {
    let abbr: String?
    let name: String
    let record: String
    let isTeam: Bool?
}

struct FindGameSide: Decodable, Hashable {
    let abbr: String?
    let name: String?
    let score: String?
    let winner: Bool?

    private enum CodingKeys: String, CodingKey { case abbr, name, score, winner }

    // ESPN sends a score as text ("31") or a number; either reads as text.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        abbr = try? container.decodeIfPresent(String.self, forKey: .abbr)
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        winner = try? container.decodeIfPresent(Bool.self, forKey: .winner)
        if let text = try? container.decodeIfPresent(String.self, forKey: .score) {
            score = text
        } else if let number = try? container.decodeIfPresent(Double.self, forKey: .score) {
            score = FindEntityFormat.trim(number)
        } else {
            score = nil
        }
    }
}

struct FindSportsGame: Decodable, Hashable {
    let id: String
    let date: String?
    let state: String?
    let homeAway: String?
    let opponent: String?
    let opponentAbbr: String?
    let home: FindGameSide
    let away: FindGameSide
    let result: String?
    let score: String?
    let network: String?
    let venue: String?
    let recap: String?
    let line: String?
    // Live games only.
    let period: String?
    let clock: String?
    let detail: String?
    let situation: String?
}

struct FindSportsRecentGame: Decodable, Hashable {
    let opponent: String
    let homeAway: String
    let result: String
    let score: String
}

struct FindSportsGamesSection: Decodable {
    let live: FindSportsGame?
    let last: FindSportsGame?
    let next: FindSportsGame?
    let recent: [FindSportsRecentGame]?
}

struct FindLeaderRow: Decodable, Hashable {
    let label: String
    let name: String
    let position: String?
    let stat: String
    let detail: String?
}

struct FindSportsLeadersSection: Decodable {
    let offense: [FindLeaderRow]
    let defense: [FindLeaderRow]
    let offenseTitle: String?
    let defenseTitle: String?
}

struct FindEntityArticle: Decodable, Hashable {
    let headline: String
    let source: String?
    let published: String?
    let url: String
    let imageUrl: String?
}

struct FindEntityNewsSection: Decodable {
    let articles: [FindEntityArticle]
}

// MARK: Stores, restaurants, local services

struct FindPlaceLocation: Decodable, Hashable {
    let name: String?
    let address: String
    let shortAddress: String?
    let city: String?
    let phone: String?
    let distanceMi: Double?
    let openNow: Bool?
    let open24Hours: Bool?
    let nextCloseTime: String?
    let nextOpenTime: String?
    let utcOffsetMinutes: Int?
    let mapsUrl: String?
    let directionsUrl: String?

    /// "111 N State St, Chicago, IL 60602, USA" -> "111 N State St".
    var street: String {
        address.split(separator: ",").first.map(String.init) ?? shortAddress ?? address
    }

    var milesText: String? {
        guard let distanceMi else { return nil }
        return distanceMi < 0.1 ? "under 0.1 mi" : "\(FindEntityFormat.trim(distanceMi)) mi"
    }
}

struct FindPlaceRating: Decodable {
    let value: Double
    let count: Int
}

struct FindPlaceDay: Decodable, Hashable {
    let day: String
    let hours: String
}

struct FindPlaceSection: Decodable {
    let nearest: FindPlaceLocation
    let others: [FindPlaceLocation]?
    let usedPosition: Bool?
    let rating: FindPlaceRating?
    let priceLevel: String?
    let category: String?
    let website: String?
    let hoursWeek: [FindPlaceDay]?
    let serves: [String]?
    let about: String?
    let photoUrl: String?
}

struct FindPlaceDetails: Decodable {
    struct Sale: Decodable, Hashable { let title: String; let discount: String?; let detail: String?; let endsAt: String? }
    struct Dish: Decodable, Hashable { let name: String; let description: String?; let price: String? }
    struct Service: Decodable, Hashable { let name: String; let price: String?; let duration: String? }
    let sales: [Sale]?
    let popular: [Dish]?
    let services: [Service]?
    let menuUrl: String?
}

struct FindSaleSection: Decodable {
    struct Item: Decodable, Hashable { let title: String; let url: String; let imageUrl: String?; let price: String?; let was: String? }
    let items: [Item]
}

// MARK: 16Ahead Store shops

struct FindShopProduct: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let price: String?
    let imageUrl: String?
    let url: String
    let watchUrl: String?
}

struct FindShopSection: Decodable {
    struct Collection: Decodable, Hashable { let name: String; let count: Int? }
    let description: String?
    let heroLine: String?
    let category: String?
    let location: String?
    let productCount: Int?
    let collections: [Collection]?
    let shipping: [String]?
    let freeShippingOver: String?
    let returns: String?
    let products: [FindShopProduct]?
    let url: String
}

// MARK: Countries, states, cities

struct FindRegionSection: Decodable {
    struct Meta: Decodable, Hashable { let label: String; let value: String }
    struct RowList: Decodable, Hashable { let title: String; let rows: [FindListRow] }
    struct Currency: Decodable { let code: String; let rate: Double }
    struct Advisory: Decodable { let level: Int; let text: String; let url: String }
    struct Links: Decodable { let wikipedia: String?; let website: String?; let map: String? }
    let tags: [FindEntityTag]?
    let meta: [Meta]?
    let thumbUrl: String?
    let imageUrl: String?
    let imageAlt: String?
    let tiles: [FindStatTile]?
    let lists: [RowList]?
    let currency: Currency?
    let advisory: Advisory?
    let links: Links?
}

struct FindRegionLocal: Decodable {
    struct Weather: Decodable { let temperature: Int; let unit: String?; let condition: String?; let high: Int?; let low: Int? }
    let place: String
    let timeZone: String
    let weather: Weather?
}

struct FindRowsSection: Decodable {
    let rows: [FindListRow]
}

// MARK: Movies and TV shows

struct FindMediaScore: Decodable, Hashable {
    let source: String
    let label: String
    let value: String
    let scale: String?
}

struct FindMediaTitleSection: Decodable {
    struct Links: Decodable { let imdb: String?; let trailer: String?; let tickets: String?; let watch: String? }
    let posterUrl: String?
    let tags: [FindEntityTag]?
    let meta: [String]?
    let scores: [FindMediaScore]?
    let scoresVia: String?
    let awards: String?
    let tiles: [FindStatTile]?
    /// Movies: theaters (about ten weeks after opening), coming, or released.
    let status: String?
    let released: String?
    let cast: [FindListRow]?
    let crew: [FindListRow]?
    let links: Links?
}

struct FindMovieFactsSection: Decodable {
    struct Links: Decodable { let website: String?; let wikipedia: String? }
    let tiles: [FindStatTile]?
    let cast: [FindListRow]?
    let composer: String?
    let distributors: [String]?
    let links: Links?
}

struct FindTvEpisode: Decodable, Hashable {
    let code: String
    let name: String?
    let airstamp: String?
    let airdate: String?
    let runtime: Int?
}

struct FindTvShowSection: Decodable {
    struct Links: Decodable { let guide: String? }
    let status: String?
    let statusTag: String?
    let service: String?
    let serviceUrl: String?
    let next: FindTvEpisode?
    let latest: FindTvEpisode?
    let imageUrl: String?
    let tiles: [FindStatTile]?
    let seasons: [FindListRow]?
    let cast: [FindListRow]?
    let episodes: [FindListRow]?
    let currentSeason: Int?
    let links: Links?
}

// MARK: Artists, albums and songs

struct FindMusicFactsSection: Decodable {
    struct Review: Decodable, Hashable { let source: String; let score: String }
    // radio and bandcamp: Taliferro Music's own artists only.
    struct Links: Decodable { let spotify: String?; let youtube: String?; let genius: String?; let website: String?; let wikipedia: String?; let radio: String?; let bandcamp: String? }
    let artist: String?
    let album: String?
    let released: String?
    let imageUrl: String?
    let tiles: [FindStatTile]?
    let credits: [FindListRow]?
    let members: [FindListRow]?
    let reviews: [Review]?
    let links: Links?
    let appleId: String?
}

struct FindMusicTrack: Decodable, Hashable {
    let number: Int?
    let name: String
    let length: String?
    let previewUrl: String?
    let url: String?
    let album: String?
}

struct FindMusicAppleSection: Decodable {
    struct Latest: Decodable { let name: String; let kind: String; let released: String?; let artworkUrl: String?; let url: String? }
    struct Links: Decodable { let apple: String?; let appleAlbum: String?; let appleArtist: String? }
    let artworkUrl: String?
    // Song
    let track: FindMusicTrack?
    let album: String?
    // Album
    let tracks: [FindMusicTrack]?
    let trackCount: Int?
    let length: String?
    // Artist
    let topSongs: [FindMusicTrack]?
    let albums: [FindListRow]?
    let albumCount: Int?
    let latest: Latest?
    let links: Links?
}

// MARK: Formatting

enum FindEntityFormat {
    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// ESPN's "2026-10-24T19:30Z" has no seconds; TVmaze's "+00:00" offsets parse as usual.
    static func date(_ text: String?) -> Date? {
        guard var text, !text.isEmpty else { return nil }
        if text.range(of: #"T\d\d:\d\dZ$"#, options: .regularExpression) != nil {
            text = text.replacingOccurrences(of: "Z", with: ":00Z")
        }
        return iso.date(from: text) ?? isoFractional.date(from: text)
    }

    /// A plain "2025-03-21" (no time) at noon UTC, so it stays on its day everywhere.
    static func day(_ text: String?) -> Date? {
        guard let text, text.count == 10 else { return nil }
        return iso.date(from: "\(text)T12:00:00Z")
    }

    static func format(_ date: Date, _ template: String, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    /// "2h ago", "Yesterday", "Oct 27".
    static func ago(_ text: String?) -> String? {
        guard let date = date(text) else { return nil }
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 60 { return "\(max(minutes, 1))m ago" }
        if minutes < 24 * 60 { return "\(minutes / 60)h ago" }
        if minutes < 48 * 60 { return "Yesterday" }
        return format(date, "MMMd")
    }

    /// 1.0 -> "1", 2.5 -> "2.5".
    static func trim(_ number: Double) -> String {
        number == number.rounded() ? String(Int(number)) : String(format: "%.1f", number)
    }
}
