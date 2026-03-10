import Foundation

struct InstalledModuleInfo: Codable, Hashable {
    let name: String
    let displayName: String
}

enum BrowsePreferredViewMode: String, Codable, Hashable {
    case list
    case kanban
}

enum BrowseMenuNodeKind: String, Codable, Hashable {
    case app
    case category
    case leaf
}

struct BrowseMenuNode: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let kind: BrowseMenuNodeKind
    let model: String?
    let preferredViewMode: BrowsePreferredViewMode?
    let children: [BrowseMenuNode]

    init(
        id: Int,
        name: String,
        kind: BrowseMenuNodeKind,
        model: String?,
        preferredViewMode: BrowsePreferredViewMode? = nil,
        children: [BrowseMenuNode]
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.model = model
        self.preferredViewMode = preferredViewMode
        self.children = children
    }

    var isDirectRecordListEntry: Bool {
        children.isEmpty && model != nil
    }
}

struct InstalledModulesResponse: Codable {
    let modules: [InstalledModuleInfo]
    let browseMenuTree: [BrowseMenuNode]

    init(modules: [InstalledModuleInfo], browseMenuTree: [BrowseMenuNode] = []) {
        self.modules = modules
        self.browseMenuTree = browseMenuTree
    }

    private enum CodingKeys: String, CodingKey {
        case modules
        case browseMenuTree
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modules = try container.decodeIfPresent([InstalledModuleInfo].self, forKey: .modules) ?? []
        browseMenuTree = try container.decodeIfPresent([BrowseMenuNode].self, forKey: .browseMenuTree) ?? []
    }
}
