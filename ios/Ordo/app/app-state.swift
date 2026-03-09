import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    enum Phase {
        case launching
        case login
        case authenticated
    }

    private(set) var phase: Phase = .launching
    private(set) var session: StoredSession?
    private(set) var currentPrincipal: AuthenticatedPrincipal?
    private(set) var installedModuleNames: Set<String> = []
    private(set) var pendingMutationCount = 0
    var statusMessage: String?

    let config: AppConfig
    let sessionStore: SessionStoring
    let apiClient: APIClient
    let cacheStore: CacheStoring
    let mutationQueueStore: MutationQueueStoring

    private var hasAttemptedRestore = false
    private var refreshTask: Task<Void, Error>?
    private let sessionRefreshLeadTime: TimeInterval = 60

    init(
        config: AppConfig,
        sessionStore: SessionStoring,
        apiClient: APIClient,
        cacheStore: CacheStoring,
        mutationQueueStore: MutationQueueStoring = FileMutationQueueStore()
    ) {
        self.config = config
        self.sessionStore = sessionStore
        self.apiClient = apiClient
        self.cacheStore = cacheStore
        self.mutationQueueStore = mutationQueueStore
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

    var availableModels: [ModelDescriptor] {
        installedModuleNames.isEmpty
            ? ModelRegistry.supported
            : ModelRegistry.available(installedModules: installedModuleNames)
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
            currentPrincipal = try await withAuthenticatedToken { [self] token in
                try await self.apiClient.me(token: token)
            }
            await fetchInstalledModules()
            phase = .authenticated
            await refreshPendingMutationCount()
            await replayPendingMutations()
        } catch {
            try? sessionStore.clear()
            session = nil
            currentPrincipal = nil
            pendingMutationCount = 0
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
        await fetchInstalledModules()
        phase = .authenticated
        await refreshPendingMutationCount()
        await replayPendingMutations()
    }

    func withAuthenticatedToken<T>(_ operation: @escaping (String) async throws -> T) async throws -> T {
        guard session != nil else {
            throw APIClientError.unauthorized
        }

        do {
            try await ensureFreshSession()
        } catch {
            signOut()
            throw APIClientError.unauthorized
        }

        guard let accessToken = session?.accessToken else {
            throw APIClientError.unauthorized
        }

        do {
            return try await operation(accessToken)
        } catch {
            guard case APIClientError.unauthorized = error else {
                throw error
            }

            do {
                try await refreshSession(force: true)
            } catch {
                signOut()
                throw APIClientError.unauthorized
            }

            guard let refreshedAccessToken = session?.accessToken else {
                signOut()
                throw APIClientError.unauthorized
            }

            do {
                return try await operation(refreshedAccessToken)
            } catch {
                if case APIClientError.unauthorized = error {
                    signOut()
                }
                throw error
            }
        }
    }

    func signOut() {
        try? sessionStore.clear()
        session = nil
        currentPrincipal = nil
        installedModuleNames = []
        pendingMutationCount = 0
        phase = .login
        statusMessage = nil
        refreshTask = nil
    }

    func logout() async {
        guard session != nil else {
            signOut()
            return
        }

        do {
            _ = try await withAuthenticatedToken { [self] token in
                try await self.apiClient.logout(token: token)
            }
            signOut()
        } catch {
            if case APIClientError.unauthorized = error {
                signOut()
                return
            }

            signOut()
            self.statusMessage = "Signed out locally, but the server logout could not be confirmed."
        }
    }

    func clearCache() async throws {
        try await cacheStore.clear(scope: cacheScope)
    }

    func enqueuePendingMutation(_ mutation: QueuedRecordMutation) async throws {
        guard let scope = cacheScope else {
            throw APIClientError.unauthorized
        }

        try await mutationQueueStore.enqueue(mutation, scope: scope)
        await refreshPendingMutationCount()
        statusMessage = pendingMutationCount == 1 ? "1 change is pending sync." : "\(pendingMutationCount) changes are pending sync."
    }

    func replayPendingMutations() async {
        guard let scope = cacheScope, phase == .authenticated else { return }

        let queuedMutations = await mutationQueueStore.load(scope: scope)
        guard !queuedMutations.isEmpty else {
            pendingMutationCount = 0
            return
        }

        var replayedCount = 0

        for mutation in queuedMutations {
            do {
                try await replay(mutation, scope: scope)
                try await mutationQueueStore.remove(id: mutation.id, scope: scope)
                replayedCount += 1
            } catch {
                guard case APIClientError.unauthorized = error else {
                    var failedMutation = mutation
                    failedMutation.retryCount += 1
                    failedMutation.lastError = error.localizedDescription
                    try? await mutationQueueStore.update(failedMutation, scope: scope)
                    continue
                }

                break
            }
        }

        await refreshPendingMutationCount()

        if replayedCount > 0 {
            statusMessage = pendingMutationCount == 0
                ? "Synced \(replayedCount) pending change\(replayedCount == 1 ? "" : "s")."
                : "Synced \(replayedCount) pending change\(replayedCount == 1 ? "" : "s"). \(pendingMutationCount) still pending."
        } else if pendingMutationCount > 0 {
            statusMessage = pendingMutationCount == 1 ? "1 change is pending sync." : "\(pendingMutationCount) changes are pending sync."
        }
    }

    private func fetchInstalledModules() async {
        do {
            let response = try await withAuthenticatedToken { [self] token in
                try await self.apiClient.installedModules(token: token)
            }
            installedModuleNames = Set(response.modules.map(\.name))
        } catch {
            // Graceful degradation: show all models if module check fails
            installedModuleNames = []
        }
    }

    private func ensureFreshSession() async throws {
        guard let session else {
            throw APIClientError.unauthorized
        }

        guard session.expiresAt.timeIntervalSinceNow <= sessionRefreshLeadTime else {
            return
        }

        try await refreshSession(force: true)
    }

    private func refreshSession(force: Bool) async throws {
        guard session != nil else {
            throw APIClientError.unauthorized
        }

        if !force, let session, session.expiresAt.timeIntervalSinceNow > sessionRefreshLeadTime {
            return
        }

        if let refreshTask {
            return try await refreshTask.value
        }

        let task = Task { @MainActor in
            guard let currentSession = self.session else {
                throw APIClientError.unauthorized
            }

            let tokenResponse = try await self.apiClient.refresh(
                request: RefreshTokenRequest(refreshToken: currentSession.refreshToken)
            )

            let updatedSession = StoredSession(
                backendBaseURL: currentSession.backendBaseURL,
                odooURL: currentSession.odooURL,
                database: currentSession.database,
                login: currentSession.login,
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
                user: tokenResponse.user
            )

            try self.sessionStore.save(updatedSession)
            self.session = updatedSession
            if self.pendingMutationCount == 0 {
                self.statusMessage = nil
            }
        }

        refreshTask = task
        defer { refreshTask = nil }
        try await task.value
    }

    private func refreshPendingMutationCount() async {
        pendingMutationCount = await mutationQueueStore.pendingCount(scope: cacheScope)
    }

    private func replay(_ mutation: QueuedRecordMutation, scope: CacheScope) async throws {
        switch mutation.kind {
        case .update:
            let result = try await withAuthenticatedToken { [self] token in
                try await self.apiClient.updateRecord(
                    model: mutation.model,
                    id: mutation.recordID,
                    values: mutation.values,
                    fields: mutation.fields,
                    token: token
                )
            }

            try await cacheStore.saveRecord(result.record, for: mutation.model, id: mutation.recordID, scope: scope)
        case .delete:
            _ = try await withAuthenticatedToken { [self] token in
                try await self.apiClient.deleteRecord(model: mutation.model, id: mutation.recordID, token: token)
            }

            try await cacheStore.deleteRecord(for: mutation.model, id: mutation.recordID, scope: scope)
        case .action:
            let actionName = mutation.actionName ?? ""
            let result = try await withAuthenticatedToken { [self] token in
                try await self.apiClient.runRecordAction(
                    model: mutation.model,
                    id: mutation.recordID,
                    actionName: actionName,
                    fields: mutation.fields,
                    token: token
                )
            }

            let record: RecordData
            if let updatedRecord = result.record {
                record = updatedRecord
            } else {
                record = try await withAuthenticatedToken { [self] token in
                    try await self.apiClient.record(
                        model: mutation.model,
                        id: mutation.recordID,
                        fields: mutation.fields,
                        token: token
                    )
                }
            }

            try await cacheStore.saveRecord(record, for: mutation.model, id: mutation.recordID, scope: scope)
        }
    }
}

extension AppState {
    static func live() -> AppState {
        let config = AppConfig.load()
        return AppState(
            config: config,
            sessionStore: KeychainSessionStore(),
            apiClient: APIClient(baseURL: config.defaultBaseURL),
            cacheStore: FileCacheStore(),
            mutationQueueStore: FileMutationQueueStore()
        )
    }

    static let preview: AppState = {
        let state = AppState(
            config: .preview,
            sessionStore: InMemorySessionStore(),
            apiClient: APIClient(baseURL: AppConfig.preview.defaultBaseURL),
            cacheStore: FileCacheStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: "OrdoPreviewCache", directoryHint: .isDirectory)),
            mutationQueueStore: FileMutationQueueStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: "OrdoPreviewMutationQueue", directoryHint: .isDirectory))
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
