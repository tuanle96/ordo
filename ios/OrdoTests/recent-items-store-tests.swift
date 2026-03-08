import Foundation
import Testing
@testable import Ordo

@MainActor
struct RecentItemsStoreTests {
    @Test
    func addMovesExistingRecordToFrontAndHonorsCap() {
        let suiteName = "com.ordo.app.tests.recent-items.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var tick = 0
        let store = RecentItemsStore(
            defaults: defaults,
            storageKey: "recent-items",
            maxItems: 3,
            dateProvider: {
                tick += 1
                return Date(timeIntervalSince1970: TimeInterval(tick))
            }
        )

        store.add(model: "res.partner", recordID: 1, displayName: "Azure Interior")
        store.add(model: "crm.lead", recordID: 2, displayName: "Website redesign")
        store.add(model: "sale.order", recordID: 3, displayName: "S00045")
        store.add(model: "res.partner", recordID: 1, displayName: "Azure Interior (Updated)")
        store.add(model: "res.partner", recordID: 4, displayName: "Gemini Furniture")

        #expect(store.items.count == 3)
        #expect(store.items.map(\.id) == ["res.partner-4", "res.partner-1", "sale.order-3"])
        #expect(store.items[1].displayName == "Azure Interior (Updated)")
    }

    @Test
    func persistedItemsReloadAndClearRemovesStoredState() {
        let suiteName = "com.ordo.app.tests.recent-items.persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstStore = RecentItemsStore(defaults: defaults, storageKey: "recent-items-test")
        firstStore.add(model: "res.partner", recordID: 1, displayName: "Azure Interior")
        firstStore.add(model: "crm.lead", recordID: 2, displayName: "Website redesign")

        let secondStore = RecentItemsStore(defaults: defaults, storageKey: "recent-items-test")
        #expect(secondStore.items.map(\.id) == ["crm.lead-2", "res.partner-1"])

        secondStore.clear()

        let thirdStore = RecentItemsStore(defaults: defaults, storageKey: "recent-items-test")
        #expect(thirdStore.items.isEmpty)
    }
}