import Foundation

struct LoginRequest: Encodable {
    let odooUrl: String
    let db: String
    let login: String
    let password: String
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
