import Combine
import Foundation

@MainActor
final class RecordListViewModel: ObservableObject {
    @Published private(set) var items: [RecordData] = []
    @Published private(set) var searchResults: [NameSearchResult] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var cacheMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var canLoadMore = true
    @Published var query = ""

    let descriptor: ModelDescriptor

    private var searchTask: Task<Void, Never>?
    private let pageSize = 30
    private var loadedOffsets = Set<Int>()

    init(descriptor: ModelDescriptor) {
        self.descriptor = descriptor
    }

    deinit {
        searchTask?.cancel()
    }

    func load(using appState: AppState) async {
        await loadPage(offset: 0, using: appState, replacing: true)
    }

    func loadMoreIfNeeded(currentID: Int, using appState: AppState) async {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isLoading && !isLoadingMore && canLoadMore else { return }
        guard currentID == summaries.last?.id else { return }
        guard !loadedOffsets.contains(items.count) else { return }

        await loadPage(offset: items.count, using: appState, replacing: false)
    }

    private func loadPage(offset: Int, using appState: AppState, replacing: Bool) async {
        guard let token = appState.session?.accessToken else {
            errorMessage = "Sign in again to load records."
            return
        }
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
        }

        if replacing,
              let cached = await appState.cacheStore.loadListPage(for: descriptor.model, limit: pageSize, offset: 0, scope: cacheScope) {
            items = cached.value.items
            canLoadMore = cached.value.items.count == pageSize
            cacheMessage = "Showing saved data from \(cached.relativeTimestamp)."
            loadedOffsets.insert(0)
        }

        do {
            let result = try await appState.apiClient.listRecords(
                model: descriptor.model,
                fields: descriptor.listFields,
                limit: pageSize,
                offset: offset,
                token: token
            )
            if replacing {
                items = result.items
            } else {
                items += result.items
            }
            canLoadMore = result.items.count == pageSize
            cacheMessage = nil
            loadedOffsets.insert(offset)
            try? await appState.cacheStore.saveListPage(result, for: descriptor.model, limit: pageSize, offset: offset, scope: cacheScope)
        } catch {
            if case APIClientError.unauthorized = error {
                appState.signOut()
            } else if !replacing,
                      let cached = await appState.cacheStore.loadListPage(for: descriptor.model, limit: pageSize, offset: offset, scope: cacheScope) {
                items += cached.value.items
                canLoadMore = cached.value.items.count == pageSize
                cacheMessage = "Loaded more from saved data (\(cached.relativeTimestamp))."
                loadedOffsets.insert(offset)
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

        guard let token = appState.session?.accessToken else { return }

        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }

                let results = try await appState.apiClient.search(
                    model: descriptor.model,
                    query: trimmedQuery,
                    limit: 15,
                    token: token
                )

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self?.searchResults = results
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
}
