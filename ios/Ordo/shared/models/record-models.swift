import Foundation

typealias RecordData = [String: JSONValue]

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
