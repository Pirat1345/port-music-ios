import SwiftUI
import MediaPlayer

public struct FullscreenPlayerView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var volumeManager = SystemVolumeManager.shared
    @ObservedObject private var progress = AudioPlayerProgress.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared
    public let serverURL: String
    public let onClose: () -> Void

    @State private var isScrubbing: Bool = false
    @State private var scrubPosition: Double = 0.0
    @State private var showQueueSheet: Bool = false
    @State private var isFavorite: Bool = false
    @State private var showLyrics: Bool = false
    @State private var sidePanelMode: SidePanelMode = .none
    @State private var dragOffset: CGFloat = 0.0
    @State private var isDismissing: Bool = false
    @State private var volume: Float = 0.7
    @State private var artworkDragOffset: CGFloat = 0.0

    // Feature #18: Synced Lyrics State
    @State private var lyricsLines: [LyricLine] = []
    @State private var isLoadingLyrics: Bool = false
    @State private var lyricsSizeScale: CGFloat = 1.0

    public enum SidePanelMode: Equatable {
        case none
        case lyrics
        case queue
    }

    public init(serverURL: String, onClose: @escaping () -> Void) {
        self.serverURL = serverURL
        self.onClose = onClose
    }

    private func triggerDismiss(fullHeight: CGFloat) {
        guard !isDismissing else { return }
        isDismissing = true
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            dragOffset = fullHeight + 60
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            onClose()
        }
    }

    private var activeProgress: Double {
        if isScrubbing {
            return scrubPosition
        }
        return progress.currentTime
    }

    private var currentLyricId: String? {
        guard !lyricsLines.isEmpty else { return nil }
        let time = activeProgress
        guard let first = lyricsLines.first, time >= first.time - 0.4 else {
            return nil
        }
        return lyricsLines.last(where: { $0.time <= time + 0.15 })?.id
    }

    public var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let isTablet = (UIDevice.current.userInterfaceIdiom == .pad) && (geo.size.width >= 768)
            let fullWidth = geo.size.width
            let fullHeight = geo.size.height

            // Dynamischer Eckenradius: Im Ruhezustand 0 (vollflächig bis an den Displayrand ohne schwarze Lücken),
            // beim Herunterziehen (dragOffset > 0) blendet sich die 44pt-Kartenabrundung ein:
            let pullProgress = min(1.0, max(0.0, dragOffset / 120.0))
            let dynamicCornerRadius: CGFloat = dragOffset > 0 ? (pullProgress * 44.0) : 0.0

            // ── GESAMTER MODAL-CONTAINER (Hintergrund + Inhalt wandern gemeinsam) ──
            // Exakt auf fullWidth x fullHeight begrenzt und geclippt.
            // Beim Ziehen (dragOffset > 0) wandert der Container nach unten.
            // Der freigezogene Bereich oben zeigt direkt die darunterliegende echte Seite (Startseite, Suche, etc.)!
            ZStack(alignment: .top) {
                // 1. Weichgezeichneter Album-Hintergrund (Exakt an Container gebunden)
                backgroundLayer(width: fullWidth, height: fullHeight)
                    .compositingGroup()

                // 2. Inhalt
                VStack(spacing: 0) {
                    // Kopfleiste mit Drag-Griff
                    topBarSection(safeTop: safeTop, fullHeight: fullHeight)

                    if isTablet && sidePanelMode != .none {
                        // Tablet / iPad Split 2-Spalten-Layout (Exakt wie in Apple Music auf dem iPad bei aktivem Side-Panel)
                        tabletSplitLayout(geo: geo)
                    } else if !isTablet && showLyrics {
                        // Smartphone Vollbild-Songtext-Modus (Mit Live-Karaoke-Scroll)
                        phoneLyricsLayout(geo: geo)
                    } else {
                        // Zentrierter Vollbild-Player (Big Picture Modus sowohl für Smartphone als auch für iPad)
                        centeredPlayerLayout(geo: geo, isTablet: isTablet)
                    }
                }
                .frame(width: fullWidth)
            }
            .frame(width: fullWidth, height: fullHeight)
            .clipShape(RoundedRectangle(cornerRadius: dynamicCornerRadius, style: .continuous))
            .simultaneousGesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .global)
                    .onChanged { val in
                        guard !isDismissing else { return }
                        let dy = val.translation.height
                        if dy > 0 {
                            var transaction = Transaction()
                            transaction.animation = nil
                            withTransaction(transaction) {
                                dragOffset = dy
                            }
                        } else {
                            let damped = dy * 0.15
                            var transaction = Transaction()
                            transaction.animation = nil
                            withTransaction(transaction) {
                                dragOffset = damped
                            }
                        }
                    }
                    .onEnded { val in
                        guard !isDismissing else { return }
                        let dy = val.translation.height
                        let velocityY = val.predictedEndTranslation.height - val.translation.height
                        if dy > 120 || (dy > 60 && velocityY > 150) {
                            triggerDismiss(fullHeight: fullHeight)
                        } else {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .scaleEffect(max(0.88, 1.0 - (max(0, dragOffset) / 1400.0)), anchor: .top)
            .shadow(
                color: Color.black.opacity(dragOffset > 0 ? (pullProgress * 0.60) : 0.0),
                radius: dragOffset > 0 ? (pullProgress * 36) : 0,
                y: dragOffset > 0 ? (pullProgress * 18) : 0
            )
            .offset(y: max(0, dragOffset))
            .sheet(isPresented: $showQueueSheet) {
                QueueSheetView(serverURL: serverURL, onClose: { showQueueSheet = false })
            }
            .task(id: player.currentTrack?.id) {
                await loadTrackExtras()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            dragOffset = 0
            isDismissing = false
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
            // 1. Blickdichte, absolut solide Basis (#0e0e11)
            // Verhindert jegliche unerwünschte Transparenz zur darunterliegenden Seite im geöffneten Zustand:
            Color(hex: "#0e0e11")
                .frame(width: width, height: height)

            // 2. Weichgezeichnetes Cover mit Ambient Glow
            if let artwork = player.nowPlayingArtwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .blur(radius: 64)
                    .opacity(0.50)
                    .scaleEffect(1.25)
                    .clipped()
            } else {
                let offlineCover = player.currentTrack.flatMap { offlineManager.localCoverFileURL(for: $0.id) }
                let resolved = offlineCover ?? resolveCoverURL(player.currentTrack?.coverUrl, serverURL: serverURL)
                PortCachedAsyncImage(url: resolved) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .blur(radius: 64)
                        .opacity(0.50)
                        .scaleEffect(1.25)
                        .clipped()
                } placeholder: {
                    Color.clear
                }
            }

            // 3. Dunkler Kontrast-Verlauf für optimale Lesbarkeit (wie in der Web-App)
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.30), location: 0.0),
                    .init(color: Color.black.opacity(0.48), location: 0.45),
                    .init(color: Color.black.opacity(0.80), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    // MARK: - Safe Area & Kopfleisten-Abstand
    private var deviceSafeTop: CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
            let top = window.safeAreaInsets.top
            if top > 0 { return top }
        }
        let isPad = (UIDevice.current.userInterfaceIdiom == .pad)
        return isPad ? 24 : 50
    }

    // MARK: - Obere Kopfleiste (Drag-Griff zentriert zum Herunterziehen)
    private func topBarSection(safeTop: CGFloat, fullHeight: CGFloat) -> some View {
        let effectiveSafeTop = max(safeTop, deviceSafeTop)
        let topDistance = effectiveSafeTop + 8

        return VStack(spacing: 0) {
            Color.clear
                .frame(height: topDistance)

            // Zentrierter Drag-Griff (Pill Handle) - Antippen schließt, Ziehen folgt flüssig der Hand
            pullDownHandle
                .padding(.top, 4)
                .padding(.bottom, 14)
                .contentShape(Rectangle())
                .onTapGesture {
                    triggerDismiss(fullHeight: fullHeight)
                }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Drag Handle
    public var pullDownHandle: some View {
        Capsule()
            .fill(Color.white.opacity(0.55))
            .frame(width: 46, height: 5)
            .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
    }

    // MARK: - TABLET / IPAD 2-SPALTEN LAYOUT (Wenn Lyrics oder Warteschlange aktiv)
    private func tabletSplitLayout(geo: GeometryProxy) -> some View {
        HStack(alignment: .center, spacing: min(56, geo.size.width * 0.06)) {
            // LINKE SPALTE: Cover-Artwork & Bedienelemente
            VStack(spacing: 20) {
                Spacer(minLength: 6)

                // Großes Albumcover im 1:1 Apple Music Format
                artworkSection(maxSize: min(geo.size.height * 0.44, 420))

                // Titel, Interpret & Favorit
                trackInfoSection

                // Scrubber mit negativer Restzeit (-M:SS)
                scrubberSection

                // Bedienelemente
                playbackControlsSection

                // Lautstärke-Regler
                volumeSliderSection

                // Untere Aktionen (Lyrics, AirPlay, Shuffle, Repeat, Queue)
                bottomActionRow

                Spacer(minLength: 12)
            }
            .frame(width: min(geo.size.width * 0.44, 460))

            // RECHTE SPALTE: Synchronisierte Karaoke Lyrics oder Warteschlange
            VStack(alignment: .leading, spacing: 0) {
                if sidePanelMode == .lyrics {
                    tabletLyricsColumn
                } else if sidePanelMode == .queue {
                    tabletQueueColumn
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, min(48, geo.size.width * 0.05))
        .padding(.bottom, 24)
        .frame(width: geo.size.width)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    // MARK: - PHONE PORTRAIT LYRICS MODUS (Synchronisierter Songtext über den gesamten Bildschirm)
    private func phoneLyricsLayout(geo: GeometryProxy) -> some View {
        let contentWidth = min(geo.size.width - 44, 420)

        return VStack(spacing: 12) {
            // Kompakte Kopfzeile mit Mini-Cover, Song-Info und Schließen-Button
            HStack(spacing: 12) {
                artworkSection(maxSize: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentTrack?.title ?? "Kein Titel")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(player.currentTrack?.artist ?? "Unbekannter Interpret")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showLyrics = false
                    }
                }) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#fc3c44"))
                        .frame(width: 44, height: 44)
                }
            }
            .frame(width: contentWidth)
            .padding(.top, 4)

            // Synchronisierter Karaoke-Songtext mit dynamischem Auto-Scroll
            tabletLyricsColumn
                .frame(width: contentWidth)

            // Scrubber, Transport-Leiste & Aktionen unten
            VStack(spacing: 8) {
                scrubberContent(fixedWidth: contentWidth)
                playbackControlsSection
                    .frame(width: contentWidth)
                bottomActionRow
                    .frame(width: contentWidth)
            }
            .padding(.bottom, max(geo.safeAreaInsets.bottom, 20))
        }
        .frame(width: geo.size.width)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    // MARK: - ZENTRIERTER VOLLBILD PLAYER (Big Picture Modus sowohl für Phone als auch für iPad)
    private func centeredPlayerLayout(geo: GeometryProxy, isTablet: Bool) -> some View {
        let contentWidth = min(geo.size.width - (isTablet ? 96 : 44), isTablet ? 500 : 420)
        let artworkMax = isTablet ? min(contentWidth, geo.size.height * 0.44) : min(contentWidth, geo.size.height * 0.38)

        return VStack(spacing: min(16, geo.size.height * 0.022)) {
            Spacer(minLength: 2)

            // Großes Albumcover im 1:1 Apple Music Format
            artworkSection(maxSize: artworkMax)

            // Titel, Interpret & runde Aktionsbuttons (Favorit & Optionen)
            trackInfoSection
                .frame(width: contentWidth)

            // Scrubber mit Qualitäts-Chip ("High") und negativer Restzeit
            scrubberContent(fixedWidth: contentWidth)
                .frame(width: contentWidth)

            // Große Transport-Bedienelemente (Vorheriger, solider weißer Play/Pause-Button, Nächster)
            playbackControlsSection
                .frame(width: contentWidth)

            // Lautstärke-Schieberegler
            volumeSliderSection
                .frame(width: contentWidth)

            // Untere Aktionszeile (Lyrics, AirPlay, Shuffle, Repeat, Queue)
            bottomActionRow
                .frame(width: contentWidth)

            Spacer(minLength: max(geo.safeAreaInsets.bottom, 16))
        }
        .frame(width: geo.size.width, alignment: .center)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    // MARK: - Album Cover mit Feder-Animation & 1:1 Format (Apple Music Standard)
    private func artworkSection(maxSize: CGFloat) -> some View {
        let isLarge = maxSize > 100
        let cornerRadius: CGFloat = isLarge ? 14 : 8
        return ZStack(alignment: .center) {
            if let artwork = player.nowPlayingArtwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: maxSize, height: maxSize)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                let offlineCover = player.currentTrack.flatMap { offlineManager.localCoverFileURL(for: $0.id) }
                let resolved = offlineCover ?? resolveCoverURL(player.currentTrack?.coverUrl, serverURL: serverURL)
                PortCachedAsyncImage(url: resolved) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: maxSize, height: maxSize)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                } placeholder: {
                    ZStack {
                        Color.white.opacity(0.08)
                        Image(systemName: "music.note")
                            .font(.system(size: isLarge ? 48 : 20))
                            .foregroundColor(Color.white.opacity(0.35))
                    }
                    .frame(width: maxSize, height: maxSize)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            }
        }
        .frame(width: maxSize, height: maxSize)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(
            color: Color.black.opacity(player.isPlaying ? 0.45 : 0.20),
            radius: isLarge ? (player.isPlaying ? 24 : 10) : 4,
            y: isLarge ? (player.isPlaying ? 12 : 5) : 2
        )
        .scaleEffect(isLarge ? (player.isPlaying ? 1.0 : 0.88) : 1.0)
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: player.isPlaying)
        .offset(x: isLarge ? artworkDragOffset : 0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { val in
                    guard isLarge, !isDismissing else { return }
                    if abs(val.translation.width) > abs(val.translation.height) * 1.5 {
                        artworkDragOffset = val.translation.width
                    }
                }
                .onEnded { val in
                    guard isLarge, !isDismissing else { return }
                    if abs(val.translation.width) > abs(val.translation.height) * 1.5 {
                        let dx = val.translation.width
                        let velocityX = val.predictedEndTranslation.width - val.translation.width
                        if dx < -45 || velocityX < -60 {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            player.next(serverURL: serverURL)
                        } else if dx > 45 || velocityX > 60 {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            player.previous(serverURL: serverURL)
                        }
                    }
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                        artworkDragOffset = 0
                    }
                }
        )
    }

    // MARK: - Titel, Interpret, Qualitäts-Chip & Favorit
    public var trackInfoSection: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentTrack?.title ?? "Kein Titel")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.white)
                    .lineLimit(1)

                Text(player.currentTrack?.artist ?? "Unbekannter Interpret")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.70))
                    .lineLimit(1)
            }

            Spacer()

            // Runde Aktionsbuttons rechts: Favorit & Optionen
            HStack(spacing: 10) {
                // Favoriten-Button (Runder Frosted Glass Button mit Herz in #fc3c44)
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
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(isFavorite ? Color(hex: "#fc3c44") : Color.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // Optionen-Menü (Runder Frosted Glass Button mit •••)
                Menu {
                    if let current = player.currentTrack {
                        if offlineManager.isDownloaded(trackId: current.id) {
                            Button(role: .destructive, action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                offlineManager.removeDownload(trackId: current.id)
                            }) {
                                Label("Offline-Download entfernen", systemImage: "trash")
                            }
                        } else if offlineManager.isDownloading(trackId: current.id) {
                            Button(action: {}) {
                                Label("Wird heruntergeladen...", systemImage: "arrow.down.circle")
                            }
                            .disabled(true)
                        } else if !current.isLive {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                Task {
                                    await offlineManager.downloadTrack(
                                        track: current,
                                        serverURL: serverURL,
                                        token: SessionManager.shared.currentToken
                                    )
                                }
                            }) {
                                Label("Offline speichern", systemImage: "arrow.down.circle")
                            }
                        }

                        Divider()
                    }

                    Button(action: {
                        if (UIDevice.current.userInterfaceIdiom == .pad) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                sidePanelMode = (sidePanelMode == .queue) ? .none : .queue
                            }
                        } else {
                            showQueueSheet = true
                        }
                    }) {
                        Label("Warteschlange anzeigen", systemImage: "list.bullet")
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scrubber mit negativer Restzeit (-M:SS)
    public var scrubberSection: some View {
        scrubberContent(fixedWidth: nil)
    }

    @ViewBuilder
    private func scrubberContent(fixedWidth: CGFloat?) -> some View {
        VStack(spacing: 8) {
            if let w = fixedWidth {
                scrubberBar(width: w)
            } else {
                GeometryReader { geo in
                    scrubberBar(width: geo.size.width)
                }
                .frame(height: 24)
            }

            // Links vergangen, Mitte Qualitäts-Chip ("High" / "Lossless"), Rechts verbleibend (-M:SS)
            HStack {
                Text(formatSeconds(activeProgress))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.60))

                Spacer()

                let isOfflineTrack = player.isPlayingOffline || (player.currentTrack.map { offlineManager.isDownloaded(trackId: $0.id) } ?? false)
                if isOfflineTrack {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "#10b981"))
                        Text("Offline · Lokal")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.92))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#10b981").opacity(0.18))
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: "#10b981").opacity(0.35), lineWidth: 0.6)
                            )
                    )
                } else {
                    Text(player.currentTrack?.isLive == true ? "Live Radio" : "High")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.14))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                )
                        )
                }

                Spacer()

                let remaining = max(0, player.duration - activeProgress)
                Text("-" + formatSeconds(remaining))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.60))
            }
        }
    }

    private func scrubberBar(width: CGFloat) -> some View {
        let maxDur = max(player.duration, 1.0)
        let pct = min(1.0, max(0.0, activeProgress / maxDur))

        return ZStack(alignment: .leading) {
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
        .frame(width: width, height: 24)
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

    // MARK: - Playback Controls (Exakt wie im Screenshot media_1794856506477_d5bf729e.jpg)
    public var playbackControlsSection: some View {
        HStack(spacing: 0) {
            // 1. Vorheriger Song (|◀◀ wie im Screenshot)
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.previous(serverURL: serverURL)
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())

            // 2. Play / Pause Haupt-Button (Exakt wie im Screenshot media_1794856506477_d5bf729e.jpg: Weisses Symbol)
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                player.togglePlayPause()
            }) {
                ZStack {
                    if player.isBuffering {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // 3. Nächster Song (▶▶| wie im Screenshot)
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                player.next(serverURL: serverURL)
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: - Untere Aktionsleiste (Lyrics, AirPlay, Shuffle, Repeat, Queue)
    public var bottomActionRow: some View {
        let isLyricsActive = (showLyrics || sidePanelMode == .lyrics)
        let isQueueActive = (sidePanelMode == .queue)

        return HStack(spacing: 0) {
            // 1. Lyrics Toggle (quote.bubble)
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if (UIDevice.current.userInterfaceIdiom == .pad) {
                        sidePanelMode = (sidePanelMode == .lyrics) ? .none : .lyrics
                    } else {
                        showLyrics.toggle()
                    }
                }
            }) {
                Image(systemName: isLyricsActive ? "quote.bubble.fill" : "quote.bubble")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isLyricsActive ? Color(hex: "#fc3c44") : Color.white.opacity(0.65))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())

            // 2. AirPlay Symbol
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }) {
                Image(systemName: "airplayaudio")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.65))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())

            // 3. Shuffle
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

            // 4. Repeat
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

            // 5. Queue Toggle (list.bullet)
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                if (UIDevice.current.userInterfaceIdiom == .pad) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        sidePanelMode = (sidePanelMode == .queue) ? .none : .queue
                    }
                } else {
                    showQueueSheet = true
                }
            }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isQueueActive ? Color(hex: "#fc3c44") : Color.white.opacity(0.65))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Lautstärke-Regler mit Lautsprecher-Icon
    public var volumeSliderSection: some View {
        HStack(spacing: 12) {
            Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.fill")
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

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.60))
                .frame(width: 22)
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
                                    .font(.system(size: 22 * lyricsSizeScale, weight: isCurrent ? .bold : .medium))
                                    .foregroundColor(isCurrent ? Color.white : Color.white.opacity(0.32))
                                    .lineSpacing(4)
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
                            .font(.system(size: 18, weight: isCurrent ? .bold : .medium))
                            .foregroundColor(isCurrent ? Color.white : Color.white.opacity(0.32))
                            .lineSpacing(4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                player.seek(to: line.time)
                            }
                            .animation(.easeInOut(duration: 0.25), value: isCurrent)
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
        if sessionManager.isOfflineMode {
            lyricsLines = []
            isLoadingLyrics = false
            return
        }
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
