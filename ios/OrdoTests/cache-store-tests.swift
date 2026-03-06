import Foundation
import Testing
@testable import Ordo

struct CacheStoreTests {
    private let scope = CacheScope(namespace: "test-scope")

    @Test
    func schemaRoundTrip() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let store = FileCacheStore(baseDirectoryURL: directoryURL)
        let schema = MobileFormSchema(
            model: "res.partner",
            title: "Contact",
            header: FormHeader(statusbar: nil, actions: []),
            sections: [FormSection(label: "Main", fields: [FieldSchema(name: "name", type: .char, label: "Name", required: nil, readonly: nil, invisible: nil, domain: nil, comodel: nil, selection: nil, currencyField: nil, placeholder: nil, digits: nil, subfields: nil, searchable: nil, widget: nil)])],
            tabs: [],
            hasChatter: false
        )

        try await store.saveSchema(schema, for: schema.model, scope: scope)
        let cached = await store.loadSchema(for: schema.model, scope: scope)

        #expect(cached?.value == schema)
    }

    @Test
    func listPageRoundTripAndClear() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let store = FileCacheStore(baseDirectoryURL: directoryURL)
        let list = RecordListResult(
            items: [["id": .number(1), "name": .string("Azure Interior")]],
            limit: 30,
            offset: 0
        )

        try await store.saveListPage(list, for: "res.partner", limit: 30, offset: 0, scope: scope)
        let cached = await store.loadListPage(for: "res.partner", limit: 30, offset: 0, scope: scope)
        #expect(cached?.value.items.count == 1)

        try await store.clear(scope: scope)
        let cleared = await store.loadListPage(for: "res.partner", limit: 30, offset: 0, scope: scope)

        #expect(cleared == nil)
        }
    }
