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
        return .array([.string(field.name), .string(normalized.filterOperator.rawValue), value])
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

        return clauses.isEmpty ? nil : .array(clauses)
    }

    var activeCount: Int {
        conditions.count
    }

    static let empty = BrowseFilterState()
}

enum BrowseFilterRegistry {
    static func fields(for descriptor: ModelDescriptor) -> [BrowseFilterField] {
        switch descriptor.model {
        case "res.partner":
            return [
                BrowseFilterField(name: "name", label: "Name", kind: .text),
                BrowseFilterField(name: "email", label: "Email", kind: .text),
                BrowseFilterField(name: "phone", label: "Phone", kind: .text),
                BrowseFilterField(name: "city", label: "City", kind: .text),
                BrowseFilterField(name: "customer_rank", label: "Customer Rank", kind: .number),
                BrowseFilterField(name: "is_company", label: "Company", kind: .boolean),
            ]
        case "crm.lead":
            return [
                BrowseFilterField(name: "name", label: "Opportunity", kind: .text),
                BrowseFilterField(name: "partner_name", label: "Customer", kind: .text),
                BrowseFilterField(name: "email_from", label: "Email", kind: .text),
                BrowseFilterField(name: "phone", label: "Phone", kind: .text),
                BrowseFilterField(name: "stage_id", label: "Stage", kind: .text),
                BrowseFilterField(name: "user_id", label: "Salesperson", kind: .text),
            ]
        case "sale.order":
            return [
                BrowseFilterField(name: "name", label: "Order", kind: .text),
                BrowseFilterField(name: "partner_id", label: "Customer", kind: .text),
                BrowseFilterField(name: "user_id", label: "Salesperson", kind: .text),
                BrowseFilterField(name: "state", label: "Status", kind: .selection([["draft", "Quotation"], ["sale", "Sales Order"]])),
                BrowseFilterField(name: "amount_total", label: "Total", kind: .number),
            ]
        default:
            return [BrowseFilterField(name: descriptor.primarySortField, label: descriptor.title, kind: .text)]
        }
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