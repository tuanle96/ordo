import SwiftUI

struct SchemaRendererView: View {
    let schema: MobileFormSchema
    let record: RecordData
    var draft: FormDraft? = nil
    var isEditing = false
    var hiddenFieldNames: Set<String> = []
    var searchDomains: [String: JSONValue] = [:]
    var validationErrors: [String: String] = [:]
    var onFieldChange: ((FieldSchema, JSONValue?) -> Void)? = nil

    var body: some View {
        ForEach(Array(schema.sections.enumerated()), id: \.offset) { index, section in
            SchemaSectionView(
                section: section,
                record: record,
                draft: draft,
                isEditing: isEditing,
                hiddenFieldNames: hiddenFieldNames,
                searchDomains: searchDomains,
                validationErrors: validationErrors,
                onFieldChange: onFieldChange,
                title: section.label ?? "Details",
                identifierPrefix: "primary-\(index)"
            )
        }

        ForEach(Array(schema.tabs.enumerated()), id: \.offset) { tabIndex, tab in
            ForEach(Array(tab.sections.enumerated()), id: \.offset) { sectionIndex, section in
                SchemaSectionView(
                    section: section,
                    record: record,
                    draft: draft,
                    isEditing: isEditing,
                    hiddenFieldNames: hiddenFieldNames,
                    searchDomains: searchDomains,
                    validationErrors: validationErrors,
                    onFieldChange: onFieldChange,
                    title: section.label ?? tab.label,
                    identifierPrefix: "tab-\(tabIndex)-\(sectionIndex)"
                )
            }
        }
    }
}

private struct SchemaSectionView: View {
    let section: FormSection
    let record: RecordData
    let draft: FormDraft?
    let isEditing: Bool
    let hiddenFieldNames: Set<String>
    let searchDomains: [String: JSONValue]
    let validationErrors: [String: String]
    let onFieldChange: ((FieldSchema, JSONValue?) -> Void)?
    let title: String
    let identifierPrefix: String

    private var values: RecordData {
        draft?.values ?? record
    }

    private var fields: [FieldSchema] {
        section.fields.filter { field in
            !hiddenFieldNames.contains(field.name) && !field.isInvisible(in: values)
        }
    }

    private var rows: [FieldSchema] {
        fields.filter { field in
            let rawValue = values[field.name] ?? record[field.name]
            if isEditing, draft != nil, !field.isReadOnly(in: values), EditableFieldFactory.model(for: field) != nil {
                return true
            }
            return FieldRowFactory.model(for: field, rawValue: rawValue, record: record) != nil
        }
    }

    @ViewBuilder
    private func row(for field: FieldSchema) -> some View {
        let rawValue = values[field.name] ?? record[field.name]

        if isEditing,
           let draft,
              !field.isReadOnly(in: values),
           let editor = EditableFieldFactory.model(for: field) {
            EditableFieldRow(
                field: field,
                model: editor,
                draft: draft,
                fallbackValue: record[field.name],
                searchDomain: searchDomains[field.name],
                validationMessage: validationErrors[field.name],
                onValueChange: onFieldChange
            )
        } else if let row = FieldRowFactory.model(for: field, rawValue: rawValue, record: record) {
            ReadOnlyFieldRow(model: row)
        }
    }

    var body: some View {
        if !rows.isEmpty {
            Section(title) {
                ForEach(rows, id: \.name) { field in
                    row(for: field)
                }
            }
            .accessibilityIdentifier("schema-section-\(identifierPrefix)")
        }
    }
}

#Preview {
    List {
        SchemaRendererView(
            schema: MobileFormSchema(
                model: "res.partner",
                title: "Customer",
                header: FormHeader(statusbar: nil, actions: []),
                sections: [
                    FormSection(label: "Main", fields: [
                        FieldSchema(name: "name", type: .char, label: "Name", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
                    ]),
                ],
                tabs: [],
                hasChatter: false
            ),
            record: ["name": .string("Azure Interior")]
        )
    }
}