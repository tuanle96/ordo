import Testing
@testable import Ordo

struct ConditionEvaluatorTests {
    @Test
    func equalityAndInequalityUseCurrentValues() {
        let values: RecordData = [
            "state": .string("draft"),
            "is_company": .bool(false),
        ]

        #expect(ConditionEvaluator.matches(.init(field: "state", op: "==", value: "draft", values: nil), values: values))
        #expect(ConditionEvaluator.matches(.init(field: "is_company", op: "!=", value: "true", values: nil), values: values))
    }

    @Test
    func inAndNotInWorkForSelectionValues() {
        let values: RecordData = [
            "customer_rank": .string("vip"),
        ]

        #expect(ConditionEvaluator.matches(.init(field: "customer_rank", op: "in", value: nil, values: ["vip", "gold"]), values: values))
        #expect(ConditionEvaluator.matches(.init(field: "customer_rank", op: "not in", value: nil, values: ["standard", "bronze"]), values: values))
    }

    @Test
    func fieldVisibilityUsesInvisibleCondition() {
        let field = FieldSchema(name: "internal_note", type: .text, label: "Internal Note", required: nil, readonly: nil, invisible: .init(field: "is_company", op: "==", value: "false", values: nil), domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)

        #expect(field.isInvisible(in: ["is_company": .bool(false)]))
        #expect(!field.isInvisible(in: ["is_company": .bool(true)]))
    }
}