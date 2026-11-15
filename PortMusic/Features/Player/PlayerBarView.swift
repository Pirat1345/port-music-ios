import SwiftUI

public struct PlayerBarView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    public let serverURL: String
    public let onOpenFullscreen: () -> Void

    @State private var dragProgress: Double? = nil

    public init(serverURL: String, onOpenFullscreen: @escaping () -> Void) {
        self.serverURL = serverURL
        self.onOpenFullscreen = onOpenFullscreen
    }

    private var progress: Double {
        if let drag = dragProgress {
            return drag
        }
        guard player.duration > 0, !player.currentTime.isNaN && player.currentTime.isFinite else {
            return 0.0
        }
        return max(0.0, min(1.0, player.currentTime / player.duration))
    }

    private var activeProgress: Double {
        progress
    }

    public var body: some View {
        if let track = player.currentTrack {
            VStack(spacing: 0) {
                // Top border line
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)

                // Main Info & Transport Controls Row (Thicker and larger layout)
                HStack(spacing: 14) {
                    // Left area: Cover + Titles (Click opens Fullscreen Player)
                    Button(action: onOpenFullscreen) {
                        HStack(spacing: 14) {
                            // Cover Artwork (44x44, rounded-md)
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
                                        .foregroundColor(Color.white.opacity(0.5))
                                }
                            }
                            .frame(width: 44, height: 44)

                            // Title & Artist
                            let displayTitle = track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unbekannter Titel" : track.title
                            let displayArtist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unbekannter Interpret" : track.artist

                            VStack(alignment: .leading, spacing: 3) {
                                Text(displayTitle)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(PortColors.textPrimary)
                                    .lineLimit(1)

                                Text(displayArtist)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.65))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer(minLength: 8)

                    // Right area: Transport Controls (|◀, Solid White Play/Pause Circle, ▶|)
                    HStack(spacing: 16) {
                        // Previous Track (|◀)
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            player.previous(serverURL: serverURL)
                        }) {
                            Image(systemName: "backward.end.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.85))
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Play/Pause Solid White Circle
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            player.togglePlayPause()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 42, height: 42)
                                    .shadow(color: Color.black.opacity(0.35), radius: 5, y: 1)

                                if player.isBuffering {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.black)
                                        .offset(x: player.isPlaying ? 0 : 1.5)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Next Track (▶|)
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            player.next(serverURL: serverURL)
                        }) {
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.85))
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

                // Timeline Scrubber at the Bottom of PlayerBar
                timelineScrubberSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .background(Color.black)
        }
    }

    // MARK: - Timeline Scrubber Section
    private var timelineScrubberSection: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let pct = max(0.0, min(1.0, activeProgress))
            let thumbX = width * CGFloat(pct)

            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.white.opacity(0.20))
                    .frame(height: 2)

                // Progress Fill Track
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(0, min(thumbX, width)), height: 2)

                // Thumb Knob (white dot)
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: Color.black.opacity(0.4), radius: 2)
                    .offset(x: max(0, min(thumbX - 6, width - 12)))
            }
            .frame(height: 18)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newPct = max(0.0, min(1.0, Double(value.location.x / width)))
                        dragProgress = newPct
                    }
                    .onEnded { value in
                        let finalPct = max(0.0, min(1.0, Double(value.location.x / width)))
                        dragProgress = nil
                        let targetTime = finalPct * player.duration
                        player.seek(to: targetTime)
                    }
            )
        }
        .frame(height: 18)
    }
}
