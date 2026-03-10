import SwiftUI

struct KanbanBoardView: View {
    let descriptor: ModelDescriptor
    let sections: [RecordListViewModel.KanbanSection]
    var onAction: ((KanbanCardButton, Int) -> Void)?

    private var isFlat: Bool {
        sections.count == 1 && sections.first?.key == "__flat__"
    }

    var body: some View {
        if sections.isEmpty {
            ContentUnavailableView(
                "No kanban columns yet",
                systemImage: "square.grid.3x2",
                description: Text("There are no grouped records to show right now.")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, OrdoSpacing.xl)
        } else if isFlat, let flatSection = sections.first {
            flatGrid(flatSection)
        } else {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: OrdoSpacing.lg) {
                    ForEach(sections) { section in
                        kanbanColumn(section)
                    }
                }
                .padding(.horizontal, OrdoSpacing.lg)
                .padding(.vertical, OrdoSpacing.sm)
            }
        }
    }

    private func flatGrid(_ section: RecordListViewModel.KanbanSection) -> some View {
        let columns = [
            GridItem(.flexible()),
        ]

        return LazyVGrid(columns: columns, spacing: OrdoSpacing.md) {
            ForEach(section.rows) { card in
                cardCell(card)
            }
        }
        .padding(.horizontal, OrdoSpacing.lg)
        .padding(.vertical, OrdoSpacing.sm)
    }

    private func kanbanColumn(_ section: RecordListViewModel.KanbanSection) -> some View {
        VStack(alignment: .leading, spacing: OrdoSpacing.md) {
            VStack(alignment: .leading, spacing: OrdoSpacing.xs) {
                Text(section.title)
                    .font(OrdoTypography.headline)
                    .foregroundStyle(OrdoColors.textPrimary)

                Text(section.rows.count == 1 ? "1 record" : "\(section.rows.count) records")
                    .font(OrdoTypography.caption)
                    .foregroundStyle(OrdoColors.textTertiary)
            }

            LazyVStack(alignment: .leading, spacing: OrdoSpacing.md) {
                ForEach(section.rows) { card in
                    cardCell(card)
                }
            }
        }
        .frame(width: 280, alignment: .topLeading)
        .padding(OrdoSpacing.md)
        .background(OrdoColors.surfaceGrouped, in: RoundedRectangle(cornerRadius: OrdoRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OrdoRadius.lg, style: .continuous)
                .strokeBorder(OrdoColors.separator.opacity(0.35), lineWidth: 1)
        )
        .accessibilityIdentifier("kanban-column-\(section.key)")
    }

    /// Builds a single kanban card.
    /// The card body navigates to the detail view, while action buttons
    /// perform their own actions without triggering navigation.
    private func cardCell(_ card: RecordListViewModel.KanbanCardModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card content — wrapped in NavigationLink for detail view
            NavigationLink {
                RecordDetailView(descriptor: descriptor, recordID: card.id)
            } label: {
                cardContent(card)
            }
            .buttonStyle(.plain)

            // Action buttons — outside NavigationLink to prevent navigation
            if !card.buttons.isEmpty {
                Divider()

                HStack(spacing: OrdoSpacing.sm) {
                    ForEach(card.buttons) { button in
                        kanbanActionButton(button, cardID: card.id)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, OrdoSpacing.md)
                .padding(.vertical, OrdoSpacing.sm)
                .background(OrdoColors.surfaceGrouped.opacity(0.4))
            }
        }
        .background(OrdoColors.surfaceCard, in: RoundedRectangle(cornerRadius: OrdoRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OrdoRadius.md, style: .continuous)
                .strokeBorder(OrdoColors.separator.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: OrdoRadius.md, style: .continuous))
        .accessibilityIdentifier("kanban-card-\(card.id)")
    }

    private func cardContent(_ card: RecordListViewModel.KanbanCardModel) -> some View {
        HStack(alignment: .top, spacing: OrdoSpacing.md) {
            AvatarView(name: card.summary.title, size: 48)

            VStack(alignment: .leading, spacing: OrdoSpacing.xs) {
                Text(card.summary.title)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(OrdoColors.textPrimary)
                    .lineLimit(1)

                if let subtitle = card.summary.subtitle {
                    Text(subtitle)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.teal)
                        .lineLimit(1)
                }

                if let footnote = card.summary.footnote {
                    Text(footnote)
                        .font(OrdoTypography.caption)
                        .foregroundStyle(OrdoColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(OrdoColors.textTertiary)
                .padding(.top, OrdoSpacing.xs)
        }
        .padding(OrdoSpacing.md)
    }

    @ViewBuilder
    private func kanbanActionButton(_ button: KanbanCardButton, cardID: Int) -> some View {
        if button.isPrimary {
            Button {
                onAction?(button, cardID)
            } label: {
                Text(button.label)
                    .font(.system(.caption, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityIdentifier("kanban-action-\(button.name)")
        } else {
            Button {
                onAction?(button, cardID)
            } label: {
                Text(button.label)
                    .font(.system(.caption, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("kanban-action-\(button.name)")
        }
    }
}