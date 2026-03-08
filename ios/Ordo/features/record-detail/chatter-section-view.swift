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
                    if viewModel.isPosting {
                        ProgressView()
                    }

                    Spacer()

                    Button("Post Note") {
                        Task {
                            await viewModel.postNote(using: appState)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isPosting)
                    .accessibilityIdentifier("chatter-post-button")
                }

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