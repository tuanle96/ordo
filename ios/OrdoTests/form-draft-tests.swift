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

    @Test
    func many2oneChangedValuesNormalizeToRelationID() {
        let baseline: RecordData = [
            "country_id": .relation(id: 233, label: "United States"),
        ]
        let draft = FormDraft(record: baseline)
        let fields = [
            FieldSchema(name: "country_id", type: .many2one, label: "Country", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "res.country", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
        ]

        draft.setValue(.relation(id: 124, label: "Canada"), for: "country_id")

        let changedValues = draft.changedValues(comparedTo: baseline, fields: fields)

        #expect(changedValues == ["country_id": .number(124)])
    }

    @Test
    func requiredValidationFlagsMissingMany2One() {
        let draft = FormDraft(record: [:])
        let fields = [
            FieldSchema(name: "country_id", type: .many2one, label: "Country", required: true, readonly: nil, invisible: nil, domain: nil, comodel: "res.country", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
        ]

        #expect(draft.validationErrors(for: fields)["country_id"] == "Country is required.")

        draft.setValue(.relation(id: 124, label: "Canada"), for: "country_id")

        #expect(draft.validationErrors(for: fields)["country_id"] == nil)
    }

    @Test
    func clearingMany2OneProducesNullMutationValue() {
        let baseline: RecordData = [
            "country_id": .relation(id: 233, label: "United States"),
        ]
        let draft = FormDraft(record: baseline)
        let fields = [
            FieldSchema(name: "country_id", type: .many2one, label: "Country", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "res.country", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
        ]

        draft.setValue(nil, for: "country_id")

        let changedValues = draft.changedValues(comparedTo: baseline, fields: fields)

        #expect(changedValues == ["country_id": .null])
    }

    @Test
    func many2OneLabelChangeWithSameIDIsNotDirty() {
        let baseline: RecordData = [
            "country_id": .relation(id: 233, label: "United States"),
        ]
        let draft = FormDraft(record: baseline)
        let fields = [
            FieldSchema(name: "country_id", type: .many2one, label: "Country", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "res.country", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
        ]

        draft.setValue(.relation(id: 233, label: "USA"), for: "country_id")

        #expect(draft.changedValues(comparedTo: baseline, fields: fields).isEmpty)
        #expect(draft.isDirty(comparedTo: baseline, fields: fields) == false)
    }

    @Test
    func many2manyChangedValuesNormalizeToReplaceCommand() {
        let baseline: RecordData = [
            "category_id": .array([
                .relation(id: 8, label: "VIP"),
            ]),
        ]
        let draft = FormDraft(record: baseline)
        let fields = [
            FieldSchema(name: "category_id", type: .many2many, label: "Tags", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "res.partner.category", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
        ]

        draft.setValue(.array([
            .relation(id: 8, label: "VIP"),
            .relation(id: 11, label: "Wholesale"),
        ]), for: "category_id")

        let changedValues = draft.changedValues(comparedTo: baseline, fields: fields)

        #expect(changedValues == [
            "category_id": .array([
                .array([
                    .number(6),
                    .number(0),
                    .array([.number(8), .number(11)]),
                ]),
            ]),
        ])
    }

    @Test
    func clearingMany2manyProducesReplaceCommandWithEmptyIDs() {
        let baseline: RecordData = [
            "category_id": .array([
                .relation(id: 8, label: "VIP"),
            ]),
        ]
        let draft = FormDraft(record: baseline)
        let fields = [
            FieldSchema(name: "category_id", type: .many2many, label: "Tags", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "res.partner.category", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
        ]

        draft.setValue(.array([]), for: "category_id")

        let changedValues = draft.changedValues(comparedTo: baseline, fields: fields)

        #expect(changedValues == [
            "category_id": .array([
                .array([
                    .number(6),
                    .number(0),
                    .array([]),
                ]),
            ]),
        ])
    }

    @Test
    func many2manyLabelChangeWithSameIDsIsNotDirty() {
        let baseline: RecordData = [
            "category_id": .array([
                .relation(id: 8, label: "VIP"),
                .relation(id: 11, label: "Wholesale"),
            ]),
        ]
        let draft = FormDraft(record: baseline)
        let fields = [
            FieldSchema(name: "category_id", type: .many2many, label: "Tags", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "res.partner.category", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
        ]

        draft.setValue(.array([
            .relation(id: 11, label: "Wholesale Accounts"),
            .relation(id: 8, label: "VIP Clients"),
        ]), for: "category_id")

        #expect(draft.changedValues(comparedTo: baseline, fields: fields).isEmpty)
        #expect(draft.isDirty(comparedTo: baseline, fields: fields) == false)
    }

    @Test
    func numericAndTemporalStringsNormalizeForMutations() {
        let baseline: RecordData = [:]
        let draft = FormDraft(record: baseline)
        let fields = [
            FieldSchema(name: "sequence", type: .integer, label: "Sequence", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "amount_total", type: .float, label: "Amount", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: [16, 2], subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "date_order", type: .date, label: "Order Date", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "write_date", type: .datetime, label: "Updated", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
        ]

        draft.setValue(.string("42"), for: "sequence")
        draft.setValue(.string("19.95"), for: "amount_total")
        draft.setValue(.string("2026-03-08"), for: "date_order")
        draft.setValue(.string("2026-03-08 14:30"), for: "write_date")

        let changedValues = draft.changedValues(comparedTo: baseline, fields: fields)

        #expect(changedValues["sequence"] == .number(42))
        #expect(changedValues["amount_total"] == .number(19.95))
        #expect(changedValues["date_order"] == .string("2026-03-08"))
        #expect(changedValues["write_date"] == .string("2026-03-08 14:30:00"))
    }

    @Test
    func invalidNumericAndTemporalInputsSurfaceValidationErrors() {
        let draft = FormDraft(record: [:])
        let fields = [
            FieldSchema(name: "sequence", type: .integer, label: "Sequence", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "amount_total", type: .float, label: "Amount", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: [16, 2], subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "date_order", type: .date, label: "Order Date", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "write_date", type: .datetime, label: "Updated", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
        ]

        draft.setValue(.string("forty-two"), for: "sequence")
        draft.setValue(.string("19,95"), for: "amount_total")
        draft.setValue(.string("08/03/2026"), for: "date_order")
        draft.setValue(.string("tomorrow noon"), for: "write_date")

        let errors = draft.validationErrors(for: fields)

        #expect(errors["sequence"] == "Sequence must be a whole number.")
        #expect(errors["amount_total"] == "Amount must be a number.")
        #expect(errors["date_order"] == "Order Date must use YYYY-MM-DD.")
        #expect(errors["write_date"] == "Updated must use YYYY-MM-DD HH:MM format.")
    }

    @Test
    func onchangeValuesNormalizeCurrentDraftState() {
        let baseline: RecordData = [
            "name": .string("Azure Interior"),
            "country_id": .relation(id: 233, label: "United States"),
            "amount_total": .number(10),
        ]
        let draft = FormDraft(record: baseline)
        let fields = [
            FieldSchema(name: "name", type: .char, label: "Name", required: true, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "country_id", type: .many2one, label: "Country", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: "res.country", selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            FieldSchema(name: "amount_total", type: .float, label: "Amount", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: [16, 2], subfields: nil, searchable: nil, widget: nil),
        ]

        draft.setValue(.string("Priority Client"), for: "name")
        draft.setValue(.relation(id: 124, label: "Canada"), for: "country_id")
        draft.setValue(.string("19.95"), for: "amount_total")

        let onchangeValues = draft.onchangeValues(comparedTo: baseline, fields: fields)

        #expect(onchangeValues["name"] == .string("Priority Client"))
        #expect(onchangeValues["country_id"] == .number(124))
        #expect(onchangeValues["amount_total"] == .number(19.95))
    }

    @Test
    func mergeOnchangeValuesSkipsFieldsEditedAfterRequestStarted() {
        let draft = FormDraft(record: [
            "name": .string("Azure Interior"),
            "nickname": .string("VIP 1"),
        ])
        let fieldsByName = [
            "name": FieldSchema(name: "name", type: .char, label: "Name", required: nil, readonly: nil, invisible: nil, modifiers: nil, onchange: OnchangeFieldMeta(trigger: "name", source: "view", dependencies: nil, mergeReturnedValue: true), domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
            "nickname": FieldSchema(name: "nickname", type: .char, label: "Nickname", required: nil, readonly: nil, invisible: nil, modifiers: nil, onchange: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil),
        ]

        draft.setValue(.string("Ac"), for: "name")
        let protectedVersions = draft.editVersions
        draft.setValue(.string("Ace"), for: "name")

        let mergedFields = draft.mergeOnchangeValues(
            [
                "name": .string("Server Name"),
                "nickname": .string("Server Nick"),
            ],
            fieldsByName: fieldsByName,
            protectingEditsAfter: protectedVersions
        )

        #expect(draft.value(for: "name", fallback: nil) == .string("Ace"))
        #expect(draft.value(for: "nickname", fallback: nil) == .string("Server Nick"))
        #expect(mergedFields == ["nickname"])
    }
}