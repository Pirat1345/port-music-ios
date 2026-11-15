import SwiftUI

public struct LibraryView: View {
    public let serverURL: String
    public let user: UserProfile

    @ObservedObject private var player = AudioPlayerManager.shared

    @State private var selectedTab: String = "Playlists"
    private let tabOptions = ["Playlists", "Songs", "Alben", "Verlauf"]

    @State private var favorites: [Track] = []
    @State private var playlists: [DiscoveryPlaylist] = []
    @State private var historyTracks: [Track] = []
    @State private var isLoading: Bool = false

    public init(serverURL: String, user: UserProfile) {
        self.serverURL = serverURL
        self.user = user
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    // Header
                    libraryHeaderSection
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // Hero-Bereich: Lieblingssongs & Playlists-Karussell
                    heroShelfSection

                    // Segmentierte Tabs
                    segmentedTabBar
                        .padding(.horizontal, 20)

                    // Tab-Inhalt
                    tabContentSection
                        .padding(.horizontal, 20)

                    // Ausreichend Abstand am unteren Rand fuer MiniPlayer & TabBar
                    Spacer(minLength: 120)
                }
                .padding(.top, 6)
            }
            .refreshable {
                await loadLibraryData()
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .task {
            if favorites.isEmpty && playlists.isEmpty {
                await loadLibraryData()
            }
        }
    }

    // MARK: - Header
    private var libraryHeaderSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bibliothek")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(PortColors.textPrimary)

            Text("Deine Musiksammlung, Favoriten und Playlists")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.65))
        }
    }

    // MARK: - Hero Shelf Section
    private var heroShelfSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                // Lieblingssongs Gradient Hero Card
                likedSongsHeroCard

                // Playlists Carousel Items
                ForEach(playlists) { pl in
                    playlistHeroCard(playlist: pl)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Liked Songs Hero Card (1:1 wie Web PWA)
    private var likedSongsHeroCard: some View {
        Button(action: {
            if !favorites.isEmpty {
                player.play(track: favorites[0], from: favorites, serverURL: serverURL)
            }
        }) {
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

                        Text("\(favorites.count) Titel")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.80))
                    }

                    Spacer()

                    Circle()
                        .fill(Color.white)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                                .offset(x: 1)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 6, y: 2)
                }
                .padding(14)
            }
            .frame(width: 175, height: 175)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 8, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Playlist Hero Card
    private func playlistHeroCard(playlist: DiscoveryPlaylist) -> some View {
        Button(action: {
            let t = Track(
                id: "pl_\(playlist.id)",
                title: playlist.title,
                artist: playlist.user ?? "Port Music",
                album: "Playlist",
                coverUrl: playlist.cover
            )
            player.play(track: t, from: [t], serverURL: serverURL)
        }) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.08))
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
                }
                .frame(width: 145, height: 145)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

                Text(playlist.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(PortColors.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: 145, alignment: .leading)

                let countText = playlist.nbTracks.map { "\($0) Songs" } ?? "Playlist"
                Text(countText)
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.60))
                    .lineLimit(1)
            }
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
                        PortTrackCard(
                            title: pl.title,
                            subtitle: pl.user ?? (pl.nbTracks.map { "\($0) Songs" } ?? "Playlist"),
                            coverUrl: pl.cover,
                            serverURL: serverURL
                        ) {
                            let t = Track(
                                id: "pl_\(pl.id)",
                                title: pl.title,
                                artist: pl.user ?? "Port Music",
                                album: "Playlist",
                                coverUrl: pl.cover
                            )
                            player.play(track: t, from: [t], serverURL: serverURL)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Songs Tab (Lieblingssongs)
    private var songsTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !favorites.isEmpty {
                HStack(spacing: 12) {
                    Button(action: {
                        player.play(track: favorites[0], from: favorites, serverURL: serverURL)
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
                        player.isShuffle = true
                        let randomIdx = Int.random(in: 0..<favorites.count)
                        player.play(track: favorites[randomIdx], from: favorites, serverURL: serverURL)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Zufallswiedergabe")
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
                LazyVStack(spacing: 8) {
                    ForEach(favorites) { track in
                        trackRowItem(track: track, fullQueue: favorites)
                    }
                }
            }
        }
    }

    // MARK: - Albums Tab
    private var albumsTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Extrahierte Alben aus Favoriten und Verlauf
            let uniqueAlbums = extractUniqueAlbums()

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
                            title: album.title,
                            subtitle: album.artist,
                            coverUrl: album.coverUrl,
                            serverURL: serverURL
                        ) {
                            player.play(track: album, from: uniqueAlbums, serverURL: serverURL)
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
                LazyVStack(spacing: 8) {
                    ForEach(tracks) { track in
                        trackRowItem(track: track, fullQueue: tracks)
                    }
                }
            }
        }
    }

    // MARK: - Track Row Item
    private func trackRowItem(track: Track, fullQueue: [Track]) -> some View {
        Button(action: {
            player.play(track: track, from: fullQueue, serverURL: serverURL)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 48, height: 48)

                    let resolved = resolveCoverURL(track.coverUrl, serverURL: serverURL)
                    PortCachedAsyncImage(url: resolved) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: {
                        Image(systemName: "music.note")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.50))
                    }
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PortColors.textPrimary)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer()

                Text(track.duration)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.50))
            }
            .padding(10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
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

    // MARK: - Helper: Extract Unique Albums from Saved Tracks
    private func extractUniqueAlbums() -> [Track] {
        var seen = Set<String>()
        var albums: [Track] = []
        for t in (favorites + historyTracks + player.recentTracks) {
            if let alb = t.album, !alb.isEmpty, !seen.contains(alb) {
                seen.insert(alb)
                albums.append(t)
            }
        }
        return albums
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
