import SwiftUI

struct RecordDetailView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: RecordDetailViewModel

    init(descriptor: ModelDescriptor, recordID: Int) {
        _viewModel = StateObject(wrappedValue: RecordDetailViewModel(descriptor: descriptor, recordID: recordID))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.record == nil {
                ProgressView("Loading record…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        VStack(alignment: .leading, spacing: 6) {
                            Text(record["display_name"]?.displayText ?? record["name"]?.displayText ?? schema.title)
                                .font(.title3.weight(.semibold))

                            if let statusField = schema.header.statusbar?.field,
                               let status = record[statusField]?.displayText,
                               status != "—" {
                                Label(status, systemImage: "circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    ForEach(Array(schema.sections.enumerated()), id: \.offset) { _, section in
                        let visibleFields = section.fields.compactMap { field in
                            viewModel.value(for: field).map { value in (field, value) }
                        }

                        if !visibleFields.isEmpty {
                            Section(section.label ?? "Details") {
                                ForEach(visibleFields, id: \.0.name) { field, value in
                                    LabeledContent(field.label) {
                                        Text(value)
                                            .multilineTextAlignment(.trailing)
                                    }
                                }
                            }
                        }
                    }

                    if !schema.tabs.isEmpty {
                        Section("Additional Sections") {
                            ForEach(schema.tabs) { tab in
                                Text(tab.label)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .refreshable {
                    await viewModel.load(using: appState)
                }
            } else {
                ContentUnavailableView("No Record Selected", systemImage: "doc.text")
            }
        }
        .navigationTitle(viewModel.descriptor.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(using: appState)
        }
    }
}

#Preview {
    NavigationStack {
        RecordDetailView(descriptor: ModelRegistry.supported[0], recordID: 1)
            .environmentObject(AppState.preview)
    }
}
