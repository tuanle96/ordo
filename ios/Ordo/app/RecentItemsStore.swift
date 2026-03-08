import Combine
import Foundation

struct RecentItem: Codable, Identifiable, Hashable {
    let model: String
    let recordID: Int
    let displayName: String
    let timestamp: Date

    var id: String { "\(model)-\(recordID)" }
}

final class RecentItemsStore: ObservableObject {
    private static let defaultStorageKey = "ordo.recentItems"
    private static let defaultMaxItems = 10

    private let defaults: UserDefaults
    private let storageKey: String
    private let maxItems: Int
    private let dateProvider: () -> Date

    @Published private(set) var items: [RecentItem] = []

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = defaultStorageKey,
        maxItems: Int = defaultMaxItems,
        dateProvider: @escaping () -> Date = Date.init,
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.maxItems = maxItems
        self.dateProvider = dateProvider
        load()
    }

    func add(model: String, recordID: Int, displayName: String) {
        var current = items
        current.removeAll { $0.model == model && $0.recordID == recordID }

        let item = RecentItem(
            model: model,
            recordID: recordID,
            displayName: displayName,
            timestamp: dateProvider()
        )
        current.insert(item, at: 0)

        if current.count > maxItems {
            current = Array(current.prefix(maxItems))
        }

        items = current
        save()
    }

    func clear() {
        items = []
        defaults.removeObject(forKey: storageKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([RecentItem].self, from: data) else {
            return
        }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
