import SwiftUI

public struct SearchBrowseCategory: Identifiable {
    public let id = UUID()
    public let name: String
    public let gradient: [Color]
    public let iconName: String
    public let artworkUrl: String?

    public init(name: String, gradient: [Color], iconName: String, artworkUrl: String? = nil) {
        self.name = name
        self.gradient = gradient
        self.iconName = iconName
        self.artworkUrl = artworkUrl
    }
}

public struct SearchView: View {
    public let serverURL: String

    @ObservedObject private var player = AudioPlayerManager.shared
    @State private var searchQuery: String = ""
    @State private var searchTask: Task<Void, Never>? = nil

    @State private var isSearching: Bool = false
    @State private var searchResponse: DiscoverySearchResponse? = nil
    @State private var fallbackTracks: [Track] = []
    @State private var hasSearched: Bool = false

    @State private var selectedFilter: String = "Top-Treffer"
    private let filterOptions = ["Top-Treffer", "Songs", "Künstler", "Alben", "Playlists"]

    @State private var recentSearches: [String] = []

    private let browseCategories: [SearchBrowseCategory] = [
        SearchBrowseCategory(name: "Hits", gradient: [Color(hex: "#2c2a38"), Color(hex: "#1e1d24")], iconName: "chart.bar.fill", artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/2e/18/a3/2e18a394-f9b2-1079-8d42-ccfa6d51d20d/88823a4b-bcc9-40c9-be1e-5671776d8837.png/600x600sr.jpg"),
        SearchBrowseCategory(name: "Deutschrap", gradient: [Color(hex: "#1e293b"), Color(hex: "#0f172a")], iconName: "headphones", artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/3f/39/61/3f3961dd-2eea-eb27-a7f2-4b799218f227/313a61ae-8a20-4faf-9a5f-ede8bc713069.png/600x600sr.jpg"),
        SearchBrowseCategory(name: "Pop", gradient: [Color(hex: "#3b1e38"), Color(hex: "#221124")], iconName: "music.mic", artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/16/e0/d7/16e0d799-dd77-b8e1-cce3-f27f7664ead6/80e1dd92-de5f-424f-8e76-2144694ad6f3.png/600x600sr.jpg"),
        SearchBrowseCategory(name: "Rock", gradient: [Color(hex: "#381e1e"), Color(hex: "#200e0e")], iconName: "guitars.fill", artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/b6/13/a6/b613a6a2-0c03-cdb5-eef6-3f104e50ce86/aa8d0f82-c0d4-4a07-aae8-16f1db32c703.png/600x600sr.jpg"),
        SearchBrowseCategory(name: "Dance & Electro", gradient: [Color(hex: "#102c38"), Color(hex: "#09171f")], iconName: "bolt.fill", artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features221/v4/62/61/c4/6261c465-fe72-eb32-5687-b7c015064b39/77b7bb43-5e28-4c40-afbc-97904ab8636a.png/600x600sr.jpg"),
        SearchBrowseCategory(name: "Chillen", gradient: [Color(hex: "#1c2e2c"), Color(hex: "#0e1817")], iconName: "moon.fill", artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features221/v4/0f/17/d5/0f17d5a3-6774-1ae1-4530-2b694d8fb6bf/d7944211-2928-4ccc-b382-f0564bcf00b2.png/600x600sr.jpg"),
        SearchBrowseCategory(name: "Deutschpop", gradient: [Color(hex: "#381c2a"), Color(hex: "#1f0f18")], iconName: "sparkles", artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Features/v4/48/a5/67/48a5677e-f0d2-cf36-2479-03c240f98fe8/9cee0055-90a3-4814-a7e7-1a46041a2d78.png/600x600sr.jpg"),
        SearchBrowseCategory(name: "R&B & Soul", gradient: [Color(hex: "#281e3a"), Color(hex: "#160f22")], iconName: "heart.fill", artworkUrl: nil),
        SearchBrowseCategory(name: "Indie & Alt", gradient: [Color(hex: "#173022"), Color(hex: "#0a1710")], iconName: "leaf.fill", artworkUrl: nil),
        SearchBrowseCategory(name: "Fitness & Workout", gradient: [Color(hex: "#381a1a"), Color(hex: "#1f0c0c")], iconName: "flame.fill", artworkUrl: nil)
    ]

    public init(serverURL: String) {
        self.serverURL = serverURL
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header & Suchleiste
                searchHeaderSection
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                if !searchQuery.isEmpty && hasSearched {
                    // Filter-Pills
                    filterPillsSection
                        .padding(.bottom, 12)
                }

                // Hauptbereich
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        if isSearching && searchResponse == nil && fallbackTracks.isEmpty {
                            loadingView
                        } else if hasSearched && isEmptyResults {
                            emptyResultsView
                        } else if !searchQuery.isEmpty && hasSearched {
                            activeResultsView
                        } else {
                            idleDiscoverView
                        }

                        // Abstand fuer MiniPlayer & TabBar
                        Spacer(minLength: 120)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .onAppear {
            loadRecentSearches()
        }
    }

    private var isEmptyResults: Bool {
        let hasTracks = !(searchResponse?.tracks?.isEmpty ?? true) || !fallbackTracks.isEmpty
        let hasAlbums = !(searchResponse?.albums?.isEmpty ?? true)
        let hasArtists = !(searchResponse?.artists?.isEmpty ?? true)
        let hasPlaylists = !(searchResponse?.playlists?.isEmpty ?? true)
        return !hasTracks && !hasAlbums && !hasArtists && !hasPlaylists
    }

    // MARK: - Suchleiste
    private var searchHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suche")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(PortColors.textPrimary)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.60))

                TextField(
                    "",
                    text: $searchQuery,
                    prompt: Text("Songs, Alben oder Künstler...")
                        .foregroundColor(Color.white.opacity(0.45))
                )
                .font(.system(size: 15))
                .foregroundColor(PortColors.textPrimary)
                .tint(.white)
                .accentColor(.white)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .onChange(of: searchQuery) { newValue in
                    scheduleDebouncedSearch(query: newValue)
                }
                .onSubmit {
                    submitSearch(query: searchQuery)
                }

                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        searchResponse = nil
                        fallbackTracks = []
                        hasSearched = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.white.opacity(0.60))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
        }
    }

    // MARK: - Filter-Pills
    private var filterPillsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filterOptions, id: \.self) { filter in
                    let isSelected = selectedFilter == filter
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        selectedFilter = filter
                    }) {
                        Text(filter)
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
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Idle State (Recent Searches & Browse Categories)
    private var idleDiscoverView: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Zuletzt gesucht
            if !recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Zuletzt gesucht")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(PortColors.textPrimary)

                        Spacer()

                        Button(action: {
                            clearAllRecentSearches()
                        }) {
                            Text("Löschen")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.60))
                        }
                    }
                    .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recentSearches, id: \.self) { query in
                                HStack(spacing: 6) {
                                    Button(action: {
                                        searchQuery = query
                                        submitSearch(query: query)
                                    }) {
                                        Text(query)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white)
                                    }

                                    Button(action: {
                                        removeRecentSearch(query)
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(Color.white.opacity(0.50))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.09))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }

            // Kategorien entdecken
            VStack(alignment: .leading, spacing: 14) {
                Text("Kategorien entdecken")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(PortColors.textPrimary)
                    .padding(.horizontal, 20)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(browseCategories) { cat in
                        Button(action: {
                            searchQuery = cat.name
                            submitSearch(query: cat.name)
                        }) {
                            ZStack(alignment: .bottomLeading) {
                                LinearGradient(
                                    gradient: Gradient(colors: cat.gradient),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .opacity(0.85)

                                if let art = cat.artworkUrl, let url = URL(string: art) {
                                    HStack {
                                        Spacer()
                                        PortCachedAsyncImage(url: url) { img in
                                            img
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 64, height: 64)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .rotationEffect(.degrees(14))
                                                .offset(x: 10, y: 10)
                                                .shadow(color: Color.black.opacity(0.4), radius: 5, x: -2, y: 2)
                                        } placeholder: {
                                            EmptyView()
                                        }
                                    }
                                } else {
                                    HStack {
                                        Spacer()
                                        VStack {
                                            Image(systemName: cat.iconName)
                                                .font(.system(size: 32, weight: .bold))
                                                .foregroundColor(Color.white.opacity(0.25))
                                                .padding(12)
                                            Spacer()
                                        }
                                    }
                                }

                                LinearGradient(
                                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.65)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )

                                Text(cat.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(14)
                            }
                            .frame(height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 6, y: 3)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Active Search Results
    private var activeResultsView: some View {
        VStack(alignment: .leading, spacing: 24) {
            let tracks = (searchResponse?.tracks?.map { $0.toTrack() } ?? []) + fallbackTracks
            let artists = searchResponse?.artists ?? []
            let albums = searchResponse?.albums ?? []
            let playlists = searchResponse?.playlists ?? []

            if selectedFilter == "Top-Treffer" {
                // Top Result Hero Card
                topResultHeroCard(tracks: tracks, artists: artists)

                // Songs Section
                if !tracks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Songs")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(PortColors.textPrimary)
                            .padding(.horizontal, 20)

                        VStack(spacing: 6) {
                            ForEach(Array(tracks.prefix(5))) { track in
                                searchTrackRow(track: track, fullQueue: tracks)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Künstler Shelf
                if !artists.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Künstler")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(PortColors.textPrimary)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(artists) { artist in
                                    NavigationLink(value: AppRoute.artist(name: artist.name, coverUrl: artist.picture)) {
                                        PortArtistCard(artist: artist, serverURL: serverURL) {
                                            let artistTrack = Track(
                                                id: "artist_\(artist.id)",
                                                title: artist.name,
                                                artist: artist.name,
                                                coverUrl: artist.picture
                                            )
                                            player.play(track: artistTrack, from: [artistTrack], serverURL: serverURL)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                // Alben Shelf
                if !albums.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Alben")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(PortColors.textPrimary)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(albums) { album in
                                    NavigationLink(value: AppRoute.album(id: album.id, title: album.title, artist: album.artist, coverUrl: album.cover)) {
                                        PortAlbumCard(
                                            title: album.title,
                                            subtitle: album.artist,
                                            coverUrl: album.cover,
                                            serverURL: serverURL
                                        ) {
                                            let albumTrack = Track(
                                                id: "album_\(album.id)",
                                                title: album.title,
                                                artist: album.artist,
                                                album: album.title,
                                                coverUrl: album.cover
                                            )
                                            player.play(track: albumTrack, from: [albumTrack], serverURL: serverURL)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                // Playlists Shelf
                if !playlists.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Playlists")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(PortColors.textPrimary)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(playlists) { playlist in
                                    let sub = playlist.user ?? (playlist.nbTracks.map { "\($0) Songs" } ?? "Playlist")
                                    PortTrackCard(
                                        title: playlist.title,
                                        subtitle: sub,
                                        coverUrl: playlist.cover,
                                        serverURL: serverURL
                                    ) {
                                        let playlistTrack = Track(
                                            id: "pl_\(playlist.id)",
                                            title: playlist.title,
                                            artist: playlist.user ?? "Port Music",
                                            album: "Playlist",
                                            coverUrl: playlist.cover
                                        )
                                        player.play(track: playlistTrack, from: [playlistTrack], serverURL: serverURL)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            } else if selectedFilter == "Songs" {
                VStack(spacing: 8) {
                    ForEach(tracks) { track in
                        searchTrackRow(track: track, fullQueue: tracks)
                    }
                }
                .padding(.horizontal, 20)
            } else if selectedFilter == "Künstler" {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(artists) { artist in
                        NavigationLink(value: AppRoute.artist(name: artist.name, coverUrl: artist.picture)) {
                            PortArtistCard(artist: artist, serverURL: serverURL) {
                                let artistTrack = Track(
                                    id: "artist_\(artist.id)",
                                    title: artist.name,
                                    artist: artist.name,
                                    coverUrl: artist.picture
                                )
                                player.play(track: artistTrack, from: [artistTrack], serverURL: serverURL)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            } else if selectedFilter == "Alben" {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(albums) { album in
                        NavigationLink(value: AppRoute.album(id: album.id, title: album.title, artist: album.artist, coverUrl: album.cover)) {
                            PortAlbumCard(
                                title: album.title,
                                subtitle: album.artist,
                                coverUrl: album.cover,
                                serverURL: serverURL
                            ) {
                                let albumTrack = Track(
                                    id: "album_\(album.id)",
                                    title: album.title,
                                    artist: album.artist,
                                    album: album.title,
                                    coverUrl: album.cover
                                )
                                player.play(track: albumTrack, from: [albumTrack], serverURL: serverURL)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            } else if selectedFilter == "Playlists" {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(playlists) { playlist in
                        let sub = playlist.user ?? (playlist.nbTracks.map { "\($0) Songs" } ?? "Playlist")
                        PortTrackCard(
                            title: playlist.title,
                            subtitle: sub,
                            coverUrl: playlist.cover,
                            serverURL: serverURL
                        ) {
                            let playlistTrack = Track(
                                id: "pl_\(playlist.id)",
                                title: playlist.title,
                                artist: playlist.user ?? "Port Music",
                                album: "Playlist",
                                coverUrl: playlist.cover
                            )
                            player.play(track: playlistTrack, from: [playlistTrack], serverURL: serverURL)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Top Result Hero Card
    @ViewBuilder
    private func topResultHeroCard(tracks: [Track], artists: [DiscoveryArtist]) -> some View {
        if let topArtist = artists.first, searchQuery.lowercased().contains(topArtist.name.lowercased()) || topArtist.name.lowercased().contains(searchQuery.lowercased()) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Bester Treffer")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(PortColors.textPrimary)
                    .padding(.horizontal, 20)

                NavigationLink(value: AppRoute.artist(name: topArtist.name, coverUrl: topArtist.picture)) {
                    HStack(spacing: 16) {
                        let resolved = resolveCoverURL(topArtist.picture, serverURL: serverURL)
                        PortCachedAsyncImage(url: resolved) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 80, height: 80)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(topArtist.name)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text("Künstler")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.60))

                            if let fans = topArtist.nbFan {
                                Text("\(fans) Fans")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.white.opacity(0.45))
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.35))
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20)
            }
        } else if let topTrack = tracks.first {
            VStack(alignment: .leading, spacing: 10) {
                Text("Bester Treffer")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(PortColors.textPrimary)
                    .padding(.horizontal, 20)

                Button(action: {
                    player.play(track: topTrack, from: tracks, serverURL: serverURL)
                }) {
                    HStack(spacing: 16) {
                        let resolved = resolveCoverURL(topTrack.coverUrl, serverURL: serverURL)
                        PortCachedAsyncImage(url: resolved) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 84, height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 84, height: 84)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text(topTrack.title)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text(topTrack.artist)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.70))
                                .lineLimit(1)

                            Text("Song")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }

                        Spacer()

                        Circle()
                            .fill(Color.white)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                                    .offset(x: 1)
                            )
                            .shadow(color: Color.black.opacity(0.4), radius: 6, y: 2)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Search Track Row
    private func searchTrackRow(track: Track, fullQueue: [Track]) -> some View {
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

    // MARK: - Status Views
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.1)
            Text("Suche läuft...")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var emptyResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 38))
                .foregroundColor(Color.white.opacity(0.35))
            Text("Keine Treffer für \"\(searchQuery)\"")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(PortColors.textPrimary)
            Text("Überprüfe die Schreibweise oder suche nach einem anderen Begriff.")
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.60))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Search Operations
    private func scheduleDebouncedSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResponse = nil
            fallbackTracks = []
            hasSearched = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if !Task.isCancelled {
                await executeSearch(query: trimmed, saveHistory: false)
            }
        }
    }

    private func submitSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            await executeSearch(query: trimmed, saveHistory: true)
        }
    }

    private func executeSearch(query: String, saveHistory: Bool) async {
        isSearching = true
        hasSearched = true

        if saveHistory {
            saveRecentSearch(query)
        }

        let token = SessionManager.shared.currentToken
        async let discoveryResult = MusicService.shared.fetchDiscoverySearch(query: query, serverURL: serverURL, token: token)
        async let fallbackResult = MusicService.shared.search(query: query, serverURL: serverURL, token: token)

        let (disc, fb) = await (discoveryResult, fallbackResult)

        await MainActor.run {
            self.searchResponse = disc
            self.fallbackTracks = fb
            self.isSearching = false
        }
    }

    // MARK: - Recent Searches Persistence
    private func loadRecentSearches() {
        if let saved = UserDefaults.standard.stringArray(forKey: "port_music_recent_searches") {
            self.recentSearches = saved
        }
    }

    private func saveRecentSearch(_ query: String) {
        var current = recentSearches.filter { $0.lowercased() != query.lowercased() }
        current.insert(query, at: 0)
        if current.count > 12 {
            current = Array(current.prefix(12))
        }
        recentSearches = current
        UserDefaults.standard.set(current, forKey: "port_music_recent_searches")
    }

    private func removeRecentSearch(_ query: String) {
        recentSearches.removeAll { $0 == query }
        UserDefaults.standard.set(recentSearches, forKey: "port_music_recent_searches")
    }

    private func clearAllRecentSearches() {
        recentSearches.removeAll()
        UserDefaults.standard.removeObject(forKey: "port_music_recent_searches")
    }
}
