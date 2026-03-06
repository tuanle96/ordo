import Foundation

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

    var displayText: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value.rounded() == value ? String(Int(value)) : String(value)
        case .bool(let value):
            return value ? "Yes" : "No"
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
        case .number, .bool:
            return false
        }
    }
}
