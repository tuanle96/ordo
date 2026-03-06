import Foundation

struct ReadOnlyFieldRowModel: Identifiable, Equatable {
    enum Style: Equatable {
        case standard
        case multiline
        case status
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
        .statusbar,
    ]

    static func model(for field: FieldSchema, rawValue: JSONValue?) -> ReadOnlyFieldRowModel? {
        guard let rawValue, !rawValue.isVisuallyEmpty else { return nil }

        let style: ReadOnlyFieldRowModel.Style
        if supportedTypes.contains(field.type) {
            if field.type == .statusbar {
                style = .status
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
            value: formattedValue(for: field, rawValue: rawValue),
            style: style
        )
    }

    static func formattedValue(for field: FieldSchema, rawValue: JSONValue) -> String {
        if field.type == .selection,
           let key = rawValue.stringValue,
           let option = field.selection?.first(where: { $0.first == key }),
           option.count > 1 {
            return option[1]
        }

        return rawValue.displayText
    }
}