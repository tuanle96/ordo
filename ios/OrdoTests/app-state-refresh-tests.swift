import Foundation
import Testing
@testable import Ordo

@MainActor
struct AppStateRefreshTests {
    @Test
    func restoreSessionRefreshesExpiredAccessTokenBeforeAuthenticatedRequest() async throws {
        let defaults = UserDefaults(suiteName: "com.ordo.app.tests.refresh") ?? .standard
        let sessionStore = UserDefaultsSessionStore(defaults: defaults, key: "refresh-session")
        try? sessionStore.clear()

        let expiredSession = StoredSession(
            backendBaseURL: URL(string: AppConfig.fallbackBaseURL)!,
            odooURL: "http://127.0.0.1:38421",
            database: "odoo17",
            login: "admin",
            accessToken: "expired-access",
            refreshToken: "refresh-token",
            expiresAt: .now.addingTimeInterval(-120),
            user: AuthUser(id: 1, name: "Demo Admin", email: "admin@example.com", lang: "en_US", tz: "UTC", avatarUrl: nil)
        )
        try sessionStore.save(expiredSession)

        RefreshTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/refresh") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: TokenResponse(
                    accessToken: "refreshed-access",
                    refreshToken: "refreshed-refresh",
                    expiresIn: 900,
                    user: expiredSession.user
                ))))
            }

            if path.hasSuffix("/auth/me") {
                let authHeader = request.value(forHTTPHeaderField: "Authorization")
                #expect(authHeader == "Bearer refreshed-access")
                return (200, try JSONEncoder().encode(TestEnvelope(data: AuthenticatedPrincipal(
                    uid: 1,
                    db: "odoo17",
                    odooUrl: "http://127.0.0.1:38421",
                    version: "17",
                    lang: "en_US",
                    groups: [1],
                    name: "Demo Admin",
                    email: "admin@example.com",
                    tz: "UTC"
                ))))
            }

            throw URLError(.unsupportedURL)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefreshTestURLProtocol.self]
        let apiClient = APIClient(baseURL: URL(string: AppConfig.fallbackBaseURL)!, session: URLSession(configuration: configuration))
        let cacheStore = FileCacheStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        let appState = AppState(config: .preview, sessionStore: sessionStore, apiClient: apiClient, cacheStore: cacheStore)

        await appState.restoreSession()

        #expect(appState.session?.accessToken == "refreshed-access")
        #expect(appState.session?.refreshToken == "refreshed-refresh")
        #expect(appState.currentPrincipal?.uid == 1)
    }
}

private final class RefreshTestURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

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

    override func stopLoading() {}
}

private struct TestEnvelope<T: Encodable>: Encodable {
    let success = true
    let data: T
    let meta: TestMeta? = nil
    let errors: [TestErrorPayload] = []
}

private struct TestMeta: Encodable {
    let total: Int?
    let offset: Int?
    let limit: Int?
    let timestamp: String?
}

private struct TestErrorPayload: Encodable {
    let code: String
    let message: String
    let field: String?
}