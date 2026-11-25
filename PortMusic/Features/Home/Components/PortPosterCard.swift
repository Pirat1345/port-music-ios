import SwiftUI

public struct PortPosterCard: View {
    public let title: String
    public let subtitle: String
    public let coverUrl: String?
    public let serverURL: String
    public let isPlaying: Bool
    public let trackId: String?
    public let onPlay: () -> Void

    private let cardWidth: CGFloat = 204
    private let cardHeight: CGFloat = 282
    private let coverSize: CGFloat = 204
    private var footerHeight: CGFloat { cardHeight - coverSize } // 78pt grosszuegiger Textbereich unten

    public init(
        title: String,
        subtitle: String,
        coverUrl: String?,
        serverURL: String = "",
        isPlaying: Bool = false,
        trackId: String? = nil,
        onPlay: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.coverUrl = coverUrl
        self.serverURL = serverURL
        self.isPlaying = isPlaying
        self.trackId = trackId
        self.onPlay = onPlay
    }

    public var body: some View {
        Button(action: onPlay) {
            ZStack(alignment: .bottomLeading) {
                // Hintergrund & Cover-Praesentation
                ZStack(alignment: .top) {
                    Color(hex: "#1a1a1c")

                    let offlineCover = trackId.flatMap { OfflineDownloadManager.shared.localCoverFileURL(for: $0) }
                    if let resolved = offlineCover ?? resolveCoverURL(coverUrl, serverURL: serverURL) {
                        PortCachedAsyncImage(url: resolved) { image in
                            ZStack(alignment: .top) {
                                // Untere Reflexions-Weichzeichnung als Basis fuer den Textkasten
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: cardWidth, height: cardHeight)
                                    .blur(radius: 22)
                                    .scaleEffect(1.15)
                                    .opacity(0.88)

                                // Scharfes Cover-Bild oben (1:1 Quadrat)
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: cardWidth, height: coverSize)
                                    .clipped()
                            }
                        } placeholder: {
                            Image(systemName: "music.note")
                                .font(.system(size: 34))
                                .foregroundColor(Color.white.opacity(0.20))
                                .frame(width: cardWidth, height: coverSize)
                        }
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 34))
                            .foregroundColor(Color.white.opacity(0.20))
                            .frame(width: cardWidth, height: coverSize)
                    }

                    // Weicher Uebergang und abgedunkelter Kasten unten fuer perfekte Lesbarkeit
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.56),
                            .init(color: Color.black.opacity(0.45), location: 0.72),
                            .init(color: Color.black.opacity(0.88), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Unterer Textkasten exakt unterhalb des scharfen Covers (78pt Hoehe)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                        .lineSpacing(1)
                        .multilineTextAlignment(.leading)
                        .shadow(color: .black.opacity(0.75), radius: 3, y: 1)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.72))
                        .lineLimit(1)
                }
                .padding(.leading, 14)
                .padding(.trailing, 58)
                .padding(.vertical, 8)
                .frame(width: cardWidth, height: footerHeight, alignment: .leading)

                // Schwebender Play-Button unten rechts
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 40, height: 40)
                                .shadow(color: Color.black.opacity(0.45), radius: 6, y: 2)

                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.black)
                                .offset(x: isPlaying ? 0 : 1)
                        }
                        .padding(12)
                    }
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.42), radius: 10, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
