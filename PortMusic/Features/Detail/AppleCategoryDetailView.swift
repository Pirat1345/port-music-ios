import SwiftUI

private struct CategoryPlayButtonMaxYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if let next = nextValue() {
            value = next
        }
    }
}

public struct AppleCategoryDetailView: View {
    public let id: String
    public let title: String
    public let artworkUrl: String?
    public let bgColor: String?
    public let serverURL: String

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var favoritesManager = FavoritesManager.shared

    @State private var categoryData: AppleCategoryDetailData? = nil
    @State private var enrichedTracks: [Track] = []
    @State private var enrichedPlaylists: [DiscoveryPlaylist] = []
    @State private var enrichedAlbums: [DiscoveryAlbum] = []
    @State private var isLoading: Bool = true
    @State private var showStickyTopBar: Bool = false

    public init(id: String, title: String, artworkUrl: String? = nil, bgColor: String? = nil, serverURL: String) {
        self.id = id
        self.title = title
        self.artworkUrl = artworkUrl
        self.bgColor = bgColor
        self.serverURL = serverURL
    }

    private var effectiveBgColor: Color {
        if let bg = bgColor, !bg.isEmpty {
            return Color(hex: bg)
        }
        if let catBg = categoryData?.bgColor, !catBg.isEmpty {
            return Color(hex: catBg)
        }
        return Color(hex: "#18181b")
    }

    private var effectiveTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        return categoryData?.title ?? "Kategorie"
    }

    private var effectiveArtwork: String? {
        if let art = artworkUrl, !art.isEmpty {
            return art
        }
        if let hero = categoryData?.heroArtwork, !hero.isEmpty {
            return hero
        }
        return allAvailableTracks.first?.coverUrl
            ?? enrichedPlaylists.first?.cover
            ?? enrichedAlbums.first?.cover
    }

    private var topSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 54
    }

    private var allAvailableTracks: [Track] {
        var result: [Track] = []
        var seenIds = Set<String>()
        if let sections = categoryData?.sections {
            for section in sections {
                for item in section.items where item.kind == "track" {
                    let t = item.toTrack()
                    if seenIds.insert(t.id).inserted {
                        result.append(t)
                    }
                }
            }
        }
        if result.isEmpty {
            return enrichedTracks
        }
        return result
    }

    private var isCategoryCurrentlyPlaying: Bool {
        guard player.isPlaying, let cur = player.currentTrack else { return false }
        return allAvailableTracks.contains(where: { $0.id == cur.id })
    }

    private var totalItemCount: Int {
        let secCount = categoryData?.sections.reduce(0) { $0 + $1.items.count } ?? 0
        return secCount + enrichedTracks.count + enrichedPlaylists.count + enrichedAlbums.count
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ZStack(alignment: .top) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Stretchy Hero Header (analog ArtistDetailView)
                        heroBannerHeader

                        if isLoading && categoryData == nil && enrichedTracks.isEmpty {
                            loadingSection
                        } else {
                            contentSections
                        }

                        Spacer(minLength: 140)
                    }
                }
                .coordinateSpace(name: "category_scroll")
                .ignoresSafeArea(edges: .top)
                .refreshable {
                    await loadCategoryDetails()
                }
                .onPreferenceChange(CategoryPlayButtonMaxYPreferenceKey.self) { maxY in
                    guard let maxY else { return }
                    let threshold = topSafeAreaInset + 60
                    let shouldShow = maxY <= threshold
                    if shouldShow != showStickyTopBar {
                        withAnimation(.easeOut(duration: 0.22)) {
                            showStickyTopBar = shouldShow
                        }
                    }
                }

                stickyTopBarOverlay
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background(InteractivePopGestureEnabler())
        .preferredColorScheme(.dark)
        .tint(.white)
        .task(id: id) {
            if categoryData == nil, let cached = MusicService.shared.cachedCategoryDetail(id: id) {
                categoryData = cached
            }
            await loadCategoryDetails()
        }
        .onReceive(NotificationCenter.default.publisher(for: .portMusicDidReconnect)) { _ in
            Task {
                await loadCategoryDetails()
            }
        }
    }

    // MARK: - Sticky Top Bar (analog ArtistDetailView)
    private var stickyTopBarOverlay: some View {
        HStack(spacing: 12) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(showStickyTopBar ? Color.white.opacity(0.10) : Color.black.opacity(0.45))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(showStickyTopBar ? 0.14 : 0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Zurück")

            HStack(spacing: 10) {
                Button(action: toggleCategoryPlayPause) {
                    Image(systemName: isCategoryCurrentlyPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .offset(x: isCategoryCurrentlyPlaying ? 0 : 1)
                        .frame(width: 34, height: 34)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(allAvailableTracks.isEmpty)
                .opacity(allAvailableTracks.isEmpty ? 0.55 : 1.0)
                .accessibilityLabel(isCategoryCurrentlyPlaying ? "Pause" : "Wiedergabe")

                Text(effectiveTitle)
                    .font(.system(size: 15, weight: .black, design: .serif))
                    .tracking(2.0)
                    .textCase(.uppercase)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .opacity(showStickyTopBar ? 1 : 0)
            .offset(y: showStickyTopBar ? 0 : -6)
            .scaleEffect(showStickyTopBar ? 1 : 0.95, anchor: .leading)
            .allowsHitTesting(showStickyTopBar)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .frame(maxWidth: .infinity)
        .background(
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.62))

                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 0.5)
            }
            .ignoresSafeArea(edges: .top)
            .opacity(showStickyTopBar ? 1 : 0)
            .allowsHitTesting(showStickyTopBar)
        )
    }

    // MARK: - Stretchy Hero Banner Header (analog ArtistDetailView)
    private var heroBannerHeader: some View {
        let heroHeight: CGFloat = 310 + topSafeAreaInset

        return ZStack(alignment: .bottom) {
            GeometryReader { geo in
                let minY = geo.frame(in: .named("category_scroll")).minY
                let pullDown = max(0, minY)
                let width = geo.size.width
                let stretchedHeight = max(geo.size.height, heroHeight) + pullDown

                ZStack {
                    LinearGradient(
                        colors: [effectiveBgColor, effectiveBgColor.opacity(0.55), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    if let art = effectiveArtwork, let resolved = resolveCoverURL(art, serverURL: serverURL) {
                        PortCachedAsyncImage(url: resolved) { img in
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: width, height: stretchedHeight, alignment: .center)
                                .clipped()
                        } placeholder: {
                            Color.clear
                        }
                    }

                    // Sanfter Übergang nach reinem Schwarz
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.28), location: 0.0),
                            .init(color: Color.black.opacity(0.12), location: 0.25),
                            .init(color: Color.black.opacity(0.36), location: 0.56),
                            .init(color: Color.black.opacity(0.86), location: 0.86),
                            .init(color: Color.black, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(width: width, height: stretchedHeight)
                .offset(y: -pullDown)
            }
            .frame(height: heroHeight)

            VStack(alignment: .center, spacing: 8) {
                Text("Apple Music · Kategorie")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundColor(Color.white.opacity(0.75))

                Text(effectiveTitle)
                    .font(.system(size: 36, weight: .black, design: .serif))
                    .tracking(3.2)
                    .textCase(.uppercase)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                    .multilineTextAlignment(.center)
                    .shadow(color: Color.black.opacity(0.90), radius: 14, y: 4)
                    .padding(.horizontal, 12)

                if totalItemCount > 0 {
                    Text("\(allAvailableTracks.count) Songs · Entdecken & Charts")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.78))
                }

                HStack(spacing: 14) {
                    // Zufallswiedergabe
                    Button(action: { playAll(shuffle: true) }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
                            )
                    }
                    .disabled(allAvailableTracks.isEmpty)
                    .opacity(allAvailableTracks.isEmpty ? 0.45 : 1.0)

                    // Play / Pause All (Weißer Octave Hero Button)
                    Button(action: toggleCategoryPlayPause) {
                        Image(systemName: isCategoryCurrentlyPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black)
                            .offset(x: isCategoryCurrentlyPlaying ? 0 : 1.5)
                            .frame(width: 58, height: 58)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.45), radius: 10, y: 4)
                    }
                    .disabled(allAvailableTracks.isEmpty)
                    .opacity(allAvailableTracks.isEmpty ? 0.55 : 1.0)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: CategoryPlayButtonMaxYPreferenceKey.self,
                                value: geo.frame(in: .named("category_scroll")).maxY
                            )
                        }
                    )
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
    }

    // MARK: - Loading View
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            Text("Kategorie wird geladen...")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.60))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Content Sections
    private var contentSections: some View {
        VStack(alignment: .leading, spacing: 28) {
            if sessionManager.isOfflineMode {
                HStack(spacing: 10) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Offline-Modus")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(.white)
                        Text("Zwischengespeicherte Kategorie-Inhalte – nur geladene Songs abspielbar.")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.60))
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.10), lineWidth: 1))
                .padding(.horizontal, 20)
            }

            // 1. API Sections (if provided)
            if let sections = categoryData?.sections, !sections.isEmpty {
                ForEach(sections) { section in
                    renderSection(section)
                }
            }

            // 2. Enriched Songs (when category detail had few or no direct tracks)
            if !enrichedTracks.isEmpty && ((categoryData?.sections.isEmpty ?? true) || allAvailableTracks.isEmpty) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Beliebte Songs")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)

                    LazyVStack(spacing: 4) {
                        ForEach(Array(enrichedTracks.prefix(25).enumerated()), id: \.element.id) { index, track in
                            TrackRowView(
                                track: track,
                                index: index,
                                contextQueue: enrichedTracks,
                                serverURL: serverURL,
                                isLiked: favoritesManager.isFavorite(trackId: track.id),
                                isDownloaded: offlineManager.isDownloaded(trackId: track.id),
                                showCover: true,
                                showTrackNumber: true
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            // 3. Enriched Playlists
            if !enrichedPlaylists.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Beliebte Playlists")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(enrichedPlaylists) { pl in
                                NavigationLink(value: AppRoute.playlist(id: pl.id, title: pl.title, coverUrl: pl.cover)) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ZStack(alignment: .bottomTrailing) {
                                            PlaylistArtworkView(
                                                coverUrl: pl.cover,
                                                trackCovers: pl.trackCovers,
                                                cornerRadius: 14,
                                                iconSize: 32,
                                                serverURL: serverURL
                                            )
                                            .frame(width: 145, height: 145)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                            )

                                            Button(action: {
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
                                            }) {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.white)
                                                        .frame(width: 36, height: 36)
                                                        .shadow(color: Color.black.opacity(0.4), radius: 5, y: 2)
                                                    Image(systemName: "play.fill")
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundColor(.black)
                                                        .offset(x: 1)
                                                }
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .padding(8)
                                        }
                                        .frame(width: 145, height: 145)

                                        Text(pl.title)
                                            .font(.system(size: 13.5, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .frame(width: 145, alignment: .leading)

                                        Text(pl.user ?? "Playlist")
                                            .font(.system(size: 11.5))
                                            .foregroundColor(Color.white.opacity(0.55))
                                            .lineLimit(1)
                                            .frame(width: 145, alignment: .leading)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }

            // 4. Enriched Albums
            if !enrichedAlbums.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Beliebte Alben")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(enrichedAlbums) { alb in
                                NavigationLink(value: AppRoute.album(id: alb.id, title: alb.title, artist: alb.artist, coverUrl: alb.cover)) {
                                    PortAlbumCard(
                                        title: alb.title,
                                        subtitle: alb.artist,
                                        coverUrl: alb.cover,
                                        serverURL: serverURL,
                                        onTap: nil,
                                        onPlay: {
                                            Task {
                                                if let detail = await MusicService.shared.fetchAlbum(id: alb.id, serverURL: serverURL, token: SessionManager.shared.currentToken) {
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
        }
        .padding(.top, 20)
    }

    // MARK: - Section Renderer
    @ViewBuilder
    private func renderSection(_ section: AppleCategorySection) -> some View {
        let tracks = section.items.filter { $0.kind == "track" }
        let otherItems = section.items.filter { $0.kind != "track" }

        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            if !tracks.isEmpty {
                let trackModels = tracks.map { $0.toTrack() }
                LazyVStack(spacing: 4) {
                    ForEach(Array(trackModels.enumerated()), id: \.element.id) { index, track in
                        TrackRowView(
                            track: track,
                            index: index,
                            contextQueue: trackModels,
                            serverURL: serverURL,
                            isLiked: favoritesManager.isFavorite(trackId: track.id),
                            isDownloaded: offlineManager.isDownloaded(trackId: track.id),
                            showCover: true,
                            showTrackNumber: true
                        )
                    }
                }
                .padding(.horizontal, 20)
            }

            if !otherItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(otherItems) { item in
                            if item.kind == "artist" {
                                NavigationLink(value: AppRoute.artist(name: item.title, coverUrl: item.cover)) {
                                    VStack(spacing: 8) {
                                        PortCoverImage(
                                            coverUrl: item.cover,
                                            serverURL: serverURL,
                                            placeholderIcon: "person.fill"
                                        )
                                        .frame(width: 124, height: 124)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))

                                        Text(item.title)
                                            .font(.system(size: 13.5, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .frame(width: 124)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else if item.kind == "album" {
                                let cleanId = item.id.replacingOccurrences(of: "^apple:", with: "", options: .regularExpression)
                                NavigationLink(value: AppRoute.album(id: cleanId, title: item.title, artist: item.subtitle, coverUrl: item.cover)) {
                                    PortAlbumCard(
                                        title: item.title,
                                        subtitle: item.subtitle ?? "Album",
                                        coverUrl: item.cover,
                                        serverURL: serverURL,
                                        onTap: nil,
                                        onPlay: {
                                            Task {
                                                if let detail = await MusicService.shared.fetchAlbum(id: cleanId, serverURL: serverURL, token: SessionManager.shared.currentToken) {
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
                            } else {
                                let cleanId = item.id.replacingOccurrences(of: "^apple:", with: "", options: .regularExpression)
                                NavigationLink(value: AppRoute.playlist(id: cleanId, title: item.title, coverUrl: item.cover)) {
                                    PortTrackCard(
                                        title: item.title,
                                        subtitle: item.subtitle ?? "Playlist",
                                        coverUrl: item.cover,
                                        serverURL: serverURL,
                                        onTap: nil,
                                        onPlay: {
                                            Task {
                                                if let detail = await MusicService.shared.fetchDiscoveryPlaylist(id: cleanId, serverURL: serverURL, token: SessionManager.shared.currentToken) {
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
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Playback Actions
    private func toggleCategoryPlayPause() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if isCategoryCurrentlyPlaying {
            player.togglePlayPause()
        } else {
            playAll(shuffle: false)
        }
    }

    private func playAll(shuffle: Bool) {
        let tracks = allAvailableTracks
        guard !tracks.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let queue = shuffle ? tracks.shuffled() : tracks
        if let first = queue.first {
            player.isShuffle = shuffle
            player.play(track: first, from: queue, serverURL: serverURL)
        }
    }

    // MARK: - Data Loading
    private func loadCategoryDetails() async {
        isLoading = true
        let token = SessionManager.shared.currentToken

        // 1. Fetch from /api/category/:id (with offline cache fallback)
        var detail = await MusicService.shared.fetchCategoryDetail(id: id, serverURL: serverURL, token: token)
        if detail == nil, !effectiveTitle.isEmpty, effectiveTitle.lowercased() != id.lowercased() {
            detail = await MusicService.shared.fetchCategoryDetail(id: effectiveTitle.lowercased(), serverURL: serverURL, token: token)
        }

        // 2. Also check if sections are sparse (< 2 sections or total items < 10, wie CategoryPage.tsx)
        let totalItems = detail?.sections.reduce(0) { $0 + $1.items.count } ?? 0
        var tracks: [Track] = []
        var pls: [DiscoveryPlaylist] = []
        var albs: [DiscoveryAlbum] = []

        if !sessionManager.isOfflineMode && (detail == nil || totalItems < 10) {
            if let search = await MusicService.shared.fetchDiscoverySearch(query: effectiveTitle, serverURL: serverURL, token: token) {
                tracks = search.tracks?.map { $0.toTrack() } ?? []
                pls = search.playlists ?? []
                albs = search.albums ?? []
            }
        }

        await MainActor.run {
            if let d = detail {
                self.categoryData = d
            }
            self.enrichedTracks = tracks
            self.enrichedPlaylists = pls
            self.enrichedAlbums = albs
            self.isLoading = false
        }
    }
}
