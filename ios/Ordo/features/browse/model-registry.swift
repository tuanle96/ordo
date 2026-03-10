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

    static let fallbackBrowseMenuTree: [BrowseMenuNode] = supported.map { descriptor in
        BrowseMenuNode(
            id: stableMenuID(for: descriptor.model),
            name: descriptor.title,
            kind: .app,
            model: descriptor.model,
            children: []
        )
    }

    static func flatten(from browseMenuTree: [BrowseMenuNode]) -> [ModelDescriptor] {
        var seenModels = Set<String>()

        func traverse(nodes: [BrowseMenuNode]) -> [ModelDescriptor] {
            nodes.flatMap { node in
                var descriptors: [ModelDescriptor] = []

                if let model = node.model, seenModels.insert(model).inserted {
                    descriptors.append(descriptor(for: model, browseTitle: node.name))
                }

                if !node.children.isEmpty {
                    descriptors.append(contentsOf: traverse(nodes: node.children))
                }

                return descriptors
            }
        }

        return traverse(nodes: browseMenuTree)
    }

    static func descriptor(for model: String, browseTitle: String? = nil) -> ModelDescriptor {
        supported.first(where: { $0.model == model })
            ?? genericDescriptor(model: model, title: browseTitle)
    }

    private static func genericDescriptor(model: String, title: String?) -> ModelDescriptor {
        ModelDescriptor(
            model: model,
            title: normalizedTitle(title, fallbackModel: model),
            subtitle: humanizedModelName(model),
            systemImage: genericSystemImage(for: model, title: title),
            listFields: nil,
            titleFields: ["display_name", "name"],
            subtitleFields: ["partner_name", "email", "phone", "partner_id", "state"],
            footnoteFields: ["user_id", "company_id", "amount_total", "date_deadline"],
            requiredModule: nil
        )
    }

    private static func normalizedTitle(_ title: String?, fallbackModel: String) -> String {
        guard let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedTitle.isEmpty else {
            return humanizedModelName(fallbackModel)
        }

        return trimmedTitle
    }

    private static func humanizedModelName(_ model: String) -> String {
        model
            .split(separator: ".")
            .flatMap { $0.split(separator: "_") }
            .map { token in
                let lowercased = token.lowercased()
                guard let first = lowercased.first else { return "" }
                return String(first).uppercased() + lowercased.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func genericSystemImage(for model: String, title: String?) -> String {
        let haystack = [model, title ?? ""]
            .joined(separator: " ")
            .lowercased()

        if haystack.contains("account") || haystack.contains("invoice") || haystack.contains("bill") {
            return "doc.text"
        }

        if haystack.contains("stock") || haystack.contains("inventory") || haystack.contains("warehouse") {
            return "shippingbox"
        }

        if haystack.contains("project") || haystack.contains("task") {
            return "checklist"
        }

        if haystack.contains("hr") || haystack.contains("employee") || haystack.contains("recruit") {
            return "person.3"
        }

        return "square.grid.2x2"
    }

    private static func stableMenuID(for model: String) -> Int {
        model.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31) &+ Int(scalar.value)
        }
    }
}

extension ModelDescriptor {
    static func generic(model: String, browseTitle: String? = nil) -> ModelDescriptor {
        ModelRegistry.descriptor(for: model, browseTitle: browseTitle)
    }
}

