import Foundation

enum FindAPIError: LocalizedError {
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server response could not be understood."
        case .httpError(let code):
            return "The server returned HTTP \(code)."
        }
    }
}

// Immutable after init (config, coder instances), so cards can call it from any task.
final class FindAPIClient: @unchecked Sendable {
    private let config: AppConfig
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(config: AppConfig) {
        self.config = config
    }

    func search(
        query: String,
        context: String? = nil,
        maxResults: Int = 10,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async throws -> FindSearchResponse {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = FindSearchRequest(
            query: trimmedQuery,
            context: context?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            maxResults: min(max(maxResults, 1), 10),
            postalCode: Self.extractPostalCode(from: trimmedQuery),
            latitude: latitude,
            longitude: longitude,
            timeZone: TimeZone.current.identifier,
            features: ["instant", "units"]
        )

        return try await post(path: "find/search", payload: payload, responseType: FindSearchResponse.self)
    }

    // Mirrors extractPostalCode() in the web app's find-experience.service.ts
    // so a bare ZIP in the query text (e.g. "weather 98106") reaches the
    // backend's weather fast-path the same way regardless of which client
    // sent it.
    private static func extractPostalCode(from query: String) -> String? {
        let pattern = #"(?:^|\s)(\d{5})(?:-\d{4})?(?=\s|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(query.startIndex..., in: query)
        guard let match = regex.firstMatch(in: query, range: range),
              let zipRange = Range(match.range(at: 1), in: query) else { return nil }
        return String(query[zipRange])
    }

    /// "Watch a find" endpoints (/find/watches…, /find/devices); all POSTs.
    func watch(_ path: String, _ payload: FindWatchRequest) async throws -> FindWatchResponse {
        try await post(path: path, payload: payload, responseType: FindWatchResponse.self)
    }

    /// A short find.16ahead.com/s/<id> link that previews a result.
    func share(_ payload: FindShareRequest) async throws -> FindShareResponse {
        try await post(path: "find/share", payload: payload, responseType: FindShareResponse.self)
    }

    func followup(_ payload: FindFollowupRequest) async throws -> FindFollowupResponse {
        try await post(path: "find/followup", payload: payload, responseType: FindFollowupResponse.self)
    }

    func summarize(query: String, url: String, title: String) async throws -> String {
        let payload = FindSummarizeRequest(query: query, url: url, title: title)
        let response = try await post(path: "find/summarize", payload: payload, responseType: FindSummarizeResponse.self)
        return response.answer
    }

    /// Is this query one thing (a team, a store, a country, a movie...)?
    /// Answers before the search finishes; nil means no card.
    func detectEntity(query: String) async throws -> FindEntity? {
        let payload = FindEntityDetectRequest(query: query.trimmingCharacters(in: .whitespacesAndNewlines), cardTypes: EntityCardView.cardTypes)
        return try await post(path: "find/entity", payload: payload, responseType: FindEntityDetectResponse.self).entity
    }

    /// One section of a single-item card, as the raw JSON of its `data`
    /// (nil when the backend has none). Each section loads on its own so the
    /// card fills in as they arrive; the card decodes the shape it expects.
    func entitySection(_ entity: FindEntity, section: String, latitude: Double? = nil, longitude: Double? = nil) async throws -> Data? {
        let payload = FindEntitySectionRequest(type: entity.type, league: entity.league, id: entity.id, section: section, latitude: latitude, longitude: longitude)
        let data = try await postData(path: "find/entity/section", payload: payload)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let section = object["data"], !(section is NSNull) else { return nil }
        return try JSONSerialization.data(withJSONObject: section)
    }

    func submitFeedback(_ payload: FindFeedbackRequest) async throws {
        _ = try await post(path: "find/feedback", payload: payload, responseType: FindFeedbackResponse.self)
    }

    private func post<Request: Encodable, Response: Decodable>(
        path: String,
        payload: Request,
        responseType: Response.Type
    ) async throws -> Response {
        try decoder.decode(responseType, from: try await postData(path: path, payload: payload))
    }

    private func postData<Request: Encodable>(path: String, payload: Request) async throws -> Data {
        let url = config.apiBaseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FindAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw FindAPIError.httpError(httpResponse.statusCode)
        }

        return data
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
