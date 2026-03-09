import SwiftUI

struct FilterSheetView: View {
    @Environment(\ .dismiss) private var dismiss

    let descriptor: ModelDescriptor
    let fields: [BrowseFilterField]
    let initialState: BrowseFilterState
    let onApply: (BrowseFilterState) -> Void

    @State private var draftState: BrowseFilterState

    init(
        descriptor: ModelDescriptor,
        fields: [BrowseFilterField],
        initialState: BrowseFilterState,
        onApply: @escaping (BrowseFilterState) -> Void
    ) {
        self.descriptor = descriptor
        self.fields = fields
        self.initialState = initialState
        self.onApply = onApply
        _draftState = State(initialValue: initialState)
    }

    var body: some View {
        NavigationStack {
            Form {
                if fields.isEmpty {
                    Section {
                        Text("No filters are available for this model yet.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Text("Combine multiple conditions to narrow the browse list. Search still works on top of the filtered result set.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Conditions") {
                        if draftState.conditions.isEmpty {
                            Text("No active conditions yet.")
                                .foregroundStyle(.secondary)
                        }

                        ForEach($draftState.conditions) { $condition in
                            FilterConditionEditor(condition: $condition, fields: fields)
                        }
                        .onDelete { offsets in
                            draftState.conditions.remove(atOffsets: offsets)
                        }

                        Button {
                            addCondition()
                        } label: {
                            Label("Add Condition", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") {
                        draftState = .empty
                    }
                    .disabled(draftState.conditions.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        onApply(draftState.normalized(with: fields))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func addCondition() {
        guard let field = fields.first else { return }
        let filterOperator = BrowseFilterOperator.supported(for: field.kind).first ?? .contains
        draftState.conditions.append(
            BrowseFilterCondition(fieldName: field.name, filterOperator: filterOperator)
        )
    }
}

private struct FilterConditionEditor: View {
    @Binding var condition: BrowseFilterCondition

    let fields: [BrowseFilterField]

    private var selectedField: BrowseFilterField {
        fields.first(where: { $0.name == condition.fieldName }) ?? fields[0]
    }

    private var supportedOperators: [BrowseFilterOperator] {
        BrowseFilterOperator.supported(for: selectedField.kind)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Field", selection: fieldNameBinding) {
                ForEach(fields) { field in
                    Text(field.label).tag(field.name)
                }
            }

            Picker("Operator", selection: operatorBinding) {
                ForEach(supportedOperators) { filterOperator in
                    Text(filterOperator.title).tag(filterOperator)
                }
            }

            valueEditor
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var valueEditor: some View {
        switch selectedField.kind {
        case .text:
            TextField("Value", text: stringValueBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        case .number:
            TextField("Value", text: numberStringBinding)
                .keyboardType(.decimalPad)
        case .selection(let options):
            Picker("Value", selection: stringValueBinding) {
                Text("Select…").tag("")
                ForEach(options, id: \.self) { option in
                    if option.count > 1 {
                        Text(option[1]).tag(option[0])
                    }
                }
            }
        case .boolean:
            Picker("Value", selection: boolBinding) {
                Text("Yes").tag(true)
                Text("No").tag(false)
            }
            .pickerStyle(.segmented)
        }
    }

    private var fieldNameBinding: Binding<String> {
        Binding(
            get: { condition.fieldName },
            set: { newFieldName in
                guard let field = fields.first(where: { $0.name == newFieldName }) else { return }
                condition.fieldName = newFieldName
                condition.filterOperator = BrowseFilterOperator.supported(for: field.kind).first ?? .contains
                condition.value = defaultValue(for: field.kind)
            }
        )
    }

    private var operatorBinding: Binding<BrowseFilterOperator> {
        Binding(
            get: {
                let current = condition.filterOperator
                return supportedOperators.contains(current) ? current : supportedOperators.first ?? .contains
            },
            set: { condition.filterOperator = $0 }
        )
    }

    private var stringValueBinding: Binding<String> {
        Binding(
            get: { condition.value?.stringValue ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                condition.value = trimmed.isEmpty ? nil : .string(trimmed)
            }
        )
    }

    private var numberStringBinding: Binding<String> {
        Binding(
            get: {
                switch condition.value {
                case .number(let number):
                    return number.rounded() == number ? String(Int(number)) : String(number)
                case .string(let raw):
                    return raw
                default:
                    return ""
                }
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                condition.value = trimmed.isEmpty ? nil : .string(trimmed)
            }
        )
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: {
                if case .bool(let value)? = condition.value {
                    return value
                }
                return true
            },
            set: { condition.value = .bool($0) }
        )
    }

    private func defaultValue(for kind: BrowseFilterFieldKind) -> JSONValue? {
        switch kind {
        case .text, .number:
            return nil
        case .selection(let options):
            guard let firstKey = options.first?.first else { return nil }
            return .string(firstKey)
        case .boolean:
            return .bool(true)
        }
    }
}