import Foundation
import CryptoKit

protocol CacheStoring {
    func loadSchema(for model: String, scope: CacheScope) async -> CachedValue<MobileFormSchema>?
    func saveSchema(_ schema: MobileFormSchema, for model: String, scope: CacheScope) async throws
    func loadRecord(for model: String, id: Int, scope: CacheScope) async -> CachedValue<RecordData>?
    func saveRecord(_ record: RecordData, for model: String, id: Int, scope: CacheScope) async throws
    func loadListPage(for model: String, limit: Int, offset: Int, scope: CacheScope) async -> CachedValue<RecordListResult>?
    func saveListPage(_ result: RecordListResult, for model: String, limit: Int, offset: Int, scope: CacheScope) async throws
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

    init(
        baseDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.baseDirectoryURL = baseDirectoryURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "OrdoCache", directoryHint: .isDirectory)
    }

    func loadSchema(for model: String, scope: CacheScope) async -> CachedValue<MobileFormSchema>? {
        await loadValue(at: fileURL(for: .schema(model), scope: scope))
    }

    func saveSchema(_ schema: MobileFormSchema, for model: String, scope: CacheScope) async throws {
        try await saveValue(schema, at: fileURL(for: .schema(model), scope: scope))
    }

    func loadRecord(for model: String, id: Int, scope: CacheScope) async -> CachedValue<RecordData>? {
        await loadValue(at: fileURL(for: .record(model: model, id: id), scope: scope))
    }

    func saveRecord(_ record: RecordData, for model: String, id: Int, scope: CacheScope) async throws {
        try await saveValue(record, at: fileURL(for: .record(model: model, id: id), scope: scope))
    }

    func loadListPage(for model: String, limit: Int, offset: Int, scope: CacheScope) async -> CachedValue<RecordListResult>? {
        await loadValue(at: fileURL(for: .list(model: model, limit: limit, offset: offset), scope: scope))
    }

    func saveListPage(_ result: RecordListResult, for model: String, limit: Int, offset: Int, scope: CacheScope) async throws {
        try await saveValue(result, at: fileURL(for: .list(model: model, limit: limit, offset: offset), scope: scope))
    }

    func clear(scope: CacheScope? = nil) async throws {
        let targetURL = scope.map { scopedDirectoryURL(for: $0) } ?? baseDirectoryURL
        guard fileManager.fileExists(atPath: targetURL.path()) else { return }
        try fileManager.removeItem(at: targetURL)
    }

    private func saveValue<Value: Codable>(_ value: Value, at url: URL) async throws {
        try ensureDirectoryExists(for: url.deletingLastPathComponent())
        let envelope = CacheEnvelope(cachedAt: .now, value: value)
        let data = try encoder.encode(envelope)
        try data.write(to: url, options: .atomic)
    }

    private func loadValue<Value: Codable>(at url: URL) async -> CachedValue<Value>? {
        guard fileManager.fileExists(atPath: url.path()) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let envelope = try decoder.decode(CacheEnvelope<Value>.self, from: data)
            return CachedValue(value: envelope.value, cachedAt: envelope.cachedAt)
        } catch {
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

private enum CacheKey {
    case schema(String)
    case record(model: String, id: Int)
    case list(model: String, limit: Int, offset: Int)

    var filename: String {
        switch self {
        case .schema(let model):
            return "schema-\(safe(model)).json"
        case .record(let model, let id):
            return "record-\(safe(model))-\(id).json"
        case .list(let model, let limit, let offset):
            return "list-\(safe(model))-\(limit)-\(offset).json"
        }
    }

    private func safe(_ value: String) -> String {
        let data = Data(value.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
