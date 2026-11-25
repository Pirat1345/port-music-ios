import SwiftUI

public struct HomeView: View {
    public let serverURL: String
    public let user: UserProfile

    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared

    @State private var discovery: DiscoveryHomeResponse? = nil
    @State private var userFavorites: [Track] = []
    @State private var userPlaylists: [DiscoveryPlaylist] = []
    @State private var recommendedTracks: [Track] = []
    @State private var topArtistSpotlight: (name: String, tracks: [Track])? = nil
    @State private var radarTracks: [Track] = []

    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var showSettingsSheet: Bool = false

    public init(serverURL: String, user: UserProfile) {
        self.serverURL = serverURL
        self.user = user
    }

    // Exakt identisch zur Web-Funktion getGreeting() in Index.tsx
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Guten Morgen"
        case 12..<18: return "Guten Tag"
        case 18..<23: return "Guten Abend"
        default: return "Gute Nacht"
        }
    }

    private var timeContextSubtitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Dein Sound für den Morgen · Favoriten und Empfehlungen"
        case 12..<18: return "Dein Mix für den Tag · Favoriten, Neuheiten und Trends"
        case 18..<23: return "Dein Abend-Mix · Passend zu deinem Geschmack"
        default: return "Spätabend-Vibes · Favoriten und Entdeckungen"
        }
    }

    public var body: some View {
        ZStack {
            // Reines Schwarz (#000000) wie auf der Webseite
            Color.black
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    // Header: Begruessung + dezenter Avatar-Button rechts
                    topGreetingHeader
                        .padding(.top, 16)

                    mainContentBody

                    // Ausreichend Abstand am unteren Rand fuer MiniPlayer & TabBar
                    Spacer(minLength: 160)
                }
            }
            .refreshable {
                await loadHomeData()
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .task {
            if discovery == nil {
                await loadHomeData()
            } else {
                let token = SessionManager.shared.currentToken
                let historyRes = await MusicService.shared.fetchStatsAndHistory(serverURL: serverURL, token: token)
                if !historyRes.isEmpty {
                    player.mergeServerHistory(historyRes)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task {
                if sessionManager.isOfflineMode {
                    _ = await sessionManager.retryConnection()
                }
                let token = SessionManager.shared.currentToken
                await FavoritesManager.shared.syncPendingWithServer(serverURL: serverURL, token: token)
                let historyRes = await MusicService.shared.fetchStatsAndHistory(serverURL: serverURL, token: token)
                if !historyRes.isEmpty {
                    player.mergeServerHistory(historyRes)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .portMusicDidReconnect)) { _ in
            Task {
                await loadHomeData()
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsMainView(user: user, serverURL: serverURL) {
                SessionManager.shared.logout()
            }
        }
    }

    @ViewBuilder
    private var mainContentBody: some View {
        if sessionManager.isOfflineMode && discovery == nil {
            offlineHomeSection(tracks: offlineManager.allDownloadedTracks())
        } else if isLoading && discovery == nil {
            VStack(spacing: 28) {
                PortShelfSkeletonView()
                PortShelfSkeletonView()
                PortShelfSkeletonView()
            }
            .padding(.top, 16)
        } else if errorMessage != nil, discovery == nil {
            offlineHomeSection(tracks: offlineManager.allDownloadedTracks())
        } else if let data = discovery {
            let deduplicated = deduplicateShelves(data: data, recentHistory: player.recentTracks)
            discoveryShelvesContent(deduplicated: deduplicated, rawData: data)
        }
    }

    @ViewBuilder
    private func discoveryShelvesContent(deduplicated: DeduplicatedResult, rawData: DiscoveryHomeResponse) -> some View {
        // 0. Schnellzugriff (Lieblingssongs + Eigene Playlists)
        if !userFavorites.isEmpty || !userPlaylists.isEmpty {
            quickAccessGridSection
        }

        // 1. Top-Picks für dich (3:4 Poster-Karten, 204x282)
        if !deduplicated.topPicks.isEmpty {
            shelfTopPicks(picks: deduplicated.topPicks, allDiscovery: rawData)
        }

        // 2. Zuletzt gehört (Chronologischer Verlauf)
        if !deduplicated.recentTracks.isEmpty {
            shelfRecentlyPlayed(tracks: deduplicated.recentTracks, allDiscovery: rawData)
        }

        // 3. Mehr von <Top-Künstler> (Artist Deep Cuts Spotlight wie im Web)
        if let spotlight = topArtistSpotlight, !deduplicated.deepCuts.isEmpty {
            shelfDeepCuts(artistName: spotlight.name, tracks: deduplicated.deepCuts, allDiscovery: rawData)
        }

        // 4. Frisch erschienen (Release Radar aus Top-Künstlern & Neuheiten)
        if !deduplicated.releaseRadar.isEmpty {
            shelfReleaseRadar(tracks: deduplicated.releaseRadar, allDiscovery: rawData)
        }

        // 5. Für dich empfohlen (Personalisierte Empfehlungen)
        if !deduplicated.forYou.isEmpty {
            shelfForYou(tracks: deduplicated.forYou, allDiscovery: rawData)
        }

        // 6. Trending überall
        if !deduplicated.trending.isEmpty {
            shelfTrending(tracks: deduplicated.trending, allDiscovery: rawData)
        }

        // 7. Neue Alben & EPs
        if !deduplicated.topAlbums.isEmpty {
            shelfAlbums(albums: deduplicated.topAlbums, allDiscovery: rawData)
        }

        // 8. Frische Song-Drops
        if !deduplicated.newMusicDrops.isEmpty {
            shelfSongDrops(drops: deduplicated.newMusicDrops, allDiscovery: rawData)
        }

        // 9. Top Hits heute (mit Rang-Badges)
        if !deduplicated.topHits.isEmpty {
            shelfTopHits(tracks: deduplicated.topHits, allDiscovery: rawData)
        }

        // 10. Top 100: Global (mit Rang-Badges)
        if !deduplicated.top100.isEmpty {
            shelfTop100Global(tracks: deduplicated.top100, allDiscovery: rawData)
        }

        // 11. Top-Playlists
        if !deduplicated.topPlaylists.isEmpty {
            shelfTopPlaylists(playlists: deduplicated.topPlaylists, allDiscovery: rawData)
        }

        // 12. Stimmungen & Genres (aus Discovery moodsAndGenres)
        if !deduplicated.moodsAndGenres.isEmpty {
            shelfMoodsAndGenres(genres: deduplicated.moodsAndGenres)
        }

        // 13. Deine Playlists (Persönliche Playlists aus der Bibliothek)
        if !userPlaylists.isEmpty {
            shelfUserPlaylists(playlists: userPlaylists)
        }

        // 14. Angesagte Künstler (Runde Avatare)
        if !deduplicated.trendingArtists.isEmpty {
            shelfTrendingArtists(artists: deduplicated.trendingArtists)
        }
    }

    // MARK: - Header (Apple-Stil: Begrüßung + dezenter Avatar-Button rechts)
    private var topGreetingHeader: some View {
        HStack {
            Text(greeting)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                showSettingsSheet = true
            }) {
                PortUserAvatarView(
                    rawAvatar: user.avatar,
                    username: user.username,
                    serverURL: serverURL,
                    size: 38
                )
                .overlay(
                    Circle().stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                )
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Offline Fallback Section
    private func offlineHomeSection(tracks: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(PortColors.accentOrange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Offline-Modus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(tracks.count) gespeicherte Titel auf diesem Gerät bereit")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.60))
                }

                Spacer()

                Button("Verbinden") {
                    Task {
                        _ = await SessionManager.shared.retryConnection()
                        await loadHomeData()
                    }
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)

            if tracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 36))
                        .foregroundColor(Color.white.opacity(0.30))
                    Text("Noch keine Songs heruntergeladen")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Speichere Songs im WLAN über das Drei-Punkte-Menü, um sie ohne Internet zu hören.")
                        .font(.system(size: 12.5))
                        .foregroundColor(Color.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
            } else {
                PortShelfHeader(
                    iconName: "arrow.down.circle.fill",
                    iconColor: Color(hex: "#00d26a"),
                    title: "Heruntergeladene Musik",
                    seeAllTitle: "Alle anzeigen",
                    seeAllRoute: .libraryCategory(category: "downloaded")
                )
                .padding(.horizontal, 20)

                LazyVStack(spacing: 4) {
                    ForEach(Array(tracks.prefix(30).enumerated()), id: \.element.id) { index, track in
                        TrackRowView(
                            track: track,
                            index: index,
                            contextQueue: tracks,
                            serverURL: serverURL,
                            isLiked: FavoritesManager.shared.isFavorite(trackId: track.id),
                            isDownloaded: true,
                            showCover: true,
                            showTrackNumber: false
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Shelf 0: Schnellzugriff (Kompaktes 2-Spalten-Grid wie Web)
    private var quickAccessGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schnellzugriff")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                if !userFavorites.isEmpty {
                    NavigationLink(value: AppRoute.likedSongs) {
                        HStack(spacing: 10) {
                            ZStack {
                                LinearGradient(
                                    colors: [Color(hex: "#6366f1"), Color(hex: "#a855f7")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 50, height: 50)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Lieblingssongs")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text("\(userFavorites.count) Titel")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.white.opacity(0.55))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                        }
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                let maxPlaylists = userFavorites.isEmpty ? 6 : 5
                ForEach(userPlaylists.prefix(maxPlaylists)) { pl in
                    NavigationLink(value: AppRoute.playlist(id: pl.id, title: pl.title, coverUrl: pl.cover)) {
                        HStack(spacing: 10) {
                            PortCoverImage(
                                coverUrl: pl.cover,
                                serverURL: serverURL,
                                placeholderIcon: "music.note.list"
                            )
                            .frame(width: 50, height: 50)
                            .clipped()

                            VStack(alignment: .leading, spacing: 2) {
                                Text(pl.title)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                if let nb = pl.nbTracks {
                                    Text("\(nb) Songs")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.white.opacity(0.55))
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 4)
                        }
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Shelf 1: Top-Picks für dich (3:4 Poster-Karten)
    private func shelfTopPicks(picks: [DiscoveryPosterPick], allDiscovery: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "sparkles",
                iconColor: .white,
                title: "Top-Picks für dich",
                subtitle: timeContextSubtitle
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(picks) { pick in
                    let isCurrentPlaying = player.isPlaying && player.currentTrack?.id == pick.id
                    PortPosterCard(
                        title: pick.title,
                        subtitle: pick.subtitle,
                        coverUrl: pick.cover,
                        serverURL: serverURL,
                        isPlaying: isCurrentPlaying,
                        trackId: pick.id
                    ) {
                        playTrackWithFullQueue(pick.toTrack(), discovery: allDiscovery)
                    }
                }
            }
        }
    }

    // MARK: - Shelf 2: Zuletzt gehört (Recently Played)
    private func shelfRecentlyPlayed(tracks: [Track], allDiscovery: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "clock",
                iconColor: .white,
                title: "Zuletzt gehört",
                seeAllTitle: "Alle anzeigen",
                seeAllRoute: .libraryCategory(category: "history")
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(tracks.prefix(16)) { track in
                    let isCurrentPlaying = player.isPlaying && player.currentTrack?.id == track.id
                    PortTrackCard(
                        title: track.title,
                        subtitle: track.artist,
                        coverUrl: track.coverUrl,
                        serverURL: serverURL,
                        isPlaying: isCurrentPlaying
                    ) {
                        playTrackWithFullQueue(track, discovery: allDiscovery)
                    }
                }
            }
        }
    }

    // MARK: - Shelf 3: Mehr von Top-Künstler (Deep Cuts Spotlight)
    private func shelfDeepCuts(artistName: String, tracks: [Track], allDiscovery: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "opticaldisc",
                iconColor: .white,
                title: "Mehr von \(artistName)",
                subtitle: "Weitere Titel und Favoriten von \(artistName)",
                seeAllTitle: "Alle anzeigen",
                seeAllRoute: .artist(name: artistName, coverUrl: nil)
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(tracks.prefix(14)) { track in
                    let isCurrentPlaying = player.isPlaying && player.currentTrack?.id == track.id
                    PortTrackCard(
                        title: track.title,
                        subtitle: track.artist,
                        coverUrl: track.coverUrl,
                        serverURL: serverURL,
                        isPlaying: isCurrentPlaying
                    ) {
                        playTrackWithFullQueue(track, discovery: allDiscovery)
                    }
                }
            }
        }
    }

    // MARK: - Shelf 4: Frisch erschienen (Release Radar)
    private func shelfReleaseRadar(tracks: [Track], allDiscovery: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "bolt.fill",
                iconColor: .white,
                title: "Frisch erschienen",
                subtitle: "Neue Veröffentlichungen deiner Favoriten & Entdeckungen"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(tracks.prefix(16)) { track in
                    let isCurrentPlaying = player.isPlaying && player.currentTrack?.id == track.id
                    PortTrackCard(
                        title: track.title,
                        subtitle: track.artist,
                        coverUrl: track.coverUrl,
                        serverURL: serverURL,
                        isPlaying: isCurrentPlaying
                    ) {
                        playTrackWithFullQueue(track, discovery: allDiscovery)
                    }
                }
            }
        }
    }

    // MARK: - Shelf 5: Für dich empfohlen
    private func shelfForYou(tracks: [Track], allDiscovery: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "flame.fill",
                iconColor: .white,
                title: "Für dich empfohlen",
                subtitle: "Basierend auf deinem Hörverlauf"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(tracks.prefix(16)) { track in
                    let isCurrentPlaying = player.isPlaying && player.currentTrack?.id == track.id
                    PortTrackCard(
                        title: track.title,
                        subtitle: track.artist,
                        coverUrl: track.coverUrl,
                        serverURL: serverURL,
                        isPlaying: isCurrentPlaying
                    ) {
                        playTrackWithFullQueue(track, discovery: allDiscovery)
                    }
                }
            }
        }
    }

    // MARK: - Shelf 6: Trending überall
    private func shelfTrending(tracks: [Track], allDiscovery: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "chart.line.uptrend.xyaxis",
                iconColor: .white,
                title: "Trending überall",
                subtitle: "Aktuell weltweit angesagte Titel"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(tracks.prefix(16)) { track in
                    let isCurrentPlaying = player.isPlaying && player.currentTrack?.id == track.id
                    PortTrackCard(
                        title: track.title,
                        subtitle: track.artist,
                        coverUrl: track.coverUrl,
                        serverURL: serverURL,
                        isPlaying: isCurrentPlaying
                    ) {
                        playTrackWithFullQueue(track, discovery: allDiscovery)
                    }
                }
            }
        }
    }

    // MARK: - Shelf 7: Neue Alben & EPs
    private func shelfAlbums(albums: [DiscoveryAlbum], allDiscovery: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "square.stack.fill",
                iconColor: .white,
                title: "Neue Alben & EPs",
                subtitle: "Brandneue Alben & Veröffentlichungen der Woche"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(albums.prefix(24)) { album in
                    NavigationLink(value: AppRoute.album(
                        id: album.id,
                        title: album.title,
                        artist: album.artist,
                        coverUrl: album.cover
                    )) {
                        PortAlbumCard(
                            title: album.title,
                            subtitle: album.artist,
                            coverUrl: album.cover,
                            serverURL: serverURL,
                            onTap: nil,
                            onPlay: {
                                Task {
                                    if let detail = await MusicService.shared.fetchAlbum(id: album.id, serverURL: serverURL, token: SessionManager.shared.currentToken) {
                                        let trks = detail.tracks.map { $0.toTrack() }
                                        if let first = trks.first {
                                            await MainActor.run {
                                                player.play(track: first, from: trks, serverURL: serverURL)
                                            }
                                        }
                                    }
                                }
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Shelf 8: Frische Song-Drops
    private func shelfSongDrops(drops: [DiscoveryAlbum], allDiscovery: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "sparkles",
                iconColor: .white,
                title: "Frische Song-Drops",
                subtitle: "Tagesaktuelle Hits & Drops, handverlesen"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(drops.prefix(24)) { drop in
                    NavigationLink(value: AppRoute.album(
                        id: drop.id,
                        title: drop.title,
                        artist: drop.artist,
                        coverUrl: drop.cover
                    )) {
                        PortTrackCard(
                            title: drop.title,
                            subtitle: drop.artist,
                            coverUrl: drop.cover,
                            serverURL: serverURL,
                            onTap: nil,
                            onPlay: {
                                let fallbackTrack = Track(
                                    id: drop.id,
                                    title: drop.title,
                                    artist: drop.artist,
                                    album: drop.title,
                                    coverUrl: drop.cover
                                )
                                playTrackWithFullQueue(fallbackTrack, discovery: allDiscovery)
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Shelf 9: Top Hits heute (mit Rang-Badge)
    private func shelfTopHits(tracks: [DiscoveryChartTrack], allDiscovery: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "chart.line.uptrend.xyaxis",
                iconColor: .white,
                title: "Top Hits heute",
                subtitle: "Die meistgespielten Titel"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(Array(tracks.prefix(16).enumerated()), id: \.element.id) { index, item in
                    let track = item.toTrack()
                    let isCurrentPlaying = player.isPlaying && player.currentTrack?.id == track.id
                    let rankNum = item.rank ?? (index + 1)
                    PortTrackCard(
                        title: track.title,
                        subtitle: track.artist,
                        coverUrl: track.coverUrl,
                        serverURL: serverURL,
                        rank: rankNum,
                        isPlaying: isCurrentPlaying
                    ) {
                        playTrackWithFullQueue(track, discovery: allDiscovery)
                    }
                }
            }
        }
    }

    // MARK: - Shelf 10: Top 100: Global
    private func shelfTop100Global(tracks: [DiscoveryChartTrack], allDiscovery: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "bolt.fill",
                iconColor: .white,
                title: "Top 100: Global",
                subtitle: "Live-Chart — täglich aktualisiert"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(Array(tracks.prefix(25).enumerated()), id: \.element.id) { index, item in
                    let track = item.toTrack()
                    let isCurrentPlaying = player.isPlaying && player.currentTrack?.id == track.id
                    let rankNum = item.rank ?? (index + 1)
                    PortAlbumCard(
                        title: track.title,
                        subtitle: track.artist,
                        coverUrl: track.coverUrl,
                        serverURL: serverURL,
                        rank: rankNum,
                        isPlaying: isCurrentPlaying
                    ) {
                        playTrackWithFullQueue(track, discovery: allDiscovery)
                    }
                }
            }
        }
    }

    // MARK: - Shelf 11: Top-Playlists
    private func shelfTopPlaylists(playlists: [DiscoveryPlaylist], allDiscovery: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "music.note.list",
                iconColor: .white,
                title: "Top-Playlists",
                subtitle: "Die beliebtesten Playlists der Community"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(playlists.prefix(20)) { playlist in
                    let sub = playlist.user ?? (playlist.nbTracks.map { "\($0) Songs" } ?? "Playlist")
                    NavigationLink(value: AppRoute.playlist(
                        id: playlist.id,
                        title: playlist.title,
                        coverUrl: playlist.cover
                    )) {
                        PortTrackCard(
                            title: playlist.title,
                            subtitle: sub,
                            coverUrl: playlist.cover,
                            serverURL: serverURL,
                            onTap: nil,
                            onPlay: {
                                Task {
                                    if let detail = await MusicService.shared.fetchDiscoveryPlaylist(id: playlist.id, serverURL: serverURL, token: SessionManager.shared.currentToken) {
                                        let trks = detail.tracks.map { $0.toTrack() }
                                        if let first = trks.first {
                                            await MainActor.run {
                                                player.play(track: first, from: trks, serverURL: serverURL)
                                            }
                                        }
                                    }
                                }
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Shelf 12: Stimmungen & Genres
    private func shelfMoodsAndGenres(genres: [DiscoveryMoodGenre]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "square.grid.2x2.fill",
                iconColor: .white,
                title: "Stimmungen & Genres",
                subtitle: "Entdecke passende Playlists und Sounds nach Genre"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(genres) { genre in
                    NavigationLink(value: AppRoute.appleCategory(
                        id: genre.id,
                        title: genre.title,
                        artworkUrl: genre.cover,
                        bgColor: nil
                    )) {
                        ZStack(alignment: .bottomLeading) {
                            PortCoverImage(
                                coverUrl: genre.cover,
                                serverURL: serverURL,
                                placeholderIcon: "music.quarternote.3"
                            )
                            .frame(width: 150, height: 110)
                            .clipped()

                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.25),
                                    .init(color: Color.black.opacity(0.84), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )

                            Text(genre.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 10)
                        }
                        .frame(width: 150, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Shelf 13: Deine Playlists (aus Bibliothek)
    private func shelfUserPlaylists(playlists: [DiscoveryPlaylist]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "music.note.list",
                iconColor: .white,
                title: "Deine Playlists",
                seeAllTitle: "Alle anzeigen",
                seeAllRoute: .libraryCategory(category: "playlists")
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(playlists.prefix(12)) { pl in
                    let sub = pl.nbTracks.map { "\($0) Songs" } ?? "Eigene Playlist"
                    NavigationLink(value: AppRoute.playlist(
                        id: pl.id,
                        title: pl.title,
                        coverUrl: pl.cover
                    )) {
                        PortTrackCard(
                            title: pl.title,
                            subtitle: sub,
                            coverUrl: pl.cover,
                            serverURL: serverURL,
                            onTap: nil,
                            onPlay: {
                                Task {
                                    if let detail = await MusicService.shared.fetchDiscoveryPlaylist(id: pl.id, serverURL: serverURL, token: SessionManager.shared.currentToken) {
                                        let trks = detail.tracks.map { $0.toTrack() }
                                        if let first = trks.first {
                                            await MainActor.run {
                                                player.play(track: first, from: trks, serverURL: serverURL)
                                            }
                                        }
                                    }
                                }
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Shelf 14: Angesagte Künstler
    private func shelfTrendingArtists(artists: [DiscoveryArtist]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "dot.radiowaves.left.and.right",
                iconColor: .white,
                title: "Angesagte Künstler"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(artists) { artist in
                    NavigationLink(value: AppRoute.artist(
                        name: artist.name,
                        coverUrl: artist.picture
                    )) {
                        PortArtistCard(artist: artist, serverURL: serverURL)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Master Cross-Shelf Deduplication Pipeline (Ohne Leerlaufen von Drops & Top Hits)
    private struct DeduplicatedResult {
        let topPicks: [DiscoveryPosterPick]
        let recentTracks: [Track]
        let deepCuts: [Track]
        let releaseRadar: [Track]
        let forYou: [Track]
        let trending: [Track]
        let topAlbums: [DiscoveryAlbum]
        let newMusicDrops: [DiscoveryAlbum]
        let topHits: [DiscoveryChartTrack]
        let top100: [DiscoveryChartTrack]
        let topPlaylists: [DiscoveryPlaylist]
        let moodsAndGenres: [DiscoveryMoodGenre]
        let trendingArtists: [DiscoveryArtist]
    }

    private func deduplicateShelves(data: DiscoveryHomeResponse, recentHistory: [Track]) -> DeduplicatedResult {
        var seenIds = Set<String>()
        var seenSignatures = Set<String>()

        func getSignature(title: String, artist: String) -> String {
            let cleanTitle = title.lowercased()
                .replacingOccurrences(of: "\\s*\\(remaster(ed)?(\\s*\\d+)?\\)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s*\\[official.*?\\]", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s*\\(feat\\..*?\\)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s*\\(with.*?\\)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s*-\\s*ep$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s*-\\s*single$", with: "", options: .regularExpression)
                .filter { $0.isLetter || $0.isNumber }

            let cleanArtist = artist.lowercased()
                .replacingOccurrences(of: "\\s*feat\\..*$", with: "", options: .regularExpression)
                .filter { $0.isLetter || $0.isNumber }

            return cleanArtist.isEmpty ? cleanTitle : "\(cleanTitle):::\(cleanArtist)"
        }

        func primaryArtistKey(_ artist: String) -> String {
            let base = artist
                .components(separatedBy: CharacterSet(charactersIn: ",;/&"))
                .first ?? artist
            return base.lowercased()
                .replacingOccurrences(of: "\\s*feat\\..*$", with: "", options: .regularExpression)
                .filter { $0.isLetter || $0.isNumber }
        }

        func isDuplicate(id: String, title: String, artist: String) -> Bool {
            if !id.isEmpty && seenIds.contains(id) { return true }
            let sig = getSignature(title: title, artist: artist)
            if !sig.isEmpty && seenSignatures.contains(sig) { return true }
            return false
        }

        func register(id: String, title: String, artist: String) {
            if !id.isEmpty { seenIds.insert(id) }
            let sig = getSignature(title: title, artist: artist)
            if !sig.isEmpty { seenSignatures.insert(sig) }
        }

        // 1. Top-Picks: Personalisierte Mischung aus Favoriten, Verlauf, Empfehlungen & Server-Picks (bis zu 8, ein Künstler pro Pick)
        var dedupTopPicks: [DiscoveryPosterPick] = []
        var topPickArtists = Set<String>()

        func tryAddPick(_ pick: DiscoveryPosterPick) {
            guard dedupTopPicks.count < 8 else { return }
            let aKey = primaryArtistKey(pick.subtitle)
            if !aKey.isEmpty && topPickArtists.contains(aKey) { return }
            guard !pick.cover.isEmpty else { return }
            if !isDuplicate(id: pick.id, title: pick.title, artist: pick.subtitle) {
                register(id: pick.id, title: pick.title, artist: pick.subtitle)
                if !aKey.isEmpty { topPickArtists.insert(aKey) }
                dedupTopPicks.append(pick)
            }
        }

        for pick in data.topPicks ?? [] {
            tryAddPick(pick)
        }
        for fav in userFavorites {
            if let cov = fav.coverUrl, !cov.isEmpty {
                tryAddPick(DiscoveryPosterPick(
                    id: fav.id,
                    tag: "Favorit",
                    title: fav.title,
                    subtitle: fav.artist,
                    cover: cov,
                    kind: "track",
                    targetUrl: ""
                ))
            }
        }
        for rec in recommendedTracks {
            if let cov = rec.coverUrl, !cov.isEmpty {
                tryAddPick(DiscoveryPosterPick(
                    id: rec.id,
                    tag: "Empfehlung",
                    title: rec.title,
                    subtitle: rec.artist,
                    cover: cov,
                    kind: "track",
                    targetUrl: ""
                ))
            }
        }
        for tr in data.trendingEverywhere ?? [] {
            if let cov = tr.cover, !cov.isEmpty {
                tryAddPick(DiscoveryPosterPick(
                    id: tr.id,
                    tag: "Trending",
                    title: tr.title,
                    subtitle: tr.artist,
                    cover: cov,
                    kind: "track",
                    targetUrl: ""
                ))
            }
        }

        // 2. Zuletzt gehört (darf NIEMALS durch Top-Picks geleert werden!)
        var dedupRecent: [Track] = []
        var recentSeen = Set<String>()
        var recentSigs = Set<String>()
        for t in recentHistory {
            let sig = getSignature(title: t.title, artist: t.artist)
            if recentSeen.contains(t.id) || (!sig.isEmpty && recentSigs.contains(sig)) {
                continue
            }
            recentSeen.insert(t.id)
            if !sig.isEmpty { recentSigs.insert(sig) }
            register(id: t.id, title: t.title, artist: t.artist)
            dedupRecent.append(t)
        }

        // 3. Mehr von Top-Künstler (Deep Cuts Spotlight)
        var dedupDeepCuts: [Track] = []
        if let spotlight = topArtistSpotlight {
            for t in spotlight.tracks {
                if !isDuplicate(id: t.id, title: t.title, artist: t.artist) {
                    register(id: t.id, title: t.title, artist: t.artist)
                    dedupDeepCuts.append(t)
                }
            }
        }

        // 4. Frisch erschienen (Release Radar — nutzt zuerst Künstler-Releases, danach ggf. hintere Top100/Alben ohne newMusic zu plündern)
        var dedupRadar: [Track] = []
        var radarArtists = Set<String>()
        for t in radarTracks {
            let aKey = primaryArtistKey(t.artist)
            if !aKey.isEmpty && radarArtists.contains(aKey) { continue }
            if !isDuplicate(id: t.id, title: t.title, artist: t.artist) {
                register(id: t.id, title: t.title, artist: t.artist)
                if !aKey.isEmpty { radarArtists.insert(aKey) }
                dedupRadar.append(t)
            }
        }
        // Falls Nutzer noch keine eigenen Künstler hat, ergänzen wir aus Top-Alben
        if dedupRadar.count < 8 {
            for alb in (data.topAlbums ?? []).prefix(12) {
                guard dedupRadar.count < 14 else { break }
                let aKey = primaryArtistKey(alb.artist)
                if !aKey.isEmpty && radarArtists.contains(aKey) { continue }
                let t = Track(id: alb.id, title: alb.title, artist: alb.artist, album: alb.title, coverUrl: alb.cover)
                if !isDuplicate(id: t.id, title: t.title, artist: t.artist) {
                    register(id: t.id, title: t.title, artist: t.artist)
                    if !aKey.isEmpty { radarArtists.insert(aKey) }
                    dedupRadar.append(t)
                }
            }
        }

        // 5. Für dich empfohlen (nutzt Recommendations + Favoriten + tieferen Top100-Pool, lässt todaysTopHits unberührt!)
        var dedupForYou: [Track] = []
        var forYouArtists = Set<String>()
        let forYouCandidates: [Track] = recommendedTracks + userFavorites + (data.top100Global ?? []).dropFirst(16).map { $0.toTrack() }
        for t in forYouCandidates {
            guard dedupForYou.count < 16 else { break }
            let aKey = primaryArtistKey(t.artist)
            if !aKey.isEmpty && forYouArtists.contains(aKey) { continue }
            if !isDuplicate(id: t.id, title: t.title, artist: t.artist) {
                register(id: t.id, title: t.title, artist: t.artist)
                if !aKey.isEmpty { forYouArtists.insert(aKey) }
                dedupForYou.append(t)
            }
        }

        // 6. Trending überall
        var dedupTrending: [Track] = []
        for item in data.trendingEverywhere ?? [] {
            let t = item.toTrack()
            if !isDuplicate(id: t.id, title: t.title, artist: t.artist) {
                register(id: t.id, title: t.title, artist: t.artist)
                dedupTrending.append(t)
            }
        }

        // 7. Neue Alben & EPs (eigener Album-Pool, dedupliziert innerhalb Alben)
        var dedupAlbums: [DiscoveryAlbum] = []
        var seenAlbumArtists = Set<String>()
        var seenAlbumIds = Set<String>()
        for album in data.topAlbums ?? [] {
            if seenAlbumIds.contains(album.id) { continue }
            let aKey = primaryArtistKey(album.artist)
            if !aKey.isEmpty && seenAlbumArtists.contains(aKey) { continue }
            seenAlbumIds.insert(album.id)
            if !aKey.isEmpty { seenAlbumArtists.insert(aKey) }
            dedupAlbums.append(album)
        }

        // 8. Frische Song-Drops (komplett aus data.newMusic — bleibt voll erhalten!)
        var dedupDrops: [DiscoveryAlbum] = []
        var dropArtists = Set<String>()
        for drop in data.newMusic ?? [] {
            let aKey = primaryArtistKey(drop.artist)
            if !aKey.isEmpty && dropArtists.contains(aKey) { continue }
            if !isDuplicate(id: drop.id, title: drop.title, artist: drop.artist) {
                register(id: drop.id, title: drop.title, artist: drop.artist)
                if !aKey.isEmpty { dropArtists.insert(aKey) }
                dedupDrops.append(drop)
            }
        }

        // 9. Top Hits heute (aus data.todaysTopHits — bleibt voll erhalten mit Rang-Badges!)
        var dedupHits: [DiscoveryChartTrack] = []
        var hitsArtists = Set<String>()
        for item in data.todaysTopHits ?? [] {
            let t = item.toTrack()
            let aKey = primaryArtistKey(t.artist)
            if !aKey.isEmpty && hitsArtists.contains(aKey) { continue }
            if !isDuplicate(id: t.id, title: t.title, artist: t.artist) {
                register(id: t.id, title: t.title, artist: t.artist)
                if !aKey.isEmpty { hitsArtists.insert(aKey) }
                dedupHits.append(item)
            }
        }

        // 10. Top 100: Global (eigenständiger Chart wie im Web — bewahrt Ränge 1..25)
        var dedup100: [DiscoveryChartTrack] = []
        var seenTop100Keys = Set<String>()
        for item in data.top100Global ?? [] {
            let key = "\(item.id)_\(item.title)_\(item.artist)".lowercased()
            if !seenTop100Keys.contains(key) {
                seenTop100Keys.insert(key)
                dedup100.append(item)
            }
        }

        return DeduplicatedResult(
            topPicks: dedupTopPicks,
            recentTracks: dedupRecent,
            deepCuts: dedupDeepCuts,
            releaseRadar: dedupRadar,
            forYou: dedupForYou,
            trending: dedupTrending,
            topAlbums: dedupAlbums,
            newMusicDrops: dedupDrops,
            topHits: dedupHits,
            top100: dedup100,
            topPlaylists: data.topPlaylists ?? [],
            moodsAndGenres: data.moodsAndGenres ?? [],
            trendingArtists: data.trendingArtists ?? []
        )
    }

    // MARK: - Queue Seeding Helper (Feature #7: Dynamic Discovery Queue Pre-seeding)
    private func makeDiscoveryQueue(targetTrack: Track, discovery: DiscoveryHomeResponse) -> [Track] {
        var queue: [Track] = []
        var seenIds = Set<String>()

        seenIds.insert(targetTrack.id)
        queue.append(targetTrack)

        let pools: [[Track]] = [
            discovery.topPicks?.map { $0.toTrack() } ?? [],
            recommendedTracks,
            discovery.trendingEverywhere?.map { $0.toTrack() } ?? [],
            discovery.todaysTopHits?.map { $0.toTrack() } ?? [],
            discovery.newMusic?.map { Track(id: $0.id, title: $0.title, artist: $0.artist, album: $0.title, coverUrl: $0.cover) } ?? [],
            discovery.top100Global?.map { $0.toTrack() } ?? []
        ]

        for pool in pools {
            for t in pool {
                if !seenIds.contains(t.id) {
                    seenIds.insert(t.id)
                    queue.append(t)
                }
            }
        }

        return queue
    }

    private func playTrackWithFullQueue(_ targetTrack: Track, discovery: DiscoveryHomeResponse) {
        var resolvedTrack = targetTrack
        if resolvedTrack.durationSeconds <= 0 {
            if let m = (discovery.trendingEverywhere ?? []).first(where: { $0.id == targetTrack.id || ($0.title.lowercased() == targetTrack.title.lowercased() && $0.artist.lowercased() == targetTrack.artist.lowercased()) }) {
                resolvedTrack = m.toTrack()
            } else if let m = (discovery.todaysTopHits ?? []).first(where: { $0.id == targetTrack.id || ($0.title.lowercased() == targetTrack.title.lowercased() && $0.artist.lowercased() == targetTrack.artist.lowercased()) }) {
                resolvedTrack = m.toTrack()
            }
        }
        let queue = makeDiscoveryQueue(targetTrack: resolvedTrack, discovery: discovery)
        player.play(track: resolvedTrack, from: queue, serverURL: serverURL)
    }

    // MARK: - Fehleranzeige
    private func errorStateView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 38))
                .foregroundColor(PortColors.errorRed)

            Text("Entdeckungen konnten nicht geladen werden")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(PortColors.textPrimary)

            Text(error)
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.60))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button(action: {
                Task {
                    await loadHomeData()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .bold))
                    Text("Erneut versuchen")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(PortColors.buttonPrimaryBg)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - API Abruf & Personalisierte Anreicherung
    private func loadHomeData() async {
        isLoading = true
        errorMessage = nil

        let token = SessionManager.shared.currentToken

        async let discoveryFetch = MusicService.shared.fetchHomeDiscovery(serverURL: serverURL, token: token)
        async let historyFetch = MusicService.shared.fetchStatsAndHistory(serverURL: serverURL, token: token)
        async let favoritesFetch = MusicService.shared.fetchFavorites(serverURL: serverURL, token: token)
        async let playlistsFetch = MusicService.shared.fetchPlaylists(serverURL: serverURL, token: token)

        let (discoveryRes, historyRes, favsRes, plsRes) = await (discoveryFetch, historyFetch, favoritesFetch, playlistsFetch)

        if !historyRes.isEmpty {
            player.mergeServerHistory(historyRes)
        }

        await MainActor.run {
            if !favsRes.isEmpty || discoveryRes != nil {
                self.userFavorites = favsRes
            } else if self.userFavorites.isEmpty {
                self.userFavorites = FavoritesManager.shared.cachedFavoriteTracks
            }
            if !plsRes.isEmpty || discoveryRes != nil {
                self.userPlaylists = plsRes
            }
        }

        if let response = discoveryRes {
            await MainActor.run {
                SessionManager.shared.setOfflineMode(false)
                self.discovery = response
                self.isLoading = false
            }
            prefetchHomeCovers(from: response)
            await enrichPersonalizedShelves(discovery: response, favorites: favsRes, token: token)
        } else {
            await MainActor.run {
                SessionManager.shared.setOfflineMode(true)
                self.errorMessage = "Keine Verbindung zum Server auf \(serverURL)."
                self.isLoading = false
            }
        }
    }

    private func enrichPersonalizedShelves(discovery: DiscoveryHomeResponse, favorites: [Track], token: String?) async {
        let pool = player.recentTracks + favorites
        var artistCounts: [String: (display: String, count: Int)] = [:]
        for t in pool {
            let raw = t.artist
                .components(separatedBy: CharacterSet(charactersIn: ",;/&"))
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let clean = raw.replacingOccurrences(of: "\\s*feat\\..*$", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty, clean.lowercased() != "unbekannt", clean.lowercased() != "unbekannter interpret" else { continue }
            let key = clean.lowercased()
            let existing = artistCounts[key]?.count ?? 0
            artistCounts[key] = (display: artistCounts[key]?.display ?? clean, count: existing + 1)
        }

        let topArtists = artistCounts.values
            .sorted { $0.count > $1.count }
            .map { $0.display }

        // 1. Personalisierte Empfehlungen (/api/discovery/recommendations)
        let seedTrack = favorites.first ?? player.recentTracks.first ?? discovery.trendingEverywhere?.first?.toTrack()
        var recResults: [Track] = []
        if let seed = seedTrack {
            recResults = await MusicService.shared.fetchRecommendations(
                trackId: seed.id,
                artist: topArtists.first ?? seed.artist,
                title: seed.title,
                serverURL: serverURL,
                token: token
            )
        }

        // 2. Top-Künstler Deep Cuts & Release Radar
        var spotlightResult: (name: String, tracks: [Track])? = nil
        var radarResults: [Track] = []
        let currentYear = Calendar.current.component(.year, from: Date())

        for (idx, artistName) in topArtists.prefix(3).enumerated() {
            if let detail = await MusicService.shared.fetchArtist(name: artistName, serverURL: serverURL, token: token) {
                if idx == 0 && !detail.topTracks.isEmpty {
                    let mapped = detail.topTracks.map { $0.toTrack(fallbackCover: detail.picture, fallbackAlbum: detail.name) }
                    spotlightResult = (name: detail.name, tracks: mapped)
                }

                let recentItems = detail.singles + detail.albums
                for item in recentItems {
                    if let y = item.year, y >= currentYear - 1 {
                        let t = Track(
                            id: item.id,
                            title: item.title,
                            artist: detail.name,
                            album: item.title,
                            coverUrl: item.cover ?? detail.picture
                        )
                        radarResults.append(t)
                    }
                }
            }
        }

        await MainActor.run {
            self.recommendedTracks = recResults
            self.topArtistSpotlight = spotlightResult
            self.radarTracks = radarResults
        }
    }

    private func prefetchHomeCovers(from res: DiscoveryHomeResponse) {
        var rawUrls: [String?] = []
        res.topPicks?.forEach { rawUrls.append($0.cover) }
        res.trendingEverywhere?.forEach { rawUrls.append($0.cover) }
        res.todaysTopHits?.forEach { rawUrls.append($0.cover) }
        res.top100Global?.forEach { rawUrls.append($0.cover) }
        res.topAlbums?.forEach { rawUrls.append($0.cover) }
        res.newMusic?.forEach { rawUrls.append($0.cover) }
        res.topPlaylists?.forEach { rawUrls.append($0.cover) }
        res.trendingArtists?.forEach { rawUrls.append($0.picture) }
        res.trendingAlbums?.forEach { rawUrls.append($0.cover) }
        res.moodsAndGenres?.forEach { rawUrls.append($0.cover) }

        let resolved = rawUrls.compactMap { resolveCoverURL($0, serverURL: serverURL) }
        PortImageCache.shared.prefetch(urls: resolved)
    }
}
