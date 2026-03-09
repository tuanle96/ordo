import Foundation

enum InlineImageSupport {
    static let maxBytes = 2_000_000
    static let limitDescription = "2 MB"
}

enum InlineSignatureSupport {
    static let maxBytes = 500_000
    static let limitDescription = "500 KB"
}

enum InlineBinaryDocumentSupport {
    static let maxBytes = 1_500_000
    static let limitDescription = "1.5 MB"
}

enum InlineFilePayloadSupport {
    static func resolvedFilename(
        preferredFilename: String?,
        fallbackStem: String,
        data: Data,
        fallbackExtension: String
    ) -> String {
        if let preferredFilename {
            let trimmed = preferredFilename.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        let fileExtension = inferredFileExtension(for: data) ?? fallbackExtension
        return "\(fallbackStem).\(fileExtension)"
    }

    static func inferredFileExtension(for data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        let bytes = [UInt8](data.prefix(12))

        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }

        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "jpg"
        }

        if bytes.starts(with: [0x25, 0x50, 0x44, 0x46]) {
            return "pdf"
        }

        if bytes.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return "gif"
        }

        if bytes.count >= 12,
           bytes[0...3].elementsEqual([0x52, 0x49, 0x46, 0x46]),
           bytes[8...11].elementsEqual([0x57, 0x45, 0x42, 0x50]) {
            return "webp"
        }

        return nil
    }
}

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
        case .number(let value):
            return "Record #\(Int(value))"
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

    var binaryData: Data? {
        guard let payload = base64Payload else { return nil }
        return Data(base64Encoded: payload, options: [.ignoreUnknownCharacters])
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
        case .bool:
            return false
        }
    }

    private var base64Payload: String? {
        guard case .string(let rawValue) = self else { return nil }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("data:"),
           let separator = trimmed.firstIndex(of: ",") {
            let payloadStart = trimmed.index(after: separator)
            return String(trimmed[payloadStart...])
        }

        return trimmed
    }
}
