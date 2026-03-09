import Testing
import UIKit
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

        #expect(model?.value == "Hello")
        #expect(model?.style == .multiline)
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
    func imageReadOnlyUsesPreviewStyle() {
        let field = FieldSchema(name: "image_128", type: .image, label: "Photo", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)

        let model = FieldRowFactory.model(for: field, rawValue: .string(Self.sampleImageBase64))

        #expect(model?.value == "Image attached")
        #expect(model?.style == .image)
        #expect(model?.previewData != nil)
    }

    @Test
    func binaryReadOnlyUsesFilenameCompanionWhenPresent() {
        let field = FieldSchema(name: "attachment", type: .binary, label: "Attachment", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, filenameField: "attachment_name", placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)
        let record: RecordData = [
            "attachment": .string(Data([0x25, 0x50, 0x44, 0x46]).base64EncodedString()),
            "attachment_name": .string("invoice.pdf"),
        ]

        let model = FieldRowFactory.model(for: field, rawValue: record["attachment"], record: record)

        #expect(model?.value == "invoice.pdf")
        #expect(model?.style == .standard)
    }

    @Test
    func monetaryUsesConfiguredPrecision() {
        let field = FieldSchema(name: "credit_limit", type: .monetary, label: "Credit Limit", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: "currency_id", placeholder: nil, digits: [16, 2], subfields: nil, searchable: nil, widget: nil)
        let record: RecordData = [
            "credit_limit": .number(2500.5),
            "currency_id": .relation(id: 3, label: "USD"),
        ]

        let model = FieldRowFactory.model(for: field, rawValue: .number(2500.5), record: record)

        #expect(model?.value == "USD 2,500.50")
        #expect(model?.style == .standard)
    }

    @Test
    func unsupportedFieldsRemainOutOfEditMode() {
        let many2one = FieldSchema(name: "country_id", type: .many2one, label: "Country", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "res.country", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)
        let one2many = FieldSchema(name: "order_line", type: .one2many, label: "Order Lines", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "sale.order.line", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: [FieldSchema(name: "name", type: .char, label: "Description", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)], searchable: nil, widget: nil)
        let many2many = FieldSchema(name: "category_id", type: .many2many, label: "Tags", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "res.partner.category", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)
        let monetary = FieldSchema(name: "credit_limit", type: .monetary, label: "Credit Limit", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: "currency_id", placeholder: nil, digits: [16, 2], subfields: nil, searchable: nil, widget: nil)
        let integer = FieldSchema(name: "sequence", type: .integer, label: "Sequence", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)
        let float = FieldSchema(name: "amount_total", type: .float, label: "Amount", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: [16, 2], subfields: nil, searchable: nil, widget: nil)
        let date = FieldSchema(name: "date_order", type: .date, label: "Order Date", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)
        let datetime = FieldSchema(name: "write_date", type: .datetime, label: "Updated", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)
        let html = FieldSchema(name: "bio", type: .html, label: "Biography", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)
        let image = FieldSchema(name: "image_128", type: .image, label: "Photo", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)
        let binary = FieldSchema(name: "attachment", type: .binary, label: "Attachment", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, filenameField: "attachment_name", placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)
        let priority = FieldSchema(name: "priority", type: .priority, label: "Priority", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)

        let many2oneModel = EditableFieldFactory.model(for: many2one)
        let one2manyModel = EditableFieldFactory.model(for: one2many)
        let many2manyModel = EditableFieldFactory.model(for: many2many)
        let monetaryModel = EditableFieldFactory.model(for: monetary)
        let integerModel = EditableFieldFactory.model(for: integer)
        let floatModel = EditableFieldFactory.model(for: float)
        let dateModel = EditableFieldFactory.model(for: date)
        let datetimeModel = EditableFieldFactory.model(for: datetime)
        let htmlModel = EditableFieldFactory.model(for: html)
        let imageModel = EditableFieldFactory.model(for: image)
        let binaryModel = EditableFieldFactory.model(for: binary)
        let priorityModel = EditableFieldFactory.model(for: priority)

        if case .many2one(let comodel)? = many2oneModel?.style {
            #expect(comodel == "res.country")
        } else {
            Issue.record("Expected many2one field to stay editable.")
        }

        if case .one2many(let subfields)? = one2manyModel?.style {
            #expect(subfields.map(\.name) == ["name"])
        } else {
            Issue.record("Expected one2many field with subfields to stay editable.")
        }

        if case .many2many(let comodel)? = many2manyModel?.style {
            #expect(comodel == "res.partner.category")
        } else {
            Issue.record("Expected many2many field to stay editable.")
        }

        if case .monetary(let currencyField)? = monetaryModel?.style {
            #expect(currencyField == "currency_id")
        } else {
            Issue.record("Expected monetary field to stay editable.")
        }

        if case .integer? = integerModel?.style {
            #expect(integerModel != nil)
        } else {
            Issue.record("Expected integer field to stay editable.")
        }

        if case .float? = floatModel?.style {
            #expect(floatModel != nil)
        } else {
            Issue.record("Expected float field to stay editable.")
        }

        if case .date? = dateModel?.style {
            #expect(dateModel != nil)
        } else {
            Issue.record("Expected date field to stay editable.")
        }

        if case .datetime? = datetimeModel?.style {
            #expect(datetimeModel != nil)
        } else {
            Issue.record("Expected datetime field to stay editable.")
        }

        if case .multiline? = htmlModel?.style {
            #expect(htmlModel != nil)
        } else {
            Issue.record("Expected html field to stay editable as multiline text.")
        }

        if case .image? = imageModel?.style {
            #expect(imageModel != nil)
        } else {
            Issue.record("Expected image field to stay editable.")
        }

        if case .binary(let filenameField)? = binaryModel?.style {
            #expect(filenameField == "attachment_name")
        } else {
            Issue.record("Expected binary field to stay editable.")
        }

        if case .priority? = priorityModel?.style {
            #expect(priorityModel != nil)
        } else {
            Issue.record("Expected priority field to stay editable.")
        }
    }

    @Test
    func htmlReadOnlyUsesPlainTextFallback() {
        let field = FieldSchema(name: "terms", type: .html, label: "Terms", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)

        let model = FieldRowFactory.model(for: field, rawValue: .string("<div><strong>Pay</strong> now</div>"))

        #expect(model?.value == "Pay now")
        #expect(model?.style == .multiline)
    }

    @Test
    func booleanFalseReadOnlyStaysVisible() {
        let field = FieldSchema(name: "is_company", type: .boolean, label: "Company", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)

        let model = FieldRowFactory.model(for: field, rawValue: .bool(false))

        #expect(model?.value == "No")
        #expect(model?.style == .standard)
    }

    @Test
    func one2ManyEditorSupportKeepsHtmlAndMonetaryOnGenericPath() {
        #expect(One2ManyFieldEditorSupport.isEditable(.html) == true)
        #expect(One2ManyFieldEditorSupport.isEditable(.monetary) == true)
        #expect(One2ManyFieldEditorSupport.usesMultilineInput(.html) == true)
        #expect(One2ManyFieldEditorSupport.keyboardType(for: .monetary) == .decimalPad)
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

    @Test
    func one2ManyReadOnlyUsesLineCount() {
        let field = FieldSchema(name: "order_line", type: .one2many, label: "Order Lines", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "sale.order.line", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)

        let model = FieldRowFactory.model(for: field, rawValue: .array([
            .number(11),
            .object(["name": .string("Custom line")]),
        ]))

        #expect(model?.value == "2 line items")
        #expect(model?.style == .standard)
    }

    private static var sampleImageBase64: String {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }

        return image.pngData()?.base64EncodedString() ?? ""
    }
}