import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class RecordChatterViewModel {
    private static let logger = Logger(subsystem: "com.ordo.app", category: "record-chatter")

    private(set) var messages: [ChatterMessage] = []
    private(set) var errorMessage: String?
    private(set) var isLoading = false
    private(set) var isPosting = false
    private(set) var hasLoaded = false
    private(set) var hasMore = false
    private(set) var nextBefore: Int?
    var draftBody = ""

    let model: String
    let recordID: Int

    init(model: String, recordID: Int) {
        self.model = model
        self.recordID = recordID
    }

    func loadIfNeeded(using appState: AppState) async {
        guard !hasLoaded else { return }
        await refresh(using: appState)
    }

    func refresh(using appState: AppState) async {
        guard appState.session?.accessToken != nil else {
            errorMessage = "Sign in again to load chatter."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await appState.withAuthenticatedToken { token in
                try await appState.apiClient.chatter(model: self.model, id: self.recordID, before: nil, token: token)
            }
            messages = result.messages
            hasMore = result.hasMore
            nextBefore = result.nextBefore
            hasLoaded = true
        } catch {
            Self.logger.error("Failed to load chatter for \(self.model, privacy: .public)#\(self.recordID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            if case APIClientError.unauthorized = error {
                appState.signOut()
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadMore(using appState: AppState) async {
        guard !isLoading, hasMore, let nextBefore else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await appState.withAuthenticatedToken { token in
                try await appState.apiClient.chatter(model: self.model, id: self.recordID, before: nextBefore, token: token)
            }
            messages.append(contentsOf: result.messages)
            hasMore = result.hasMore
            self.nextBefore = result.nextBefore
            hasLoaded = true
        } catch {
            Self.logger.error("Failed to load more chatter for \(self.model, privacy: .public)#\(self.recordID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            if case APIClientError.unauthorized = error {
                appState.signOut()
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func postNote(using appState: AppState) async -> Bool {
        let body = draftBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            errorMessage = "Enter a note before posting."
            return false
        }

        isPosting = true
        errorMessage = nil
        defer { isPosting = false }

        do {
            let message = try await appState.withAuthenticatedToken { token in
                try await appState.apiClient.postChatterNote(model: self.model, id: self.recordID, body: body, token: token)
            }
            messages.insert(message, at: 0)
            draftBody = ""
            hasLoaded = true
            return true
        } catch {
            Self.logger.error("Failed to post chatter note for \(self.model, privacy: .public)#\(self.recordID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            if case APIClientError.unauthorized = error {
                appState.signOut()
            } else {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }
}