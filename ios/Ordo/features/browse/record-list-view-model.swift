import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class RecordListViewModel {
    private static let logger = Logger(subsystem: "com.ordo.app", category: "record-list")

    private(set) var items: [RecordData] = []
    private(set) var searchResults: [NameSearchResult] = []
    private(set) var errorMessage: String?
    private(set) var cacheMessage: String?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var canLoadMore = true
    var query = ""

    let descriptor: ModelDescriptor

    private var searchTask: Task<Void, Never>?
    private let pageSize = 30 // matches the current backend default limit for browse lists
    private let searchDebounce = Duration.milliseconds(300)
    private var loadedOffsets = Set<Int>()
    private var nextOffset = 0

    init(descriptor: ModelDescriptor) {
        self.descriptor = descriptor
    }

    func load(using appState: AppState) async {
        await loadPage(offset: 0, using: appState, replacing: true)
    }

    func loadMoreIfNeeded(currentID: Int, using appState: AppState) async {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isLoading && !isLoadingMore && canLoadMore else { return }
        guard currentID == summaries.last?.id else { return }
        guard !loadedOffsets.contains(nextOffset) else { return }

        await loadPage(offset: nextOffset, using: appState, replacing: false)
    }

    private func loadPage(offset: Int, using appState: AppState, replacing: Bool) async {
        guard let cacheScope = appState.cacheScope else {
            errorMessage = "Sign in again to load records."
            return
        }

        if replacing {
            isLoading = true
        } else {
            isLoadingMore = true
        }

        errorMessage = nil
        if replacing {
            cacheMessage = nil
            loadedOffsets.removeAll()
            nextOffset = 0
        }

        if replacing,
              let cached = await appState.cacheStore.loadListPage(for: descriptor.model, limit: pageSize, offset: 0, scope: cacheScope) {
            applyPage(cached.value, offset: 0, replacing: true)
            cacheMessage = "Showing saved data from \(cached.relativeTimestamp)."
        }

        Self.logger.info("📋 Loading page for \(self.descriptor.model, privacy: .public) offset=\(offset, privacy: .public) replacing=\(replacing, privacy: .public)")

        do {
            let result = try await appState.withAuthenticatedToken { [self] token in
                try await appState.apiClient.listRecords(
                    model: self.descriptor.model,
                    fields: self.descriptor.listFields,
                    limit: self.pageSize,
                    offset: offset,
                    token: token
                )
            }
            Self.logger.debug("📋 Page loaded: \(result.items.count, privacy: .public) items for \(self.descriptor.model, privacy: .public)")
            applyPage(result, offset: offset, replacing: replacing)
            cacheMessage = nil
            do {
                try await appState.cacheStore.saveListPage(result, for: descriptor.model, limit: pageSize, offset: offset, scope: cacheScope)
            } catch {
                Self.logger.error("Failed to save list cache for \(self.descriptor.model, privacy: .public) offset \(offset, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            Self.logger.error("❌ Failed to load list \(self.descriptor.model, privacy: .public) offset=\(offset, privacy: .public): \(String(describing: error), privacy: .public)")
            if case APIClientError.unauthorized = error {
                appState.signOut()
            } else if !replacing,
                      let cached = await appState.cacheStore.loadListPage(for: descriptor.model, limit: pageSize, offset: offset, scope: cacheScope) {
                applyPage(cached.value, offset: offset, replacing: false)
                cacheMessage = "Loaded more from saved data (\(cached.relativeTimestamp))."
            } else if !replacing {
                errorMessage = error.localizedDescription
            } else if items.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
        isLoadingMore = false
    }

    func loadIfNeeded(using appState: AppState) async {
        guard items.isEmpty else { return }
        await load(using: appState)
    }

    func performSearch(using appState: AppState) async {
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedQuery.count >= 2 else {
            searchResults = []
            return
        }

        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: self?.searchDebounce ?? .milliseconds(300))
                guard !Task.isCancelled else { return }

                guard let self else { return }

                let results = try await appState.withAuthenticatedToken { token in
                    try await appState.apiClient.search(
                        model: self.descriptor.model,
                        query: trimmedQuery,
                        limit: 15,
                        token: token
                    )
                }

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.searchResults = results
                }
            } catch {
                guard !(error is CancellationError) else { return }

                if case APIClientError.unauthorized = error {
                    await MainActor.run {
                        appState.signOut()
                    }
                    return
                }

                await MainActor.run {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }

        await searchTask?.value
    }

    var summaries: [RecordRowSummary] {
        items.compactMap(descriptor.summary(from:))
    }

    private func applyPage(_ result: RecordListResult, offset: Int, replacing: Bool) {
        if replacing {
            items = deduplicated(result.items)
        } else {
            items = merge(existing: items, with: result.items)
        }

        canLoadMore = result.items.count == pageSize
        loadedOffsets.insert(offset)
        nextOffset = offset + result.items.count
    }

    private func deduplicated(_ records: [RecordData]) -> [RecordData] {
        merge(existing: [], with: records)
    }

    private func merge(existing: [RecordData], with incoming: [RecordData]) -> [RecordData] {
        var merged = existing
        var seenIDs = Set(existing.compactMap { $0["id"]?.intValue })

        for record in incoming {
            guard let id = record["id"]?.intValue else {
                merged.append(record)
                continue
            }

            guard !seenIDs.contains(id) else { continue }
            seenIDs.insert(id)
            merged.append(record)
        }

        return merged
    }
}
