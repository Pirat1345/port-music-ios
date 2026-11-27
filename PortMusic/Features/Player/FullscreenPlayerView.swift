import SwiftUI
import MediaPlayer
import AVKit

private struct PortAirPlayRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.backgroundColor = .clear
        picker.tintColor = UIColor.white.withAlphaComponent(0.72)
        picker.activeTintColor = UIColor.white
        picker.prioritizesVideoDevices = false
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

public struct FullscreenPlayerView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var volumeManager = SystemVolumeManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared
    public let serverURL: String
    public let onDragProgressChanged: ((CGFloat) -> Void)?
    public let onClose: () -> Void

    @AppStorage("playback_autoplay_enabled") private var autoplayEnabled: Bool = true
    @State private var isScrubbing: Bool = false
    @State private var isAdjustingVolume: Bool = false
    @State private var showQueueSheet: Bool = false
    @State private var isFavorite: Bool = false
    @State private var showLyrics: Bool = false
    @State private var showInlineQueue: Bool = false
    @State private var isQueueCompactHeaderCollapsed: Bool = false
    @State private var sidePanelMode: SidePanelMode = .none
    @State private var dismissTrigger: Int = 0
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

    public init(
        serverURL: String,
        onDragProgressChanged: ((CGFloat) -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.serverURL = serverURL
        self.onDragProgressChanged = onDragProgressChanged
        self.onClose = onClose
    }

    public var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let isTablet = (UIDevice.current.userInterfaceIdiom == .pad) && (geo.size.width >= 768)
            let fullWidth = geo.size.width
            let fullHeight = geo.size.height
            let resolvedBackgroundCoverURL: URL? = {
                guard player.nowPlayingArtwork == nil else { return nil }
                let offlineCover = player.currentTrack.flatMap { offlineManager.localCoverFileURL(for: $0.id) }
                return offlineCover ?? resolveCoverURL(player.currentTrack?.coverUrl, serverURL: serverURL)
            }()

            let playerContent = ZStack(alignment: .top) {
                FullscreenBackgroundLayer(
                    artwork: player.nowPlayingArtwork,
                    coverURL: resolvedBackgroundCoverURL,
                    width: fullWidth,
                    height: fullHeight
                )
                .equatable()

                VStack(spacing: 0) {
                    topBarSection(safeTop: safeTop, fullHeight: fullHeight)

                    if isTablet && sidePanelMode != .none {
                        tabletSplitLayout(geo: geo)
                    } else if !isTablet && showLyrics {
                        phoneLyricsLayout(geo: geo)
                    } else if !isTablet && showInlineQueue {
                        phoneQueueLayout(geo: geo, fullHeight: fullHeight)
                    } else {
                        centeredPlayerLayout(geo: geo, isTablet: isTablet)
                    }
                }
                .frame(width: fullWidth)
            }

            DraggablePlayerSheet(
                fullWidth: fullWidth,
                fullHeight: fullHeight,
                restrictDragToTopBar: (!isTablet && (showInlineQueue || (showLyrics && !lyricsLines.isEmpty))),
                safeTopArea: max(safeTop, deviceSafeTop),
                isSliderActive: isScrubbing || isAdjustingVolume,
                dismissTrigger: dismissTrigger,
                onDismiss: {
                    onDragProgressChanged?(1.0)
                    onClose()
                },
                content: playerContent
            )
            .sheet(isPresented: $showQueueSheet) {
                QueueSheetView(serverURL: serverURL, onClose: { showQueueSheet = false })
            }
            .task(id: player.currentTrack?.id) {
                try? await Task.sleep(nanoseconds: 160_000_000)
                if !Task.isCancelled {
                    await loadTrackExtras()
                }
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
                    dismissTrigger += 1
                }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Safe Area Hilfswert
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
        let contentWidth = min(geo.size.width - 56, 420)

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
                        .foregroundColor(.white)
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
                    .frame(width: contentWidth)
                playbackControlsSection
                    .frame(width: contentWidth)
                bottomActionRow
                    .frame(width: contentWidth)
            }
            .frame(width: contentWidth)
            .padding(.bottom, max(geo.safeAreaInsets.bottom, 20))
        }
        .frame(width: geo.size.width)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    // MARK: - PHONE INLINE APPLE MUSIC QUEUE MODUS (Wiedergabe fortsetzen)
    private func phoneQueueLayout(geo: GeometryProxy, fullHeight: CGFloat) -> some View {
        let contentWidth = min(geo.size.width - 56, 420)
        let upcomingStart = min(player.queueIndex + 1, player.queue.count)
        let upcoming = Array(player.queue[upcomingStart...])

        return VStack(spacing: 12) {
            if !isQueueCompactHeaderCollapsed {
                queueCompactTrackHeader
                    .frame(width: contentWidth)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            queueFourActionPills
                .frame(width: contentWidth)

            VStack(alignment: .leading, spacing: 2) {
                Text("Wiedergabe fortsetzen")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Text(upcoming.isEmpty ? "Keine weiteren Titel" : "Nächste \(upcoming.count) Titel")
                    .font(.system(size: 13.5))
                    .foregroundColor(Color.white.opacity(0.50))
            }
            .frame(width: contentWidth, alignment: .leading)
            .padding(.top, 4)

            if upcoming.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 34))
                        .foregroundColor(Color.white.opacity(0.30))
                    Text("Keine Titel in der Warteschlange")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.55))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Color.clear
                        .frame(height: 1)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .onDisappear {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isQueueCompactHeaderCollapsed = true
                            }
                        }
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isQueueCompactHeaderCollapsed = false
                            }
                        }

                    ForEach(Array(upcoming.enumerated()), id: \.offset) { offset, item in
                        upcomingQueueRow(item: item, realIndex: upcomingStart + offset)
                    }
                    .onMove { fromOffsets, toOffset in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        player.moveUpcomingQueueItem(fromOffsets: fromOffsets, toOffset: toOffset)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }

            VStack(spacing: 12) {
                scrubberContent(fixedWidth: contentWidth)
                    .frame(width: contentWidth)
                playbackControlsSection
                    .frame(width: contentWidth)
                volumeSliderSection
                    .frame(width: contentWidth)
                bottomActionRow
                    .frame(width: contentWidth)
            }
            .frame(width: contentWidth)
            .padding(.bottom, max(geo.safeAreaInsets.bottom, 18))
        }
        .frame(width: geo.size.width)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private func upcomingQueueRow(item: Track, realIndex: Int) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            player.play(track: item, from: player.queue, serverURL: serverURL)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 48, height: 48)
                    let localCover = offlineManager.localCoverFileURL(for: item.id)
                    let resolved = localCover ?? resolveCoverURL(item.coverUrl, serverURL: serverURL)
                    PortCachedAsyncImage(url: resolved) { img in
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: {
                        Image(systemName: "music.note")
                            .font(.system(size: 15))
                            .foregroundColor(Color.white.opacity(0.35))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 15.5, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(item.artist)
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 3, leading: 22, bottom: 3, trailing: 18))
        .contextMenu {
            Button(role: .destructive) {
                player.removeUpcomingQueueItem(at: realIndex)
            } label: {
                Label("Aus Warteschlange entfernen", systemImage: "trash")
            }
        }
    }

    private var queueCompactTrackHeader: some View {
        HStack(spacing: 12) {
            artworkSection(maxSize: 50)

            VStack(alignment: .leading, spacing: 2) {
                Text(player.currentTrack?.title ?? "Kein Titel")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(player.currentTrack?.artist ?? "Unbekannter Interpret")
                    .font(.system(size: 13.5))
                    .foregroundColor(.white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer()

            trackActionCircleButtons
        }
        .padding(.top, 2)
    }

    private var queueFourActionPills: some View {
        let isLive = (player.currentTrack?.isLive == true)
        return HStack(spacing: 10) {
            Button {
                guard !isLive else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                player.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(!isLive && player.isShuffle ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(!isLive && player.isShuffle ? Color.white.opacity(0.90) : Color.white.opacity(0.14))
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isLive)

            Button {
                guard !isLive else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                player.toggleRepeat()
            } label: {
                Image(systemName: !isLive && player.isRepeat ? "repeat.1" : "repeat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(!isLive && player.isRepeat ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(!isLive && player.isRepeat ? Color.white.opacity(0.90) : Color.white.opacity(0.14))
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isLive)

            Button {
                guard !isLive else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                autoplayEnabled.toggle()
            } label: {
                Image(systemName: "infinity")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(!isLive && autoplayEnabled ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(!isLive && autoplayEnabled ? Color.white.opacity(0.90) : Color.white.opacity(0.14))
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isLive)
        }
    }

    // MARK: - ZENTRIERTER VOLLBILD PLAYER (Big Picture Modus sowohl für Phone als auch für iPad)
    private func centeredPlayerLayout(geo: GeometryProxy, isTablet: Bool) -> some View {
        let contentWidth = min(geo.size.width - (isTablet ? 96 : 56), isTablet ? 500 : 420)
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
                    guard isLarge else { return }
                    if abs(val.translation.width) > abs(val.translation.height) * 1.4 {
                        var tx = Transaction()
                        tx.animation = nil
                        withTransaction(tx) {
                            artworkDragOffset = val.translation.width
                        }
                    }
                }
                .onEnded { val in
                    guard isLarge else { return }
                    if abs(val.translation.width) > abs(val.translation.height) * 1.4 {
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
                    if artworkDragOffset != 0 {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                            artworkDragOffset = 0
                        }
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

                Button(action: navigateToCurrentArtist) {
                    HStack(spacing: 4) {
                        Text(player.currentTrack?.artist ?? "Unbekannter Interpret")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.75))
                            .lineLimit(1)
                        if let cur = player.currentTrack, !cur.isLive, !cur.artist.isEmpty, cur.artist.lowercased() != "unbekannter interpret" {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.45))
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()

            // Runde Aktionsbuttons rechts: Favorit & Optionen (Apple Music Kreis-Stil)
            trackActionCircleButtons
        }
        .frame(maxWidth: .infinity)
    }

    private var trackActionCircleButtons: some View {
        HStack(spacing: 10) {
            if player.currentTrack?.isLive != true {
                Button(action: {
                    guard let track = player.currentTrack else { return }
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    isFavorite.toggle()
                    let targetState = isFavorite
                    FavoritesManager.shared.enqueueMutation(track: track, isFavorite: targetState)
                    Task {
                        let token = SessionManager.shared.currentToken
                        _ = await MusicService.shared.toggleFavorite(
                            track: track,
                            desiredState: targetState,
                            serverURL: serverURL,
                            token: token
                        )
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 34, height: 34)

                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isFavorite ? Color(hex: "#fc3c44") : Color.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

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

                if let cur = player.currentTrack, !cur.isLive, !cur.artist.isEmpty, cur.artist.lowercased() != "unbekannter interpret" {
                    Button(action: navigateToCurrentArtist) {
                        Label("Zum Künstler", systemImage: "person.fill")
                    }
                }

                Button(action: {
                    showQueueSheet = true
                }) {
                    Label("Komplette Warteschlange", systemImage: "list.bullet")
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 34, height: 34)

                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Scrubber mit negativer Restzeit (-M:SS)
    public var scrubberSection: some View {
        scrubberContent(fixedWidth: nil)
    }

    @ViewBuilder
    private func scrubberContent(fixedWidth: CGFloat?) -> some View {
        FullscreenScrubberView(
            isScrubbing: $isScrubbing,
            fixedWidth: fixedWidth,
            serverURL: serverURL
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

    // MARK: - Untere Aktionsleiste (Apple Music: Lyrics, AirPlay, Queue)
    public var bottomActionRow: some View {
        let isLive = (player.currentTrack?.isLive == true)
        let isLyricsActive = !isLive && (showLyrics || sidePanelMode == .lyrics)
        let isQueueActive = (showInlineQueue || sidePanelMode == .queue)

        return HStack(spacing: 0) {
            // 1. Lyrics Toggle (quote.bubble)
            Button(action: {
                guard !isLive else { return }
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                    if (UIDevice.current.userInterfaceIdiom == .pad) {
                        sidePanelMode = (sidePanelMode == .lyrics) ? .none : .lyrics
                    } else {
                        showInlineQueue = false
                        showLyrics.toggle()
                    }
                }
            }) {
                Image(systemName: isLyricsActive ? "quote.bubble.fill" : "quote.bubble")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(isLyricsActive ? .white : Color.white.opacity(isLive ? 0.25 : 0.68))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(isLyricsActive ? 0.22 : 0.0))
                    )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isLive)

            // 2. Native AirPlay Audio-Picker
            PortAirPlayRouteButton()
                .frame(width: 40, height: 40)
                .frame(maxWidth: .infinity)

            // 3. Queue Toggle (list.bullet - Apple Music Inline Queue)
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                    if (UIDevice.current.userInterfaceIdiom == .pad) {
                        sidePanelMode = (sidePanelMode == .queue) ? .none : .queue
                    } else {
                        showLyrics = false
                        isQueueCompactHeaderCollapsed = false
                        showInlineQueue.toggle()
                    }
                }
            }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(isQueueActive ? .white : Color.white.opacity(0.68))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(isQueueActive ? 0.22 : 0.0))
                    )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    // MARK: - Lautstärke-Regler mit Lautsprecher-Icon (Apple Music Stil ohne Knopf)
    public var volumeSliderSection: some View {
        HStack(spacing: 12) {
            Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.fill")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.55))
                .frame(width: 20)

            GeometryReader { vGeo in
                let vWidth = vGeo.size.width
                let vPct = CGFloat(max(0.0, min(1.0, volume)))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(height: 5)

                    Capsule()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: max(0, vWidth * vPct), height: 5)
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            isAdjustingVolume = true
                            let pct = Float(max(0.0, min(1.0, val.location.x / vWidth)))
                            volume = pct
                            volumeManager.setVolume(pct)
                            player.setVolume(pct)
                        }
                        .onEnded { _ in
                            isAdjustingVolume = false
                        }
                )
            }
            .frame(height: 20)

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.55))
                .frame(width: 20)
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
                    Text("Keine Lyrics für diesen Song gefunden")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                FullscreenSyncedLyricsScrollView(
                    lyricsLines: lyricsLines,
                    lyricsSizeScale: lyricsSizeScale,
                    onSeek: { player.seek(to: $0) }
                )
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
                                            .foregroundColor(Color.white)
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
                                            .foregroundColor(Color.white)
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
                Text("Keine Lyrics für diesen Song gefunden")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.50))
                    .padding(.vertical, 16)
            } else {
                FullscreenSyncedLyricsCompactList(
                    lyricsLines: lyricsLines,
                    onSeek: { player.seek(to: $0) }
                )
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func loadTrackExtras() async {
        guard let track = player.currentTrack else { return }

        // Favoriten-Status (inkl. Offline-Vormerkung) sofort synchronisieren
        let localFav = FavoritesManager.shared.isFavorite(trackId: track.id)
        await MainActor.run {
            self.isFavorite = localFav
        }

        // Lokal gespeicherte Offline-Lyrics sofort ohne Netzwerk laden
        let cachedLocalLrc = OfflineDownloadManager.shared.localLyrics(for: track.id)
        if let localRaw = cachedLocalLrc {
            await MainActor.run {
                self.lyricsLines = parseLRC(localRaw)
                self.isLoadingLyrics = false
            }
        }

        let token = SessionManager.shared.currentToken
        if sessionManager.isOfflineMode {
            if cachedLocalLrc == nil {
                await MainActor.run {
                    self.lyricsLines = []
                    self.isLoadingLyrics = false
                }
            }
            return
        }

        let serverFav = await MusicService.shared.checkIsFavorite(trackId: track.id, serverURL: serverURL, token: token)
        await MainActor.run {
            self.isFavorite = serverFav
        }

        if cachedLocalLrc == nil {
            await MainActor.run {
                self.isLoadingLyrics = true
            }
        }
        if let rawLrc = await MusicService.shared.fetchLyrics(
            trackId: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album,
            durationSeconds: track.durationSeconds > 0 ? track.durationSeconds : nil,
            serverURL: serverURL,
            token: token
        ) {
            let parsed = parseLRC(rawLrc)
            if !parsed.isEmpty && OfflineDownloadManager.shared.isDownloaded(trackId: track.id) {
                OfflineDownloadManager.shared.saveLyrics(rawLrc, for: track.id)
            }
            await MainActor.run {
                self.lyricsLines = parsed
            }
        } else if cachedLocalLrc == nil {
            await MainActor.run {
                self.lyricsLines = []
            }
        }
        await MainActor.run {
            self.isLoadingLyrics = false
        }
    }

    private func navigateToCurrentArtist() {
        guard let cur = player.currentTrack, !cur.isLive else { return }
        let name = cur.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.lowercased() != "unbekannter interpret" else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onClose()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(
                name: .portMusicNavigateToArtist,
                object: nil,
                userInfo: ["name": name]
            )
        }
    }
}

private func formatPlayerSeconds(_ seconds: Double) -> String {
    let sec = Int(max(0, seconds))
    let m = sec / 60
    let s = sec % 60
    return String(format: "%d:%02d", m, s)
}

private func activeLyricLineId(in lines: [LyricLine], at time: Double) -> String? {
    guard !lines.isEmpty, let first = lines.first, time >= first.time - 0.4 else {
        return nil
    }
    return lines.last(where: { $0.time <= time + 0.15 })?.id
}

// MARK: - Weichgezeichneter Album-Hintergrund (Equatable isoliert: 0 Redraws während Drag)
private struct FullscreenBackgroundLayer: View, Equatable {
    let artwork: UIImage?
    let coverURL: URL?
    let width: CGFloat
    let height: CGFloat

    static func == (lhs: FullscreenBackgroundLayer, rhs: FullscreenBackgroundLayer) -> Bool {
        lhs.artwork === rhs.artwork &&
        lhs.coverURL == rhs.coverURL &&
        lhs.width == rhs.width &&
        lhs.height == rhs.height
    }

    var body: some View {
        let lowW = max(1, width * 0.25)
        let lowH = max(1, height * 0.25)

        ZStack {
            Color(hex: "#121215")
                .frame(width: width, height: height)

            Group {
                if let artwork = artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: lowW, height: lowH)
                        .blur(radius: 16)
                        .opacity(0.56)
                        .scaleEffect(4.6)
                } else {
                    PortCachedAsyncImage(url: coverURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: lowW, height: lowH)
                            .blur(radius: 16)
                            .opacity(0.56)
                            .scaleEffect(4.6)
                    } placeholder: {
                        Color.clear
                    }
                }
            }
            .frame(width: width, height: height)
            .clipped()

            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.28), location: 0.0),
                    .init(color: Color.black.opacity(0.42), location: 0.48),
                    .init(color: Color.black.opacity(0.76), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .drawingGroup(opaque: true)
        .clipped()
    }
}

// MARK: - GPU-isolierter Drag-to-Dismiss Container (O(1) Transform ohne Content- oder TabView-Redraw)
private struct DraggablePlayerSheet<Content: View>: View {
    let fullWidth: CGFloat
    let fullHeight: CGFloat
    let restrictDragToTopBar: Bool
    let safeTopArea: CGFloat
    let isSliderActive: Bool
    let dismissTrigger: Int
    let onDismiss: () -> Void
    let content: Content

    private enum AxisLock {
        case undecided
        case vertical
        case ignored
    }

    @State private var dragOffset: CGFloat = 0.0
    @State private var isDismissing: Bool = false
    @State private var axisLock: AxisLock = .undecided
    @State private var anchorOffsetY: CGFloat = 0.0

    private func performDismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.26, dampingFraction: 0.90)) {
            dragOffset = fullHeight + 48
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onDismiss()
        }
    }

    var body: some View {
        let isActivelyPulled = dragOffset > 0.5
        let backdropProgress = min(1.0, max(0.0, dragOffset / max(1.0, fullHeight * 0.65)))
        let backdropOpacity = isActivelyPulled ? (0.48 * Double(1.0 - backdropProgress)) : 0.0

        ZStack(alignment: .top) {
            Color.black
                .opacity(backdropOpacity)
                .frame(width: fullWidth, height: fullHeight)
                .allowsHitTesting(false)

            content
                .frame(width: fullWidth, height: fullHeight)
                .clipShape(RoundedRectangle(cornerRadius: isActivelyPulled ? 40.0 : 0.0, style: .continuous))
                .offset(y: max(0.0, dragOffset))
        }
        .frame(width: fullWidth, height: fullHeight)
        .simultaneousGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .onChanged { val in
                    guard !isDismissing else { return }
                    if isSliderActive {
                        axisLock = .ignored
                        return
                    }

                    let dx = val.translation.width
                    let dy = val.translation.height

                    if axisLock == .undecided {
                        if restrictDragToTopBar && val.startLocation.y > (safeTopArea + 130) {
                            axisLock = .ignored
                            return
                        }
                        let dist = hypot(dx, dy)
                        guard dist >= 10 else { return }
                        if dy > 0 && abs(dy) > abs(dx) * 1.15 {
                            axisLock = .vertical
                            anchorOffsetY = dy
                        } else {
                            axisLock = .ignored
                            return
                        }
                    }

                    guard axisLock == .vertical else { return }
                    let adjusted = max(0.0, dy - anchorOffsetY)
                    var transaction = Transaction()
                    transaction.animation = nil
                    withTransaction(transaction) {
                        dragOffset = adjusted
                    }
                }
                .onEnded { val in
                    defer {
                        axisLock = .undecided
                        anchorOffsetY = 0.0
                    }
                    guard !isDismissing, axisLock == .vertical else { return }
                    let dy = max(0.0, val.translation.height - anchorOffsetY)
                    let velocityY = val.predictedEndTranslation.height - val.translation.height
                    if dy > 110 || (dy > 48 && velocityY > 140) {
                        performDismiss()
                    } else {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                            dragOffset = 0.0
                        }
                    }
                }
        )
        .onChange(of: dismissTrigger) { _ in
            performDismiss()
        }
        .onAppear {
            dragOffset = 0.0
            isDismissing = false
            axisLock = .undecided
            anchorOffsetY = 0.0
        }
    }
}

// MARK: - Isolierter Scrubber (Progress-Ticks triggern nur diese kleine Teilansicht)
private struct FullscreenScrubberView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var progress = AudioPlayerProgress.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared

    @Binding var isScrubbing: Bool
    @State private var scrubPosition: Double = 0.0
    let fixedWidth: CGFloat?
    let serverURL: String

    private var activeProgress: Double {
        isScrubbing ? scrubPosition : progress.currentTime
    }

    var body: some View {
        if player.currentTrack?.isLive == true {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color.white.opacity(0.22))
                        .frame(height: 1.5)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: "#ff3b30"))
                            .frame(width: 7, height: 7)
                            .shadow(color: Color(hex: "#ff3b30").opacity(0.75), radius: 4)

                        Text("LIVE")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .tracking(1.6)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
                            )
                    )

                    Rectangle()
                        .fill(Color.white.opacity(0.22))
                        .frame(height: 1.5)
                }

                let subtitle = player.currentTrack?.album?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                Text(subtitle.isEmpty || subtitle == "Radio" ? "Live-Übertragung" : subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.62))
                    .lineLimit(1)
            }
            .frame(width: fixedWidth)
            .padding(.vertical, 2)
        } else {
            VStack(spacing: 8) {
                if let w = fixedWidth {
                    scrubberBar(width: w)
                } else {
                    GeometryReader { geo in
                        scrubberBar(width: geo.size.width)
                    }
                    .frame(height: 24)
                }

                ZStack(alignment: .center) {
                    HStack {
                        Text(formatPlayerSeconds(activeProgress))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.60))

                        Spacer()

                        let remaining = max(0, player.duration - activeProgress)
                        Text("-" + formatPlayerSeconds(remaining))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.60))
                    }

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
                        let storedQuality = UserDefaults.standard.string(forKey: "portmusic_audio_quality")
                        let qualityTitle = (storedQuality == "low" || storedQuality == "normal") ? "Low" : "High"
                        Text(qualityTitle)
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
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: fixedWidth)
        }
    }

    private func scrubberBar(width: CGFloat) -> some View {
        let maxDur = max(player.duration, 1.0)
        let pct = min(1.0, max(0.0, activeProgress / maxDur))
        let barHeight: CGFloat = isScrubbing ? 9 : 6

        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(height: barHeight)

            Capsule()
                .fill(Color.white.opacity(0.92))
                .frame(width: max(0, width * CGFloat(pct)), height: barHeight)
        }
        .animation(.easeOut(duration: 0.14), value: isScrubbing)
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
}

private struct FullscreenSyncedLyricsScrollView: View {
    @ObservedObject private var progress = AudioPlayerProgress.shared
    let lyricsLines: [LyricLine]
    let lyricsSizeScale: CGFloat
    let onSeek: (Double) -> Void

    var body: some View {
        let currentId = activeLyricLineId(in: lyricsLines, at: progress.currentTime)
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(lyricsLines) { line in
                        let isCurrent = currentId == line.id
                        Text(line.text)
                            .font(.system(size: 22 * lyricsSizeScale, weight: isCurrent ? .bold : .medium))
                            .foregroundColor(isCurrent ? Color.white : Color.white.opacity(0.32))
                            .lineSpacing(4)
                            .id(line.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSeek(line.time)
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
            .onChange(of: currentId) { newId in
                if let id = newId {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }
}

private struct FullscreenSyncedLyricsCompactList: View {
    @ObservedObject private var progress = AudioPlayerProgress.shared
    let lyricsLines: [LyricLine]
    let onSeek: (Double) -> Void

    var body: some View {
        let currentId = activeLyricLineId(in: lyricsLines, at: progress.currentTime)
        VStack(alignment: .leading, spacing: 14) {
            ForEach(lyricsLines) { line in
                let isCurrent = currentId == line.id
                Text(line.text)
                    .font(.system(size: 18, weight: isCurrent ? .bold : .medium))
                    .foregroundColor(isCurrent ? Color.white : Color.white.opacity(0.32))
                    .lineSpacing(4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSeek(line.time)
                    }
                    .animation(.easeInOut(duration: 0.25), value: isCurrent)
            }
        }
    }
}

// MARK: - Queue Sheet
public struct QueueSheetView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared
    public let serverURL: String
    public let onClose: () -> Void

    private var hasNonDownloadedQueueItems: Bool {
        player.queue.contains { !offlineManager.isDownloaded(trackId: $0.id) }
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Warteschlange")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(PortColors.textPrimary)
                        if sessionManager.isOfflineMode {
                            Text("Offline: nicht geladene Songs werden übersprungen")
                                .font(.system(size: 11.5))
                                .foregroundColor(PortColors.accentOrange)
                        }
                    }

                    Spacer()

                    if sessionManager.isOfflineMode && hasNonDownloadedQueueItems {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            player.pruneQueueToDownloadedOnly()
                        }) {
                            Text("Bereinigen")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }

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
        let isDownloaded = offlineManager.isDownloaded(trackId: item.id)
        let isUnavailableOffline = sessionManager.isOfflineMode && !isDownloaded && !isCurrent

        Button(action: {
            guard !isUnavailableOffline else { return }
            player.play(track: item, from: player.queue)
        }) {
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(isCurrent ? Color.white : Color.white.opacity(0.40))
                    .frame(width: 24)

                queueCoverImage(track: item)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 14, weight: isCurrent ? .bold : .medium))
                        .foregroundColor(isCurrent ? Color.white : PortColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if isDownloaded {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#00d26a"))
                        } else if sessionManager.isOfflineMode {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 11))
                                .foregroundColor(PortColors.accentOrange.opacity(0.85))
                        }
                        Text(item.artist)
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isCurrent {
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.white)
                }
            }
            .padding(.vertical, 4)
            .opacity(isUnavailableOffline ? 0.38 : 1.0)
        }
        .disabled(isUnavailableOffline)
        .listRowBackground(Color.white.opacity(isCurrent ? 0.12 : 0.04))
    }

    @ViewBuilder
    private func queueCoverImage(track: Track) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.08))
                .frame(width: 38, height: 38)

            let localCover = offlineManager.localCoverFileURL(for: track.id)
            let resolved = localCover ?? resolveCoverURL(track.coverUrl, serverURL: serverURL)
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
