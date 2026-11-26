import SwiftUI

// MARK: - Playlist Detail View (Feature #15)
public struct PlaylistDetailView: View {
    public let playlistId: String
    public let initialTitle: String?
    public let initialCover: String?
    public let serverURL: String

    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared
    @State private var playlistData: DiscoveryPlaylistDetailData? = nil
    @State private var tracks: [Track] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var searchQuery: String = ""
    @State private var showShareSheet: Bool = false

    public init(
        playlistId: String,
        initialTitle: String? = nil,
        initialCover: String? = nil,
        serverURL: String
    ) {
        self.playlistId = playlistId
        self.initialTitle = initialTitle
        self.initialCover = initialCover
        self.serverURL = serverURL
    }

    private var isPlaylistSyncMarked: Bool {
        offlineManager.markedOfflinePlaylistIds.contains(playlistId)
            || offlineManager.isPlaylistMarkedForOffline(playlistId)
    }

    private var isPlaylistDownloading: Bool {
        offlineManager.isPlaylistDownloading(playlistId, tracks: tracks)
    }

    private var downloadedTrackCount: Int {
        offlineManager.downloadedCount(forPlaylistTracks: tracks)
    }

    private var isAllTracksDownloaded: Bool {
        offlineManager.areAllTracksDownloaded(tracks)
    }

    private var hasMissingOfflineTracks: Bool {
        isPlaylistSyncMarked && !tracks.isEmpty && downloadedTrackCount < tracks.count
    }

    private var displayTitle: String {
        playlistData?.title ?? initialTitle ?? "Playlist"
    }

    private var displayCover: String? {
        playlistData?.cover ?? initialCover
    }

    private var displayDescription: String? {
        playlistData?.description
    }

    private var displayCreator: String {
        playlistData?.user ?? "Port Music"
    }

    private var isPlayingThisPlaylist: Bool {
        guard let current = player.currentTrack else { return false }
        return player.isPlaying && tracks.contains(where: { $0.id == current.id })
    }

    private var durationSummary: String {
        let totalSecs = tracks.reduce(0.0) { acc, t in
            if t.durationSeconds > 0 { return acc + t.durationSeconds }
            let parts = t.duration.split(separator: ":").compactMap { Double($0) }
            if parts.count == 2 { return acc + parts[0] * 60 + parts[1] }
            return acc + 180
        }
        let totalMins = Int(totalSecs) / 60
        let hours = totalMins / 60
        let mins = totalMins % 60
        if hours > 0 {
            return "\(hours) Std. \(mins) Min."
        } else {
            return "\(mins) Min."
        }
    }

    private var filteredTracks: [Track] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return tracks }
        return tracks.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q) ||
            ($0.album?.lowercased().contains(q) ?? false)
        }
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // Dynamic Ambient Backdrop Gradient
            VStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#1e1e24").opacity(0.85),
                        Color(hex: "#121216").opacity(0.40),
                        Color.clear
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 380)
                .ignoresSafeArea(edges: .top)

                Spacer()
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    // ── HERO COVER & METADATA ──
                    playlistHeaderHero
                        .padding(.top, 14)

                    // ── ACTION BUTTONS ROW ──
                    actionButtonsRow
                        .padding(.horizontal, 20)

                    if isPlaylistDownloading || hasMissingOfflineTracks {
                        offlineSyncStatusBanner
                            .padding(.horizontal, 20)
                    }

                    // ── INLINE SEARCH (wenn Tracks vorhanden) ──
                    if tracks.count > 5 {
                        searchBarSection
                            .padding(.horizontal, 20)
                    }

                    // ── TRACKLIST SECTION ──
                    tracklistSection

                    // Spacer fuer Minibar
                    Spacer(minLength: 120)
                }
            }
            .refreshable {
                await loadPlaylistData()
            }
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .tint(.white)
        .task {
            await loadPlaylistData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .portMusicDidReconnect)) { _ in
            Task {
                await loadPlaylistData()
            }
        }
        .onChange(of: player.currentTrack?.id) { newId in
            guard let id = newId, player.isPlaying, tracks.contains(where: { $0.id == id }) else { return }
            PlaylistActivityStore.shared.markPlayed(playlistId: playlistId)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [
                "Höre Playlist '\(displayTitle)' auf Port Music",
                serverURL
            ])
        }
    }

    // MARK: - Playlist Header Hero
    private var derivedTrackCovers: [String] {
        var seen = Set<String>()
        var covers: [String] = []
        for t in tracks {
            guard let raw = t.coverUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty,
                  !raw.contains("cover-1."),
                  raw != "/default-cover.svg" else { continue }
            if seen.insert(raw).inserted {
                covers.append(raw)
                if covers.count >= 4 { break }
            }
        }
        return covers
    }

    private var playlistHeaderHero: some View {
        VStack(spacing: 16) {
            // Zentriertes Cover Artwork (Custom, 2x2 Collage, Single Track oder zentriertes Icon)
            PlaylistArtworkView(
                coverUrl: displayCover,
                trackCovers: derivedTrackCovers,
                cornerRadius: 16,
                iconSize: 52,
                serverURL: serverURL
            )
            .frame(width: 190, height: 190)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.60), radius: 18, y: 6)

            // Titel & Metadaten
            VStack(spacing: 6) {
                Text(displayTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 20)

                if let desc = displayDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 30)
                }

                HStack(spacing: 6) {
                    Text(displayCreator)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.85))

                    Text("•")
                        .foregroundColor(Color.white.opacity(0.40))

                    Text("\(tracks.count) Songs")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.60))

                    if !tracks.isEmpty {
                        Text("•")
                            .foregroundColor(Color.white.opacity(0.40))
                        Text(durationSummary)
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.50))
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Action Buttons Row
    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            // Play All Button
            Button(action: {
                guard !tracks.isEmpty else { return }
                if isPlayingThisPlaylist {
                    player.togglePlayPause()
                } else {
                    PlaylistActivityStore.shared.markPlayed(playlistId: playlistId)
                    player.playAll(tracks: tracks, shuffle: false, serverURL: serverURL)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isPlayingThisPlaylist ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(isPlayingThisPlaylist ? "Pause" : "Wiedergabe")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.3), radius: 6, y: 2)
            }
            .buttonStyle(PlainButtonStyle())

            // Shuffle Button
            Button(action: {
                guard !tracks.isEmpty else { return }
                PlaylistActivityStore.shared.markPlayed(playlistId: playlistId)
                player.playAll(tracks: tracks, shuffle: true, serverURL: serverURL)
            }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())

            // Download Toggle Button (echter Download-Status: laufend / alle geladen / unvollstaendig / aus)
            Button(action: toggleDownload) {
                Group {
                    if isPlaylistDownloading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.85)
                    } else if isAllTracksDownloaded {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#10b981"))
                    } else if hasMissingOfflineTracks {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#f59e0b"))
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 20, height: 20)
                .padding(11)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Share Button
            Button(action: {
                showShareSheet = true
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())

            // More Options Menu
            Menu {
                Button(action: {
                    player.playAll(tracks: tracks, shuffle: false, serverURL: serverURL)
                }) {
                    Label("Playlist abspielen", systemImage: "play")
                }

                Button(action: {
                    for t in tracks {
                        player.addToQueue(track: t)
                    }
                }) {
                    Label("Alle zur Warteschlange hinzufügen", systemImage: "text.append")
                }

                if isPlaylistDownloading {
                    Button(action: {
                        offlineManager.cancelPlaylistDownload(playlistId)
                    }) {
                        Label("Download abbrechen", systemImage: "xmark.circle")
                    }
                } else if hasMissingOfflineTracks && !sessionManager.isOfflineMode {
                    Button(action: {
                        offlineManager.downloadPlaylist(
                            playlistId: playlistId,
                            name: displayTitle,
                            coverUrl: displayCover,
                            tracks: tracks,
                            serverURL: serverURL,
                            token: SessionManager.shared.currentToken
                        )
                    }) {
                        Label("Fehlende Songs laden (\(tracks.count - downloadedTrackCount))", systemImage: "arrow.down.circle")
                    }
                }

                if isAllTracksDownloaded || isPlaylistSyncMarked || downloadedTrackCount > 0 {
                    Button(role: .destructive, action: {
                        offlineManager.removePlaylistDownload(playlistId: playlistId)
                    }) {
                        Label("Offline-Download entfernen", systemImage: "trash")
                    }
                } else {
                    Button(action: toggleDownload) {
                        Label("Playlist herunterladen", systemImage: "arrow.down.circle")
                    }
                }

                Divider()

                Button(action: {
                    showShareSheet = true
                }) {
                    Label("Playlist teilen", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var offlineSyncStatusBanner: some View {
        HStack(spacing: 10) {
            if isPlaylistDownloading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
                Text("Lädt herunter · \(downloadedTrackCount) von \(tracks.count) Songs gespeichert")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.85))
                Spacer()
            } else if hasMissingOfflineTracks {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#f59e0b"))
                Text("\(downloadedTrackCount) von \(tracks.count) Songs offline geladen")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.85))
                Spacer()
                if !sessionManager.isOfflineMode {
                    Button("Nachladen") {
                        offlineManager.downloadPlaylist(
                            playlistId: playlistId,
                            name: displayTitle,
                            coverUrl: displayCover,
                            tracks: tracks,
                            serverURL: serverURL,
                            token: SessionManager.shared.currentToken
                        )
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Search Bar Section
    private var searchBarSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.40))

            TextField("In Playlist suchen...", text: $searchQuery)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .autocorrectionDisabled()

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.40))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Tracklist Section
    private var tracklistSection: some View {
        VStack(spacing: 4) {
            if isLoading && tracks.isEmpty {
                loadingSkeletonView
            } else if let error = errorMessage, tracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.65))
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.70))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if tracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 36))
                        .foregroundColor(Color.white.opacity(0.30))
                    Text("Diese Playlist enthält noch keine Titel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.60))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                let currentList = filteredTracks
                LazyVStack(spacing: 4) {
                    ForEach(Array(currentList.enumerated()), id: \.element.id) { index, track in
                        TrackRowView(
                            track: track,
                            index: index,
                            contextQueue: currentList,
                            serverURL: serverURL,
                            isLiked: false,
                            isDownloaded: offlineManager.isDownloaded(trackId: track.id),
                            showCover: true,
                            showTrackNumber: false
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Loading Skeleton
    private var loadingSkeletonView: some View {
        VStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 140, height: 12)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 90, height: 10)
                    }

                    Spacer()

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 32, height: 10)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Data Loading
    private func loadPlaylistData() async {
        errorMessage = nil
        let token = SessionManager.shared.currentToken

        // 0. Sofort offline geladene Tracks anzeigen (0 ms ohne Netzwerk-Wartezeit)
        let offlineTracks = OfflineDownloadManager.shared.downloadedTracks(forPlaylistId: playlistId)
        let cachedCollections = await MusicService.shared.cachedLibraryCollections()
        let cachedPlaylistTracks = cachedCollections.playlistTracksMap[playlistId] ?? []
        let offlineById = Dictionary(uniqueKeysWithValues: offlineTracks.map { ($0.id, $0) })

        let mergedCachedTracks: [Track]
        if !cachedPlaylistTracks.isEmpty {
            var seen = Set<String>()
            var combined: [Track] = cachedPlaylistTracks.map { t in
                seen.insert(t.id)
                return offlineById[t.id] ?? t
            }
            for off in offlineTracks where seen.insert(off.id).inserted {
                combined.append(off)
            }
            mergedCachedTracks = combined
        } else {
            mergedCachedTracks = offlineTracks
        }

        if !mergedCachedTracks.isEmpty {
            let meta = OfflineDownloadManager.shared.downloadedPlaylistMeta(forPlaylistId: playlistId)
            await MainActor.run {
                self.playlistData = DiscoveryPlaylistDetailData(
                    id: playlistId,
                    title: meta?.name ?? initialTitle ?? "Playlist",
                    description: nil,
                    cover: meta?.coverUrl ?? initialCover,
                    heroArtwork: nil,
                    motionVideo: nil,
                    user: "Offline",
                    nbTracks: mergedCachedTracks.count,
                    tracks: []
                )
                self.tracks = mergedCachedTracks
                self.isLoading = false
            }
            if await MainActor.run(body: { SessionManager.shared.isOfflineMode }) {
                return
            }
        } else {
            await MainActor.run {
                self.isLoading = true
            }
            if await MainActor.run(body: { SessionManager.shared.isOfflineMode }) {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Im Offline-Modus sind für diese Playlist keine geladenen Titel vorhanden."
                }
                return
            }
        }

        // 1. Try Discovery Playlist (/api/discovery/playlist/:id)
        if let detail = await MusicService.shared.fetchDiscoveryPlaylist(id: playlistId, serverURL: serverURL, token: token) {
            let netTracks = detail.tracks.map { $0.toTrack() }
            await MainActor.run {
                self.playlistData = detail
                if !netTracks.isEmpty || self.tracks.isEmpty {
                    self.tracks = netTracks
                }
                self.isLoading = false
                if OfflineDownloadManager.shared.isPlaylistMarkedForOffline(playlistId) {
                    OfflineDownloadManager.shared.syncPlaylistIfMarked(
                        playlistId: playlistId,
                        name: detail.title,
                        coverUrl: detail.cover,
                        latestTracks: netTracks,
                        serverURL: serverURL,
                        token: token
                    )
                }
            }
            return
        }

        // 2. Try User State (/api/state)
        let (statePlaylists, _) = await MusicService.shared.fetchUserState(serverURL: serverURL, token: token)
        if let found = statePlaylists.first(where: { $0.id == playlistId }) {
            let netTracks = found.tracks.map { $0.toTrack() }
            await MainActor.run {
                self.playlistData = found
                if !netTracks.isEmpty || self.tracks.isEmpty {
                    self.tracks = netTracks
                }
                self.isLoading = false
                if OfflineDownloadManager.shared.isPlaylistMarkedForOffline(playlistId) {
                    OfflineDownloadManager.shared.syncPlaylistIfMarked(
                        playlistId: playlistId,
                        name: found.title,
                        coverUrl: found.cover,
                        latestTracks: netTracks,
                        serverURL: serverURL,
                        token: token
                    )
                }
            }
            return
        }

        await MainActor.run {
            self.isLoading = false
            if self.tracks.isEmpty {
                self.errorMessage = "Playlist konnte nicht geladen werden"
            }
        }
    }

    private func toggleDownload() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        if isPlaylistDownloading {
            OfflineDownloadManager.shared.cancelPlaylistDownload(playlistId)
        } else if isAllTracksDownloaded {
            OfflineDownloadManager.shared.removePlaylistDownload(playlistId: playlistId)
        } else if sessionManager.isOfflineMode {
            if isPlaylistSyncMarked || downloadedTrackCount > 0 {
                OfflineDownloadManager.shared.removePlaylistDownload(playlistId: playlistId)
            }
        } else {
            OfflineDownloadManager.shared.downloadPlaylist(
                playlistId: playlistId,
                name: displayTitle,
                coverUrl: displayCover,
                tracks: tracks,
                serverURL: serverURL,
                token: SessionManager.shared.currentToken
            )
        }
    }
}
