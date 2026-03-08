import Testing
@testable import Ordo

struct ConditionEvaluatorTests {
    @Test
    func equalityAndInequalityUseCurrentValues() {
        let values: RecordData = [
            "state": .string("draft"),
            "is_company": .bool(false),
        ]

        #expect(ConditionEvaluator.matches(.init(field: "state", op: "==", value: .string("draft"), values: nil), values: values))
        #expect(ConditionEvaluator.matches(.init(field: "is_company", op: "!=", value: .bool(true), values: nil), values: values))
    }

    @Test
    func inAndNotInWorkForSelectionValues() {
        let values: RecordData = [
            "customer_rank": .string("vip"),
        ]

        #expect(ConditionEvaluator.matches(.init(field: "customer_rank", op: "in", value: nil, values: [.string("vip"), .string("gold")]), values: values))
        #expect(ConditionEvaluator.matches(.init(field: "customer_rank", op: "not in", value: nil, values: [.string("standard"), .string("bronze")]), values: values))
    }

    @Test
    func fieldVisibilityUsesInvisibleCondition() {
        let field = FieldSchema(name: "internal_note", type: .text, label: "Internal Note", required: nil, readonly: nil, invisible: .init(field: "is_company", op: "==", value: .bool(false), values: nil), modifiers: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)

        #expect(field.isInvisible(in: ["is_company": .bool(false)]))
        #expect(!field.isInvisible(in: ["is_company": .bool(true)]))
    }

    @Test
    func recursiveModifierRulesDriveReadonlyAndRequired() {
        let field = FieldSchema(
            name: "email",
            type: .char,
            label: "Email",
            required: nil,
            readonly: nil,
            invisible: nil,
            modifiers: .init(
                invisible: .init(
                    type: "or",
                    condition: nil,
                    rules: [
                        .init(type: "condition", condition: .init(field: "company_type", op: "==", value: .string("private"), values: nil), rules: nil, constant: nil),
                        .init(type: "condition", condition: .init(field: "active", op: "==", value: .bool(false), values: nil), rules: nil, constant: nil),
                    ],
                    constant: nil
                ),
                readonly: .init(type: "condition", condition: .init(field: "state", op: "==", value: .string("done"), values: nil), rules: nil, constant: nil),
                required: .init(type: "condition", condition: .init(field: "state", op: "!=", value: .string("draft"), values: nil), rules: nil, constant: nil)
            ),
            domain: nil,
            comodel: nil,
            selection: nil,
            currencyField: nil,
            placeholder: nil,
            digits: nil,
            subfields: nil,
            searchable: nil,
            widget: nil
        )

        #expect(field.isInvisible(in: ["company_type": .string("private")]))
        #expect(field.isReadOnly(in: ["state": .string("done")]))
        #expect(field.isRequired(in: ["state": .string("sent")]))
        #expect(!field.isRequired(in: ["state": .string("draft")]))
    }
}