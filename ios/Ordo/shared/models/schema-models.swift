import Foundation

enum FieldType: String, Codable {
    case char
    case text
    case integer
    case float
    case boolean
    case selection
    case date
    case datetime
    case many2one
    case one2many
    case many2many
    case monetary
    case binary
    case image
    case html
    case statusbar
    case priority
    case signature
    case unsupported

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = FieldType(rawValue: rawValue) ?? .unsupported
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct Condition: Codable, Hashable {
    let field: String
    let op: String
    let value: ConditionValue?
    let values: [ConditionValue]?
}

enum ConditionValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

struct ModifierRule: Codable, Hashable {
    let type: String
    let condition: Condition?
    let rules: [ModifierRule]?
    let constant: Bool?
}

struct FieldModifiers: Codable, Hashable {
    let invisible: ModifierRule?
    let readonly: ModifierRule?
    let required: ModifierRule?
}

struct OnchangeFieldMeta: Codable, Hashable {
    let trigger: String
    let source: String?
    let dependencies: [String]?
    let mergeReturnedValue: Bool?
}

struct ActionButton: Codable, Hashable {
    let name: String
    let label: String
    let type: String
    let style: String?
    let invisible: Condition?
    let modifiers: FieldModifiers?
    let confirm: String?

    init(
        name: String,
        label: String,
        type: String,
        style: String? = nil,
        invisible: Condition? = nil,
        modifiers: FieldModifiers? = nil,
        confirm: String? = nil
    ) {
        self.name = name
        self.label = label
        self.type = type
        self.style = style
        self.invisible = invisible
        self.modifiers = modifiers
        self.confirm = confirm
    }
}

struct FieldSchema: Codable, Hashable {
    let name: String
    let type: FieldType
    let label: String
    let required: Bool?
    let readonly: Bool?
    let invisible: Condition?
    let modifiers: FieldModifiers?
    let onchange: OnchangeFieldMeta?
    let domain: JSONValue?
    let comodel: String?
    let selection: [[String]]?
    let currencyField: String?
    let filenameField: String?
    let placeholder: String?
    let digits: [Int]?
    let subfields: [FieldSchema]?
    let searchable: Bool?
    let widget: String?

    init(
        name: String,
        type: FieldType,
        label: String,
        required: Bool? = nil,
        readonly: Bool? = nil,
        invisible: Condition? = nil,
        modifiers: FieldModifiers? = nil,
        onchange: OnchangeFieldMeta? = nil,
        domain: JSONValue? = nil,
        comodel: String? = nil,
        selection: [[String]]? = nil,
        currencyField: String? = nil,
        filenameField: String? = nil,
        placeholder: String? = nil,
        digits: [Int]? = nil,
        subfields: [FieldSchema]? = nil,
        searchable: Bool? = nil,
        widget: String? = nil
    ) {
        self.name = name
        self.type = type
        self.label = label
        self.required = required
        self.readonly = readonly
        self.invisible = invisible
        self.modifiers = modifiers
        self.onchange = onchange
        self.domain = domain
        self.comodel = comodel
        self.selection = selection
        self.currencyField = currencyField
        self.filenameField = filenameField
        self.placeholder = placeholder
        self.digits = digits
        self.subfields = subfields
        self.searchable = searchable
        self.widget = widget
    }
}

struct FormHeader: Codable, Hashable {
    struct StatusBar: Codable, Hashable {
        let field: String
        let visibleStates: [String]?
    }

    let statusbar: StatusBar?
    let actions: [ActionButton]
}

struct FormSection: Codable, Hashable {
    let label: String?
    let fields: [FieldSchema]
}

struct FormTab: Codable, Hashable, Identifiable {
    let label: String
    let content: [String: JSONValue]

    var id: String { label }

    var sections: [FormSection] {
        content.decodedValue(forKey: "sections", as: [FormSection].self) ?? []
    }
}

struct MobileFormSchema: Codable, Hashable {
    let model: String
    let title: String
    let header: FormHeader
    let sections: [FormSection]
    let tabs: [FormTab]
    let hasChatter: Bool

    var allFields: [FieldSchema] {
        sections.flatMap(\.fields) + tabs.flatMap(\.sections).flatMap(\.fields)
    }

    var requestedFieldNames: [String] {
        var fields = allFields.map(\.name)
        fields.append(contentsOf: allFields.compactMap(\.filenameField))

        if let statusField = header.statusbar?.field {
            fields.append(statusField)
        }

        return Array(Set(fields + ["id", "display_name", "name"]))
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func decodedValue<T: Decodable>(forKey key: String, as type: T.Type) -> T? {
        guard let value = self[key] else { return nil }

        do {
            let data = try JSONEncoder().encode(value)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }
}
