import SwiftUI

// MARK: - Colors

enum OrdoColors {
    // Brand
    static let accent = Color.indigo
    static let accentLight = Color.indigo.opacity(0.12)

    // Semantic
    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red

    // Surfaces
    static let surfaceCard = Color(.secondarySystemGroupedBackground)
    static let surfaceGrouped = Color(.systemGroupedBackground)

    // Text
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)
    static let separator = Color(.separator)

    // Avatar palette — deterministic color from name
    static let avatarPalette: [Color] = [
        .indigo, .purple, .pink, .orange, .teal, .cyan, .mint, .brown,
    ]

    static func avatarColor(for name: String) -> Color {
        let hash = abs(name.hashValue)
        return avatarPalette[hash % avatarPalette.count]
    }
}

// MARK: - Typography (Rounded design inspired by SnapCal)

enum OrdoTypography {
    static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let body = Font.body
    static let subheadline = Font.subheadline
    static let caption = Font.caption
    static let fieldLabel = Font.subheadline.weight(.medium)
    static let fieldValue = Font.body
    // Metrics — for large numbers/stats
    static let metric = Font.system(size: 34, weight: .bold, design: .rounded)
    static let metricSmall = Font.system(size: 20, weight: .semibold, design: .rounded)
}

// MARK: - Spacing

enum OrdoSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - Radius

enum OrdoRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
}

// MARK: - Shadow

enum OrdoShadow {
    static func card<V: View>(_ content: V) -> some View {
        content.shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Animation

enum OrdoAnim {
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.7)
    static let quick = Animation.easeOut(duration: 0.2)
}
