import SwiftUI

struct SchemaRendererView: View {
    let schema: MobileFormSchema
    let record: RecordData

    var body: some View {
        ForEach(Array(schema.sections.enumerated()), id: \.offset) { index, section in
            SchemaSectionView(
                section: section,
                record: record,
                title: section.label ?? "Details",
                identifierPrefix: "primary-\(index)"
            )
        }

        ForEach(Array(schema.tabs.enumerated()), id: \.offset) { tabIndex, tab in
            ForEach(Array(tab.sections.enumerated()), id: \.offset) { sectionIndex, section in
                SchemaSectionView(
                    section: section,
                    record: record,
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
    let title: String
    let identifierPrefix: String

    private var rows: [ReadOnlyFieldRowModel] {
        section.fields.compactMap { field in
            FieldRowFactory.model(for: field, rawValue: record[field.name])
        }
    }

    var body: some View {
        if !rows.isEmpty {
            Section(title) {
                ForEach(rows) { row in
                    ReadOnlyFieldRow(model: row)
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