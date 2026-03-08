import Foundation

struct ChatterAuthor: Codable, Hashable {
    let id: Int
    let name: String
    let type: String
}

struct ChatterMessage: Codable, Hashable, Identifiable {
    let id: Int
    let body: String
    let plainBody: String
    let date: String
    let messageType: String
    let isNote: Bool
    let isDiscussion: Bool
    let author: ChatterAuthor?

    var authorName: String {
        author?.name ?? "System"
    }

    var displayBody: String {
        let trimmed = plainBody.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    var relativeTimestamp: String {
        guard let parsed = Self.serverDateFormatter.date(from: date) else { return date }
        return Self.relativeDateFormatter.localizedString(for: parsed, relativeTo: Date())
    }

    private static let serverDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let relativeDateFormatter = RelativeDateTimeFormatter()
}

struct ChatterThreadResult: Codable, Hashable {
    let messages: [ChatterMessage]
    let limit: Int
    let hasMore: Bool
    let nextBefore: Int?
}

struct PostChatterNoteRequest: Codable {
    let body: String
}