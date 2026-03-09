import Foundation

struct ReadOnlyFieldRowModel: Identifiable, Equatable {
    enum Style: Equatable {
        case standard
        case multiline
        case status
        case phone
        case email
        case url
        case unsupported(FieldType)
    }

    let id: String
    let label: String
    let value: String
    let style: Style
}

enum FieldRowFactory {
    private static let multilineTypes: Set<FieldType> = [.text]
    private static let supportedTypes: Set<FieldType> = [
        .char,
        .text,
        .integer,
        .float,
        .boolean,
        .selection,
        .date,
        .datetime,
        .many2one,
        .one2many,
        .many2many,
        .monetary,
        .priority,
        .statusbar,
    ]

    static func model(for field: FieldSchema, rawValue: JSONValue?, record: RecordData? = nil) -> ReadOnlyFieldRowModel? {
        guard let rawValue, !rawValue.isVisuallyEmpty else { return nil }

        let style: ReadOnlyFieldRowModel.Style
        if supportedTypes.contains(field.type) {
            if field.type == .statusbar {
                style = .status
            } else if field.name.contains("phone") || field.name.contains("mobile") {
                style = .phone
            } else if field.name.contains("email") {
                style = .email
            } else if field.name == "website" || field.widget == "url" {
                style = .url
            } else if multilineTypes.contains(field.type) {
                style = .multiline
            } else {
                style = .standard
            }
        } else {
            style = .unsupported(field.type)
        }

        return ReadOnlyFieldRowModel(
            id: field.name,
            label: field.label,
            value: formattedValue(for: field, rawValue: rawValue, record: record),
            style: style
        )
    }

    static func formattedValue(for field: FieldSchema, rawValue: JSONValue, record: RecordData? = nil) -> String {
        if field.type == .priority {
            return formattedPriority(for: rawValue)
        }

        if field.type == .monetary {
            return formattedMonetaryValue(for: field, rawValue: rawValue, record: record)
        }

        if field.type == .selection,
           let key = rawValue.stringValue,
           let option = field.selection?.first(where: { $0.first == key }),
           option.count > 1 {
            return option[1]
        }

        if field.type == .many2many {
            return formattedManyRelationValue(for: rawValue)
        }

        if field.type == .one2many {
            return formattedOne2ManyValue(for: rawValue)
        }

        return rawValue.displayText
    }

    private static func formattedPriority(for rawValue: JSONValue) -> String {
        let value = rawValue.stringValue ?? rawValue.displayText
        let priority = max(0, min(Int(value) ?? rawValue.intValue ?? 0, 3))
        guard priority > 0 else { return "Not set" }
        return String(repeating: "★", count: priority) + String(repeating: "☆", count: max(0, 3 - priority))
    }

    private static func formattedMonetaryValue(for field: FieldSchema, rawValue: JSONValue, record: RecordData?) -> String {
        guard case .number(let amount) = rawValue else { return rawValue.displayText }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = field.digits?.last ?? 2
        formatter.maximumFractionDigits = field.digits?.last ?? 2
        let formattedAmount = formatter.string(from: NSNumber(value: amount)) ?? rawValue.displayText

        guard let currencyField = field.currencyField,
              let currencyValue = record?[currencyField] else {
            return formattedAmount
        }

        let currencyLabel = currencyValue.relationLabel ?? currencyValue.stringValue
        guard let currencyLabel, !currencyLabel.isEmpty else {
            return formattedAmount
        }

        return "\(currencyLabel) \(formattedAmount)"
    }

    private static func formattedManyRelationValue(for rawValue: JSONValue) -> String {
        let relations = rawValue.relationValues
        if !relations.isEmpty {
            return relations.map(\.label).joined(separator: ", ")
        }

        let count = rawValue.manyRelationIDs.count
        if count > 0 {
            return count == 1 ? "1 item selected" : "\(count) items selected"
        }

        return rawValue.displayText
    }

    private static func formattedOne2ManyValue(for rawValue: JSONValue) -> String {
        guard case .array(let values) = rawValue else { return rawValue.displayText }

        let count = values.count
        guard count > 0 else { return "—" }

        return count == 1 ? "1 line item" : "\(count) line items"
    }
}