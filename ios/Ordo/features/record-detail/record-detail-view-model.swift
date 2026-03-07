import Combine
import Foundation
import OSLog

@MainActor
final class RecordDetailViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.ordo.app", category: "record-detail")

    @Published private(set) var schema: MobileFormSchema?
    @Published private(set) var record: RecordData?
    @Published private(set) var errorMessage: String?
    @Published private(set) var cacheMessage: String?
    @Published private(set) var isLoading = false

    let descriptor: ModelDescriptor
    let recordID: Int

    init(descriptor: ModelDescriptor, recordID: Int) {
        self.descriptor = descriptor
        self.recordID = recordID
    }

    func load(using appState: AppState) async {
        guard let token = appState.session?.accessToken else {
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
            let schema = try await appState.apiClient.schema(model: descriptor.model, token: token)
            Self.logger.debug("📐 Schema OK — \(schema.requestedFieldNames.count, privacy: .public) fields")

            Self.logger.debug("📄 Fetching record \(self.descriptor.model, privacy: .public)#\(self.recordID, privacy: .public) with fields: \(schema.requestedFieldNames.joined(separator: ", "), privacy: .public)")
            let record = try await appState.apiClient.record(
                model: descriptor.model,
                id: recordID,
                fields: schema.requestedFieldNames,
                token: token
            )
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
}
