import SwiftUI

struct RecordListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: RecordListViewModel

    init(descriptor: ModelDescriptor) {
        _viewModel = StateObject(wrappedValue: RecordListViewModel(descriptor: descriptor))
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
                                        RecordCardRow(summary: RecordRowSummary(
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
                        ForEach(viewModel.summaries) { summary in
                            NavigationLink {
                                RecordDetailView(descriptor: viewModel.descriptor, recordID: summary.id)
                            } label: {
                                RecordCardRow(summary: summary)
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
        .searchable(text: $viewModel.query, prompt: "Search \(viewModel.descriptor.title.lowercased())")
        .task {
            await viewModel.loadIfNeeded(using: appState)
        }
        .task(id: viewModel.query) {
            await viewModel.performSearch(using: appState)
        }
    }
}

#Preview {
    NavigationStack {
        RecordListView(descriptor: ModelRegistry.supported[0])
            .environmentObject(AppState.preview)
    }
}
