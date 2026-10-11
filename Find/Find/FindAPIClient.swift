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

final class FindAPIClient {
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

    func summarize(query: String, url: String, title: String) async throws -> String {
        let payload = FindSummarizeRequest(query: query, url: url, title: title)
        let response = try await post(path: "find/summarize", payload: payload, responseType: FindSummarizeResponse.self)
        return response.answer
    }

    func submitFeedback(_ payload: FindFeedbackRequest) async throws {
        _ = try await post(path: "find/feedback", payload: payload, responseType: FindFeedbackResponse.self)
    }

    private func post<Request: Encodable, Response: Decodable>(
        path: String,
        payload: Request,
        responseType: Response.Type
    ) async throws -> Response {
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

        return try decoder.decode(responseType, from: data)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
