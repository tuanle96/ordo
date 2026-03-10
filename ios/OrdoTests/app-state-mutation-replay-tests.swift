import Foundation
import Testing
@testable import Ordo

@MainActor
struct AppStateMutationReplayTests {
    @Test
    func restoreSessionReplaysQueuedMutationsAfterAuthentication() async throws {
        let backendURL = URL(string: "http://127.0.0.1:35120")!
        let validSession = StoredSession(
            backendBaseURL: backendURL,
            odooURL: "http://127.0.0.1:38950",
            database: "odoo17",
            login: "admin",
            accessToken: "access-token",
            refreshToken: "refresh-token",
            expiresAt: Date().addingTimeInterval(3600),
            user: StoredSession.preview.user
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStateMutationReplayURLProtocol.self]

        var patchRequestCount = 0
        AppStateMutationReplayURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(AppStateReplayEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.hasSuffix("/modules/installed") {
                return (200, try JSONEncoder().encode(AppStateReplayEnvelope(data: InstalledModulesResponse(modules: []))))
            }

            if path.contains("/records/res.partner/7") && request.httpMethod == "PATCH" {
                patchRequestCount += 1
                return (200, try JSONEncoder().encode(AppStateReplayEnvelope(data: RecordMutationResult(id: 7, record: ["id": .number(7), "name": .string("Queued")]))))
            }

            throw URLError(.unsupportedURL)
        }

        let sessionStore = AppStateReplaySessionStore(session: validSession)
        let apiClient = APIClient(baseURL: backendURL, session: URLSession(configuration: configuration))
        let cacheStore = FileCacheStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        let queueStore = FileMutationQueueStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        let scope = CacheScope(namespace: [backendURL.absoluteString, validSession.odooURL, validSession.database, validSession.login, String(validSession.user.id)].joined(separator: "|").data(using: .utf8)!.base64EncodedString().replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-"))

        try await queueStore.enqueue(
            QueuedRecordMutation(model: "res.partner", recordID: 7, kind: .update, values: ["name": .string("Queued")], fields: ["name"]),
            scope: scope
        )

        let appState = AppState(
            config: .preview,
            sessionStore: sessionStore,
            apiClient: apiClient,
            cacheStore: cacheStore,
            mutationQueueStore: queueStore
        )

        await appState.restoreSession()

        #expect(appState.phase == AppState.Phase.authenticated)
        #expect(patchRequestCount == 1)
        #expect(appState.pendingMutationCount == 0)
        #expect(appState.statusMessage?.contains("Synced 1 pending change") == true)
    }

    @Test
    func retryPendingMutationRemovesQueuedMutationAfterSuccessfulManualRetry() async throws {
        let backendURL = URL(string: "http://127.0.0.1:35120")!
        let validSession = StoredSession(
            backendBaseURL: backendURL,
            odooURL: "http://127.0.0.1:38950",
            database: "odoo17",
            login: "admin",
            accessToken: "access-token",
            refreshToken: "refresh-token",
            expiresAt: Date().addingTimeInterval(3600),
            user: StoredSession.preview.user
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStateMutationReplayURLProtocol.self]

        var patchRequestCount = 0
        AppStateMutationReplayURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(AppStateReplayEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.hasSuffix("/modules/installed") {
                return (200, try JSONEncoder().encode(AppStateReplayEnvelope(data: InstalledModulesResponse(modules: []))))
            }

            if path.contains("/records/res.partner/7") && request.httpMethod == "PATCH" {
                patchRequestCount += 1
                return (200, try JSONEncoder().encode(AppStateReplayEnvelope(data: RecordMutationResult(id: 7, record: ["id": .number(7), "name": .string("Retried")]))))
            }

            throw URLError(.unsupportedURL)
        }

        let sessionStore = AppStateReplaySessionStore(session: validSession)
        let apiClient = APIClient(baseURL: backendURL, session: URLSession(configuration: configuration))
        let cacheStore = FileCacheStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        let queueStore = FileMutationQueueStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        let appState = AppState(
            config: .preview,
            sessionStore: sessionStore,
            apiClient: apiClient,
            cacheStore: cacheStore,
            mutationQueueStore: queueStore
        )

        await appState.restoreSession()

        let scope = try #require(appState.cacheScope)
        let queuedMutation = QueuedRecordMutation(
            model: "res.partner",
            recordID: 7,
            kind: .update,
            values: ["name": .string("Retried")],
            fields: ["name"]
        )
        try await queueStore.enqueue(queuedMutation, scope: scope)

        #expect((await appState.pendingMutations()).count == 1)

        await appState.retryPendingMutation(id: queuedMutation.id)

        #expect(patchRequestCount == 1)
        #expect(await queueStore.load(scope: scope).isEmpty)
        #expect(appState.pendingMutationCount == 0)
        #expect(appState.statusMessage == "Synced 1 pending change.")
    }

    @Test
    func retryPendingMutationKeepsQueuedMutationAndCapturesLastErrorOnFailure() async throws {
        let backendURL = URL(string: "http://127.0.0.1:35120")!
        let validSession = StoredSession(
            backendBaseURL: backendURL,
            odooURL: "http://127.0.0.1:38950",
            database: "odoo17",
            login: "admin",
            accessToken: "access-token",
            refreshToken: "refresh-token",
            expiresAt: Date().addingTimeInterval(3600),
            user: StoredSession.preview.user
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppStateMutationReplayURLProtocol.self]

        AppStateMutationReplayURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(AppStateReplayEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.hasSuffix("/modules/installed") {
                return (200, try JSONEncoder().encode(AppStateReplayEnvelope(data: InstalledModulesResponse(modules: []))))
            }

            if path.contains("/records/res.partner/7") && request.httpMethod == "PATCH" {
                throw URLError(.timedOut)
            }

            throw URLError(.unsupportedURL)
        }

        let sessionStore = AppStateReplaySessionStore(session: validSession)
        let apiClient = APIClient(baseURL: backendURL, session: URLSession(configuration: configuration))
        let cacheStore = FileCacheStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        let queueStore = FileMutationQueueStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        let appState = AppState(
            config: .preview,
            sessionStore: sessionStore,
            apiClient: apiClient,
            cacheStore: cacheStore,
            mutationQueueStore: queueStore
        )

        await appState.restoreSession()

        let scope = try #require(appState.cacheScope)
        let queuedMutation = QueuedRecordMutation(
            model: "res.partner",
            recordID: 7,
            kind: .update,
            values: ["name": .string("Retried")],
            fields: ["name"]
        )
        try await queueStore.enqueue(queuedMutation, scope: scope)

        await appState.retryPendingMutation(id: queuedMutation.id)

        let storedMutation = try #require(await queueStore.load(scope: scope).first)
        #expect(storedMutation.retryCount == 1)
        #expect(storedMutation.lastError?.isEmpty == false)
        #expect(appState.pendingMutationCount == 1)
        #expect(appState.statusMessage == "Still couldn’t sync that pending change. It remains queued for a later retry.")
    }
}

private final class AppStateReplaySessionStore: SessionStoring {
    private var storedSession: StoredSession?

    init(session: StoredSession?) {
        storedSession = session
    }

    func load() throws -> StoredSession? { storedSession }
    func save(_ session: StoredSession) throws { storedSession = session }
    func clear() throws { storedSession = nil }
}

private final class AppStateMutationReplayURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let client, let url = request.url, let requestHandler = Self.requestHandler else { return }

        do {
            let (statusCode, data) = try requestHandler(request)
            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: data)
            client.urlProtocolDidFinishLoading(self)
        } catch {
            client.urlProtocol(self, didFailWithError: error)
        }
    }
}

private struct AppStateReplayEnvelope<T: Encodable>: Encodable {
    let success = true
    let data: T
    let meta: AppStateReplayMeta? = nil
    let errors: [AppStateReplayError] = []
}

private struct AppStateReplayMeta: Encodable {
    let total: Int? = nil
    let offset: Int? = nil
    let limit: Int? = nil
    let timestamp: String? = nil
}

private struct AppStateReplayError: Encodable {
    let code: String = ""
    let message: String = ""
    let field: String? = nil
}