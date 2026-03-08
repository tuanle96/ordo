import SwiftUI

struct RecordListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: RecordListViewModel

    init(descriptor: ModelDescriptor) {
        _viewModel = State(initialValue: RecordListViewModel(descriptor: descriptor))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.summaries.isEmpty && viewModel.searchResults.isEmpty {
                ProgressView("Loading \(viewModel.descriptor.title.lowercased())…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage, viewModel.summaries.isEmpty && viewModel.searchResults.isEmpty {
                ContentUnavailableView(
                    "Couldn’t Load Records",
                    systemImage: "wifi.exclamationmark",
                    description: Text(errorMessage)
                )
            } else {
                List {
                    if let cacheMessage = viewModel.cacheMessage {
                        Section {
                            OfflineStateBanner(title: "Showing saved data", message: cacheMessage)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }
                    }

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

                    Section(viewModel.query.isEmpty ? "Recent Records" : "Browse") {
                        if viewModel.viewMode == .table {
                            TableHeaderRow()
                        }

                        ForEach(viewModel.summaries) { summary in
                            NavigationLink {
                                RecordDetailView(descriptor: viewModel.descriptor, recordID: summary.id)
                            } label: {
                                rowView(summary: summary)
                            }
                            .accessibilityIdentifier("record-row-\(summary.id)")
                            .task {
                                await viewModel.loadMoreIfNeeded(currentID: summary.id, using: appState)
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
                .accessibilityIdentifier("record-list-screen")
                .refreshable {
                    await viewModel.load(using: appState)
                }
            }
        }
        .navigationTitle(viewModel.descriptor.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    RecordDetailView(descriptor: viewModel.descriptor)
                } label: {
                    Label("New Record", systemImage: "plus")
                }
                .accessibilityIdentifier("record-list-create-button")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Layout", selection: Binding(
                        get: { viewModel.viewMode },
                        set: { viewModel.viewMode = $0 }
                    )) {
                        ForEach(RecordListViewModel.ViewMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

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
                } label: {
                    Label("Browse Options", systemImage: viewModel.viewMode == .cards ? "rectangle.grid.1x2" : "tablecells")
                }
                .accessibilityIdentifier("record-list-options-button")
            }
        }
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
    }

    @ViewBuilder
    private func rowView(summary: RecordRowSummary) -> some View {
        if viewModel.viewMode == .table {
            RecordTableRow(summary: summary)
        } else {
            RecordCardRow(summary: summary)
        }
    }
}

private struct TableHeaderRow: View {
    var body: some View {
        HStack(alignment: .center, spacing: OrdoSpacing.md) {
            Text("Title")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Details")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Meta")
                .frame(maxWidth: .infinity, alignment: .trailing)
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
