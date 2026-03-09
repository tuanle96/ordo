import Foundation

struct RelationValue: Hashable, Identifiable {
    let id: Int
    let label: String
}

enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
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
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var intValue: Int? {
        guard case .number(let value) = self else { return nil }
        return Int(value)
    }

    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var relationID: Int? {
        switch self {
        case .array(let values):
            guard let first = values.first else { return nil }
            return first.intValue
        case .object(let values):
            return values["id"]?.intValue
        case .number(let value):
            return Int(value)
        default:
            return nil
        }
    }

    var relationLabel: String? {
        switch self {
        case .array(let values):
            guard values.count >= 2 else { return nil }
            return values[1].stringValue
        case .object(let values):
            return values["display_name"]?.stringValue ?? values["name"]?.stringValue
        case .string(let value):
            return value
        default:
            return nil
        }
    }

    var relationValue: RelationValue? {
        switch self {
        case .array(let values):
            guard values.count == 2, let id = values[0].intValue else { return nil }
            return RelationValue(id: id, label: values[1].stringValue ?? "Record #\(id)")
        case .object(let values):
            guard let id = values["id"]?.intValue else { return nil }
            let label = values["display_name"]?.stringValue
                ?? values["name"]?.stringValue
                ?? "Record #\(id)"
            return RelationValue(id: id, label: label)
        case .number(let value):
            let id = Int(value)
            return RelationValue(id: id, label: "Record #\(id)")
        default:
            return nil
        }
    }

    var relationValues: [RelationValue] {
        if let relationValue {
            return [relationValue]
        }

        guard case .array(let values) = self else { return [] }

        var seen = Set<Int>()
        return values.compactMap(\.relationValue).filter { seen.insert($0.id).inserted }
    }

    var manyRelationIDs: [Int] {
        relationValues.map(\.id)
    }

    static func relation(id: Int, label: String) -> JSONValue {
        .array([.number(Double(id)), .string(label)])
    }

    var displayText: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value.rounded() == value ? String(Int(value)) : String(value)
        case .bool(let value):
            return value ? "Yes" : "—"
        case .array(let values):
            if values.count == 2, let label = values.last?.stringValue {
                return label
            }

            return values.map(\.displayText).joined(separator: ", ")
        case .object(let values):
            return values["display_name"]?.displayText
                ?? values["name"]?.displayText
                ?? "—"
        case .null:
            return "—"
        }
    }

    var objectValue: [String: JSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    var isVisuallyEmpty: Bool {
        switch self {
        case .string(let value):
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .array(let values):
            return values.isEmpty
        case .object(let values):
            return values.isEmpty
        case .null:
            return true
        case .number:
            return false
        case .bool(let value):
            return !value
        }
    }
}
