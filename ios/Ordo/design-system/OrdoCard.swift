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
    }
    .padding()
    .background(OrdoColors.surfaceGrouped)
}
