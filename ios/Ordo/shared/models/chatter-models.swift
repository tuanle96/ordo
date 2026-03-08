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

struct ChatterFollower: Codable, Hashable, Identifiable {
    let id: Int
    let partnerId: Int
    let name: String
    let email: String?
    let isActive: Bool
    let isSelf: Bool
}

struct ChatterActivityAssignee: Codable, Hashable {
    let id: Int
    let name: String
}

struct ChatterActivityTypeOption: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let summary: String?
    let icon: String?
    let defaultNote: String?
}

struct ChatterActivity: Codable, Hashable, Identifiable {
    let id: Int
    let typeId: Int?
    let typeName: String
    let summary: String?
    let note: String
    let plainNote: String
    let dateDeadline: String
    let state: String
    let canWrite: Bool
    let assignedUser: ChatterActivityAssignee?

    var displaySummary: String {
        if let summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return summary
        }

        return typeName
    }

    var displayNote: String {
        let trimmed = plainNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No note" : trimmed
    }

    var relativeDeadline: String {
        guard let parsed = Self.serverDateFormatter.date(from: dateDeadline) else { return dateDeadline }
        return Self.relativeDateFormatter.localizedString(for: parsed, relativeTo: Date())
    }

    var stateLabel: String {
        state.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private static let serverDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
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

struct ChatterDetailsResult: Codable, Hashable {
    let followers: [ChatterFollower]
    let followersCount: Int
    let selfFollower: ChatterFollower?
    let activities: [ChatterActivity]
    let availableActivityTypes: [ChatterActivityTypeOption]
}

struct PostChatterNoteRequest: Codable {
    let body: String
}

struct CompleteChatterActivityRequest: Codable {
    let feedback: String?
}

struct ScheduleChatterActivityRequest: Codable {
    let activityTypeId: Int
    let summary: String?
    let note: String?
    let dateDeadline: String?
}