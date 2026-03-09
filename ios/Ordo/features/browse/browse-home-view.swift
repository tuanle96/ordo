import SwiftUI

struct BrowseHomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(spacing: OrdoSpacing.lg) {
                OrdoCard {
                    VStack(spacing: 0) {
                        ForEach(Array(appState.availableModels.enumerated()), id: \.element.id) { index, descriptor in
                            NavigationLink {
                                RecordListView(descriptor: descriptor)
                            } label: {
                                HStack(spacing: OrdoSpacing.md) {
                                    Image(systemName: descriptor.systemImage)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 40, height: 40)
                                        .background(OrdoColors.accent, in: RoundedRectangle(cornerRadius: OrdoRadius.sm, style: .continuous))

                                    VStack(alignment: .leading, spacing: OrdoSpacing.xs) {
                                        Text(descriptor.title)
                                            .font(OrdoTypography.headline)
                                            .foregroundStyle(OrdoColors.textPrimary)
                                        Text(descriptor.subtitle)
                                            .font(OrdoTypography.subheadline)
                                            .foregroundStyle(OrdoColors.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(OrdoColors.textTertiary)
                                }
                                .padding(.vertical, OrdoSpacing.md)
                            }
                            .accessibilityIdentifier("browse-model-\(descriptor.model.replacingOccurrences(of: ".", with: "-"))")

                            if index < appState.availableModels.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, OrdoSpacing.lg)
            .padding(.vertical, OrdoSpacing.sm)
        }
        .background(OrdoColors.surfaceGrouped)
        .navigationTitle("Browse")
        .accessibilityIdentifier("browse-home-screen")
    }
}

#Preview {
    NavigationStack {
        BrowseHomeView()
            .environment(AppState.preview)
    }
}

