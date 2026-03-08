import Testing
@testable import Ordo

struct FieldRowFactoryTests {
    @Test
    func selectionUsesDisplayLabel() {
        let field = FieldSchema(name: "state", type: .selection, label: "Status", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: [["draft", "Draft"], ["done", "Done"]], currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)

        let model = FieldRowFactory.model(for: field, rawValue: .string("done"))

        #expect(model?.value == "Done")
        #expect(model?.style == .standard)
    }

    @Test
    func unsupportedTypesFallBackGracefully() {
        let field = FieldSchema(name: "bio", type: .html, label: "Biography", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)

        let model = FieldRowFactory.model(for: field, rawValue: .string("<p>Hello</p>"))

        #expect(model?.value == "<p>Hello</p>")
        #expect(model?.style == .unsupported(.html))
    }

    @Test
    func unknownTypesUseUnsupportedFallbackStyle() {
        let field = FieldSchema(name: "x_payload", type: .unsupported, label: "Payload", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)

        let model = FieldRowFactory.model(for: field, rawValue: .string("{\"ok\":true}"))

        #expect(model?.value == "{\"ok\":true}")
        #expect(model?.style == .unsupported(.unsupported))
    }

    @Test
    func priorityUsesFormattedStars() {
        let field = FieldSchema(name: "priority", type: .priority, label: "Priority", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)

        let model = FieldRowFactory.model(for: field, rawValue: .string("2"))

        #expect(model?.value == "★★☆")
        #expect(model?.style == .standard)
    }

    @Test
    func monetaryUsesConfiguredPrecision() {
        let field = FieldSchema(name: "credit_limit", type: .monetary, label: "Credit Limit", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: "currency_id", placeholder: nil, digits: [16, 2], subfields: nil, searchable: nil, widget: nil)

        let model = FieldRowFactory.model(for: field, rawValue: .number(2500.5))

        #expect(model?.value == "2,500.50")
        #expect(model?.style == .standard)
    }

    @Test
    func unsupportedFieldsRemainOutOfEditMode() {
        let many2one = FieldSchema(name: "country_id", type: .many2one, label: "Country", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "res.country", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)
        let many2many = FieldSchema(name: "category_id", type: .many2many, label: "Tags", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "res.partner.category", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)
        let html = FieldSchema(name: "bio", type: .html, label: "Biography", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)

        let many2oneModel = EditableFieldFactory.model(for: many2one)
        let many2manyModel = EditableFieldFactory.model(for: many2many)

        if case .many2one(let comodel)? = many2oneModel?.style {
            #expect(comodel == "res.country")
        } else {
            Issue.record("Expected many2one field to stay editable.")
        }

        if case .many2many(let comodel)? = many2manyModel?.style {
            #expect(comodel == "res.partner.category")
        } else {
            Issue.record("Expected many2many field to stay editable.")
        }

        #expect(EditableFieldFactory.model(for: html) == nil)
    }

    @Test
    func many2ManyReadOnlyUsesTagLabels() {
        let field = FieldSchema(name: "category_id", type: .many2many, label: "Tags", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "res.partner.category", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)

        let model = FieldRowFactory.model(for: field, rawValue: .array([
            .relation(id: 8, label: "VIP"),
            .relation(id: 11, label: "Wholesale"),
        ]))

        #expect(model?.value == "VIP, Wholesale")
        #expect(model?.style == .standard)
    }
}