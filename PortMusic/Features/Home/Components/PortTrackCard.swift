import SwiftUI

public struct PortTrackCard: View {
    public let title: String
    public let subtitle: String
    public let coverUrl: String?
    public let rank: Int?
    public let isPlaying: Bool
    public let onPlay: () -> Void

    public init(
        title: String,
        subtitle: String,
        coverUrl: String?,
        rank: Int? = nil,
        isPlaying: Bool = false,
        onPlay: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.coverUrl = coverUrl
        self.rank = rank
        self.isPlaying = isPlaying
        self.onPlay = onPlay
    }

    public var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 8) {
                // Cover-Box 1:1
                ZStack(alignment: .topLeading) {
                    ZStack {
                        Color(hex: "#181818")

                        if let cover = coverUrl, let url = URL(string: cover) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 145, height: 145)
                                        .clipped()
                                default:
                                    Image(systemName: "music.note")
                                        .font(.system(size: 28))
                                        .foregroundColor(Color.white.opacity(0.25))
                                }
                            }
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: 28))
                                .foregroundColor(Color.white.opacity(0.25))
                        }
                    }
                    .frame(width: 145, height: 145)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Rang-Badge (falls vorhanden)
                    if let r = rank {
                        Text("\(r)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
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
                .frame(width: 145, height: 145)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 8, y: 3)

                // Titel & Interpret
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(PortColors.textPrimary)
                        .lineLimit(1)
                        .frame(width: 145, alignment: .leading)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(hex: "#a0a0a0"))
                        .lineLimit(1)
                        .frame(width: 145, alignment: .leading)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
