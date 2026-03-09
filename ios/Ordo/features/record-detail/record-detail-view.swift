import SwiftUI

struct RecordDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(RecentItemsStore.self) private var recentItems
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: RecordDetailViewModel
    @State private var chatterViewModel: RecordChatterViewModel
    @State private var isEditing = false
    @State private var draft: FormDraft?
    @State private var showDiscardConfirmation = false
    @State private var pendingWorkflowAction: ActionButton?
    @State private var showDeleteConfirmation = false

    init(descriptor: ModelDescriptor, recordID: Int? = nil) {
        _viewModel = State(initialValue: RecordDetailViewModel(descriptor: descriptor, recordID: recordID))
        _chatterViewModel = State(initialValue: RecordChatterViewModel(model: descriptor.model, recordID: recordID ?? 0))
        _isEditing = State(initialValue: recordID == nil)
        _draft = State(initialValue: recordID == nil ? FormDraft(record: [:]) : nil)
    }

    private var isCreating: Bool {
        viewModel.isCreating
    }

    private var currentValues: RecordData {
        draft?.values ?? viewModel.record ?? [:]
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
                        let statusbarTapCandidate = !isEditing && !viewModel.isRunningWorkflowAction ? viewModel.statusbarTapCandidate : nil
                        let statusChips = viewModel.statusbarDisplayStates.map { state in
                            RecordHeaderStatusChip(
                                value: state.value,
                                label: state.label,
                                isCurrent: state.isCurrent,
                                isInteractive: statusbarTapCandidate?.targetValue == state.value
                            )
                        }

                        RecordHeaderCard(
                            displayName: headerDisplayName(schema: schema, record: record),
                            status: {
                                if let statusField = schema.header.statusbar?.field,
                                   let statusSchema = schema.allFields.first(where: { $0.name == statusField }),
                                   let rawStatus = record[statusField] {
                                    let formattedStatus = FieldRowFactory.formattedValue(for: statusSchema, rawValue: rawStatus)
                                    return formattedStatus == "—" ? nil : formattedStatus
                                }
                                return nil
                            }(),
                            statusChips: statusChips,
                            isEditing: isEditing,
                            nameText: headerNameBinding(schema: schema, record: record),
                            namePlaceholder: headerNameField(in: schema, values: currentValues)?.label,
                            onStatusTap: { chip in
                                guard let candidate = statusbarTapCandidate,
                                      candidate.targetValue == chip.value else { return }
                                handleWorkflowActionTap(candidate.action)
                            }
                        )
                    }

                    if !isEditing, !viewModel.visibleWorkflowActions.isEmpty {
                        Section("Actions") {
                            VStack(alignment: .leading, spacing: OrdoSpacing.sm) {
                                ForEach(viewModel.visibleWorkflowActions, id: \.name) { action in
                                    Button {
                                        handleWorkflowActionTap(action)
                                    } label: {
                                        HStack(spacing: OrdoSpacing.sm) {
                                            if viewModel.isRunningAction(action) {
                                                ProgressView()
                                                    .controlSize(.small)
                                            }

                                            Text(action.label)
                                                .font(.subheadline.weight(.semibold))
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(workflowActionTint(for: action))
                                    .disabled(viewModel.isRunningWorkflowAction)
                                    .accessibilityIdentifier("detail-action-\(action.name)")
                                }
                            }
                        }
                    }

                    SchemaRendererView(
                        schema: schema,
                        record: record,
                        draft: draft,
                        isEditing: isEditing,
                        hiddenFieldNames: hiddenSchemaFieldNames(schema: schema, values: currentValues),
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

                    if !isEditing, !isCreating, viewModel.recordID != nil {
                        Section("Danger Zone") {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                HStack {
                                    if viewModel.isDeleting {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text(viewModel.isDeleting ? "Deleting…" : "Delete Record")
                                }
                            }
                            .disabled(!viewModel.canDelete)
                            .accessibilityIdentifier("detail-delete-button")
                        }
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
                        .disabled(viewModel.isRunningWorkflowAction)
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
        .alert("Delete this record?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await handleDeleteTap()
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert(
            pendingWorkflowAction?.label ?? "Run Action",
            isPresented: workflowActionConfirmationBinding
        ) {
            Button("Cancel", role: .cancel) {
                pendingWorkflowAction = nil
            }

            Button(
                pendingWorkflowAction?.label ?? "Run",
                role: pendingWorkflowAction?.style == "danger" ? .destructive : nil
            ) {
                guard let action = pendingWorkflowAction else { return }
                pendingWorkflowAction = nil
                Task {
                    await executeWorkflowAction(action)
                }
            }
        } message: {
            Text(pendingWorkflowAction?.confirm ?? "")
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

    private func headerDisplayName(schema: MobileFormSchema, record: RecordData) -> String {
        let draftName = draft?
            .value(for: "name", fallback: record["name"])?
            .stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let draftName, !draftName.isEmpty {
            return draftName
        }

        return record["display_name"]?.displayText
            ?? record["name"]?.displayText
            ?? (isCreating ? "New \(schema.title)" : schema.title)
    }

    private func headerNameField(in schema: MobileFormSchema, values: RecordData) -> FieldSchema? {
        guard isEditing else { return nil }

        return schema.allFields.first { field in
            field.name == "name"
                && !field.isInvisible(in: values)
                && !field.isReadOnly(in: values)
                && EditableFieldFactory.model(for: field) != nil
        }
    }

    private func headerNameBinding(schema: MobileFormSchema, record: RecordData) -> Binding<String>? {
        guard let draft, let field = headerNameField(in: schema, values: currentValues) else {
            return nil
        }

        return Binding(
            get: {
                draft.value(for: field.name, fallback: record[field.name])?.stringValue ?? ""
            },
            set: { newValue in
                viewModel.applyFieldEdit(newValue.isEmpty ? nil : .string(newValue), for: field, draft: draft, using: appState)
            }
        )
    }

    private func hiddenSchemaFieldNames(schema: MobileFormSchema, values: RecordData) -> Set<String> {
        headerNameField(in: schema, values: values) == nil ? [] : ["name"]
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

    private func handleDeleteTap() async {
        guard let recordID = viewModel.recordID else { return }
        let didDelete = await viewModel.deleteRecord(using: appState)
        guard didDelete else { return }

        recentItems.remove(model: viewModel.descriptor.model, recordID: recordID)
        dismiss()
    }

    private var workflowActionConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingWorkflowAction != nil },
            set: { isPresented in
                if !isPresented {
                    pendingWorkflowAction = nil
                }
            }
        )
    }

    private func workflowActionTint(for action: ActionButton) -> Color {
        switch action.style {
        case "danger":
            return OrdoColors.danger
        case "secondary":
            return .secondary
        default:
            return OrdoColors.accent
        }
    }

    private func handleWorkflowActionTap(_ action: ActionButton) {
        guard !viewModel.isRunningWorkflowAction else { return }

        if let confirm = action.confirm, !confirm.isEmpty {
            pendingWorkflowAction = action
            return
        }

        Task {
            await executeWorkflowAction(action)
        }
    }

    private func executeWorkflowAction(_ action: ActionButton) async {
        let didRun = await viewModel.runWorkflowAction(action, using: appState)
        guard didRun, let updatedRecord = viewModel.record, let recordID = viewModel.recordID else { return }

        draft = FormDraft(record: updatedRecord)
        let displayName = updatedRecord["display_name"]?.displayText ?? updatedRecord["name"]?.displayText ?? "Record"
        recentItems.add(model: viewModel.descriptor.model, recordID: recordID, displayName: displayName)

        if viewModel.schema?.hasChatter == true {
            chatterViewModel = RecordChatterViewModel(model: viewModel.descriptor.model, recordID: recordID)
            await chatterViewModel.refresh(using: appState)
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
