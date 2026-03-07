import SwiftUI

struct AvatarView: View {
    let name: String
    var size: CGFloat = 40

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let result = parts.map { String($0.prefix(1)).uppercased() }.joined()
        return result.isEmpty ? "?" : result
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(OrdoColors.avatarColor(for: name), in: Circle())
            .accessibilityLabel("\(name) avatar")
    }
}

#Preview("Single") {
    AvatarView(name: "Tuấn Lê", size: 64)
}

#Preview("Grid") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
        AvatarView(name: "Administrator")
        AvatarView(name: "My Company")
        AvatarView(name: "Azure Interior")
        AvatarView(name: "Ready Mat")
        AvatarView(name: "Gemini Corp")
        AvatarView(name: "Delta PC")
    }
    .padding()
}
