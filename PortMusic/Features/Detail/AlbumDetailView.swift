import SwiftUI

public struct AlbumDetailView: View {
    public let albumId: String
    public let initialTitle: String?
    public let initialArtist: String?
    public let initialCover: String?
    public let serverURL: String

    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @State private var albumData: DiscoveryAlbumDetailData? = nil
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var isFavorite: Bool = false

    private let savedAlbumsKey = "port_music_saved_albums"

    public init(
        albumId: String,
        initialTitle: String? = nil,
        initialArtist: String? = nil,
        initialCover: String? = nil,
        serverURL: String
    ) {
        self.albumId = albumId
        self.initialTitle = initialTitle
        self.initialArtist = initialArtist
        self.initialCover = initialCover
        self.serverURL = serverURL
    }

    private var displayTitle: String {
        albumData?.title ?? initialTitle ?? "Album"
    }

    private var displayArtist: String {
        albumData?.artist ?? initialArtist ?? "Unbekannt"
    }

    private var displayCover: String? {
        albumData?.cover ?? initialCover
    }

    private var durationSummary: String {
        if let ds = albumData?.durationSeconds, ds > 0 {
            let totalMins = Int(ds) / 60
            let hours = totalMins / 60
            let mins = totalMins % 60
            if hours > 0 {
                return "\(hours) Std. \(mins) Min."
            }
            return "\(mins) Min."
        } else if let dStr = albumData?.duration, !dStr.isEmpty {
            return dStr
        }
        return ""
    }

    private var metadataLine: String {
        var parts: [String] = []
        if let year = albumData?.year {
            parts.append("\(year)")
        }
        let count = albumData?.trackCount ?? albumData?.tracks.count ?? 0
        if count > 0 {
            parts.append("\(count) Titel")
        }
        if !durationSummary.isEmpty {
            parts.append(durationSummary)
        }
        return parts.joined(separator: " • ")
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // ── HEADER HERO COVER & METADATA ──
                    albumHeaderHero
                        .padding(.top, 16)

                    // ── ACTION BUTTONS ──
                    actionButtonsRow
                        .padding(.horizontal, 20)

                    // ── TRACKLIST OR LOADING ──
                    if isLoading && albumData == nil {
                        loadingSkeletonView
                            .padding(.top, 16)
                    } else if let error = errorMessage, albumData == nil {
                        errorStateView(error)
                            .padding(.top, 32)
                    } else if let data = albumData {
                        tracklistSection(tracks: data.tracks)
                    }

                    // Puffer fuer Minibar & TabBar
                    Spacer(minLength: 120)
                }
            }
            .refreshable {
                await loadAlbumData()
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .task {
            loadFavoriteStatus()
            await loadAlbumData()
        }
    }

    // MARK: - Album Header Hero
    private var albumHeaderHero: some View {
        VStack(spacing: 16) {
            // Grosses Cover Artwork
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#18181b"))
                    .frame(width: 190, height: 190)

                if let cover = displayCover, let resolved = resolveCoverURL(cover, serverURL: serverURL) {
                    PortCachedAsyncImage(url: resolved) { img in
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 190, height: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } placeholder: {
                        Image(systemName: "opticaldisc")
                            .font(.system(size: 48))
                            .foregroundColor(Color.white.opacity(0.30))
                    }
                } else {
                    Image(systemName: "opticaldisc")
                        .font(.system(size: 48))
                        .foregroundColor(Color.white.opacity(0.30))
                }
            }
            .frame(width: 190, height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 16, y: 6)

            // Titel & Kuenstler
            VStack(spacing: 6) {
                Text(displayTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)

                // Klickbarer Link zum Kuenstler
                NavigationLink(value: AppRoute.artist(name: displayArtist, coverUrl: nil)) {
                    Text(displayArtist)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "#fc3c44"))
                }
                .buttonStyle(PlainButtonStyle())

                if !metadataLine.isEmpty {
                    Text(metadataLine)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.55))
                        .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - Action Buttons
    private var actionButtonsRow: some View {
        HStack(spacing: 14) {
            // Play
            Button(action: {
                playAllTracks(shuffle: false)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Wiedergabe")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.3), radius: 6, y: 2)
            }

            // Shuffle
            Button(action: {
                playAllTracks(shuffle: true)
            }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }

            // Favorite Toggle
            Button(action: toggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isFavorite ? Color(hex: "#fc3c44") : .white)
                    .padding(12)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }

            // Download Toggle
            Button(action: toggleAlbumDownload) {
                Image(systemName: isAlbumDownloaded ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isAlbumDownloaded ? Color(hex: "#00d26a") : .white)
                    .padding(12)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
        }
    }

    private var isAlbumDownloaded: Bool {
        guard let data = albumData, !data.tracks.isEmpty else { return false }
        return data.tracks.allSatisfy { offlineManager.isDownloaded(trackId: $0.id) }
    }

    private func toggleAlbumDownload() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        guard let data = albumData else { return }
        let allTracks = data.tracks.map { $0.toTrack(fallbackCover: displayCover, fallbackAlbum: displayTitle) }
        let token = SessionManager.shared.currentToken

        if isAlbumDownloaded {
            for t in allTracks {
                offlineManager.removeDownload(trackId: t.id)
            }
        } else {
            offlineManager.downloadPlaylist(
                playlistId: albumId,
                name: displayTitle,
                tracks: allTracks,
                serverURL: serverURL,
                token: token
            )
        }
    }

    // MARK: - Complete Tracklist
    private func tracklistSection(tracks: [DiscoveryArtistTrackItem]) -> some View {
        VStack(spacing: 2) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, item in
                let track = item.toTrack(fallbackCover: displayCover, fallbackAlbum: displayTitle)
                let isPlayingThis = player.isPlaying && player.currentTrack?.id == track.id
                let trackNum = item.trackNumber ?? (index + 1)
                let isDownloaded = offlineManager.isDownloaded(trackId: item.id)

                Button(action: {
                    playTrackFromAlbum(track: track, allItems: tracks)
                }) {
                    HStack(spacing: 14) {
                        // Track Number
                        Text("\(trackNum)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(isPlayingThis ? Color(hex: "#fc3c44") : Color.white.opacity(0.40))
                            .frame(width: 26, alignment: .center)

                        // Title & Artist
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(isPlayingThis ? Color(hex: "#fc3c44") : .white)
                                    .lineLimit(1)

                                if isDownloaded {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#00d26a"))
                                }

                                if item.isExplicit == true {
                                    Text("E")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.white.opacity(0.85))
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                            }

                            if !item.artist.isEmpty && item.artist.lowercased() != displayArtist.lowercased() {
                                Text(item.artist)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.white.opacity(0.55))
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        // Playing Icon or Duration
                        if isPlayingThis {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "#fc3c44"))
                        } else {
                            Text(item.duration ?? "0:00")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.45))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(isPlayingThis ? Color.white.opacity(0.08) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    if isDownloaded {
                        Button(role: .destructive) {
                            offlineManager.removeDownload(trackId: track.id)
                        } label: {
                            Label("Download entfernen", systemImage: "trash")
                        }
                    } else {
                        Button {
                            Task {
                                await offlineManager.downloadTrack(
                                    track: track,
                                    serverURL: serverURL,
                                    token: SessionManager.shared.currentToken
                                )
                            }
                        } label: {
                            Label("Offline speichern", systemImage: "arrow.down.circle")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Loading Skeleton
    private var loadingSkeletonView: some View {
        VStack(spacing: 12) {
            ForEach(0..<8, id: \.self) { _ in
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 20, height: 16)

                    VStack(alignment: .leading, spacing: 5) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 180, height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 100, height: 12)
                    }

                    Spacer()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 36, height: 14)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Error State
    private func errorStateView(_ error: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34))
                .foregroundColor(Color(hex: "#fc3c44"))

            Text("Album konnte nicht geladen werden")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Text(error)
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.60))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button(action: {
                Task { await loadAlbumData() }
            }) {
                Text("Erneut versuchen")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Playback & Data Operations
    private func playAllTracks(shuffle: Bool) {
        guard let data = albumData, !data.tracks.isEmpty else { return }
        var mapped = data.tracks.map { $0.toTrack(fallbackCover: displayCover, fallbackAlbum: displayTitle) }
        if shuffle {
            mapped.shuffle()
        }
        if let first = mapped.first {
            player.play(track: first, from: mapped, serverURL: serverURL)
        }
    }

    private func playTrackFromAlbum(track: Track, allItems: [DiscoveryArtistTrackItem]) {
        let fullQueue = allItems.map { $0.toTrack(fallbackCover: displayCover, fallbackAlbum: displayTitle) }
        player.play(track: track, from: fullQueue, serverURL: serverURL)
    }

    private func loadFavoriteStatus() {
        if let saved = UserDefaults.standard.stringArray(forKey: savedAlbumsKey) {
            isFavorite = saved.contains(where: { $0.lowercased() == albumId.lowercased() })
        }
    }

    private func toggleFavorite() {
        var current = UserDefaults.standard.stringArray(forKey: savedAlbumsKey) ?? []
        if isFavorite {
            current.removeAll { $0.lowercased() == albumId.lowercased() }
            isFavorite = false
        } else {
            current.append(albumId)
            isFavorite = true
        }
        UserDefaults.standard.set(current, forKey: savedAlbumsKey)
    }

    private func loadAlbumData() async {
        isLoading = true
        errorMessage = nil

        let token = SessionManager.shared.currentToken
        if let data = await MusicService.shared.fetchAlbum(id: albumId, serverURL: serverURL, token: token) {
            self.albumData = data
            self.isLoading = false
        } else {
            self.errorMessage = "Keine Verbindung zum Discovery-Dienst für dieses Album."
            self.isLoading = false
        }
    }
}
