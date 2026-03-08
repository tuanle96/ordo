import SwiftUI

struct EditableFieldRowModel {
    enum Style {
        case text
        case multiline
        case toggle
        case selection(options: [[String]])
        case many2one(comodel: String)
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
        case .many2one:
            guard let comodel = field.comodel else { return nil }
            return .init(style: .many2one(comodel: comodel))
        default:
            return nil
        }
    }
}

struct EditableFieldRow: View {
    @Environment(AppState.self) private var appState

    let field: FieldSchema
    let model: EditableFieldRowModel
    let draft: FormDraft
    let fallbackValue: JSONValue?
    let validationMessage: String?

    @State private var isShowingRelationPicker = false

    var body: some View {
        switch model.style {
        case .text:
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent(field.label) {
                    TextField(field.placeholder ?? field.label, text: stringBinding)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("field-editor-\(field.name)")
                }
                validationText
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
                validationText
            }
            .accessibilityIdentifier("field-row-\(field.name)")
        case .toggle:
            VStack(alignment: .leading, spacing: 6) {
                Toggle(field.label, isOn: boolBinding)
                    .accessibilityIdentifier("field-editor-\(field.name)")
                validationText
            }
            .accessibilityIdentifier("field-row-\(field.name)")
        case .selection(let options):
            VStack(alignment: .leading, spacing: 6) {
                Picker(field.label, selection: selectionBinding(options: options)) {
                    ForEach(options, id: \.self) { option in
                        if option.count > 1 {
                            Text(option[1]).tag(option[0])
                        }
                    }
                }
                .accessibilityIdentifier("field-editor-\(field.name)")
                validationText
            }
            .accessibilityIdentifier("field-row-\(field.name)")
        case .many2one(let comodel):
            VStack(alignment: .leading, spacing: 8) {
                Text(field.label)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 12) {
                    Button {
                        isShowingRelationPicker = true
                    } label: {
                        HStack {
                            Text(relationLabel ?? field.placeholder ?? "Select \(field.label)")
                                .foregroundStyle(relationLabel == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("field-editor-\(field.name)")

                    if relationLabel != nil {
                        Button("Clear") {
                            draft.setValue(nil, for: field.name)
                        }
                        .font(.subheadline.weight(.medium))
                        .accessibilityIdentifier("field-clear-\(field.name)")
                    }
                }

                validationText
            }
            .accessibilityIdentifier("field-row-\(field.name)")
            .sheet(isPresented: $isShowingRelationPicker) {
                Many2OnePickerSheet(
                    field: field,
                    comodel: comodel,
                    currentValue: draft.value(for: field.name, fallback: fallbackValue),
                    onSelect: { selection in
                        draft.setValue(selection, for: field.name)
                    }
                )
                .environment(appState)
            }
        }
    }

    @ViewBuilder
    private var validationText: some View {
        if let validationMessage {
            Text(validationMessage)
                .font(.caption)
                .foregroundStyle(.red)
                .accessibilityIdentifier("field-error-\(field.name)")
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

    private var relationLabel: String? {
        draft.value(for: field.name, fallback: fallbackValue)?.relationLabel
            ?? fallbackValue?.relationLabel
    }
}

private struct Many2OnePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let field: FieldSchema
    let comodel: String
    let currentValue: JSONValue?
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
                            .accessibilityIdentifier("many2one-option-\(field.name)-\(result.id)")
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
                        .accessibilityIdentifier("many2one-clear-\(field.name)")
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
                try await appState.apiClient.search(model: comodel, query: trimmedQuery, limit: 20, token: token)
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