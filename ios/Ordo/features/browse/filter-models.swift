import Foundation

enum BrowseFilterFieldKind: Codable, Hashable {
    case text
    case number
    case selection([[String]])
    case boolean
}

enum BrowseFilterOperator: String, CaseIterable, Codable, Hashable, Identifiable {
    case contains = "ilike"
    case notContains = "not ilike"
    case equals = "="
    case notEquals = "!="
    case greaterThan = ">"
    case lessThan = "<"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .contains:
            return "Contains"
        case .notContains:
            return "Doesn’t Contain"
        case .equals:
            return "Equals"
        case .notEquals:
            return "Doesn’t Equal"
        case .greaterThan:
            return "Greater Than"
        case .lessThan:
            return "Less Than"
        }
    }

    static func supported(for kind: BrowseFilterFieldKind) -> [BrowseFilterOperator] {
        switch kind {
        case .text:
            return [.contains, .notContains, .equals, .notEquals]
        case .number:
            return [.equals, .notEquals, .greaterThan, .lessThan]
        case .selection, .boolean:
            return [.equals, .notEquals]
        }
    }
}

struct BrowseFilterField: Identifiable, Hashable {
    let name: String
    let label: String
    let kind: BrowseFilterFieldKind
    let filterDomainTemplate: JSONValue?

    var id: String { name }
}

struct BrowseFilterCondition: Codable, Hashable, Identifiable {
    var id: String
    var fieldName: String
    var operatorRawValue: String
    var value: JSONValue?

    init(
        id: String = UUID().uuidString,
        fieldName: String,
        filterOperator: BrowseFilterOperator,
        value: JSONValue? = nil
    ) {
        self.id = id
        self.fieldName = fieldName
        self.operatorRawValue = filterOperator.rawValue
        self.value = value
    }

    var filterOperator: BrowseFilterOperator {
        get { BrowseFilterOperator(rawValue: operatorRawValue) ?? .contains }
        set { operatorRawValue = newValue.rawValue }
    }

    func isActive(for field: BrowseFilterField) -> Bool {
        switch field.kind {
        case .text, .selection:
            guard let trimmed = value?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return false
            }
            return !trimmed.isEmpty
        case .number:
            switch value {
            case .number:
                return true
            case .string(let raw):
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return !trimmed.isEmpty && Double(trimmed) != nil
            default:
                return false
            }
        case .boolean:
            if case .bool = value {
                return true
            }
            return false
        }
    }

    func normalized(for field: BrowseFilterField) -> BrowseFilterCondition? {
        let supportedOperators = BrowseFilterOperator.supported(for: field.kind)
        let resolvedOperator = supportedOperators.contains(filterOperator) ? filterOperator : supportedOperators.first ?? .equals

        let normalizedValue: JSONValue?
        switch field.kind {
        case .text, .selection:
            let trimmed = value?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            normalizedValue = trimmed.isEmpty ? nil : .string(trimmed)
        case .number:
            if case .number(let number)? = value {
                normalizedValue = .number(number)
            } else if case .string(let raw)? = value,
                      let number = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
                normalizedValue = .number(number)
            } else {
                normalizedValue = nil
            }
        case .boolean:
            if case .bool(let boolValue)? = value {
                normalizedValue = .bool(boolValue)
            } else {
                normalizedValue = nil
            }
        }

        var copy = self
        copy.filterOperator = resolvedOperator
        copy.value = normalizedValue
        return copy.isActive(for: field) ? copy : nil
    }

    func domainClause(for field: BrowseFilterField) -> JSONValue? {
        guard let normalized = normalized(for: field), let value = normalized.value else { return nil }

        if normalized.filterOperator == .contains,
           let resolvedTemplateDomain = BrowseFilterDomainTemplateResolver.resolve(field.filterDomainTemplate, substituting: value) {
            return resolvedTemplateDomain
        }

        return .array([.string(field.name), .string(normalized.filterOperator.rawValue), value])
    }
}

private enum BrowseFilterDomainTemplateResolver {
    static func resolve(_ template: JSONValue?, substituting value: JSONValue) -> JSONValue? {
        guard let template else { return nil }

        let resolved = substituteSelf(in: template, with: value)
        guard case .array = resolved else { return nil }
        return resolved
    }

    private static func substituteSelf(in jsonValue: JSONValue, with value: JSONValue) -> JSONValue {
        switch jsonValue {
        case .string(let stringValue) where stringValue == "self":
            return value
        case .array(let values):
            return .array(values.map { substituteSelf(in: $0, with: value) })
        case .object(let object):
            return .object(object.mapValues { substituteSelf(in: $0, with: value) })
        default:
            return jsonValue
        }
    }
}

struct BrowseFilterState: Codable, Hashable {
    var conditions: [BrowseFilterCondition] = []

    func normalized(with fields: [BrowseFilterField]) -> BrowseFilterState {
        let fieldsByName = Dictionary(uniqueKeysWithValues: fields.map { ($0.name, $0) })

        let normalizedConditions = conditions.compactMap { condition -> BrowseFilterCondition? in
            guard let field = fieldsByName[condition.fieldName] else { return nil }
            return condition.normalized(for: field)
        }

        return BrowseFilterState(conditions: normalizedConditions)
    }

    func domainValue(using fields: [BrowseFilterField]) -> JSONValue? {
        let fieldsByName = Dictionary(uniqueKeysWithValues: fields.map { ($0.name, $0) })
        let clauses = conditions.compactMap { condition -> JSONValue? in
            guard let field = fieldsByName[condition.fieldName] else { return nil }
            return condition.domainClause(for: field)
        }

        return BrowseFilterDomainComposer.compose(clauses)
    }

    var activeCount: Int {
        conditions.count
    }

    static let empty = BrowseFilterState()
}

enum BrowseFilterDomainComposer {
    static func compose(_ domains: [JSONValue]) -> JSONValue? {
        guard !domains.isEmpty else { return nil }
        guard domains.count > 1 else {
            let domain = domains[0]
            return isCompoundExpression(domain) ? domain : .array([domain])
        }

        let mergedComponents = domains.flatMap(domainComponents)
        return .array(mergedComponents)
    }

    private static func domainComponents(for array: [JSONValue]) -> [JSONValue] {
        if let first = array.first,
           case .string(let operatorValue) = first,
           ["|", "&", "!"].contains(operatorValue) {
            return array
        }

        if array.allSatisfy(isClauseLike) {
            return array.map { .array([$0]) }
        }

        return array
    }

    private static func domainComponents(_ domain: JSONValue) -> [JSONValue] {
        guard case .array(let values) = domain else {
            return [domain]
        }

        if isCompoundExpression(domain) {
            return values
        }

        if isClauseLike(domain) {
            return [domain]
        }

        return values
    }

    private static func isCompoundExpression(_ domain: JSONValue) -> Bool {
        guard case .array(let values) = domain,
              let first = values.first,
              case .string(let operatorValue) = first else {
            return false
        }

        return ["|", "&", "!"].contains(operatorValue)
    }

    private static func isClauseLike(_ domain: JSONValue) -> Bool {
        guard case .array(let values) = domain,
              values.count == 3,
              case .string = values[0],
              case .string = values[1] else {
            return false
        }

        return true
    }
}

enum BrowseFilterRegistry {
    static func fields(for descriptor: ModelDescriptor, listSchema: MobileListSchema? = nil) -> [BrowseFilterField] {
        if let schemaFields = listSchema?.search.fields,
           !schemaFields.isEmpty {
            let dynamicFields = schemaFields.compactMap(field(from:))
            if !dynamicFields.isEmpty {
                return dynamicFields
            }
        }

        switch descriptor.model {
        case "res.partner":
            return [
                BrowseFilterField(name: "name", label: "Name", kind: .text, filterDomainTemplate: nil),
                BrowseFilterField(name: "email", label: "Email", kind: .text, filterDomainTemplate: nil),
                BrowseFilterField(name: "phone", label: "Phone", kind: .text, filterDomainTemplate: nil),
                BrowseFilterField(name: "city", label: "City", kind: .text, filterDomainTemplate: nil),
                BrowseFilterField(name: "customer_rank", label: "Customer Rank", kind: .number, filterDomainTemplate: nil),
                BrowseFilterField(name: "is_company", label: "Company", kind: .boolean, filterDomainTemplate: nil),
            ]
        case "crm.lead":
            return [
                BrowseFilterField(name: "name", label: "Opportunity", kind: .text, filterDomainTemplate: nil),
                BrowseFilterField(name: "partner_name", label: "Customer", kind: .text, filterDomainTemplate: nil),
                BrowseFilterField(name: "email_from", label: "Email", kind: .text, filterDomainTemplate: nil),
                BrowseFilterField(name: "phone", label: "Phone", kind: .text, filterDomainTemplate: nil),
                BrowseFilterField(name: "stage_id", label: "Stage", kind: .text, filterDomainTemplate: nil),
                BrowseFilterField(name: "user_id", label: "Salesperson", kind: .text, filterDomainTemplate: nil),
            ]
        case "sale.order":
            return [
                BrowseFilterField(name: "name", label: "Order", kind: .text, filterDomainTemplate: nil),
                BrowseFilterField(name: "partner_id", label: "Customer", kind: .text, filterDomainTemplate: nil),
                BrowseFilterField(name: "user_id", label: "Salesperson", kind: .text, filterDomainTemplate: nil),
                BrowseFilterField(name: "state", label: "Status", kind: .selection([["draft", "Quotation"], ["sale", "Sales Order"]]), filterDomainTemplate: nil),
                BrowseFilterField(name: "amount_total", label: "Total", kind: .number, filterDomainTemplate: nil),
            ]
        default:
            return [BrowseFilterField(name: descriptor.primarySortField, label: descriptor.title, kind: .text, filterDomainTemplate: nil)]
        }
    }

    nonisolated private static func field(from searchField: SearchField) -> BrowseFilterField? {
        let kind: BrowseFilterFieldKind

        switch searchField.type {
        case .integer, .float, .monetary:
            kind = .number
        case .selection, .priority, .statusbar:
            kind = .selection(searchField.selection ?? [])
        case .boolean:
            kind = .boolean
        default:
            kind = .text
        }

        return BrowseFilterField(
            name: searchField.name,
            label: searchField.label,
            kind: kind,
            filterDomainTemplate: searchField.filterDomain.flatMap(JSONValue.decoded(fromJSONString:))
        )
    }
}

enum BrowseFilterStore {
    private static let keyPrefix = "browse-filter-state"

    static func load(model: String, userDefaults: UserDefaults = .standard) -> BrowseFilterState {
        guard let data = userDefaults.data(forKey: key(for: model)) else {
            return .empty
        }

        return (try? JSONDecoder().decode(BrowseFilterState.self, from: data)) ?? .empty
    }

    static func save(_ state: BrowseFilterState, model: String, userDefaults: UserDefaults = .standard) {
        if state.conditions.isEmpty {
            userDefaults.removeObject(forKey: key(for: model))
            return
        }

        guard let data = try? JSONEncoder().encode(state) else { return }
        userDefaults.set(data, forKey: key(for: model))
    }

    private static func key(for model: String) -> String {
        "\(keyPrefix).\(model)"
    }
}

enum BrowseGroupByStore {
    private static let keyPrefix = "browse-group-by"

    static func load(model: String, userDefaults: UserDefaults = .standard) -> String? {
        let value = userDefaults.string(forKey: key(for: model))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    static func save(_ groupByName: String?, model: String, userDefaults: UserDefaults = .standard) {
        guard let groupByName = groupByName?.trimmingCharacters(in: .whitespacesAndNewlines), !groupByName.isEmpty else {
            userDefaults.removeObject(forKey: key(for: model))
            return
        }

        userDefaults.set(groupByName, forKey: key(for: model))
    }

    private static func key(for model: String) -> String {
        "\(keyPrefix).\(model)"
    }
}