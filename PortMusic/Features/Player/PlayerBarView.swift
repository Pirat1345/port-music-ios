import SwiftUI

// MARK: - Floating Frosted Glass MiniPlayer (Apple Liquid Glass Kapsel mit Gestensteuerung)
public struct PlayerBarView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    public let serverURL: String
    public let isInline: Bool
    public let onOpenFullscreen: () -> Void

    @State private var dragProgress: Double? = nil
    @State private var horizontalDragOffset: CGFloat = 0
    @State private var isSwiping: Bool = false

    public init(serverURL: String, isInline: Bool = false, onOpenFullscreen: @escaping () -> Void) {
        self.serverURL = serverURL
        self.isInline = isInline
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
            ZStack(alignment: .bottom) {
                if isInline {
                    inlineContentView(track: track)
                        .transition(AnyTransition.opacity)
                } else {
                    expandedContentView(track: track)
                        .transition(AnyTransition.opacity)
                }
            }
            .frame(height: isInline ? 62 : 48)
            .background(
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.18), location: 0.0),
                                    .init(color: Color.white.opacity(0.04), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
            )
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: isInline)
        }
    }

    // MARK: - Inline Minibar (Exakt wie in Octave: Sitzt im minimierten Zustand zwischen linkem und rechtem 62pt-Kreis)
    @ViewBuilder
    private func inlineContentView(track: Track) -> some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onOpenFullscreen()
        }) {
            HStack(spacing: 10) {
                // Mini Cover Artwork (38x38, 8pt Radius)
                let resolved = resolveCoverURL(track.coverUrl, serverURL: serverURL)
                PortCachedAsyncImage(url: resolved) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 38, height: 38)
                }
                .shadow(color: Color.black.opacity(0.30), radius: 3, y: 1)

                // Titel
                Text(track.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Play / Pause Button (32x32 runder Glasbutton)
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    player.togglePlayPause()
                }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.18)))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .frame(height: 62)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Vollwertige Schwebende Minibar (Im Ruhezustand über der durchgehenden Leiste)
    @ViewBuilder
    private func expandedContentView(track: Track) -> some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 10) {
                // Linker Bereich: Cover + Titel + Interpret (Antippen oeffnet Vollbild)
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onOpenFullscreen()
                }) {
                    HStack(spacing: 10) {
                        // Cover-Artwork (44x44 Standard)
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.08))
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
                                    .font(.system(size: 15))
                                    .foregroundColor(Color.white.opacity(0.5))
                            }
                        }
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.black.opacity(0.25), radius: 3, y: 1.5)

                        // Titel und Interpret
                        let displayTitle = track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unbekannter Titel" : track.title
                        let displayArtist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unbekannter Interpret" : track.artist

                        VStack(alignment: .leading, spacing: 1) {
                            Text(displayTitle)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text(displayArtist)
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundColor(Color.white.opacity(0.65))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .offset(x: horizontalDragOffset)

                // Rechter Bereich: Apple Music Transport-Buttons (Play/Pause, Weiter)
                HStack(spacing: 8) {
                    // Play/Pause Button
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        player.togglePlayPause()
                    }) {
                        if player.isBuffering {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.80)
                                .frame(width: 30, height: 30)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Naechster Titel (forward.fill)
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        player.next(serverURL: serverURL)
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.90))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            // Gesten: Wischen nach oben oeffnet Vollbild, Wischen horizontal wechselt Titel
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { val in
                        if abs(val.translation.width) > abs(val.translation.height) {
                            isSwiping = true
                            horizontalDragOffset = val.translation.width
                        }
                    }
                    .onEnded { val in
                        let dx = val.translation.width
                        let dy = val.translation.height
                        let velocityX = val.predictedEndTranslation.width - val.translation.width
                        let velocityY = val.predictedEndTranslation.height - val.translation.height

                        // 1. Wischen nach oben: Vollbild-Player oeffnen (wie in Apple Music)
                        if dy < -25 || velocityY < -35 {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                                onOpenFullscreen()
                            }
                            return
                        }

                        // 2. Horizontales Wischen: Vorheriger / Naechster Titel
                        guard isSwiping else { return }
                        isSwiping = false
                        if dx < -45 || velocityX < -60 {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            player.next(serverURL: serverURL)
                        } else if dx > 45 || velocityX > 60 {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            player.previous(serverURL: serverURL)
                        }
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                            horizontalDragOffset = 0
                        }
                    }
            )

            // 2px filigrane Fortschrittslinie direkt am unteren Rand der Kapsel
            timelineScrubberSection
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
        }
    }

    // MARK: - Timeline Scrubber Section
    private var timelineScrubberSection: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let ratio = max(0.0, min(1.0, activeProgress))

            ZStack(alignment: .leading) {
                // Hintergrund-Leiste
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 2.5)

                // Aktiver Fortschritt
                Capsule()
                    .fill(Color.white.opacity(0.90))
                    .frame(width: max(0, w * CGFloat(ratio)), height: 2.5)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        let r = max(0.0, min(1.0, Double(val.location.x / w)))
                        dragProgress = r
                    }
                    .onEnded { val in
                        let r = max(0.0, min(1.0, Double(val.location.x / w)))
                        let target = r * player.duration
                        player.seek(to: target)
                        dragProgress = nil
                    }
            )
        }
        .frame(height: 2.5)
    }
}
