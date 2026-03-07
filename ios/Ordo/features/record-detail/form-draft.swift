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
}