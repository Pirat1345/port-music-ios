import SwiftUI

public struct PortPosterCard: View {
    public let title: String
    public let subtitle: String
    public let coverUrl: String?
    public let serverURL: String
    public let isPlaying: Bool
    public let onPlay: () -> Void

    public init(
        title: String,
        subtitle: String,
        coverUrl: String?,
        serverURL: String = "",
        isPlaying: Bool = false,
        onPlay: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.coverUrl = coverUrl
        self.serverURL = serverURL
        self.isPlaying = isPlaying
        self.onPlay = onPlay
    }

    public var body: some View {
        Button(action: onPlay) {
            ZStack(alignment: .bottomLeading) {
                // Hintergrund & Cover-Präsentation
                ZStack {
                    Color(hex: "#1a1a1c")

                    if let resolved = resolveCoverURL(coverUrl, serverURL: serverURL) {
                        PortCachedAsyncImage(url: resolved) { image in
                            ZStack {
                                // Untere Reflexions-Weichzeichnung
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 155, height: 207)
                                    .blur(radius: 16)
                                    .scaleEffect(1.1)
                                    .opacity(0.85)

                                // Scharfes Cover-Bild oben
                                VStack(spacing: 0) {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 155, height: 155)
                                        .clipped()
                                    Spacer(minLength: 0)
                                }
                            }
                        } placeholder: {
                            Image(systemName: "music.note")
                                .font(.system(size: 32))
                                .foregroundColor(Color.white.opacity(0.20))
                        }
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 32))
                            .foregroundColor(Color.white.opacity(0.20))
                    }

                    // Weicher Schattenverlauf fuer perfekte Typografie-Lesbarkeit wie im Web
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.35),
                            .init(color: Color.black.opacity(0.40), location: 0.65),
                            .init(color: Color.black.opacity(0.92), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(width: 155, height: 207)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Textbereich unten
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .shadow(color: .black.opacity(0.8), radius: 3, y: 1)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.68))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.trailing, 46)

                // Schwebender Play-Button unten rechts
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 38, height: 38)
                                .shadow(color: Color.black.opacity(0.45), radius: 6, y: 2)

                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.black)
                                .offset(x: isPlaying ? 0 : 1)
                        }
                        .padding(10)
                    }
                }
            }
            .frame(width: 155, height: 207)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 10, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
