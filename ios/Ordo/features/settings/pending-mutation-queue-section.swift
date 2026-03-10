import SwiftUI

struct PendingMutationQueueSection: View {
    @Environment(AppState.self) private var appState

    @State private var queuedMutations: [QueuedRecordMutation] = []
    @State private var isRetryingAll = false
    @State private var isClearingAll = false
    @State private var activeMutationID: UUID?
    @State private var localMessage: String?

    var body: some View {
        if !queuedMutations.isEmpty || appState.pendingMutationCount > 0 {
            VStack(alignment: .leading, spacing: OrdoSpacing.sm) {
                Text("PENDING SYNC")
                    .font(OrdoTypography.caption)
                    .foregroundStyle(OrdoColors.textTertiary)
                    .fontWeight(.semibold)
                    .padding(.horizontal, OrdoSpacing.xs)

                OrdoCard {
                    VStack(alignment: .leading, spacing: OrdoSpacing.md) {
                        OfflineStateBanner(
                            title: appState.pendingMutationCount == 1 ? "1 pending change" : "\(appState.pendingMutationCount) pending changes",
                            message: "Review queued updates, retry them manually, or clear stale items from this device."
                        )

                        if let localMessage, !localMessage.isEmpty {
                            Text(localMessage)
                                .font(.footnote)
                                .foregroundStyle(OrdoColors.textSecondary)
                        }

                        HStack(spacing: OrdoSpacing.sm) {
                            Button {
                                Task {
                                    isRetryingAll = true
                                    await appState.replayPendingMutations()
                                    localMessage = appState.statusMessage
                                    await reloadQueue()
                                    isRetryingAll = false
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if isRetryingAll {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text(isRetryingAll ? "Retrying…" : "Retry All")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isRetryingAll || isClearingAll || activeMutationID != nil)
                            .accessibilityIdentifier("pending-mutations-retry-all")

                            Button(role: .destructive) {
                                Task {
                                    isClearingAll = true
                                    do {
                                        try await appState.clearPendingMutations()
                                        localMessage = appState.statusMessage
                                    } catch {
                                        localMessage = error.localizedDescription
                                    }
                                    await reloadQueue()
                                    isClearingAll = false
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if isClearingAll {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text(isClearingAll ? "Clearing…" : "Clear All")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isRetryingAll || isClearingAll || activeMutationID != nil)
                            .accessibilityIdentifier("pending-mutations-clear-all")
                        }

                        VStack(spacing: OrdoSpacing.sm) {
                            ForEach(queuedMutations) { mutation in
                                queueRow(for: mutation)
                            }
                        }
                    }
                }
            }
            .task(id: appState.pendingMutationCount) {
                await reloadQueue()
            }
        }
    }

    @ViewBuilder
    private func queueRow(for mutation: QueuedRecordMutation) -> some View {
        VStack(alignment: .leading, spacing: OrdoSpacing.sm) {
            HStack(alignment: .top, spacing: OrdoSpacing.sm) {
                Image(systemName: iconName(for: mutation.kind))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(iconBackground(for: mutation.kind), in: RoundedRectangle(cornerRadius: OrdoRadius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title(for: mutation))
                        .font(OrdoTypography.headline)
                        .foregroundStyle(OrdoColors.textPrimary)

                    Text(subtitle(for: mutation))
                        .font(OrdoTypography.caption)
                        .foregroundStyle(OrdoColors.textSecondary)

                    if let lastError = mutation.lastError, !lastError.isEmpty {
                        Text(lastError)
                            .font(OrdoTypography.caption)
                            .foregroundStyle(OrdoColors.danger)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: OrdoSpacing.sm) {
                Button {
                    Task {
                        activeMutationID = mutation.id
                        await appState.retryPendingMutation(id: mutation.id)
                        localMessage = appState.statusMessage
                        await reloadQueue()
                        activeMutationID = nil
                    }
                } label: {
                    HStack(spacing: 6) {
                        if activeMutationID == mutation.id {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(activeMutationID == mutation.id ? "Retrying…" : "Retry Now")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRetryingAll || isClearingAll || activeMutationID != nil)

                Button(role: .destructive) {
                    Task {
                        activeMutationID = mutation.id
                        do {
                            try await appState.removePendingMutation(id: mutation.id)
                            localMessage = appState.statusMessage
                        } catch {
                            localMessage = error.localizedDescription
                        }
                        await reloadQueue()
                        activeMutationID = nil
                    }
                } label: {
                    Text("Remove")
                }
                .buttonStyle(.bordered)
                .disabled(isRetryingAll || isClearingAll || activeMutationID != nil)
            }
        }
        .padding(OrdoSpacing.md)
        .background(OrdoColors.surfaceGrouped, in: RoundedRectangle(cornerRadius: OrdoRadius.sm, style: .continuous))
        .accessibilityIdentifier("pending-mutation-\(mutation.id.uuidString)")
    }

    private func reloadQueue() async {
        queuedMutations = await appState.pendingMutations()
    }

    private func title(for mutation: QueuedRecordMutation) -> String {
        let modelTitle = appState.modelDescriptor(for: mutation.model).title
        return "\(kindLabel(for: mutation.kind)) · \(modelTitle)"
    }

    private func subtitle(for mutation: QueuedRecordMutation) -> String {
        var parts = ["Record #\(mutation.recordID)"]

        if mutation.kind == .action, let actionName = mutation.actionName, !actionName.isEmpty {
            parts.append("Action: \(actionName)")
        }

        if mutation.retryCount > 0 {
            parts.append("Retries: \(mutation.retryCount)")
        }

        parts.append(mutation.createdAt.formatted(date: .abbreviated, time: .shortened))
        return parts.joined(separator: " · ")
    }

    private func kindLabel(for kind: QueuedRecordMutationKind) -> String {
        switch kind {
        case .update: return "Update"
        case .delete: return "Delete"
        case .action: return "Action"
        }
    }

    private func iconName(for kind: QueuedRecordMutationKind) -> String {
        switch kind {
        case .update: return "square.and.pencil"
        case .delete: return "trash"
        case .action: return "bolt.fill"
        }
    }

    private func iconBackground(for kind: QueuedRecordMutationKind) -> Color {
        switch kind {
        case .update: return OrdoColors.accent
        case .delete: return OrdoColors.danger
        case .action: return .orange
        }
    }
}