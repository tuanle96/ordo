import SwiftUI

struct ActionableFieldRow: View {
    enum Action {
        case phone(String)
        case email(String)
        case url(String)
    }

    let label: String
    let value: String
    let action: Action
    let fieldID: String

    @Environment(\.openURL) private var openURL

    private var icon: String {
        switch action {
        case .phone: "phone.fill"
        case .email: "envelope.fill"
        case .url: "safari.fill"
        }
    }

    private var iconColor: Color {
        switch action {
        case .phone: .green
        case .email: OrdoColors.accent
        case .url: .orange
        }
    }

    private var actionURL: URL? {
        switch action {
        case .phone(let number):
            let cleaned = number.replacingOccurrences(of: " ", with: "")
            return URL(string: "tel:\(cleaned)")
        case .email(let address):
            return URL(string: "mailto:\(address)")
        case .url(let rawURL):
            if rawURL.hasPrefix("http://") || rawURL.hasPrefix("https://") {
                return URL(string: rawURL)
            }
            return URL(string: "https://\(rawURL)")
        }
    }

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: OrdoSpacing.sm) {
                Text(value)
                    .foregroundStyle(OrdoColors.accent)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("field-value-\(fieldID)")

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = actionURL {
                openURL(url)
            }
        }
        .accessibilityIdentifier("field-row-\(fieldID)")
        .accessibilityHint("Tap to open")
    }
}

#Preview {
    List {
        ActionableFieldRow(
            label: "Phone",
            value: "+1 234 567 890",
            action: .phone("+1 234 567 890"),
            fieldID: "phone"
        )
        ActionableFieldRow(
            label: "Email",
            value: "admin@example.com",
            action: .email("admin@example.com"),
            fieldID: "email"
        )
        ActionableFieldRow(
            label: "Website",
            value: "example.com",
            action: .url("example.com"),
            fieldID: "website"
        )
    }
}
