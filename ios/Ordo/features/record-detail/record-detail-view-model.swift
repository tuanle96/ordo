import Combine
import Foundation

@MainActor
final class RecordDetailViewModel: ObservableObject {
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

        do {
            let schema = try await appState.apiClient.schema(model: descriptor.model, token: token)
            let record = try await appState.apiClient.record(
                model: descriptor.model,
                id: recordID,
                fields: schema.requestedFieldNames,
                token: token
            )
            self.schema = schema
            self.record = record
            cacheMessage = nil
            try? await appState.cacheStore.saveSchema(schema, for: descriptor.model, scope: cacheScope)
            try? await appState.cacheStore.saveRecord(record, for: descriptor.model, id: recordID, scope: cacheScope)
        } catch {
            if case APIClientError.unauthorized = error {
                appState.signOut()
            } else if schema == nil || record == nil {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func value(for field: FieldSchema) -> String? {
        guard let rawValue = record?[field.name], !rawValue.isVisuallyEmpty else { return nil }

        if field.type == .selection,
           let key = rawValue.stringValue,
           let option = field.selection?.first(where: { $0.first == key }),
           option.count > 1 {
            return option[1]
        }

        return rawValue.displayText
    }
}
