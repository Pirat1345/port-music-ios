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
    @State private var sidePanelMode: SidePanelMode = .lyrics
    @State private var dragOffset: CGFloat = 0.0
    @State private var volume: Float = 0.7

    // Feature #18: Synced Lyrics State
    @State private var lyricsLines: [LyricLine] = []
    @State private var isLoadingLyrics: Bool = false
    @State private var lyricsSizeScale: CGFloat = 1.0

    public enum SidePanelMode: Equatable {
        case lyrics
        case queue
    }

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

    private var currentLyricId: String? {
        guard !lyricsLines.isEmpty else { return nil }
        let time = activeProgress
        let matched = lyricsLines.last(where: { $0.time <= time + 0.15 })
        return matched?.id ?? lyricsLines.first?.id
    }

    public var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let isTablet = (UIDevice.current.userInterfaceIdiom == .pad) || (geo.size.width >= 700)
            let fullWidth = geo.size.width
            let fullHeight = geo.size.height

            // ── GESAMTER MODAL-CONTAINER (Hintergrund + Inhalt wandern gemeinsam) ──
            // Exakt auf fullWidth x fullHeight begrenzt und geclippt.
            // Beim Ziehen (dragOffset > 0) wandert der Container nach unten.
            // Der freigezogene Bereich oben zeigt direkt die darunterliegende echte Seite (Startseite, Suche, etc.)!
            ZStack(alignment: .top) {
                // 1. Weichgezeichneter Album-Hintergrund (Exakt an Container gebunden)
                backgroundLayer(width: fullWidth, height: fullHeight)

                // 2. Inhalt
                VStack(spacing: 0) {
                    // Kopfleiste mit Schließen-Button (xmark) und Drag-Griff
                    topBarSection(safeTop: safeTop)

                    if isTablet {
                        // Tablet / iPad Split 2-Spalten-Layout (Exakt wie im Web-App Screenshot)
                        tabletSplitLayout(geo: geo)
                    } else {
                        // Smartphone Portrait-Layout (Perfekt zentriert, kein Rechts-Versatz, Lyrics zum Runterscrollen)
                        phoneScrollLayout(geo: geo)
                    }
                }
                .frame(width: fullWidth)
            }
            .frame(width: fullWidth, height: fullHeight)
            .clipped()
            .offset(y: max(0, dragOffset))
            .gesture(
                DragGesture(minimumDistance: 10)
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
        .preferredColorScheme(.dark)
        .onAppear {
            volumeManager.syncVolume()
            self.volume = volumeManager.volume
            if let track = player.currentTrack {
                self.isFavorite = FavoritesManager.shared.isFavorite(trackId: track.id)
            }
        }
    }

    // MARK: - Weichgezeichneter Album-Hintergrund (Ambient Glow)
    public func backgroundLayer(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            let resolved = resolveCoverURL(player.currentTrack?.coverUrl, serverURL: serverURL)
            PortCachedAsyncImage(url: resolved) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .blur(radius: 64)
                    .opacity(0.40)
                    .clipped()
            } placeholder: {
                Color(hex: "#121214")
                    .frame(width: width, height: height)
            }

            // Subtiler dunkler Verlauf für optimalen Lesekontrast
            LinearGradient(
                colors: [Color.black.opacity(0.45), Color.black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    // MARK: - Obere Kopfleiste (Schließen-Button oben links & Drag-Griff)
    private func topBarSection(safeTop: CGFloat) -> some View {
        VStack(spacing: 2) {
            Color.clear
                .frame(height: max(10, safeTop))

            HStack {
                // Schließen-Button oben links (X)
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onClose()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.85))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                // Zentrierter Drag-Pill Griff oben
                pullDownHandle
                    .onTapGesture {
                        onClose()
                    }

                Spacer()

                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Drag Handle
    public var pullDownHandle: some View {
        Capsule()
            .fill(Color.white.opacity(0.35))
            .frame(width: 38, height: 5)
    }

    // MARK: - TABLET / IPAD 2-SPALTEN LAYOUT (Exakt wie im Web-App Screenshot)
    private func tabletSplitLayout(geo: GeometryProxy) -> some View {
        HStack(alignment: .center, spacing: min(56, geo.size.width * 0.06)) {
            // LINKE SPALTE: Cover-Artwork & Bedienelemente
            VStack(spacing: 22) {
                Spacer(minLength: 6)

                // Großes Albumcover mit Feder-Animation
                artworkSection(maxSize: min(geo.size.height * 0.44, 460))

                // Titel, Interpret & Stern-Favorit (☆)
                trackInfoSection

                // Scrubber mit negativer Restzeit (-M:SS)
                scrubberSection

                // Bedienelemente (Shuffle, Repeat, Zurück, Play/Pause rein weiß ohne Kreis, Vor, Lyrics, Queue)
                playbackControlsSection

                // Lautstärke-Regler mit Lautsprecher-Icon
                volumeSliderSection

                Spacer(minLength: 12)
            }
            .frame(width: min(geo.size.width * 0.44, 480))

            // RECHTE SPALTE: Synchronisierte Karaoke Lyrics (oder Queue)
            VStack(alignment: .leading, spacing: 0) {
                if sidePanelMode == .lyrics || showLyrics {
                    tabletLyricsColumn
                } else {
                    tabletQueueColumn
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, min(48, geo.size.width * 0.05))
        .padding(.bottom, 24)
        .frame(width: geo.size.width)
    }

    // MARK: - PHONE PORTRAIT LAYOUT (Perfekt zentriert, kein Rechts-Versatz, Lyrics zum Runterscrollen)
    private func phoneScrollLayout(geo: GeometryProxy) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer(minLength: 8)

                // Albumcover zentriert
                artworkSection(maxSize: min(geo.size.width - 64, 320))

                // Titel, Interpret & Stern-Favorit (☆)
                trackInfoSection

                // Scrubber mit negativer Restzeit
                scrubberSection

                // Bedienelemente (Shuffle, Repeat, Zurück, Play/Pause rein weiß ohne Kreis, Vor, Lyrics, Queue)
                playbackControlsSection

                // Lautstärke-Regler mit Lautsprecher-Icon
                volumeSliderSection

                // Synchronisierter Songtext auf dem Handy direkt darunter zum nahtlosen Runterscrollen
                phoneLyricsSection
                    .padding(.top, 14)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: min(geo.size.width - 40, 420))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 20)
        }
        .frame(width: geo.size.width)
    }

    // MARK: - Album Cover mit Feder-Animation (Spring Scale)
    private func artworkSection(maxSize: CGFloat) -> some View {
        ZStack {
            let resolved = resolveCoverURL(player.currentTrack?.coverUrl, serverURL: serverURL)
            PortCachedAsyncImage(url: resolved) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } placeholder: {
                ZStack {
                    Color.white.opacity(0.08)
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: maxSize)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(player.isPlaying ? 0.65 : 0.35),
            radius: player.isPlaying ? 28 : 14,
            y: player.isPlaying ? 14 : 6
        )
        .scaleEffect(player.isPlaying ? 1.0 : 0.86)
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: player.isPlaying)
    }

    // MARK: - Titel, Interpret & Stern-Favorit (☆ wie im Web-App Screenshot)
    public var trackInfoSection: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentTrack?.title ?? "Kein Titel")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.white)
                    .lineLimit(1)

                Text(player.currentTrack?.artist ?? "Unbekannter Interpret")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer()

            // Stern-Favoriten-Button (☆ im Screenshot)
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
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isFavorite ? Color(hex: "#ffcc00") : Color.white.opacity(0.70))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scrubber mit negativer Restzeit (-M:SS)
    public var scrubberSection: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                let maxDur = max(player.duration, 1.0)
                let pct = min(1.0, max(0.0, activeProgress / maxDur))

                ZStack(alignment: .leading) {
                    // Hintergrundleiste
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 5)

                    // Gespielte Leiste
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, width * CGFloat(pct)), height: 5)

                    // Schieberegler-Knopf
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

            // Links vergangen, Rechts verbleibend (-M:SS)
            HStack {
                Text(formatSeconds(activeProgress))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.60))

                Spacer()

                let remaining = max(0, player.duration - activeProgress)
                Text("-" + formatSeconds(remaining))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.60))
            }
        }
    }

    // MARK: - Playback Controls (Exakt wie im Screenshot media_1794768801325_390874e2.jpg)
    public var playbackControlsSection: some View {
        HStack(spacing: 0) {
            // 1. Shuffle
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.toggleShuffle()
            }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(player.isShuffle ? Color(hex: "#fc3c44") : Color.white.opacity(0.65))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())

            // 2. Repeat
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.toggleRepeat()
            }) {
                Image(systemName: player.isRepeat ? "repeat.1" : "repeat")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(player.isRepeat ? Color(hex: "#fc3c44") : Color.white.opacity(0.65))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())

            // 3. Vorheriger Song (|◀ wie im Screenshot)
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.previous(serverURL: serverURL)
            }) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())

            // 4. Play / Pause Haupt-Button (Reines solid weißes Symbol ohne weißen Kreis!)
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                player.togglePlayPause()
            }) {
                if player.isBuffering {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity)
                } else {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PlainButtonStyle())

            // 5. Nächster Song (▶| wie im Screenshot)
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.next(serverURL: serverURL)
            }) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())

            // 6. Lyrics Toggle (mic wie im Screenshot)
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showLyrics.toggle()
                    sidePanelMode = (sidePanelMode == .lyrics && !showLyrics) ? .queue : .lyrics
                }
            }) {
                Image(systemName: (sidePanelMode == .lyrics || showLyrics) ? "mic.fill" : "mic")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor((sidePanelMode == .lyrics || showLyrics) ? Color(hex: "#fc3c44") : Color.white.opacity(0.65))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())

            // 7. Queue Toggle (list.bullet)
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                if (UIDevice.current.userInterfaceIdiom == .pad) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        sidePanelMode = (sidePanelMode == .queue) ? .lyrics : .queue
                    }
                } else {
                    showQueueSheet = true
                }
            }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor((sidePanelMode == .queue && !showLyrics) ? Color(hex: "#fc3c44") : Color.white.opacity(0.65))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: - Lautstärke-Regler mit Lautsprecher-Icon
    public var volumeSliderSection: some View {
        HStack(spacing: 12) {
            Image(systemName: volume == 0 ? "speaker.slash.fill" : (volume < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.2.fill"))
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.60))
                .frame(width: 22)

            GeometryReader { vGeo in
                let vWidth = vGeo.size.width
                let vPct = CGFloat(max(0.0, min(1.0, volume)))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 4)

                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, vWidth * vPct), height: 4)
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let pct = Float(max(0.0, min(1.0, val.location.x / vWidth)))
                            volume = pct
                            volumeManager.setVolume(pct)
                            player.setVolume(pct)
                        }
                )
            }
            .frame(height: 20)
        }
    }

    // MARK: - Tablet Rechte Spalte: Synchronisierte Karaoke Lyrics (Exakt wie im Screenshot)
    private var tabletLyricsColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isLoadingLyrics {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Lade Songtext...")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.50))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if lyricsLines.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 38))
                        .foregroundColor(Color.white.opacity(0.30))
                    Text("Kein synchronisierter Songtext verfügbar")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.50))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(lyricsLines) { line in
                                let isCurrent = currentLyricId == line.id
                                Text(line.text)
                                    .font(.system(size: (isCurrent ? 24 : 19) * lyricsSizeScale, weight: isCurrent ? .bold : .medium))
                                    .foregroundColor(isCurrent ? Color.white : Color.white.opacity(0.35))
                                    .id(line.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        player.seek(to: line.time)
                                    }
                                    .animation(.easeInOut(duration: 0.25), value: isCurrent)
                            }
                        }
                        .padding(.vertical, 80)
                    }
                    .mask(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.12),
                                .init(color: .black, location: 0.88),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tablet Rechte Spalte: Warteschlange
    private var tabletQueueColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Warteschlange")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 10)

            if player.queue.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 38))
                        .foregroundColor(Color.white.opacity(0.30))
                    Text("Keine Titel in der Warteschlange")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.50))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(player.queue.enumerated()), id: \.offset) { index, item in
                            let isCurrent = (index == player.queueIndex)
                            Button(action: {
                                player.play(track: item, from: player.queue)
                            }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.white.opacity(0.08))
                                            .frame(width: 44, height: 44)

                                        let resolved = resolveCoverURL(item.coverUrl, serverURL: serverURL)
                                        PortCachedAsyncImage(url: resolved) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                                .frame(width: 44, height: 44)
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                        } placeholder: {
                                            Image(systemName: "music.note")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color.white.opacity(0.40))
                                        }
                                    }
                                    .frame(width: 44, height: 44)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .font(.system(size: 14, weight: isCurrent ? .bold : .medium))
                                            .foregroundColor(isCurrent ? Color(hex: "#fc3c44") : Color.white)
                                            .lineLimit(1)
                                        Text(item.artist)
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.white.opacity(0.60))
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    if isCurrent {
                                        Image(systemName: "waveform")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(Color(hex: "#fc3c44"))
                                    }
                                }
                                .padding(10)
                                .background(Color.white.opacity(isCurrent ? 0.12 : 0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Phone Lyrics Section (Unten im Scrollbereich des Handys)
    private var phoneLyricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Songtext")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.85))

                Spacer()

                if !lyricsLines.isEmpty {
                    Text("\(lyricsLines.count) Zeilen")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.45))
                }
            }

            if isLoadingLyrics {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Lade Songtext...")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.50))
                }
                .padding(.vertical, 16)
            } else if lyricsLines.isEmpty {
                Text("Kein synchronisierter Songtext verfügbar")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.45))
                    .padding(.vertical, 16)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(lyricsLines) { line in
                        let isCurrent = currentLyricId == line.id
                        Text(line.text)
                            .font(.system(size: isCurrent ? 20 : 16, weight: isCurrent ? .bold : .medium))
                            .foregroundColor(isCurrent ? Color.white : Color.white.opacity(0.38))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                player.seek(to: line.time)
                            }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func loadTrackExtras() async {
        guard let track = player.currentTrack else { return }

        // Favoriten-Status synchronisieren
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
