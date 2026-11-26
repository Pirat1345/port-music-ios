import SwiftUI

public struct SearchView: View {
    public let serverURL: String
    public let user: UserProfile?

    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var favoritesManager = FavoritesManager.shared

    @State private var searchQuery: String = ""
    @State private var isSearchActive: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var searchScope: String = "Katalog"
    private let searchScopeOptions = ["Katalog", "Bibliothek"]
    @Namespace private var searchScopeNamespace
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
    @State private var showSettingsSheet: Bool = false

    // Bibliothek-Suchindex (Ordner, Playlists, Songs, Künstler, Alben, Podcasts, Radio)
    @State private var libraryData = LibraryCollectionsData()
    @State private var libraryHistoryTracks: [Track] = []
    @State private var libraryLocalTracks: [Track] = []
    @State private var libraryRadioFavorites: [LibraryRadioStation] = []
    @State private var libraryPodcasts: [PodcastItem] = []
    @State private var hasLoadedLibraryIndex: Bool = false

    // Navigation History (Vor & Zurück)
    @State private var forwardQuery: String = ""
    @State private var forwardRouteHistory: [AppRoute] = []
    private var navigationPath: Binding<[AppRoute]>?

    public init(serverURL: String, user: UserProfile? = nil, navigationPath: Binding<[AppRoute]>? = nil) {
        self.serverURL = serverURL
        self.user = user
        self.navigationPath = navigationPath
    }

    private var activeProfileUser: UserProfile {
        sessionManager.currentUser ?? user ?? UserProfile(id: "me", username: "Port Music")
    }

    private var canGoBack: Bool {
        let hasPushedRoute = (navigationPath?.wrappedValue.count ?? 0) > 0
        return hasPushedRoute || !searchQuery.isEmpty
    }

    private var canGoForward: Bool {
        let hasForwardRoute = !forwardRouteHistory.isEmpty
        return hasForwardRoute || !forwardQuery.isEmpty
    }

    private func handleGoBack() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if let path = navigationPath, !path.wrappedValue.isEmpty {
            let popped = path.wrappedValue.removeLast()
            forwardRouteHistory.append(popped)
            return
        }

        if !searchQuery.isEmpty {
            forwardQuery = searchQuery
            searchQuery = ""
            return
        }

        presentationMode.wrappedValue.dismiss()
    }

    private func handleGoForward() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if !forwardRouteHistory.isEmpty, let path = navigationPath {
            let next = forwardRouteHistory.removeLast()
            path.wrappedValue.append(next)
            return
        }

        if !forwardQuery.isEmpty {
            searchQuery = forwardQuery
            forwardQuery = ""
            return
        }
    }

    private func activateSearch() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
            isSearchActive = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            isSearchFieldFocused = true
        }
        Task {
            await ensureLibrarySearchIndexLoaded()
        }
    }

    private func deactivateSearch() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        searchTask?.cancel()
        autoSaveTask?.cancel()
        isSearchFieldFocused = false
        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
            isSearchActive = false
            searchQuery = ""
            searchResponse = nil
            fallbackTracks = []
            hasSearched = false
        }
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color.black
                .ignoresSafeArea()

            if isSearchActive {
                activeSearchContainer
                    .transition(.opacity)
                    .zIndex(2)
            } else {
                idleBrowseScrollView
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .tint(.white)
        .sheet(isPresented: $showSettingsSheet) {
            SettingsMainView(user: activeProfileUser, serverURL: serverURL) {
                SessionManager.shared.logout()
            }
        }
        .task {
            await initializeData()
        }
        .onChange(of: searchQuery) { newValue in
            if !newValue.isEmpty && !isSearchActive {
                isSearchActive = true
            }
        }
    }

    private var idleBrowseScrollView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                searchTopHeaderBar

                Section {
                    VStack(alignment: .leading, spacing: 26) {
                        idleDiscoverView

                        // Abstand fuer MiniPlayer & TabBar
                        Spacer(minLength: 160)
                    }
                    .padding(.top, 14)
                } header: {
                    pinnedIdleSearchBarHeader
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var activeSearchContainer: some View {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(spacing: 0) {
            activeSearchTopControls
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(
                    LinearGradient(
                        stops: [
                            .init(color: Color.black, location: 0.0),
                            .init(color: Color.black.opacity(0.95), location: 0.82),
                            .init(color: Color.black.opacity(0.0), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .top)
                )

            if trimmed.isEmpty {
                if !recentSearches.isEmpty {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            recentSearchesSection
                            Spacer(minLength: 160)
                        }
                        .padding(.top, 10)
                    }
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    emptyRecentSearchesFocusedView
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        filterPillsSection
                            .padding(.top, 6)

                        if searchScope == "Bibliothek" {
                            librarySearchResultsView(query: trimmed)
                        } else {
                            if isSearching && searchResponse == nil && fallbackTracks.isEmpty {
                                loadingView
                            } else if hasSearched && isEmptyResults {
                                emptyResultsView
                            } else {
                                activeResultsView
                            }
                        }

                        Spacer(minLength: 160)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var emptyRecentSearchesFocusedView: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 48)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 42, weight: .regular))
                .foregroundColor(Color.white.opacity(0.32))

            Text("Keine letzten Suchanfragen")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)

            Text("Deine letzten Suchanfragen werden\nhier angezeigt.")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.50))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 120)
        .contentShape(Rectangle())
        .onTapGesture {
            isSearchFieldFocused = false
        }
    }

    private var isEmptyResults: Bool {
        let hasTracks = !(searchResponse?.tracks?.isEmpty ?? true) || !fallbackTracks.isEmpty
        let hasAlbums = !(searchResponse?.albums?.isEmpty ?? true)
        let hasArtists = !(searchResponse?.artists?.isEmpty ?? true)
        let hasPlaylists = !(searchResponse?.playlists?.isEmpty ?? true)
        return !hasTracks && !hasAlbums && !hasArtists && !hasPlaylists
    }

    // MARK: - Header ("Suche" + Profil) & Pinned Search Bar
    private var searchTopHeaderBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Suche")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showSettingsSheet = true
            } label: {
                PortUserAvatarView(
                    rawAvatar: activeProfileUser.avatar,
                    username: activeProfileUser.username,
                    serverURL: serverURL,
                    size: 36
                )
                .clipShape(Circle())
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .portLiquidGlassCircle(interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Benutzerprofil")
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    private var pinnedIdleSearchBarHeader: some View {
        Button {
            activateSearch()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.55))

                Text("Künstler:innen, Titel, Songtexte...")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.42))
                    .lineLimit(1)

                Spacer()

                Image(systemName: "mic.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.45))
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .contentShape(Capsule())
            .portLiquidGlassCapsule(interactive: true)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color.black, location: 0.0),
                    .init(color: Color.black.opacity(0.92), location: 0.78),
                    .init(color: Color.black.opacity(0.0), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    private var activeSearchTopControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.55))

                    TextField(
                        "",
                        text: $searchQuery,
                        prompt: Text("Künstler:innen, Titel, Songtexte...")
                            .foregroundColor(Color.white.opacity(0.40))
                    )
                    .font(.system(size: 15))
                    .foregroundColor(PortColors.textPrimary)
                    .tint(Color(hex: "#0a84ff"))
                    .accentColor(Color(hex: "#0a84ff"))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .focused($isSearchFieldFocused)
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
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color.white.opacity(0.45))
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .portLiquidGlassCapsule(interactive: true)

                Button(action: {
                    deactivateSearch()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .portLiquidGlassCircle(interactive: true)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Suche schließen")
            }

            // 2-Segment Liquid Glass Switch ("Katalog" vs. "Bibliothek") - nur bei aktiver Suche
            HStack(spacing: 0) {
                ForEach(searchScopeOptions, id: \.self) { scope in
                    let isSelected = (searchScope == scope)
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            searchScope = scope
                        }
                        if scope == "Bibliothek" {
                            Task { await ensureLibrarySearchIndexLoaded() }
                        } else {
                            let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !q.isEmpty && searchResponse == nil && !isSearching {
                                Task { await executeSearch(query: q, saveHistory: false) }
                            }
                        }
                    }) {
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(Color.white.opacity(0.20))
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.32), Color.white.opacity(0.08)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ),
                                                lineWidth: 0.5
                                            )
                                    )
                                    .matchedGeometryEffect(id: "active_scope_tab", in: searchScopeNamespace)
                            }
                            Text(scope)
                                .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .white : Color.white.opacity(0.70))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(3)
            .portLiquidGlassCapsule(interactive: true)
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
    private var categoryGridColumns: [GridItem] {
        if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular {
            return [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ]
        } else {
            return [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
        }
    }

    private var browseCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Kategorien entdecken")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(PortColors.textPrimary)
                .padding(.horizontal, 20)

            LazyVGrid(
                columns: categoryGridColumns,
                spacing: UIDevice.current.userInterfaceIdiom == .pad ? 14 : 12
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
                .padding(12)
        }
        .aspectRatio(2.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
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
                                        PortArtistCard(artist: artist, serverURL: serverURL)
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
                                    NavigationLink(value: AppRoute.playlist(id: playlist.id, title: playlist.title, coverUrl: playlist.cover)) {
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
                            PortArtistCard(artist: artist, serverURL: serverURL)
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
                .padding(.horizontal, 20)
            } else if selectedFilter == "Playlists" {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(playlists) { playlist in
                        let sub = playlist.user ?? (playlist.nbTracks.map { "\($0) Songs" } ?? "Playlist")
                        NavigationLink(value: AppRoute.playlist(id: playlist.id, title: playlist.title, coverUrl: playlist.cover)) {
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

        if searchScope == "Bibliothek" {
            hasSearched = true
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                if !Task.isCancelled {
                    await ensureLibrarySearchIndexLoaded()
                }
            }
        } else {
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                if !Task.isCancelled {
                    await executeSearch(query: trimmed, saveHistory: false)
                }
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

        if searchScope == "Bibliothek" {
            hasSearched = true
            Task {
                await saveRecentSearch(trimmed)
                await ensureLibrarySearchIndexLoaded()
            }
            return
        }

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

    // MARK: - Bibliothek-Suche (Ordner, Playlists, Songs, Künstler, Alben, Podcasts, Radio)
    private func ensureLibrarySearchIndexLoaded() async {
        let token = SessionManager.shared.currentToken
        async let collectionsTask = MusicService.shared.fetchLibraryCollections(serverURL: serverURL, token: token)
        async let historyTask = MusicService.shared.fetchStatsAndHistory(serverURL: serverURL, token: token)
        async let localTask = MusicService.shared.fetchLocalAudioFiles(serverURL: serverURL, token: token)
        async let radioTask = MusicService.shared.fetchRadioFavorites(serverURL: serverURL, token: token)

        let (collections, hist, local, radios) = await (collectionsTask, historyTask, localTask, radioTask)
        let podcasts = PodcastSubscriptionStore.load()

        await MainActor.run {
            self.libraryData = collections
            self.libraryHistoryTracks = hist
            self.libraryLocalTracks = local
            self.libraryRadioFavorites = radios
            self.libraryPodcasts = podcasts
            self.hasLoadedLibraryIndex = true
        }
    }

    private func folderBreadcrumbTrail(for folder: LibraryFolder) -> [String] {
        var names: [String] = []
        var visited = Set<String>([folder.id])
        var parentId = folder.parentId
        let folderById = Dictionary(uniqueKeysWithValues: libraryData.folders.map { ($0.id, $0) })
        while let pid = parentId, let parent = folderById[pid], !visited.contains(pid) {
            visited.insert(pid)
            names.insert(parent.name, at: 0)
            parentId = parent.parentId
        }
        return ["Playlists"] + names
    }

    private func folderSubtitle(_ folder: LibraryFolder) -> String {
        let subCount = libraryData.folders.filter { $0.parentId == folder.id }.count
        let plCount = libraryData.playlists.filter { $0.folderId == folder.id }.count
        if subCount > 0 {
            return "\(subCount) Ordner · \(plCount) Playlists"
        }
        return "\(plCount) \(plCount == 1 ? "Playlist" : "Playlists")"
    }

    private func allUniqueLibraryTracks() -> [Track] {
        var seen = Set<String>()
        var combined: [Track] = []
        let sources: [[Track]] = [
            libraryData.favorites,
            Array(libraryData.playlistTracksMap.values.joined()),
            offlineManager.allDownloadedTracks(),
            libraryHistoryTracks,
            libraryLocalTracks,
            player.recentTracks
        ]
        for list in sources {
            for t in list where seen.insert(t.id).inserted {
                combined.append(t)
            }
        }
        return combined
    }

    private func allUniqueLibraryArtists(from tracks: [Track]) -> [(name: String, cover: String?)] {
        var coverByArtist: [String: (display: String, cover: String?)] = [:]
        for name in libraryData.savedArtists {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            coverByArtist[trimmed.lowercased()] = (trimmed, nil)
        }
        for t in tracks {
            let trimmed = t.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.lowercased() != "unbekannter interpret" else { continue }
            let key = trimmed.lowercased()
            if coverByArtist[key] == nil {
                coverByArtist[key] = (trimmed, t.coverUrl)
            } else if coverByArtist[key]?.cover == nil, let cov = t.coverUrl, !cov.isEmpty {
                coverByArtist[key]?.cover = cov
            }
        }
        return coverByArtist.values
            .map { ($0.display, $0.cover) }
            .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }

    private func allUniqueLibraryAlbums(from tracks: [Track]) -> [(id: String, title: String, artist: String, cover: String?)] {
        var map: [String: (id: String, title: String, artist: String, cover: String?)] = [:]
        for title in libraryData.savedAlbums {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let cov = libraryData.albumCovers[trimmed]
            map[trimmed.lowercased()] = (trimmed, trimmed, "Bibliothek", cov)
        }
        for t in tracks {
            guard let alb = t.album?.trimmingCharacters(in: .whitespacesAndNewlines), !alb.isEmpty else { continue }
            let key = alb.lowercased()
            if map[key] == nil {
                map[key] = (alb, alb, t.artist, t.coverUrl)
            }
        }
        return Array(map.values).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    @ViewBuilder
    private func librarySearchResultsView(query: String) -> some View {
        let q = query.lowercased()
        let folderById = Dictionary(uniqueKeysWithValues: libraryData.folders.map { ($0.id, $0) })

        let matchedFolders = libraryData.folders.filter { $0.name.lowercased().contains(q) }
        let matchedPlaylists = libraryData.playlists.filter {
            $0.title.lowercased().contains(q) || ($0.user?.lowercased().contains(q) ?? false)
        }

        let allSongs = allUniqueLibraryTracks()
        let matchedSongs = allSongs.filter {
            $0.title.lowercased().contains(q)
                || $0.artist.lowercased().contains(q)
                || ($0.album?.lowercased().contains(q) ?? false)
        }
        let matchedArtists = allUniqueLibraryArtists(from: allSongs).filter { $0.name.lowercased().contains(q) }
        let matchedAlbums = allUniqueLibraryAlbums(from: allSongs).filter {
            $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
        }
        let matchedPodcasts = libraryPodcasts.filter {
            $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
        }
        let matchedRadios = libraryRadioFavorites.filter {
            $0.name.lowercased().contains(q) || ($0.tags?.joined(separator: " ").lowercased().contains(q) ?? false)
        }

        let showFoldersAndPlaylists = (selectedFilter == "Top-Treffer" || selectedFilter == "Playlists")
        let showSongs = (selectedFilter == "Top-Treffer" || selectedFilter == "Songs")
        let showArtists = (selectedFilter == "Top-Treffer" || selectedFilter == "Künstler")
        let showAlbums = (selectedFilter == "Top-Treffer" || selectedFilter == "Alben")
        let showExtraCategories = (selectedFilter == "Top-Treffer")

        let noMatches = matchedFolders.isEmpty
            && matchedPlaylists.isEmpty
            && matchedSongs.isEmpty
            && matchedArtists.isEmpty
            && matchedAlbums.isEmpty
            && matchedPodcasts.isEmpty
            && matchedRadios.isEmpty

        if !hasLoadedLibraryIndex && noMatches {
            loadingView
        } else if noMatches {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(Color.white.opacity(0.30))
                Text("Keine Treffer in deiner Bibliothek")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text("Keine Ordner, Playlists oder Titel für „\(query)“ gefunden.")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 56)
        } else {
            VStack(alignment: .leading, spacing: 22) {
                if showFoldersAndPlaylists && !matchedFolders.isEmpty {
                    libraryFoldersSection(matchedFolders)
                }

                if showFoldersAndPlaylists && !matchedPlaylists.isEmpty {
                    libraryPlaylistsSection(matchedPlaylists, folderById: folderById)
                }

                if showSongs && !matchedSongs.isEmpty {
                    librarySongsSection(matchedSongs)
                }

                if showArtists && !matchedArtists.isEmpty {
                    libraryArtistsSection(matchedArtists)
                }

                if showAlbums && !matchedAlbums.isEmpty {
                    libraryAlbumsSection(matchedAlbums)
                }

                if showExtraCategories && !matchedPodcasts.isEmpty {
                    libraryPodcastsSection(matchedPodcasts)
                }

                if showExtraCategories && !matchedRadios.isEmpty {
                    libraryRadiosSection(matchedRadios)
                }
            }
        }
    }

    private func libraryFoldersSection(_ folders: [LibraryFolder]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ordner")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(PortColors.textPrimary)
                .padding(.horizontal, 20)

            VStack(spacing: 4) {
                ForEach(folders) { folder in
                    let inFolder = libraryData.playlists.filter { $0.folderId == folder.id }
                    NavigationLink(value: AppRoute.playlistFolder(
                        folderId: folder.id,
                        title: folder.name,
                        parentTrail: folderBreadcrumbTrail(for: folder)
                    )) {
                        HStack(spacing: 12) {
                            FolderCoverView(
                                folder: folder,
                                playlists: inFolder,
                                serverURL: serverURL
                            )
                            .frame(width: 56, height: 56)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(folder.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(folderSubtitle(folder))
                                    .font(.system(size: 12.5))
                                    .foregroundColor(Color.white.opacity(0.55))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.35))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
        }
    }

    private func libraryPlaylistsSection(_ pls: [DiscoveryPlaylist], folderById: [String: LibraryFolder]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Playlists")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(PortColors.textPrimary)
                .padding(.horizontal, 20)

            VStack(spacing: 4) {
                ForEach(pls) { pl in
                    NavigationLink(value: AppRoute.playlist(id: pl.id, title: pl.title, coverUrl: pl.cover)) {
                        HStack(spacing: 12) {
                            PlaylistArtworkView(
                                coverUrl: pl.cover,
                                trackCovers: pl.trackCovers,
                                cornerRadius: 8,
                                iconSize: 18,
                                serverURL: serverURL
                            )
                            .frame(width: 52, height: 52)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(pl.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                let countText = pl.nbTracks.map { "\($0) Titel" } ?? "Playlist"
                                let folderName = pl.folderId.flatMap { folderById[$0]?.name }
                                let subText = folderName.map { "\($0) · \(countText)" } ?? countText
                                Text(subText)
                                    .font(.system(size: 12.5))
                                    .foregroundColor(Color.white.opacity(0.55))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.35))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
        }
    }

    private func librarySongsSection(_ songs: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Songs")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(PortColors.textPrimary)
                .padding(.horizontal, 20)

            VStack(spacing: 6) {
                ForEach(selectedFilter == "Top-Treffer" ? Array(songs.prefix(8)) : songs) { track in
                    searchTrackRow(track: track, fullQueue: songs)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func libraryArtistsSection(_ artists: [(name: String, cover: String?)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Künstler")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(PortColors.textPrimary)
                .padding(.horizontal, 20)

            VStack(spacing: 4) {
                ForEach(artists, id: \.name) { item in
                    NavigationLink(value: AppRoute.artist(name: item.name, coverUrl: item.cover)) {
                        HStack(spacing: 12) {
                            PortCachedAsyncImage(url: resolveCoverURL(item.cover, serverURL: serverURL)) { img in
                                img
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 48, height: 48)
                                    .clipShape(Circle())
                            } placeholder: {
                                Circle()
                                    .fill(Color.white.opacity(0.10))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Image(systemName: "music.mic")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color.white.opacity(0.45))
                                    )
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text("Künstler")
                                    .font(.system(size: 12.5))
                                    .foregroundColor(Color.white.opacity(0.55))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.35))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
        }
    }

    private func libraryAlbumsSection(_ albums: [(id: String, title: String, artist: String, cover: String?)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alben")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(PortColors.textPrimary)
                .padding(.horizontal, 20)

            VStack(spacing: 4) {
                ForEach(albums, id: \.id) { alb in
                    NavigationLink(value: AppRoute.album(id: alb.id, title: alb.title, artist: alb.artist, coverUrl: alb.cover)) {
                        HStack(spacing: 12) {
                            PortCachedAsyncImage(url: resolveCoverURL(alb.cover, serverURL: serverURL)) { img in
                                img
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.10))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Image(systemName: "square.stack")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color.white.opacity(0.45))
                                    )
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(alb.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(alb.artist)
                                    .font(.system(size: 12.5))
                                    .foregroundColor(Color.white.opacity(0.55))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.35))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
        }
    }

    private func libraryPodcastsSection(_ podcasts: [PodcastItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Podcasts")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(PortColors.textPrimary)
                .padding(.horizontal, 20)

            VStack(spacing: 4) {
                ForEach(podcasts) { pod in
                    NavigationLink(value: AppRoute.podcast(
                        id: pod.id,
                        title: pod.title,
                        artist: pod.artist,
                        coverUrl: pod.cover,
                        feedUrl: pod.feedUrl
                    )) {
                        HStack(spacing: 12) {
                            PortCachedAsyncImage(url: resolveCoverURL(pod.cover, serverURL: serverURL)) { img in
                                img
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.10))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color.white.opacity(0.45))
                                    )
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(pod.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(pod.artist)
                                    .font(.system(size: 12.5))
                                    .foregroundColor(Color.white.opacity(0.55))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.35))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
        }
    }

    private func libraryRadiosSection(_ radios: [LibraryRadioStation]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Radio")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(PortColors.textPrimary)
                .padding(.horizontal, 20)

            VStack(spacing: 4) {
                ForEach(radios) { station in
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        let radioTrack = Track(
                            id: "radio_\(station.id)",
                            title: station.name,
                            artist: "Live Radio",
                            album: station.tags?.first ?? station.country ?? "Radio",
                            duration: "Radio",
                            durationSeconds: 0,
                            coverUrl: station.favicon,
                            isLive: true,
                            isExplicit: false,
                            sourceUrl: station.url
                        )
                        player.play(track: radioTrack, from: [radioTrack], serverURL: serverURL)
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.10))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Image(systemName: "dot.radiowaves.left.and.right")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(station.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(station.tags?.first ?? station.country ?? "Live Radio")
                                    .font(.system(size: 12.5))
                                    .foregroundColor(Color.white.opacity(0.55))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.white.opacity(0.45))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
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
