import Foundation

enum ListColumnOptionalVisibility: String, Codable, Hashable {
    case show
    case hide
}

struct ListColumn: Codable, Hashable, Identifiable {
    let name: String
    let type: FieldType
    let label: String
    let comodel: String?
    let selection: [[String]]?
    let widget: String?
    let optional: ListColumnOptionalVisibility?
    let columnInvisible: Bool?

    var id: String { name }

    var isVisibleByDefault: Bool {
        columnInvisible != true && optional != .hide
    }
}

struct SearchFilter: Codable, Hashable, Identifiable {
    let name: String
    let label: String
    let domain: String

    var id: String { name }

    var domainValue: JSONValue? {
        JSONValue.decoded(fromJSONString: domain)
    }
}

struct SearchGroupBy: Codable, Hashable, Identifiable {
    let name: String
    let label: String
    let fieldName: String

    var id: String { name }
}

struct SearchField: Codable, Hashable, Identifiable {
    let name: String
    let label: String
    let type: FieldType
    let filterDomain: String?
    let selection: [[String]]?

    var id: String { name }
}

struct MobileListSchema: Codable, Hashable {
    struct SearchMetadata: Codable, Hashable {
        let fields: [SearchField]
        let filters: [SearchFilter]
        let groupBy: [SearchGroupBy]
    }

    let model: String
    let title: String
    let columns: [ListColumn]
    let defaultOrder: String?
    let search: SearchMetadata

    var visibleColumns: [ListColumn] {
        columns.filter(\.isVisibleByDefault)
    }

    var requestedFieldNames: [String] {
        let fieldNames = visibleColumns.isEmpty ? columns.map(\.name) : visibleColumns.map(\.name)
        return orderedUnique(["id", "display_name", "name"] + fieldNames)
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

extension JSONValue {
    static func decoded(fromJSONString value: String) -> JSONValue? {
        guard let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(JSONValue.self, from: data)
    }
}