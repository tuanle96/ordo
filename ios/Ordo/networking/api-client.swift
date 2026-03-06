import Foundation

final class APIClient {
    private let session: URLSession
    private(set) var baseURL: URL

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func updateBaseURL(_ url: URL) {
        baseURL = url
    }

    func login(request: LoginRequest) async throws -> TokenResponse {
        let body = try JSONEncoder().encode(request)
        return try await perform(route: "auth/login", method: "POST", body: body)
    }

    func me(token: String) async throws -> AuthenticatedPrincipal {
        try await perform(route: "auth/me", token: token)
    }

    func schema(model: String, token: String) async throws -> MobileFormSchema {
        try await perform(route: "schema/\(model)", token: token)
    }

    func listRecords(model: String, fields: [String], limit: Int, offset: Int, token: String) async throws -> RecordListResult {
        let queryItems = [
            URLQueryItem(name: "fields", value: fields.joined(separator: ",")),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]

        return try await perform(route: "records/\(model)", queryItems: queryItems, token: token)
    }

    func search(model: String, query: String, limit: Int, token: String) async throws -> [NameSearchResult] {
        let queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        return try await perform(route: "search/\(model)", queryItems: queryItems, token: token)
    }

    func record(model: String, id: Int, fields: [String], token: String) async throws -> RecordData {
        let queryItems = [URLQueryItem(name: "fields", value: fields.joined(separator: ","))]
        return try await perform(route: "records/\(model)/\(id)", queryItems: queryItems, token: token)
    }

    private func perform<T: Decodable>(
        route: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        token: String? = nil,
        body: Data? = nil
    ) async throws -> T {
        guard let requestURL = url(for: route, queryItems: queryItems) else {
            throw APIClientError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        let decoder = JSONDecoder()

        if httpResponse.statusCode == 401 {
            throw APIClientError.unauthorized
        }

        do {
            let envelope = try decoder.decode(APIEnvelope<T>.self, from: data)
            guard httpResponse.statusCode < 400 else {
                throw APIClientError.server(statusCode: httpResponse.statusCode, errors: envelope.errors)
            }
            return envelope.data
        } catch {
            if let envelope = try? decoder.decode(APIEnvelope<JSONValue>.self, from: data), !envelope.errors.isEmpty {
                throw APIClientError.server(statusCode: httpResponse.statusCode, errors: envelope.errors)
            }
            throw APIClientError.decodingFailed(error.localizedDescription)
        }
    }

    private func url(for route: String, queryItems: [URLQueryItem]) -> URL? {
        var components = URLComponents(url: baseURL.appending(path: route), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        return components?.url
    }
}

enum APIClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case server(statusCode: Int, errors: [APIErrorPayload])
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL is invalid."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .unauthorized:
            return "Your session is no longer valid. Please sign in again."
        case .server(_, let errors):
            return errors.first?.message ?? "The server could not complete the request."
        case .decodingFailed(let message):
            return "The app could not read the server response: \(message)"
        }
    }
}
