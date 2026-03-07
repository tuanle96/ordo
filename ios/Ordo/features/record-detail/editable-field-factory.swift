import SwiftUI

struct EditableFieldRowModel {
    enum Style {
        case text
        case multiline
        case toggle
        case selection(options: [[String]])
    }

    let style: Style
}

enum EditableFieldFactory {
    static func model(for field: FieldSchema) -> EditableFieldRowModel? {
        switch field.type {
        case .char:
            return .init(style: .text)
        case .text:
            return .init(style: .multiline)
        case .boolean:
            return .init(style: .toggle)
        case .selection:
            return .init(style: .selection(options: field.selection ?? []))
        default:
            return nil
        }
    }
}

struct EditableFieldRow: View {
    let field: FieldSchema
    let model: EditableFieldRowModel
    @ObservedObject var draft: FormDraft
    let fallbackValue: JSONValue?

    var body: some View {
        switch model.style {
        case .text:
            LabeledContent(field.label) {
                TextField(field.placeholder ?? field.label, text: stringBinding)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("field-editor-\(field.name)")
            }
            .accessibilityIdentifier("field-row-\(field.name)")
        case .multiline:
            VStack(alignment: .leading, spacing: 8) {
                Text(field.label)
                    .font(.subheadline.weight(.medium))
                TextField(field.placeholder ?? field.label, text: stringBinding, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("field-editor-\(field.name)")
            }
            .accessibilityIdentifier("field-row-\(field.name)")
        case .toggle:
            Toggle(field.label, isOn: boolBinding)
                .accessibilityIdentifier("field-editor-\(field.name)")
        case .selection(let options):
            Picker(field.label, selection: selectionBinding(options: options)) {
                ForEach(options, id: \.self) { option in
                    if option.count > 1 {
                        Text(option[1]).tag(option[0])
                    }
                }
            }
            .accessibilityIdentifier("field-editor-\(field.name)")
        }
    }

    private var stringBinding: Binding<String> {
        Binding(
            get: { draft.value(for: field.name, fallback: fallbackValue)?.stringValue ?? "" },
            set: { draft.setValue($0.isEmpty ? nil : .string($0), for: field.name) }
        )
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: {
                if case .bool(let value) = draft.value(for: field.name, fallback: fallbackValue) {
                    return value
                }
                return false
            },
            set: { draft.setValue(.bool($0), for: field.name) }
        )
    }

    private func selectionBinding(options: [[String]]) -> Binding<String> {
        Binding(
            get: {
                if let value = draft.value(for: field.name, fallback: fallbackValue)?.stringValue {
                    return value
                }
                return options.first?.first ?? ""
            },
            set: { draft.setValue($0.isEmpty ? nil : .string($0), for: field.name) }
        )
    }
}