import Foundation
import Testing
@testable import Ordo

@Suite(.serialized)
@MainActor
struct RecordChatterViewModelTests {
    @Test
    func loadFetchesMessagesFromBackend() async throws {
        ChatterViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(ChatterEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.contains("/records/res.partner/1/chatter") && request.httpMethod == "GET" {
                return (200, try JSONEncoder().encode(ChatterEnvelope(data: threadResult)))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeAppState()
        let viewModel = RecordChatterViewModel(model: "res.partner", recordID: 1)

        await viewModel.loadIfNeeded(using: appState)

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.plainBody == "Internal note")
        #expect(viewModel.hasMore == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func postNotePrependsMessageAndClearsDraft() async throws {
        ChatterViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(ChatterEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.contains("/records/res.partner/1/chatter/note") && request.httpMethod == "POST" {
                return (201, try JSONEncoder().encode(ChatterEnvelope(data: threadResult.messages[0])))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeAppState()
        let viewModel = RecordChatterViewModel(model: "res.partner", recordID: 1)
        viewModel.draftBody = "  Internal note  "

        let didPost = await viewModel.postNote(using: appState)

        #expect(didPost == true)
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.id == 91)
        #expect(viewModel.draftBody.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    private func makeAppState() async throws -> AppState {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ChatterViewModelTestURLProtocol.self]

        let sessionStore = ChatterSessionStore(session: .preview)
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

private let threadResult = ChatterThreadResult(
    messages: [ChatterMessage(
        id: 91,
        body: "<p>Internal note</p>",
        plainBody: "Internal note",
        date: "2026-03-08 10:00:00",
        messageType: "comment",
        isNote: true,
        isDiscussion: false,
        author: ChatterAuthor(id: 7, name: "Administrator", type: "partner")
    )],
    limit: 20,
    hasMore: false,
    nextBefore: nil
)

private final class ChatterViewModelTestURLProtocol: URLProtocol {
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

private final class ChatterSessionStore: SessionStoring {
    private var storedSession: StoredSession?
    init(session: StoredSession?) { self.storedSession = session }
    func load() throws -> StoredSession? { storedSession }
    func save(_ session: StoredSession) throws { storedSession = session }
    func clear() throws { storedSession = nil }
}

private struct ChatterEnvelope<T: Encodable>: Encodable {
    let success = true
    let data: T
    let meta: ChatterMeta? = nil
    let errors: [ChatterErrorPayload] = []
}

private struct ChatterMeta: Encodable { let total: Int? = nil; let offset: Int? = nil; let limit: Int? = nil; let timestamp: String? = nil }
private struct ChatterErrorPayload: Encodable { let code: String = ""; let message: String = ""; let field: String? = nil }