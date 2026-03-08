import Foundation

enum UITestAppStateFactory {
    static func make() -> AppState? {
        let environment = ProcessInfo.processInfo.environment
        guard environment["ORDO_UI_TEST_MODE"] == "smoke" else { return nil }

        let suiteName = storageSuiteName(from: environment)
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let sessionStore = UserDefaultsSessionStore(defaults: defaults)
        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "OrdoUITestCache", directoryHint: .isDirectory)
            .appending(path: environment["ORDO_UI_TEST_STORAGE_NAMESPACE"] ?? "default", directoryHint: .isDirectory)

        if environment["ORDO_UI_TEST_RESET_STORAGE"] == "1" {
            defaults.removePersistentDomain(forName: suiteName)
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

    static func storageSuiteName(from environment: [String: String]) -> String {
        guard let namespace = environment["ORDO_UI_TEST_STORAGE_NAMESPACE"], !namespace.isEmpty else {
            return "com.ordo.app.ui-tests"
        }

        return "com.ordo.app.ui-tests.\(namespace)"
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

        if path.hasPrefix("/api/v1/mobile/schema/") {
            let model = String(path.dropFirst("/api/v1/mobile/schema/".count))
            guard let schema = UITestFixtures.schema(for: model) else {
                return notFound(encoder: encoder)
            }
            return (200, try encoder.encode(UITestEnvelope(data: schema, meta: nil)))
        }

        if path.hasPrefix("/api/v1/mobile/records/") {
            let suffix = String(path.dropFirst("/api/v1/mobile/records/".count))
            let components = suffix.split(separator: "/").map(String.init)

            if components.count == 1, request.httpMethod == "GET" {
                let model = components[0]
                let offset = request.url.flatMap(Self.queryItems(from:))?["offset"].flatMap(Int.init) ?? 0
                let order = request.url.flatMap(Self.queryItems(from:))?["order"]
                guard let result = UITestFixtures.listPage(for: model, offset: offset, order: order) else {
                    return notFound(encoder: encoder)
                }
                let meta = UITestMeta(total: result.items.count, offset: result.offset, limit: result.limit, timestamp: nil)
                return (200, try encoder.encode(UITestEnvelope(data: result, meta: meta)))
            }

            if components.count == 2 {
                let model = components[0]
                let recordID = Int(components[1]) ?? 1

                if request.httpMethod == "PATCH" {
                    if ProcessInfo.processInfo.environment["ORDO_UI_TEST_FAIL_SAVE"] == "1" {
                        let data = try encoder.encode(
                            UITestEnvelope<JSONValue>(
                                success: false,
                                data: .null,
                                meta: nil,
                                errors: [UITestError(code: "save_failed", message: "Save failed for test.", field: nil)]
                            )
                        )
                        return (500, data)
                    }

                    let body = request.httpBody ?? Data()
                    let mutationRequest = try JSONDecoder().decode(RecordMutationRequest.self, from: body)
                    guard let updatedRecord = UITestFixtures.updatedRecord(model: model, id: recordID, values: mutationRequest.values) else {
                        return notFound(encoder: encoder)
                    }
                    let result = RecordMutationResult(id: recordID, record: updatedRecord)
                    return (200, try encoder.encode(UITestEnvelope(data: result, meta: nil)))
                }

                guard let record = UITestFixtures.record(model: model, id: recordID) else {
                    return notFound(encoder: encoder)
                }
                return (200, try encoder.encode(UITestEnvelope(data: record, meta: nil)))
            }
        }

        if path.hasPrefix("/api/v1/mobile/search/") {
            let model = String(path.dropFirst("/api/v1/mobile/search/".count))
            guard let results = UITestFixtures.searchResults(for: model) else {
                return notFound(encoder: encoder)
            }
            return (200, try encoder.encode(UITestEnvelope(data: results, meta: nil)))
        }

        if path.hasSuffix("/auth/login") {
            return (200, try encoder.encode(UITestEnvelope(data: UITestFixtures.tokenResponse, meta: nil)))
        }

        if path.hasSuffix("/auth/refresh") {
            return (200, try encoder.encode(UITestEnvelope(data: UITestFixtures.tokenResponse, meta: nil)))
        }

        if path.hasSuffix("/auth/me") {
            return (200, try encoder.encode(UITestEnvelope(data: UITestFixtures.principal, meta: nil)))
        }

        return notFound(encoder: encoder)
    }

    private static func notFound(encoder: JSONEncoder) -> (Int, Data) {
        let data = (try? encoder.encode(
            UITestEnvelope<JSONValue>(
                success: false,
                data: .null,
                meta: nil,
                errors: [UITestError(code: "not_found", message: "Fixture route not found.", field: nil)]
            )
        )) ?? Data()
        return (404, data)
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

    static let partnerSearchResults = [
        NameSearchResult(id: 1, name: "Azure Interior"),
        NameSearchResult(id: 2, name: "Deco Addict"),
    ]

    static let countrySearchResults = [
        NameSearchResult(id: 124, name: "Canada"),
        NameSearchResult(id: 233, name: "United States"),
    ]

    static let userSearchResults = [
        NameSearchResult(id: 7, name: "Mitchell Admin"),
        NameSearchResult(id: 9, name: "Marc Demo"),
    ]

    static let stageSearchResults = [
        NameSearchResult(id: 10, name: "Qualified"),
        NameSearchResult(id: 12, name: "Proposition"),
    ]

    static let partnerCategorySearchResults = [
        NameSearchResult(id: 3, name: "Retail"),
        NameSearchResult(id: 8, name: "VIP"),
        NameSearchResult(id: 11, name: "Wholesale"),
    ]

    static func schema(for model: String) -> MobileFormSchema? {
        switch model {
        case "res.partner":
            return partnerSchema
        case "crm.lead":
            return leadSchema
        case "sale.order":
            return saleOrderSchema
        default:
            return nil
        }
    }

    static func searchResults(for model: String) -> [NameSearchResult]? {
        switch model {
        case "res.partner":
            return partnerSearchResults
        case "res.country":
            return countrySearchResults
        case "res.users":
            return userSearchResults
        case "crm.stage":
            return stageSearchResults
        case "res.partner.category":
            return partnerCategorySearchResults
        default:
            return nil
        }
    }

    static func listPage(for model: String, offset: Int, order: String?) -> RecordListResult? {
        let baseItems: [RecordData]

        switch model {
        case "res.partner":
            baseItems = [partnerRecord(id: 1), partnerRecord(id: 2), partnerRecord(id: 3)]
        case "crm.lead":
            baseItems = [leadRecord(id: 1), leadRecord(id: 2)]
        case "sale.order":
            baseItems = [saleOrderRecord(id: 1), saleOrderRecord(id: 2)]
        default:
            return nil
        }

        let items = sort(records: baseItems, order: order)
        let pagedItems = offset == 0 ? items : []
        return RecordListResult(items: pagedItems, limit: 30, offset: offset)
    }

    static func record(model: String, id: Int) -> RecordData? {
        switch model {
        case "res.partner":
            return partnerRecord(id: id)
        case "crm.lead":
            return leadRecord(id: id)
        case "sale.order":
            return saleOrderRecord(id: id)
        default:
            return nil
        }
    }

    static func updatedRecord(model: String, id: Int, values: RecordData) -> RecordData? {
        guard var record = record(model: model, id: id) else { return nil }

        for (key, value) in values {
            if key == "name", let name = value.stringValue {
                record[key] = value
                record["display_name"] = .string(name)
            } else if key == "category_id" {
                let categoryValues = value.manyRelationIDs.compactMap { relationValue(for: key, id: $0) }
                record[key] = categoryValues.isEmpty ? .array([]) : .array(categoryValues)
            } else if let relationID = value.relationID,
                      let relation = relationValue(for: key, id: relationID) {
                record[key] = relation
            } else if relationFieldNames.contains(key), value == .null {
                record[key] = .null
            } else {
                record[key] = value
            }
        }

        return record
    }

    private static let relationFieldNames: Set<String> = ["country_id", "stage_id", "user_id", "partner_id"]

    private static let partnerSchema = MobileFormSchema(
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
            FieldSchema(name: "category_id", type: .many2many, label: "Tags", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "res.partner.category", selection: nil, currencyField: nil, placeholder: "No tags selected", digits: nil, subfields: nil, searchable: nil, widget: nil),
        ])],
        tabs: [FormTab(label: "Notes", content: ["sections": encodedSections([
            FormSection(label: "Notes", fields: [
                FieldSchema(name: "comment", type: .text, label: "Notes", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
                FieldSchema(name: "internal_note", type: .text, label: "Internal Note", required: nil, readonly: nil, invisible: Condition(field: "is_company", op: "==", value: .bool(false), values: nil), domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            ]),
        ])])],
        hasChatter: false
    )

    private static let leadSchema = MobileFormSchema(
        model: "crm.lead",
        title: "Lead",
        header: FormHeader(statusbar: .init(field: "stage_id", visibleStates: nil), actions: []),
        sections: [FormSection(label: "Opportunity", fields: [
            FieldSchema(name: "name", type: .char, label: "Opportunity", required: true, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "partner_name", type: .char, label: "Customer", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "email_from", type: .char, label: "Email", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "phone", type: .char, label: "Phone", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "stage_id", type: .many2one, label: "Stage", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "crm.stage", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "user_id", type: .many2one, label: "Salesperson", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "res.users", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
        ])],
        tabs: [],
        hasChatter: true
    )

    private static let saleOrderSchema = MobileFormSchema(
        model: "sale.order",
        title: "Sales Order",
        header: FormHeader(statusbar: .init(field: "state", visibleStates: nil), actions: []),
        sections: [FormSection(label: "Order", fields: [
            FieldSchema(name: "name", type: .char, label: "Order", required: true, readonly: true, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "partner_id", type: .many2one, label: "Customer", required: true, readonly: nil, invisible: nil, domain: nil, comodel: "res.partner", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "user_id", type: .many2one, label: "Salesperson", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "res.users", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "state", type: .selection, label: "Status", required: nil, readonly: true, invisible: nil, domain: nil, comodel: nil, selection: [["draft", "Quotation"], ["sale", "Sales Order"]], currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: "statusbar"),
            FieldSchema(name: "amount_total", type: .monetary, label: "Total", required: nil, readonly: true, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: "currency_id", placeholder: nil, digits: [16, 2], subfields: nil, searchable: nil, widget: nil),
        ])],
        tabs: [],
        hasChatter: false
    )

    private static func partnerRecord(id: Int) -> RecordData {
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
            "category_id": .array(index == 0
                ? [.relation(id: 8, label: "VIP"), .relation(id: 11, label: "Wholesale")]
                : [.relation(id: 3, label: "Retail")]),
            "currency_id": .array([.number(1), .string("USD")]),
            "comment": .string("Preferred customer"),
            "internal_note": .string("Backoffice only"),
        ]
    }

    private static func leadRecord(id: Int) -> RecordData {
        let names = ["Website redesign", "Warehouse expansion"]
        let customers = ["Azure Interior", "Gemini Furniture"]
        let emails = ["buyer@azure.example.com", "ops@gemini.example.com"]
        let phones = ["+1 555-0201", "+1 555-0202"]
        let index = max(0, min(id - 1, 1))

        return [
            "id": .number(Double(id)),
            "display_name": .string(names[index]),
            "name": .string(names[index]),
            "partner_name": .string(customers[index]),
            "email_from": .string(emails[index]),
            "phone": .string(phones[index]),
            "stage_id": .relation(id: 10, label: "Qualified"),
            "user_id": .relation(id: 7, label: "Mitchell Admin"),
        ]
    }

    private static func saleOrderRecord(id: Int) -> RecordData {
        let names = ["S00045", "S00046"]
        let partners: [JSONValue] = [.relation(id: 1, label: "Azure Interior"), .relation(id: 3, label: "Gemini Furniture")]
        let users: [JSONValue] = [.relation(id: 7, label: "Mitchell Admin"), .relation(id: 9, label: "Marc Demo")]
        let amounts = [1250.0, 3200.75]
        let states = ["draft", "sale"]
        let index = max(0, min(id - 1, 1))

        return [
            "id": .number(Double(id)),
            "display_name": .string(names[index]),
            "name": .string(names[index]),
            "partner_id": partners[index],
            "user_id": users[index],
            "state": .string(states[index]),
            "amount_total": .number(amounts[index]),
            "currency_id": .relation(id: 1, label: "USD"),
        ]
    }

    private static func relationValue(for field: String, id: Int) -> JSONValue? {
        switch field {
        case "country_id":
            switch id {
            case 124:
                return .relation(id: 124, label: "Canada")
            case 233:
                return .relation(id: 233, label: "United States")
            default:
                return nil
            }
        case "stage_id":
            switch id {
            case 10:
                return .relation(id: 10, label: "Qualified")
            case 12:
                return .relation(id: 12, label: "Proposition")
            default:
                return nil
            }
        case "user_id":
            switch id {
            case 7:
                return .relation(id: 7, label: "Mitchell Admin")
            case 9:
                return .relation(id: 9, label: "Marc Demo")
            default:
                return nil
            }
        case "partner_id":
            switch id {
            case 1:
                return .relation(id: 1, label: "Azure Interior")
            case 2:
                return .relation(id: 2, label: "Deco Addict")
            case 3:
                return .relation(id: 3, label: "Gemini Furniture")
            default:
                return nil
            }
        case "category_id":
            switch id {
            case 3:
                return .relation(id: 3, label: "Retail")
            case 8:
                return .relation(id: 8, label: "VIP")
            case 11:
                return .relation(id: 11, label: "Wholesale")
            default:
                return nil
            }
        default:
            return nil
        }
    }

    private static func sort(records: [RecordData], order: String?) -> [RecordData] {
        guard let order else { return records }

        let components = order.split(separator: " ").map(String.init)
        let field = components.first ?? "id"
        let isDescending = components.dropFirst().first?.lowercased() == "desc"

        return records.sorted { lhs, rhs in
            let leftValue = lhs[field]?.displayText ?? ""
            let rightValue = rhs[field]?.displayText ?? ""

            if field == "id" {
                let leftID = lhs[field]?.intValue ?? 0
                let rightID = rhs[field]?.intValue ?? 0
                return isDescending ? leftID > rightID : leftID < rightID
            }

            if leftValue == rightValue {
                let leftID = lhs["id"]?.intValue ?? 0
                let rightID = rhs["id"]?.intValue ?? 0
                return leftID < rightID
            }

            return isDescending ? leftValue.localizedCaseInsensitiveCompare(rightValue) == .orderedDescending : leftValue.localizedCaseInsensitiveCompare(rightValue) == .orderedAscending
        }
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
