import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class RecordChatterViewModel {
    private static let logger = Logger(subsystem: "com.ordo.app", category: "record-chatter")

    private(set) var messages: [ChatterMessage] = []
    private(set) var followers: [ChatterFollower] = []
    private(set) var followersCount = 0
    private(set) var selfFollower: ChatterFollower?
    private(set) var activities: [ChatterActivity] = []
    private(set) var errorMessage: String?
    private(set) var isLoading = false
    private(set) var isPosting = false
    private(set) var isUpdatingFollow = false
    private(set) var hasLoaded = false
    private(set) var hasMore = false
    private(set) var nextBefore: Int?
    private(set) var completingActivityIDs: Set<Int> = []
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
            let payload = try await appState.withAuthenticatedToken { token in
                async let thread = appState.apiClient.chatter(model: self.model, id: self.recordID, before: nil, token: token)
                async let details = appState.apiClient.chatterDetails(model: self.model, id: self.recordID, token: token)

                return try await (thread, details)
            }

            apply(thread: payload.0, details: payload.1)
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

    var isFollowing: Bool {
        selfFollower != nil
    }

    func toggleFollowing(using appState: AppState) async -> Bool {
        guard appState.session?.accessToken != nil else {
            errorMessage = "Sign in again to manage followers."
            return false
        }

        isUpdatingFollow = true
        errorMessage = nil
        defer { isUpdatingFollow = false }

        do {
            let result = try await appState.withAuthenticatedToken { token in
                if self.isFollowing {
                    return try await appState.apiClient.unfollowRecord(model: self.model, id: self.recordID, token: token)
                }

                return try await appState.apiClient.followRecord(model: self.model, id: self.recordID, token: token)
            }

            apply(details: result)
            hasLoaded = true
            return true
        } catch {
            Self.logger.error("Failed to toggle follower state for \(self.model, privacy: .public)#\(self.recordID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            if case APIClientError.unauthorized = error {
                appState.signOut()
            } else {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }

    func completeActivity(id activityID: Int, using appState: AppState) async -> Bool {
        guard !completingActivityIDs.contains(activityID) else { return false }
        guard appState.session?.accessToken != nil else {
            errorMessage = "Sign in again to manage activities."
            return false
        }

        completingActivityIDs.insert(activityID)
        errorMessage = nil
        defer { completingActivityIDs.remove(activityID) }

        do {
            let result = try await appState.withAuthenticatedToken { token in
                try await appState.apiClient.completeChatterActivity(model: self.model, id: self.recordID, activityId: activityID, token: token)
            }

            apply(details: result)
            hasLoaded = true
            return true
        } catch {
            Self.logger.error("Failed to complete chatter activity \(activityID, privacy: .public) for \(self.model, privacy: .public)#\(self.recordID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            if case APIClientError.unauthorized = error {
                appState.signOut()
            } else {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }

    private func apply(thread: ChatterThreadResult, details: ChatterDetailsResult) {
        messages = thread.messages
        hasMore = thread.hasMore
        nextBefore = thread.nextBefore
        apply(details: details)
    }

    private func apply(details: ChatterDetailsResult) {
        followers = details.followers
        followersCount = details.followersCount
        selfFollower = details.selfFollower
        activities = details.activities
    }
}