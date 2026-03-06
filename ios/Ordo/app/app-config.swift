import Foundation

struct AppConfig {
    static let fallbackBaseURL = "http://127.0.0.1:3000/api/v1/mobile"

    let defaultBaseURL: URL

    static func load() -> AppConfig {
        let configuredURL = ProcessInfo.processInfo.environment["ORDO_API_BASE_URL"]
            ?? Bundle.main.object(forInfoDictionaryKey: "ORDO_API_BASE_URL") as? String
            ?? fallbackBaseURL

        return AppConfig(
            defaultBaseURL: URL(string: normalizedURLString(configuredURL))
                ?? URL(string: fallbackBaseURL)!
        )
    }

    static let preview = AppConfig(defaultBaseURL: URL(string: fallbackBaseURL)!)

    func resolveBackendURL(from rawValue: String) throws -> URL {
        let normalized = Self.normalizedURLString(rawValue)

        guard let url = URL(string: normalized), let scheme = url.scheme, ["http", "https"].contains(scheme) else {
            throw AppConfigError.invalidBackendURL
        }

        return url
    }

    private static func normalizedURLString(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

enum AppConfigError: LocalizedError {
    case invalidBackendURL

    var errorDescription: String? {
        switch self {
        case .invalidBackendURL:
            return "Enter a valid backend URL using http or https."
        }
    }
}
