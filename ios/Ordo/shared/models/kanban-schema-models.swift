import Foundation

struct KanbanCardField: Codable, Hashable, Identifiable, Sendable {
    let name: String
    let type: FieldType
    let label: String
    let widget: String?
    let comodel: String?

    var id: String { name }
}

struct KanbanCardButton: Codable, Hashable, Identifiable, Sendable {
    let name: String
    let label: String
    let type: String
    let style: String
    let invisible: ModifierRule?

    var id: String { name }

    var isPrimary: Bool { style == "primary" }
}

struct MobileKanbanSchema: Codable, Hashable, Sendable {
    struct SearchMetadata: Codable, Hashable, Sendable {
        let fields: [SearchField]
        let filters: [SearchFilter]
    }

    let model: String
    let title: String
    let groupByField: String?
    let groupBySelection: [[String]]?
    let cardFields: [KanbanCardField]
    let cardButtons: [KanbanCardButton]
    let colorField: String?
    let search: SearchMetadata

    var requestedFieldNames: [String] {
        var fields = orderedUnique(["id", "display_name", "name"] + [groupByField].compactMap { $0 } + cardFields.map(\.name) + [colorField].compactMap { $0 })

        // Include fields referenced by button invisible conditions so they're fetched
        for button in cardButtons {
            if let rule = button.invisible {
                fields.append(contentsOf: KanbanButtonVisibility.fieldsReferenced(by: rule))
            }
        }

        return orderedUnique(fields)
    }

    /// Returns only the buttons that should be visible for a given record.
    func visibleButtons(for record: RecordData) -> [KanbanCardButton] {
        KanbanButtonVisibility.visibleButtons(from: cardButtons, record: record)
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

// MARK: - Condition Evaluation (standalone to avoid Sendable cascade)

enum KanbanButtonVisibility {
    static func visibleButtons(from buttons: [KanbanCardButton], record: RecordData) -> [KanbanCardButton] {
        buttons.filter { button in
            guard let rule = button.invisible else { return true }
            return !evaluateRule(rule, record: record)
        }
    }

    static func fieldsReferenced(by rule: ModifierRule) -> [String] {
        var fields: [String] = []
        if let condition = rule.condition {
            fields.append(condition.field)
        }
        if let rules = rule.rules {
            for child in rules {
                fields.append(contentsOf: fieldsReferenced(by: child))
            }
        }
        return fields
    }

    private static func evaluateRule(_ rule: ModifierRule, record: RecordData) -> Bool {
        switch rule.type {
        case "condition":
            guard let condition = rule.condition else { return false }
            return evaluateCondition(condition, record: record)
        case "and":
            return rule.rules?.allSatisfy { evaluateRule($0, record: record) } ?? false
        case "or":
            return rule.rules?.contains { evaluateRule($0, record: record) } ?? false
        case "not":
            if let first = rule.rules?.first {
                return !evaluateRule(first, record: record)
            }
            return false
        case "constant":
            return rule.constant ?? false
        default:
            return false
        }
    }

    private static func evaluateCondition(_ condition: Condition, record: RecordData) -> Bool {
        let recordValue = record[condition.field]

        switch condition.op {
        case "==":
            return conditionValueMatches(recordValue, condition.value)
        case "!=":
            return !conditionValueMatches(recordValue, condition.value)
        case "in":
            guard let values = condition.values else { return false }
            return values.contains { conditionValueMatches(recordValue, $0) }
        case "not in":
            guard let values = condition.values else { return true }
            return !values.contains { conditionValueMatches(recordValue, $0) }
        default:
            return false
        }
    }

    private static func conditionValueMatches(_ recordValue: JSONValue?, _ conditionValue: ConditionValue?) -> Bool {
        guard let conditionValue else {
            return recordValue == nil || recordValue?.isVisuallyEmpty == true
        }

        guard let recordValue else { return false }

        switch conditionValue {
        case .string(let expected):
            return recordValue.stringValue == expected || recordValue.displayText == expected
        case .number(let expected):
            if let intValue = recordValue.intValue { return Double(intValue) == expected }
            if let doubleValue = recordValue.doubleValue { return doubleValue == expected }
            return false
        case .bool(let expected):
            return recordValue.boolValue == expected
        case .null:
            return recordValue.isVisuallyEmpty
        }
    }
}