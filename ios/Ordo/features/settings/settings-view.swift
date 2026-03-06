import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var cacheMessage: String?

    var body: some View {
        Form {
            Section("Profile") {
                LabeledContent("Name", value: appState.displayUserName)

                if let email = appState.displayEmail {
                    LabeledContent("Email", value: email)
                }
            }

            if let session = appState.session {
                Section("Connection") {
                    LabeledContent("Middleware", value: session.backendBaseURL.absoluteString)
                    LabeledContent("Odoo", value: session.odooURL)
                    LabeledContent("Database", value: session.database)

                    if let version = appState.displayVersion {
                        LabeledContent("Version", value: version)
                    }
                }
            }

            Section("Session") {
                Button(role: .destructive) {
                    appState.signOut()
                } label: {
                    Text("Sign Out")
                }
            }

            Section("Storage") {
                Button("Clear Offline Cache", role: .destructive) {
                    Task {
                        do {
                            try await appState.clearCache()
                            cacheMessage = "Offline cache cleared."
                        } catch {
                            cacheMessage = error.localizedDescription
                        }
                    }
                }

                if let cacheMessage {
                    Text(cacheMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState.preview)
    }
}
