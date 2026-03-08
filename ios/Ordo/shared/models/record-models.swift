import Foundation

typealias RecordData = [String: JSONValue]

struct OnchangeRequest: Codable {
    let values: RecordData
    let triggerField: String
    let recordId: Int?
    let fields: [String]?
}

struct OnchangeWarning: Codable, Hashable {
    let title: String
    let message: String
    let type: String?
}

struct OnchangeResult: Codable {
    let values: RecordData
    let warnings: [OnchangeWarning]?
    let domains: [String: JSONValue]?
}

struct RecordMutationRequest: Codable {
    let values: RecordData
    let fields: [String]?
}

struct RecordMutationResult: Codable {
    let id: Int
    let record: RecordData
}

struct RecordDeleteResult: Codable {
    let id: Int
    let deleted: Bool
}

struct RecordActionResult: Codable {
    let id: Int
    let changed: Bool
    let record: RecordData?
}

struct RecordListResult: Codable {
    let items: [RecordData]
    let limit: Int
    let offset: Int
}

struct NameSearchResult: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct RecordRowSummary: Identifiable, Hashable {
    let id: Int
    let title: String
    let subtitle: String?
    let footnote: String?
}
