import SwiftUI

struct RecordHeaderStatusChip: Identifiable, Hashable {
    let value: String
    let label: String
    let isCurrent: Bool
    let isInteractive: Bool

    var id: String { value }
}

struct RecordHeaderCard: View {
    let displayName: String
    let status: String?
    var statusChips: [RecordHeaderStatusChip] = []
    var isEditing = false
    var nameText: Binding<String>? = nil
    var namePlaceholder: String? = nil
    var onStatusTap: ((RecordHeaderStatusChip) -> Void)? = nil

    var body: some View {
        VStack(spacing: OrdoSpacing.md) {
            AvatarView(name: displayName, size: 64)

            if isEditing, let nameText {
                TextField(namePlaceholder ?? "Name", text: nameText, axis: .vertical)
                    .font(OrdoTypography.title)
                    .multilineTextAlignment(.center)
                    .lineLimit(1...2)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("record-header-name-editor")
            } else {
                Text(displayName)
                    .font(OrdoTypography.title)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("record-detail-title")
            }

            if !statusChips.isEmpty {
                ViewThatFits {
                    HStack(spacing: OrdoSpacing.sm) {
                        statusChipViews
                    }

                    VStack(spacing: OrdoSpacing.sm) {
                        statusChipViews
                    }
                }
            } else if let status, status != "—" {
                statusLabel(status, isCurrent: true, isInteractive: false)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OrdoSpacing.lg)
    }

    @ViewBuilder
    private var statusChipViews: some View {
        ForEach(statusChips) { chip in
            if chip.isInteractive, let onStatusTap {
                Button {
                    onStatusTap(chip)
                } label: {
                    statusLabel(chip.label, isCurrent: chip.isCurrent, isInteractive: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("record-detail-status-chip-\(chip.value)")
            } else {
                statusLabel(chip.label, isCurrent: chip.isCurrent, isInteractive: chip.isInteractive)
                    .accessibilityIdentifier(chip.isCurrent ? "record-detail-status" : "record-detail-status-chip-\(chip.value)")
            }
        }
    }

    private func statusLabel(_ label: String, isCurrent: Bool, isInteractive: Bool) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(isCurrent ? OrdoColors.accent : (isInteractive ? OrdoColors.accent : .secondary))
            .padding(.horizontal, OrdoSpacing.md)
            .padding(.vertical, OrdoSpacing.xs + 2)
            .background(
                (isCurrent ? OrdoColors.accentLight : Color.secondary.opacity(isInteractive ? 0.12 : 0.08)),
                in: Capsule()
            )
            .overlay {
                if isInteractive {
                    Capsule()
                        .stroke(OrdoColors.accent.opacity(0.35), lineWidth: 1)
                }
            }
            .contentShape(Capsule())
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
