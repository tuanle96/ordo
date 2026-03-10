import Foundation

typealias RecordData = [String: JSONValue]

struct OnchangeRequest: Codable, Sendable {
    let values: RecordData
    let triggerField: String
    let recordId: Int?
    let fields: [String]?
}

struct OnchangeWarning: Codable, Hashable, Sendable {
    let title: String
    let message: String
    let type: String?
}

struct OnchangeResult: Codable, Sendable {
    let values: RecordData
    let warnings: [OnchangeWarning]?
    let domains: [String: JSONValue]?
}

struct RecordMutationRequest: Codable, Sendable {
    let values: RecordData
    let fields: [String]?
}

struct RecordActionRequest: Codable, Sendable {
    let fields: [String]?
}

struct RecordMutationResult: Codable, Sendable {
    let id: Int
    let record: RecordData
}

struct RecordDeleteResult: Codable, Sendable {
    let id: Int
    let deleted: Bool
}

struct RecordActionResult: Codable, Sendable {
    let id: Int
    let changed: Bool
    let record: RecordData?
}

struct RecordListResult: Codable, Sendable {
    let items: [RecordData]
    let limit: Int
    let offset: Int
    let total: Int
}

struct NameSearchResult: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
}

struct RecordRowSummary: Identifiable, Hashable {
    let id: Int
    let title: String
    let subtitle: String?
    let footnote: String?
}
