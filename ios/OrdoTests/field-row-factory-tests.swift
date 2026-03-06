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
}