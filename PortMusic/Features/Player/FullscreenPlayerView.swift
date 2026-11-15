import SwiftUI

public struct FullscreenPlayerView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    public let serverURL: String
    public let onClose: () -> Void

    @State private var isScrubbing: Bool = false
    @State private var scrubPosition: Double = 0.0
    @State private var showQueueSheet: Bool = false

    public init(serverURL: String, onClose: @escaping () -> Void) {
        self.serverURL = serverURL
        self.onClose = onClose
    }

    private var activeProgress: Double {
        if isScrubbing {
            return scrubPosition
        }
        return player.currentTime
    }

    public var body: some View {
        ZStack {
            // Atmosphärischer weichgezeichneter Album-Hintergrund
            backgroundLayer

            VStack(spacing: 0) {
                // Obere Leiste mit Schließen-Button & Titel
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        Spacer(minLength: 8)

                        // Großes Albumcover mit dezentem Leuchten
                        artworkSection

                        // Titel & Interpret
                        trackInfoSection

                        // Interaktiver Scrubber (Timeline)
                        scrubberSection

                        // Steuerungselemente (Shuffle, Vorheriger, Play/Pause, Nächster, Repeat)
                        playbackControlsSection

                        // Zusatz-Aktionen: Warteschlange
                        bottomActionsSection

                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 24)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showQueueSheet) {
            QueueSheetView(serverURL: serverURL, onClose: { showQueueSheet = false })
        }
    }

    // MARK: - Hintergrund
    private var backgroundLayer: some View {
        ZStack {
            Color(red: 0.03, green: 0.03, blue: 0.04).ignoresSafeArea()

            if let cover = player.currentTrack?.coverUrl, let url = URL(string: cover) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 60)
                            .opacity(0.35)
                            .ignoresSafeArea()
                    }
                }
            }

            LinearGradient(
                colors: [Color.black.opacity(0.4), Color.black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(PortColors.surfaceGlass)
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text("AKTUELLE WIEDERGABE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(Color.white.opacity(0.65))

                if let album = player.currentTrack?.album, !album.isEmpty {
                    Text(album)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(PortColors.textPrimary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: { showQueueSheet = true }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(PortColors.surfaceGlass)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Album Cover
    private var artworkSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(PortColors.surfaceGlassStrong)
                .aspectRatio(1, contentMode: .fit)

            if let cover = player.currentTrack?.coverUrl, let url = URL(string: cover) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                    default:
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: 320)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.6), radius: 24, y: 12)
    }

    // MARK: - Titel & Interpret
    private var trackInfoSection: some View {
        VStack(spacing: 6) {
            Text(player.currentTrack?.title ?? "Kein Titel")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(PortColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(player.currentTrack?.artist ?? "Unbekannter Interpret")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.white.opacity(0.70))
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scrubber
    private var scrubberSection: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                let maxDur = max(player.duration, 1.0)
                let pct = min(1.0, max(0.0, activeProgress / maxDur))

                ZStack(alignment: .leading) {
                    // Track-Hintergrund
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 5)

                    // Aktiver Fortschritt
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, width * CGFloat(pct)), height: 5)

                    // Scrubber Daumen
                    Circle()
                        .fill(Color.white)
                        .frame(width: isScrubbing ? 16 : 12, height: isScrubbing ? 16 : 12)
                        .shadow(color: Color.black.opacity(0.3), radius: 3)
                        .offset(x: max(0, min(width * CGFloat(pct) - 6, width - 12)))
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            isScrubbing = true
                            let progressRatio = max(0.0, min(1.0, Double(val.location.x / width)))
                            scrubPosition = progressRatio * maxDur
                        }
                        .onEnded { val in
                            let progressRatio = max(0.0, min(1.0, Double(val.location.x / width)))
                            let target = progressRatio * maxDur
                            player.seek(to: target)
                            isScrubbing = false
                        }
                )
            }
            .frame(height: 24)

            // Zeitangaben (links vergangen, rechts Rest/Gesamt)
            HStack {
                Text(formatSeconds(activeProgress))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.65))

                Spacer()

                Text(formatSeconds(player.duration))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.65))
            }
        }
    }

    // MARK: - Playback Controls
    private var playbackControlsSection: some View {
        HStack(spacing: 24) {
            // Shuffle
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.toggleShuffle()
            }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(player.isShuffle ? PortColors.successGreen : Color.white.opacity(0.55))
                    .frame(width: 36, height: 36)
            }

            Spacer()

            // Vorheriger Song
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.previous(serverURL: serverURL)
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            // Play / Pause Haupt-Button (Weiß, Monochrom)
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                player.togglePlayPause()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 68, height: 68)
                        .shadow(color: Color.white.opacity(0.25), radius: 12, y: 4)

                    if player.isBuffering {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(1.1)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                }
            }

            // Nächster Song
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.next(serverURL: serverURL)
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Repeat
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.toggleRepeat()
            }) {
                Image(systemName: "repeat")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(player.isRepeat ? PortColors.successGreen : Color.white.opacity(0.55))
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Bottom Actions
    private var bottomActionsSection: some View {
        HStack(spacing: 20) {
            Text("Warteschlange: \(player.queue.count) Titel")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.white.opacity(0.60))
        }
        .padding(.top, 8)
    }

    private func formatSeconds(_ seconds: Double) -> String {
        let sec = Int(max(0, seconds))
        let m = sec / 60
        let s = sec % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Queue Sheet
public struct QueueSheetView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    public let serverURL: String
    public let onClose: () -> Void

    public var body: some View {
        ZStack {
            FluentBackgroundView()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Warteschlange")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(PortColors.textPrimary)

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(20)

                if player.queue.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundColor(Color.white.opacity(0.4))
                        Text("Keine Titel in der Warteschlange")
                            .font(.system(size: 14))
                            .foregroundColor(PortColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, item in
                            let isCurrent = (index == player.queueIndex)
                            Button(action: {
                                player.play(track: item, from: player.queue, serverURL: serverURL)
                            }) {
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(isCurrent ? PortColors.successGreen : Color.white.opacity(0.5))
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .font(.system(size: 14, weight: isCurrent ? .bold : .medium))
                                            .foregroundColor(isCurrent ? PortColors.successGreen : PortColors.textPrimary)
                                            .lineLimit(1)

                                        Text(item.artist)
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.white.opacity(0.65))
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    if isCurrent {
                                        Image(systemName: "waveform")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(PortColors.successGreen)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.white.opacity(isCurrent ? 0.08 : 0.03))
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
