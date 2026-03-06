import Foundation
import Testing
@testable import Ordo

struct SchemaModelsTests {
    @Test
    func tabSectionsDecodeFromContent() throws {
        let section = FormSection(
            label: "Notes",
            fields: [FieldSchema(name: "comment", type: .text, label: "Notes", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)]
        )
        let tab = FormTab(label: "Extra", content: ["sections": try encodedJSONValue(from: [section])])

        #expect(tab.sections == [section])
    }

    @Test
    func requestedFieldNamesIncludeTabFields() throws {
        let schema = MobileFormSchema(
            model: "res.partner",
            title: "Customer",
            header: FormHeader(statusbar: .init(field: "state", visibleStates: nil), actions: []),
            sections: [FormSection(label: "Main", fields: [FieldSchema(name: "name", type: .char, label: "Name", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)])],
            tabs: [FormTab(label: "Extra", content: ["sections": try encodedJSONValue(from: [FormSection(label: "Notes", fields: [FieldSchema(name: "comment", type: .text, label: "Notes", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)])])])],
            hasChatter: false
        )

        #expect(Set(schema.requestedFieldNames).isSuperset(of: ["id", "display_name", "name", "state", "comment"]))
    }

    private func encodedJSONValue<T: Encodable>(from value: T) throws -> JSONValue {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}