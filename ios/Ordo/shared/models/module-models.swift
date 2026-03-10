import Foundation

struct InstalledModuleInfo: Codable, Hashable {
    let name: String
    let displayName: String
}

struct BrowseModelInfo: Codable, Hashable {
    let model: String
    let title: String
}

struct InstalledModulesResponse: Codable {
    let modules: [InstalledModuleInfo]
    let browseModels: [BrowseModelInfo]

    init(modules: [InstalledModuleInfo], browseModels: [BrowseModelInfo] = []) {
        self.modules = modules
        self.browseModels = browseModels
    }

    private enum CodingKeys: String, CodingKey {
        case modules
        case browseModels
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modules = try container.decodeIfPresent([InstalledModuleInfo].self, forKey: .modules) ?? []
        browseModels = try container.decodeIfPresent([BrowseModelInfo].self, forKey: .browseModels) ?? []
    }
}
