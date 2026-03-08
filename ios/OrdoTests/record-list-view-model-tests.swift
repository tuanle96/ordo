import Foundation
import Testing
@testable import Ordo

@Suite(.serialized)
@MainActor
struct RecordListViewModelTests {
    @Test
    func loadUsesCachedPageWhenNetworkFails() async throws {
        ListViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.contains("/records/res.partner") {
                throw URLError(.notConnectedToInternet)
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let cachedList = RecordListResult(items: [["id": .number(1), "name": .string("Azure Interior")]], limit: 30, offset: 0)
        try await appState.cacheStore.saveListPage(cachedList, for: "res.partner", limit: 30, offset: 0, order: nil, scope: try #require(appState.cacheScope))

        let viewModel = RecordListViewModel(descriptor: try #require(ModelRegistry.supported.first))
        await viewModel.load(using: appState)

        #expect(viewModel.summaries.map(\.title) == ["Azure Interior"])
        #expect(viewModel.cacheMessage?.contains("saved data") == true)
        #expect(viewModel.errorMessage == nil)
        #expect(appState.phase == .authenticated)
    }

    @Test
    func unauthorizedListResponseSignsUserOut() async throws {
        ListViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.contains("/records/res.partner") {
                return (401, Data())
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let viewModel = RecordListViewModel(descriptor: try #require(ModelRegistry.supported.first))

        await viewModel.load(using: appState)

        #expect(appState.phase == .login)
        #expect(appState.session == nil)
        #expect(appState.currentPrincipal == nil)
    }

    @Test
    func applyingSortUsesOrderQueryAndIsolatesCacheByOrder() async throws {
        var requestedOrders: [String?] = []

        ListViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.contains("/records/res.partner") {
                let order = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "order" })?.value
                requestedOrders.append(order)
                let payload = RecordListResult(items: [["id": .number(2), "name": .string("Deco Addict")]], limit: 30, offset: 0)
                return (200, try JSONEncoder().encode(TestEnvelope(data: payload)))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let viewModel = RecordListViewModel(descriptor: try #require(ModelRegistry.supported.first))

        await viewModel.apply(sortOption: .titleAscending, using: appState)

        #expect(requestedOrders == ["name asc"])
        #expect(viewModel.summaries.map(\.title) == ["Deco Addict"])

        let cached = await appState.cacheStore.loadListPage(for: "res.partner", limit: 30, offset: 0, order: "name asc", scope: try #require(appState.cacheScope))
        #expect(cached?.value.items.count == 1)

        let defaultCache = await appState.cacheStore.loadListPage(for: "res.partner", limit: 30, offset: 0, order: nil, scope: try #require(appState.cacheScope))
        #expect(defaultCache == nil)
    }

    private func makeRestoredAppState() async throws -> AppState {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ListViewModelTestURLProtocol.self]

        let sessionStore = TestSessionStore(session: .preview)
        let cacheStore = FileCacheStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        let appState = AppState(
            config: .preview,
            sessionStore: sessionStore,
            apiClient: APIClient(baseURL: URL(string: AppConfig.fallbackBaseURL)!, session: URLSession(configuration: configuration)),
            cacheStore: cacheStore
        )

        await appState.restoreSession()
        return appState
    }
}

private final class ListViewModelTestURLProtocol: URLProtocol {
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

private final class TestSessionStore: SessionStoring {
    private var storedSession: StoredSession?
    init(session: StoredSession?) { self.storedSession = session }
    func load() throws -> StoredSession? { storedSession }
    func save(_ session: StoredSession) throws { storedSession = session }
    func clear() throws { storedSession = nil }
}

private struct TestEnvelope<T: Encodable>: Encodable {
    let success = true
    let data: T
    let meta: TestMeta? = nil
    let errors: [TestErrorPayload] = []
}

private struct TestMeta: Encodable { let total: Int? = nil; let offset: Int? = nil; let limit: Int? = nil; let timestamp: String? = nil }
private struct TestErrorPayload: Encodable { let code: String = ""; let message: String = ""; let field: String? = nil }