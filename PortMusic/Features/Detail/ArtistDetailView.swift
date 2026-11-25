import SwiftUI
import AVKit

public struct ArtistDetailView: View {
    public let artistName: String
    public let initialCover: String?
    public let serverURL: String

    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var favoritesManager = FavoritesManager.shared

    @State private var artistData: DiscoveryArtistDetailData? = nil
    @State private var allFetchedTracks: [DiscoveryArtistTrackItem] = []
    @State private var localFallbackTracks: [Track] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var isSaved: Bool = false
    @State private var bioExpanded: Bool = false
    @State private var showAllTracksSheet: Bool = false
    @State private var selectedVideo: DiscoveryArtistVideoItem? = nil

    private let savedArtistsKey = "port_music_saved_artists"

    public init(artistName: String, initialCover: String? = nil, serverURL: String) {
        self.artistName = artistName
        self.initialCover = initialCover
        self.serverURL = serverURL
    }

    private var displayName: String {
        if let name = artistData?.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        return artistName
    }

    private func isBadPlaceholder(_ url: String?) -> Bool {
        guard let u = url?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty else {
            return true
        }
        let lower = u.lowercased()
        return lower.contains("52ab317011e8e6f8748ec3b7d9f38ddd")
            || lower.contains("0f30bbd33a680030054af004d698d6")
            || lower.contains("d41d8cd98f00b204e9800998ecf8427e")
            || lower.contains("default_artist")
            || lower.contains("default-cover")
            || lower.contains("silhouette")
    }

    private var displayCover: String? {
        if let pic = artistData?.picture, !isBadPlaceholder(pic) {
            return pic
        }
        if let initCov = initialCover, !isBadPlaceholder(initCov) {
            return initCov
        }
        if let albCov = artistData?.albums.first?.cover, !isBadPlaceholder(albCov) {
            return albCov
        }
        if let trCov = artistData?.topTracks.first?.cover, !isBadPlaceholder(trCov) {
            return trCov
        }
        if let localFirst = localFallbackTracks.first {
            if let localFile = offlineManager.localCoverFileURL(for: localFirst.id) {
                return localFile.absoluteString
            }
            if let cov = localFirst.coverUrl, !isBadPlaceholder(cov) {
                return cov
            }
        }
        return nil
    }

    private var fanCountFormatted: String {
        let isBand = (artistData?.artistType ?? "").lowercased() == "group"
        let prefix = isBand ? "Band" : "Künstler"
        if let fans = artistData?.nbFan, fans > 0 {
            if fans >= 1_000_000 {
                return String(format: "%@ · %.1f Mio. Fans", prefix, Double(fans) / 1_000_000.0)
            } else if fans >= 1_000 {
                return String(format: "%@ · %dK Fans", prefix, fans / 1_000)
            } else {
                return "\(prefix) · \(fans) Fans"
            }
        }
        return sessionManager.isOfflineMode ? "\(prefix) · Offline-Modus" : "Verifizierter \(prefix)"
    }

    private var effectiveTrackItems: [DiscoveryArtistTrackItem] {
        let baseOnline = !allFetchedTracks.isEmpty ? allFetchedTracks : (artistData?.topTracks ?? [])
        var seenIds = Set<String>()
        var seenTitleKeys = Set<String>()
        var merged: [DiscoveryArtistTrackItem] = []

        func cleanKey(_ title: String) -> String {
            let noParen = title
                .replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\[[^\\]]*\\]", with: "", options: .regularExpression)
            return noParen.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 1. Offline heruntergeladene Titel bevorzugen / mit Online-Katalog vereinen
        for item in baseOnline {
            seenIds.insert(item.id)
            let key = cleanKey(item.title)
            if !key.isEmpty { seenTitleKeys.insert(key) }
            merged.append(item)
        }

        for local in localFallbackTracks {
            if seenIds.contains(local.id) { continue }
            let key = cleanKey(local.title)
            if !key.isEmpty && seenTitleKeys.contains(key) { continue }
            seenIds.insert(local.id)
            if !key.isEmpty { seenTitleKeys.insert(key) }
            merged.append(DiscoveryArtistTrackItem(
                id: local.id,
                title: local.title,
                artist: local.artist,
                album: local.album,
                duration: local.duration,
                durationSeconds: local.durationSeconds,
                cover: local.coverUrl,
                isExplicit: local.isExplicit,
                rank: merged.count + 1,
                trackNumber: nil,
                sourceUrl: local.sourceUrl
            ))
        }

        return merged
    }

    private var isArtistCurrentlyPlaying: Bool {
        guard player.isPlaying, let cur = player.currentTrack else { return false }
        return Self.matchesArtist(cur.artist, target: displayName) || Self.matchesArtist(cur.artist, target: artistName)
    }

    private var latestReleaseItem: DiscoveryArtistAlbumItem? {
        artistData?.singles.first ?? artistData?.albums.first
    }

    private var cleanedDescription: String? {
        guard let raw = artistData?.description?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let lower = raw.lowercased()
        if lower.contains("join the genius community")
            || lower.contains("meaning behind the lyrics")
            || lower.contains("get all the lyrics to songs by")
            || lower.contains("read all lyrics by")
            || lower.contains("music scholars to learn the meaning") {
            return nil
        }
        return raw
    }

    private var formattedCountry: String? {
        guard let raw = artistData?.country?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if raw.count == 2 {
            let loc = Locale(identifier: "de_DE")
            if let localized = loc.localizedString(forRegionCode: raw.uppercased()) {
                return localized
            }
        }
        return raw
    }

    private var formattedBeginDate: String? {
        guard let raw = artistData?.beginDate?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM-dd"
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        if let date = inFmt.date(from: raw) {
            let outFmt = DateFormatter()
            outFmt.dateStyle = .long
            outFmt.locale = Locale(identifier: "de_DE")
            return outFmt.string(from: date)
        }
        return raw
    }

    private var hasAboutInfo: Bool {
        cleanedDescription != nil
            || formattedCountry != nil
            || formattedBeginDate != nil
            || (artistData?.nbFan ?? 0) > 0
            || artistData?.wikiUrl != nil
            || artistData?.mbid != nil
    }

    public var body: some View {
        ScrollViewReader { scrollProxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ── HERO BANNER HEADER ──
                        heroBannerHeader(scrollProxy: scrollProxy)

                        // ── CONTENT SECTIONS ──
                        let tracksToRender = effectiveTrackItems
                        let hasOfflineFallbackOnly = (artistData == nil && !localFallbackTracks.isEmpty)

                        if isLoading && artistData == nil && localFallbackTracks.isEmpty {
                            loadingSkeletonView
                                .padding(.top, 24)
                        } else if let error = errorMessage, artistData == nil && localFallbackTracks.isEmpty {
                            errorStateView(error)
                                .padding(.top, 40)
                        } else {
                            VStack(alignment: .leading, spacing: 28) {
                                if sessionManager.isOfflineMode || hasOfflineFallbackOnly {
                                    offlineNoticeBanner(trackCount: localFallbackTracks.count)
                                        .padding(.horizontal, 20)
                                }

                                // ── LATEST RELEASE SPOTLIGHT ──
                                if let latest = latestReleaseItem, !sessionManager.isOfflineMode {
                                    latestReleaseSection(release: latest)
                                }

                                // ── SECTION 1: TOP TRACKS ──
                                if !tracksToRender.isEmpty {
                                    topTracksSection(tracks: tracksToRender)
                                } else if !isLoading {
                                    noTracksEmptyCard
                                        .padding(.horizontal, 20)
                                }

                                // ── SECTION 2: ALBEN ──
                                if let albums = artistData?.albums, !albums.isEmpty {
                                    albumsSection(albums: albums)
                                }

                                // ── SECTION 3: SINGLES & EPS ──
                                if let singles = artistData?.singles, !singles.isEmpty {
                                    singlesSection(singles: singles)
                                }

                                // ── SECTION 4: TOP VIDEOS ──
                                if let videos = artistData?.videos, !videos.isEmpty {
                                    videosSection(videos: videos)
                                }

                                // ── SECTION 5: ARTIST PLAYLISTS ──
                                if let playlists = artistData?.playlists, !playlists.isEmpty {
                                    playlistsSection(playlists: playlists)
                                }

                                // ── SECTION 6: ÄHNLICHE KÜNSTLER ──
                                if let related = artistData?.related, !related.isEmpty {
                                    relatedArtistsSection(artists: related)
                                }

                                // ── SECTION 7: ÜBER DEN KÜNSTLER ──
                                if hasAboutInfo {
                                    aboutSection
                                        .id("about_section")
                                }
                            }
                            .padding(.top, 20)
                        }

                        // Puffer fuer Minibar & TabBar
                        Spacer(minLength: 130)
                    }
                }
                .refreshable {
                    await loadArtistData()
                }
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .tint(.white)
        .task(id: artistName) {
            loadSavedStatus()
            localFallbackTracks = computeLocalArtistTracks()
            if artistData == nil, let cached = MusicService.shared.cachedArtist(name: artistName) {
                artistData = cached
            }
            await loadArtistData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .portMusicDidReconnect)) { _ in
            Task {
                await loadArtistData()
            }
        }
        .sheet(isPresented: $showAllTracksSheet) {
            ArtistAllTracksSheet(
                artistName: displayName,
                fallbackCover: displayCover,
                initialTracks: effectiveTrackItems,
                serverURL: serverURL
            )
        }
        .sheet(item: $selectedVideo) { video in
            ArtistVideoPlayerSheet(video: video)
        }
    }

    // MARK: - Hero Banner Header (Octave Aesthetic)
    private func heroBannerHeader(scrollProxy: ScrollViewProxy) -> some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = max(geo.size.height, 310)

                ZStack {
                    Color(hex: "#121214")

                    if let cover = displayCover, let resolved = resolveCoverURL(cover, serverURL: serverURL) {
                        PortCachedAsyncImage(url: resolved) { img in
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: width, height: height)
                                .clipped()
                        } placeholder: {
                            Color(hex: "#18181b")
                        }
                    } else {
                        LinearGradient(
                            colors: [Color(hex: "#27272a"), Color(hex: "#09090b")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }

                    // Sanfter Octave-Gradient nach Schwarz
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.18), location: 0.0),
                            .init(color: Color.black.opacity(0.12), location: 0.28),
                            .init(color: Color.black.opacity(0.65), location: 0.65),
                            .init(color: Color.black.opacity(0.92), location: 0.88),
                            .init(color: Color.black, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .frame(height: 320)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#3b82f6"))
                    Text((artistData?.artistType ?? "").lowercased() == "group" ? "Verifizierte Band" : "Verifizierter Künstler")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.88))
                }

                Text(displayName)
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)
                    .multilineTextAlignment(.leading)
                    .shadow(color: Color.black.opacity(0.85), radius: 8, y: 2)

                Text(fanCountFormatted)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.75))

                HStack(spacing: 12) {
                    // Play / Pause All
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if isArtistCurrentlyPlaying {
                            player.togglePlayPause()
                        } else {
                            playAllTopTracks(shuffle: false)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isArtistCurrentlyPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text(isArtistCurrentlyPlaying ? "Pause" : "Abspielen")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)
                    }
                    .disabled(effectiveTrackItems.isEmpty)
                    .opacity(effectiveTrackItems.isEmpty ? 0.55 : 1.0)

                    // Shuffle
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        playAllTopTracks(shuffle: true)
                    }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    }
                    .disabled(effectiveTrackItems.isEmpty)
                    .opacity(effectiveTrackItems.isEmpty ? 0.55 : 1.0)

                    // Save / Follow Artist
                    Button(action: toggleSaveArtist) {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isSaved ? Color(hex: "#fc3c44") : .white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    }

                    // Scroll to About Section
                    if hasAboutInfo {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.45)) {
                                scrollProxy.scrollTo("about_section", anchor: .top)
                            }
                        }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.14))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )
                        }
                    }

                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(height: 320)
    }

    // MARK: - Offline Notice Banner
    private func offlineNoticeBanner(trackCount: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(PortColors.accentOrange)
            Text(trackCount > 0
                 ? "Offline-Ansicht · \(trackCount) gespeicherte Titel verfügbar"
                 : "Offline-Modus · Keine Verbindung zum Discovery-Server")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(Color.white.opacity(0.88))
                .lineLimit(2)
            Spacer()
            if trackCount == 0 {
                Button("Neu laden") {
                    Task {
                        _ = await sessionManager.retryConnection()
                        await loadArtistData()
                    }
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Latest Release Spotlight
    private func latestReleaseSection(release: DiscoveryArtistAlbumItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: AppRoute.album(
                id: Self.normalizedAlbumRouteId(release.id),
                title: release.title,
                artist: release.artist ?? displayName,
                coverUrl: release.cover
            )) {
                HStack(spacing: 14) {
                    PortCoverImage(
                        coverUrl: release.cover,
                        serverURL: serverURL,
                        placeholderIcon: "opticaldisc"
                    )
                    .frame(width: 82, height: 82)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("NEUESTES RELEASE")
                            .font(.system(size: 10.5, weight: .heavy))
                            .tracking(0.8)
                            .foregroundColor(Color.white.opacity(0.55))

                        Text(release.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        Text(release.year.map { "\($0)" } ?? "Single / Album")
                            .font(.system(size: 12.5))
                            .foregroundColor(Color.white.opacity(0.55))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Section 1: Top Tracks (15+ Tracks + Alle Anzeigen Sheet)
    private func topTracksSection(tracks: [DiscoveryArtistTrackItem]) -> some View {
        let fullQueue = tracks.map { $0.toTrack(fallbackCover: displayCover, fallbackAlbum: displayName) }

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Beliebte Titel")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if tracks.count > 10 {
                    Button(action: {
                        showAllTracksSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Text("Alle (\(tracks.count))")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(Color.white.opacity(0.65))
                    }
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 6) {
                ForEach(Array(tracks.prefix(15).enumerated()), id: \.element.id) { index, item in
                    let track = item.toTrack(fallbackCover: displayCover, fallbackAlbum: displayName)
                    ArtistTopTrackRow(
                        track: track,
                        rank: item.rank ?? (index + 1),
                        contextQueue: fullQueue,
                        serverURL: serverURL,
                        albumSubtitle: item.album ?? displayName
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var noTracksEmptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.system(size: 26))
                .foregroundColor(Color.white.opacity(0.35))
            Text("Keine Top-Titel verfügbar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Section 2: Complete Albums (mit normalisierter dz_ ID!)
    private func albumsSection(albums: [DiscoveryArtistAlbumItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Alben")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(albums) { album in
                        NavigationLink(value: AppRoute.album(
                            id: Self.normalizedAlbumRouteId(album.id),
                            title: album.title,
                            artist: album.artist ?? displayName,
                            coverUrl: album.cover
                        )) {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .topLeading) {
                                    PortCoverImage(
                                        coverUrl: album.cover,
                                        serverURL: serverURL,
                                        placeholderIcon: "opticaldisc"
                                    )
                                    .frame(width: 155, height: 155)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))

                                    if let year = album.year {
                                        Text("\(year)")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(Color.black.opacity(0.75))
                                            .clipShape(Capsule())
                                            .padding(8)
                                    }
                                }
                                .frame(width: 155, height: 155)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.35), radius: 8, y: 3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(album.title)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(PortColors.textPrimary)
                                        .lineLimit(1)
                                        .frame(width: 155, alignment: .leading)

                                    let subText = album.nbTracks.map { "\($0) Titel" } ?? (album.year.map { "\($0) · Album" } ?? "Album")
                                    Text(subText)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#a0a0a0"))
                                        .lineLimit(1)
                                        .frame(width: 155, alignment: .leading)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Section 3: Singles & EPs (mit normalisierter dz_ ID!)
    private func singlesSection(singles: [DiscoveryArtistAlbumItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Singles & EPs")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(singles) { single in
                        NavigationLink(value: AppRoute.album(
                            id: Self.normalizedAlbumRouteId(single.id),
                            title: single.title,
                            artist: single.artist ?? displayName,
                            coverUrl: single.cover
                        )) {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .topLeading) {
                                    PortCoverImage(
                                        coverUrl: single.cover,
                                        serverURL: serverURL,
                                        placeholderIcon: "music.note"
                                    )
                                    .frame(width: 140, height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                    if let year = single.year {
                                        Text("\(year)")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.black.opacity(0.75))
                                            .clipShape(Capsule())
                                            .padding(6)
                                    }
                                }
                                .frame(width: 140, height: 140)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(single.title)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(PortColors.textPrimary)
                                        .lineLimit(1)
                                        .frame(width: 140, alignment: .leading)

                                    Text(single.year.map { "\($0) · Single" } ?? "Single")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#a0a0a0"))
                                        .lineLimit(1)
                                        .frame(width: 140, alignment: .leading)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Section 4: Top Videos
    private func videosSection(videos: [DiscoveryArtistVideoItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Top-Videos")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(videos) { video in
                        Button(action: {
                            handleVideoTap(video)
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(hex: "#18181b"))
                                        .frame(width: 224, height: 126)

                                    if let thumb = video.thumbnail, let resolved = resolveCoverURL(thumb, serverURL: serverURL) {
                                        PortCachedAsyncImage(url: resolved) { img in
                                            img
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 224, height: 126)
                                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                        } placeholder: {
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(Color.white.opacity(0.08))
                                                .frame(width: 224, height: 126)
                                        }
                                    }

                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.55))
                                            .frame(width: 42, height: 42)
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .offset(x: 1.5)
                                    }
                                }
                                .frame(width: 224, height: 126)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.4), radius: 6, y: 2)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(video.title)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(PortColors.textPrimary)
                                        .lineLimit(1)
                                        .frame(width: 224, alignment: .leading)

                                    Text(video.artist.isEmpty ? displayName : video.artist)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#a0a0a0"))
                                        .lineLimit(1)
                                        .frame(width: 224, alignment: .leading)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Section 5: Artist Playlists
    private func playlistsSection(playlists: [DiscoveryArtistPlaylistItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Playlists mit \(displayName)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(playlists) { pl in
                        NavigationLink(value: AppRoute.playlist(
                            id: Self.normalizedPlaylistRouteId(pl.id),
                            title: pl.title,
                            coverUrl: pl.cover
                        )) {
                            VStack(alignment: .leading, spacing: 8) {
                                PortCoverImage(
                                    coverUrl: pl.cover,
                                    serverURL: serverURL,
                                    placeholderIcon: "music.note.list"
                                )
                                .frame(width: 148, height: 148)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.35), radius: 8, y: 3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pl.title)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(PortColors.textPrimary)
                                        .lineLimit(1)
                                        .frame(width: 148, alignment: .leading)

                                    Text("Playlist")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#a0a0a0"))
                                        .lineLimit(1)
                                        .frame(width: 148, alignment: .leading)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Section 6: Related Artists
    private func relatedArtistsSection(artists: [DiscoveryRelatedArtistItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ähnliche Künstler")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(artists) { related in
                        NavigationLink(value: AppRoute.artist(
                            name: related.name,
                            coverUrl: isBadPlaceholder(related.picture) ? nil : related.picture
                        )) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "#18181b"))
                                        .frame(width: 110, height: 110)

                                    if let pic = related.picture, !isBadPlaceholder(pic),
                                       let resolved = resolveCoverURL(pic, serverURL: serverURL) {
                                        PortCachedAsyncImage(url: resolved) { img in
                                            img
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 110, height: 110)
                                                .clipShape(Circle())
                                        } placeholder: {
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(Color.white.opacity(0.28))
                                        }
                                    } else {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(Color.white.opacity(0.28))
                                    }
                                }
                                .frame(width: 110, height: 110)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)

                                VStack(spacing: 2) {
                                    Text(related.name)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .frame(width: 110)

                                    Text("Künstler")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#a0a0a0"))
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Section 7: Über den Künstler (Bio & Metadaten)
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Über \(displayName)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 14) {
                if let bio = cleanedDescription {
                    Text(bio)
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.82))
                        .lineSpacing(4)
                        .lineLimit(bioExpanded ? nil : 4)

                    if bio.count > 220 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                bioExpanded.toggle()
                            }
                        }) {
                            Text(bioExpanded ? "Weniger anzeigen" : "Mehr lesen")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }

                // Metadaten-Pills & Externe Links
                let pills = buildMetadataPills()
                if !pills.isEmpty || artistData?.wikiUrl != nil || artistData?.mbid != nil {
                    if cleanedDescription != nil {
                        Divider()
                            .background(Color.white.opacity(0.10))
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(pills, id: \.self) { label in
                                Text(label)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.10))
                                    .clipShape(Capsule())
                            }

                            if let wikiStr = artistData?.wikiUrl, let wikiUrl = URL(string: wikiStr) {
                                Link(destination: wikiUrl) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.system(size: 11))
                                        Text("Wikipedia")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.10))
                                    .clipShape(Capsule())
                                }
                            }

                            if let mbid = artistData?.mbid, !mbid.isEmpty,
                               let mbUrl = URL(string: "https://musicbrainz.org/artist/\(mbid)") {
                                Link(destination: mbUrl) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.system(size: 11))
                                        Text("MusicBrainz")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.10))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
    }

    private func buildMetadataPills() -> [String] {
        var result: [String] = []
        let isBand = (artistData?.artistType ?? "").lowercased() == "group"
        if let country = formattedCountry {
            result.append("Herkunft: \(country)")
        }
        if let begin = formattedBeginDate {
            result.append(isBand ? "Gegründet: \(begin)" : "Geboren: \(begin)")
        }
        if let fans = artistData?.nbFan, fans > 0 {
            if fans >= 1_000_000 {
                result.append(String(format: "%.1f Mio. Fans", Double(fans) / 1_000_000.0))
            } else if fans >= 1_000 {
                result.append("\(fans / 1_000)K Fans")
            } else {
                result.append("\(fans) Fans")
            }
        }
        return result
    }

    // MARK: - Loading Skeleton
    private var loadingSkeletonView: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 24, height: 20)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 160, height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 100, height: 12)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Error State
    private func errorStateView(_ error: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: sessionManager.isOfflineMode ? "wifi.slash" : "exclamationmark.triangle.fill")
                .font(.system(size: 34))
                .foregroundColor(sessionManager.isOfflineMode ? PortColors.accentOrange : Color(hex: "#fc3c44"))

            Text(sessionManager.isOfflineMode ? "Künstler offline nicht verfügbar" : "Künstler konnte nicht geladen werden")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Text(error)
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.60))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button(action: {
                Task {
                    if sessionManager.isOfflineMode {
                        _ = await sessionManager.retryConnection()
                    }
                    await loadArtistData()
                }
            }) {
                Text("Erneut versuchen")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Helpers & Actions
    private static func normalizedAlbumRouteId(_ rawId: String) -> String {
        let trimmed = rawId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed.allSatisfy(\.isNumber) {
            return "dz_\(trimmed)"
        }
        return trimmed
    }

    private static func normalizedPlaylistRouteId(_ rawId: String) -> String {
        let trimmed = rawId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed.allSatisfy(\.isNumber) {
            return "dz_\(trimmed)"
        }
        return trimmed
    }

    private static func matchesArtist(_ candidate: String, target: String) -> Bool {
        let candLower = candidate.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let targLower = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !candLower.isEmpty, !targLower.isEmpty else { return false }
        if candLower == targLower { return true }
        let parts = candLower.components(separatedBy: CharacterSet(charactersIn: ",;/&"))
        for part in parts {
            let cleaned = part
                .replacingOccurrences(of: "^(feat\\.?|ft\\.?)\\s*", with: "", options: [.regularExpression, .caseInsensitive])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned == targLower || cleaned.contains(targLower) || (cleaned.count >= 3 && targLower.contains(cleaned)) {
                return true
            }
        }
        return candLower.contains(targLower)
    }

    private func computeLocalArtistTracks() -> [Track] {
        let downloaded = offlineManager.allDownloadedTracks()
        let cachedFavs = favoritesManager.cachedFavoriteTracks
        let recent = player.recentTracks

        var seen = Set<String>()
        var matches: [Track] = []
        for t in (downloaded + cachedFavs + recent) {
            guard Self.matchesArtist(t.artist, target: artistName) else { continue }
            if !seen.contains(t.id) {
                seen.insert(t.id)
                matches.append(t)
            }
        }
        return matches
    }

    private func handleVideoTap(_ video: DiscoveryArtistVideoItem) {
        if let preview = video.previewUrl, !preview.isEmpty {
            if player.isPlaying {
                player.pause()
            }
            selectedVideo = video
        } else {
            let cleanQuery = "\(video.title) \(video.artist.isEmpty ? displayName : video.artist)"
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let vidTrack = Track(
                id: "search:\(cleanQuery)",
                title: video.title,
                artist: video.artist.isEmpty ? displayName : video.artist,
                album: "Musikvideo",
                duration: "0:00",
                durationSeconds: 0,
                coverUrl: video.thumbnail ?? displayCover,
                isLive: false,
                isExplicit: false
            )
            player.play(track: vidTrack, from: [vidTrack], serverURL: serverURL)
        }
    }

    private func playAllTopTracks(shuffle: Bool) {
        let items = effectiveTrackItems
        guard !items.isEmpty else { return }
        var mapped = items.map { $0.toTrack(fallbackCover: displayCover, fallbackAlbum: displayName) }
        if shuffle && mapped.count > 1 {
            mapped.shuffle()
        }
        if let first = mapped.first {
            player.play(track: first, from: mapped, serverURL: serverURL)
        }
    }

    private func loadSavedStatus() {
        if let saved = UserDefaults.standard.stringArray(forKey: savedArtistsKey) {
            isSaved = saved.contains(where: { $0.lowercased() == artistName.lowercased() })
        }
    }

    private func toggleSaveArtist() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var current = UserDefaults.standard.stringArray(forKey: savedArtistsKey) ?? []
        let targetName = displayName
        if isSaved {
            current.removeAll {
                $0.lowercased() == artistName.lowercased() || $0.lowercased() == targetName.lowercased()
            }
            isSaved = false
        } else {
            if !current.contains(where: { $0.lowercased() == targetName.lowercased() }) {
                current.append(targetName)
            }
            isSaved = true
        }
        UserDefaults.standard.set(current, forKey: savedArtistsKey)

        let desired = isSaved
        let token = SessionManager.shared.currentToken
        Task {
            await MusicService.shared.syncSavedArtistState(
                artistName: targetName,
                isSaved: desired,
                serverURL: serverURL,
                token: token
            )
        }
    }

    private func loadArtistData() async {
        isLoading = true
        errorMessage = nil
        localFallbackTracks = computeLocalArtistTracks()

        let token = SessionManager.shared.currentToken

        if sessionManager.isOfflineMode {
            if let cached = MusicService.shared.cachedArtist(name: artistName) {
                self.artistData = cached
            }
            if artistData == nil && localFallbackTracks.isEmpty {
                self.errorMessage = "Keine Internetverbindung und keine gespeicherten Songs von \"\(artistName)\" vorhanden."
            }
            self.isLoading = false
            return
        }

        if let data = await MusicService.shared.fetchArtist(name: artistName, serverURL: serverURL, token: token) {
            self.artistData = data
            self.allFetchedTracks = data.topTracks
            self.isLoading = false

            // Synchronisiere gespeicherten Kuenstlerstatus mit dem Server im Hintergrund
            Task {
                let col = await MusicService.shared.fetchLibraryCollections(serverURL: serverURL, token: token)
                if !col.savedArtists.isEmpty {
                    let serverMatch = col.savedArtists.contains {
                        $0.lowercased() == data.name.lowercased() || $0.lowercased() == artistName.lowercased()
                    }
                    await MainActor.run {
                        self.isSaved = serverMatch
                        var localList = UserDefaults.standard.stringArray(forKey: savedArtistsKey) ?? []
                        if serverMatch && !localList.contains(where: { $0.lowercased() == data.name.lowercased() }) {
                            localList.append(data.name)
                            UserDefaults.standard.set(localList, forKey: savedArtistsKey)
                        }
                    }
                }
            }
        } else {
            // Letzter Rettungsversuch ueber /api/discovery/artist/:name/tracks
            let fallbackTracks = await MusicService.shared.fetchArtistTracks(name: artistName, serverURL: serverURL, token: token)
            if !fallbackTracks.isEmpty {
                self.allFetchedTracks = fallbackTracks
                self.artistData = DiscoveryArtistDetailData(
                    id: artistName,
                    name: artistName,
                    picture: fallbackTracks.first?.cover ?? initialCover,
                    topTracks: fallbackTracks
                )
            } else if self.artistData == nil && self.localFallbackTracks.isEmpty {
                self.errorMessage = "Keine Verbindung zum Discovery-Dienst für \"\(artistName)\"."
            }
            self.isLoading = false
        }
    }
}

// MARK: - Numbered Interactive Track Row on Artist Page
private struct ArtistTopTrackRow: View {
    public let track: Track
    public let rank: Int
    public let contextQueue: [Track]
    public let serverURL: String
    public let albumSubtitle: String

    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var favoritesManager = FavoritesManager.shared

    @State private var showShareSheet: Bool = false

    private var isPlayingThis: Bool {
        player.currentTrack?.id == track.id
    }

    private var isUnavailableOffline: Bool {
        sessionManager.isOfflineMode && !offlineManager.isDownloaded(trackId: track.id) && !track.isLive
    }

    private var isLiked: Bool {
        favoritesManager.isFavorite(trackId: track.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                .foregroundColor(isPlayingThis ? Color(hex: "#fc3c44") : Color.white.opacity(0.45))
                .frame(width: 24, alignment: .center)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 44, height: 44)

                let localCover = offlineManager.localCoverFileURL(for: track.id)
                let resolved = localCover ?? resolveCoverURL(track.coverUrl, serverURL: serverURL)
                PortCachedAsyncImage(url: resolved) { img in
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    Image(systemName: "music.note")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.40))
                }

                if isPlayingThis {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.60))
                            .frame(width: 44, height: 44)
                        if player.isPlaying {
                            EqualizerBarsView(color: Color(hex: "#fc3c44"))
                        } else {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: "#fc3c44"))
                        }
                    }
                }
            }
            .frame(width: 44, height: 44)
            .opacity(isUnavailableOffline ? 0.42 : 1.0)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(track.title)
                        .font(.system(size: 14, weight: isPlayingThis ? .bold : .semibold))
                        .foregroundColor(isPlayingThis ? Color(hex: "#fc3c44") : .white)
                        .lineLimit(1)

                    if track.isExplicit {
                        Text("E")
                            .font(.system(size: 8.5, weight: .heavy))
                            .foregroundColor(.black)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                HStack(spacing: 4) {
                    if offlineManager.isDownloaded(trackId: track.id) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#10b981"))
                    } else if isUnavailableOffline {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.35))
                    }

                    Text(albumSubtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.55))
                        .lineLimit(1)

                    if track.duration != "0:00" && !track.duration.isEmpty {
                        Text("·")
                            .foregroundColor(Color.white.opacity(0.35))
                        Text(track.duration)
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.45))
                    }
                }
            }
            .opacity(isUnavailableOffline ? 0.45 : 1.0)

            Spacer(minLength: 4)

            HStack(spacing: 2) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    let desired = !isLiked
                    FavoritesManager.shared.enqueueMutation(track: track, isFavorite: desired)
                    let token = SessionManager.shared.currentToken
                    Task {
                        _ = await MusicService.shared.toggleFavorite(
                            track: track,
                            desiredState: desired,
                            serverURL: serverURL,
                            token: token
                        )
                    }
                }) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isLiked ? Color(hex: "#fc3c44") : Color.white.opacity(0.42))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                Menu {
                    if offlineManager.isDownloaded(trackId: track.id) {
                        Button(role: .destructive) {
                            offlineManager.removeDownload(trackId: track.id)
                        } label: {
                            Label("Download entfernen", systemImage: "trash")
                        }
                    } else if offlineManager.isDownloading(trackId: track.id) {
                        Button(action: {}) {
                            Label("Wird heruntergeladen...", systemImage: "arrow.down.circle")
                        }
                        .disabled(true)
                    } else {
                        Button {
                            Task {
                                await offlineManager.downloadTrack(
                                    track: track,
                                    serverURL: serverURL,
                                    token: SessionManager.shared.currentToken
                                )
                            }
                        } label: {
                            Label("Herunterladen", systemImage: "arrow.down.circle")
                        }
                    }

                    Divider()

                    Button {
                        player.playNext(track: track)
                    } label: {
                        Label("Als nächstes abspielen", systemImage: "text.insert")
                    }

                    Button {
                        player.addToQueue(track: track)
                    } label: {
                        Label("Zur Warteschlange hinzufügen", systemImage: "text.append")
                    }

                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.55))
                        .frame(width: 30, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isPlayingThis ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPlayingThis ? Color.white.opacity(0.20) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isPlayingThis {
                player.togglePlayPause()
            } else {
                player.play(track: track, from: contextQueue, serverURL: serverURL)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [
                "Höre '\(track.title)' von \(track.artist) auf Port Music",
                serverURL
            ])
        }
    }
}

// MARK: - Full Artist Tracks Sheet (Alle Top-Titel durchsuchen & sortieren)
private struct ArtistAllTracksSheet: View {
    public let artistName: String
    public let fallbackCover: String?
    public let initialTracks: [DiscoveryArtistTrackItem]
    public let serverURL: String

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var player = AudioPlayerManager.shared
    @State private var searchQuery: String = ""
    @State private var sortMode: Int = 0 // 0 = Beliebtheit, 1 = Titel, 2 = Dauer

    private var mappedTracks: [Track] {
        var list = initialTracks.map { $0.toTrack(fallbackCover: fallbackCover, fallbackAlbum: artistName) }
        if sortMode == 1 {
            list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        } else if sortMode == 2 {
            list.sort { $0.durationSeconds > $1.durationSeconds }
        }
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.title.lowercased().contains(q)
                    || $0.artist.lowercased().contains(q)
                    || ($0.album?.lowercased().contains(q) ?? false)
            }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color.white.opacity(0.45))
                            TextField("Titel durchsuchen...", text: $searchQuery)
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                            if !searchQuery.isEmpty {
                                Button(action: { searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color.white.opacity(0.45))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)

                        HStack(spacing: 10) {
                            Button(action: {
                                let list = mappedTracks
                                if let first = list.first {
                                    player.play(track: first, from: list, serverURL: serverURL)
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                    Text("Alle abspielen")
                                        .fontWeight(.bold)
                                }
                                .font(.system(size: 13))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .clipShape(Capsule())
                            }

                            Button(action: {
                                var list = mappedTracks
                                if list.count > 1 { list.shuffle() }
                                if let first = list.first {
                                    player.play(track: first, from: list, serverURL: serverURL)
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "shuffle")
                                    Text("Zufall")
                                        .fontWeight(.bold)
                                }
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)

                        Picker("Sortierung", selection: $sortMode) {
                            Text("Beliebtheit").tag(0)
                            Text("Titel").tag(1)
                            Text("Dauer").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)

                        let tracks = mappedTracks
                        LazyVStack(spacing: 4) {
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                                TrackRowView(
                                    track: track,
                                    index: index,
                                    contextQueue: tracks,
                                    serverURL: serverURL,
                                    isLiked: FavoritesManager.shared.isFavorite(trackId: track.id),
                                    showCover: true,
                                    showTrackNumber: true
                                )
                            }
                        }
                        .padding(.horizontal, 14)

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("\(artistName) · Alle Titel")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - In-App Video Preview Player Sheet
private struct ArtistVideoPlayerSheet: View {
    public let video: DiscoveryArtistVideoItem
    @Environment(\.dismiss) private var dismiss
    @State private var avPlayer: AVPlayer? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let player = avPlayer {
                    VideoPlayer(player: player)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationTitle(video.title)
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        avPlayer?.pause()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                if let urlStr = video.previewUrl, let url = URL(string: urlStr) {
                    let p = AVPlayer(url: url)
                    self.avPlayer = p
                    p.play()
                }
            }
            .onDisappear {
                avPlayer?.pause()
                avPlayer = nil
            }
        }
    }
}
