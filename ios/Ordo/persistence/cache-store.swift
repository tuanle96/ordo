import CryptoKit
import Foundation
import OSLog

protocol CacheStoring {
    func loadSchema(for model: String, scope: CacheScope) async -> CachedValue<MobileFormSchema>?
    func saveSchema(_ schema: MobileFormSchema, for model: String, scope: CacheScope) async throws
    func loadRecord(for model: String, id: Int, scope: CacheScope) async -> CachedValue<RecordData>?
    func saveRecord(_ record: RecordData, for model: String, id: Int, scope: CacheScope) async throws
    func deleteRecord(for model: String, id: Int, scope: CacheScope) async throws
    func loadListPage(for model: String, limit: Int, offset: Int, order: String?, domainKey: String?, fieldKey: String?, scope: CacheScope) async -> CachedValue<RecordListResult>?
    func saveListPage(_ result: RecordListResult, for model: String, limit: Int, offset: Int, order: String?, domainKey: String?, fieldKey: String?, scope: CacheScope) async throws
    func clear(scope: CacheScope?) async throws
}

struct CacheScope: Hashable {
    let namespace: String
}

struct CachedValue<Value> {
    let value: Value
    let cachedAt: Date

    var relativeTimestamp: String {
        RelativeDateTimeFormatter().localizedString(for: cachedAt, relativeTo: .now)
    }
}

private struct CacheEnvelope<Value: Codable>: Codable {
    let cachedAt: Date
    let value: Value
}

actor FileCacheStore: CacheStoring {
    private let baseDirectoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager
    private let dateProvider: @Sendable () -> Date
    private let logger = Logger(subsystem: "com.ordo.app", category: "cache-store")

    nonisolated init() {
        let fileManager = FileManager.default
        self.fileManager = fileManager
        self.dateProvider = Date.init
        self.baseDirectoryURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "OrdoCache", directoryHint: .isDirectory)
    }

    nonisolated init(baseDirectoryURL: URL) {
        self.fileManager = .default
        self.dateProvider = Date.init
        self.baseDirectoryURL = baseDirectoryURL
    }

    nonisolated init(baseDirectoryURL: URL, fileManager: FileManager) {
        self.fileManager = fileManager
        self.dateProvider = Date.init
        self.baseDirectoryURL = baseDirectoryURL
    }

    nonisolated init(baseDirectoryURL: URL, dateProvider: @escaping @Sendable () -> Date) {
        self.fileManager = .default
        self.dateProvider = dateProvider
        self.baseDirectoryURL = baseDirectoryURL
    }

    nonisolated init(
        baseDirectoryURL: URL,
        fileManager: FileManager,
        dateProvider: @escaping @Sendable () -> Date
    ) {
        self.fileManager = fileManager
        self.dateProvider = dateProvider
        self.baseDirectoryURL = baseDirectoryURL
    }

    func loadSchema(for model: String, scope: CacheScope) async -> CachedValue<MobileFormSchema>? {
        await loadValue(at: fileURL(for: .schema(model), scope: scope), lifetime: .schema)
    }

    func saveSchema(_ schema: MobileFormSchema, for model: String, scope: CacheScope) async throws {
        try await saveValue(schema, at: fileURL(for: .schema(model), scope: scope))
    }

    func loadRecord(for model: String, id: Int, scope: CacheScope) async -> CachedValue<RecordData>? {
        await loadValue(at: fileURL(for: .record(model: model, id: id), scope: scope), lifetime: .record)
    }

    func saveRecord(_ record: RecordData, for model: String, id: Int, scope: CacheScope) async throws {
        try await saveValue(record, at: fileURL(for: .record(model: model, id: id), scope: scope))
    }

    func deleteRecord(for model: String, id: Int, scope: CacheScope) async throws {
        let url = fileURL(for: .record(model: model, id: id), scope: scope)
        guard fileManager.fileExists(atPath: url.path()) else { return }
        try fileManager.removeItem(at: url)
    }

    func loadListPage(for model: String, limit: Int, offset: Int, order: String? = nil, domainKey: String? = nil, fieldKey: String? = nil, scope: CacheScope) async -> CachedValue<RecordListResult>? {
        await loadValue(at: fileURL(for: .list(model: model, limit: limit, offset: offset, order: order, domainKey: domainKey, fieldKey: fieldKey), scope: scope), lifetime: .list)
    }

    func saveListPage(_ result: RecordListResult, for model: String, limit: Int, offset: Int, order: String? = nil, domainKey: String? = nil, fieldKey: String? = nil, scope: CacheScope) async throws {
        try await saveValue(result, at: fileURL(for: .list(model: model, limit: limit, offset: offset, order: order, domainKey: domainKey, fieldKey: fieldKey), scope: scope))
    }

    func clear(scope: CacheScope? = nil) async throws {
        let targetURL = scope.map { scopedDirectoryURL(for: $0) } ?? baseDirectoryURL
        guard fileManager.fileExists(atPath: targetURL.path()) else { return }
        try fileManager.removeItem(at: targetURL)
    }

    private func saveValue<Value: Codable>(_ value: Value, at url: URL) async throws {
        try ensureDirectoryExists(for: url.deletingLastPathComponent())
        let envelope = CacheEnvelope(cachedAt: dateProvider(), value: value)
        let data = try encoder.encode(envelope)
        try data.write(to: url, options: .atomic)
    }

    private func loadValue<Value: Codable>(at url: URL, lifetime: CacheLifetime) async -> CachedValue<Value>? {
        guard fileManager.fileExists(atPath: url.path()) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let envelope = try decoder.decode(CacheEnvelope<Value>.self, from: data)

            if envelope.cachedAt.addingTimeInterval(lifetime.ttl) <= dateProvider() {
                logger.debug("Removing expired cache entry at \(url.lastPathComponent, privacy: .public)")
                try? fileManager.removeItem(at: url)
                return nil
            }

            return CachedValue(value: envelope.value, cachedAt: envelope.cachedAt)
        } catch {
            logger.error("Failed to load cache entry \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            try? fileManager.removeItem(at: url)
            return nil
        }
    }

    private func ensureDirectoryExists(for directoryURL: URL) throws {
        guard !fileManager.fileExists(atPath: directoryURL.path()) else { return }
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func fileURL(for key: CacheKey, scope: CacheScope) -> URL {
        scopedDirectoryURL(for: scope).appending(path: key.filename)
    }

    private func scopedDirectoryURL(for scope: CacheScope) -> URL {
        baseDirectoryURL.appending(path: scope.namespace, directoryHint: .isDirectory)
    }
}

private enum CacheLifetime {
    case schema
    case record
    case list

    var ttl: TimeInterval {
        switch self {
        case .schema:
            7 * 24 * 60 * 60
        case .record, .list:
            24 * 60 * 60
        }
    }
}

private enum CacheKey {
    case schema(String)
    case record(model: String, id: Int)
    case list(model: String, limit: Int, offset: Int, order: String?, domainKey: String?, fieldKey: String?)

    var filename: String {
        switch self {
        case .schema(let model):
            return "schema-\(safe(model)).json"
        case .record(let model, let id):
            return "record-\(safe(model))-\(id).json"
        case .list(let model, let limit, let offset, let order, let domainKey, let fieldKey):
            return "list-\(safe(model))-\(safe(order ?? "default"))-\(safe(domainKey ?? "domain-default"))-\(safe(fieldKey ?? "fields-default"))-\(limit)-\(offset).json"
        }
    }

    private func safe(_ value: String) -> String {
        let data = Data(value.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
