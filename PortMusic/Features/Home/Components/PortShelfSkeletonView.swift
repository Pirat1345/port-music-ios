import SwiftUI

public struct PortShelfSkeletonView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Titel Skeleton
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.08))
                .frame(width: 160, height: 22)
                .padding(.horizontal, 20)

            // Karten Skeleton Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<5, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 145, height: 145)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 110, height: 14)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.05))
                                .frame(width: 75, height: 11)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
