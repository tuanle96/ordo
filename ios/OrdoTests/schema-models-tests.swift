import Foundation
import Testing
@testable import Ordo

@MainActor
struct SchemaModelsTests {
        @Test
        func unknownFieldTypesDecodeAsUnsupported() throws {
                // Defensive decoder coverage: the backend currently normalizes unknown types,
                // but the app still needs to survive unexpected schema payloads gracefully.
                let json = """
                {
                    "model": "res.partner",
                    "title": "Partners",
                    "header": { "actions": [] },
                    "sections": [
                        {
                            "label": null,
                            "fields": [
                                {
                                    "name": "x_custom_payload",
                                    "type": "json",
                                    "label": "Custom Payload"
                                }
                            ]
                        }
                    ],
                    "tabs": [],
                    "hasChatter": false
                }
                """.data(using: .utf8)!

                let schema = try JSONDecoder().decode(MobileFormSchema.self, from: json)

                #expect(schema.sections.first?.fields.first?.type == .unsupported)
        }

    @Test
    func tabSectionsDecodeFromContent() throws {
        let section = FormSection(
            label: "Notes",
            fields: [FieldSchema(name: "comment", type: .text, label: "Notes", required: nil, readonly: nil, invisible: nil, modifiers: nil, onchange: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)]
        )
        let tab = FormTab(label: "Extra", content: ["sections": try encodedJSONValue(from: [section])])

        #expect(tab.sections == [section])
    }

    @Test
    func fieldOnchangeMetadataDecodesWhenPresent() throws {
        let json = """
        {
            "model": "res.partner",
            "title": "Partners",
            "header": { "actions": [] },
            "sections": [
                {
                    "label": null,
                    "fields": [
                        {
                            "name": "country_id",
                            "type": "many2one",
                            "label": "Country",
                            "onchange": {
                                "trigger": "country_id",
                                "source": "view",
                                "dependencies": ["company_id"],
                                "mergeReturnedValue": true
                            }
                        }
                    ]
                }
            ],
            "tabs": [],
            "hasChatter": false
        }
        """.data(using: .utf8)!

        let schema = try JSONDecoder().decode(MobileFormSchema.self, from: json)
        let onchange = try #require(schema.sections.first?.fields.first?.onchange)

        #expect(onchange.trigger == "country_id")
        #expect(onchange.source == "view")
        #expect(onchange.dependencies == ["company_id"])
        #expect(onchange.mergeReturnedValue == true)
    }

    @Test
    func requestedFieldNamesIncludeTabFields() throws {
        let schema = MobileFormSchema(
            model: "res.partner",
            title: "Customer",
            header: FormHeader(statusbar: .init(field: "state", visibleStates: nil), actions: []),
            sections: [FormSection(label: "Main", fields: [FieldSchema(name: "name", type: .char, label: "Name", required: nil, readonly: nil, invisible: nil, modifiers: nil, onchange: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)])],
            tabs: [FormTab(label: "Extra", content: ["sections": try encodedJSONValue(from: [FormSection(label: "Notes", fields: [FieldSchema(name: "comment", type: .text, label: "Notes", required: nil, readonly: nil, invisible: nil, modifiers: nil, onchange: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)])])])],
            hasChatter: false
        )

        #expect(Set(schema.requestedFieldNames).isSuperset(of: ["id", "display_name", "name", "state", "comment"]))
    }

    @Test
    func mobileListSchemaDecodesVisibleColumnsAndRequestedFields() throws {
        let json = """
        {
            "model": "res.partner",
            "title": "Partners",
            "columns": [
                { "name": "name", "type": "char", "label": "Name" },
                { "name": "email", "type": "char", "label": "Email", "optional": "show" },
                { "name": "phone", "type": "char", "label": "Phone", "optional": "hide" },
                { "name": "image_128", "type": "image", "label": "Avatar", "columnInvisible": true }
            ],
            "defaultOrder": "name asc",
            "search": {
                "fields": [
                    { "name": "name", "label": "Name", "type": "char" }
                ],
                "filters": [
                    { "name": "companies", "label": "Companies", "domain": "[[\"is_company\",\"=\",true]]" }
                ],
                "groupBy": [
                    { "name": "group_country", "label": "Country", "fieldName": "country_id" }
                ]
            }
        }
        """.data(using: .utf8)!

        let schema = try JSONDecoder().decode(MobileListSchema.self, from: json)

        #expect(schema.visibleColumns.map(\.name) == ["name", "email"])
        #expect(Set(schema.requestedFieldNames).isSuperset(of: ["id", "display_name", "name", "email"]))
        #expect(
            schema.search.filters.first?.domainValue
                == .array([.array([.string("is_company"), .string("="), .bool(true)])])
        )
    }

    private func encodedJSONValue<T: Encodable>(from value: T) throws -> JSONValue {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}