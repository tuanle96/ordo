import SwiftUI

enum One2ManyFieldEditorSupport {
    static func isEditable(_ type: FieldType) -> Bool {
        switch type {
        case .char, .text, .html, .integer, .float, .monetary, .boolean, .selection, .date, .datetime, .many2one:
            return true
        default:
            return false
        }
    }

    static func usesMultilineInput(_ type: FieldType) -> Bool {
        switch type {
        case .text, .html:
            return true
        default:
            return false
        }
    }

    static func keyboardType(for type: FieldType) -> UIKeyboardType {
        switch type {
        case .integer:
            return .numberPad
        case .float, .monetary:
            return .decimalPad
        default:
            return .default
        }
    }
}

struct One2ManyFieldEditor: View {
    @Environment(AppState.self) private var appState

    let field: FieldSchema
    let subfields: [FieldSchema]
    @Bindable var draft: FormDraft
    let fallbackValue: JSONValue?
    let validationMessage: String?
    let onValueChange: ((FieldSchema, JSONValue?) -> Void)?

    @State private var activeMany2OneContext: Many2OneSheetContext?

    private var editableSubfields: [FieldSchema] {
        subfields.filter { One2ManyFieldEditorSupport.isEditable($0.type) }
    }

    private var lines: [JSONValue] {
        guard case .array(let values)? = draft.value(for: field.name, fallback: fallbackValue) ?? fallbackValue else {
            return []
        }

        return values
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(field.label)
                .font(.subheadline.weight(.medium))

            if lines.isEmpty {
                Text(field.placeholder ?? "No line items yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("field-empty-\(field.name)")
            } else {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    lineCard(for: line, index: index)
                }
            }

            Button(lines.isEmpty ? "Add line" : "Add another line") {
                var updatedLines = lines
                updatedLines.append(.object([:]))
                applyChange(.array(updatedLines))
            }
            .accessibilityIdentifier("field-editor-\(field.name)")

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("field-error-\(field.name)")
            }
        }
        .sheet(item: $activeMany2OneContext) { context in
            One2ManyMany2OnePickerSheet(
                field: context.subfield,
                comodel: context.comodel,
                currentValue: context.currentValue,
                searchDomain: context.subfield.domain,
                appState: appState,
                onSelect: { selectedValue in
                    updateLine(at: context.lineIndex, fieldName: context.subfield.name, value: selectedValue)
                }
            )
        }
    }

    @ViewBuilder
    private func lineCard(for line: JSONValue, index: Int) -> some View {
        let existingID = lineID(from: line)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(existingID.map { "Line #\($0)" } ?? "New line")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(role: .destructive) {
                    removeLine(at: index)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("one2many-remove-\(field.name)-\(index)")
            }

            if case .object(let values) = line {
                if editableSubfields.isEmpty {
                    Text("This line only contains unsupported nested fields in the current core slice.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(editableSubfields, id: \.name) { subfield in
                        subfieldEditor(for: subfield, lineValues: values, lineIndex: index)
                    }
                }
            } else {
                Text("Existing line details are not expanded in the current core slice. You can keep or remove this line.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("one2many-line-\(field.name)-\(index)")
    }

    @ViewBuilder
    private func subfieldEditor(for subfield: FieldSchema, lineValues: RecordData, lineIndex: Int) -> some View {
        switch subfield.type {
        case .boolean:
            Toggle(subfield.label, isOn: Binding(
                get: {
                    if case .bool(let value)? = lineValues[subfield.name] {
                        return value
                    }
                    return false
                },
                set: { newValue in
                    updateLine(at: lineIndex, fieldName: subfield.name, value: .bool(newValue))
                }
            ))
            .accessibilityIdentifier("one2many-field-\(field.name)-\(lineIndex)-\(subfield.name)")
        case .selection:
            Picker(subfield.label, selection: Binding(
                get: { lineValues[subfield.name]?.stringValue ?? subfield.selection?.first?.first ?? "" },
                set: { newValue in
                    updateLine(at: lineIndex, fieldName: subfield.name, value: newValue.isEmpty ? nil : .string(newValue))
                }
            )) {
                ForEach(subfield.selection ?? [], id: \.self) { option in
                    if option.count > 1 {
                        Text(option[1]).tag(option[0])
                    }
                }
            }
            .accessibilityIdentifier("one2many-field-\(field.name)-\(lineIndex)-\(subfield.name)")
        case .many2one:
            if let comodel = subfield.comodel {
                VStack(alignment: .leading, spacing: 6) {
                    Text(subfield.label)
                        .font(.caption.weight(.medium))

                    Button {
                        activeMany2OneContext = Many2OneSheetContext(
                            lineIndex: lineIndex,
                            subfield: subfield,
                            comodel: comodel,
                            currentValue: lineValues[subfield.name]
                        )
                    } label: {
                        HStack(spacing: 8) {
                            Text(relationButtonTitle(for: subfield, value: lineValues[subfield.name]))
                                .foregroundStyle(lineValues[subfield.name]?.relationID == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("one2many-field-\(field.name)-\(lineIndex)-\(subfield.name)")
                }
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text(subfield.label)
                    .font(.caption.weight(.medium))
                TextField(subfield.placeholder ?? subfield.label, text: Binding(
                    get: { fieldText(for: subfield, value: lineValues[subfield.name]) },
                    set: { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        updateLine(at: lineIndex, fieldName: subfield.name, value: trimmed.isEmpty ? nil : .string(trimmed))
                    }
                ), axis: One2ManyFieldEditorSupport.usesMultilineInput(subfield.type) ? .vertical : .horizontal)
                    .lineLimit(One2ManyFieldEditorSupport.usesMultilineInput(subfield.type) ? 5 : 1)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(One2ManyFieldEditorSupport.keyboardType(for: subfield.type))
                    .accessibilityIdentifier("one2many-field-\(field.name)-\(lineIndex)-\(subfield.name)")
            }
        }
    }

    private func fieldText(for subfield: FieldSchema, value: JSONValue?) -> String {
        switch value {
        case .string(let rawValue):
            return rawValue
        case .number(let number):
            return number.rounded() == number ? String(Int(number)) : String(number)
        case .null, nil:
            return ""
        default:
            return value?.displayText ?? ""
        }
    }

    private func relationButtonTitle(for subfield: FieldSchema, value: JSONValue?) -> String {
        value?.relationLabel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (value?.relationLabel ?? "")
            : (subfield.placeholder ?? "Select \(subfield.label)")
    }

    private func lineID(from value: JSONValue) -> Int? {
        switch value {
        case .number(let id):
            return Int(id)
        case .array(let relation) where relation.count == 2:
            return relation.first?.intValue
        case .object(let values):
            return values["id"]?.intValue
        default:
            return nil
        }
    }

    private func removeLine(at index: Int) {
        var updatedLines = lines
        updatedLines.remove(at: index)
        applyChange(updatedLines.isEmpty ? .array([]) : .array(updatedLines))
    }

    private func updateLine(at index: Int, fieldName: String, value: JSONValue?) {
        var updatedLines = lines
        guard case .object(var lineValues) = updatedLines[index] else { return }
        lineValues[fieldName] = value ?? .null
        updatedLines[index] = .object(lineValues)
        applyChange(.array(updatedLines))
    }

    private func applyChange(_ value: JSONValue?) {
        if let onValueChange {
            onValueChange(field, value)
        } else {
            draft.setValue(value, for: field.name)
        }
    }
}

private struct Many2OneSheetContext: Identifiable {
    let lineIndex: Int
    let subfield: FieldSchema
    let comodel: String
    let currentValue: JSONValue?

    var id: String {
        "\(lineIndex)-\(subfield.name)"
    }
}

private struct One2ManyMany2OnePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let field: FieldSchema
    let comodel: String
    let currentValue: JSONValue?
    let searchDomain: JSONValue?
    let appState: AppState
    let onSelect: (JSONValue?) -> Void

    @State private var query = ""
    @State private var results: [NameSearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let currentLabel = currentValue?.relationLabel {
                    Section("Current") {
                        Button {
                            dismiss()
                        } label: {
                            HStack {
                                Text(currentLabel)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    Section {
                        Text("Type at least 2 characters to search \(field.label.lowercased()).")
                            .foregroundStyle(.secondary)
                    }
                } else if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if results.isEmpty {
                    Section {
                        Text("No matches found.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Results") {
                        ForEach(results) { result in
                            Button {
                                onSelect(.relation(id: result.id, label: result.name))
                                dismiss()
                            } label: {
                                Text(result.name)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("one2many-many2one-option-\(field.name)-\(result.id)")
                        }
                    }
                }
            }
            .navigationTitle(field.label)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search \(field.label.lowercased())")
            .task(id: query) {
                await search()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if currentValue != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            onSelect(nil)
                            dismiss()
                        }
                        .accessibilityIdentifier("one2many-many2one-clear-\(field.name)")
                    }
                }
            }
        }
    }

    private func search() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            results = []
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            let searchResults = try await appState.withAuthenticatedToken { token in
                try await appState.apiClient.search(model: comodel, query: trimmedQuery, limit: 20, domain: searchDomain, token: token)
            }

            guard !Task.isCancelled else { return }
            results = searchResults
        } catch {
            guard !(error is CancellationError) else { return }
            errorMessage = error.localizedDescription
            results = []
        }

        isLoading = false
    }
}