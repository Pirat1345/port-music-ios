import SwiftUI

// MARK: - Library Hub & Category Rows (Feature #12)
public struct LibraryView: View {
    public let serverURL: String
    public let user: UserProfile

    @ObservedObject private var player = AudioPlayerManager.shared

    @State private var favorites: [Track] = []
    @State private var playlists: [DiscoveryPlaylist] = []
    @State private var historyTracks: [Track] = []
    @State private var isLoading: Bool = false

    // Quick Tabs for Library Hub
    @State private var selectedTab: String = "Playlists"
    private let tabOptions = ["Playlists", "Songs", "Alben", "Verlauf"]

    public init(serverURL: String, user: UserProfile) {
        self.serverURL = serverURL
        self.user = user
    }

    private var isPlayingFavorites: Bool {
        guard let current = player.currentTrack else { return false }
        return player.isPlaying && favorites.contains(where: { $0.id == current.id })
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    // ── HEADER ──
                    libraryHeaderSection
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // ── HERO SHELF: LIEBLINGSSONGS & PLAYLISTS CAROUSEL ──
                    heroShelfSection

                    // ── CATEGORY NAVIGATION ROWS ──
                    categoryNavigationRows
                        .padding(.horizontal, 20)

                    // ── QUICK PREVIEW TABS SECTION ──
                    VStack(alignment: .leading, spacing: 14) {
                        segmentedTabBar
                            .padding(.horizontal, 20)

                        tabContentSection
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 8)

                    // Ausreichend Abstand am unteren Rand fuer MiniPlayer & TabBar
                    Spacer(minLength: 160)
                }
                .padding(.top, 6)
            }
            .refreshable {
                await loadLibraryData()
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle("Bibliothek")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .tint(.white)
        .task {
            await loadLibraryData()
        }
        .onAppear {
            Task {
                await loadLibraryData()
            }
        }
    }

    // MARK: - Header
    private var libraryHeaderSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bibliothek")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Text("Deine Musiksammlung, Favoriten und Playlists")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.65))
        }
    }

    // MARK: - Hero Shelf Section (Horizontal Carousel)
    private var heroShelfSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                // Lieblingssongs Gradient Hero Card -> navigates to LikedSongsView
                NavigationLink(value: AppRoute.likedSongs) {
                    likedSongsHeroCard
                }
                .buttonStyle(PlainButtonStyle())

                // Playlists Carousel Items -> navigate to PlaylistDetailView
                ForEach(playlists) { pl in
                    NavigationLink(value: AppRoute.playlist(id: pl.id, title: pl.title, coverUrl: pl.cover)) {
                        playlistHeroCard(playlist: pl)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Liked Songs Hero Card (1:1 Web PWA Parity)
    private var likedSongsHeroCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#450af5"), Color(hex: "#8e8ee5")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtiler Schattenverlauf unten
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.60)]),
                startPoint: .top,
                endPoint: .bottom
            )

            // Grosses Herz-Symbol im Hintergrund
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "heart.fill")
                        .font(.system(size: 52))
                        .foregroundColor(Color.white.opacity(0.22))
                        .padding(14)
                }
                Spacer()
            }

            // Text & Play-Button
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Lieblingssongs")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    Text("\(favorites.count) Songs")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.80))
                }

                Spacer()

                // Play / Pause Circle Button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    if isPlayingFavorites {
                        player.togglePlayPause()
                    } else if !favorites.isEmpty {
                        player.play(track: favorites[0], from: favorites)
                    }
                }) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: isPlayingFavorites ? "pause.fill" : "play.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                                .offset(x: isPlayingFavorites ? 0 : 1)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 6, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(14)
        }
        .frame(width: 175, height: 175)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 8, y: 3)
    }

    // MARK: - Playlist Hero Card
    private func playlistHeroCard(playlist: DiscoveryPlaylist) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "#18181b"))
                    .frame(width: 145, height: 145)

                let resolved = resolveCoverURL(playlist.cover, serverURL: serverURL)
                PortCachedAsyncImage(url: resolved) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 145, height: 145)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } placeholder: {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32))
                        .foregroundColor(Color.white.opacity(0.35))
                }

                // Subtiler Play Button
                Circle()
                    .fill(Color.black.opacity(0.65))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 1)
                    )
                    .padding(8)
            }
            .frame(width: 145, height: 145)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            Text(playlist.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: 145, alignment: .leading)

            let creator = playlist.user ?? "Port Music"
            Text(creator)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#a0a0a0"))
                .lineLimit(1)

            let countText = playlist.nbTracks.map { "\($0) Titel" } ?? "Playlist"
            Text(countText)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#a0a0a0"))
                .lineLimit(1)
        }
    }

    // MARK: - Category Navigation Rows (Feature #12)
    private var categoryNavigationRows: some View {
        VStack(spacing: 0) {
            categoryRowItem(title: "Wiedergabelisten", icon: "music.note.list", route: .libraryCategory(category: "playlists"))
            Divider().background(Color.white.opacity(0.08))

            categoryRowItem(title: "Künstler", icon: "person.2.fill", route: .libraryCategory(category: "artists"))
            Divider().background(Color.white.opacity(0.08))

            categoryRowItem(title: "Alben", icon: "square.stack.fill", route: .libraryCategory(category: "albums"))
            Divider().background(Color.white.opacity(0.08))

            categoryRowItem(title: "Titel", icon: "music.note", route: .libraryCategory(category: "songs"))
            Divider().background(Color.white.opacity(0.08))

            categoryRowItem(title: "Heruntergeladen", icon: "arrow.down.circle.fill", route: .libraryCategory(category: "downloaded"))
            Divider().background(Color.white.opacity(0.08))

            categoryRowItem(title: "Zuletzt gehört", icon: "clock.arrow.circlepath", route: .libraryCategory(category: "history"))
        }
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func categoryRowItem(title: String, icon: String, route: AppRoute) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: "#fc3c44"))
                    .frame(width: 28, alignment: .center)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Segmented Tab Bar
    private var segmentedTabBar: some View {
        HStack(spacing: 8) {
            ForEach(tabOptions, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    selectedTab = tab
                }) {
                    Text(tab)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .black : Color.white.opacity(0.80))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.white : Color.white.opacity(0.10))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.white : Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer()
        }
    }

    // MARK: - Tab Content Section
    @ViewBuilder
    private var tabContentSection: some View {
        switch selectedTab {
        case "Playlists":
            playlistsTabContent
        case "Songs":
            songsTabContent
        case "Alben":
            albumsTabContent
        case "Verlauf":
            historyTabContent
        default:
            EmptyView()
        }
    }

    // MARK: - Playlists Tab
    private var playlistsTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if playlists.isEmpty && !isLoading {
                emptyPlaceholder(icon: "music.note.list", message: "Noch keine Playlists vorhanden")
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 16
                ) {
                    ForEach(playlists) { pl in
                        NavigationLink(value: AppRoute.playlist(id: pl.id, title: pl.title, coverUrl: pl.cover)) {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: "#18181b"))
                                        .aspectRatio(1, contentMode: .fit)

                                    let resolved = resolveCoverURL(pl.cover, serverURL: serverURL)
                                    PortCachedAsyncImage(url: resolved) { img in
                                        img
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    } placeholder: {
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 32))
                                            .foregroundColor(Color.white.opacity(0.25))
                                    }
                                }
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )

                                Text(pl.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                let creator = pl.user ?? "Port Music"
                                Text(creator)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "#a0a0a0"))
                                    .lineLimit(1)

                                let count = pl.nbTracks.map { "\($0) Titel" } ?? "Playlist"
                                Text(count)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "#a0a0a0"))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Songs Tab (Lieblingssongs rendered via TrackRow)
    private var songsTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !favorites.isEmpty {
                HStack(spacing: 12) {
                    Button(action: {
                        player.play(track: favorites[0], from: favorites)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Alle abspielen")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        if !favorites.isEmpty {
                            player.isShuffle = true
                            let randomIdx = Int.random(in: 0..<favorites.count)
                            player.play(track: favorites[randomIdx], from: favorites)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Mischen")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if favorites.isEmpty && !isLoading {
                emptyPlaceholder(icon: "heart.slash", message: "Noch keine Lieblingssongs markiert")
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(Array(favorites.prefix(50).enumerated()), id: \.element.id) { index, track in
                        trackRowItem(track: track, index: index, contextQueue: favorites)
                    }
                }
            }
        }
    }

    // MARK: - Album Extraction (Feature #13)
    private func extractUniqueAlbums() -> [Track] {
        let allTracks = favorites + historyTracks + player.recentTracks
        var seenTitles = Set<String>()
        var uniqueAlbums: [Track] = []

        for t in allTracks {
            if let alb = t.album, !alb.isEmpty {
                let key = "\(alb.lowercased())_\(t.artist.lowercased())"
                if !seenTitles.contains(key) {
                    seenTitles.insert(key)
                    uniqueAlbums.append(t)
                }
            }
        }
        return uniqueAlbums
    }

    // MARK: - Albums Tab (Feature #13 Real Content)
    private var albumsTabContent: some View {
        let uniqueAlbums = extractUniqueAlbums()
        return VStack(alignment: .leading, spacing: 14) {
            if uniqueAlbums.isEmpty && !isLoading {
                emptyPlaceholder(icon: "square.stack", message: "Noch keine Alben in der Bibliothek")
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 16
                ) {
                    ForEach(uniqueAlbums) { album in
                        PortAlbumCard(
                            title: album.album ?? album.title,
                            subtitle: album.artist,
                            coverUrl: album.cover,
                            serverURL: serverURL,
                            isPlaying: player.currentTrack?.album == album.album && player.isPlaying
                        ) {
                            player.play(track: album, from: uniqueAlbums)
                        }
                    }
                }
            }
        }
    }

    // MARK: - History Tab
    private var historyTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            let tracks = !historyTracks.isEmpty ? historyTracks : player.recentTracks

            if tracks.isEmpty && !isLoading {
                emptyPlaceholder(icon: "clock.arrow.circlepath", message: "Bisher kein Wiedergabeverlauf vorhanden")
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(Array(tracks.prefix(25).enumerated()), id: \.element.id) { index, track in
                        trackRowItem(track: track, index: index, contextQueue: tracks)
                    }
                }
            }
        }
    }

    // MARK: - Mobile Track Row Component (Feature #16)
    @ViewBuilder
    private func trackRowItem(track: Track, index: Int, contextQueue: [Track]) -> some View {
        HStack(spacing: 12) {
            // Standardized 48x48 artwork with cache fallback & music.note icon
            ZStack {
                let resolved = resolveCoverURL(track.cover, serverURL: serverURL)
                PortCachedAsyncImage(url: resolved) { img in
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#1f1f23"))
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundColor(Color.white.opacity(0.40))
                    }
                    .frame(width: 48, height: 48)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Title & Artist truncated with lineLimit(1)
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#a0a0a0"))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            // Duration string
            Text(track.duration)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.45))

            // Heart favorite toggle with 44x44 touch frame
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                let wasFav = favorites.contains(where: { $0.id == track.id })
                if wasFav {
                    favorites.removeAll(where: { $0.id == track.id })
                    FavoritesManager.shared.setFavorite(trackId: track.id, isFavorite: false)
                } else {
                    favorites.append(track)
                    FavoritesManager.shared.setFavorite(trackId: track.id, isFavorite: true)
                }
                Task {
                    await MusicService.shared.toggleFavorite(track: track, serverURL: serverURL, token: SessionManager.shared.currentToken)
                    if let token = SessionManager.shared.currentToken {
                        let refreshed = await MusicService.shared.fetchFavorites(serverURL: serverURL, token: token)
                        await MainActor.run {
                            self.favorites = refreshed
                        }
                    }
                }
            }) {
                Image(systemName: favorites.contains(where: { $0.id == track.id }) ? "heart.fill" : "heart")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(favorites.contains(where: { $0.id == track.id }) ? Color(hex: "#fc3c44") : Color.white.opacity(0.40))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 56)
        .background(Color.white.opacity(player.currentTrack?.id == track.id ? 0.08 : 0.02))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture {
            player.play(track: track, from: contextQueue)
        }
    }

    // MARK: - Empty State Placeholder
    private func emptyPlaceholder(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(Color.white.opacity(0.30))
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.60))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    // MARK: - Data Loading
    private func loadLibraryData() async {
        isLoading = true
        let token = SessionManager.shared.currentToken

        async let favFetch = MusicService.shared.fetchFavorites(serverURL: serverURL, token: token)
        async let playFetch = MusicService.shared.fetchPlaylists(serverURL: serverURL, token: token)
        async let histFetch = MusicService.shared.fetchStatsAndHistory(serverURL: serverURL, token: token)

        let (favs, pls, hists) = await (favFetch, playFetch, histFetch)

        await MainActor.run {
            self.favorites = favs
            self.playlists = pls
            self.historyTracks = hists
            if !hists.isEmpty {
                player.mergeServerHistory(hists)
            }
            self.isLoading = false
        }
    }
}
