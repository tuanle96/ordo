import Foundation

enum ConditionEvaluator {
    static func matches(_ condition: Condition, values: RecordData) -> Bool {
        let candidates = candidateStrings(for: values[condition.field])

        switch condition.op {
        case "==":
            guard let value = condition.value else { return false }
            return matchesEquality(candidates, against: value)
        case "!=":
            guard let value = condition.value else { return false }
            return !matchesEquality(candidates, against: value)
        case "in":
            guard let values = condition.values else { return false }
            return values.contains { matchesEquality(candidates, against: $0) }
        case "not in":
            guard let values = condition.values else { return false }
            return values.allSatisfy { !matchesEquality(candidates, against: $0) }
        case ">":
            guard let value = condition.value else { return false }
            return compare(candidates, against: value) == .orderedDescending
        case "<":
            guard let value = condition.value else { return false }
            return compare(candidates, against: value) == .orderedAscending
        case ">=":
            guard let value = condition.value else { return false }
            let result = compare(candidates, against: value)
            return result == .orderedDescending || result == .orderedSame
        case "<=":
            guard let value = condition.value else { return false }
            let result = compare(candidates, against: value)
            return result == .orderedAscending || result == .orderedSame
        default:
            return false
        }
    }

    static func matches(_ rule: ModifierRule, values: RecordData) -> Bool {
        switch rule.type {
        case "constant":
            return rule.constant ?? false
        case "condition":
            guard let condition = rule.condition else { return false }
            return matches(condition, values: values)
        case "and":
            return (rule.rules ?? []).allSatisfy { matches($0, values: values) }
        case "or":
            return (rule.rules ?? []).contains { matches($0, values: values) }
        case "not":
            guard let child = rule.rules?.first else { return false }
            return !matches(child, values: values)
        default:
            return false
        }
    }

    private static func matchesEquality(_ candidates: [String], against rhs: ConditionValue) -> Bool {
        candidateStrings(for: rhs).contains { compare(candidates, against: $0) == .orderedSame }
    }

    private static func compare(_ candidates: [String], against rhs: ConditionValue) -> ComparisonResult? {
        candidateStrings(for: rhs).lazy
            .compactMap { compare(candidates, against: $0) }
            .first
    }

    private static func compare(_ candidates: [String], against rhs: String) -> ComparisonResult? {
        for candidate in candidates {
            if let lhsNumber = Double(candidate), let rhsNumber = Double(rhs) {
                if lhsNumber == rhsNumber { return .orderedSame }
                return lhsNumber < rhsNumber ? .orderedAscending : .orderedDescending
            }

            if candidate == rhs {
                return .orderedSame
            }

            let result = candidate.localizedStandardCompare(rhs)
            if result != .orderedSame {
                return result
            }
        }

        return nil
    }

    private static func candidateStrings(for value: JSONValue?) -> [String] {
        guard let value else { return [] }

        switch value {
        case .string(let raw):
            return [raw]
        case .number(let raw):
            if raw.rounded() == raw {
                return [String(Int(raw)), String(raw)]
            }
            return [String(raw)]
        case .bool(let raw):
            return [raw ? "true" : "false", value.displayText]
        case .array(let items):
            return items.flatMap(candidateStrings(for:)).uniqued()
        case .object(let object):
            return [object["id"], object["display_name"], object["name"]]
                .flatMap { candidateStrings(for: $0) }
                .uniqued()
        case .null:
            return ["false", "null", ""]
        }
    }

    private static func candidateStrings(for value: ConditionValue) -> [String] {
        switch value {
        case .string(let raw):
            return [raw]
        case .number(let raw):
            if raw.rounded() == raw {
                return [String(Int(raw)), String(raw)]
            }
            return [String(raw)]
        case .bool(let raw):
            return [raw ? "true" : "false"]
        case .null:
            return ["false", "null", ""]
        }
    }
}

extension FieldSchema {
    func isInvisible(in values: RecordData) -> Bool {
        if let rule = modifiers?.invisible {
            return ConditionEvaluator.matches(rule, values: values)
        }

        guard let invisible else { return false }
        return ConditionEvaluator.matches(invisible, values: values)
    }

    func isReadOnly(in values: RecordData) -> Bool {
        if let rule = modifiers?.readonly {
            return ConditionEvaluator.matches(rule, values: values)
        }

        return readonly == true
    }

    func isRequired(in values: RecordData) -> Bool {
        if let rule = modifiers?.required {
            return ConditionEvaluator.matches(rule, values: values)
        }

        return required == true
    }
}

extension ActionButton {
    func isInvisible(in values: RecordData) -> Bool {
        if let rule = modifiers?.invisible {
            return ConditionEvaluator.matches(rule, values: values)
        }

        guard let invisible else { return false }
        return ConditionEvaluator.matches(invisible, values: values)
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        Array(Set(self))
    }
}