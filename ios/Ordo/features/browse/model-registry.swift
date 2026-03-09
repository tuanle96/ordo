import Foundation

struct ModelDescriptor: Identifiable, Hashable {
    let model: String
    let title: String
    let subtitle: String
    let systemImage: String
    let listFields: [String]?
    let titleFields: [String]
    let subtitleFields: [String]
    let footnoteFields: [String]
    let requiredModule: String?

    var id: String { model }

    var primarySortField: String {
        titleFields.first(where: { $0 != "display_name" })
            ?? listFields?.first(where: { $0 != "id" && $0 != "display_name" })
            ?? "id"
    }

    func summary(from record: RecordData) -> RecordRowSummary? {
        guard let id = record["id"]?.intValue else { return nil }

        let title = firstDisplayValue(in: record, fields: titleFields) ?? "Record #\(id)"
        let subtitle = joinedDisplayValues(in: record, fields: subtitleFields)
        let footnote = joinedDisplayValues(in: record, fields: footnoteFields)

        return RecordRowSummary(
            id: id,
            title: title,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            footnote: footnote.isEmpty ? nil : footnote
        )
    }

    private func firstDisplayValue(in record: RecordData, fields: [String]) -> String? {
        fields.lazy
            .compactMap { displayValue(for: $0, in: record) }
            .first
    }

    private func joinedDisplayValues(in record: RecordData, fields: [String]) -> String {
        fields.compactMap { displayValue(for: $0, in: record) }
            .joined(separator: " · ")
    }

    private func displayValue(for field: String, in record: RecordData) -> String? {
        guard let value = record[field]?.displayText, value != "—", !value.isEmpty else { return nil }
        return value
    }
}

enum ModelRegistry {
    static let supported: [ModelDescriptor] = [
        ModelDescriptor(
            model: "res.partner",
            title: "Customers",
            subtitle: "Contacts and companies",
            systemImage: "person.2",
            listFields: ["id", "display_name", "name", "email", "phone", "city", "country_id"],
            titleFields: ["display_name", "name"],
            subtitleFields: ["email", "phone"],
            footnoteFields: ["city", "country_id"],
            requiredModule: nil
        ),
        ModelDescriptor(
            model: "crm.lead",
            title: "Leads",
            subtitle: "Pipeline opportunities",
            systemImage: "target",
            listFields: ["id", "display_name", "name", "partner_name", "email_from", "phone", "stage_id", "user_id"],
            titleFields: ["name", "display_name"],
            subtitleFields: ["partner_name", "email_from", "phone"],
            footnoteFields: ["stage_id", "user_id"],
            requiredModule: "crm"
        ),
        ModelDescriptor(
            model: "sale.order",
            title: "Sales Orders",
            subtitle: "Quotes and confirmed orders",
            systemImage: "cart",
            listFields: ["id", "display_name", "name", "partner_id", "user_id", "state", "amount_total"],
            titleFields: ["name", "display_name"],
            subtitleFields: ["partner_id", "user_id"],
            footnoteFields: ["state", "amount_total"],
            requiredModule: "sale"
        ),
    ]

    static func available(installedModules: Set<String>) -> [ModelDescriptor] {
        supported.filter { descriptor in
            guard let required = descriptor.requiredModule else { return true }
            return installedModules.contains(required)
        }
    }
}

