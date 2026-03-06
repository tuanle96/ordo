import SwiftUI

struct BrowseHomeView: View {
    var body: some View {
        List(ModelRegistry.supported) { descriptor in
            NavigationLink {
                RecordListView(descriptor: descriptor)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(descriptor.title)
                            .font(.headline)
                        Text(descriptor.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: descriptor.systemImage)
                        .foregroundStyle(.tint)
                }
            }
            .accessibilityIdentifier("browse-model-\(descriptor.model.replacingOccurrences(of: ".", with: "-"))")
        }
        .navigationTitle("Browse")
        .accessibilityIdentifier("browse-home-screen")
    }
}

#Preview {
    NavigationStack {
        BrowseHomeView()
    }
}
