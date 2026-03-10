import Foundation
import Testing
@testable import Ordo

struct MutationQueueStoreTests {
    @Test
    func enqueueLoadAndRemovePersistQueuedMutations() async throws {
        let store = FileMutationQueueStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        let scope = CacheScope(namespace: "scope-a")
        let mutation = QueuedRecordMutation(model: "res.partner", recordID: 7, kind: .update, values: ["name": .string("Queued")], fields: ["name"])

        try await store.enqueue(mutation, scope: scope)
        let loaded = await store.load(scope: scope)

        #expect(loaded == [mutation])
        #expect(await store.pendingCount(scope: scope) == 1)

        try await store.remove(id: mutation.id, scope: scope)

        #expect(await store.load(scope: scope).isEmpty)
        #expect(await store.pendingCount(scope: scope) == 0)
    }

    @Test
    func enqueueReplacesEquivalentPendingMutationForSameRecordIntent() async throws {
        let store = FileMutationQueueStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        let scope = CacheScope(namespace: "scope-b")
        let first = QueuedRecordMutation(model: "res.partner", recordID: 7, kind: .update, values: ["name": .string("First")], fields: ["name"])
        let second = QueuedRecordMutation(model: "res.partner", recordID: 7, kind: .update, values: ["name": .string("Second")], fields: ["name"])

        try await store.enqueue(first, scope: scope)
        try await store.enqueue(second, scope: scope)

        let loaded = await store.load(scope: scope)
        #expect(loaded.count == 1)
        #expect(loaded.first?.values["name"] == .string("Second"))
    }

    @Test
    func clearRemovesAllQueuedMutationsForScope() async throws {
        let store = FileMutationQueueStore(baseDirectoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        let scope = CacheScope(namespace: "scope-c")

        try await store.enqueue(
            QueuedRecordMutation(model: "res.partner", recordID: 7, kind: .update, values: ["name": .string("Queued")], fields: ["name"]),
            scope: scope
        )
        try await store.enqueue(
            QueuedRecordMutation(model: "sale.order", recordID: 11, kind: .action, fields: ["state"], actionName: "action_confirm"),
            scope: scope
        )

        #expect(await store.pendingCount(scope: scope) == 2)

        try await store.clear(scope: scope)

        #expect(await store.load(scope: scope).isEmpty)
        #expect(await store.pendingCount(scope: scope) == 0)
    }
}