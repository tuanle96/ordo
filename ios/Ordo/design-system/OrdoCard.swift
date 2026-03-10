import SwiftUI

/// Card container matching SnapCal's SCCard style.
/// Rounded rectangle with subtle shadow on a secondary surface background.
struct OrdoCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack {
            content
        }
        .padding(OrdoSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrdoColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OrdoRadius.md, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

struct OrdoEmptyStateCard: View {
    let title: String
    let message: String
    let systemImage: String
    var accessibilityPrefix: String? = nil

    var body: some View {
        OrdoCard {
            HStack {
                Spacer(minLength: 0)

                VStack(spacing: OrdoSpacing.md) {
                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(OrdoColors.accent)

                    VStack(spacing: OrdoSpacing.xs) {
                        Text(title)
                            .font(OrdoTypography.headline)
                            .foregroundStyle(OrdoColors.textPrimary)
                            .accessibilityIdentifier(accessibilityIdentifier(suffix: "title"))

                        Text(message)
                            .font(OrdoTypography.subheadline)
                            .foregroundStyle(OrdoColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier(accessibilityIdentifier(suffix: "message"))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, OrdoSpacing.lg)
        }
        .accessibilityIdentifier(accessibilityIdentifier(suffix: "card"))
    }

    private func accessibilityIdentifier(suffix: String) -> String {
        guard let accessibilityPrefix, !accessibilityPrefix.isEmpty else {
            return ""
        }

        return "\(accessibilityPrefix)-\(suffix)"
    }
}

#Preview {
    VStack(spacing: 16) {
        OrdoCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Card Title")
                    .font(OrdoTypography.headline)
                Text("This is a card body with some content.")
                    .font(OrdoTypography.subheadline)
                    .foregroundStyle(OrdoColors.textSecondary)
            }
        }

        OrdoCard {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundStyle(OrdoColors.accent)
                Text("Another card")
                    .font(OrdoTypography.headline)
                Spacer()
            }
        }

        OrdoEmptyStateCard(
            title: "Nothing here yet",
            message: "This card can explain why a section is currently empty.",
            systemImage: "tray",
            accessibilityPrefix: "preview-empty-state"
        )
    }
    .padding()
    .background(OrdoColors.surfaceGrouped)
}
