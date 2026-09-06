import Foundation

// An unrecognized queryType decodes to `.unknown` rather than throwing, so a
// future backend addition can't fail decoding of the whole response the way
// `local`/`conversion` did before this enum knew about them (see
// FindSourceType.unknown below for the same reasoning).
enum FindQueryType: Codable, Hashable {
    case entity
    case question
    case person
    case weather
    case conversion
    case local
    case unknown(String)

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "entity": self = .entity
        case "question": self = .question
        case "person": self = .person
        case "weather": self = .weather
        case "conversion": self = .conversion
        case "local": self = .local
        default: self = .unknown(raw)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .entity: try container.encode("entity")
        case .question: try container.encode("question")
        case .person: try container.encode("person")
        case .weather: try container.encode("weather")
        case .conversion: try container.encode("conversion")
        case .local: try container.encode("local")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}

struct FindWeatherForecastDay: Codable, Hashable {
    let date: String
    let label: String
    let condition: String
    let description: String?
    let iconUrl: String?
    let highF: Double?
    let lowF: Double?
}

struct FindWeatherInfo: Codable, Hashable {
    let location: String
    let postalCode: String?
    let timezone: String?
    let tempF: Double
    let feelsLikeF: Double
    let condition: String
    let description: String
    let iconUrl: String
    let humidity: Double
    let windMph: Double
    let highF: Double?
    let lowF: Double?
    let updatedAt: String?
    let forecast: [FindWeatherForecastDay]?
}

enum FindConversionCategory: String, Codable {
    case currency
    case temperature
    case distance
    case weight
    case length
    case volume
}

struct FindConversionResult: Codable, Hashable {
    let category: FindConversionCategory
    let inputAmount: Double
    let inputUnit: String
    let inputUnitLabel: String?
    let outputAmount: Double
    let outputUnit: String
    let outputUnitLabel: String?
    let rate: Double?
    let rateUpdatedAt: String?
    let source: String?
}

struct FindBusinessHoursPeriod: Codable, Hashable {
    let open: String
    let close: String
}

struct FindBusinessHoursDay: Codable, Hashable {
    let day: String
    let periods: [FindBusinessHoursPeriod]
    let isClosed: Bool?
    let isTwentyFourHours: Bool?
}

struct FindBusinessHours: Codable, Hashable {
    let timezone: String?
    let isOpenNow: Bool?
    let statusText: String?
    let days: [FindBusinessHoursDay]
    let holidayNotes: [String]?
    let sourceUrl: String?
}

// New source types (like `crowdsourced`) will keep arriving from the
// backend as it grows — decoding an unrecognized raw value to `.unknown`
// instead of throwing keeps a single unfamiliar result from failing
// decoding for the entire response.
enum FindSourceType: Codable, Hashable {
    case official
    case publisher
    case government
    case academic
    case medical
    case encyclopedia
    case crowdsourced
    case unknown(String)

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "official": self = .official
        case "publisher": self = .publisher
        case "government": self = .government
        case "academic": self = .academic
        case "medical": self = .medical
        case "encyclopedia": self = .encyclopedia
        case "crowdsourced": self = .crowdsourced
        default: self = .unknown(raw)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .official: try container.encode("official")
        case .publisher: try container.encode("publisher")
        case .government: try container.encode("government")
        case .academic: try container.encode("academic")
        case .medical: try container.encode("medical")
        case .encyclopedia: try container.encode("encyclopedia")
        case .crowdsourced: try container.encode("crowdsourced")
        case .unknown(let raw): try container.encode(raw)
        }
    }
}

struct FindAnswerReference: Codable, Identifiable, Hashable {
    var id: String { url }
    let title: String
    let url: String
    let displayUrl: String
    let sourceType: FindSourceType
}

struct FindAnswerBlock: Codable, Hashable {
    let text: String
    let imageUrl: String?
    let references: [FindAnswerReference]
}

struct FindRankedResult: Codable, Identifiable, Hashable {
    var id: String { url }
    let rank: Int
    let title: String
    let summary: String
    let answer: String?
    let url: String
    let displayUrl: String
    let imageUrl: String
    let sourceType: FindSourceType
    let confidence: Double
    let pills: [String]
    let isFirstParty: Bool
    let hours: FindBusinessHours?
}

struct FindSearchHandoff: Codable, Hashable {
    let route: String
    let query: String
}

struct FindSearchTimings: Codable, Hashable {
    let totalMs: Int
    let planMs: Int
    let enrichMs: Int
    let summarizeMs: Int
    let candidateCount: Int
    let enrichedCount: Int
}

struct FindSearchResponse: Codable, Hashable {
    let success: Bool
    let query: String
    let normalizedQuery: String
    let queryType: FindQueryType
    let handoff: FindSearchHandoff?
    let answer: FindAnswerBlock?
    let weather: FindWeatherInfo?
    let conversion: FindConversionResult?
    let results: [FindRankedResult]
    let selectedIndex: Int
    let timings: FindSearchTimings?
}

struct FindSearchRequest: Encodable {
    let query: String
    let context: String?
    let maxResults: Int
    let postalCode: String?
    let latitude: Double?
    let longitude: Double?
}

struct FindSummarizeRequest: Encodable {
    let query: String
    let url: String
    let title: String
}

struct FindSummarizeResponse: Decodable {
    let answer: String
}
