import Foundation
import Testing
@testable import Ordo

@Suite(.serialized)
@MainActor
struct AppStateModelDiscoveryTests {
    @Test
    func restoreSessionBuildsAvailableModelsFromDiscoveredBrowseModels() async throws {
        let backendURL = URL(string: "http://127.0.0.1:35120")!
        let session = StoredSession(
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
        configuration.protocolClasses = [AppStateModelDiscoveryURLProtocol.self]

        AppStateModelDiscoveryURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(AppStateModelDiscoveryEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.hasSuffix("/modules/installed") {
                return (200, try JSONEncoder().encode(AppStateModelDiscoveryEnvelope(data: InstalledModulesResponse(
                    modules: [InstalledModuleInfo(name: "account", displayName: "Accounting")],
                    browseModels: [
                        BrowseModelInfo(model: "res.partner", title: "Contacts"),
                        BrowseModelInfo(model: "account.move", title: "Invoices"),
                    ]
                ))))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = AppState(
            config: .preview,
            sessionStore: AppStateModelDiscoverySessionStore(session: session),
            apiClient: APIClient(baseURL: backendURL, session: URLSession(configuration: configuration)),
            cacheStore: FileCacheStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        )

        await appState.restoreSession()

        #expect(appState.availableModels.map(\.model) == ["res.partner", "account.move"])
        #expect(appState.modelDescriptor(for: "res.partner").title == "Customers")
        #expect(appState.modelDescriptor(for: "account.move").title == "Invoices")
        #expect(appState.modelDescriptor(for: "account.move").systemImage == "doc.text")
    }

    @Test
    func restoreSessionFallsBackToStaticRegistryWhenDiscoveryFails() async throws {
        let backendURL = URL(string: "http://127.0.0.1:35120")!
        let session = StoredSession(
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
        configuration.protocolClasses = [AppStateModelDiscoveryURLProtocol.self]

        AppStateModelDiscoveryURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(AppStateModelDiscoveryEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.hasSuffix("/modules/installed") {
                throw URLError(.badServerResponse)
            }

            throw URLError(.unsupportedURL)
        }

        let appState = AppState(
            config: .preview,
            sessionStore: AppStateModelDiscoverySessionStore(session: session),
            apiClient: APIClient(baseURL: backendURL, session: URLSession(configuration: configuration)),
            cacheStore: FileCacheStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        )

        await appState.restoreSession()

        #expect(appState.availableModels.map(\.model) == ModelRegistry.supported.map(\.model))
    }

    @Test
    func restoreSessionShowsNoBrowseModelsWhenDiscoverySucceedsWithEmptyCatalog() async throws {
        let backendURL = URL(string: "http://127.0.0.1:35120")!
        let session = StoredSession(
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
        configuration.protocolClasses = [AppStateModelDiscoveryURLProtocol.self]

        AppStateModelDiscoveryURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(AppStateModelDiscoveryEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.hasSuffix("/modules/installed") {
                return (200, try JSONEncoder().encode(AppStateModelDiscoveryEnvelope(data: InstalledModulesResponse(
                    modules: [InstalledModuleInfo(name: "project", displayName: "Project")],
                    browseModels: []
                ))))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = AppState(
            config: .preview,
            sessionStore: AppStateModelDiscoverySessionStore(session: session),
            apiClient: APIClient(baseURL: backendURL, session: URLSession(configuration: configuration)),
            cacheStore: FileCacheStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        )

        await appState.restoreSession()

        #expect(appState.hasLoadedBrowseDiscovery)
        #expect(appState.availableModels.isEmpty)
        #expect(appState.modelDescriptor(for: "project.task", fallbackTitle: "Tasks").title == "Tasks")
    }
}

private final class AppStateModelDiscoverySessionStore: SessionStoring {
    private var storedSession: StoredSession?

    init(session: StoredSession?) {
        storedSession = session
    }

    func load() throws -> StoredSession? { storedSession }
    func save(_ session: StoredSession) throws { storedSession = session }
    func clear() throws { storedSession = nil }
}

private final class AppStateModelDiscoveryURLProtocol: URLProtocol {
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

private struct AppStateModelDiscoveryEnvelope<T: Encodable>: Encodable {
    let success = true
    let data: T
    let meta: AppStateModelDiscoveryMeta? = nil
    let errors: [AppStateModelDiscoveryError] = []
}

private struct AppStateModelDiscoveryMeta: Encodable {
    let total: Int? = nil
    let offset: Int? = nil
    let limit: Int? = nil
    let timestamp: String? = nil
}

private struct AppStateModelDiscoveryError: Encodable {
    let code: String = ""
    let message: String = ""
    let field: String? = nil
}