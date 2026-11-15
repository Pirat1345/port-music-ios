import SwiftUI

public struct LibraryView: View {
    public let serverURL: String
    public let user: UserProfile

    public init(serverURL: String, user: UserProfile) {
        self.serverURL = serverURL
        self.user = user
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mediathek")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(PortColors.textPrimary)

                        Text("Deine gespeicherten Songs, Alben und Playlists")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Schnell-Kacheln
                    VStack(spacing: 12) {
                        libraryRowItem(
                            icon: "heart.fill",
                            iconColor: PortColors.accentOrange,
                            title: "Lieblingssongs",
                            subtitle: "Alle von dir mit Herz markierten Tracks"
                        )

                        libraryRowItem(
                            icon: "clock.arrow.circlepath",
                            iconColor: Color(hex: "#64d2ff"),
                            title: "Zuletzt gehört",
                            subtitle: "Deine letzten Streams und Wiedergaben"
                        )

                        libraryRowItem(
                            icon: "square.stack.fill",
                            iconColor: PortColors.successGreen,
                            title: "Playlists & Alben",
                            subtitle: "Eigene Zusammenstellungen"
                        )
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 90)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func libraryRowItem(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(PortColors.textPrimary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.60))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.35))
        }
        .padding(14)
        .background(PortColors.surfaceGlass)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(PortColors.borderGlass, lineWidth: 1)
        )
    }
}
