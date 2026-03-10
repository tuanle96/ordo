import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class RecordListViewModel {
    struct DisplayRow: Identifiable {
        let summary: RecordRowSummary
        let record: RecordData

        var id: Int { summary.id }
    }

    struct DisplaySection: Identifiable {
        let title: String
        let rows: [DisplayRow]

        var id: String { title }
    }

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
    private(set) var totalCount: Int?
    private(set) var listSchema: MobileListSchema?
    private(set) var activeQuickFilterName: String?
    private(set) var activeGroupByName: String?
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
    private var didAttemptListSchemaLoad = false
    private var filterFields: [BrowseFilterField]
    private let userDefaults: UserDefaults

    init(descriptor: ModelDescriptor, userDefaults: UserDefaults = .standard) {
        let initialFilterFields = BrowseFilterRegistry.fields(for: descriptor, listSchema: nil)
        let initialFilterState = BrowseFilterStore.load(model: descriptor.model, userDefaults: userDefaults)
            .normalized(with: initialFilterFields)

        self.descriptor = descriptor
        self.userDefaults = userDefaults
        self.filterFields = initialFilterFields
        self.filterState = initialFilterState
        self.activeGroupByName = BrowseGroupByStore.load(model: descriptor.model, userDefaults: userDefaults)
    }

    var availableFilterFields: [BrowseFilterField] {
        filterFields
    }

    var activeFilterCount: Int {
        filterState.activeCount
    }

    var quickFilters: [SearchFilter] {
        listSchema?.search.filters ?? []
    }

    var availableGroupBys: [SearchGroupBy] {
        listSchema?.search.groupBy ?? []
    }

    var activeGroupBy: SearchGroupBy? {
        availableGroupBys.first(where: { $0.name == activeGroupByName })
    }

    var tableColumns: [ListColumn] {
        listSchema?.visibleColumns ?? []
    }

    var totalDisplayText: String? {
        guard let totalCount else { return nil }
        return "\(items.count) of \(totalCount)"
    }

    var hasActiveFilters: Bool {
        activeFilterCount > 0
    }

    var filterSummary: String? {
        guard hasActiveFilters else { return nil }
        return activeFilterCount == 1 ? "1 filter applied" : "\(activeFilterCount) filters applied"
    }

    private var activeDomain: JSONValue? {
        let filterDomain = filterState.domainValue(using: filterFields)
        let quickFilterDomain = quickFilters.first(where: { $0.name == activeQuickFilterName })?.domainValue

        switch (quickFilterDomain, filterDomain) {
        case (nil, nil):
            return nil
        case let (domain?, nil), let (nil, domain?):
            return domain
        case let (.array(quickClauses), .array(filterClauses)):
            return .array(quickClauses + filterClauses)
        default:
            return filterDomain ?? quickFilterDomain
        }
    }

    private var activeDomainKey: String? {
        activeDomain?.encodedJSONString
    }

    private var activeFieldKey: String {
        requestedFields.joined(separator: ",")
    }

    private var requestedFields: [String] {
        let baseFields: [String]

        if let listSchema, !listSchema.requestedFieldNames.isEmpty {
            baseFields = listSchema.requestedFieldNames
        } else if let descriptorFields = descriptor.listFields, !descriptorFields.isEmpty {
            baseFields = descriptorFields
        } else {
            baseFields = ["id", "display_name", "name"] + descriptor.titleFields + descriptor.subtitleFields + descriptor.footnoteFields
        }

        if let activeGroupField = activeGroupBy?.fieldName {
            return orderedUnique(baseFields + [activeGroupField])
        }

        return orderedUnique(baseFields)
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

    func applyQuickFilter(named filterName: String?, using appState: AppState) async {
        let resolvedFilterName = activeQuickFilterName == filterName ? nil : filterName
        guard resolvedFilterName != activeQuickFilterName else { return }
        activeQuickFilterName = resolvedFilterName
        await load(using: appState)
    }

    func applyGroupBy(named groupByName: String?, using appState: AppState) async {
        let normalizedName = normalizedGroupByName(groupByName, available: availableGroupBys)
        guard normalizedName != activeGroupByName else { return }
        activeGroupByName = normalizedName
        BrowseGroupByStore.save(normalizedName, model: descriptor.model, userDefaults: userDefaults)
        await load(using: appState)
    }

    func loadMoreIfNeeded(currentID: Int, using appState: AppState) async {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isLoading && !isLoadingMore && canLoadMore else { return }
        guard currentID == displayRows.last?.id else { return }
        guard !loadedOffsets.contains(nextOffset) else { return }

        await loadPage(offset: nextOffset, using: appState, replacing: false)
    }

    private func loadPage(offset: Int, using appState: AppState, replacing: Bool) async {
        guard let cacheScope = appState.cacheScope else {
            errorMessage = "Sign in again to load records."
            return
        }

        if replacing {
            await loadListSchemaIfNeeded(using: appState)
        }

        let order = sortOption.order(for: descriptor)
        let domain = activeDomain
        let domainKey = activeDomainKey
        let fieldKey = activeFieldKey

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
            let cached = await appState.cacheStore.loadListPage(for: descriptor.model, limit: pageSize, offset: 0, order: order, domainKey: domainKey, fieldKey: fieldKey, scope: cacheScope) {
            applyPage(cached.value, offset: 0, replacing: true)
            cacheMessage = "Showing saved data from \(cached.relativeTimestamp)."
        }

            Self.logger.info("📋 Loading page for \(self.descriptor.model, privacy: .public) offset=\(offset, privacy: .public) replacing=\(replacing, privacy: .public) order=\(order ?? "default", privacy: .public) domain=\(domainKey ?? "default", privacy: .public)")

        do {
            let result = try await appState.withAuthenticatedToken { [self] token in
                try await appState.apiClient.listRecords(
                    model: self.descriptor.model,
                    fields: self.requestedFields,
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
                try await appState.cacheStore.saveListPage(result, for: descriptor.model, limit: pageSize, offset: offset, order: order, domainKey: domainKey, fieldKey: fieldKey, scope: cacheScope)
            } catch {
                Self.logger.error("Failed to save list cache for \(self.descriptor.model, privacy: .public) offset \(offset, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            Self.logger.error("❌ Failed to load list \(self.descriptor.model, privacy: .public) offset=\(offset, privacy: .public): \(String(describing: error), privacy: .public)")
            if case APIClientError.unauthorized = error {
                appState.signOut()
            } else if !replacing,
                      let cached = await appState.cacheStore.loadListPage(for: descriptor.model, limit: pageSize, offset: offset, order: order, domainKey: domainKey, fieldKey: fieldKey, scope: cacheScope) {
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

    private func loadListSchemaIfNeeded(using appState: AppState) async {
        guard !didAttemptListSchemaLoad else { return }

        do {
            let schema = try await appState.withAuthenticatedToken { [descriptor] token in
                try await appState.apiClient.listSchema(model: descriptor.model, token: token)
            }

            didAttemptListSchemaLoad = true
            listSchema = schema
            filterFields = BrowseFilterRegistry.fields(for: descriptor, listSchema: schema)
            filterState = filterState.normalized(with: filterFields)
            activeGroupByName = normalizedGroupByName(activeGroupByName, available: schema.search.groupBy)
            BrowseGroupByStore.save(activeGroupByName, model: descriptor.model, userDefaults: userDefaults)
        } catch {
            if case APIClientError.unauthorized = error {
                appState.signOut()
                return
            }

            Self.logger.info("ℹ️ Falling back to descriptor browse config for \(self.descriptor.model, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
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

    var displayRows: [DisplayRow] {
        items.compactMap { record in
            guard let summary = summary(for: record) else { return nil }
            return DisplayRow(summary: summary, record: record)
        }
    }

    var displaySections: [DisplaySection] {
        guard let activeGroupBy else { return [] }

        let groupedRows = Dictionary(grouping: displayRows) { row in
            groupTitle(for: row.record, groupBy: activeGroupBy)
        }

        return groupedRows.keys.sorted().map { title in
            DisplaySection(title: title, rows: groupedRows[title] ?? [])
        }
    }

    var isGroupingActive: Bool {
        activeGroupBy != nil
    }

    private func summary(for record: RecordData) -> RecordRowSummary? {
        if let listSchema, !listSchema.visibleColumns.isEmpty {
            return schemaSummary(for: record, columns: listSchema.visibleColumns)
        }

        return descriptor.summary(from: record)
    }

    private func schemaSummary(for record: RecordData, columns: [ListColumn]) -> RecordRowSummary? {
        guard let id = record["id"]?.intValue else { return nil }

        let values: [String?] = columns.map { column in
            let value = record[column.name]?.displayText
            return value == "—" || value?.isEmpty == true ? nil : value
        }

        let fallbackTitle = descriptor.summary(from: record)?.title ?? "Record #\(id)"
        let title = values.compactMap { $0 }.first ?? fallbackTitle
        let subtitle = Array(values.dropFirst().prefix(2)).compactMap { $0 }.joined(separator: " · ")
        let footnote = Array(values.dropFirst(3)).compactMap { $0 }.joined(separator: " · ")

        return RecordRowSummary(
            id: id,
            title: title,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            footnote: footnote.isEmpty ? nil : footnote
        )
    }

    private func applyPage(_ result: RecordListResult, offset: Int, replacing: Bool) {
        if replacing {
            items = deduplicated(result.items)
        } else {
            items = merge(existing: items, with: result.items)
        }

        totalCount = result.total
        canLoadMore = items.count < result.total
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

    private func groupTitle(for record: RecordData, groupBy: SearchGroupBy) -> String {
        guard let value = record[groupBy.fieldName], !value.isVisuallyEmpty else {
            return "No \(groupBy.label)"
        }

        let title = value.relationLabel ?? value.stringValue ?? value.displayText
        return title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No \(groupBy.label)" : title
    }

    private func normalizedGroupByName(_ groupByName: String?, available: [SearchGroupBy]) -> String? {
        guard let groupByName else { return nil }
        return available.contains(where: { $0.name == groupByName }) ? groupByName : nil
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
