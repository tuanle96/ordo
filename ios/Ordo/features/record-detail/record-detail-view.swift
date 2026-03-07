import SwiftUI

struct RecordDetailView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var recentItems: RecentItemsStore
    @StateObject private var viewModel: RecordDetailViewModel
    @State private var isEditing = false
    @State private var draft: FormDraft?

    init(descriptor: ModelDescriptor, recordID: Int) {
        _viewModel = StateObject(wrappedValue: RecordDetailViewModel(descriptor: descriptor, recordID: recordID))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.record == nil {
                ScrollView {
                    VStack(spacing: OrdoSpacing.lg) {
                        OrdoSkeletonCard(lines: 2)
                        OrdoSkeletonCard(lines: 4)
                        OrdoSkeletonCard(lines: 3)
                    }
                    .padding(.horizontal, OrdoSpacing.lg)
                    .padding(.vertical, OrdoSpacing.sm)
                }
                .background(OrdoColors.surfaceGrouped)
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "Couldn’t Load Record",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if let schema = viewModel.schema, let record = viewModel.record {
                List {
                    if let cacheMessage = viewModel.cacheMessage {
                        Section {
                            OfflineStateBanner(title: "Showing saved record", message: cacheMessage)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }
                    }

                    Section {
                        RecordHeaderCard(
                            displayName: record["display_name"]?.displayText ?? record["name"]?.displayText ?? schema.title,
                            status: {
                                if let statusField = schema.header.statusbar?.field,
                                   let status = record[statusField]?.displayText,
                                   status != "—" {
                                    return status
                                }
                                return nil
                            }()
                        )
                    }

                    SchemaRendererView(schema: schema, record: record, draft: draft, isEditing: isEditing)
                }
                .accessibilityIdentifier("record-detail-screen")
                .refreshable {
                    await viewModel.load(using: appState)
                    if let record = viewModel.record, !isEditing {
                        draft = FormDraft(record: record)
                    }
                }
            } else {
                ContentUnavailableView("No Record Selected", systemImage: "doc.text")
            }
        }
        .navigationTitle(viewModel.descriptor.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.schema != nil, viewModel.record != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Cancel" : "Edit") {
                        if isEditing {
                            isEditing = false
                            if let record = viewModel.record {
                                draft = FormDraft(record: record)
                            }
                        } else if let record = viewModel.record {
                            draft = FormDraft(record: record)
                            isEditing = true
                        }
                    }
                    .accessibilityIdentifier("detail-edit-button")
                }
            }
        }
        .task {
            await viewModel.load(using: appState)
            if let record = viewModel.record {
                draft = FormDraft(record: record)
                let displayName = record["display_name"]?.displayText ?? record["name"]?.displayText ?? "Record"
                recentItems.add(model: viewModel.descriptor.model, recordID: viewModel.recordID, displayName: displayName)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecordDetailView(descriptor: ModelRegistry.supported[0], recordID: 1)
            .environmentObject(AppState.preview)
    }
}
