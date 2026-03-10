import SwiftUI

struct BrowseHomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        BrowseMenuListView(title: "Browse", nodes: appState.browseRoots)
    }
}

#Preview {
    NavigationStack {
        BrowseHomeView()
            .environment(AppState.preview)
    }
}

