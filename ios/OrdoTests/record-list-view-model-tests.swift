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

            if path.hasSuffix("/schema/res.partner/list") {
                throw URLError(.notConnectedToInternet)
            }

            if path.contains("/records/res.partner") {
                throw URLError(.notConnectedToInternet)
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let userDefaults = makeIsolatedUserDefaults()
        let cachedList = RecordListResult(items: [["id": .number(1), "name": .string("Azure Interior")]], limit: 30, offset: 0, total: 1)
        try await appState.cacheStore.saveListPage(
            cachedList,
            for: "res.partner",
            limit: 30,
            offset: 0,
            order: nil,
            domainKey: nil,
            fieldKey: "id,display_name,name,email,phone,city,country_id",
            scope: try #require(appState.cacheScope)
        )

        let viewModel = try makeViewModel(userDefaults: userDefaults)
        await viewModel.load(using: appState)

        #expect(viewModel.displayRows.map(\.summary.title) == ["Azure Interior"])
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

            if path.hasSuffix("/schema/res.partner/list") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: sampleListSchema)))
            }

            if path.contains("/records/res.partner") {
                return (401, Data())
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let viewModel = try makeViewModel(userDefaults: makeIsolatedUserDefaults())

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

            if path.hasSuffix("/schema/res.partner/list") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: sampleListSchema)))
            }

            if path.contains("/records/res.partner") {
                let order = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "order" })?.value
                requestedOrders.append(order)
                let payload = RecordListResult(items: [["id": .number(2), "name": .string("Deco Addict"), "email": .string("deco@example.com")]], limit: 30, offset: 0, total: 1)
                return (200, try JSONEncoder().encode(TestEnvelope(data: payload)))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let viewModel = try makeViewModel(userDefaults: makeIsolatedUserDefaults())

        await viewModel.apply(sortOption: .titleAscending, using: appState)

        #expect(requestedOrders == ["name asc"])
        #expect(viewModel.displayRows.map(\.summary.title) == ["Deco Addict"])

        let cached = await appState.cacheStore.loadListPage(
            for: "res.partner",
            limit: 30,
            offset: 0,
            order: "name asc",
            domainKey: nil,
            fieldKey: "id,display_name,name,email",
            scope: try #require(appState.cacheScope)
        )
        #expect(cached?.value.items.count == 1)

        let defaultCache = await appState.cacheStore.loadListPage(
            for: "res.partner",
            limit: 30,
            offset: 0,
            order: nil,
            domainKey: nil,
            fieldKey: "id,display_name,name,email",
            scope: try #require(appState.cacheScope)
        )
        #expect(defaultCache == nil)
    }

    @Test
    func applyingFiltersUsesDomainQueryAndCachesByDomain() async throws {
        var requestedDomains: [String?] = []

        ListViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.hasSuffix("/schema/res.partner/list") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: sampleListSchema)))
            }

            if path.contains("/records/res.partner") {
                let domain = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "domain" })?.value
                requestedDomains.append(domain)
                let payload = RecordListResult(items: [["id": .number(4), "name": .string("VIP Customer"), "email": .string("vip@example.com")]], limit: 30, offset: 0, total: 1)
                return (200, try JSONEncoder().encode(TestEnvelope(data: payload)))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let userDefaults = makeIsolatedUserDefaults()
        let viewModel = try makeViewModel(userDefaults: userDefaults)

        await viewModel.apply(
            filterState: BrowseFilterState(conditions: [
                BrowseFilterCondition(fieldName: "customer_rank", filterOperator: .greaterThan, value: .number(0)),
            ]),
            using: appState
        )

        let expectedDomain = "[[\"customer_rank\",\">\",0]]"
        #expect(requestedDomains == [expectedDomain])
        #expect(viewModel.activeFilterCount == 1)
        #expect(viewModel.displayRows.map(\.summary.title) == ["VIP Customer"])

        let filteredCache = await appState.cacheStore.loadListPage(
            for: "res.partner",
            limit: 30,
            offset: 0,
            order: nil,
            domainKey: expectedDomain,
            fieldKey: "id,display_name,name,email",
            scope: try #require(appState.cacheScope)
        )
        #expect(filteredCache?.value.items.count == 1)

        let defaultCache = await appState.cacheStore.loadListPage(
            for: "res.partner",
            limit: 30,
            offset: 0,
            order: nil,
            domainKey: nil,
            fieldKey: "id,display_name,name,email",
            scope: try #require(appState.cacheScope)
        )
        #expect(defaultCache == nil)
    }

    @Test
    func listSchemaControlsRequestedFieldsAndQuickFilterDomain() async throws {
        var requestedFields: [String?] = []
        var requestedDomains: [String?] = []

        ListViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.hasSuffix("/schema/res.partner/list") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: sampleListSchema)))
            }

            if path.contains("/records/res.partner") {
                let components = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)
                requestedFields.append(components?.queryItems?.first(where: { $0.name == "fields" })?.value)
                requestedDomains.append(components?.queryItems?.first(where: { $0.name == "domain" })?.value)

                let payload = RecordListResult(
                    items: [["id": .number(7), "name": .string("Quick Filter Customer"), "email": .string("vip@example.com")]],
                    limit: 30,
                    offset: 0,
                    total: 7
                )
                return (200, try JSONEncoder().encode(TestEnvelope(data: payload)))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let viewModel = try makeViewModel(userDefaults: makeIsolatedUserDefaults())

        await viewModel.load(using: appState)
        await viewModel.applyQuickFilter(named: "companies", using: appState)

        #expect(requestedFields == ["id,display_name,name,email", "id,display_name,name,email"])
        #expect(requestedDomains.last == "[[\"is_company\",\"=\",true]]")
        #expect(viewModel.tableColumns.map(\.name) == ["name", "email"])
        #expect(viewModel.totalDisplayText == "1 of 7")
    }

    @Test
    func schemaFilterDomainReplacesSelfPlaceholderInRequestDomain() async throws {
        var requestedDomains: [String?] = []

        ListViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.hasSuffix("/schema/res.partner/list") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: sampleListSchemaWithFilterDomain)))
            }

            if path.contains("/records/res.partner") {
                let domain = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "domain" })?.value
                requestedDomains.append(domain)
                let payload = RecordListResult(items: [["id": .number(11), "name": .string("Azure Interior")]], limit: 30, offset: 0, total: 1)
                return (200, try JSONEncoder().encode(TestEnvelope(data: payload)))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let viewModel = try makeViewModel(userDefaults: makeIsolatedUserDefaults())

        await viewModel.apply(
            filterState: BrowseFilterState(conditions: [
                BrowseFilterCondition(fieldName: "display_name", filterOperator: .contains, value: .string("azure")),
            ]),
            using: appState
        )

        #expect(requestedDomains == ["[\"|\",[\"display_name\",\"ilike\",\"azure\"],[\"name\",\"ilike\",\"azure\"]]"])

        let filteredCache = await appState.cacheStore.loadListPage(
            for: "res.partner",
            limit: 30,
            offset: 0,
            order: nil,
            domainKey: "[\"|\",[\"display_name\",\"ilike\",\"azure\"],[\"name\",\"ilike\",\"azure\"]]",
            fieldKey: "id,display_name,name,email",
            scope: try #require(appState.cacheScope)
        )
        #expect(filteredCache?.value.items.count == 1)
    }

    @Test
    func schemaFilterDomainCombinesWithQuickFilter() async throws {
        var requestedDomains: [String?] = []

        ListViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.hasSuffix("/schema/res.partner/list") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: sampleListSchemaWithFilterDomain)))
            }

            if path.contains("/records/res.partner") {
                let domain = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "domain" })?.value
                requestedDomains.append(domain)
                let payload = RecordListResult(items: [["id": .number(12), "name": .string("Azure Interior")]], limit: 30, offset: 0, total: 1)
                return (200, try JSONEncoder().encode(TestEnvelope(data: payload)))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let viewModel = try makeViewModel(userDefaults: makeIsolatedUserDefaults())

        await viewModel.load(using: appState)
        await viewModel.applyQuickFilter(named: "companies", using: appState)
        await viewModel.apply(
            filterState: BrowseFilterState(conditions: [
                BrowseFilterCondition(fieldName: "display_name", filterOperator: .contains, value: .string("azure")),
            ]),
            using: appState
        )

        #expect(requestedDomains.last == "[[\"is_company\",\"=\",true],\"|\",[\"display_name\",\"ilike\",\"azure\"],[\"name\",\"ilike\",\"azure\"]]")
    }

    @Test
    func schemaFieldWithoutFilterDomainKeepsLegacyClauseBehavior() async throws {
        var requestedDomains: [String?] = []

        ListViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.hasSuffix("/schema/res.partner/list") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: sampleListSchemaWithFilterDomain)))
            }

            if path.contains("/records/res.partner") {
                let domain = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "domain" })?.value
                requestedDomains.append(domain)
                let payload = RecordListResult(items: [["id": .number(13), "name": .string("Azure Interior")]], limit: 30, offset: 0, total: 1)
                return (200, try JSONEncoder().encode(TestEnvelope(data: payload)))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let viewModel = try makeViewModel(userDefaults: makeIsolatedUserDefaults())

        await viewModel.apply(
            filterState: BrowseFilterState(conditions: [
                BrowseFilterCondition(fieldName: "email", filterOperator: .contains, value: .string("azure")),
            ]),
            using: appState
        )

        #expect(requestedDomains == ["[[\"email\",\"ilike\",\"azure\"]]"])
    }

    @Test
    func retriesListSchemaAfterTransientFailure() async throws {
        var schemaRequestCount = 0

        ListViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.hasSuffix("/schema/res.partner/list") {
                schemaRequestCount += 1
                if schemaRequestCount == 1 {
                    throw URLError(.timedOut)
                }

                return (200, try JSONEncoder().encode(TestEnvelope(data: sampleListSchema)))
            }

            if path.contains("/records/res.partner") {
                let payload = RecordListResult(items: [["id": .number(9), "name": .string("Retry Customer"), "email": .string("retry@example.com")]], limit: 30, offset: 0, total: 1)
                return (200, try JSONEncoder().encode(TestEnvelope(data: payload)))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let viewModel = try makeViewModel(userDefaults: makeIsolatedUserDefaults())

        await viewModel.load(using: appState)
        await viewModel.load(using: appState)

        #expect(schemaRequestCount == 2)
        #expect(viewModel.tableColumns.map(\.name) == ["name", "email"])
    }

    @Test
    func applyingGroupByRequestsGroupedFieldAndBuildsSections() async throws {
        var requestedFields: [String?] = []

        ListViewModelTestURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            if path.hasSuffix("/auth/me") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: AuthenticatedPrincipal.preview)))
            }

            if path.hasSuffix("/schema/res.partner/list") {
                return (200, try JSONEncoder().encode(TestEnvelope(data: sampleListSchema)))
            }

            if path.contains("/records/res.partner") {
                let components = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)
                requestedFields.append(components?.queryItems?.first(where: { $0.name == "fields" })?.value)

                let payload = RecordListResult(
                    items: [
                        ["id": .number(1), "name": .string("Azure Interior"), "email": .string("azure@example.com"), "country_id": .relation(id: 233, label: "United States")],
                        ["id": .number(2), "name": .string("Deco Addict"), "email": .string("deco@example.com"), "country_id": .relation(id: 124, label: "Canada")],
                        ["id": .number(3), "name": .string("Northwind"), "email": .string("northwind@example.com"), "country_id": .relation(id: 233, label: "United States")],
                    ],
                    limit: 30,
                    offset: 0,
                    total: 3
                )
                return (200, try JSONEncoder().encode(TestEnvelope(data: payload)))
            }

            throw URLError(.unsupportedURL)
        }

        let appState = try await makeRestoredAppState()
        let viewModel = try makeViewModel(userDefaults: makeIsolatedUserDefaults())

        await viewModel.load(using: appState)
        await viewModel.applyGroupBy(named: "group_country", using: appState)

        #expect(requestedFields == ["id,display_name,name,email", "id,display_name,name,email,country_id"])
        #expect(viewModel.activeGroupBy?.fieldName == "country_id")
        #expect(viewModel.displaySections.map(\.title) == ["Canada", "United States"])
        #expect(viewModel.displaySections.first?.rows.map(\.summary.title) == ["Deco Addict"])
        #expect(viewModel.displaySections.last?.rows.map(\.summary.title) == ["Azure Interior", "Northwind"])
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

    private func makeViewModel(userDefaults: UserDefaults) throws -> RecordListViewModel {
        RecordListViewModel(
            descriptor: try #require(ModelRegistry.supported.first),
            userDefaults: userDefaults
        )
    }

    private func makeIsolatedUserDefaults() -> UserDefaults {
        let suiteName = "record-list-view-model-tests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
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

private let sampleListSchema = MobileListSchema(
    model: "res.partner",
    title: "Customers",
    columns: [
        ListColumn(name: "name", type: .char, label: "Name", comodel: nil, selection: nil, widget: nil, optional: nil, columnInvisible: nil),
        ListColumn(name: "email", type: .char, label: "Email", comodel: nil, selection: nil, widget: nil, optional: .show, columnInvisible: nil),
        ListColumn(name: "phone", type: .char, label: "Phone", comodel: nil, selection: nil, widget: nil, optional: .hide, columnInvisible: nil),
    ],
    defaultOrder: "name asc",
    search: .init(
        fields: [
            SearchField(name: "name", label: "Name", type: .char, filterDomain: nil, selection: nil),
            SearchField(name: "email", label: "Email", type: .char, filterDomain: nil, selection: nil),
            SearchField(name: "customer_rank", label: "Customer Rank", type: .float, filterDomain: nil, selection: nil),
        ],
        filters: [
            SearchFilter(name: "companies", label: "Companies", domain: "[[\"is_company\",\"=\",true]]"),
        ],
        groupBy: [
            SearchGroupBy(name: "group_country", label: "Country", fieldName: "country_id"),
        ]
    )
)

private let sampleListSchemaWithFilterDomain = MobileListSchema(
    model: "res.partner",
    title: "Customers",
    columns: [
        ListColumn(name: "name", type: .char, label: "Name", comodel: nil, selection: nil, widget: nil, optional: nil, columnInvisible: nil),
        ListColumn(name: "email", type: .char, label: "Email", comodel: nil, selection: nil, widget: nil, optional: .show, columnInvisible: nil),
    ],
    defaultOrder: "name asc",
    search: .init(
        fields: [
            SearchField(name: "display_name", label: "Customer", type: .char, filterDomain: "[\"|\",[\"display_name\",\"ilike\",\"self\"],[\"name\",\"ilike\",\"self\"]]", selection: nil),
            SearchField(name: "email", label: "Email", type: .char, filterDomain: nil, selection: nil),
        ],
        filters: [
            SearchFilter(name: "companies", label: "Companies", domain: "[[\"is_company\",\"=\",true]]"),
        ],
        groupBy: []
    )
)