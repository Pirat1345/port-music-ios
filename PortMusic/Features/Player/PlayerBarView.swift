import SwiftUI

public struct PlayerBarView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    public let serverURL: String
    public let onOpenFullscreen: () -> Void

    public init(serverURL: String, onOpenFullscreen: @escaping () -> Void) {
        self.serverURL = serverURL
        self.onOpenFullscreen = onOpenFullscreen
    }

    public var body: some View {
        if let track = player.currentTrack {
            VStack(spacing: 0) {
                // 1. Schlanker Fortschrittsbalken oben (2px)
                GeometryReader { geo in
                    let progress = (player.duration > 0 && !player.currentTime.isNaN && player.currentTime.isFinite) ? max(0.0, min(1.0, player.currentTime / player.duration)) : 0.0
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

                // 2. Minibar Inhalt
                HStack(spacing: 12) {
                    // Tap-Zone: Cover + Titel + Artist öffnet Fullscreen-Player
                    Button(action: onOpenFullscreen) {
                        HStack(spacing: 12) {
                            // Cover Artwork mit Hochleistungs-Cache
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(PortColors.surfaceGlassStrong)
                                    .frame(width: 44, height: 44)

                                let resolved = resolveCoverURL(track.coverUrl, serverURL: serverURL)
                                PortCachedAsyncImage(url: resolved) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } placeholder: {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color.white.opacity(0.6))
                                }
                            }
                            .frame(width: 44, height: 44)

                            // Titel & Interpret mit Fallback
                            let displayTitle = track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unbekannter Titel" : track.title
                            let displayArtist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unbekannter Interpret" : track.artist

                            VStack(alignment: .leading, spacing: 3) {
                                Text(displayTitle)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(PortColors.textPrimary)
                                    .lineLimit(1)

                                Text(displayArtist)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.70))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer(minLength: 8)

                    // Transport-Steuerung: Zurück, Play/Pause & Weiter
                    HStack(spacing: 12) {
                        // Zurück-Button
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            player.previous(serverURL: serverURL)
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.85))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Play/Pause-Button mit Ladeindikator
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

                        // Weiter-Button
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            player.next(serverURL: serverURL)
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.85))
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
                            .fill(Color.black.opacity(0.75))
                            .blur(radius: 8)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(PortColors.borderGlass, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 12, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }
}
