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

    func search(query: String, context: String? = nil, maxResults: Int = 10) async throws -> FindSearchResponse {
        let payload = FindSearchRequest(
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            context: context?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            maxResults: min(max(maxResults, 1), 10)
        )

        return try await post(path: "find/search", payload: payload, responseType: FindSearchResponse.self)
    }

    func summarize(query: String, url: String, title: String) async throws -> String {
        let payload = FindSummarizeRequest(query: query, url: url, title: title)
        let response = try await post(path: "find/summarize", payload: payload, responseType: FindSummarizeResponse.self)
        return response.answer
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
