import Foundation
import Observation

@MainActor
@Observable
final class FormDraft {
    private var storage: RecordData

    init(record: RecordData) {
        storage = record
    }

    var values: RecordData {
        storage
    }

    func value(for fieldName: String, fallback: JSONValue?) -> JSONValue? {
        storage[fieldName] ?? fallback
    }

    func setValue(_ value: JSONValue?, for fieldName: String) {
        storage[fieldName] = value ?? .null
    }

    func changedValues(comparedTo baseline: RecordData, fields: [FieldSchema]) -> RecordData {
        fields.reduce(into: RecordData()) { result, field in
            let currentRawValue = value(for: field.name, fallback: baseline[field.name])
            let current = comparableValue(for: field, value: currentRawValue)
            let original = comparableValue(for: field, value: baseline[field.name])

            guard current != original else { return }
            result[field.name] = mutationValue(for: field, value: currentRawValue) ?? .null
        }
    }

    func isDirty(comparedTo baseline: RecordData, fields: [FieldSchema]) -> Bool {
        !changedValues(comparedTo: baseline, fields: fields).isEmpty
    }

    func validationErrors(for fields: [FieldSchema]) -> [String: String] {
        fields.reduce(into: [String: String]()) { errors, field in
            guard field.isRequired(in: storage) else { return }

            switch field.type {
            case .char, .text, .selection:
                let trimmed = value(for: field.name, fallback: nil)?.stringValue?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed?.isEmpty != false {
                    errors[field.name] = "\(field.label) is required."
                }
            case .many2one:
                if comparableValue(for: field, value: value(for: field.name, fallback: nil)) == nil {
                    errors[field.name] = "\(field.label) is required."
                }
            case .many2many:
                if manyRelationIDs(from: value(for: field.name, fallback: nil)).isEmpty {
                    errors[field.name] = "\(field.label) is required."
                }
            case .boolean:
                break
            default:
                break
            }
        }
    }

    private func comparableValue(for field: FieldSchema, value: JSONValue?) -> JSONValue? {
        guard let value else {
            return field.type == .many2many ? .array([]) : nil
        }

        switch field.type {
        case .many2one:
            guard let relationID = value.relationID else { return nil }
            return .number(Double(relationID))
        case .many2many:
            return .array(manyRelationIDs(from: value).sorted().map { .number(Double($0)) })
        default:
            return value
        }
    }

    private func mutationValue(for field: FieldSchema, value: JSONValue?) -> JSONValue? {
        switch field.type {
        case .many2one:
            guard let relationID = value?.relationID else { return nil }
            return .number(Double(relationID))
        case .many2many:
            let ids = manyRelationIDs(from: value).sorted().map { JSONValue.number(Double($0)) }
            return .array([.array([.number(6), .number(0), .array(ids)])])
        default:
            return value
        }
    }

    private func manyRelationIDs(from value: JSONValue?) -> [Int] {
        guard let value else { return [] }
        return Array(Set(value.relationValues.map(\.id))).sorted()
    }
}