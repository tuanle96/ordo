import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(RecentItemsStore.self) private var recentItems

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: OrdoSpacing.lg) {
                // MARK: - Greeting Card
                OrdoCard {
                    HStack(spacing: OrdoSpacing.md) {
                        AvatarView(name: appState.displayUserName, size: 52)

                        VStack(alignment: .leading, spacing: OrdoSpacing.xs) {
                            Text("\(greeting), \(firstName)!")
                                .font(OrdoTypography.title)

                            if let email = appState.displayEmail {
                                Text(email)
                                    .font(OrdoTypography.subheadline)
                                    .foregroundStyle(OrdoColors.textSecondary)
                            }
                        }
                    }
                }

                // MARK: - Quick Actions
                VStack(alignment: .leading, spacing: OrdoSpacing.sm) {
                    Text("QUICK ACTIONS")
                        .font(OrdoTypography.caption)
                        .foregroundStyle(OrdoColors.textTertiary)
                        .fontWeight(.semibold)
                        .padding(.horizontal, OrdoSpacing.xs)

                    OrdoCard {
                        VStack(spacing: 0) {
                            ForEach(Array(ModelRegistry.supported.enumerated()), id: \.element.id) { index, descriptor in
                                NavigationLink {
                                    RecordListView(descriptor: descriptor)
                                } label: {
                                    HStack(spacing: OrdoSpacing.md) {
                                        Image(systemName: descriptor.systemImage)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .frame(width: 32, height: 32)
                                            .background(OrdoColors.accent, in: RoundedRectangle(cornerRadius: OrdoRadius.sm, style: .continuous))

                                        Text(descriptor.title)
                                            .font(OrdoTypography.headline)
                                            .foregroundStyle(OrdoColors.textPrimary)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(OrdoColors.textTertiary)
                                    }
                                    .padding(.vertical, OrdoSpacing.md)
                                }

                                if index < ModelRegistry.supported.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                // MARK: - Recently Viewed
                if !recentItems.items.isEmpty {
                    VStack(alignment: .leading, spacing: OrdoSpacing.sm) {
                        Text("RECENTLY VIEWED")
                            .font(OrdoTypography.caption)
                            .foregroundStyle(OrdoColors.textTertiary)
                            .fontWeight(.semibold)
                            .padding(.horizontal, OrdoSpacing.xs)

                        OrdoCard {
                            VStack(spacing: 0) {
                                ForEach(Array(recentItems.items.prefix(5).enumerated()), id: \.element.id) { index, item in
                                    if let descriptor = ModelRegistry.supported.first(where: { $0.model == item.model }) {
                                        NavigationLink {
                                            RecordDetailView(descriptor: descriptor, recordID: item.recordID)
                                        } label: {
                                            HStack(spacing: OrdoSpacing.md) {
                                                AvatarView(name: item.displayName, size: 36)

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(item.displayName)
                                                        .font(OrdoTypography.headline)
                                                        .foregroundStyle(OrdoColors.textPrimary)
                                                        .lineLimit(1)
                                                    Text(descriptor.title)
                                                        .font(OrdoTypography.caption)
                                                        .foregroundStyle(OrdoColors.textTertiary)
                                                }

                                                Spacer()

                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(OrdoColors.textTertiary)
                                            }
                                            .padding(.vertical, OrdoSpacing.sm)
                                        }
                                        .accessibilityIdentifier("recent-item-\(descriptor.model)-\(item.recordID)")

                                        if index < min(recentItems.items.count, 5) - 1 {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // MARK: - Connection Status
                if let session = appState.session {
                    VStack(alignment: .leading, spacing: OrdoSpacing.sm) {
                        Text("CONNECTION")
                            .font(OrdoTypography.caption)
                            .foregroundStyle(OrdoColors.textTertiary)
                            .fontWeight(.semibold)
                            .padding(.horizontal, OrdoSpacing.xs)

                        OrdoCard {
                            VStack(spacing: OrdoSpacing.md) {
                                HStack(spacing: OrdoSpacing.sm) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(OrdoColors.success)
                                    Text("Connected")
                                        .font(OrdoTypography.subheadline)
                                        .foregroundStyle(OrdoColors.success)
                                    Spacer()
                                }

                                metricRow("Server", value: session.odooURL)
                                metricRow("Database", value: session.database)

                                if let version = appState.displayVersion {
                                    metricRow("Version", value: version)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, OrdoSpacing.lg)
            .padding(.vertical, OrdoSpacing.sm)
        }
        .background(OrdoColors.surfaceGrouped)
        .navigationTitle("Home")
        .accessibilityIdentifier("home-screen")
    }

    private var firstName: String {
        let name = appState.displayUserName
        return String(name.split(separator: " ").first ?? Substring(name))
    }

    private func metricRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(OrdoColors.textSecondary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundStyle(OrdoColors.textPrimary)
                .lineLimit(1)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environment(AppState.preview)
            .environment(RecentItemsStore())
    }
}
