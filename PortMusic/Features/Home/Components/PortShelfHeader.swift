import SwiftUI

public struct PortShelfHeader: View {
    public let iconName: String
    public let iconColor: Color
    public let title: String
    public let subtitle: String?
    public let seeAllTitle: String?
    public let onSeeAll: (() -> Void)?

    public init(
        iconName: String,
        iconColor: Color = .white,
        title: String,
        subtitle: String? = nil,
        seeAllTitle: String? = nil,
        onSeeAll: (() -> Void)? = nil
    ) {
        self.iconName = iconName
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.seeAllTitle = seeAllTitle
        self.onSeeAll = onSeeAll
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(iconColor)

                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(PortColors.textPrimary)
                }

                if let sub = subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "#a0a0a0"))
                        .lineLimit(1)
                }
            }

            Spacer()

            if let seeAll = seeAllTitle, let action = onSeeAll {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(seeAll)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#a0a0a0"))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "#666666"))
                    }
                }
            }
        }
    }
}
