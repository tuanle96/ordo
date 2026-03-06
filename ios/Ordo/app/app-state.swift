import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    enum Phase {
        case launching
        case login
        case authenticated
    }

    @Published private(set) var phase: Phase = .launching
    @Published private(set) var session: StoredSession?
    @Published private(set) var currentPrincipal: AuthenticatedPrincipal?
    @Published var statusMessage: String?

    let config: AppConfig
    let sessionStore: SessionStoring
    let apiClient: APIClient
    let cacheStore: CacheStoring

    private var hasAttemptedRestore = false

    init(config: AppConfig, sessionStore: SessionStoring, apiClient: APIClient, cacheStore: CacheStoring) {
        self.config = config
        self.sessionStore = sessionStore
        self.apiClient = apiClient
        self.cacheStore = cacheStore
    }

    var displayUserName: String {
        currentPrincipal?.name ?? session?.user.name ?? "Not signed in"
    }

    var displayEmail: String? {
        currentPrincipal?.email ?? session?.user.email
    }

    var displayVersion: String? {
        currentPrincipal?.version
    }

    var cacheScope: CacheScope? {
        guard let session else { return nil }

        let principalID = currentPrincipal?.uid ?? session.user.id
        return CacheScope(namespace: [
            session.backendBaseURL.absoluteString,
            session.odooURL,
            session.database,
            session.login,
            String(principalID),
        ].joined(separator: "|").data(using: .utf8).map { data in
            data.base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
        } ?? "default")
    }

    var loginPrefill: LoginDraft {
        LoginDraft(
            backendBaseURL: session?.backendBaseURL.absoluteString ?? config.defaultBaseURL.absoluteString,
            odooURL: session?.odooURL ?? "http://127.0.0.1:38421",
            database: session?.database ?? "odoo17",
            username: session?.login ?? "admin",
            password: ""
        )
    }

    func restoreSessionIfNeeded() async {
        guard !hasAttemptedRestore else { return }
        hasAttemptedRestore = true
        await restoreSession()
    }

    func restoreSession() async {
        do {
            guard let storedSession = try sessionStore.load() else {
                session = nil
                currentPrincipal = nil
                phase = .login
                return
            }

            session = storedSession
            apiClient.updateBaseURL(storedSession.backendBaseURL)
            currentPrincipal = try await apiClient.me(token: storedSession.accessToken)
            phase = .authenticated
            statusMessage = nil
        } catch {
            try? sessionStore.clear()
            session = nil
            currentPrincipal = nil
            phase = .login
            statusMessage = "Your saved session could not be restored. Please sign in again."
        }
    }

    func signIn(with draft: LoginDraft) async throws {
        let backendBaseURL = try config.resolveBackendURL(from: draft.backendBaseURL)
        apiClient.updateBaseURL(backendBaseURL)

        let tokenResponse = try await apiClient.login(
            request: LoginRequest(
                odooUrl: draft.odooURL,
                db: draft.database,
                login: draft.username,
                password: draft.password
            )
        )
        let principal = try await apiClient.me(token: tokenResponse.accessToken)
        let storedSession = StoredSession(
            backendBaseURL: backendBaseURL,
            odooURL: draft.odooURL,
            database: draft.database,
            login: draft.username,
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
            user: tokenResponse.user
        )

        try sessionStore.save(storedSession)

        session = storedSession
        currentPrincipal = principal
        statusMessage = nil
        phase = .authenticated
    }

    func signOut() {
        try? sessionStore.clear()
        session = nil
        currentPrincipal = nil
        phase = .login
        statusMessage = nil
    }

    func clearCache() async throws {
        try await cacheStore.clear(scope: cacheScope)
    }
}

extension AppState {
    static func live() -> AppState {
        let config = AppConfig.load()
        return AppState(
            config: config,
            sessionStore: KeychainSessionStore(),
            apiClient: APIClient(baseURL: config.defaultBaseURL),
            cacheStore: FileCacheStore()
        )
    }

    static let preview: AppState = {
        let state = AppState(
            config: .preview,
            sessionStore: InMemorySessionStore(),
            apiClient: APIClient(baseURL: AppConfig.preview.defaultBaseURL),
            cacheStore: FileCacheStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: "OrdoPreviewCache", directoryHint: .isDirectory))
        )
        state.session = .preview
        state.currentPrincipal = .preview
        state.phase = .authenticated
        return state
    }()
}

private final class InMemorySessionStore: SessionStoring {
    private var storedSession: StoredSession?

    func load() throws -> StoredSession? {
        storedSession
    }

    func save(_ session: StoredSession) throws {
        storedSession = session
    }

    func clear() throws {
        storedSession = nil
    }
}
