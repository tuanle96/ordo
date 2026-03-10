import Foundation
import Testing
@testable import Ordo

@Suite(.serialized)
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

    @Test
    func restoreSessionClearsSavedSessionWhenRefreshFails() async throws {
        let defaults = UserDefaults(suiteName: "com.ordo.app.tests.refresh.failure") ?? .standard
        let sessionStore = UserDefaultsSessionStore(defaults: defaults, key: "refresh-session-failure")
        try? sessionStore.clear()

        let expiredSession = StoredSession(
            backendBaseURL: URL(string: AppConfig.fallbackBaseURL)!,
            odooURL: "http://127.0.0.1:38421",
            database: "odoo17",
            login: "admin",
            accessToken: "expired-access",
            refreshToken: "bad-refresh-token",
            expiresAt: .now.addingTimeInterval(-120),
            user: AuthUser(id: 1, name: "Demo Admin", email: "admin@example.com", lang: "en_US", tz: "UTC", avatarUrl: nil)
        )
        try sessionStore.save(expiredSession)

        RefreshTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/refresh") {
                return (401, Data())
            }

            throw URLError(.unsupportedURL)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefreshTestURLProtocol.self]
        let apiClient = APIClient(baseURL: URL(string: AppConfig.fallbackBaseURL)!, session: URLSession(configuration: configuration))
        let cacheStore = FileCacheStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        let appState = AppState(config: .preview, sessionStore: sessionStore, apiClient: apiClient, cacheStore: cacheStore)

        await appState.restoreSession()

        #expect(appState.phase == .login)
        #expect(appState.session == nil)
        #expect(appState.currentPrincipal == nil)
        #expect(appState.statusMessage == "Your saved session could not be restored. Please sign in again.")
    }

    @Test
    func logoutPostsToBackendThenClearsLocalSession() async throws {
        let defaults = UserDefaults(suiteName: "com.ordo.app.tests.logout") ?? .standard
        let sessionStore = UserDefaultsSessionStore(defaults: defaults, key: "logout-session")
        try? sessionStore.clear()

        let storedSession = StoredSession(
            backendBaseURL: URL(string: AppConfig.fallbackBaseURL)!,
            odooURL: "http://127.0.0.1:38421",
            database: "odoo17",
            login: "admin",
            accessToken: "valid-access",
            refreshToken: "refresh-token",
            expiresAt: .now.addingTimeInterval(600),
            user: AuthUser(id: 1, name: "Demo Admin", email: "admin@example.com", lang: "en_US", tz: "UTC", avatarUrl: nil)
        )
        try sessionStore.save(storedSession)

        RefreshTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/logout") {
                #expect(request.httpMethod == "POST")
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer valid-access")
                return (200, try JSONEncoder().encode(TestEnvelope(data: LogoutResponse(success: true))))
            }

            if path.hasSuffix("/auth/me") {
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
        await appState.logout()

        #expect(appState.phase == .login)
        #expect(appState.session == nil)
        #expect(appState.currentPrincipal == nil)
        #expect(try sessionStore.load() == nil)
    }

    @Test
    func logoutFallsBackToLocalSignOutWhenBackendReturnsUnauthorized() async throws {
        let defaults = UserDefaults(suiteName: "com.ordo.app.tests.logout.unauthorized") ?? .standard
        let sessionStore = UserDefaultsSessionStore(defaults: defaults, key: "logout-session-unauthorized")
        try? sessionStore.clear()

        let storedSession = StoredSession(
            backendBaseURL: URL(string: AppConfig.fallbackBaseURL)!,
            odooURL: "http://127.0.0.1:38421",
            database: "odoo17",
            login: "admin",
            accessToken: "expired-access",
            refreshToken: "bad-refresh-token",
            expiresAt: .now.addingTimeInterval(600),
            user: AuthUser(id: 1, name: "Demo Admin", email: "admin@example.com", lang: "en_US", tz: "UTC", avatarUrl: nil)
        )
        try sessionStore.save(storedSession)

        RefreshTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/logout") {
                return (401, Data())
            }

            if path.hasSuffix("/auth/refresh") {
                return (401, Data())
            }

            if path.hasSuffix("/auth/me") {
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
        await appState.logout()

        #expect(appState.phase == .login)
        #expect(appState.session == nil)
        #expect(appState.currentPrincipal == nil)
        #expect(try sessionStore.load() == nil)
    }

    @Test
    func logoutStillClearsLocalSessionWhenBackendIsUnavailable() async throws {
        let defaults = UserDefaults(suiteName: "com.ordo.app.tests.logout.unavailable") ?? .standard
        let sessionStore = UserDefaultsSessionStore(defaults: defaults, key: "logout-session-unavailable")
        try? sessionStore.clear()

        let storedSession = StoredSession(
            backendBaseURL: URL(string: AppConfig.fallbackBaseURL)!,
            odooURL: "http://127.0.0.1:38421",
            database: "odoo17",
            login: "admin",
            accessToken: "valid-access",
            refreshToken: "refresh-token",
            expiresAt: .now.addingTimeInterval(600),
            user: AuthUser(id: 1, name: "Demo Admin", email: "admin@example.com", lang: "en_US", tz: "UTC", avatarUrl: nil)
        )
        try sessionStore.save(storedSession)

        RefreshTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/logout") {
                throw URLError(.cannotConnectToHost)
            }

            if path.hasSuffix("/auth/me") {
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
        await appState.logout()

        #expect(appState.phase == .login)
        #expect(appState.session == nil)
        #expect(appState.currentPrincipal == nil)
        #expect(appState.statusMessage == "Signed out locally, but the server logout could not be confirmed.")
        #expect(try sessionStore.load() == nil)
    }

    @Test
    func signInClearsStatusMessageAfterFailedRestore() async throws {
        let defaults = UserDefaults(suiteName: "com.ordo.app.tests.signin.clears.status") ?? .standard
        let sessionStore = UserDefaultsSessionStore(defaults: defaults, key: "signin-clears-status-session")
        try? sessionStore.clear()

        let expiredSession = StoredSession(
            backendBaseURL: URL(string: AppConfig.fallbackBaseURL)!,
            odooURL: "http://127.0.0.1:38421",
            database: "odoo17",
            login: "admin",
            accessToken: "expired-access",
            refreshToken: "bad-refresh-token",
            expiresAt: .now.addingTimeInterval(-120),
            user: AuthUser(id: 1, name: "Demo Admin", email: "admin@example.com", lang: "en_US", tz: "UTC", avatarUrl: nil)
        )
        try sessionStore.save(expiredSession)

        RefreshTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/refresh") {
                return (401, Data())
            }

            if path.hasSuffix("/auth/login") {
                return (201, try JSONEncoder().encode(TestEnvelope(data: TokenResponse(
                    accessToken: "new-access",
                    refreshToken: "new-refresh",
                    expiresIn: 900,
                    user: expiredSession.user
                ))))
            }

            if path.hasSuffix("/auth/me") {
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

            if path.hasSuffix("/modules/installed") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: InstalledModulesResponse(modules: [], browseMenuTree: []))))
            }

            throw URLError(.unsupportedURL)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefreshTestURLProtocol.self]
        let apiClient = APIClient(baseURL: URL(string: AppConfig.fallbackBaseURL)!, session: URLSession(configuration: configuration))
        let cacheStore = FileCacheStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        let appState = AppState(config: .preview, sessionStore: sessionStore, apiClient: apiClient, cacheStore: cacheStore)

        await appState.restoreSession()
        #expect(appState.phase == .login)
        #expect(appState.statusMessage == "Your saved session could not be restored. Please sign in again.")

        try await appState.signIn(with: LoginDraft(
            backendBaseURL: AppConfig.fallbackBaseURL,
            odooURL: "http://127.0.0.1:38421",
            database: "odoo17",
            username: "admin",
            password: "admin"
        ))

        #expect(appState.phase == .authenticated)
        #expect(appState.statusMessage == nil)
        #expect(appState.session?.accessToken == "new-access")
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