import SwiftUI

struct RecordDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(RecentItemsStore.self) private var recentItems
    @State private var viewModel: RecordDetailViewModel
    @State private var chatterViewModel: RecordChatterViewModel
    @State private var isEditing = false
    @State private var draft: FormDraft?
    @State private var showDiscardConfirmation = false

    init(descriptor: ModelDescriptor, recordID: Int? = nil) {
        _viewModel = State(initialValue: RecordDetailViewModel(descriptor: descriptor, recordID: recordID))
        _chatterViewModel = State(initialValue: RecordChatterViewModel(model: descriptor.model, recordID: recordID ?? 0))
        _isEditing = State(initialValue: recordID == nil)
        _draft = State(initialValue: recordID == nil ? FormDraft(record: [:]) : nil)
    }

    private var isCreating: Bool {
        viewModel.isCreating
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
            } else if let errorMessage = viewModel.errorMessage,
                      viewModel.schema == nil || viewModel.record == nil {
                ContentUnavailableView(
                    "Couldn’t Load Record",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if let schema = viewModel.schema, let record = viewModel.record {
                List {
                    if let cacheMessage = viewModel.cacheMessage, !isCreating {
                        Section {
                            OfflineStateBanner(title: "Showing saved record", message: cacheMessage)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }
                    }

                    if let saveMessage = viewModel.saveMessage, !isEditing {
                        Section {
                            Text(saveMessage)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.green)
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.red)
                                .accessibilityIdentifier("detail-error-message")
                        }
                    }

                    if isEditing, !viewModel.onchangeWarnings.isEmpty {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(viewModel.onchangeWarnings.enumerated()), id: \.offset) { index, warning in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(warning.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.orange)
                                        Text(warning.message)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .accessibilityIdentifier("detail-onchange-warning-\(index)")
                                }
                            }
                        }
                    }

                    Section {
                        RecordHeaderCard(
                            displayName: record["display_name"]?.displayText ?? record["name"]?.displayText ?? (isCreating ? "New \(schema.title)" : schema.title),
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

                    SchemaRendererView(
                        schema: schema,
                        record: record,
                        draft: draft,
                        isEditing: isEditing,
                        validationErrors: viewModel.validationErrors,
                        onFieldChange: { field, value in
                            guard let draft else { return }
                            viewModel.applyFieldEdit(value, for: field, draft: draft, using: appState)
                        }
                    )
                    .id("schema-\(viewModel.recordID)-\(isEditing ? "editing" : "readonly")")

                    if schema.hasChatter, !isCreating, viewModel.recordID != nil {
                        ChatterSectionView(viewModel: chatterViewModel)
                    }
                }
                .accessibilityIdentifier("record-detail-screen")
                .refreshable {
                    await viewModel.load(using: appState)
                    if let record = viewModel.record, !isEditing {
                        draft = FormDraft(record: record)
                    }
                    if viewModel.schema?.hasChatter == true, let recordID = viewModel.recordID {
                        chatterViewModel = RecordChatterViewModel(model: viewModel.descriptor.model, recordID: recordID)
                        await chatterViewModel.refresh(using: appState)
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
                if isEditing {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            handleCancelTap()
                        }
                        .disabled(viewModel.isSaving)
                        .accessibilityIdentifier("detail-cancel-button")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        if viewModel.isSaving {
                            ProgressView()
                                .accessibilityIdentifier("detail-save-progress")
                        } else if viewModel.canSave(draft: draft) {
                            Button(isCreating ? "Create" : "Save") {
                                Task {
                                    await handleSaveTap()
                                }
                            }
                            .accessibilityIdentifier("detail-save-button")
                        }
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") {
                            draft = viewModel.startEditing()
                            isEditing = draft != nil
                        }
                        .accessibilityIdentifier("detail-edit-button")
                    }
                }
            }
        }
        .alert("Discard changes?", isPresented: $showDiscardConfirmation) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard Changes", role: .destructive) {
                finishDiscardingChanges()
            }
        } message: {
            Text("Your unsaved changes will be lost.")
        }
        .task {
            await viewModel.load(using: appState)
            if let record = viewModel.record {
                draft = FormDraft(record: record)
                if let recordID = viewModel.recordID {
                    let displayName = record["display_name"]?.displayText ?? record["name"]?.displayText ?? "Record"
                    recentItems.add(model: viewModel.descriptor.model, recordID: recordID, displayName: displayName)
                    chatterViewModel = RecordChatterViewModel(model: viewModel.descriptor.model, recordID: recordID)
                }
            }
            if viewModel.schema?.hasChatter == true, viewModel.recordID != nil {
                await chatterViewModel.loadIfNeeded(using: appState)
            }
        }
    }

    private func handleCancelTap() {
        guard viewModel.hasUnsavedChanges(draft: draft) else {
            finishDiscardingChanges()
            return
        }

        showDiscardConfirmation = true
    }

    private func finishDiscardingChanges() {
        isEditing = false
        viewModel.discardEditing()
        if let record = viewModel.record {
            draft = FormDraft(record: record)
        }
    }

    private func handleSaveTap() async {
        guard let draft else { return }
        let didSave = await viewModel.save(draft: draft, using: appState)

        guard didSave, let savedRecord = viewModel.record else { return }

        self.draft = FormDraft(record: savedRecord)
        isEditing = false
        if let recordID = viewModel.recordID {
            chatterViewModel = RecordChatterViewModel(model: viewModel.descriptor.model, recordID: recordID)
            let displayName = savedRecord["display_name"]?.displayText ?? savedRecord["name"]?.displayText ?? "Record"
            recentItems.add(model: viewModel.descriptor.model, recordID: recordID, displayName: displayName)
        }
    }
}

#Preview {
    NavigationStack {
        RecordDetailView(descriptor: ModelRegistry.supported[0], recordID: 1)
            .environment(AppState.preview)
            .environment(RecentItemsStore())
    }
}
