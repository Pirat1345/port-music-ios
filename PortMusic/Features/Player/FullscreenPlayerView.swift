import SwiftUI
import MediaPlayer

public struct FullscreenPlayerView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var volumeManager = SystemVolumeManager.shared
    public let serverURL: String
    public let onClose: () -> Void

    @State private var isScrubbing: Bool = false
    @State private var scrubPosition: Double = 0.0
    @State private var showQueueSheet: Bool = false
    @State private var isFavorite: Bool = false
    @State private var showLyrics: Bool = false
    @State private var dragOffset: CGFloat = 0.0
    @State private var volume: Float = 0.7

    // Feature #18: Synced Lyrics State
    @State private var lyricsLines: [LyricLine] = []
    @State private var isLoadingLyrics: Bool = false
    @State private var lyricsSizeScale: CGFloat = 1.0

    // Feature #20: Recommendations State
    @State private var recommendations: [Track] = []

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
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let isTablet = UIDevice.current.userInterfaceIdiom == .pad

            ZStack {
                // Reines Schwarz als Basis-Hintergrund gemaess Invariante
                Color.black
                    .ignoresSafeArea()

                // Weichgezeichneter Album-Hintergrund
                backgroundLayer

                VStack(spacing: 0) {
                    // Safe Top Clearance (stellt sicher, dass Griff und Header nicht in Notch/Statusbar rutschen)
                    Color.clear
                        .frame(height: max(14, safeTop))

                    // Drag-Pill Griff oben
                    pullDownHandle
                        .padding(.top, 4)
                        .padding(.bottom, 6)

                    // Obere Leiste mit Schliessen-Button
                    headerBar
                        .padding(.horizontal, isTablet ? 32 : 24)
                        .padding(.vertical, 6)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: isTablet ? 26 : 22) {
                            Spacer(minLength: 4)

                            // Artwork oder synchronisierter Songtext (Feature #18)
                            if showLyrics {
                                lyricsSection
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            } else {
                                // Grosses Albumcover mit Feder-Animation (Spring-Bounce) auf Play/Pause
                                artworkSection
                            }

                            // Titel, Interpret & Herz-Favoriten-Button
                            trackInfoSection

                            // Interaktiver Scrubber (Timeline mit negativer Restzeit)
                            scrubberSection

                            // Steuerungselemente (Shuffle, Vorheriger, Play/Pause, Naechster, Repeat)
                            playbackControlsSection

                            // Lautstaerke-Regler
                            volumeSliderSection

                            // Zusatz-Aktionen: Songtext, AirPlay, Warteschlange
                            bottomActionsSection

                            // Song-Details & Empfehlungen (Feature #20)
                            songDetailsAndRecommendationsSection

                            Spacer(minLength: 28)
                        }
                        .frame(maxWidth: isTablet ? 480 : 440)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, isTablet ? 36 : 28)
                    }
                }
                .offset(y: max(0, dragOffset))
            }
            .preferredColorScheme(.dark)
            .onAppear {
                volumeManager.syncVolume()
                self.volume = volumeManager.volume
                if let track = player.currentTrack {
                    self.isFavorite = FavoritesManager.shared.isFavorite(trackId: track.id)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { val in
                        if val.translation.height > 0 {
                            dragOffset = val.translation.height
                        }
                    }
                    .onEnded { val in
                        if val.translation.height > 120 {
                            onClose()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .sheet(isPresented: $showQueueSheet) {
                QueueSheetView(serverURL: serverURL, onClose: { showQueueSheet = false })
            }
            .task(id: player.currentTrack?.id) {
                await loadTrackExtras()
            }
        }
    }

    // MARK: - Drag Handle
    private var pullDownHandle: some View {
        Capsule()
            .fill(Color.white.opacity(0.35))
            .frame(width: 38, height: 5)
    }

    // MARK: - Hintergrund
    private var backgroundLayer: some View {
        ZStack {
            let resolved = resolveCoverURL(player.currentTrack?.coverUrl, serverURL: serverURL)
            PortCachedAsyncImage(url: resolved) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 65)
                    .opacity(0.32)
                    .ignoresSafeArea()
            } placeholder: {
                Color.black.ignoresSafeArea()
            }

            LinearGradient(
                colors: [Color.black.opacity(0.35), Color.black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Header (Clean dismiss button)
    private var headerBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.80))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            Spacer()

            if let album = player.currentTrack?.album, !album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(album)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.70))
                    .lineLimit(1)
            }

            Spacer()

            // Platzhalter fuer Symmetrie
            Color.clear
                .frame(width: 38, height: 38)
        }
    }

    // MARK: - Album Cover mit Feder-Animation (Spring Scale)
    private var artworkSection: some View {
        ZStack {
            let resolved = resolveCoverURL(player.currentTrack?.coverUrl, serverURL: serverURL)
            PortCachedAsyncImage(url: resolved) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            } placeholder: {
                ZStack {
                    Color.white.opacity(0.08)
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .clipShape(RoundedRectangle(cornerRadius: 22))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 360 : 320)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(player.isPlaying ? 0.70 : 0.40),
            radius: player.isPlaying ? 28 : 14,
            y: player.isPlaying ? 14 : 6
        )
        .scaleEffect(player.isPlaying ? 1.0 : 0.86)
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: player.isPlaying)
    }

    // MARK: - Synced Karaoke Lyrics Section (Feature #18)
    private var lyricsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Songtext")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.60))

                Spacer()

                Button(action: {
                    lyricsSizeScale = (lyricsSizeScale >= 1.25) ? 0.9 : (lyricsSizeScale + 0.15)
                }) {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.65))
                        .padding(6)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 8)

            if isLoadingLyrics {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Lade Songtext...")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.50))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if lyricsLines.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 32))
                        .foregroundColor(Color.white.opacity(0.30))
                    Text("Kein synchronisierter Songtext verfügbar")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.50))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(lyricsLines) { line in
                                let isCurrent = currentLyricId == line.id
                                Text(line.text)
                                    .font(.system(size: (isCurrent ? 22 : 18) * lyricsSizeScale, weight: isCurrent ? .bold : .medium))
                                    .foregroundColor(isCurrent ? Color.white : Color.white.opacity(0.35))
                                    .id(line.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        player.seek(to: line.time)
                                    }
                                    .animation(.easeInOut(duration: 0.25), value: isCurrent)
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    .onChange(of: currentLyricId) { newId in
                        if let id = newId {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 320, minHeight: 320, maxHeight: 320)
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var currentLyricId: String? {
        guard !lyricsLines.isEmpty else { return nil }
        let time = activeProgress
        let matched = lyricsLines.last(where: { $0.time <= time + 0.15 })
        return matched?.id ?? lyricsLines.first?.id
    }

    // MARK: - Titel, Interpret & Herz-Favorit
    private var trackInfoSection: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentTrack?.title ?? "Kein Titel")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(PortColors.textPrimary)
                    .lineLimit(1)

                Text(player.currentTrack?.artist ?? "Unbekannter Interpret")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.70))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                guard let track = player.currentTrack else { return }
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                isFavorite.toggle()
                FavoritesManager.shared.setFavorite(trackId: track.id, isFavorite: isFavorite)
                Task {
                    let token = SessionManager.shared.currentToken
                    let ok = await MusicService.shared.toggleFavorite(track: track, serverURL: serverURL, token: token)
                    if !ok {
                        await MainActor.run {
                            isFavorite.toggle()
                            FavoritesManager.shared.setFavorite(trackId: track.id, isFavorite: isFavorite)
                        }
                    }
                }
            }) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isFavorite ? Color(hex: "#fc3c44") : Color.white.opacity(0.70))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scrubber mit negativer Restzeit
    private var scrubberSection: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                let maxDur = max(player.duration, 1.0)
                let pct = min(1.0, max(0.0, activeProgress / maxDur))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 5)

                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, width * CGFloat(pct)), height: 5)

                    Circle()
                        .fill(Color.white)
                        .frame(width: isScrubbing ? 16 : 12, height: isScrubbing ? 16 : 12)
                        .shadow(color: Color.black.opacity(0.4), radius: 3)
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

            // Links vergangen, Rechts verbleibend (-0:00)
            HStack {
                Text(formatSeconds(activeProgress))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.65))

                Spacer()

                let remaining = max(0, player.duration - activeProgress)
                Text("-" + formatSeconds(remaining))
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
                    .foregroundColor(player.isShuffle ? Color.white : Color.white.opacity(0.40))
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

            // Play / Pause Haupt-Button (Rein weiss, monochrom)
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                player.togglePlayPause()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 68, height: 68)
                        .shadow(color: Color.white.opacity(0.20), radius: 10, y: 3)

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

            // Naechster Song
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
                    .foregroundColor(player.isRepeat ? Color.white : Color.white.opacity(0.40))
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Lautstaerke-Slider
    private var volumeSliderSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.50))

            GeometryReader { geo in
                let width = geo.size.width
                let currentVolume = volumeManager.volume
                let pct = CGFloat(max(0.0, min(1.0, currentVolume)))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 4)

                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, width * pct), height: 4)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: Color.black.opacity(0.3), radius: 2)
                        .offset(x: max(0, min(width * pct - 7, width - 14)))
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let ratio = Float(max(0.0, min(1.0, val.location.x / width)))
                            self.volume = ratio
                            volumeManager.setVolume(ratio)
                            MPVolumeView.setVolume(ratio)
                        }
                )
            }
            .frame(height: 20)

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.50))
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    // MARK: - Zusatz-Aktionen
    private var bottomActionsSection: some View {
        HStack(spacing: 40) {
            // Lyrics Toggle
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showLyrics.toggle()
                }
            }) {
                Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(showLyrics ? Color.white : Color.white.opacity(0.55))
            }

            // AirPlay Icon
            Button(action: {}) {
                Image(systemName: "airplayaudio")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.55))
            }

            // Queue Button
            Button(action: { showQueueSheet = true }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.55))
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Song Details & Empfehlungen (Feature #20)
    private var songDetailsAndRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.top, 10)

            trackCreditsCard

            if !recommendations.isEmpty {
                recommendationsCard
            }
        }
    }

    private var trackCreditsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Titelinformationen")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.white)

            if let album = player.currentTrack?.album, !album.isEmpty {
                creditRow(label: "Album", value: album)
            }

            if let artist = player.currentTrack?.artist, !artist.isEmpty {
                creditRow(label: "Künstler", value: artist)
            }

            if let dur = player.currentTrack?.duration {
                creditRow(label: "Dauer", value: dur)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func creditRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.50))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white)
        }
    }

    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ähnliche Titel")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.white)

            VStack(spacing: 8) {
                ForEach(recommendations.prefix(6)) { rec in
                    recommendationRow(rec: rec)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func recommendationRow(rec: Track) -> some View {
        Button(action: {
            player.play(track: rec, from: recommendations)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 40, height: 40)

                    let resolved = resolveCoverURL(rec.coverUrl, serverURL: serverURL)
                    PortCachedAsyncImage(url: resolved) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } placeholder: {
                        Image(systemName: "music.note")
                            .font(.system(size: 16))
                            .foregroundColor(Color.white.opacity(0.40))
                    }
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(rec.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(rec.artist)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#a0a0a0"))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color.white.opacity(0.60))
            }
            .padding(8)
            .background(Color.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func loadTrackExtras() async {
        guard let track = player.currentTrack else { return }

        // Sync Favorite Status with Server & Local Cache
        let localFav = FavoritesManager.shared.isFavorite(trackId: track.id)
        await MainActor.run {
            self.isFavorite = localFav
        }
        let token = SessionManager.shared.currentToken
        let serverFav = await MusicService.shared.checkIsFavorite(trackId: track.id, serverURL: serverURL, token: token)
        await MainActor.run {
            self.isFavorite = serverFav
            FavoritesManager.shared.setFavorite(trackId: track.id, isFavorite: serverFav)
        }

        isLoadingLyrics = true
        if let rawLrc = await MusicService.shared.fetchLyrics(trackId: track.id, title: track.title, artist: track.artist, serverURL: serverURL, token: token) {
            lyricsLines = parseLRC(rawLrc)
        } else {
            lyricsLines = []
        }
        isLoadingLyrics = false

        recommendations = await MusicService.shared.fetchRecommendations(trackId: track.id, artist: track.artist, title: track.title, serverURL: serverURL, token: token)
    }

    private func formatSeconds(_ seconds: Double) -> String {
        let sec = Int(max(0, seconds))
        let m = sec / 60
        let s = sec % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Volume Helper
extension MPVolumeView {
    static func setVolume(_ volume: Float) {
        let volumeView = MPVolumeView()
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            slider?.value = volume
        }
    }
}

// MARK: - Queue Sheet
public struct QueueSheetView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    public let serverURL: String
    public let onClose: () -> Void

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Warteschlange")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(PortColors.textPrimary)

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.white.opacity(0.70))
                    }
                }
                .padding(20)

                if player.queue.isEmpty {
                    emptyQueueView
                } else {
                    List {
                        ForEach(Array(player.queue.enumerated()), id: \.offset) { index, item in
                            queueRow(index: index, item: item)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var emptyQueueView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundColor(Color.white.opacity(0.35))
            Text("Keine Titel in der Warteschlange")
                .font(.system(size: 14))
                .foregroundColor(PortColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func queueRow(index: Int, item: Track) -> some View {
        let isCurrent = (index == player.queueIndex)
        Button(action: {
            player.play(track: item, from: player.queue)
        }) {
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(isCurrent ? Color.white : Color.white.opacity(0.40))
                    .frame(width: 24)

                queueCoverImage(url: item.coverUrl)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 14, weight: isCurrent ? .bold : .medium))
                        .foregroundColor(isCurrent ? Color.white : PortColors.textPrimary)
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
                        .foregroundColor(Color.white)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.white.opacity(isCurrent ? 0.12 : 0.04))
    }

    @ViewBuilder
    private func queueCoverImage(url: String?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.08))
                .frame(width: 38, height: 38)

            let resolved = resolveCoverURL(url, serverURL: serverURL)
            PortCachedAsyncImage(url: resolved) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } placeholder: {
                Image(systemName: "music.note")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.40))
            }
        }
        .frame(width: 38, height: 38)
    }
}
