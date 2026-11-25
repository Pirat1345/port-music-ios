import SwiftUI

public struct PortShelfHeader: View {
    public let iconName: String
    public let iconColor: Color
    public let title: String
    public let subtitle: String?
    public let seeAllTitle: String?
    public let seeAllRoute: AppRoute?
    public let onSeeAll: (() -> Void)?

    public init(
        iconName: String,
        iconColor: Color = .white,
        title: String,
        subtitle: String? = nil,
        seeAllTitle: String? = nil,
        seeAllRoute: AppRoute? = nil,
        onSeeAll: (() -> Void)? = nil
    ) {
        self.iconName = iconName
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.seeAllTitle = seeAllTitle
        self.seeAllRoute = seeAllRoute
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
                        .lineLimit(1)
                }

                if let sub = subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "#a0a0a0"))
                        .lineLimit(1)
                }
            }

            Spacer()

            if let seeAll = seeAllTitle {
                if let route = seeAllRoute {
                    NavigationLink(value: route) {
                        seeAllLabel(seeAll)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else if let action = onSeeAll {
                    Button(action: action) {
                        seeAllLabel(seeAll)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func seeAllLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#a0a0a0"))
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "#666666"))
        }
    }
}
