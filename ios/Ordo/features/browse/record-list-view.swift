import SwiftUI

struct RecordListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: RecordListViewModel
    @State private var isShowingFilterSheet = false

    init(descriptor: ModelDescriptor) {
        _viewModel = State(initialValue: RecordListViewModel(descriptor: descriptor))
    }

    var body: some View {
        content
        .navigationTitle(viewModel.descriptor.title)
        .toolbar { toolbarContent }
        .searchable(
            text: Binding(
                get: { viewModel.query },
                set: { viewModel.query = $0 }
            ),
            prompt: "Search \(viewModel.descriptor.title.lowercased())"
        )
        .task {
            await viewModel.loadIfNeeded(using: appState)
        }
        .task(id: viewModel.query) {
            await viewModel.performSearch(using: appState)
        }
        .sheet(isPresented: $isShowingFilterSheet) {
            FilterSheetView(
                descriptor: viewModel.descriptor,
                fields: viewModel.availableFilterFields,
                initialState: viewModel.filterState,
                onApply: { filterState in
                    Task {
                        await viewModel.apply(filterState: filterState, using: appState)
                    }
                }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.displayRows.isEmpty && viewModel.searchResults.isEmpty {
            ProgressView("Loading \(viewModel.descriptor.title.lowercased())…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage,
                  viewModel.displayRows.isEmpty,
                  viewModel.searchResults.isEmpty {
            ContentUnavailableView(
                "Couldn’t Load Records",
                systemImage: "wifi.exclamationmark",
                description: Text(errorMessage)
            )
        } else {
            listContent
        }
    }

    private var listContent: some View {
        List {
            cacheBannerSection
            filterSummarySection
            quickFiltersSection
            totalCountSection
            searchResultsSection
            recordsSection
        }
        .accessibilityIdentifier("record-list-screen")
        .refreshable {
            await viewModel.load(using: appState)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                RecordDetailView(descriptor: viewModel.descriptor)
            } label: {
                Label("New Record", systemImage: "plus")
            }
            .accessibilityIdentifier("record-list-create-button")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isShowingFilterSheet = true
            } label: {
                Label(filterButtonTitle, systemImage: filterButtonIcon)
            }
            .accessibilityIdentifier("record-list-filter-button")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                layoutPicker
                sortPicker
            } label: {
                Label("Browse Options", systemImage: browseOptionsIcon)
            }
            .accessibilityIdentifier("record-list-options-button")
        }
    }

    private var filterButtonTitle: String {
        viewModel.hasActiveFilters ? "Filters (\(viewModel.activeFilterCount))" : "Filters"
    }

    private var filterButtonIcon: String {
        viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
    }

    private var browseOptionsIcon: String {
        viewModel.viewMode == .cards ? "rectangle.grid.1x2" : "tablecells"
    }

    private var layoutPicker: some View {
        Picker("Layout", selection: Binding(
            get: { viewModel.viewMode },
            set: { viewModel.viewMode = $0 }
        )) {
            ForEach(RecordListViewModel.ViewMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
    }

    private var sortPicker: some View {
        Picker("Sort", selection: Binding(
            get: { viewModel.sortOption },
            set: { newValue in
                Task {
                    await viewModel.apply(sortOption: newValue, using: appState)
                }
            }
        )) {
            ForEach(RecordListViewModel.SortOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
    }

    @ViewBuilder
    private var cacheBannerSection: some View {
        if let cacheMessage = viewModel.cacheMessage {
            Section {
                OfflineStateBanner(title: "Showing saved data", message: cacheMessage)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }
        }
    }

    @ViewBuilder
    private var filterSummarySection: some View {
        if let filterSummary = viewModel.filterSummary {
            Section {
                Label(filterSummary, systemImage: "line.3.horizontal.decrease.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var quickFiltersSection: some View {
        if !viewModel.quickFilters.isEmpty {
            Section("Quick Filters") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: OrdoSpacing.sm) {
                        ForEach(viewModel.quickFilters) { filter in
                            quickFilterChip(filter)
                        }
                    }
                    .padding(.vertical, OrdoSpacing.xs)
                }
            }
        }
    }

    private func quickFilterChip(_ filter: SearchFilter) -> some View {
        Button {
            Task {
                await viewModel.applyQuickFilter(named: filter.name, using: appState)
            }
        } label: {
            Text(filter.label)
                .font(OrdoTypography.caption.weight(.medium))
                .padding(.horizontal, OrdoSpacing.md)
                .padding(.vertical, OrdoSpacing.sm)
                .background(activeQuickFilterBackground(for: filter))
                .foregroundStyle(activeQuickFilterForeground(for: filter))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func activeQuickFilterBackground(for filter: SearchFilter) -> Color {
        viewModel.activeQuickFilterName == filter.name ? OrdoColors.accent : OrdoColors.surfaceCard
    }

    private func activeQuickFilterForeground(for filter: SearchFilter) -> Color {
        viewModel.activeQuickFilterName == filter.name ? .white : OrdoColors.textSecondary
    }

    @ViewBuilder
    private var totalCountSection: some View {
        if let totalDisplayText = viewModel.totalDisplayText, viewModel.query.isEmpty {
            Section {
                Label(totalDisplayText, systemImage: "number")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Section("Matches") {
                if viewModel.searchResults.isEmpty {
                    Text("Keep typing to search by name.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.searchResults) { result in
                        NavigationLink {
                            RecordDetailView(descriptor: viewModel.descriptor, recordID: result.id)
                        } label: {
                            rowView(summary: RecordRowSummary(
                                id: result.id,
                                title: result.name,
                                subtitle: nil,
                                footnote: nil
                            ))
                        }
                    }
                }
            }
        }
    }

    private var recordsSectionTitle: String {
        viewModel.query.isEmpty ? "Recent Records" : "Browse"
    }

    private var recordsSection: some View {
        Section(recordsSectionTitle) {
            if viewModel.viewMode == .table {
                TableHeaderRow(columns: viewModel.tableColumns)
            }

            ForEach(viewModel.displayRows) { row in
                NavigationLink {
                    RecordDetailView(descriptor: viewModel.descriptor, recordID: row.id)
                } label: {
                    rowView(row: row)
                }
                .accessibilityIdentifier("record-row-\(row.id)")
                .task {
                    await viewModel.loadMoreIfNeeded(currentID: row.id, using: appState)
                }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(row: RecordListViewModel.DisplayRow) -> some View {
        if viewModel.viewMode == .table {
            RecordTableRow(summary: row.summary, record: row.record, columns: viewModel.tableColumns)
        } else {
            RecordCardRow(summary: row.summary, columns: viewModel.tableColumns)
        }
    }

    @ViewBuilder
    private func rowView(summary: RecordRowSummary) -> some View {
        if viewModel.viewMode == .table {
            RecordTableRow(summary: summary, record: nil, columns: nil)
        } else {
            RecordCardRow(summary: summary, columns: viewModel.tableColumns)
        }
    }
}

private struct TableHeaderRow: View {
    let columns: [ListColumn]

    var body: some View {
        HStack(alignment: .center, spacing: OrdoSpacing.md) {
            if columns.isEmpty {
                Text("Title")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Details")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Meta")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                ForEach(columns) { column in
                    Text(column.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .font(OrdoTypography.caption.weight(.semibold))
        .foregroundStyle(OrdoColors.textTertiary)
        .textCase(nil)
        .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        RecordListView(descriptor: ModelRegistry.supported[0])
            .environment(AppState.preview)
    }
}
