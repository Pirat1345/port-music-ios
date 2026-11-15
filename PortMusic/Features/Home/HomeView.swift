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
                    // Octave Top Header: Greeting
                    topGreetingHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    if isLoading && discovery == nil {
                        loadingSkeletonView
                            .padding(.top, 40)
                    } else if let error = errorMessage, discovery == nil {
                        errorStateView(error)
                    } else if let data = discovery {
                        // ── SHELF 1: TOP-PICKS FÜR DICH (3:4 Poster Cards wie im Web) ──
                        if let topPicks = data.topPicks, !topPicks.isEmpty {
                            shelfTopPicks(picks: topPicks, allTrending: data.trendingEverywhere ?? [])
                        }

                        // ── SHELF 2: TRENDING ÜBERALL (Standard 1:1 Cards) ──
                        if let trending = data.trendingEverywhere, !trending.isEmpty {
                            shelfTrending(tracks: trending)
                        }

                        // ── SHELF 3: TOP HITS HEUTE (1:1 Cards mit Rang-Badge) ──
                        if let topHits = data.todaysTopHits, !topHits.isEmpty {
                            shelfTopHits(tracks: topHits)
                        }

                        // ── SHELF 4: NEUE ALBEN & EPS ──
                        if let albums = data.topAlbums ?? data.newMusic, !albums.isEmpty {
                            shelfAlbums(albums: albums)
                        }

                        // ── SHELF 5: FRISCHE SONG-DROPS ──
                        if let drops = data.newMusic, !drops.isEmpty {
                            shelfSongDrops(drops: drops)
                        }

                        // ── SHELF 6: ANGESAGTE KÜNSTLER (Runde Porträts) ──
                        if let artists = data.trendingArtists, !artists.isEmpty {
                            shelfTrendingArtists(artists: artists)
                        }
                    }

                    // Abstand am unteren Rand, damit der schwebende MiniPlayer nichts verdeckt
                    Spacer(minLength: 110)
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

    // MARK: - Greeting Header
    private var topGreetingHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(PortColors.textPrimary)

                Text(user.username)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.60))
            }

            Spacer()

            // Status-Pill
            HStack(spacing: 6) {
                Circle()
                    .fill(PortColors.successGreen)
                    .frame(width: 7, height: 7)

                Text("Online")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(PortColors.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(PortColors.surfaceGlass)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(PortColors.borderGlass, lineWidth: 1)
            )
        }
    }

    // MARK: - Shelf 1: Top-Picks für dich (3:4 Poster Card)
    private func shelfTopPicks(picks: [DiscoveryPosterPick], allTrending: [DiscoveryTrack]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            shelfHeader(
                icon: "sparkles",
                title: "Top-Picks für dich",
                subtitle: "Favoriten, Neuheiten und Empfehlungen"
            )
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(picks) { pick in
                        let isItemPlaying = (player.currentTrack?.title.lowercased() == pick.title.lowercased() && player.isPlaying)
                        posterCard(pick: pick, isPlaying: isItemPlaying, allTrending: allTrending)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func posterCard(pick: DiscoveryPosterPick, isPlaying: Bool, allTrending: [DiscoveryTrack]) -> some View {
        Button(action: {
            playPosterPick(pick, allTrending: allTrending)
        }) {
            ZStack(alignment: .bottomLeading) {
                // Cover Artwork (3:4 Aspect)
                ZStack {
                    Color(hex: "#1a1a1c")

                    if let url = URL(string: pick.cover) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 165, height: 220)
                                    .clipped()
                            default:
                                Image(systemName: "music.note")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color.white.opacity(0.3))
                            }
                        }
                    }
                }
                .frame(width: 165, height: 220)

                // Verlauf nach unten
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.40), Color.black.opacity(0.90)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // Text & Play-Button
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pick.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .shadow(color: .black.opacity(0.8), radius: 2)

                        Text(pick.subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.70))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    // Play Button
                    ZStack {
                        Circle()
                            .fill(PortColors.accentOrange)
                            .frame(width: 36, height: 36)
                            .shadow(color: PortColors.accentOrange.opacity(0.4), radius: 6, y: 2)

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .offset(x: isPlaying ? 0 : 1)
                    }
                }
                .padding(12)
            }
            .frame(width: 165, height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.40), radius: 10, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Shelf 2: Trending überall (Standard 1:1 Card)
    private func shelfTrending(tracks: [DiscoveryTrack]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            shelfHeader(
                icon: "chart.line.uptrend.xyaxis",
                title: "Trending überall",
                subtitle: "Weltweit am meisten gehört"
            )
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(tracks) { item in
                        let track = item.toTrack()
                        let isItemPlaying = (player.currentTrack?.id == track.id && player.isPlaying)
                        standardCard(
                            title: track.title,
                            subtitle: track.artist,
                            coverUrl: track.coverUrl,
                            rank: nil,
                            isPlaying: isItemPlaying,
                            onPlay: {
                                let queue = tracks.map { $0.toTrack() }
                                player.play(track: track, from: queue, serverURL: serverURL)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Shelf 3: Top Hits heute (mit Rang-Badge)
    private func shelfTopHits(tracks: [DiscoveryChartTrack]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            shelfHeader(
                icon: "flame.fill",
                title: "Top Hits heute",
                subtitle: "Die aktuellen Chartstürmer"
            )
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(tracks) { item in
                        let track = item.toTrack()
                        let isItemPlaying = (player.currentTrack?.id == track.id && player.isPlaying)
                        standardCard(
                            title: track.title,
                            subtitle: track.artist,
                            coverUrl: track.coverUrl,
                            rank: item.rank,
                            isPlaying: isItemPlaying,
                            onPlay: {
                                let queue = tracks.map { $0.toTrack() }
                                player.play(track: track, from: queue, serverURL: serverURL)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Shelf 4: Neue Alben & EPs
    private func shelfAlbums(albums: [DiscoveryAlbum]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            shelfHeader(
                icon: "square.stack.fill",
                title: "Neue Alben & EPs",
                subtitle: "Brandneue Alben & Veröffentlichungen der Woche"
            )
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(albums) { album in
                        standardCard(
                            title: album.title,
                            subtitle: album.artist,
                            coverUrl: album.cover,
                            rank: nil,
                            isPlaying: false,
                            onPlay: {
                                let track = Track(
                                    id: album.id,
                                    title: album.title,
                                    artist: album.artist,
                                    album: album.title,
                                    duration: "0:00",
                                    durationSeconds: 0,
                                    coverUrl: album.cover
                                )
                                player.play(track: track, from: [track], serverURL: serverURL)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Shelf 5: Frische Song-Drops
    private func shelfSongDrops(drops: [DiscoveryAlbum]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            shelfHeader(
                icon: "sparkles",
                title: "Frische Song-Drops",
                subtitle: "Tagesaktuelle Hits & Drops, handverlesen"
            )
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(drops.reversed()) { drop in
                        standardCard(
                            title: drop.title,
                            subtitle: drop.artist,
                            coverUrl: drop.cover,
                            rank: nil,
                            isPlaying: false,
                            onPlay: {
                                let track = Track(
                                    id: drop.id,
                                    title: drop.title,
                                    artist: drop.artist,
                                    album: drop.title,
                                    duration: "0:00",
                                    durationSeconds: 0,
                                    coverUrl: drop.cover
                                )
                                player.play(track: track, from: [track], serverURL: serverURL)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Shelf 6: Angesagte Künstler
    private func shelfTrendingArtists(artists: [DiscoveryArtist]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            shelfHeader(
                icon: "person.2.fill",
                title: "Angesagte Künstler",
                subtitle: "Aktuell am meisten gestreamt"
            )
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(artists) { artist in
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(PortColors.surfaceGlassStrong)
                                    .frame(width: 90, height: 90)

                                if let pic = artist.picture, let url = URL(string: pic) {
                                    AsyncImage(url: url) { phase in
                                        if case .success(let image) = phase {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 90, height: 90)
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                            }
                            .frame(width: 90, height: 90)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 6, y: 3)

                            Text(artist.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(PortColors.textPrimary)
                                .lineLimit(1)
                                .frame(width: 96)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Standard 1:1 Card (wie OctaveStandardCard)
    private func standardCard(
        title: String,
        subtitle: String,
        coverUrl: String?,
        rank: Int?,
        isPlaying: Bool,
        onPlay: @escaping () -> Void
    ) -> some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 8) {
                // Cover-Box (145x145)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "#181818"))
                        .frame(width: 145, height: 145)

                    if let cover = coverUrl, let url = URL(string: cover) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 145, height: 145)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            default:
                                Image(systemName: "music.note")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color.white.opacity(0.25))
                            }
                        }
                    }

                    // Rank-Badge (falls vorhanden)
                    if let r = rank {
                        Text("\(r)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.75))
                            .clipShape(Capsule())
                            .padding(8)
                    }

                    // Floating Play Button (unten rechts)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(PortColors.accentOrange)
                                    .frame(width: 38, height: 38)
                                    .shadow(color: PortColors.accentOrange.opacity(0.4), radius: 6, y: 2)

                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.black)
                                    .offset(x: isPlaying ? 0 : 1)
                            }
                            .padding(8)
                        }
                    }
                }
                .frame(width: 145, height: 145)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 8, y: 3)

                // Titel & Interpret
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(PortColors.textPrimary)
                        .lineLimit(1)
                        .frame(width: 145, alignment: .leading)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(hex: "#a0a0a0"))
                        .lineLimit(1)
                        .frame(width: 145, alignment: .leading)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Sektions Header (Octave Stil)
    private func shelfHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(PortColors.accentOrange)

                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(PortColors.textPrimary)
            }

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#a0a0a0"))
        }
    }

    // MARK: - Aktionen
    private func playPosterPick(_ pick: DiscoveryPosterPick, allTrending: [DiscoveryTrack]) {
        let heroTrack = pick.toTrack()
        let fullQueue = [heroTrack] + allTrending.map { $0.toTrack() }
        player.play(track: heroTrack, from: fullQueue, serverURL: serverURL)
    }

    // MARK: - Lade- & Fehleranzeige
    private var loadingSkeletonView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            Text("Entdeckungen werden geladen...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(PortColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func errorStateView(_ msg: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 32))
                .foregroundColor(PortColors.errorRed)

            Text(msg)
                .font(.system(size: 14))
                .foregroundColor(PortColors.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: {
                Task { await loadHomeData() }
            }) {
                Text("Erneut versuchen")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(PortColors.surfaceGlass)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 40)
    }

    private func loadHomeData() async {
        isLoading = true
        errorMessage = nil

        let token = SessionManager.shared.currentToken
        let res = await MusicService.shared.fetchHomeDiscovery(serverURL: serverURL, token: token)

        await MainActor.run {
            self.isLoading = false
            if let data = res {
                self.discovery = data
            } else {
                self.errorMessage = "Startseite konnte nicht geladen werden. Bitte Netzwerkverbindung prüfen."
            }
        }
    }
}
