import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class RecordDetailViewModel {
    private static let logger = Logger(subsystem: "com.ordo.app", category: "record-detail")
    private let onchangeDebounce = Duration.milliseconds(300)

    private(set) var schema: MobileFormSchema?
    private(set) var record: RecordData?
    private(set) var errorMessage: String?
    private(set) var cacheMessage: String?
    private(set) var saveMessage: String?
    private(set) var onchangeWarnings: [OnchangeWarning] = []
    private(set) var onchangeDomains: [String: JSONValue] = [:]
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var isDeleting = false
    private(set) var runningActionName: String?
    private(set) var validationErrors: [String: String] = [:]

    let descriptor: ModelDescriptor
    private(set) var recordID: Int?
    private var onchangeTask: Task<Void, Never>?
    private var onchangeGeneration = 0

    init(descriptor: ModelDescriptor, recordID: Int?) {
        self.descriptor = descriptor
        self.recordID = recordID
    }

    var isCreating: Bool {
        recordID == nil
    }

    var isRunningWorkflowAction: Bool {
        runningActionName != nil
    }

    var canDelete: Bool {
        !isCreating && recordID != nil && !isDeleting && !isSaving && runningActionName == nil
    }

    var visibleWorkflowActions: [ActionButton] {
        guard let schema, let record, !isCreating else { return [] }
        return schema.header.actions.filter { !$0.isInvisible(in: record) }
    }

    func isRunningAction(_ action: ActionButton) -> Bool {
        runningActionName == action.name
    }

    func load(using appState: AppState) async {
        guard appState.session?.accessToken != nil else {
            errorMessage = "Sign in again to load this record."
            return
        }

        isLoading = true
        errorMessage = nil
        cacheMessage = nil
        saveMessage = nil
        resetOnchangeState()

        if isCreating {
            await loadCreateSchema(using: appState)
            return
        }

        guard let recordID, let cacheScope = appState.cacheScope else {
            errorMessage = "Sign in again to load this record."
            isLoading = false
            return
        }

        let cachedSchema = await appState.cacheStore.loadSchema(for: descriptor.model, scope: cacheScope)
        let cachedRecord = await appState.cacheStore.loadRecord(for: descriptor.model, id: recordID, scope: cacheScope)

        if let cachedSchema, let cachedRecord {
            schema = cachedSchema.value
            record = cachedRecord.value
            cacheMessage = "Showing saved data from \(cachedRecord.relativeTimestamp)."
        }

        Self.logger.info("⏳ Loading record \(self.descriptor.model, privacy: .public)#\(recordID, privacy: .public)")

        do {
            let schema = try await appState.withAuthenticatedToken { [self] token in
                try await appState.apiClient.schema(model: self.descriptor.model, token: token)
            }

            let record = try await appState.withAuthenticatedToken { [self] token in
                try await appState.apiClient.record(
                    model: self.descriptor.model,
                    id: recordID,
                    fields: schema.requestedFieldNames,
                    token: token
                )
            }

            self.schema = schema
            self.record = record
            cacheMessage = nil

            do {
                try await appState.cacheStore.saveSchema(schema, for: descriptor.model, scope: cacheScope)
            } catch {
                Self.logger.error("Failed to save schema cache for \(self.descriptor.model, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }

            do {
                try await appState.cacheStore.saveRecord(record, for: descriptor.model, id: recordID, scope: cacheScope)
            } catch {
                Self.logger.error("Failed to save record cache for \(self.descriptor.model, privacy: .public)#\(recordID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            Self.logger.error("❌ Failed to load \(self.descriptor.model, privacy: .public)#\(recordID, privacy: .public): \(String(describing: error), privacy: .public)")
            if case APIClientError.unauthorized = error {
                appState.signOut()
            } else if schema == nil || record == nil {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func startEditing() -> FormDraft? {
        guard let record else { return nil }
        validationErrors = [:]
        saveMessage = nil
        errorMessage = nil
        resetOnchangeFeedback()
        return FormDraft(record: record)
    }

    func hasUnsavedChanges(draft: FormDraft?) -> Bool {
        guard let draft, let record else { return false }
        return draft.isDirty(comparedTo: record, fields: editableFields(using: draft.values))
    }

    func canSave(draft: FormDraft?) -> Bool {
        guard draft != nil else { return false }
        return isCreating ? !isSaving : (!isSaving && hasUnsavedChanges(draft: draft))
    }

    func discardEditing() {
        cancelPendingOnchange()
        validationErrors = [:]
        saveMessage = nil
        resetOnchangeFeedback()
    }

    func applyFieldEdit(_ value: JSONValue?, for field: FieldSchema, draft: FormDraft, using appState: AppState) {
        draft.setValue(value, for: field.name)
        validationErrors.removeValue(forKey: field.name)
        saveMessage = nil
        errorMessage = nil

        guard field.onchange != nil else { return }
        scheduleOnchange(for: field, draft: draft, using: appState)
    }

    func waitForOnchangeToSettle() async {
        await onchangeTask?.value
    }

    func save(draft: FormDraft, using appState: AppState) async -> Bool {
        guard let schema, let record else { return false }
        cancelPendingOnchange()

        let wasCreating = isCreating
        let editableFields = editableFields(using: draft.values)
        let localValidationErrors = draft.validationErrors(for: editableFields)

        validationErrors = localValidationErrors
        errorMessage = nil

        guard localValidationErrors.isEmpty else {
            return false
        }

        let changedValues = draft.changedValues(comparedTo: record, fields: editableFields)
        guard !changedValues.isEmpty else {
            return true
        }

        isSaving = true
        saveMessage = nil
        defer { isSaving = false }

        do {
            let result = try await appState.withAuthenticatedToken { [self] token in
                if let recordID = self.recordID {
                    return try await appState.apiClient.updateRecord(
                        model: self.descriptor.model,
                        id: recordID,
                        values: changedValues,
                        fields: schema.requestedFieldNames,
                        token: token
                    )
                }

                return try await appState.apiClient.createRecord(
                    model: self.descriptor.model,
                    values: changedValues,
                    fields: schema.requestedFieldNames,
                    token: token
                )
            }

            self.recordID = result.id
            self.record = result.record
            cacheMessage = nil
            validationErrors = [:]
            errorMessage = nil
            saveMessage = wasCreating ? "Record created." : "Changes saved."
            resetOnchangeFeedback()

            if let recordID = self.recordID, let cacheScope = appState.cacheScope {
                do {
                    try await appState.cacheStore.saveRecord(result.record, for: descriptor.model, id: recordID, scope: cacheScope)
                } catch {
                    Self.logger.error("Failed to save record cache after mutation for \(self.descriptor.model, privacy: .public)#\(recordID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }

            return true
        } catch {
            let targetRecordID = self.recordID ?? 0
            Self.logger.error("❌ Failed to save \(self.descriptor.model, privacy: .public)#\(targetRecordID, privacy: .public): \(String(describing: error), privacy: .public)")
            if case APIClientError.unauthorized = error {
                appState.signOut()
            } else {
                errorMessage = error.localizedDescription
            }

            return false
        }
    }

    func runWorkflowAction(_ action: ActionButton, using appState: AppState) async -> Bool {
        guard let schema, let recordID else { return false }
        guard runningActionName == nil else { return false }

        runningActionName = action.name
        errorMessage = nil
        saveMessage = nil
        defer { runningActionName = nil }

        do {
            let result = try await appState.withAuthenticatedToken { [self] token in
                try await appState.apiClient.runRecordAction(
                    model: self.descriptor.model,
                    id: recordID,
                    actionName: action.name,
                    fields: schema.requestedFieldNames,
                    token: token
                )
            }

            let refreshedRecord = try await resolvedActionRecord(from: result, schema: schema, using: appState)
            record = refreshedRecord
            cacheMessage = nil
            errorMessage = nil
            validationErrors = [:]
            saveMessage = result.changed ? "\(action.label) completed." : "No changes from \(action.label.lowercased())."

            if let cacheScope = appState.cacheScope {
                do {
                    try await appState.cacheStore.saveRecord(refreshedRecord, for: descriptor.model, id: recordID, scope: cacheScope)
                } catch {
                    Self.logger.error("Failed to save record cache after workflow action for \(self.descriptor.model, privacy: .public)#\(recordID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }

            return true
        } catch {
            Self.logger.error("❌ Failed to run action \(action.name, privacy: .public) for \(self.descriptor.model, privacy: .public)#\(recordID, privacy: .public): \(String(describing: error), privacy: .public)")
            if case APIClientError.unauthorized = error {
                appState.signOut()
            } else {
                errorMessage = error.localizedDescription
            }

            return false
        }
    }

    func deleteRecord(using appState: AppState) async -> Bool {
        guard let recordID, !isCreating, !isDeleting else { return false }

        isDeleting = true
        errorMessage = nil
        saveMessage = nil
        defer { isDeleting = false }

        do {
            _ = try await appState.withAuthenticatedToken { [self] token in
                try await appState.apiClient.deleteRecord(
                    model: self.descriptor.model,
                    id: recordID,
                    token: token
                )
            }

            validationErrors = [:]
            cacheMessage = nil
            errorMessage = nil
            resetOnchangeState()
            return true
        } catch {
            Self.logger.error("❌ Failed to delete \(self.descriptor.model, privacy: .public)#\(recordID, privacy: .public): \(String(describing: error), privacy: .public)")
            if case APIClientError.unauthorized = error {
                appState.signOut()
            } else {
                errorMessage = error.localizedDescription
            }

            return false
        }
    }

    private func editableFields(using values: RecordData) -> [FieldSchema] {
        guard let schema else { return [] }

        return schema.allFields.filter { field in
            !field.isInvisible(in: values)
                && !field.isReadOnly(in: values)
                && EditableFieldFactory.model(for: field) != nil
        }
    }

    private func scheduleOnchange(for field: FieldSchema, draft: FormDraft, using appState: AppState) {
        guard let schema, let record else { return }

        cancelPendingOnchange()
        resetOnchangeFeedback()

        onchangeGeneration += 1
        let generation = onchangeGeneration
        let protectedVersions = draft.editVersions
        let requestValues = draft.onchangeValues(comparedTo: record, fields: schema.allFields)
        let shouldDebounce = shouldDebounceOnchange(for: field)

        onchangeTask = Task { [weak self] in
            await self?.runOnchange(
                field: field,
                draft: draft,
                using: appState,
                generation: generation,
                protectedVersions: protectedVersions,
                requestValues: requestValues,
                debounce: shouldDebounce
            )
        }
    }

    private func runOnchange(
        field: FieldSchema,
        draft: FormDraft,
        using appState: AppState,
        generation: Int,
        protectedVersions: [String: Int],
        requestValues: RecordData,
        debounce: Bool
    ) async {
        do {
            if debounce {
                try await Task.sleep(for: onchangeDebounce)
            }

            guard !Task.isCancelled, generation == onchangeGeneration, let schema else { return }

            let result = try await appState.withAuthenticatedToken { [self] token in
                try await appState.apiClient.onchange(
                    model: self.descriptor.model,
                    values: requestValues,
                    triggerField: field.name,
                    recordId: self.recordID,
                    fields: schema.requestedFieldNames,
                    token: token
                )
            }

            guard !Task.isCancelled, generation == onchangeGeneration else { return }

            let fieldsByName = Dictionary(uniqueKeysWithValues: schema.allFields.map { ($0.name, $0) })
            _ = draft.mergeOnchangeValues(
                result.values,
                fieldsByName: fieldsByName,
                protectingEditsAfter: protectedVersions
            )

            onchangeWarnings = result.warnings ?? []
            onchangeDomains = result.domains ?? [:]
            validationErrors = draft.validationErrors(for: editableFields(using: draft.values))
        } catch {
            guard !(error is CancellationError) else { return }

            Self.logger.error("⚠️ Onchange failed for \(self.descriptor.model, privacy: .public).\(field.name, privacy: .public): \(error.localizedDescription, privacy: .public)")

            if case APIClientError.unauthorized = error {
                appState.signOut()
            }
        }
    }

    private func shouldDebounceOnchange(for field: FieldSchema) -> Bool {
        switch field.type {
        case .char, .text, .integer, .float, .monetary, .html:
            return true
        default:
            return false
        }
    }

    private func cancelPendingOnchange() {
        onchangeTask?.cancel()
        onchangeTask = nil
        onchangeGeneration += 1
    }

    private func resolvedActionRecord(
        from result: RecordActionResult,
        schema: MobileFormSchema,
        using appState: AppState
    ) async throws -> RecordData {
        if let record = result.record {
            return record
        }

        return try await appState.withAuthenticatedToken { [self] token in
            try await appState.apiClient.record(
                model: self.descriptor.model,
                id: result.id,
                fields: schema.requestedFieldNames,
                token: token
            )
        }
    }

    private func resetOnchangeFeedback() {
        onchangeWarnings = []
        onchangeDomains = [:]
    }

    private func resetOnchangeState() {
        cancelPendingOnchange()
        resetOnchangeFeedback()
    }

    private func loadCreateSchema(using appState: AppState) async {
        do {
            let schema = try await appState.withAuthenticatedToken { [self] token in
                try await appState.apiClient.schema(model: self.descriptor.model, token: token)
            }

            self.schema = schema
            let defaultFieldNames = defaultValueFieldNames(for: schema)

            do {
                self.record = try await appState.withAuthenticatedToken { [self] token in
                    try await appState.apiClient.defaultValues(
                        model: self.descriptor.model,
                        fields: defaultFieldNames,
                        token: token
                    )
                }
                errorMessage = nil
            } catch {
                if case APIClientError.unauthorized = error {
                    appState.signOut()
                    isLoading = false
                    return
                }

                Self.logger.error("⚠️ Failed to load create defaults for \(self.descriptor.model, privacy: .public): \(String(describing: error), privacy: .public)")
                self.record = [:]
                errorMessage = "Couldn’t load server defaults. You can still enter values manually."
            }

            cacheMessage = nil
        } catch {
            Self.logger.error("❌ Failed to load create schema for \(self.descriptor.model, privacy: .public): \(String(describing: error), privacy: .public)")
            if case APIClientError.unauthorized = error {
                appState.signOut()
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func defaultValueFieldNames(for schema: MobileFormSchema) -> [String] {
        var fields = schema.allFields.map(\.name)

        if let statusField = schema.header.statusbar?.field {
            fields.append(statusField)
        }

        return Array(Set(fields)).sorted()
    }
}
