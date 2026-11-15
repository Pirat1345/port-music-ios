import SwiftUI

public struct HomeView: View {
    public let serverURL: String
    public let user: UserProfile

    @ObservedObject private var player = AudioPlayerManager.shared
    @State private var discovery: DiscoveryHomeResponse? = nil
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil

    public init(serverURL: String, user: UserProfile) {
        self.serverURL = serverURL
        self.user = user
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Guten Morgen"
        case 12..<18: return "Guten Tag"
        case 18..<23: return "Guten Abend"
        default: return "Gute Nacht"
        }
    }

    public var body: some View {
        ZStack {
            FluentBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    // Header: Begruessung & Server-Status
                    topGreetingHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    if isLoading && discovery == nil {
                        VStack(spacing: 28) {
                            PortShelfSkeletonView()
                            PortShelfSkeletonView()
                            PortShelfSkeletonView()
                        }
                        .padding(.top, 16)
                    } else if let error = errorMessage, discovery == nil {
                        errorStateView(error)
                    } else if let data = discovery {
                        // SHELF 1: Top-Picks für dich (3:4 Poster Cards wie im Web / PWA)
                        if let topPicks = data.topPicks, !topPicks.isEmpty {
                            shelfTopPicks(picks: topPicks, data: data)
                        }

                        // SHELF 2: Trending überall (1:1 Standard Cards)
                        if let trending = data.trendingEverywhere, !trending.isEmpty {
                            shelfTrending(tracks: trending, data: data)
                        }

                        // SHELF 3: Top Hits heute (1:1 Cards mit Rang-Badge)
                        if let topHits = data.todaysTopHits, !topHits.isEmpty {
                            shelfTopHits(tracks: topHits, data: data)
                        }

                        // SHELF 4: Neue Alben & EPs
                        if let albums = data.topAlbums ?? data.newMusic, !albums.isEmpty {
                            shelfAlbums(albums: albums)
                        }

                        // SHELF 5: Frische Song-Drops
                        if let drops = data.newMusic, !drops.isEmpty {
                            shelfSongDrops(drops: drops, data: data)
                        }

                        // SHELF 6: Top 100: Global
                        if let global100 = data.top100Global, !global100.isEmpty {
                            shelfTop100Global(tracks: global100, data: data)
                        }

                        // SHELF 7: Top-Playlists
                        if let playlists = data.topPlaylists, !playlists.isEmpty {
                            shelfTopPlaylists(playlists: playlists)
                        }

                        // SHELF 8: Angesagte Künstler (Runde Avatar-Karten)
                        if let artists = data.trendingArtists, !artists.isEmpty {
                            shelfTrendingArtists(artists: artists)
                        }
                    }

                    // Ausreichend Abstand am unteren Rand fuer MiniPlayer & TabBar
                    Spacer(minLength: 100)
                }
            }
            .refreshable {
                await loadHomeData()
            }
        }
        .task {
            if discovery == nil {
                await loadHomeData()
            }
        }
    }

    // MARK: - Header mit dynamischer Begruessung
    private var topGreetingHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(PortColors.textPrimary)

                Text(user.username)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.60))
            }

            Spacer()

            // Server-Status-Pill
            HStack(spacing: 6) {
                Circle()
                    .fill(PortColors.successGreen)
                    .frame(width: 7, height: 7)

                Text("Online")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(PortColors.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(PortColors.surfaceGlass)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(PortColors.borderGlass, lineWidth: 1))
        }
    }

    // MARK: - Shelf 1: Top-Picks für dich (3:4 Poster Cards)
    private func shelfTopPicks(picks: [DiscoveryPosterPick], data: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "sparkles",
                iconColor: PortColors.accentOrange,
                title: "Top-Picks für dich",
                subtitle: "Favoriten, Neuheiten und Empfehlungen"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(picks) { pick in
                    let isCurrentPlaying = player.isPlaying && player.currentTrack?.id == pick.id
                    PortPosterCard(
                        title: pick.title,
                        subtitle: pick.subtitle,
                        coverUrl: pick.cover,
                        isPlaying: isCurrentPlaying
                    ) {
                        playTrackWithDiscoveryQueue(pick.toTrack(), data: data)
                    }
                }
            }
        }
    }

    // MARK: - Shelf 2: Trending überall (1:1 Cards)
    private func shelfTrending(tracks: [DiscoveryTrack], data: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "chart.line.uptrend.xyaxis",
                iconColor: PortColors.accentOrange,
                title: "Trending überall",
                subtitle: "Aktuell weltweit am meisten gestreamt"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(tracks) { item in
                    let track = item.toTrack()
                    let isCurrentPlaying = player.isPlaying && player.currentTrack?.id == track.id
                    PortTrackCard(
                        title: track.title,
                        subtitle: track.artist,
                        coverUrl: track.coverUrl,
                        isPlaying: isCurrentPlaying
                    ) {
                        playTrackWithDiscoveryQueue(track, data: data)
                    }
                }
            }
        }
    }

    // MARK: - Shelf 3: Top Hits heute (1:1 Cards mit Rang)
    private func shelfTopHits(tracks: [DiscoveryChartTrack], data: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "flame.fill",
                iconColor: PortColors.accentOrange,
                title: "Top Hits heute",
                subtitle: "Die beliebtesten Titel von heute"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, item in
                    let track = item.toTrack()
                    let isCurrentPlaying = player.isPlaying && player.currentTrack?.id == track.id
                    let rankNumber = item.rank ?? (index + 1)
                    PortTrackCard(
                        title: track.title,
                        subtitle: track.artist,
                        coverUrl: track.coverUrl,
                        rank: rankNumber,
                        isPlaying: isCurrentPlaying
                    ) {
                        playTrackWithDiscoveryQueue(track, data: data)
                    }
                }
            }
        }
    }

    // MARK: - Shelf 4: Neue Alben & EPs
    private func shelfAlbums(albums: [DiscoveryAlbum]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "square.stack.fill",
                iconColor: PortColors.accentOrange,
                title: "Neue Alben & EPs",
                subtitle: "Brandneue Veröffentlichungen der Woche"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(albums) { album in
                    PortAlbumCard(
                        title: album.title,
                        subtitle: album.artist,
                        coverUrl: album.cover
                    ) {
                        let fallbackTrack = Track(
                            id: "album_\(album.id)",
                            title: album.title,
                            artist: album.artist,
                            album: album.title,
                            coverUrl: album.cover
                        )
                        player.play(track: fallbackTrack, serverURL: serverURL)
                    }
                }
            }
        }
    }

    // MARK: - Shelf 5: Frische Song-Drops
    private func shelfSongDrops(drops: [DiscoveryAlbum], data: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "sparkles",
                iconColor: PortColors.accentOrange,
                title: "Frische Song-Drops",
                subtitle: "Tagesaktuelle Hits & Drops, handverlesen"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(drops) { drop in
                    let dropTrack = Track(
                        id: "drop_\(drop.id)",
                        title: drop.title,
                        artist: drop.artist,
                        album: drop.title,
                        coverUrl: drop.cover
                    )
                    let isCurrentPlaying = player.isPlaying && player.currentTrack?.id == dropTrack.id
                    PortTrackCard(
                        title: drop.title,
                        subtitle: drop.artist,
                        coverUrl: drop.cover,
                        isPlaying: isCurrentPlaying
                    ) {
                        playTrackWithDiscoveryQueue(dropTrack, data: data)
                    }
                }
            }
        }
    }

    // MARK: - Shelf 6: Top 100: Global
    private func shelfTop100Global(tracks: [DiscoveryChartTrack], data: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "bolt.fill",
                iconColor: PortColors.accentOrange,
                title: "Top 100: Global",
                subtitle: "Live-Chart — täglich aktualisiert"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, item in
                    let track = item.toTrack()
                    let isCurrentPlaying = player.isPlaying && player.currentTrack?.id == track.id
                    let rankNumber = item.rank ?? (index + 1)
                    PortAlbumCard(
                        title: track.title,
                        subtitle: track.artist,
                        coverUrl: track.coverUrl,
                        rank: rankNumber,
                        isPlaying: isCurrentPlaying
                    ) {
                        playTrackWithDiscoveryQueue(track, data: data)
                    }
                }
            }
        }
    }

    // MARK: - Shelf 7: Top-Playlists
    private func shelfTopPlaylists(playlists: [DiscoveryPlaylist]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "music.note.list",
                iconColor: PortColors.accentOrange,
                title: "Top-Playlists",
                subtitle: "Die beliebtesten Playlists der Community"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(playlists) { playlist in
                    let sub = playlist.user ?? (playlist.nbTracks.map { "\($0) Songs" } ?? "Playlist")
                    PortTrackCard(
                        title: playlist.title,
                        subtitle: sub,
                        coverUrl: playlist.cover
                    ) {
                        let playlistTrack = Track(
                            id: "pl_\(playlist.id)",
                            title: playlist.title,
                            artist: playlist.user ?? "Port Music",
                            album: "Playlist",
                            coverUrl: playlist.cover
                        )
                        player.play(track: playlistTrack, serverURL: serverURL)
                    }
                }
            }
        }
    }

    // MARK: - Shelf 8: Angesagte Künstler
    private func shelfTrendingArtists(artists: [DiscoveryArtist]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "person.2.fill",
                iconColor: PortColors.accentOrange,
                title: "Angesagte Künstler",
                subtitle: "Beliebte Musiker weltweit"
            )
            .padding(.horizontal, 20)

            PortShelfContainer {
                ForEach(artists) { artist in
                    PortArtistCard(artist: artist) {
                        let artistTrack = Track(
                            id: "artist_\(artist.id)",
                            title: artist.name,
                            artist: artist.name,
                            coverUrl: artist.picture
                        )
                        player.play(track: artistTrack, serverURL: serverURL)
                    }
                }
            }
        }
    }

    // MARK: - Continuous Playback Queue Helper (Invariante 3)
    private func playTrackWithDiscoveryQueue(_ targetTrack: Track, data: DiscoveryHomeResponse) {
        var queuePool: [Track] = [targetTrack]

        if let picks = data.topPicks {
            for p in picks {
                let t = p.toTrack()
                if t.id != targetTrack.id && !queuePool.contains(where: { $0.id == t.id }) {
                    queuePool.append(t)
                }
            }
        }
        if let trending = data.trendingEverywhere {
            for tr in trending {
                let t = tr.toTrack()
                if t.id != targetTrack.id && !queuePool.contains(where: { $0.id == t.id }) {
                    queuePool.append(t)
                }
            }
        }
        if let topHits = data.todaysTopHits {
            for ch in topHits {
                let t = ch.toTrack()
                if t.id != targetTrack.id && !queuePool.contains(where: { $0.id == t.id }) {
                    queuePool.append(t)
                }
            }
        }

        player.play(track: targetTrack, from: queuePool, serverURL: serverURL)
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

    // MARK: - API Abruf
    private func loadHomeData() async {
        isLoading = true
        errorMessage = nil

        let token = SessionManager.shared.currentToken
        if let response = await MusicService.shared.fetchHomeDiscovery(serverURL: serverURL, token: token) {
            self.discovery = response
            self.isLoading = false
        } else {
            self.errorMessage = "Keine Verbindung zum Discovery-Dienst auf \(serverURL)."
            self.isLoading = false
        }
    }
}
