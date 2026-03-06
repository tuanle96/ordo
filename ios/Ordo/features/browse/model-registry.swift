import Foundation

struct ModelDescriptor: Identifiable, Hashable {
    let model: String
    let title: String
    let subtitle: String
    let systemImage: String
    let listFields: [String]

    var id: String { model }

    func summary(from record: RecordData) -> RecordRowSummary? {
        guard let id = record["id"]?.intValue else { return nil }

        let title = record["display_name"]?.displayText
            ?? record["name"]?.displayText
            ?? "Record #\(id)"
        let subtitle = [record["email"]?.displayText, record["phone"]?.displayText]
            .compactMap { value -> String? in
                guard let value, value != "—", !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
        let footnote = [record["city"]?.displayText, record["country_id"]?.displayText]
            .compactMap { value -> String? in
                guard let value, value != "—", !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")

        return RecordRowSummary(
            id: id,
            title: title,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            footnote: footnote.isEmpty ? nil : footnote
        )
    }
}

enum ModelRegistry {
    static let supported: [ModelDescriptor] = [
        ModelDescriptor(
            model: "res.partner",
            title: "Customers",
            subtitle: "Contacts and companies",
            systemImage: "person.2",
            listFields: ["id", "display_name", "name", "email", "phone", "city", "country_id"]
        ),
    ]
}
