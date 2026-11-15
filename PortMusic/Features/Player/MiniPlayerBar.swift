import SwiftUI

public struct MiniPlayerBar: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    public let serverURL: String
    public let onOpenFullscreen: () -> Void

    public init(serverURL: String, onOpenFullscreen: @escaping () -> Void) {
        self.serverURL = serverURL
        self.onOpenFullscreen = onOpenFullscreen
    }

    public var body: some View {
        if let track = player.currentTrack {
            Button(action: onOpenFullscreen) {
                VStack(spacing: 0) {
                    // Schlanker Fortschrittsbalken oben
                    GeometryReader { geo in
                        let progress = player.duration > 0 ? (player.currentTime / player.duration) : 0.0
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 2)

                            Rectangle()
                                .fill(Color.white)
                                .frame(width: max(0, min(geo.size.width * CGFloat(progress), geo.size.width)), height: 2)
                        }
                    }
                    .frame(height: 2)

                    HStack(spacing: 12) {
                        // Cover Artwork
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(PortColors.surfaceGlassStrong)
                                .frame(width: 44, height: 44)

                            if let cover = track.coverUrl, let url = URL(string: cover) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    default:
                                        Image(systemName: "music.note")
                                            .font(.system(size: 18))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                            } else {
                                Image(systemName: "music.note")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .frame(width: 44, height: 44)

                        // Titel & Interpret
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(PortColors.textPrimary)
                                .lineLimit(1)

                            Text(track.artist)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.70))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        // Steuerung: Play/Pause & Weiter
                        HStack(spacing: 16) {
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                player.togglePlayPause()
                            }) {
                                ZStack {
                                    if player.isBuffering {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.85)
                                    } else {
                                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(width: 32, height: 32)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                player.next(serverURL: serverURL)
                            }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.trailing, 6)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(PortColors.surfaceGlassStrong)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.65))
                                .blur(radius: 8)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(PortColors.borderGlass, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 12, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }
}
