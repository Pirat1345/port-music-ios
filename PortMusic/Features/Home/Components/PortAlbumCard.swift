import SwiftUI

public struct PortAlbumCard: View {
    public let title: String
    public let subtitle: String
    public let coverUrl: String?
    public let serverURL: String
    public let rank: Int?
    public let isPlaying: Bool
    public let onPlay: () -> Void

    public init(
        title: String,
        subtitle: String,
        coverUrl: String?,
        serverURL: String = "",
        rank: Int? = nil,
        isPlaying: Bool = false,
        onPlay: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.coverUrl = coverUrl
        self.serverURL = serverURL
        self.rank = rank
        self.isPlaying = isPlaying
        self.onPlay = onPlay
    }

    public var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    PortCoverImage(
                        coverUrl: coverUrl,
                        serverURL: serverURL,
                        placeholderIcon: "opticaldisc"
                    )
                    .frame(width: 155, height: 155)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Rang-Badge (falls vorhanden z. B. in Top 100: Global)
                    if let r = rank {
                        Text("\(r)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.75))
                            .clipShape(Capsule())
                            .padding(8)
                    }

                    // Schwebender Play-Button unten rechts
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(PortColors.accentOrange)
                                    .frame(width: 38, height: 38)
                                    .shadow(color: PortColors.accentOrange.opacity(0.40), radius: 6, y: 2)

                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.black)
                                    .offset(x: isPlaying ? 0 : 1)
                            }
                            .padding(8)
                        }
                    }
                }
                .frame(width: 155, height: 155)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 8, y: 3)

                // Titel & Kuenstler
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(PortColors.textPrimary)
                        .lineLimit(1)
                        .frame(width: 155, alignment: .leading)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "#a0a0a0"))
                        .lineLimit(1)
                        .frame(width: 155, alignment: .leading)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
