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

            if path.contains("/records/res.partner/1/chatter/details") && request.httpMethod == "GET" {
                return (200, try JSONEncoder().encode(ChatterEnvelope(data: detailsResult)))
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
        #expect(viewModel.followersCount == 1)
        #expect(viewModel.isFollowing == true)
        #expect(viewModel.activities.count == 1)
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

    @Test
    func toggleFollowingUpdatesFollowerState() async throws {
        ChatterViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(ChatterEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.contains("/records/res.partner/1/chatter/details") && request.httpMethod == "GET" {
                return (200, try JSONEncoder().encode(ChatterEnvelope(data: detailsResult)))
            }

            if path.contains("/records/res.partner/1/chatter") && request.httpMethod == "GET" {
                return (200, try JSONEncoder().encode(ChatterEnvelope(data: threadResult)))
            }

            if path.contains("/records/res.partner/1/chatter/follow") && request.httpMethod == "DELETE" {
                return (200, try JSONEncoder().encode(ChatterEnvelope(data: unfollowedDetailsResult)))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeAppState()
        let viewModel = RecordChatterViewModel(model: "res.partner", recordID: 1)
        await viewModel.refresh(using: appState)

        let didToggle = await viewModel.toggleFollowing(using: appState)

        #expect(didToggle == true)
        #expect(viewModel.isFollowing == false)
        #expect(viewModel.followersCount == 0)
        #expect(viewModel.followers.isEmpty)
    }

    @Test
    func completeActivityRefreshesActivities() async throws {
        ChatterViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(ChatterEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.contains("/records/res.partner/1/chatter/details") && request.httpMethod == "GET" {
                return (200, try JSONEncoder().encode(ChatterEnvelope(data: detailsResult)))
            }

            if path.contains("/records/res.partner/1/chatter") && request.httpMethod == "GET" {
                return (200, try JSONEncoder().encode(ChatterEnvelope(data: threadResult)))
            }

            if path.contains("/records/res.partner/1/chatter/activities/44/done") && request.httpMethod == "POST" {
                return (200, try JSONEncoder().encode(ChatterEnvelope(data: completedActivityDetailsResult)))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeAppState()
        let viewModel = RecordChatterViewModel(model: "res.partner", recordID: 1)
        await viewModel.refresh(using: appState)

        let didComplete = await viewModel.completeActivity(id: 44, using: appState)

        #expect(didComplete == true)
        #expect(viewModel.activities.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func scheduleActivityRefreshesActivities() async throws {
        var capturedRequest: ScheduleChatterActivityRequest?

        ChatterViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(ChatterEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.contains("/records/res.partner/1/chatter/details") && request.httpMethod == "GET" {
                return (200, try JSONEncoder().encode(ChatterEnvelope(data: detailsResult)))
            }

            if path.contains("/records/res.partner/1/chatter") && request.httpMethod == "GET" {
                return (200, try JSONEncoder().encode(ChatterEnvelope(data: threadResult)))
            }

            if path.hasSuffix("/records/res.partner/1/chatter/activities") && request.httpMethod == "POST" {
                capturedRequest = try JSONDecoder().decode(ScheduleChatterActivityRequest.self, from: try #require(request.httpBody))
                return (200, try JSONEncoder().encode(ChatterEnvelope(data: scheduledActivityDetailsResult)))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeAppState()
        let viewModel = RecordChatterViewModel(model: "res.partner", recordID: 1)
        await viewModel.refresh(using: appState)

        let deadline = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 3, day: 12))
        let didSchedule = await viewModel.scheduleActivity(
            activityTypeId: 3,
            summary: "Call customer",
            note: "Ask for update",
            dateDeadline: deadline,
            using: appState
        )

        #expect(didSchedule == true)
        #expect(capturedRequest?.activityTypeId == 3)
        #expect(capturedRequest?.summary == "Call customer")
        #expect(capturedRequest?.note == "Ask for update")
        #expect(capturedRequest?.dateDeadline == "2026-03-12")
        #expect(viewModel.activities.count == 2)
        #expect(viewModel.availableActivityTypes.count == 1)
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

private let detailsResult = ChatterDetailsResult(
    followers: [ChatterFollower(id: 15, partnerId: 7, name: "Administrator", email: "admin@example.com", isActive: true, isSelf: true)],
    followersCount: 1,
    selfFollower: ChatterFollower(id: 15, partnerId: 7, name: "Administrator", email: "admin@example.com", isActive: true, isSelf: true),
    activities: [ChatterActivity(id: 44, typeId: 3, typeName: "To Do", summary: "Follow up", note: "<p>Call back tomorrow</p>", plainNote: "Call back tomorrow", dateDeadline: "2026-03-10", state: "planned", canWrite: true, assignedUser: ChatterActivityAssignee(id: 2, name: "Administrator"))],
    availableActivityTypes: [ChatterActivityTypeOption(id: 3, name: "To Do", summary: "Follow up", icon: "fa-tasks", defaultNote: "<p>Default note</p>")]
)

private let unfollowedDetailsResult = ChatterDetailsResult(
    followers: [],
    followersCount: 0,
    selfFollower: nil,
    activities: detailsResult.activities,
    availableActivityTypes: detailsResult.availableActivityTypes
)

private let completedActivityDetailsResult = ChatterDetailsResult(
    followers: detailsResult.followers,
    followersCount: detailsResult.followersCount,
    selfFollower: detailsResult.selfFollower,
    activities: [],
    availableActivityTypes: detailsResult.availableActivityTypes
)

private let scheduledActivityDetailsResult = ChatterDetailsResult(
    followers: detailsResult.followers,
    followersCount: detailsResult.followersCount,
    selfFollower: detailsResult.selfFollower,
    activities: detailsResult.activities + [
        ChatterActivity(
            id: 45,
            typeId: 3,
            typeName: "To Do",
            summary: "Call customer",
            note: "<p>Ask for update</p>",
            plainNote: "Ask for update",
            dateDeadline: "2026-03-12",
            state: "planned",
            canWrite: true,
            assignedUser: ChatterActivityAssignee(id: 2, name: "Administrator")
        )
    ],
    availableActivityTypes: detailsResult.availableActivityTypes
)

private final class ChatterViewModelTestURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        guard let client, let url = request.url, let requestHandler = Self.requestHandler else { return }
        do {
            let normalizedRequest = request.withMaterializedHTTPBody()
            let (statusCode, data) = try requestHandler(normalizedRequest)
            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: data)
            client.urlProtocolDidFinishLoading(self)
        } catch {
            client.urlProtocol(self, didFailWithError: error)
        }
    }
}

private extension URLRequest {
    func withMaterializedHTTPBody() -> URLRequest {
        guard httpBody == nil, let httpBodyStream else { return self }

        let data = Data(reading: httpBodyStream)
        var request = self
        request.httpBody = data.isEmpty ? nil : data
        return request
    }
}

private extension Data {
    init(reading stream: InputStream) {
        stream.open()
        defer { stream.close() }

        var buffer = [UInt8](repeating: 0, count: 4096)
        var data = Data()

        while true {
            let readCount = stream.read(&buffer, maxLength: buffer.count)

            if readCount < 0 {
                break
            }

            if readCount == 0 {
                break
            }

            data.append(buffer, count: readCount)
        }

        self = data
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