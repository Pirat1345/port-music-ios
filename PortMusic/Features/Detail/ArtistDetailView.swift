import SwiftUI

public struct ArtistDetailView: View {
    public let artistName: String
    public let initialCover: String?
    public let serverURL: String

    @ObservedObject private var player = AudioPlayerManager.shared
    @State private var artistData: DiscoveryArtistDetailData? = nil
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var isSaved: Bool = false

    private let savedArtistsKey = "port_music_saved_artists"

    public init(artistName: String, initialCover: String? = nil, serverURL: String) {
        self.artistName = artistName
        self.initialCover = initialCover
        self.serverURL = serverURL
    }

    private var displayCover: String? {
        artistData?.picture ?? initialCover
    }

    private var fanCountFormatted: String {
        if let fans = artistData?.nbFan, fans > 0 {
            if fans >= 1_000_000 {
                return String(format: "%.1fM monatliche Hörer", Double(fans) / 1_000_000.0)
            } else if fans >= 1_000 {
                return String(format: "%dK monatliche Hörer", fans / 1_000)
            } else {
                return "\(fans) monatliche Hörer"
            }
        }
        return "Verifizierter Künstler"
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── HERO BANNER HEADER ──
                    heroBannerHeader

                    // ── CONTENT SECTIONS ──
                    if isLoading && artistData == nil {
                        loadingSkeletonView
                            .padding(.top, 24)
                    } else if let error = errorMessage, artistData == nil {
                        errorStateView(error)
                            .padding(.top, 40)
                    } else if let data = artistData {
                        VStack(alignment: .leading, spacing: 32) {
                            // ── SECTION 1: TOP TRACKS (15+ TRACKS) ──
                            if !data.topTracks.isEmpty {
                                topTracksSection(tracks: data.topTracks)
                            }

                            // ── SECTION 2: ALBEN (30+ ALBEN) ──
                            if !data.albums.isEmpty {
                                albumsSection(albums: data.albums)
                            }

                            // ── SECTION 3: SINGLES & EPS ──
                            if !data.singles.isEmpty {
                                singlesSection(singles: data.singles)
                            }

                            // ── SECTION 4: ÄHNLICHE KÜNSTLER (RELATED) ──
                            if !data.related.isEmpty {
                                relatedArtistsSection(artists: data.related)
                            }
                        }
                        .padding(.top, 24)
                    }

                    // Puffer fuer Minibar & TabBar
                    Spacer(minLength: 120)
                }
            }
            .refreshable {
                await loadArtistData()
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .task {
            loadSavedStatus()
            await loadArtistData()
        }
    }

    // MARK: - Hero Banner Header
    private var heroBannerHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Hintergrundbild mit Weichzeichnung & Verlauf
            GeometryReader { geo in
                let width = geo.size.width
                let height = max(geo.size.height, 280)

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
                        Color(hex: "#18181b")
                    }

                    // Gradient Blend in #000000
                    LinearGradient(
                        stops: [
                            .init(color: Color.clear, location: 0.0),
                            .init(color: Color.black.opacity(0.35), location: 0.40),
                            .init(color: Color.black.opacity(0.85), location: 0.75),
                            .init(color: Color.black, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .frame(height: 290)

            // Header Content
            VStack(alignment: .leading, spacing: 8) {
                // Badge
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#3b82f6"))
                    Text("Verifizierter Künstler")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.85))
                }

                // Künstlername
                Text(artistName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .shadow(color: Color.black.opacity(0.8), radius: 6, y: 2)

                // Hörer / Fans
                Text(fanCountFormatted)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.70))

                // Action Controls Row
                HStack(spacing: 14) {
                    // Play All
                    Button(action: {
                        playAllTopTracks(shuffle: false)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Abspielen")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.3), radius: 6, y: 2)
                    }

                    // Shuffle
                    Button(action: {
                        playAllTopTracks(shuffle: true)
                    }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }

                    // Favorite / Follow
                    Button(action: toggleSaveArtist) {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isSaved ? Color(hex: "#fc3c44") : .white)
                            .padding(12)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }

                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(height: 290)
    }

    // MARK: - Section 1: Top Tracks (15+ Tracks)
    private func topTracksSection(tracks: [DiscoveryArtistTrackItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Beliebte Titel")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            VStack(spacing: 4) {
                ForEach(Array(tracks.prefix(15).enumerated()), id: \.element.id) { index, item in
                    let track = item.toTrack(fallbackCover: displayCover, fallbackAlbum: artistName)
                    let isPlayingThis = player.isPlaying && player.currentTrack?.id == track.id
                    let rankNumber = item.rank ?? (index + 1)

                    Button(action: {
                        playSelectedTrack(track: track, allItems: tracks)
                    }) {
                        HStack(spacing: 12) {
                            // Rank
                            Text("\(rankNumber)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(isPlayingThis ? Color(hex: "#fc3c44") : Color.white.opacity(0.45))
                                .frame(width: 24, alignment: .center)

                            // Thumbnail
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 44, height: 44)

                                let coverUrl = item.cover ?? displayCover
                                if let resolved = resolveCoverURL(coverUrl, serverURL: serverURL) {
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
                                }
                            }
                            .frame(width: 44, height: 44)

                            // Title & Details
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(isPlayingThis ? Color(hex: "#fc3c44") : .white)
                                        .lineLimit(1)

                                    if item.isExplicit == true {
                                        Text("E")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.white.opacity(0.85))
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                    }
                                }

                                Text(item.album ?? artistName)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.white.opacity(0.55))
                                    .lineLimit(1)
                            }

                            Spacer()

                            // Playing Indicator or Duration
                            if isPlayingThis {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: "#fc3c44"))
                            } else {
                                Text(item.duration ?? "0:00")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.45))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isPlayingThis ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isPlayingThis ? Color.white.opacity(0.20) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Section 2: Complete Albums (30+ Albums)
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
                            id: album.id,
                            title: album.title,
                            artist: album.artist ?? artistName,
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

                                    let subText = album.nbTracks.map { "\($0) Titel" } ?? "Album"
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

    // MARK: - Section 3: Singles & EPs
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
                            id: single.id,
                            title: single.title,
                            artist: single.artist ?? artistName,
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

                                    Text("Single")
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

    // MARK: - Section 4: Related Artists
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
                            coverUrl: related.picture
                        )) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "#18181b"))
                                        .frame(width: 110, height: 110)

                                    if let pic = related.picture, let resolved = resolveCoverURL(pic, serverURL: serverURL) {
                                        PortCachedAsyncImage(url: resolved) { img in
                                            img
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 110, height: 110)
                                                .clipShape(Circle())
                                        } placeholder: {
                                            Circle().fill(Color.white.opacity(0.10))
                                        }
                                    } else {
                                        Circle().fill(Color.white.opacity(0.10))
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

    // MARK: - Loading Skeleton
    private var loadingSkeletonView: some View {
        VStack(alignment: .leading, spacing: 20) {
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
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34))
                .foregroundColor(Color(hex: "#fc3c44"))

            Text("Künstler konnte nicht geladen werden")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Text(error)
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.60))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button(action: {
                Task { await loadArtistData() }
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

    // MARK: - Actions & API Call
    private func playAllTopTracks(shuffle: Bool) {
        guard let data = artistData, !data.topTracks.isEmpty else { return }
        var mapped = data.topTracks.map { $0.toTrack(fallbackCover: displayCover, fallbackAlbum: artistName) }
        if shuffle {
            mapped.shuffle()
        }
        if let first = mapped.first {
            player.play(track: first, from: mapped, serverURL: serverURL)
        }
    }

    private func playSelectedTrack(track: Track, allItems: [DiscoveryArtistTrackItem]) {
        let fullQueue = allItems.map { $0.toTrack(fallbackCover: displayCover, fallbackAlbum: artistName) }
        player.play(track: track, from: fullQueue, serverURL: serverURL)
    }

    private func loadSavedStatus() {
        if let saved = UserDefaults.standard.stringArray(forKey: savedArtistsKey) {
            isSaved = saved.contains(where: { $0.lowercased() == artistName.lowercased() })
        }
    }

    private func toggleSaveArtist() {
        var current = UserDefaults.standard.stringArray(forKey: savedArtistsKey) ?? []
        if isSaved {
            current.removeAll { $0.lowercased() == artistName.lowercased() }
            isSaved = false
        } else {
            current.append(artistName)
            isSaved = true
        }
        UserDefaults.standard.set(current, forKey: savedArtistsKey)
    }

    private func loadArtistData() async {
        isLoading = true
        errorMessage = nil

        let token = SessionManager.shared.currentToken
        if let data = await MusicService.shared.fetchArtist(name: artistName, serverURL: serverURL, token: token) {
            self.artistData = data
            self.isLoading = false
        } else {
            self.errorMessage = "Keine Verbindung zum Discovery-Dienst für \"\(artistName)\"."
            self.isLoading = false
        }
    }
}
