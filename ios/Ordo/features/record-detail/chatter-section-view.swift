import SwiftUI

struct ChatterSectionView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: RecordChatterViewModel

    var body: some View {
        Section("Chatter") {
            VStack(alignment: .leading, spacing: OrdoSpacing.md) {
                TextEditor(text: $viewModel.draftBody)
                    .frame(minHeight: 88)
                    .padding(OrdoSpacing.sm)
                    .background(OrdoColors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: OrdoRadius.lg, style: .continuous))
                    .accessibilityIdentifier("chatter-note-editor")

                HStack {
                    if viewModel.isPosting || viewModel.isUpdatingFollow {
                        ProgressView()
                    }

                    Spacer()

                    Button(viewModel.isFollowing ? "Unfollow" : "Follow") {
                        Task {
                            await viewModel.toggleFollowing(using: appState)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isUpdatingFollow)
                    .accessibilityIdentifier("chatter-follow-button")

                    Button("Post Note") {
                        Task {
                            await viewModel.postNote(using: appState)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isPosting)
                    .accessibilityIdentifier("chatter-post-button")
                }

                FollowersSummaryView(viewModel: viewModel)

                ActivitiesSummaryView(viewModel: viewModel, appState: appState)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("chatter-error-message")
                }

                if viewModel.isLoading && viewModel.messages.isEmpty {
                    ProgressView("Loading chatter…")
                } else if viewModel.messages.isEmpty {
                    Text("No messages yet.")
                        .font(.subheadline)
                        .foregroundStyle(OrdoColors.textSecondary)
                } else {
                    ForEach(viewModel.messages) { message in
                        ChatterMessageRow(message: message)
                    }
                }

                if viewModel.hasMore {
                    Button("Load More") {
                        Task {
                            await viewModel.loadMore(using: appState)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, OrdoSpacing.xs)
        }
    }
}

private struct FollowersSummaryView: View {
    @Bindable var viewModel: RecordChatterViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: OrdoSpacing.sm) {
            Text("Followers · \(viewModel.followersCount)")
                .font(.headline)

            if viewModel.followers.isEmpty {
                Text("No followers yet.")
                    .font(.subheadline)
                    .foregroundStyle(OrdoColors.textSecondary)
            } else {
                ForEach(viewModel.followers) { follower in
                    HStack(spacing: OrdoSpacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(follower.name)
                                .font(.subheadline.weight(.medium))

                            if let email = follower.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(OrdoColors.textSecondary)
                            }
                        }

                        Spacer()

                        if follower.isSelf {
                            Text("You")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(OrdoSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OrdoColors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: OrdoRadius.lg, style: .continuous))
                }
            }
        }
    }
}

private struct ActivitiesSummaryView: View {
    @Bindable var viewModel: RecordChatterViewModel
    let appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: OrdoSpacing.sm) {
            Text("Activities")
                .font(.headline)

            if viewModel.activities.isEmpty {
                Text("No active activities.")
                    .font(.subheadline)
                    .foregroundStyle(OrdoColors.textSecondary)
            } else {
                ForEach(viewModel.activities) { activity in
                    VStack(alignment: .leading, spacing: OrdoSpacing.sm) {
                        HStack(alignment: .firstTextBaseline, spacing: OrdoSpacing.sm) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.displaySummary)
                                    .font(.subheadline.weight(.semibold))

                                Text("\(activity.typeName) · \(activity.stateLabel)")
                                    .font(.caption)
                                    .foregroundStyle(OrdoColors.textSecondary)
                            }

                            Spacer(minLength: 12)

                            Text(activity.relativeDeadline)
                                .font(.caption)
                                .foregroundStyle(OrdoColors.textSecondary)
                        }

                        if let assignedUser = activity.assignedUser {
                            Text("Assigned to \(assignedUser.name)")
                                .font(.caption)
                                .foregroundStyle(OrdoColors.textSecondary)
                        }

                        Text(activity.displayNote)
                            .font(.body)
                            .foregroundStyle(OrdoColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if activity.canWrite {
                            HStack {
                                Spacer()

                                if viewModel.completingActivityIDs.contains(activity.id) {
                                    ProgressView()
                                } else {
                                    Button("Mark Done") {
                                        Task {
                                            await viewModel.completeActivity(id: activity.id, using: appState)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("chatter-activity-done-\(activity.id)")
                                }
                            }
                        }
                    }
                    .padding(OrdoSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OrdoColors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: OrdoRadius.lg, style: .continuous))
                }
            }
        }
    }
}

private struct ChatterMessageRow: View {
    let message: ChatterMessage

    var body: some View {
        VStack(alignment: .leading, spacing: OrdoSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: OrdoSpacing.sm) {
                Text(message.authorName)
                    .font(.subheadline.weight(.semibold))

                if message.isNote {
                    Text("Note")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                Spacer(minLength: 12)

                Text(message.relativeTimestamp)
                    .font(.caption)
                    .foregroundStyle(OrdoColors.textSecondary)
            }

            Text(message.displayBody)
                .font(.body)
                .foregroundStyle(OrdoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(OrdoSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrdoColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OrdoRadius.lg, style: .continuous))
    }
}