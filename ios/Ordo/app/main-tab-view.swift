import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                BrowseHomeView()
            }
            .tabItem {
                Label("Browse", systemImage: "rectangle.stack.person.crop")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(OrdoColors.accent)
        .accessibilityIdentifier("main-tab-screen")
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState.preview)
}
