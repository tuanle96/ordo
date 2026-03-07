import Foundation
import Testing
@testable import Ordo

@MainActor
struct FormDraftTests {
    @Test
    func changedValuesOnlyIncludesModifiedEditableFields() {
        let draft = FormDraft(record: [
            "name": .string("Azure Interior"),
            "customer_rank": .string("standard"),
            "is_company": .bool(false),
        ])
        let fields = [
            FieldSchema(name: "name", type: .char, label: "Name", required: true, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "customer_rank", type: .selection, label: "Customer Rank", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: [["standard", "Standard"], ["vip", "VIP"]], currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "is_company", type: .boolean, label: "Company", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
        ]

        draft.setValue(.string("Priority Client"), for: "name")

        let changedValues = draft.changedValues(comparedTo: [
            "name": .string("Azure Interior"),
            "customer_rank": .string("standard"),
            "is_company": .bool(false),
        ], fields: fields)

        #expect(changedValues == ["name": .string("Priority Client")])
        #expect(draft.isDirty(comparedTo: [
            "name": .string("Azure Interior"),
            "customer_rank": .string("standard"),
            "is_company": .bool(false),
        ], fields: fields))
    }

    @Test
    func requiredValidationFlagsBlankTextAndSelectionButNotBooleanFalse() {
        let draft = FormDraft(record: [
            "name": .string("Azure Interior"),
            "customer_rank": .string("vip"),
            "is_company": .bool(false),
        ])
        let fields = [
            FieldSchema(name: "name", type: .char, label: "Name", required: true, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "customer_rank", type: .selection, label: "Customer Rank", required: true, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: [["standard", "Standard"], ["vip", "VIP"]], currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "is_company", type: .boolean, label: "Company", required: true, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
        ]

        draft.setValue(nil, for: "name")
        draft.setValue(nil, for: "customer_rank")
        draft.setValue(.bool(false), for: "is_company")

        let errors = draft.validationErrors(for: fields)

        #expect(errors["name"] == "Name is required.")
        #expect(errors["customer_rank"] == "Customer Rank is required.")
        #expect(errors["is_company"] == nil)
    }
}