import Foundation

enum FindQueryType: String, Codable {
    case entity
    case question
    case person
}

enum FindSourceType: String, Codable {
    case official
    case publisher
    case government
    case academic
    case medical
    case encyclopedia
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
    let results: [FindRankedResult]
    let selectedIndex: Int
    let timings: FindSearchTimings?
}

struct FindSearchRequest: Encodable {
    let query: String
    let context: String?
    let maxResults: Int
}

struct FindSummarizeRequest: Encodable {
    let query: String
    let url: String
    let title: String
}

struct FindSummarizeResponse: Decodable {
    let answer: String
}
