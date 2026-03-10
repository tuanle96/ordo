import SwiftUI

struct RecordCardRow: View {
    let summary: RecordRowSummary
    let columns: [ListColumn]?
    var buttons: [KanbanCardButton] = []
    var onAction: ((KanbanCardButton) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: OrdoSpacing.sm) {
            HStack(spacing: OrdoSpacing.md) {
                AvatarView(name: summary.title, size: 44)

                VStack(alignment: .leading, spacing: OrdoSpacing.xs) {
                    Text(summary.title)
                        .font(OrdoTypography.headline)
                        .foregroundStyle(OrdoColors.textPrimary)
                        .lineLimit(1)

                    if let subtitle = summary.subtitle {
                        Text(subtitle)
                            .font(OrdoTypography.subheadline)
                            .foregroundStyle(OrdoColors.textSecondary)
                            .lineLimit(1)
                    }

                    if let footnote = summary.footnote {
                        Text(footnote)
                            .font(OrdoTypography.caption)
                            .foregroundStyle(OrdoColors.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            if !buttons.isEmpty {
                HStack(spacing: OrdoSpacing.sm) {
                    ForEach(buttons) { button in
                        cardActionButton(button)
                    }
                }
            }
        }
        .padding(.vertical, OrdoSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func cardActionButton(_ button: KanbanCardButton) -> some View {
        if button.isPrimary {
            Button {
                onAction?(button)
            } label: {
                Text(button.label)
                    .font(OrdoTypography.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityIdentifier("card-action-\(button.name)")
        } else {
            Button {
                onAction?(button)
            } label: {
                Text(button.label)
                    .font(OrdoTypography.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("card-action-\(button.name)")
        }
    }
}

struct RecordTableRow: View {
    let summary: RecordRowSummary
    let record: RecordData?
    let columns: [ListColumn]?

    var body: some View {
        Group {
            if let record, let columns, !columns.isEmpty {
                HStack(alignment: .top, spacing: OrdoSpacing.md) {
                    ForEach(columns) { column in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(column.label)
                                .font(OrdoTypography.caption)
                                .foregroundStyle(OrdoColors.textTertiary)

                            Text(record[column.name]?.displayText ?? "—")
                                .font(OrdoTypography.caption)
                                .foregroundStyle(OrdoColors.textSecondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: OrdoSpacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: OrdoSpacing.sm) {
                        Text(summary.title)
                            .font(OrdoTypography.subheadline.weight(.semibold))
                            .foregroundStyle(OrdoColors.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Text("#\(summary.id)")
                            .font(OrdoTypography.caption.monospacedDigit())
                            .foregroundStyle(OrdoColors.textTertiary)
                    }

                    HStack(alignment: .top, spacing: OrdoSpacing.md) {
                        tableColumn(title: "Details", value: summary.subtitle)
                        tableColumn(title: "Meta", value: summary.footnote, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.vertical, OrdoSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func tableColumn(title: String, value: String?, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title)
                .font(OrdoTypography.caption)
                .foregroundStyle(OrdoColors.textTertiary)

            Text(value ?? "—")
                .font(OrdoTypography.caption)
                .foregroundStyle(OrdoColors.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
    }
}

#Preview {
    List {
        RecordCardRow(summary: RecordRowSummary(
            id: 1,
            title: "Azure Interior",
            subtitle: "azure@example.com · +1 234 567",
            footnote: "San Francisco · United States"
        ), columns: nil)
        RecordCardRow(summary: RecordRowSummary(
            id: 2,
            title: "My Company",
            subtitle: nil,
            footnote: nil
        ), columns: nil)
        RecordCardRow(summary: RecordRowSummary(
            id: 3,
            title: "Ready Mat",
            subtitle: "ready@example.com",
            footnote: "Brussels · Belgium"
        ), columns: nil)
    }
}
