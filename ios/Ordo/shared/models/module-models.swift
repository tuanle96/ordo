import Foundation

struct InstalledModuleInfo: Codable, Hashable {
    let name: String
    let displayName: String
}

struct InstalledModulesResponse: Codable {
    let modules: [InstalledModuleInfo]
}
