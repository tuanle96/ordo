import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section("You") {
                LabeledContent("Name", value: appState.displayUserName)

                if let email = appState.displayEmail {
                    LabeledContent("Email", value: email)
                }
            }

            Section("Connection") {
                if let session = appState.session {
                    LabeledContent("Middleware", value: session.backendBaseURL.absoluteString)
                    LabeledContent("Odoo", value: session.odooURL)
                    LabeledContent("Database", value: session.database)
                }

                if let version = appState.displayVersion {
                    LabeledContent("Version", value: version)
                }
            }

            Section("Ready on iPhone") {
                Label("Browse customers with native list navigation", systemImage: "person.2")
                Label("Search by name and jump into record detail", systemImage: "magnifyingglass")
                Label("Review schema-backed fields in a read-only detail view", systemImage: "doc.text.magnifyingglass")
            }
        }
        .navigationTitle("Home")
        .accessibilityIdentifier("home-screen")
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AppState.preview)
    }
}
