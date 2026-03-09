import Foundation
import Observation

@MainActor
@Observable
final class FormDraft {
    private var storage: RecordData
    private var editVersion = 0
    private var fieldEditVersions: [String: Int] = [:]

    init(record: RecordData) {
        storage = record
    }

    var values: RecordData {
        storage
    }

    var editVersions: [String: Int] {
        fieldEditVersions
    }

    func value(for fieldName: String, fallback: JSONValue?) -> JSONValue? {
        storage[fieldName] ?? fallback
    }

    func setValue(_ value: JSONValue?, for fieldName: String) {
        setValue(value, for: fieldName, markEdited: true)
    }

    func setValue(_ value: JSONValue?, for fieldName: String, markEdited: Bool) {
        storage[fieldName] = value ?? .null

        guard markEdited else { return }

        editVersion += 1
        fieldEditVersions[fieldName] = editVersion
    }

    func changedValues(comparedTo baseline: RecordData, fields: [FieldSchema]) -> RecordData {
        fields.reduce(into: RecordData()) { result, field in
            let currentRawValue = value(for: field.name, fallback: baseline[field.name])

            if field.type == .one2many {
                let current = comparableValue(for: field, value: currentRawValue)
                let original = comparableValue(for: field, value: baseline[field.name])

                guard current != original else { return }
                guard let mutationValue = one2ManyMutationValue(for: field, currentValue: currentRawValue, baselineValue: baseline[field.name]) else {
                    return
                }

                result[field.name] = mutationValue
                return
            }

            let current = comparableValue(for: field, value: currentRawValue)
            let original = comparableValue(for: field, value: baseline[field.name])

            guard current != original else { return }
            result[field.name] = mutationValue(for: field, value: currentRawValue) ?? .null
        }
    }

    func isDirty(comparedTo baseline: RecordData, fields: [FieldSchema]) -> Bool {
        !changedValues(comparedTo: baseline, fields: fields).isEmpty
    }

    func onchangeValues(comparedTo baseline: RecordData, fields: [FieldSchema]) -> RecordData {
        fields.reduce(into: RecordData()) { result, field in
            let currentRawValue = value(for: field.name, fallback: baseline[field.name])

            guard currentRawValue != nil else { return }

            result[field.name] = mutationValue(for: field, value: currentRawValue) ?? .null
        }
    }

    @discardableResult
    func mergeOnchangeValues(
        _ values: RecordData,
        fieldsByName: [String: FieldSchema],
        protectingEditsAfter protectedVersions: [String: Int]
    ) -> [String] {
        var mergedFields: [String] = []

        for (fieldName, serverValue) in values {
            let protectedVersion = protectedVersions[fieldName] ?? 0
            let currentVersion = fieldEditVersions[fieldName] ?? 0

            guard currentVersion <= protectedVersion else { continue }

            let field = fieldsByName[fieldName]
            guard field?.onchange?.mergeReturnedValue != false else { continue }

            let normalizedValue = normalizedOnchangeValue(serverValue, for: field, existingValue: storage[fieldName])
            guard storage[fieldName] != normalizedValue else { continue }

            storage[fieldName] = normalizedValue
            mergedFields.append(fieldName)
        }

        return mergedFields.sorted()
    }

    func validationErrors(for fields: [FieldSchema]) -> [String: String] {
        fields.reduce(into: [String: String]()) { errors, field in
            let normalizedValue = comparableValue(for: field, value: value(for: field.name, fallback: nil))

            switch field.type {
            case .integer:
                if let rawValue = value(for: field.name, fallback: nil),
                   !rawValue.isVisuallyEmpty,
                   normalizedValue == nil {
                    errors[field.name] = "\(field.label) must be a whole number."
                    return
                }
            case .float, .monetary:
                if let rawValue = value(for: field.name, fallback: nil),
                   !rawValue.isVisuallyEmpty,
                   normalizedValue == nil {
                    errors[field.name] = "\(field.label) must be a number."
                    return
                }
            case .date:
                if let rawValue = value(for: field.name, fallback: nil),
                   !rawValue.isVisuallyEmpty,
                   normalizedValue == nil {
                    errors[field.name] = "\(field.label) must use YYYY-MM-DD."
                    return
                }
            case .datetime:
                if let rawValue = value(for: field.name, fallback: nil),
                   !rawValue.isVisuallyEmpty,
                   normalizedValue == nil {
                    errors[field.name] = "\(field.label) must use YYYY-MM-DD HH:MM format."
                    return
                }
            default:
                break
            }

            guard field.isRequired(in: storage) else { return }

            switch field.type {
            case .char, .text, .selection:
                let trimmed = value(for: field.name, fallback: nil)?.stringValue?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed?.isEmpty != false {
                    errors[field.name] = "\(field.label) is required."
                }
            case .integer, .float, .monetary, .date, .datetime:
                if normalizedValue == nil {
                    errors[field.name] = "\(field.label) is required."
                }
            case .many2one:
                if normalizedValue == nil {
                    errors[field.name] = "\(field.label) is required."
                }
            case .many2many:
                if manyRelationIDs(from: value(for: field.name, fallback: nil)).isEmpty {
                    errors[field.name] = "\(field.label) is required."
                }
            case .one2many:
                if normalizedOne2ManyLines(for: field, from: value(for: field.name, fallback: nil)).isEmpty {
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
        case .integer:
            return normalizedIntegerValue(from: value)
        case .float, .monetary:
            return normalizedFloatValue(from: value)
        case .date:
            return normalizedDateValue(from: value)
        case .datetime:
            return normalizedDateTimeValue(from: value)
        case .many2one:
            guard let relationID = value.relationID else { return nil }
            return .number(Double(relationID))
        case .one2many:
            return .array(normalizedOne2ManyLines(for: field, from: value).map(encodeOne2ManyComparableLine))
        case .many2many:
            return .array(manyRelationIDs(from: value).sorted().map { .number(Double($0)) })
        default:
            return value
        }
    }

    private func mutationValue(for field: FieldSchema, value: JSONValue?) -> JSONValue? {
        switch field.type {
        case .integer:
            return normalizedIntegerValue(from: value)
        case .float, .monetary:
            return normalizedFloatValue(from: value)
        case .date:
            return normalizedDateValue(from: value)
        case .datetime:
            return normalizedDateTimeValue(from: value)
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

    private func normalizedOnchangeValue(
        _ value: JSONValue,
        for field: FieldSchema?,
        existingValue: JSONValue?
    ) -> JSONValue {
        guard let field else { return value }

        switch field.type {
        case .many2one:
            return normalizedMany2OneOnchangeValue(value, existingValue: existingValue)
        case .many2many:
            return normalizedMany2ManyOnchangeValue(value, existingValue: existingValue)
        default:
            return value
        }
    }

    private func normalizedMany2OneOnchangeValue(_ value: JSONValue, existingValue: JSONValue?) -> JSONValue {
        if let relation = value.relationValue {
            return .relation(id: relation.id, label: relation.label)
        }

        guard let relationID = value.relationID else { return value }

        if existingValue?.relationID == relationID, let existingValue {
            return existingValue
        }

        return .relation(id: relationID, label: "Record #\(relationID)")
    }

    private func normalizedMany2ManyOnchangeValue(_ value: JSONValue, existingValue: JSONValue?) -> JSONValue {
        guard case .array(let rawValues) = value else {
            return value == .null ? .array([]) : value
        }

        let existingLabels = Dictionary(uniqueKeysWithValues: (existingValue?.relationValues ?? []).map { ($0.id, $0.label) })
        let relationValues = rawValues.compactMap { rawValue -> JSONValue? in
            if let relation = rawValue.relationValue {
                return .relation(id: relation.id, label: relation.label)
            }

            guard let relationID = rawValue.relationID else { return nil }
            let label = existingLabels[relationID] ?? "Record #\(relationID)"
            return .relation(id: relationID, label: label)
        }

        return relationValues.isEmpty ? value : .array(relationValues)
    }

    private func manyRelationIDs(from value: JSONValue?) -> [Int] {
        guard let value else { return [] }
        return Array(Set(value.relationValues.map(\.id))).sorted()
    }

    private func one2ManyMutationValue(
        for field: FieldSchema,
        currentValue: JSONValue?,
        baselineValue: JSONValue?
    ) -> JSONValue? {
        let currentLines = normalizedOne2ManyLines(for: field, from: currentValue)
        let baselineLines = normalizedOne2ManyLines(for: field, from: baselineValue)
        var commands: [JSONValue] = []

        let currentIDs = Set(currentLines.compactMap(\.id))

        for line in baselineLines {
            guard let id = line.id, !currentIDs.contains(id) else { continue }
            commands.append(.array([.number(2), .number(Double(id)), .bool(false)]))
        }

        let baselineByID = Dictionary(uniqueKeysWithValues: baselineLines.compactMap { line in
            line.id.map { ($0, line.values) }
        })

        for line in currentLines {
            if let id = line.id {
                let baselineValues = baselineByID[id] ?? [:]
                guard line.values != baselineValues else { continue }
                commands.append(.array([.number(1), .number(Double(id)), .object(line.values)]))
                continue
            }

            guard !line.values.isEmpty else { continue }
            commands.append(.array([.number(0), .number(0), .object(line.values)]))
        }

        return commands.isEmpty ? nil : .array(commands)
    }

    private func normalizedOne2ManyLines(for field: FieldSchema, from value: JSONValue?) -> [One2ManyComparableLine] {
        guard case .array(let rawLines)? = value else { return [] }

        return rawLines.compactMap { rawLine in
            switch rawLine {
            case .number(let id):
                return One2ManyComparableLine(id: Int(id), values: [:])
            case .array(let relation) where relation.count == 2:
                return relation.first?.intValue.map { One2ManyComparableLine(id: $0, values: [:]) }
            case .object(let rawValues):
                var mutableValues = rawValues
                let id = mutableValues.removeValue(forKey: "id")?.intValue
                let normalizedValues = normalizedOne2ManyLineValues(subfields: field.subfields ?? [], rawValues: mutableValues)

                if id == nil && normalizedValues.isEmpty {
                    return nil
                }

                return One2ManyComparableLine(id: id, values: normalizedValues)
            default:
                return nil
            }
        }
    }

    private func normalizedOne2ManyLineValues(subfields: [FieldSchema], rawValues: RecordData) -> RecordData {
        subfields.reduce(into: RecordData()) { result, subfield in
            let hasExplicitValue = rawValues.keys.contains(subfield.name)
            let normalizedValue = mutationValue(for: subfield, value: rawValues[subfield.name])

            if let normalizedValue {
                result[subfield.name] = normalizedValue
            } else if hasExplicitValue {
                result[subfield.name] = .null
            }
        }
    }

    private func encodeOne2ManyComparableLine(_ line: One2ManyComparableLine) -> JSONValue {
        if let id = line.id, line.values.isEmpty {
            return .number(Double(id))
        }

        var object = line.values
        if let id = line.id {
            object["id"] = .number(Double(id))
        }

        return .object(object)
    }

    private struct One2ManyComparableLine: Equatable {
        let id: Int?
        let values: RecordData
    }

    private func normalizedIntegerValue(from value: JSONValue?) -> JSONValue? {
        switch value {
        case .number(let number):
            return .number(Double(Int(number)))
        case .string(let rawString):
            let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let number = Int(trimmed) else { return nil }
            return .number(Double(number))
        case .null, nil:
            return nil
        default:
            return nil
        }
    }

    private func normalizedFloatValue(from value: JSONValue?) -> JSONValue? {
        switch value {
        case .number(let number):
            return .number(number)
        case .string(let rawString):
            let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let number = Double(trimmed) else { return nil }
            return .number(number)
        case .null, nil:
            return nil
        default:
            return nil
        }
    }

    private func normalizedDateValue(from value: JSONValue?) -> JSONValue? {
        normalizedTemporalValue(from: value, type: .date)
    }

    private func normalizedDateTimeValue(from value: JSONValue?) -> JSONValue? {
        normalizedTemporalValue(from: value, type: .datetime)
    }

    private func normalizedTemporalValue(from value: JSONValue?, type: FieldType) -> JSONValue? {
        guard case .string(let rawString)? = value else {
            return value == nil || value == .null ? nil : nil
        }

        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        switch type {
        case .date:
            guard let date = Self.dateFormatter.date(from: trimmed) else { return nil }
            return .string(Self.dateFormatter.string(from: date))
        case .datetime:
            guard let date = Self.parseDateTime(trimmed) else { return nil }
            return .string(Self.dateTimeFormatter.string(from: date))
        default:
            return nil
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let shortDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static func parseDateTime(_ value: String) -> Date? {
        if let date = dateTimeFormatter.date(from: value) {
            return date
        }

        if let date = shortDateTimeFormatter.date(from: value) {
            return date
        }

        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }

        return nil
    }
}