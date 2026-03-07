import Foundation

enum ConditionEvaluator {
    static func matches(_ condition: Condition, values: RecordData) -> Bool {
        let candidates = candidateStrings(for: values[condition.field])

        switch condition.op {
        case "==":
            guard let value = condition.value else { return false }
            return compare(candidates, against: value) == .orderedSame
        case "!=":
            guard let value = condition.value else { return false }
            return compare(candidates, against: value) != .orderedSame
        case "in":
            guard let values = condition.values else { return false }
            return values.contains { compare(candidates, against: $0) == .orderedSame }
        case "not in":
            guard let values = condition.values else { return false }
            return values.allSatisfy { compare(candidates, against: $0) != .orderedSame }
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
            return []
        }
    }
}

extension FieldSchema {
    func isInvisible(in values: RecordData) -> Bool {
        guard let invisible else { return false }
        return ConditionEvaluator.matches(invisible, values: values)
    }

    var isStaticallyReadOnly: Bool {
        readonly == true
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        Array(Set(self))
    }
}