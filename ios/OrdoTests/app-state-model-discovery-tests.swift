import Foundation
import Testing
@testable import Ordo

@Suite(.serialized)
@MainActor
struct AppStateModelDiscoveryTests {
    @Test
    func restoreSessionBuildsAvailableModelsFromDiscoveredBrowseMenuTree() async throws {
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
                    browseMenuTree: [
                        BrowseMenuNode(
                            id: 10,
                            name: "Contacts",
                            kind: .app,
                            model: "res.partner",
                            children: [
                                BrowseMenuNode(id: 11, name: "Contacts", kind: .leaf, model: "res.partner", children: []),
                            ]
                        ),
                        BrowseMenuNode(
                            id: 20,
                            name: "Accounting",
                            kind: .app,
                            model: "account.move",
                            children: [
                                BrowseMenuNode(id: 21, name: "Invoices", kind: .leaf, model: "account.move", children: []),
                            ]
                        ),
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

        #expect(appState.browseRoots.map(\.name) == ["Contacts", "Accounting"])
        #expect(appState.availableModels.map(\.model) == ["res.partner", "account.move"])
        #expect(appState.modelDescriptor(for: "res.partner").title == "Customers")
        #expect(appState.modelDescriptor(for: "account.move").title == "Invoices")
        #expect(appState.modelDescriptor(for: "account.move").systemImage == "doc.text")
    }

    @Test
    func restoreSessionKeepsBrowseCatalogEmptyWhenDiscoveryFails() async throws {
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

        #expect(!appState.hasLoadedBrowseDiscovery)
        #expect(appState.browseRoots.isEmpty)
        #expect(appState.availableModels.isEmpty)
        #expect(appState.browseDiscoveryErrorMessage == "Browse discovery could not be loaded right now. Try again in a moment.")
        #expect(appState.modelDescriptor(for: "crm.lead").title == "Leads")
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
                    browseMenuTree: []
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
        #expect(appState.browseDiscoveryErrorMessage == nil)
        #expect(appState.modelDescriptor(for: "project.task", fallbackTitle: "Tasks").title == "Tasks")
    }

    @Test
    func restoreSessionPrefersLeafTitleWhenAppAndLeafShareUnknownModel() async throws {
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
                    modules: [InstalledModuleInfo(name: "crm", displayName: "CRM")],
                    browseMenuTree: [
                        BrowseMenuNode(
                            id: 10,
                            name: "CRM",
                            kind: .app,
                            model: "x_pipeline.record",
                            children: [
                                BrowseMenuNode(
                                    id: 11,
                                    name: "Sales",
                                    kind: .category,
                                    model: nil,
                                    children: [
                                        BrowseMenuNode(id: 12, name: "Pipeline", kind: .leaf, model: "x_pipeline.record", children: []),
                                    ]
                                ),
                            ]
                        ),
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

        #expect(appState.availableModels.map(\ .model) == ["x_pipeline.record"])
        #expect(appState.modelDescriptor(for: "x_pipeline.record").title == "Pipeline")
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