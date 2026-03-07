import Combine
import Foundation

@MainActor
final class FormDraft: ObservableObject {
    @Published private var storage: RecordData

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
        storage[fieldName] = value
    }

    func changedValues(comparedTo baseline: RecordData, fields: [FieldSchema]) -> RecordData {
        fields.reduce(into: RecordData()) { result, field in
            let current = value(for: field.name, fallback: baseline[field.name])
            let original = baseline[field.name]

            guard current != original else { return }
            result[field.name] = current ?? .null
        }
    }

    func isDirty(comparedTo baseline: RecordData, fields: [FieldSchema]) -> Bool {
        !changedValues(comparedTo: baseline, fields: fields).isEmpty
    }

    func validationErrors(for fields: [FieldSchema]) -> [String: String] {
        fields.reduce(into: [String: String]()) { errors, field in
            guard field.required == true else { return }

            switch field.type {
            case .char, .text, .selection:
                let trimmed = value(for: field.name, fallback: nil)?.stringValue?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed?.isEmpty != false {
                    errors[field.name] = "\(field.label) is required."
                }
            case .boolean:
                break
            default:
                break
            }
        }
    }
}