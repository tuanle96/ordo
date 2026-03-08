import SwiftUI

struct ChatterSectionView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: RecordChatterViewModel
    @State private var isShowingScheduleSheet = false

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
                    if viewModel.isPosting || viewModel.isUpdatingFollow || viewModel.isSchedulingActivity {
                        ProgressView()
                    }

                    Spacer()

                    if !viewModel.availableActivityTypes.isEmpty {
                        Button("Schedule Activity") {
                            isShowingScheduleSheet = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isSchedulingActivity)
                        .accessibilityIdentifier("chatter-schedule-button")
                    }

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
        .sheet(isPresented: $isShowingScheduleSheet) {
            ScheduleActivitySheet(viewModel: viewModel, isPresented: $isShowingScheduleSheet)
                .environment(appState)
        }
    }
}

private struct ScheduleActivitySheet: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: RecordChatterViewModel
    @Binding var isPresented: Bool

    @State private var selectedActivityTypeID: Int?
    @State private var summary = ""
    @State private var note = ""
    @State private var includesDeadline = false
    @State private var deadline = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Activity Type", selection: selectedTypeBinding) {
                        ForEach(viewModel.availableActivityTypes) { activityType in
                            Text(activityType.name)
                                .tag(Optional(activityType.id))
                        }
                    }

                    Text("Assigned to you")
                        .font(.footnote)
                        .foregroundStyle(OrdoColors.textSecondary)
                }

                Section("Details") {
                    TextField("Summary", text: $summary)
                        .accessibilityIdentifier("chatter-schedule-summary")

                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("chatter-schedule-note")
                }

                Section("Deadline") {
                    Toggle("Set deadline", isOn: $includesDeadline)

                    if includesDeadline {
                        DatePicker(
                            "Deadline",
                            selection: $deadline,
                            displayedComponents: .date
                        )
                    }
                }
            }
            .navigationTitle("Schedule Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await submit()
                        }
                    }
                    .disabled(selectedActivityTypeID == nil || viewModel.isSchedulingActivity)
                }
            }
            .onAppear {
                if selectedActivityTypeID == nil {
                    selectedActivityTypeID = viewModel.availableActivityTypes.first?.id
                }
            }
        }
    }

    private var selectedTypeBinding: Binding<Int?> {
        Binding(
            get: { selectedActivityTypeID },
            set: { newValue in
                selectedActivityTypeID = newValue
                guard let selectedType = viewModel.availableActivityTypes.first(where: { $0.id == newValue }) else { return }
                if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    summary = selectedType.summary ?? ""
                }
                if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    note = selectedType.defaultNote ?? ""
                }
            }
        )
    }

    private func submit() async {
        guard let activityTypeID = selectedActivityTypeID else { return }

        let didSchedule = await viewModel.scheduleActivity(
            activityTypeId: activityTypeID,
            summary: summary,
            note: note,
            dateDeadline: includesDeadline ? deadline : nil,
            using: appState
        )

        if didSchedule {
            isPresented = false
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