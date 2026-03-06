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
}

struct Condition: Codable, Hashable {
    let field: String
    let op: String
    let value: String?
    let values: [String]?
}

struct ActionButton: Codable, Hashable {
    let name: String
    let label: String
    let type: String
    let style: String?
    let invisible: Condition?
    let confirm: String?
}

struct FieldSchema: Codable, Hashable {
    let name: String
    let type: FieldType
    let label: String
    let required: Bool?
    let readonly: Bool?
    let invisible: Condition?
    let domain: String?
    let comodel: String?
    let selection: [[String]]?
    let currencyField: String?
    let placeholder: String?
    let digits: [Int]?
    let subfields: [FieldSchema]?
    let searchable: Bool?
    let widget: String?
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

    var requestedFieldNames: [String] {
        var fields = sections.flatMap(\.fields).map(\.name)
        fields.append(contentsOf: tabs.flatMap(\.sections).flatMap(\.fields).map(\.name))

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
