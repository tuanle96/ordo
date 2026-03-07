import SwiftUI

struct RecordCardRow: View {
    let summary: RecordRowSummary

    var body: some View {
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
        .padding(.vertical, OrdoSpacing.xs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        RecordCardRow(summary: RecordRowSummary(
            id: 1,
            title: "Azure Interior",
            subtitle: "azure@example.com · +1 234 567",
            footnote: "San Francisco · United States"
        ))
        RecordCardRow(summary: RecordRowSummary(
            id: 2,
            title: "My Company",
            subtitle: nil,
            footnote: nil
        ))
        RecordCardRow(summary: RecordRowSummary(
            id: 3,
            title: "Ready Mat",
            subtitle: "ready@example.com",
            footnote: "Brussels · Belgium"
        ))
    }
}
