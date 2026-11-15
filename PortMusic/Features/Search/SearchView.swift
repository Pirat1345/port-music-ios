import SwiftUI

public struct SearchView: View {
    public let serverURL: String

    @ObservedObject private var player = AudioPlayerManager.shared

    @State private var searchQuery: String = ""
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var autoSaveTask: Task<Void, Never>? = nil

    @State private var isSearching: Bool = false
    @State private var searchResponse: DiscoverySearchResponse? = nil
    @State private var fallbackTracks: [Track] = []
    @State private var hasSearched: Bool = false

    @State private var selectedFilter: String = "Top-Treffer"
    private let filterOptions = ["Top-Treffer", "Songs", "Künstler", "Alben", "Playlists"]

    @State private var recentSearches: [String] = []
    @State private var categories: [BrowseCategoryItem] = BrowseCategoryItem.defaultCategories

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
        .task {
            await initializeData()
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

    // MARK: - Idle State (Zuletzt gesucht & Browse Categories)
    private var idleDiscoverView: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Zuletzt gesucht / Suchverlauf
            if !recentSearches.isEmpty {
                recentSearchesSection
            }

            // Kategorien entdecken (Alle 44 Kategorien im Octave 2:1 Banner-Design)
            browseCategoriesSection
        }
    }

    // MARK: - Recent Searches Section
    private var recentSearchesSection: some View {
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
                        .font(.system(size: 13, weight: .semibold))
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

    // MARK: - Browse Categories Section
    private var browseCategoriesSection: some View {
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
                ForEach(categories) { cat in
                    NavigationLink(value: AppRoute.appleCategory(
                        id: cat.id,
                        title: cat.displayTitle,
                        artworkUrl: cat.artworkUrl,
                        bgColor: cat.bgColor
                    )) {
                        categoryCard(cat)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - 2:1 Category Card
    private func categoryCard(_ cat: BrowseCategoryItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Background Gradient Base via Hex Colors
            LinearGradient(
                gradient: Gradient(colors: cat.gradient.isEmpty ? [Color(hex: cat.bgColor), Color(hex: "#18181b")] : cat.gradient),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Artwork Cover or Fallback Icon
            if let url = URL(string: cat.bannerUrl) {
                PortCachedAsyncImage(url: url) { img in
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    LinearGradient(
                        gradient: Gradient(colors: cat.gradient),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            } else {
                HStack {
                    Spacer()
                    Image(systemName: cat.iconName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.20))
                        .padding(12)
                }
            }

            // Dark gradient overlay from bottom to top for maximum text legibility
            LinearGradient(
                colors: [
                    Color.black.opacity(0.78),
                    Color.black.opacity(0.15),
                    Color.clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )

            // Category Title
            Text(cat.displayTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .shadow(color: Color.black.opacity(0.6), radius: 4, x: 0, y: 1)
                .padding(12)
        }
        .aspectRatio(2.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 6, y: 3)
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

    // MARK: - Track Row Item
    private func searchTrackRow(track: Track, fullQueue: [Track]) -> some View {
        let isCurrent = player.currentTrack?.id == track.id
        return Button(action: {
            player.play(track: track, from: fullQueue, serverURL: serverURL)
        }) {
            HStack(spacing: 12) {
                let resolved = resolveCoverURL(track.coverUrl, serverURL: serverURL)
                PortCachedAsyncImage(url: resolved) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 48, height: 48)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isCurrent ? PortColors.primaryAccent : .white)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.60))
                        .lineLimit(1)
                }

                Spacer()

                if isCurrent && player.isPlaying {
                    Image(systemName: "waveform")
                        .foregroundColor(PortColors.primaryAccent)
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.40))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isCurrent ? Color.white.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helper Views
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            Text("Suche läuft…")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.60))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var emptyResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(Color.white.opacity(0.30))

            Text("Keine Treffer für „\(searchQuery)“")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text("Überprüfe deine Suchbegriffe oder suche nach anderen Titeln.")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Search Operations & History Sync
    private func scheduleDebouncedSearch(query: String) {
        searchTask?.cancel()
        autoSaveTask?.cancel()

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

        // Auto-save query to history when viewed and stabilized for 2s (matching web behavior)
        if trimmed.count >= 2 {
            autoSaveTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if !Task.isCancelled {
                    await saveRecentSearch(trimmed)
                }
            }
        }
    }

    private func submitSearch(query: String) {
        searchTask?.cancel()
        autoSaveTask?.cancel()

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
            await saveRecentSearch(query)
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

    // MARK: - Initialization & Sync
    private func initializeData() async {
        loadRecentSearchesLocally()

        let token = SessionManager.shared.currentToken
        async let historyTask = MusicService.shared.fetchSearchHistory(serverURL: serverURL, token: token)
        async let categoriesTask = MusicService.shared.fetchCategories(serverURL: serverURL)

        let (serverHistory, serverCategories) = await (historyTask, categoriesTask)

        await MainActor.run {
            if !serverHistory.isEmpty {
                self.recentSearches = serverHistory
                UserDefaults.standard.set(serverHistory, forKey: "port_music_recent_searches")
            }
            if !serverCategories.isEmpty {
                self.categories = serverCategories
            }
        }
    }

    private func loadRecentSearchesLocally() {
        if let saved = UserDefaults.standard.stringArray(forKey: "port_music_recent_searches") {
            self.recentSearches = saved
        }
    }

    private func saveRecentSearch(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }

        var current = recentSearches.filter { $0.lowercased() != trimmed.lowercased() }
        current.insert(trimmed, at: 0)
        if current.count > 12 {
            current = Array(current.prefix(12))
        }

        await MainActor.run {
            self.recentSearches = current
        }
        UserDefaults.standard.set(current, forKey: "port_music_recent_searches")

        let token = SessionManager.shared.currentToken
        await MusicService.shared.saveSearchHistory(current, serverURL: serverURL, token: token)
    }

    private func removeRecentSearch(_ query: String) {
        var current = recentSearches
        current.removeAll { $0 == query }
        recentSearches = current
        UserDefaults.standard.set(current, forKey: "port_music_recent_searches")

        let token = SessionManager.shared.currentToken
        Task {
            await MusicService.shared.saveSearchHistory(current, serverURL: serverURL, token: token)
        }
    }

    private func clearAllRecentSearches() {
        recentSearches.removeAll()
        UserDefaults.standard.removeObject(forKey: "port_music_recent_searches")

        let token = SessionManager.shared.currentToken
        Task {
            await MusicService.shared.saveSearchHistory([], serverURL: serverURL, token: token)
        }
    }
}
