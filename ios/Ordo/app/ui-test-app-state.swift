import Foundation

enum UITestAppStateFactory {
    static func make() -> AppState? {
        let environment = ProcessInfo.processInfo.environment
        guard environment["ORDO_UI_TEST_MODE"] == "smoke" else { return nil }

        let defaults = UserDefaults(suiteName: "com.ordo.app.ui-tests") ?? .standard
        let sessionStore = UserDefaultsSessionStore(defaults: defaults)
        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "OrdoUITestCache", directoryHint: .isDirectory)

        if environment["ORDO_UI_TEST_RESET_STORAGE"] == "1" {
            try? sessionStore.clear()
            try? fileManager.removeItem(at: cacheDirectory)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UITestURLProtocol.self]

        let config = AppConfig.load()
        let apiClient = APIClient(baseURL: config.defaultBaseURL, session: URLSession(configuration: configuration))
        let cacheStore = FileCacheStore(baseDirectoryURL: cacheDirectory, fileManager: fileManager)

        return AppState(
            config: config,
            sessionStore: sessionStore,
            apiClient: apiClient,
            cacheStore: cacheStore
        )
    }
}

private final class UITestURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let client, let url = request.url else { return }

        do {
            let (statusCode, data) = try Self.response(for: request)
            let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: data)
            client.urlProtocolDidFinishLoading(self)
        } catch {
            client.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func response(for request: URLRequest) throws -> (Int, Data) {
        let encoder = JSONEncoder()
        let path = request.url?.path ?? ""

        if path.hasSuffix("/auth/login") {
            return (200, try encoder.encode(UITestEnvelope(data: UITestFixtures.tokenResponse, meta: nil)))
        }

        if path.hasSuffix("/auth/refresh") {
            return (200, try encoder.encode(UITestEnvelope(data: UITestFixtures.tokenResponse, meta: nil)))
        }

        if path.hasSuffix("/auth/me") {
            return (200, try encoder.encode(UITestEnvelope(data: UITestFixtures.principal, meta: nil)))
        }

        if path.hasSuffix("/schema/res.partner") {
            return (200, try encoder.encode(UITestEnvelope(data: UITestFixtures.schema, meta: nil)))
        }

        if path.hasSuffix("/records/res.partner") {
            let offset = request.url.flatMap(Self.queryItems(from:))?["offset"].flatMap(Int.init) ?? 0
            let result = UITestFixtures.listPage(offset: offset)
            let meta = UITestMeta(total: result.items.count, offset: result.offset, limit: result.limit, timestamp: nil)
            return (200, try encoder.encode(UITestEnvelope(data: result, meta: meta)))
        }

        if path.contains("/records/res.partner/") && request.httpMethod == "PATCH" {
            let body = request.httpBody ?? Data()
            let mutationRequest = try JSONDecoder().decode(RecordMutationRequest.self, from: body)
            let recordID = Int(request.url?.lastPathComponent ?? "") ?? 1
            let updatedRecord = UITestFixtures.updatedRecord(id: recordID, values: mutationRequest.values)
            let result = RecordMutationResult(id: recordID, record: updatedRecord)
            return (200, try encoder.encode(UITestEnvelope(data: result, meta: nil)))
        }

        if path.contains("/records/res.partner/") {
            let recordID = Int(request.url?.lastPathComponent ?? "") ?? 1
            return (200, try encoder.encode(UITestEnvelope(data: UITestFixtures.record(id: recordID), meta: nil)))
        }

        if path.hasSuffix("/search/res.partner") {
            return (200, try encoder.encode(UITestEnvelope(data: UITestFixtures.searchResults, meta: nil)))
        }

        return (
            404,
            try encoder.encode(
                UITestEnvelope<JSONValue>(
                    success: false,
                    data: .null,
                    meta: nil,
                    errors: [UITestError(code: "not_found", message: "Fixture route not found.", field: nil)]
                )
            )
        )
    }

    private nonisolated static func queryItems(from url: URL) -> [String: String]? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.reduce(into: [:]) { result, item in
            result[item.name] = item.value
        }
    }
}

private enum UITestFixtures {
    static let tokenResponse = TokenResponse(
        accessToken: "ui-test-access-token",
        refreshToken: "ui-test-refresh-token",
        expiresIn: 3600,
        user: AuthUser(id: 1, name: "Demo Admin", email: "admin@example.com", lang: "en_US", tz: "UTC", avatarUrl: nil)
    )

    static let principal = AuthenticatedPrincipal(
        uid: 1,
        db: "odoo17",
        odooUrl: "http://127.0.0.1:38421",
        version: "17.0",
        lang: "en_US",
        groups: [1],
        name: "Demo Admin",
        email: "admin@example.com",
        tz: "UTC"
    )

    static let schema = MobileFormSchema(
        model: "res.partner",
        title: "Customer",
        header: FormHeader(statusbar: nil, actions: []),
        sections: [FormSection(label: "Contact", fields: [
            FieldSchema(name: "name", type: .char, label: "Name", required: true, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "nickname", type: .char, label: "Nickname", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: "Optional nickname", digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "email", type: .char, label: "Email", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "phone", type: .char, label: "Phone", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "is_company", type: .boolean, label: "Company", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "customer_rank", type: .selection, label: "Customer Rank", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: [["standard", "Standard"], ["vip", "VIP"]], currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "credit_limit", type: .monetary, label: "Credit Limit", required: nil, readonly: true, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: "currency_id", placeholder: nil, digits: [16, 2], subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "priority", type: .priority, label: "Priority", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "city", type: .char, label: "City", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "country_id", type: .many2one, label: "Country", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "res.country", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
        ])],
        tabs: [FormTab(label: "Notes", content: ["sections": encodedSections([
            FormSection(label: "Notes", fields: [
                FieldSchema(name: "comment", type: .text, label: "Notes", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
                FieldSchema(name: "internal_note", type: .text, label: "Internal Note", required: nil, readonly: nil, invisible: Condition(field: "is_company", op: "==", value: "false", values: nil), domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            ]),
        ])])],
        hasChatter: false
    )

    static let searchResults = [
        NameSearchResult(id: 1, name: "Azure Interior"),
        NameSearchResult(id: 2, name: "Deco Addict"),
    ]

    static func listPage(offset: Int) -> RecordListResult {
        let items = [record(id: 1), record(id: 2), record(id: 3)]
        let pagedItems = offset == 0 ? items : []
        return RecordListResult(items: pagedItems, limit: 30, offset: offset)
    }

    static func record(id: Int) -> RecordData {
        let names = ["Azure Interior", "Deco Addict", "Gemini Furniture"]
        let emails = ["azure@example.com", "deco@example.com", "gemini@example.com"]
        let phones = ["+1 555-0101", "+1 555-0102", "+1 555-0103"]
        let cities = ["San Francisco", "Austin", "Seattle"]
        let index = max(0, min(id - 1, 2))

        return [
            "id": .number(Double(id)),
            "display_name": .string(names[index]),
            "name": .string(names[index]),
            "nickname": .string("VIP \(id)"),
            "email": .string(emails[index]),
            "phone": .string(phones[index]),
            "is_company": .bool(false),
            "customer_rank": .string(index == 0 ? "vip" : "standard"),
            "credit_limit": .number(2500.5),
            "priority": .string(index == 0 ? "2" : "1"),
            "city": .string(cities[index]),
            "country_id": .array([.number(233), .string("United States")]),
            "currency_id": .array([.number(1), .string("USD")]),
            "comment": .string("Preferred customer"),
            "internal_note": .string("Backoffice only"),
        ]
    }

    static func updatedRecord(id: Int, values: RecordData) -> RecordData {
        var record = record(id: id)
        for (key, value) in values {
            record[key] = value
            if key == "name", let name = value.stringValue {
                record["display_name"] = .string(name)
            }
        }
        return record
    }

    private static func encodedSections(_ sections: [FormSection]) -> JSONValue {
        do {
            let data = try JSONEncoder().encode(sections)
            return try JSONDecoder().decode(JSONValue.self, from: data)
        } catch {
            return .array([])
        }
    }
}

private struct UITestEnvelope<T: Encodable>: Encodable {
    let success: Bool
    let data: T
    let meta: UITestMeta?
    let errors: [UITestError]

    init(success: Bool = true, data: T, meta: UITestMeta?, errors: [UITestError] = []) {
        self.success = success
        self.data = data
        self.meta = meta
        self.errors = errors
    }
}

private struct UITestMeta: Encodable {
    let total: Int?
    let offset: Int?
    let limit: Int?
    let timestamp: String?
}

private struct UITestError: Encodable {
    let code: String
    let message: String
    let field: String?
}
