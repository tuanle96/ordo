import SwiftUI

struct RecordHeaderCard: View {
    let displayName: String
    let status: String?

    var body: some View {
        VStack(spacing: OrdoSpacing.md) {
            AvatarView(name: displayName, size: 64)

            Text(displayName)
                .font(OrdoTypography.title)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("record-detail-title")

            if let status, status != "—" {
                Text(status)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(OrdoColors.accent)
                    .padding(.horizontal, OrdoSpacing.md)
                    .padding(.vertical, OrdoSpacing.xs + 2)
                    .background(OrdoColors.accentLight, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OrdoSpacing.lg)
    }
}

#Preview {
    List {
        Section {
            RecordHeaderCard(displayName: "Azure Interior", status: "Active")
        }
        Section {
            RecordHeaderCard(displayName: "Mitchell Admin", status: nil)
        }
    }
}
