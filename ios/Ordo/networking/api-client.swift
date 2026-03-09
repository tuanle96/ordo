import Foundation
import OSLog

final class APIClient {
    private static let logger = Logger(subsystem: "com.ordo.app", category: "api-client")
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

    func refresh(request: RefreshTokenRequest) async throws -> TokenResponse {
        let body = try JSONEncoder().encode(request)
        return try await perform(route: "auth/refresh", method: "POST", body: body)
    }

    func me(token: String) async throws -> AuthenticatedPrincipal {
        try await perform(route: "auth/me", token: token)
    }

    func logout(token: String) async throws -> LogoutResponse {
        try await perform(route: "auth/logout", method: "POST", token: token)
    }

    func schema(model: String, fresh: Bool = false, token: String) async throws -> MobileFormSchema {
        let queryItems = fresh ? [URLQueryItem(name: "fresh", value: "true")] : []
        return try await perform(route: "schema/\(model)", queryItems: queryItems, token: token)
    }

    func listSchema(model: String, fresh: Bool = false, token: String) async throws -> MobileListSchema {
        let queryItems = fresh ? [URLQueryItem(name: "fresh", value: "true")] : []
        return try await perform(route: "schema/\(model)/list", queryItems: queryItems, token: token)
    }

    func installedModules(token: String) async throws -> InstalledModulesResponse {
        try await perform(route: "modules/installed", token: token)
    }

    func listRecords(
        model: String,
        fields: [String],
        limit: Int,
        offset: Int,
        order: String? = nil,
        domain: JSONValue? = nil,
        token: String
    ) async throws -> RecordListResult {
        var queryItems = [
            URLQueryItem(name: "fields", value: fields.joined(separator: ",")),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]

        if let order, !order.isEmpty {
            queryItems.append(URLQueryItem(name: "order", value: order))
        }

        if let encodedDomain = domain?.encodedJSONString, !encodedDomain.isEmpty {
            queryItems.append(URLQueryItem(name: "domain", value: encodedDomain))
        }

        return try await perform(route: "records/\(model)", queryItems: queryItems, token: token)
    }

    func search(model: String, query: String, limit: Int, domain: JSONValue? = nil, token: String) async throws -> [NameSearchResult] {
        let queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ] + (domain?.encodedJSONString.map { [URLQueryItem(name: "domain", value: $0)] } ?? [])

        return try await perform(route: "search/\(model)", queryItems: queryItems, token: token)
    }

    func record(model: String, id: Int, fields: [String], token: String) async throws -> RecordData {
        let queryItems = [URLQueryItem(name: "fields", value: fields.joined(separator: ","))]
        return try await perform(route: "records/\(model)/\(id)", queryItems: queryItems, token: token)
    }

    func defaultValues(model: String, fields: [String], token: String) async throws -> RecordData {
        let queryItems = [URLQueryItem(name: "fields", value: fields.joined(separator: ","))]
        return try await perform(route: "records/\(model)/defaults", queryItems: queryItems, token: token)
    }

    func chatter(model: String, id: Int, before: Int? = nil, token: String) async throws -> ChatterThreadResult {
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "limit", value: "20")]

        if let before {
            queryItems.append(URLQueryItem(name: "before", value: String(before)))
        }

        return try await perform(route: "records/\(model)/\(id)/chatter", queryItems: queryItems, token: token)
    }

    func chatterDetails(model: String, id: Int, token: String) async throws -> ChatterDetailsResult {
        try await perform(route: "records/\(model)/\(id)/chatter/details", token: token)
    }

    func postChatterNote(model: String, id: Int, body: String, token: String) async throws -> ChatterMessage {
        let payload = try JSONEncoder().encode(PostChatterNoteRequest(body: body))
        return try await perform(route: "records/\(model)/\(id)/chatter/note", method: "POST", token: token, body: payload)
    }

    func followRecord(model: String, id: Int, token: String) async throws -> ChatterDetailsResult {
        try await perform(route: "records/\(model)/\(id)/chatter/follow", method: "POST", token: token)
    }

    func unfollowRecord(model: String, id: Int, token: String) async throws -> ChatterDetailsResult {
        try await perform(route: "records/\(model)/\(id)/chatter/follow", method: "DELETE", token: token)
    }

    func completeChatterActivity(model: String, id: Int, activityId: Int, feedback: String? = nil, token: String) async throws -> ChatterDetailsResult {
        let payload = try JSONEncoder().encode(CompleteChatterActivityRequest(feedback: feedback))
        return try await perform(route: "records/\(model)/\(id)/chatter/activities/\(activityId)/done", method: "POST", token: token, body: payload)
    }

    func scheduleChatterActivity(
        model: String,
        id: Int,
        activityTypeId: Int,
        summary: String? = nil,
        note: String? = nil,
        dateDeadline: String? = nil,
        token: String
    ) async throws -> ChatterDetailsResult {
        let payload = try JSONEncoder().encode(
            ScheduleChatterActivityRequest(
                activityTypeId: activityTypeId,
                summary: summary,
                note: note,
                dateDeadline: dateDeadline
            )
        )
        return try await perform(route: "records/\(model)/\(id)/chatter/activities", method: "POST", token: token, body: payload)
    }

    func updateRecord(
        model: String,
        id: Int,
        values: RecordData,
        fields: [String],
        token: String
    ) async throws -> RecordMutationResult {
        let body = try JSONEncoder().encode(RecordMutationRequest(values: values, fields: fields))
        return try await perform(route: "records/\(model)/\(id)", method: "PATCH", token: token, body: body)
    }

    func createRecord(
        model: String,
        values: RecordData,
        fields: [String],
        token: String
    ) async throws -> RecordMutationResult {
        let body = try JSONEncoder().encode(RecordMutationRequest(values: values, fields: fields))
        return try await perform(route: "records/\(model)", method: "POST", token: token, body: body)
    }

    func deleteRecord(
        model: String,
        id: Int,
        token: String
    ) async throws -> RecordDeleteResult {
        try await perform(route: "records/\(model)/\(id)", method: "DELETE", token: token)
    }

    func runRecordAction(
        model: String,
        id: Int,
        actionName: String,
        fields: [String],
        token: String
    ) async throws -> RecordActionResult {
        let body = try JSONEncoder().encode(RecordActionRequest(fields: fields))
        return try await perform(
            route: "records/\(model)/\(id)/actions/\(actionName)",
            method: "POST",
            token: token,
            body: body
        )
    }

    func onchange(
        model: String,
        values: RecordData,
        triggerField: String,
        recordId: Int?,
        fields: [String],
        token: String
    ) async throws -> OnchangeResult {
        let body = try JSONEncoder().encode(
            OnchangeRequest(
                values: values,
                triggerField: triggerField,
                recordId: recordId,
                fields: fields
            )
        )

        return try await perform(route: "records/\(model)/onchange", method: "POST", token: token, body: body)
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

        Self.logger.debug("→ \(method, privacy: .public) \(requestURL.absoluteString, privacy: .public)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        Self.logger.debug("← HTTP \(httpResponse.statusCode, privacy: .public) (\(data.count, privacy: .public) bytes) for \(route, privacy: .public)")

        let decoder = JSONDecoder()

        if httpResponse.statusCode == 401 {
            throw APIClientError.unauthorized
        }

        do {
            let envelope = try decoder.decode(APIEnvelope<T>.self, from: data)
            guard httpResponse.statusCode < 400 else {
                throw APIClientError.server(statusCode: httpResponse.statusCode, errors: envelope.errors)
            }
            guard let payload = envelope.data else {
                throw APIClientError.decodingFailed("Server returned success but data was null")
            }
            return payload
        } catch {
            // Log the raw response body for debugging
            let bodyPreview = String(data: data.prefix(2000), encoding: .utf8) ?? "<non-UTF8 data>"
            Self.logger.error("‼️ Decoding FAILED for route \(route, privacy: .public)")
            Self.logger.error("‼️ Response body (first 2000 chars):\n\(bodyPreview, privacy: .public)")
            Self.logger.error("‼️ Decoding error detail: \(String(describing: error), privacy: .public)")

            // Log structured DecodingError details
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    Self.logger.error("‼️ TYPE MISMATCH: expected \(String(describing: type), privacy: .public) at keyPath: \(context.codingPath.map(\.stringValue).joined(separator: "."), privacy: .public) — \(context.debugDescription, privacy: .public)")
                case .valueNotFound(let type, let context):
                    Self.logger.error("‼️ VALUE NOT FOUND: \(String(describing: type), privacy: .public) at keyPath: \(context.codingPath.map(\.stringValue).joined(separator: "."), privacy: .public) — \(context.debugDescription, privacy: .public)")
                case .keyNotFound(let key, let context):
                    Self.logger.error("‼️ KEY NOT FOUND: '\(key.stringValue, privacy: .public)' at keyPath: \(context.codingPath.map(\.stringValue).joined(separator: "."), privacy: .public) — \(context.debugDescription, privacy: .public)")
                case .dataCorrupted(let context):
                    Self.logger.error("‼️ DATA CORRUPTED at keyPath: \(context.codingPath.map(\.stringValue).joined(separator: "."), privacy: .public) — \(context.debugDescription, privacy: .public)")
                @unknown default:
                    Self.logger.error("‼️ UNKNOWN DecodingError: \(String(describing: decodingError), privacy: .public)")
                }
            }

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
