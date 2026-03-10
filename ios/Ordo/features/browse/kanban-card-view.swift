import SwiftUI

struct KanbanCardView: View {
    let card: RecordListViewModel.KanbanCardModel
    var onAction: ((KanbanCardButton) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card content — tappable for navigation (handled by parent)
            cardContent

            // Action buttons — separate from navigation
            if !card.buttons.isEmpty {
                Divider()

                HStack(spacing: OrdoSpacing.sm) {
                    ForEach(card.buttons) { button in
                        kanbanActionButton(button)
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
        .accessibilityElement(children: .combine)
    }

    private var cardContent: some View {
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
    private func kanbanActionButton(_ button: KanbanCardButton) -> some View {
        if button.isPrimary {
            Button {
                onAction?(button)
            } label: {
                Text(button.label)
                    .font(.system(.caption, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityIdentifier("kanban-action-\(button.name)")
        } else {
            Button {
                onAction?(button)
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