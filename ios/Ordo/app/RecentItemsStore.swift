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
    private static let storageKey = "ordo.recentItems"
    private static let maxItems = 10

    @Published private(set) var items: [RecentItem] = []

    init() {
        load()
    }

    func add(model: String, recordID: Int, displayName: String) {
        var current = items
        current.removeAll { $0.model == model && $0.recordID == recordID }

        let item = RecentItem(
            model: model,
            recordID: recordID,
            displayName: displayName,
            timestamp: Date()
        )
        current.insert(item, at: 0)

        if current.count > Self.maxItems {
            current = Array(current.prefix(Self.maxItems))
        }

        items = current
        save()
    }

    func clear() {
        items = []
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([RecentItem].self, from: data) else {
            return
        }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
