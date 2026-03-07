import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var cacheMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: OrdoSpacing.lg) {
                // MARK: - Profile Card (with accent bar)
                VStack(spacing: 0) {
                    // Top accent bar
                    OrdoColors.accent
                        .frame(height: 3)
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: OrdoRadius.md,
                            topTrailingRadius: OrdoRadius.md
                        ))

                    OrdoCard {
                        HStack(spacing: OrdoSpacing.md) {
                            AvatarView(name: appState.displayUserName, size: 52)

                            VStack(alignment: .leading, spacing: OrdoSpacing.xs) {
                                Text(appState.displayUserName)
                                    .font(OrdoTypography.headline)

                                if let email = appState.displayEmail {
                                    Text(email)
                                        .font(OrdoTypography.subheadline)
                                        .foregroundStyle(OrdoColors.textSecondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(OrdoColors.textTertiary)
                        }
                    }
                    .clipShape(UnevenRoundedRectangle(
                        bottomLeadingRadius: OrdoRadius.md,
                        bottomTrailingRadius: OrdoRadius.md
                    ))
                }
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)

                // MARK: - Connection
                if let session = appState.session {
                    VStack(alignment: .leading, spacing: OrdoSpacing.sm) {
                        Text("CONNECTION")
                            .font(OrdoTypography.caption)
                            .foregroundStyle(OrdoColors.textTertiary)
                            .fontWeight(.semibold)
                            .padding(.horizontal, OrdoSpacing.xs)

                        OrdoCard {
                            VStack(spacing: 0) {
                                iconRow(icon: "circle.fill", iconColor: OrdoColors.success, iconBg: OrdoColors.success, label: "Status", value: "Connected")
                                Divider().padding(.leading, 48)
                                iconRow(icon: "server.rack", iconColor: .white, iconBg: .purple, label: "Middleware", value: shortURL(session.backendBaseURL.absoluteString))
                                Divider().padding(.leading, 48)
                                iconRow(icon: "globe", iconColor: .white, iconBg: .blue, label: "Odoo", value: shortURL(session.odooURL))
                                Divider().padding(.leading, 48)
                                iconRow(icon: "cylinder.split.1x2", iconColor: .white, iconBg: .orange, label: "Database", value: session.database)
                                if let version = appState.displayVersion {
                                    Divider().padding(.leading, 48)
                                    iconRow(icon: "info.circle", iconColor: .white, iconBg: .gray, label: "Version", value: version)
                                }
                            }
                        }
                    }
                }

                // MARK: - Storage
                VStack(alignment: .leading, spacing: OrdoSpacing.sm) {
                    Text("STORAGE")
                        .font(OrdoTypography.caption)
                        .foregroundStyle(OrdoColors.textTertiary)
                        .fontWeight(.semibold)
                        .padding(.horizontal, OrdoSpacing.xs)

                    OrdoCard {
                        Button {
                            Task {
                                do {
                                    try await appState.clearCache()
                                    cacheMessage = "Offline cache cleared."
                                } catch {
                                    cacheMessage = error.localizedDescription
                                }
                            }
                        } label: {
                            HStack(spacing: OrdoSpacing.md) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(OrdoColors.danger, in: RoundedRectangle(cornerRadius: OrdoRadius.sm, style: .continuous))

                                Text("Clear Offline Cache")
                                    .font(.body)
                                    .foregroundStyle(OrdoColors.danger)

                                Spacer()
                            }
                        }

                        if let cacheMessage {
                            Text(cacheMessage)
                                .font(.footnote)
                                .foregroundStyle(OrdoColors.textSecondary)
                                .padding(.top, OrdoSpacing.xs)
                        }
                    }
                }

                // MARK: - About
                VStack(alignment: .leading, spacing: OrdoSpacing.sm) {
                    Text("ABOUT")
                        .font(OrdoTypography.caption)
                        .foregroundStyle(OrdoColors.textTertiary)
                        .fontWeight(.semibold)
                        .padding(.horizontal, OrdoSpacing.xs)

                    OrdoCard {
                        VStack(spacing: 0) {
                            iconRow(icon: "app.badge", iconColor: .white, iconBg: OrdoColors.accent, label: "App Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                            Divider().padding(.leading, 48)
                            iconRow(icon: "hammer.fill", iconColor: .white, iconBg: .gray, label: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                        }
                    }
                }

                // MARK: - Sign Out
                OrdoCard {
                    Button {
                        appState.signOut()
                    } label: {
                        HStack(spacing: OrdoSpacing.md) {
                            Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(OrdoColors.danger, in: RoundedRectangle(cornerRadius: OrdoRadius.sm, style: .continuous))

                            Text("Sign Out")
                                .font(.body)
                                .foregroundStyle(OrdoColors.danger)

                            Spacer()
                        }
                    }
                }
            }
            .padding(.horizontal, OrdoSpacing.lg)
            .padding(.vertical, OrdoSpacing.sm)
        }
        .background(OrdoColors.surfaceGrouped)
        .navigationTitle("Settings")
    }

    // MARK: - Row Components

    /// Icon row mimicking SnapCal's settings row style:
    /// [colored icon circle] Label ..................... Value
    private func iconRow(icon: String, iconColor: Color, iconBg: Color, label: String, value: String) -> some View {
        HStack(spacing: OrdoSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconBg, in: RoundedRectangle(cornerRadius: OrdoRadius.sm, style: .continuous))

            Text(label)
                .font(.body)
                .foregroundStyle(OrdoColors.textSecondary)

            Spacer()

            Text(value)
                .font(.body)
                .foregroundStyle(OrdoColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.vertical, OrdoSpacing.sm)
    }

    private func shortURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        let host = url.host ?? urlString
        if let port = url.port {
            return "\(host):\(port)"
        }
        return host
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState.preview)
    }
}
