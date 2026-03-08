import Foundation
import Testing
@testable import Ordo

@Suite(.serialized)
@MainActor
struct RecordDetailViewModelTests {
    @Test
    func loadUsesCachedSchemaAndRecordWhenNetworkFails() async throws {
        DetailViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(DetailEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.contains("/schema/res.partner") {
                throw URLError(.notConnectedToInternet)
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        try await appState.cacheStore.saveSchema(partnerSchema, for: "res.partner", scope: try #require(appState.cacheScope))
        try await appState.cacheStore.saveRecord(partnerRecord, for: "res.partner", id: 1, scope: try #require(appState.cacheScope))

        let viewModel = RecordDetailViewModel(descriptor: try #require(ModelRegistry.supported.first), recordID: 1)
        await viewModel.load(using: appState)

        #expect(viewModel.schema?.model == "res.partner")
        #expect(viewModel.record?["name"]?.stringValue == "Azure Interior")
        #expect(viewModel.cacheMessage?.contains("saved data") == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func saveValidationErrorsPreventNetworkWrite() async throws {
        var patchRequestCount = 0

        DetailViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(DetailEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.contains("/schema/res.partner") {
                return (200, try JSONEncoder().encode(DetailEnvelope(data: partnerSchema)))
            }

            if path.contains("/records/res.partner/1") && request.httpMethod == "GET" {
                return (200, try JSONEncoder().encode(DetailEnvelope(data: partnerRecord)))
            }

            if path.contains("/records/res.partner/1") && request.httpMethod == "PATCH" {
                patchRequestCount += 1
                return (200, try JSONEncoder().encode(DetailEnvelope(data: RecordMutationResult(id: 1, record: partnerRecord))))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let viewModel = RecordDetailViewModel(descriptor: try #require(ModelRegistry.supported.first), recordID: 1)
        await viewModel.load(using: appState)

        let draft = try #require(viewModel.startEditing())
        draft.setValue(nil, for: "name")
        let didSave = await viewModel.save(draft: draft, using: appState)

        #expect(didSave == false)
        #expect(viewModel.validationErrors["name"] == "Name is required.")
        #expect(patchRequestCount == 0)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func createFlowPostsMutationAndTransitionsIntoDetailMode() async throws {
        var createRequestCount = 0

        DetailViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(DetailEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.contains("/schema/res.partner") {
                return (200, try JSONEncoder().encode(DetailEnvelope(data: partnerSchema)))
            }

            if path.hasSuffix("/records/res.partner") && request.httpMethod == "POST" {
                createRequestCount += 1
                return (200, try JSONEncoder().encode(DetailEnvelope(data: RecordMutationResult(id: 99, record: createdPartnerRecord))))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let viewModel = RecordDetailViewModel(descriptor: try #require(ModelRegistry.supported.first), recordID: nil)
        await viewModel.load(using: appState)

        let draft = FormDraft(record: [:])
        draft.setValue(.string("New Customer"), for: "name")

        let didSave = await viewModel.save(draft: draft, using: appState)

        #expect(didSave == true)
        #expect(createRequestCount == 1)
        #expect(viewModel.recordID == 99)
        #expect(viewModel.record?["name"]?.stringValue == "New Customer")
        #expect(viewModel.saveMessage == "Record created.")
        #expect(viewModel.isCreating == false)
    }

    @Test
    func applyFieldEditDebouncesOnchangeAndSurfacesWarnings() async throws {
        var capturedRequest: OnchangeRequest?

        DetailViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(DetailEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.contains("/schema/res.partner") {
                return (200, try JSONEncoder().encode(DetailEnvelope(data: partnerSchemaWithOnchange)))
            }

            if path.contains("/records/res.partner/1") && request.httpMethod == "GET" {
                return (200, try JSONEncoder().encode(DetailEnvelope(data: partnerRecord)))
            }

            if path.hasSuffix("/records/res.partner/onchange") && request.httpMethod == "POST" {
                capturedRequest = try JSONDecoder().decode(OnchangeRequest.self, from: try #require(request.httpBody))
                return (201, try JSONEncoder().encode(DetailEnvelope(data: OnchangeResult(
                    values: ["nickname": .string("Server VIP")],
                    warnings: [OnchangeWarning(title: "Heads up", message: "Nickname refreshed.", type: "warning")],
                    domains: nil
                ))))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let viewModel = RecordDetailViewModel(descriptor: try #require(ModelRegistry.supported.first), recordID: 1)
        await viewModel.load(using: appState)

        let draft = try #require(viewModel.startEditing())
        let nameField = try #require(viewModel.schema?.allFields.first(where: { $0.name == "name" }))

        viewModel.applyFieldEdit(.string("Acme"), for: nameField, draft: draft, using: appState)
        try await Task.sleep(for: .milliseconds(1200))

        #expect(capturedRequest?.triggerField == "name")
        #expect(capturedRequest?.recordId == 1)
        #expect(capturedRequest?.values["name"] == .string("Acme"))
        #expect(draft.value(for: "nickname", fallback: nil) == .string("Server VIP"))
        #expect(viewModel.onchangeWarnings.first?.message == "Nickname refreshed.")
    }

    @Test
    func staleOnchangeResponsesDoNotOverwriteNewerDraftEdits() async throws {
        var requestOrder: [String] = []

        DetailViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(DetailEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.contains("/schema/res.partner") {
                return (200, try JSONEncoder().encode(DetailEnvelope(data: partnerSchemaWithOnchange)))
            }

            if path.contains("/records/res.partner/1") && request.httpMethod == "GET" {
                return (200, try JSONEncoder().encode(DetailEnvelope(data: partnerRecord)))
            }

            if path.hasSuffix("/records/res.partner/onchange") && request.httpMethod == "POST" {
                let payload = try JSONDecoder().decode(OnchangeRequest.self, from: try #require(request.httpBody))
                let typedName = payload.values["name"]?.stringValue ?? ""
                requestOrder.append(typedName)

                if typedName == "Ac" {
                    Thread.sleep(forTimeInterval: 0.4)
                    return (201, try JSONEncoder().encode(DetailEnvelope(data: OnchangeResult(
                        values: ["nickname": .string("Old Nick")],
                        warnings: nil,
                        domains: nil
                    ))))
                }

                Thread.sleep(forTimeInterval: 0.05)
                return (201, try JSONEncoder().encode(DetailEnvelope(data: OnchangeResult(
                    values: ["nickname": .string("Fresh Nick")],
                    warnings: nil,
                    domains: nil
                ))))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let viewModel = RecordDetailViewModel(descriptor: try #require(ModelRegistry.supported.first), recordID: 1)
        await viewModel.load(using: appState)

        let draft = try #require(viewModel.startEditing())
        let nameField = try #require(viewModel.schema?.allFields.first(where: { $0.name == "name" }))

        viewModel.applyFieldEdit(.string("Ac"), for: nameField, draft: draft, using: appState)
        try await Task.sleep(for: .milliseconds(350))
        viewModel.applyFieldEdit(.string("Ace"), for: nameField, draft: draft, using: appState)
        try await Task.sleep(for: .milliseconds(1200))

        #expect(requestOrder.last == "Ace")
        #expect(draft.value(for: "name", fallback: nil) == .string("Ace"))
        #expect(draft.value(for: "nickname", fallback: nil) == .string("Fresh Nick"))
    }

    private func makeRestoredAppState() async throws -> AppState {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DetailViewModelTestURLProtocol.self]

        let sessionStore = DetailSessionStore(session: .preview)
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

private let partnerSchema = MobileFormSchema(
    model: "res.partner",
    title: "Customer",
    header: FormHeader(statusbar: nil, actions: []),
    sections: [FormSection(label: "Contact", fields: [
        FieldSchema(name: "name", type: .char, label: "Name", required: true, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
        FieldSchema(name: "nickname", type: .char, label: "Nickname", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
    ])],
    tabs: [],
    hasChatter: false
)

private let partnerSchemaWithOnchange = MobileFormSchema(
    model: "res.partner",
    title: "Customer",
    header: FormHeader(statusbar: nil, actions: []),
    sections: [FormSection(label: "Contact", fields: [
        FieldSchema(name: "name", type: .char, label: "Name", required: true, readonly: nil, invisible: nil, modifiers: nil, onchange: OnchangeFieldMeta(trigger: "name", source: "view", dependencies: ["nickname"], mergeReturnedValue: true), domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
        FieldSchema(name: "nickname", type: .char, label: "Nickname", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
    ])],
    tabs: [],
    hasChatter: false
)

private let partnerRecord: RecordData = [
    "id": .number(1),
    "display_name": .string("Azure Interior"),
    "name": .string("Azure Interior"),
    "nickname": .string("VIP 1"),
]

private let createdPartnerRecord: RecordData = [
    "id": .number(99),
    "display_name": .string("New Customer"),
    "name": .string("New Customer"),
    "nickname": .null,
]

private final class DetailViewModelTestURLProtocol: URLProtocol {
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

private final class DetailSessionStore: SessionStoring {
    private var storedSession: StoredSession?
    init(session: StoredSession?) { self.storedSession = session }
    func load() throws -> StoredSession? { storedSession }
    func save(_ session: StoredSession) throws { storedSession = session }
    func clear() throws { storedSession = nil }
}

private struct DetailEnvelope<T: Encodable>: Encodable {
    let success = true
    let data: T
    let meta: DetailMeta? = nil
    let errors: [DetailErrorPayload] = []
}

private struct DetailMeta: Encodable { let total: Int? = nil; let offset: Int? = nil; let limit: Int? = nil; let timestamp: String? = nil }
private struct DetailErrorPayload: Encodable { let code: String = ""; let message: String = ""; let field: String? = nil }