import SwiftUI

public struct AppleCategoryDetailView: View {
    public let id: String
    public let title: String
    public let artworkUrl: String?
    public let bgColor: String?
    public let serverURL: String

    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var player = AudioPlayerManager.shared

    @State private var categoryData: AppleCategoryDetailData? = nil
    @State private var enrichedTracks: [Track] = []
    @State private var enrichedPlaylists: [DiscoveryPlaylist] = []
    @State private var enrichedAlbums: [DiscoveryAlbum] = []
    @State private var isLoading: Bool = true

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

    private var effectiveArtwork: String? {
        if let art = artworkUrl, !art.isEmpty {
            return art
        }
        return categoryData?.heroArtwork
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero Banner Header
                    heroBannerHeader

                    if isLoading && categoryData == nil && enrichedTracks.isEmpty {
                        loadingSection
                    } else {
                        contentSections
                    }

                    Spacer(minLength: 120)
                }
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .task {
            await loadCategoryDetails()
        }
    }

    // MARK: - Hero Banner Header
    private var heroBannerHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Color Base
            effectiveBgColor
                .frame(height: 260)

            // Artwork
            if let art = effectiveArtwork, let url = URL(string: art) {
                PortCachedAsyncImage(url: url) { img in
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: 260)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(effectiveBgColor)
                        .frame(height: 260)
                }
            }

            // Dark gradient overlay for typography readability
            LinearGradient(
                colors: [
                    Color.black.opacity(0.85),
                    Color.black.opacity(0.40),
                    Color.clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )

            // Header Content
            VStack(alignment: .leading, spacing: 14) {
                // Top Navigation Bar
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }

                    Spacer()
                }
                .padding(.top, 48)

                Spacer()

                // Category Title & Play Action
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kategorie")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.70))
                            .textCase(.uppercase)

                        Text(title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .shadow(color: Color.black.opacity(0.5), radius: 6, y: 2)
                    }

                    Spacer()

                    let playableTracks = allAvailableTracks
                    if !playableTracks.isEmpty {
                        Button(action: {
                            if let first = playableTracks.first {
                                player.play(track: first, from: playableTracks, serverURL: serverURL)
                            }
                        }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.black)
                                        .offset(x: 1.5)
                                )
                                .shadow(color: Color.black.opacity(0.4), radius: 8, y: 3)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(height: 260)
    }

    private var allAvailableTracks: [Track] {
        var result: [Track] = []
        if let sections = categoryData?.sections {
            for section in sections {
                for item in section.items where item.kind == "track" {
                    result.append(item.toTrack())
                }
            }
        }
        if result.isEmpty {
            result = enrichedTracks
        }
        return result
    }

    // MARK: - Loading View
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            Text("Kategorie wird geladen…")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.60))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Content Sections
    private var contentSections: some View {
        VStack(alignment: .leading, spacing: 28) {
            // 1. API Sections (if provided)
            if let sections = categoryData?.sections, !sections.isEmpty {
                ForEach(sections) { section in
                    renderSection(section)
                }
            }

            // 2. Enriched Songs (if category detail was sparse)
            if !enrichedTracks.isEmpty && (categoryData?.sections.isEmpty ?? true) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Beliebte Songs")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(PortColors.textPrimary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 6) {
                        ForEach(Array(enrichedTracks.prefix(20))) { track in
                            trackRow(track: track, queue: enrichedTracks)
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
                        .foregroundColor(PortColors.textPrimary)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(enrichedPlaylists) { pl in
                                NavigationLink(value: AppRoute.playlist(id: pl.id, title: pl.title, coverUrl: pl.cover)) {
                                    PortTrackCard(
                                        title: pl.title,
                                        subtitle: pl.user ?? "Playlist",
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
                        .padding(.horizontal, 20)
                    }
                }
            }

            // 4. Enriched Albums
            if !enrichedAlbums.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Beliebte Alben")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(PortColors.textPrimary)
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
                .foregroundColor(PortColors.textPrimary)
                .padding(.horizontal, 20)

            if !tracks.isEmpty {
                let trackModels = tracks.map { $0.toTrack() }
                VStack(spacing: 6) {
                    ForEach(tracks) { item in
                        trackRow(track: item.toTrack(), queue: trackModels)
                    }
                }
                .padding(.horizontal, 20)
            }

            if !otherItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(otherItems) { item in
                            if item.kind == "album" {
                                NavigationLink(value: AppRoute.album(id: item.id, title: item.title, artist: item.subtitle, coverUrl: item.cover)) {
                                    PortAlbumCard(
                                        title: item.title,
                                        subtitle: item.subtitle ?? "Album",
                                        coverUrl: item.cover,
                                        serverURL: serverURL
                                    ) {
                                        let dummy = item.toTrack()
                                        player.play(track: dummy, from: [dummy], serverURL: serverURL)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                NavigationLink(value: AppRoute.playlist(id: item.id, title: item.title, coverUrl: item.cover)) {
                                    PortTrackCard(
                                        title: item.title,
                                        subtitle: item.subtitle ?? "Playlist",
                                        coverUrl: item.cover,
                                        serverURL: serverURL
                                    ) {
                                        let dummy = item.toTrack()
                                        player.play(track: dummy, from: [dummy], serverURL: serverURL)
                                    }
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

    // MARK: - Track Row
    private func trackRow(track: Track, queue: [Track]) -> some View {
        let isCurrent = player.currentTrack?.id == track.id
        return Button(action: {
            player.play(track: track, from: queue, serverURL: serverURL)
        }) {
            HStack(spacing: 12) {
                let resolved = resolveCoverURL(track.coverUrl, serverURL: serverURL)
                PortCachedAsyncImage(url: resolved) { img in
                    img
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
                        .font(.system(size: 15, weight: .semibold))
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
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isCurrent ? Color.white.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Data Loading
    private func loadCategoryDetails() async {
        isLoading = true
        let token = SessionManager.shared.currentToken

        // 1. Fetch from /api/category/:id
        let detail = await MusicService.shared.fetchCategoryDetail(id: id, serverURL: serverURL, token: token)

        // 2. Also check if sections are sparse (< 2 sections or total items < 6)
        let totalItems = detail?.sections.reduce(0) { $0 + $1.items.count } ?? 0
        var tracks: [Track] = []
        var pls: [DiscoveryPlaylist] = []
        var albs: [DiscoveryAlbum] = []

        if detail == nil || totalItems < 6 {
            // Enrich from discovery search using the category title (just like web CategoryPage.tsx!)
            if let search = await MusicService.shared.fetchDiscoverySearch(query: title, serverURL: serverURL, token: token) {
                tracks = search.tracks?.map { $0.toTrack() } ?? []
                pls = search.playlists ?? []
                albs = search.albums ?? []
            }
        }

        await MainActor.run {
            self.categoryData = detail
            self.enrichedTracks = tracks
            self.enrichedPlaylists = pls
            self.enrichedAlbums = albs
            self.isLoading = false
        }
    }
}
