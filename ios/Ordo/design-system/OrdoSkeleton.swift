import SwiftUI

/// Shimmer loading placeholder matching SnapCal's SCSkeleton.
struct OrdoSkeleton: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16

    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.12))
            .overlay(
                shimmerGradient
                    .offset(x: phase)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 300
                }
            }
    }

    private var shimmerGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.clear,
                Color.white.opacity(0.2),
                Color.clear,
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 120)
    }
}

/// A group of skeleton rows for card-shaped loading placeholders.
struct OrdoSkeletonCard: View {
    var lines: Int = 3

    var body: some View {
        OrdoCard {
            VStack(alignment: .leading, spacing: OrdoSpacing.md) {
                ForEach(0..<lines, id: \.self) { i in
                    OrdoSkeleton(
                        width: i == 0 ? 120 : nil,
                        height: i == 0 ? 20 : 14
                    )
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        OrdoSkeletonCard(lines: 3)
        OrdoSkeletonCard(lines: 2)
    }
    .padding()
    .background(OrdoColors.surfaceGrouped)
}
