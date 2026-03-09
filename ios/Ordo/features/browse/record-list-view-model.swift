import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class RecordListViewModel {
    enum ViewMode: String, CaseIterable, Identifiable {
        case cards
        case table

        var id: String { rawValue }

        var title: String {
            switch self {
            case .cards:
                return "Cards"
            case .table:
                return "Table"
            }
        }
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case serverDefault
        case newestFirst
        case oldestFirst
        case titleAscending
        case titleDescending

        var id: String { rawValue }

        var title: String {
            switch self {
            case .serverDefault:
                return "Default"
            case .newestFirst:
                return "Newest"
            case .oldestFirst:
                return "Oldest"
            case .titleAscending:
                return "Title A–Z"
            case .titleDescending:
                return "Title Z–A"
            }
        }

        func order(for descriptor: ModelDescriptor) -> String? {
            switch self {
            case .serverDefault:
                return nil
            case .newestFirst:
                return "id desc"
            case .oldestFirst:
                return "id asc"
            case .titleAscending:
                return "\(descriptor.primarySortField) asc"
            case .titleDescending:
                return "\(descriptor.primarySortField) desc"
            }
        }
    }

    private static let logger = Logger(subsystem: "com.ordo.app", category: "record-list")

    private(set) var items: [RecordData] = []
    private(set) var searchResults: [NameSearchResult] = []
    private(set) var errorMessage: String?
    private(set) var cacheMessage: String?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var canLoadMore = true
    var viewMode: ViewMode = .cards
    private(set) var sortOption: SortOption = .serverDefault
    private(set) var filterState: BrowseFilterState
    var query = ""

    let descriptor: ModelDescriptor

    private var searchTask: Task<Void, Never>?
    private let pageSize = 30 // matches the current backend default limit for browse lists
    private let searchDebounce = Duration.milliseconds(300)
    private var loadedOffsets = Set<Int>()
    private var nextOffset = 0
    private let filterFields: [BrowseFilterField]
    private let userDefaults: UserDefaults

    init(descriptor: ModelDescriptor, userDefaults: UserDefaults = .standard) {
        self.descriptor = descriptor
        self.userDefaults = userDefaults
        self.filterFields = BrowseFilterRegistry.fields(for: descriptor)
        self.filterState = BrowseFilterStore.load(model: descriptor.model, userDefaults: userDefaults).normalized(with: filterFields)
    }

    var availableFilterFields: [BrowseFilterField] {
        filterFields
    }

    var activeFilterCount: Int {
        filterState.activeCount
    }

    var hasActiveFilters: Bool {
        activeFilterCount > 0
    }

    var filterSummary: String? {
        guard hasActiveFilters else { return nil }
        return activeFilterCount == 1 ? "1 filter applied" : "\(activeFilterCount) filters applied"
    }

    private var activeDomain: JSONValue? {
        filterState.domainValue(using: filterFields)
    }

    private var activeDomainKey: String? {
        activeDomain?.encodedJSONString
    }

    func apply(sortOption: SortOption, using appState: AppState) async {
        guard self.sortOption != sortOption else { return }
        self.sortOption = sortOption
        await load(using: appState)
    }

    func load(using appState: AppState) async {
        await loadPage(offset: 0, using: appState, replacing: true)
    }

    func apply(filterState: BrowseFilterState, using appState: AppState) async {
        let normalizedState = filterState.normalized(with: filterFields)
        guard normalizedState != self.filterState else { return }
        self.filterState = normalizedState
        BrowseFilterStore.save(normalizedState, model: descriptor.model, userDefaults: userDefaults)
        await load(using: appState)

        if query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
            await performSearch(using: appState)
        }
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

        let order = sortOption.order(for: descriptor)
        let domain = activeDomain
        let domainKey = activeDomainKey

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
                    let cached = await appState.cacheStore.loadListPage(for: descriptor.model, limit: pageSize, offset: 0, order: order, domainKey: domainKey, scope: cacheScope) {
            applyPage(cached.value, offset: 0, replacing: true)
            cacheMessage = "Showing saved data from \(cached.relativeTimestamp)."
        }

            Self.logger.info("📋 Loading page for \(self.descriptor.model, privacy: .public) offset=\(offset, privacy: .public) replacing=\(replacing, privacy: .public) order=\(order ?? "default", privacy: .public) domain=\(domainKey ?? "default", privacy: .public)")

        do {
            let result = try await appState.withAuthenticatedToken { [self] token in
                try await appState.apiClient.listRecords(
                    model: self.descriptor.model,
                    fields: self.descriptor.listFields,
                    limit: self.pageSize,
                    offset: offset,
                    order: order,
                    domain: domain,
                    token: token
                )
            }
            Self.logger.debug("📋 Page loaded: \(result.items.count, privacy: .public) items for \(self.descriptor.model, privacy: .public)")
            applyPage(result, offset: offset, replacing: replacing)
            cacheMessage = nil
            do {
                try await appState.cacheStore.saveListPage(result, for: descriptor.model, limit: pageSize, offset: offset, order: order, domainKey: domainKey, scope: cacheScope)
            } catch {
                Self.logger.error("Failed to save list cache for \(self.descriptor.model, privacy: .public) offset \(offset, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            Self.logger.error("❌ Failed to load list \(self.descriptor.model, privacy: .public) offset=\(offset, privacy: .public): \(String(describing: error), privacy: .public)")
            if case APIClientError.unauthorized = error {
                appState.signOut()
            } else if !replacing,
                      let cached = await appState.cacheStore.loadListPage(for: descriptor.model, limit: pageSize, offset: offset, order: order, domainKey: domainKey, scope: cacheScope) {
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
                        domain: self.activeDomain,
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
