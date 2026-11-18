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

    public var body: some View {
        ZStack {
            // Reines Schwarz (#000000) wie auf der Webseite
            Color.black
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    // Header: Exakt wie im Web nur die Begruessung, kein Benutzername & kein Pill-Badge
                    topGreetingHeader
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
                        let deduplicated = deduplicateShelves(data: data, recentHistory: player.recentTracks)

                        // ── SHELF 1: TOP-PICKS FÜR DICH (3:4 Poster-Karten) ──
                        if !deduplicated.topPicks.isEmpty {
                            shelfTopPicks(picks: deduplicated.topPicks, allDiscovery: data)
                        }

                        // ── SHELF 2: ZULETZT GEHÖRT (Chronologischer Verlauf) ──
                        let displayRecent = !deduplicated.recentTracks.isEmpty ? deduplicated.recentTracks : player.recentTracks
                        if !displayRecent.isEmpty {
                            shelfRecentlyPlayed(tracks: displayRecent, allDiscovery: data)
                        }

                        // ── SHELF 3: FRISCH ERSCHIENEN (Release Radar) ──
                        if !deduplicated.releaseRadar.isEmpty {
                            shelfReleaseRadar(tracks: deduplicated.releaseRadar, allDiscovery: data)
                        }

                        // ── SHELF 4: FÜR DICH EMPFOHLEN ──
                        if !deduplicated.forYou.isEmpty {
                            shelfForYou(tracks: deduplicated.forYou, allDiscovery: data)
                        }

                        // ── SHELF 5: TRENDING ÜBERALL ──
                        if !deduplicated.trending.isEmpty {
                            shelfTrending(tracks: deduplicated.trending, allDiscovery: data)
                        }

                        // ── SHELF 6: NEUE ALBEN & EPS ──
                        if !deduplicated.topAlbums.isEmpty {
                            shelfAlbums(albums: deduplicated.topAlbums, allDiscovery: data)
                        }

                        // ── SHELF 7: FRISCHE SONG-DROPS ──
                        if !deduplicated.newMusicDrops.isEmpty {
                            shelfSongDrops(drops: deduplicated.newMusicDrops, allDiscovery: data)
                        }

                        // ── SHELF 8: TOP HITS HEUTE (1:1 mit Rang-Badges, ohne Duplikate aus Trending) ──
                        if !deduplicated.topHits.isEmpty {
                            shelfTopHits(tracks: deduplicated.topHits, allDiscovery: data)
                        }

                        // ── SHELF 9: TOP 100: GLOBAL (mit Rang-Badges) ──
                        if !deduplicated.top100.isEmpty {
                            shelfTop100Global(tracks: deduplicated.top100, allDiscovery: data)
                        }

                        // ── SHELF 10: TOP-PLAYLISTS ──
                        if !deduplicated.topPlaylists.isEmpty {
                            shelfTopPlaylists(playlists: deduplicated.topPlaylists, allDiscovery: data)
                        }

                        // ── SHELF 11: ANGESAGTE KÜNSTLER (Runde Avatare) ──
                        if !deduplicated.trendingArtists.isEmpty {
                            shelfTrendingArtists(artists: deduplicated.trendingArtists, allDiscovery: data)
                        }
                    }

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
                let token = SessionManager.shared.currentToken
                let historyRes = await MusicService.shared.fetchStatsAndHistory(serverURL: serverURL, token: token)
                if !historyRes.isEmpty {
                    player.mergeServerHistory(historyRes)
                }
            }
        }
    }

    // MARK: - Header (Exakt wie auf der Webseite: reine Begruessung)
    private var topGreetingHeader: some View {
        HStack {
            Text(greeting)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Shelf 1: Top-Picks für dich (3:4 Poster-Karten)
    private func shelfTopPicks(picks: [DiscoveryPosterPick], allDiscovery: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "sparkles",
                iconColor: .white,
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
                        serverURL: serverURL,
                        isPlaying: isCurrentPlaying
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
                onSeeAll: {}
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

    // MARK: - Shelf 3: Frisch erschienen (Release Radar)
    private func shelfReleaseRadar(tracks: [Track], allDiscovery: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "bolt.fill",
                iconColor: .white,
                title: "Frisch erschienen",
                subtitle: "Neue Veröffentlichungen & frische Entdeckungen"
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

    // MARK: - Shelf 4: Für dich empfohlen
    private func shelfForYou(tracks: [Track], allDiscovery: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "flame.fill",
                iconColor: .white,
                title: "Für dich empfohlen"
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

    // MARK: - Shelf 5: Trending überall
    private func shelfTrending(tracks: [Track], allDiscovery: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "chart.line.uptrend.xyaxis",
                iconColor: .white,
                title: "Trending überall",
                seeAllTitle: "Alle anzeigen",
                onSeeAll: {}
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

    // MARK: - Shelf 6: Neue Alben & EPs
    private func shelfAlbums(albums: [DiscoveryAlbum], allDiscovery: DiscoveryHomeResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PortShelfHeader(
                iconName: "square.stack.fill",
                iconColor: .white,
                title: "Neue Alben & EPs",
                subtitle: "Brandneue Veröffentlichungen der Woche"
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

    // MARK: - Shelf 7: Frische Song-Drops
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
                ForEach(drops.prefix(20)) { drop in
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
                                Task {
                                    if let detail = await MusicService.shared.fetchAlbum(id: drop.id, serverURL: serverURL, token: SessionManager.shared.currentToken) {
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

    // MARK: - Shelf 8: Top Hits heute (mit Rang-Badge)
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

    // MARK: - Shelf 9: Top 100: Global
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
                ForEach(Array(tracks.prefix(20).enumerated()), id: \.element.id) { index, item in
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

    // MARK: - Shelf 10: Top-Playlists
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
                ForEach(playlists) { playlist in
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

    // MARK: - Shelf 11: Angesagte Künstler
    private func shelfTrendingArtists(artists: [DiscoveryArtist], allDiscovery: DiscoveryHomeResponse) -> some View {
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

    // MARK: - Master Cross-Shelf Deduplication Pipeline (Exakt nach Vorbild aus Index.tsx)
    private struct DeduplicatedResult {
        let topPicks: [DiscoveryPosterPick]
        let recentTracks: [Track]
        let releaseRadar: [Track]
        let forYou: [Track]
        let trending: [Track]
        let topAlbums: [DiscoveryAlbum]
        let newMusicDrops: [DiscoveryAlbum]
        let topHits: [DiscoveryChartTrack]
        let top100: [DiscoveryChartTrack]
        let topPlaylists: [DiscoveryPlaylist]
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

        // 1. Top-Picks
        var dedupTopPicks: [DiscoveryPosterPick] = []
        for pick in data.topPicks ?? [] {
            if !isDuplicate(id: pick.id, title: pick.title, artist: pick.subtitle) {
                register(id: pick.id, title: pick.title, artist: pick.subtitle)
                dedupTopPicks.append(pick)
            }
        }

        // 2. Zuletzt gehört (Exakt wie Web PWA Index.tsx L1350: darf NIEMALS durch Top-Picks geleert werden!)
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

        // 3. Frisch erschienen (Release Radar aus newMusic)
        var dedupRadar: [Track] = []
        for album in data.newMusic ?? [] {
            let t = Track(id: album.id, title: album.title, artist: album.artist, album: album.title, coverUrl: album.cover)
            if !isDuplicate(id: t.id, title: t.title, artist: t.artist) {
                register(id: t.id, title: t.title, artist: t.artist)
                dedupRadar.append(t)
            }
        }

        // 4. Für dich empfohlen (kombiniert aus Top Hits & Trending, die nicht in Top-Picks waren)
        var dedupForYou: [Track] = []
        for item in data.todaysTopHits ?? [] {
            let t = item.toTrack()
            if !isDuplicate(id: t.id, title: t.title, artist: t.artist) {
                register(id: t.id, title: t.title, artist: t.artist)
                dedupForYou.append(t)
            }
        }

        // 5. Trending überall
        var dedupTrending: [Track] = []
        for item in data.trendingEverywhere ?? [] {
            let t = item.toTrack()
            if !isDuplicate(id: t.id, title: t.title, artist: t.artist) {
                register(id: t.id, title: t.title, artist: t.artist)
                dedupTrending.append(t)
            }
        }

        // 6. Neue Alben & EPs
        var dedupAlbums: [DiscoveryAlbum] = []
        for album in data.topAlbums ?? data.newMusic ?? [] {
            if !isDuplicate(id: album.id, title: album.title, artist: album.artist) {
                register(id: album.id, title: album.title, artist: album.artist)
                dedupAlbums.append(album)
            }
        }

        // 7. Frische Song-Drops
        var dedupDrops: [DiscoveryAlbum] = []
        for drop in data.newMusic ?? [] {
            if !isDuplicate(id: drop.id, title: drop.title, artist: drop.artist) {
                register(id: drop.id, title: drop.title, artist: drop.artist)
                dedupDrops.append(drop)
            }
        }

        // 8. Top Hits heute (Hier greift der Deduplizierungs-Filter, damit Titel aus Trending NICHT doppelt erscheinen)
        var dedupHits: [DiscoveryChartTrack] = []
        for item in data.todaysTopHits ?? [] {
            let t = item.toTrack()
            if !isDuplicate(id: t.id, title: t.title, artist: t.artist) {
                register(id: t.id, title: t.title, artist: t.artist)
                dedupHits.append(item)
            }
        }

        // 9. Top 100: Global
        var dedup100: [DiscoveryChartTrack] = []
        for item in data.top100Global ?? [] {
            let t = item.toTrack()
            if !isDuplicate(id: t.id, title: t.title, artist: t.artist) {
                register(id: t.id, title: t.title, artist: t.artist)
                dedup100.append(item)
            }
        }

        return DeduplicatedResult(
            topPicks: dedupTopPicks,
            recentTracks: dedupRecent,
            releaseRadar: dedupRadar,
            forYou: dedupForYou,
            trending: dedupTrending,
            topAlbums: dedupAlbums,
            newMusicDrops: dedupDrops,
            topHits: dedupHits,
            top100: dedup100,
            topPlaylists: data.topPlaylists ?? [],
            trendingArtists: data.trendingArtists ?? []
        )
    }

    // MARK: - Queue Seeding Helper (Feature #7: Dynamic Discovery Queue Pre-seeding)
    private func makeDiscoveryQueue(targetTrack: Track, discovery: DiscoveryHomeResponse) -> [Track] {
        var queue: [Track] = []
        var seenIds = Set<String>()

        seenIds.insert(targetTrack.id)
        queue.append(targetTrack)

        // 1. Top-Picks
        if let picks = discovery.topPicks {
            for p in picks {
                let t = p.toTrack()
                if !seenIds.contains(t.id) {
                    seenIds.insert(t.id)
                    queue.append(t)
                }
            }
        }
        // 2. Trending Überall
        if let trending = discovery.trendingEverywhere {
            for tr in trending {
                let t = tr.toTrack()
                if !seenIds.contains(t.id) {
                    seenIds.insert(t.id)
                    queue.append(t)
                }
            }
        }
        // 3. Top Hits Heute
        if let topHits = discovery.todaysTopHits {
            for ch in topHits {
                let t = ch.toTrack()
                if !seenIds.contains(t.id) {
                    seenIds.insert(t.id)
                    queue.append(t)
                }
            }
        }
        // 4. Release Radar / New Music
        if let newMusic = discovery.newMusic {
            for nm in newMusic {
                let t = Track(id: nm.id, title: nm.title, artist: nm.artist, album: nm.title, coverUrl: nm.cover)
                if !seenIds.contains(t.id) {
                    seenIds.insert(t.id)
                    queue.append(t)
                }
            }
        }
        // 5. Top 100 Global
        if let top100 = discovery.top100Global {
            for ch in top100 {
                let t = ch.toTrack()
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

    // MARK: - API Abruf
    private func loadHomeData() async {
        isLoading = true
        errorMessage = nil

        let token = SessionManager.shared.currentToken

        // Discovery & Verlauf (Multi-Device Stats + DB History) parallel abrufen
        async let discoveryFetch = MusicService.shared.fetchHomeDiscovery(serverURL: serverURL, token: token)
        async let historyFetch = MusicService.shared.fetchStatsAndHistory(serverURL: serverURL, token: token)

        let (discoveryRes, historyRes) = await (discoveryFetch, historyFetch)

        if !historyRes.isEmpty {
            player.mergeServerHistory(historyRes)
        }

        if let response = discoveryRes {
            self.discovery = response
            self.isLoading = false
            prefetchHomeCovers(from: response)
        } else {
            self.errorMessage = "Keine Verbindung zum Discovery-Dienst auf \(serverURL)."
            self.isLoading = false
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

        let resolved = rawUrls.compactMap { resolveCoverURL($0, serverURL: serverURL) }
        PortImageCache.shared.prefetch(urls: resolved)
    }
}
