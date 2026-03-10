import Foundation

protocol MutationQueueStoring {
    func load(scope: CacheScope) async -> [QueuedRecordMutation]
    func enqueue(_ mutation: QueuedRecordMutation, scope: CacheScope) async throws
    func update(_ mutation: QueuedRecordMutation, scope: CacheScope) async throws
    func remove(id: UUID, scope: CacheScope) async throws
    func clear(scope: CacheScope) async throws
    func pendingCount(scope: CacheScope?) async -> Int
}

enum QueuedRecordMutationKind: String, Codable {
    case update
    case delete
    case action
}

struct QueuedRecordMutation: Codable, Identifiable, Hashable {
    let id: UUID
    let model: String
    let recordID: Int
    let kind: QueuedRecordMutationKind
    let values: RecordData
    let fields: [String]
    let actionName: String?
    let createdAt: Date
    var retryCount: Int
    var lastError: String?

    init(
        id: UUID = UUID(),
        model: String,
        recordID: Int,
        kind: QueuedRecordMutationKind,
        values: RecordData = [:],
        fields: [String],
        actionName: String? = nil,
        createdAt: Date = Date(),
        retryCount: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.model = model
        self.recordID = recordID
        self.kind = kind
        self.values = values
        self.fields = fields
        self.actionName = actionName
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.lastError = lastError
    }
}

actor FileMutationQueueStore: MutationQueueStoring {
    private let baseDirectoryURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    nonisolated init() {
        let fileManager = FileManager.default
        self.fileManager = fileManager
        self.baseDirectoryURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "OrdoMutationQueue", directoryHint: .isDirectory)
    }

    nonisolated init(baseDirectoryURL: URL) {
        self.fileManager = .default
        self.baseDirectoryURL = baseDirectoryURL
    }

    nonisolated init(baseDirectoryURL: URL, fileManager: FileManager) {
        self.fileManager = fileManager
        self.baseDirectoryURL = baseDirectoryURL
    }

    func load(scope: CacheScope) async -> [QueuedRecordMutation] {
        let url = queueFileURL(for: scope)
        guard fileManager.fileExists(atPath: url.path()) else { return [] }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([QueuedRecordMutation].self, from: data)
        } catch {
            try? fileManager.removeItem(at: url)
            return []
        }
    }

    func enqueue(_ mutation: QueuedRecordMutation, scope: CacheScope) async throws {
        var mutations = await load(scope: scope)
        // Keep only the most recent queued intent for the same record + operation shape.
        // This stays intentionally narrow: it avoids stacking duplicate retries without
        // pretending to merge different mutation kinds or action names into one smart sync plan.
        mutations.removeAll { existing in
            existing.model == mutation.model
                && existing.recordID == mutation.recordID
                && existing.kind == mutation.kind
                && existing.actionName == mutation.actionName
        }
        mutations.append(mutation)
        try save(mutations, scope: scope)
    }

    func update(_ mutation: QueuedRecordMutation, scope: CacheScope) async throws {
        var mutations = await load(scope: scope)
        guard let index = mutations.firstIndex(where: { $0.id == mutation.id }) else {
            try await enqueue(mutation, scope: scope)
            return
        }

        mutations[index] = mutation
        try save(mutations, scope: scope)
    }

    func remove(id: UUID, scope: CacheScope) async throws {
        let mutations = await load(scope: scope).filter { $0.id != id }
        try save(mutations, scope: scope)
    }

    func clear(scope: CacheScope) async throws {
        try save([], scope: scope)
    }

    func pendingCount(scope: CacheScope?) async -> Int {
        if let scope {
            return await load(scope: scope).count
        }

        guard fileManager.fileExists(atPath: baseDirectoryURL.path()) else { return 0 }
        let fileURLs = (try? fileManager.contentsOfDirectory(at: baseDirectoryURL, includingPropertiesForKeys: nil)) ?? []
        var total = 0

        for fileURL in fileURLs where fileURL.pathExtension == "json" {
            if let data = try? Data(contentsOf: fileURL),
               let mutations = try? decoder.decode([QueuedRecordMutation].self, from: data) {
                total += mutations.count
            }
        }

        return total
    }

    private func save(_ mutations: [QueuedRecordMutation], scope: CacheScope) throws {
        let url = queueFileURL(for: scope)
        let directory = url.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: directory.path()) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        if mutations.isEmpty {
            try? fileManager.removeItem(at: url)
            return
        }

        let data = try encoder.encode(mutations.sorted { $0.createdAt < $1.createdAt })
        try data.write(to: url, options: .atomic)
    }

    private func queueFileURL(for scope: CacheScope) -> URL {
        baseDirectoryURL
            .appending(path: scope.namespace, directoryHint: .isDirectory)
            .appending(path: "queue.json")
    }
}