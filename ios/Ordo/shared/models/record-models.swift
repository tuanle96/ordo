import Foundation

typealias RecordData = [String: JSONValue]

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
