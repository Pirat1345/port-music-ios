import SwiftUI

// MARK: - Floating Frosted Glass MiniPlayer (Schwebende Kapsel mit Gestensteuerung)
public struct PlayerBarView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    public let serverURL: String
    public let onOpenFullscreen: () -> Void

    @State private var dragProgress: Double? = nil
    @State private var horizontalDragOffset: CGFloat = 0
    @State private var isSwiping: Bool = false

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
            ZStack(alignment: .bottom) {
                // Schwebende Kapsel (Floating Glass Island)
                HStack(spacing: 12) {
                    // Linker Bereich: Cover + Titel (Antippen oeffnet Vollbild)
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onOpenFullscreen()
                    }) {
                        HStack(spacing: 12) {
                            // Cover-Artwork (44x44, 8pt Radius)
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
                                        .font(.system(size: 18))
                                        .foregroundColor(Color.white.opacity(0.5))
                                }
                            }
                            .frame(width: 44, height: 44)
                            .shadow(color: Color.black.opacity(0.35), radius: 4, y: 2)

                            // Titel und Interpret
                            let displayTitle = track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unbekannter Titel" : track.title
                            let displayArtist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unbekannter Interpret" : track.artist

                            VStack(alignment: .leading, spacing: 2) {
                                Text(displayTitle)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Text(displayArtist)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.65))
                                    .lineLimit(1)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .offset(x: horizontalDragOffset)

                    Spacer(minLength: 4)

                    // Rechter Bereich: Transport-Buttons (Zurueck, Play/Pause, Weiter)
                    HStack(spacing: 12) {
                        // Vorheriger Titel (|◀)
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            player.previous(serverURL: serverURL)
                        }) {
                            Image(systemName: "backward.end.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.85))
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Play/Pause Button
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            player.togglePlayPause()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 38, height: 38)
                                    .shadow(color: Color.black.opacity(0.30), radius: 4, y: 1)

                                if player.isBuffering {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .scaleEffect(0.85)
                                } else {
                                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                        .offset(x: player.isPlaying ? 0 : 1.2)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Naechster Titel (▶|)
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            player.next(serverURL: serverURL)
                        }) {
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.85))
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hex: "#18181b").opacity(0.80))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(0.40), radius: 10, y: 4)
                )
                // Wischgeste horizontal zum Titelwechsel (Glissando)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { val in
                            if abs(val.translation.width) > abs(val.translation.height) {
                                isSwiping = true
                                horizontalDragOffset = val.translation.width * 0.4
                            }
                        }
                        .onEnded { val in
                            guard isSwiping else { return }
                            isSwiping = false
                            let dx = val.translation.width
                            let velocity = val.predictedEndTranslation.width - val.translation.width
                            if dx < -60 || velocity < -80 {
                                // Nach links gewischt: Naechster Titel
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                player.next(serverURL: serverURL)
                            } else if dx > 60 || velocity > 80 {
                                // Nach rechts gewischt: Vorheriger Titel
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                player.previous(serverURL: serverURL)
                            }
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                horizontalDragOffset = 0
                            }
                        }
                )

                // 2px filigrane Fortschrittslinie direkt am unteren Rand der Kapsel
                timelineScrubberSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 2)
            }
            .padding(.horizontal, 10)
        }
    }

    // MARK: - Timeline Scrubber Section
    private var timelineScrubberSection: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let pct = max(0.0, min(1.0, activeProgress))
            let fillWidth = max(0, min(width * CGFloat(pct), width))

            ZStack(alignment: .leading) {
                // Hintergrund-Leiste
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 2)

                // Fortschritts-Fuellung
                Capsule()
                    .fill(Color.white.opacity(0.90))
                    .frame(width: fillWidth, height: 2)
            }
            .frame(height: 2)
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
                        if player.duration > 0 {
                            let targetTime = finalPct * player.duration
                            player.seek(to: targetTime)
                        }
                    }
            )
        }
        .frame(height: 2)
    }
}
