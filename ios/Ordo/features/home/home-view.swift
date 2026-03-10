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
                if let statusMessage = appState.statusMessage, !statusMessage.isEmpty {
                    OfflineStateBanner(title: appState.pendingMutationCount > 0 ? "Pending sync" : "Status", message: statusMessage)
                }

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

                    if appState.browseRoots.isEmpty {
                        OrdoEmptyStateCard(
                            title: appState.browseDiscoveryErrorMessage == nil
                                ? "No browseable models yet"
                                : "Browse is unavailable right now",
                            message: appState.browseDiscoveryErrorMessage
                                ?? "This account does not currently expose any browseable Odoo menus. Check menu and action access for the signed-in user.",
                            systemImage: "square.grid.2x2",
                            accessibilityPrefix: "home-empty-browse-catalog"
                        )
                    } else {
                        OrdoCard {
                            VStack(spacing: 0) {
                                ForEach(Array(appState.browseRoots.enumerated()), id: \.element.id) { index, node in
                                    BrowseMenuRowLink(node: node, compact: true)

                                    if index < appState.browseRoots.count - 1 {
                                        Divider()
                                    }
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
                                    let descriptor = appState.modelDescriptor(for: item.model)

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

                                if appState.pendingMutationCount > 0 {
                                    metricRow("Pending Changes", value: String(appState.pendingMutationCount))
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
