import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class RecordDetailViewModel {
    private static let logger = Logger(subsystem: "com.ordo.app", category: "record-detail")

    private(set) var schema: MobileFormSchema?
    private(set) var record: RecordData?
    private(set) var errorMessage: String?
    private(set) var cacheMessage: String?
    private(set) var saveMessage: String?
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var validationErrors: [String: String] = [:]

    let descriptor: ModelDescriptor
    let recordID: Int

    init(descriptor: ModelDescriptor, recordID: Int) {
        self.descriptor = descriptor
        self.recordID = recordID
    }

    func load(using appState: AppState) async {
        guard appState.session?.accessToken != nil else {
            errorMessage = "Sign in again to load this record."
            return
        }
        guard let cacheScope = appState.cacheScope else {
            errorMessage = "Sign in again to load this record."
            return
        }

        isLoading = true
        errorMessage = nil
        cacheMessage = nil
        saveMessage = nil

        let cachedSchema = await appState.cacheStore.loadSchema(for: descriptor.model, scope: cacheScope)
        let cachedRecord = await appState.cacheStore.loadRecord(for: descriptor.model, id: recordID, scope: cacheScope)

        if let cachedSchema, let cachedRecord {
            schema = cachedSchema.value
            record = cachedRecord.value
            cacheMessage = "Showing saved data from \(cachedRecord.relativeTimestamp)."
        }

        Self.logger.info("⏳ Loading record \(self.descriptor.model, privacy: .public)#\(self.recordID, privacy: .public)")

        do {
            Self.logger.debug("📐 Fetching schema for \(self.descriptor.model, privacy: .public)…")
            let schema = try await appState.withAuthenticatedToken { [self] token in
                try await appState.apiClient.schema(model: self.descriptor.model, token: token)
            }
            Self.logger.debug("📐 Schema OK — \(schema.requestedFieldNames.count, privacy: .public) fields")

            Self.logger.debug("📄 Fetching record \(self.descriptor.model, privacy: .public)#\(self.recordID, privacy: .public) with fields: \(schema.requestedFieldNames.joined(separator: ", "), privacy: .public)")
            let record = try await appState.withAuthenticatedToken { [self] token in
                try await appState.apiClient.record(
                    model: self.descriptor.model,
                    id: self.recordID,
                    fields: schema.requestedFieldNames,
                    token: token
                )
            }
            Self.logger.debug("📄 Record OK — \(record.count, privacy: .public) keys: \(record.keys.sorted().joined(separator: ", "), privacy: .public)")

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
                Self.logger.error("Failed to save record cache for \(self.descriptor.model, privacy: .public)#\(self.recordID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            Self.logger.error("❌ Failed to load \(self.descriptor.model, privacy: .public)#\(self.recordID, privacy: .public): \(String(describing: error), privacy: .public)")
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
        return FormDraft(record: record)
    }

    func hasUnsavedChanges(draft: FormDraft?) -> Bool {
        guard let draft, let record else { return false }
        return draft.isDirty(comparedTo: record, fields: editableFields(using: draft.values))
    }

    func canSave(draft: FormDraft?) -> Bool {
        guard let draft else { return false }
        return !isSaving && hasUnsavedChanges(draft: draft)
    }

    func discardEditing() {
        validationErrors = [:]
        saveMessage = nil
    }

    func save(draft: FormDraft, using appState: AppState) async -> Bool {
        guard let schema, let record else { return false }

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

        defer {
            isSaving = false
        }

        do {
            let result = try await appState.withAuthenticatedToken { [self] token in
                try await appState.apiClient.updateRecord(
                    model: self.descriptor.model,
                    id: self.recordID,
                    values: changedValues,
                    fields: schema.requestedFieldNames,
                    token: token
                )
            }

            self.record = result.record
            cacheMessage = nil
            validationErrors = [:]
            errorMessage = nil
            saveMessage = "Changes saved."

            if let cacheScope = appState.cacheScope {
                do {
                    try await appState.cacheStore.saveRecord(result.record, for: descriptor.model, id: recordID, scope: cacheScope)
                } catch {
                    Self.logger.error("Failed to save record cache after update for \(self.descriptor.model, privacy: .public)#\(self.recordID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }

            return true
        } catch {
            Self.logger.error("❌ Failed to save \(self.descriptor.model, privacy: .public)#\(self.recordID, privacy: .public): \(String(describing: error), privacy: .public)")
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
                && !field.isStaticallyReadOnly
                && EditableFieldFactory.model(for: field) != nil
        }
    }
}
