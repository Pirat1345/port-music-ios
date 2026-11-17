import SwiftUI

// MARK: - Floating Frosted Glass MiniPlayer (Schwebende Kapsel mit Gestensteuerung)
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
            if isInline {
                // MARK: - Inline Minibar (Kompakter Modus für minimierte Liquid Glass TabBar)
                // Sitzt exakt zwischen den beiden 62x62 Kreisen (Aktiver Tab links, Suche rechts)
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onOpenFullscreen()
                }) {
                    HStack(spacing: 8) {
                        // Mini Cover Artwork
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
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Play / Pause Button
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
                    .padding(.horizontal, 10)
                    .frame(height: 62)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(.ultraThinMaterial)
                            AppleLiquidGlassView(style: .systemChromeMaterialDark, tintAlpha: 0.38)
                                .clipShape(Capsule())
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color.white.opacity(0.16), location: 0.0),
                                            .init(color: Color.white.opacity(0.06), location: 0.45),
                                            .init(color: Color.clear, location: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color.white.opacity(0.65), location: 0.0),
                                            .init(color: Color.white.opacity(0.24), location: 0.35),
                                            .init(color: Color.white.opacity(0.08), location: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.85
                                )
                        }
                        .shadow(color: Color.black.opacity(0.45), radius: 16, x: 0, y: 8)
                        .shadow(color: Color.black.opacity(0.20), radius: 4, x: 0, y: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // MARK: - Vollwertige Schwebende Minibar (Authentisches Apple Music Design)
                ZStack(alignment: .bottom) {
                    HStack(spacing: 12) {
                        // Linker Bereich: Cover + Titel (Antippen oeffnet Vollbild)
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            onOpenFullscreen()
                        }) {
                            HStack(spacing: 12) {
                                // Cover-Artwork (40x40, 8pt Radius)
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 40, height: 40)

                                    let resolved = resolveCoverURL(track.coverUrl, serverURL: serverURL)
                                    PortCachedAsyncImage(url: resolved) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 40, height: 40)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } placeholder: {
                                        Image(systemName: "music.note")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color.white.opacity(0.5))
                                    }
                                }
                                .frame(width: 40, height: 40)
                                .shadow(color: Color.black.opacity(0.25), radius: 3, y: 1.5)

                                // Titel und Interpret
                                let displayTitle = track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unbekannter Titel" : track.title
                                let displayArtist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unbekannter Interpret" : track.artist

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(displayTitle)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Text(displayArtist)
                                        .font(.system(size: 12, weight: .regular))
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
                        HStack(spacing: 10) {
                            // Play/Pause Button (Reines, randloses Apple Symbol)
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                player.togglePlayPause()
                            }) {
                                if player.isBuffering {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.85)
                                        .frame(width: 32, height: 32)
                                } else {
                                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 19, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Naechster Titel (Apple Music Style: forward.fill)
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                player.next(serverURL: serverURL)
                            }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color.white.opacity(0.90))
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.regularMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            stops: [
                                                .init(color: Color.white.opacity(0.30), location: 0.0),
                                                .init(color: Color.white.opacity(0.10), location: 0.45),
                                                .init(color: Color.white.opacity(0.02), location: 1.0)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 0.65
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
                            .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)
                    )
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

                    // 2px filigrane Fortschrittslinie direkt am unteren Rand der Karte
                    timelineScrubberSection
                        .padding(.horizontal, 14)
                        .padding(.bottom, 2)
                }
            }
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
