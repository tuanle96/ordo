import Foundation

struct LoginRequest: Encodable {
    let odooUrl: String
    let db: String
    let login: String
    let password: String
}

struct RefreshTokenRequest: Encodable {
    let refreshToken: String
}

struct LoginDraft: Equatable {
    var backendBaseURL: String
    var odooURL: String
    var database: String
    var username: String
    var password: String
}

struct AuthUser: Codable, Hashable {
    let id: Int
    let name: String
    let email: String?
    let lang: String
    let tz: String?
    let avatarUrl: String?
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: AuthUser
}

struct AuthenticatedPrincipal: Codable, Hashable {
    let uid: Int
    let db: String
    let odooUrl: String
    let version: String
    let lang: String
    let groups: [Int]
    let name: String
    let email: String?
    let tz: String?
}

extension AuthUser {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case lang
        case tz
        case avatarUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decodeLossyOptionalString(forKey: .email)
        lang = try container.decode(String.self, forKey: .lang)
        tz = try container.decodeLossyOptionalString(forKey: .tz)
        avatarUrl = try container.decodeLossyOptionalString(forKey: .avatarUrl)
    }
}

extension AuthenticatedPrincipal {
    private enum CodingKeys: String, CodingKey {
        case uid
        case db
        case odooUrl
        case version
        case lang
        case groups
        case name
        case email
        case tz
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(Int.self, forKey: .uid)
        db = try container.decode(String.self, forKey: .db)
        odooUrl = try container.decode(String.self, forKey: .odooUrl)
        version = try container.decode(String.self, forKey: .version)
        lang = try container.decode(String.self, forKey: .lang)
        groups = try container.decode([Int].self, forKey: .groups)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decodeLossyOptionalString(forKey: .email)
        tz = try container.decodeLossyOptionalString(forKey: .tz)
    }
}

struct StoredSession: Codable, Hashable {
    let backendBaseURL: URL
    let odooURL: String
    let database: String
    let login: String
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let user: AuthUser
}

extension StoredSession {
    static let preview = StoredSession(
        backendBaseURL: URL(string: AppConfig.fallbackBaseURL)!,
        odooURL: "http://127.0.0.1:38421",
        database: "odoo17",
        login: "admin",
        accessToken: "preview-access",
        refreshToken: "preview-refresh",
        expiresAt: .now.addingTimeInterval(3600),
        user: AuthUser(id: 2, name: "Mitchell Admin", email: "admin@example.com", lang: "en_US", tz: "UTC", avatarUrl: nil)
    )
}

extension AuthenticatedPrincipal {
    static let preview = AuthenticatedPrincipal(
        uid: 2,
        db: "odoo17",
        odooUrl: "http://127.0.0.1:38421",
        version: "17.0",
        lang: "en_US",
        groups: [1],
        name: "Mitchell Admin",
        email: "admin@example.com",
        tz: "UTC"
    )
}

private extension KeyedDecodingContainer {
    func decodeLossyOptionalString(forKey key: Key) throws -> String? {
        let stringValue = try? decodeIfPresent(String.self, forKey: key)
        if let value = stringValue ?? nil {
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedValue.isEmpty ? nil : trimmedValue
        }

        let boolValue = try? decodeIfPresent(Bool.self, forKey: key)
        if boolValue != nil {
            return nil
        }

        return nil
    }
}
