import SwiftUI

struct EditableFieldRowModel {
    enum Style {
        case text
        case multiline
        case toggle
        case selection(options: [[String]])
        case many2one(comodel: String)
        case many2many(comodel: String)
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
        case .many2many:
            guard let comodel = field.comodel else { return nil }
            return .init(style: .many2many(comodel: comodel))
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
        case .many2many(let comodel):
            VStack(alignment: .leading, spacing: 10) {
                Text(field.label)
                    .font(.subheadline.weight(.medium))

                if selectedRelations.isEmpty {
                    Text(field.placeholder ?? "No items selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("field-empty-\(field.name)")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(selectedRelations) { relation in
                            Button {
                                removeRelation(relation.id)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(relation.label)
                                        .lineLimit(1)
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("many2many-tag-\(field.name)-\(relation.id)")
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button(selectedRelations.isEmpty ? "Add" : "Manage") {
                        isShowingRelationPicker = true
                    }
                    .accessibilityIdentifier("field-editor-\(field.name)")

                    if !selectedRelations.isEmpty {
                        Button("Clear") {
                            draft.setValue(.array([]), for: field.name)
                        }
                        .font(.subheadline.weight(.medium))
                        .accessibilityIdentifier("field-clear-\(field.name)")
                    }
                }

                validationText
            }
            .accessibilityIdentifier("field-row-\(field.name)")
            .sheet(isPresented: $isShowingRelationPicker) {
                Many2ManyPickerSheet(
                    field: field,
                    comodel: comodel,
                    currentSelections: selectedRelations,
                    onSelect: { selections in
                        draft.setValue(.array(selections.map { .relation(id: $0.id, label: $0.label) }), for: field.name)
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

    private var selectedRelations: [RelationValue] {
        let value = draft.value(for: field.name, fallback: fallbackValue) ?? fallbackValue
        return value?.relationValues ?? []
    }

    private func removeRelation(_ relationID: Int) {
        let remaining = selectedRelations.filter { $0.id != relationID }
        draft.setValue(.array(remaining.map { .relation(id: $0.id, label: $0.label) }), for: field.name)
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

private struct Many2ManyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let field: FieldSchema
    let comodel: String
    let currentSelections: [RelationValue]
    let onSelect: ([RelationValue]) -> Void

    @State private var query = ""
    @State private var results: [NameSearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedRelations: [RelationValue]

    init(field: FieldSchema, comodel: String, currentSelections: [RelationValue], onSelect: @escaping ([RelationValue]) -> Void) {
        self.field = field
        self.comodel = comodel
        self.currentSelections = currentSelections
        self.onSelect = onSelect
        _selectedRelations = State(initialValue: currentSelections)
    }

    var body: some View {
        NavigationStack {
            List {
                if !selectedRelations.isEmpty {
                    Section("Selected") {
                        ForEach(selectedRelations) { relation in
                            Button {
                                toggleSelection(id: relation.id, label: relation.label)
                            } label: {
                                HStack {
                                    Text(relation.label)
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("many2many-selected-\(field.name)-\(relation.id)")
                        }
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
                                toggleSelection(id: result.id, label: result.name)
                            } label: {
                                HStack {
                                    Text(result.name)
                                    Spacer()
                                    if isSelected(result.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("many2many-option-\(field.name)-\(result.id)")
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

                if !selectedRelations.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            selectedRelations = []
                        }
                        .accessibilityIdentifier("many2many-clear-\(field.name)")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onSelect(selectedRelations)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("many2many-done-\(field.name)")
                }
            }
        }
    }

    private func isSelected(_ relationID: Int) -> Bool {
        selectedRelations.contains { $0.id == relationID }
    }

    private func toggleSelection(id: Int, label: String) {
        if let index = selectedRelations.firstIndex(where: { $0.id == id }) {
            selectedRelations.remove(at: index)
        } else {
            selectedRelations.append(RelationValue(id: id, label: label))
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