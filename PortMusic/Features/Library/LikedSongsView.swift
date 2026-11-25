import SwiftUI

public enum LikedSongsSortMode: String, CaseIterable, Identifiable {
    case recentlyAdded = "Kürzlich hinzugefügt"
    case title = "Titel"
    case artist = "Künstler"
    case album = "Album"
    case duration = "Dauer"

    public var id: String { rawValue }
}

// MARK: - Liked Songs View (Feature #14)
public struct LikedSongsView: View {
    public let serverURL: String

    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @State private var favorites: [Track] = []
    @State private var isLoading: Bool = true
    @State private var searchQuery: String = ""
    @State private var sortMode: LikedSongsSortMode = .recentlyAdded

    // Navigation State
    @State private var selectedArtist: String? = nil
    @State private var selectedAlbum: String? = nil

    public init(serverURL: String) {
        self.serverURL = serverURL
    }

    private var isPlayingFavorites: Bool {
        guard let current = player.currentTrack else { return false }
        return player.isPlaying && favorites.contains(where: { $0.id == current.id })
    }

    private var totalDurationString: String {
        let totalSecs = favorites.reduce(0.0) { acc, t in
            if t.durationSeconds > 0 { return acc + t.durationSeconds }
            let parts = t.duration.split(separator: ":").compactMap { Double($0) }
            if parts.count == 2 { return acc + parts[0] * 60 + parts[1] }
            return acc + 180
        }
        let totalMins = Int(totalSecs) / 60
        let hours = totalMins / 60
        let mins = totalMins % 60
        if hours > 0 {
            return "\(hours) Std. \(mins) Min."
        } else {
            return "\(mins) Min."
        }
    }

    private var isAllLikedDownloaded: Bool {
        guard !favorites.isEmpty else { return false }
        return favorites.allSatisfy { offlineManager.isDownloaded(trackId: $0.id) }
    }

    private func toggleDownloadLikedSongs() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        let token = SessionManager.shared.currentToken

        if isAllLikedDownloaded {
            for t in favorites {
                offlineManager.removeDownload(trackId: t.id)
            }
        } else {
            offlineManager.downloadPlaylist(
                playlistId: "liked_songs",
                name: "Lieblingssongs",
                tracks: favorites,
                serverURL: serverURL,
                token: token
            )
        }
    }

    private var processedTracks: [Track] {
        var list = favorites
        switch sortMode {
        case .recentlyAdded:
            break
        case .title:
            list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .artist:
            list.sort { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
        case .album:
            list.sort { ($0.album ?? "").localizedCaseInsensitiveCompare($1.album ?? "") == .orderedAscending }
        case .duration:
            list.sort { $0.durationSeconds > $1.durationSeconds }
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.title.lowercased().contains(query) ||
                $0.artist.lowercased().contains(query) ||
                ($0.album?.lowercased().contains(query) ?? false)
            }
        }
        return list
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // Soft Ambient Top Backdrop
            VStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#450af5").opacity(0.45),
                        Color(hex: "#8e8ee5").opacity(0.18),
                        Color.clear
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 380)
                .ignoresSafeArea(edges: .top)

                Spacer()
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // ── HERO BANNER ──
                    heroBannerSection
                        .padding(.top, 10)

                    // ── ACTION BAR (Play All, Shuffle, Sort, Search) ──
                    actionBarSection
                        .padding(.horizontal, 20)

                    // ── TRACKLIST ──
                    tracklistSection

                    // Spacer fuer Minibar
                    Spacer(minLength: 120)
                }
            }
            .refreshable {
                await loadFavorites()
            }
        }
        .navigationTitle("Lieblingssongs")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .tint(.white)
        .task {
            await loadFavorites()
        }
        .onReceive(NotificationCenter.default.publisher(for: .portMusicDidReconnect)) { _ in
            Task {
                await loadFavorites()
            }
        }
        .onReceive(FavoritesManager.shared.$cachedFavoriteTracks) { updated in
            if SessionManager.shared.isOfflineMode || !updated.isEmpty {
                self.favorites = updated
            }
        }
    }

    // MARK: - Hero Banner Section
    private var heroBannerSection: some View {
        VStack(spacing: 16) {
            // Grosses Cover Artwork mit Purple Gradient
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#450af5"), Color(hex: "#8e8ee5")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtiler Schattenverlauf
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.40)]),
                    startPoint: .top,
                    endPoint: .bottom
                )

                Image(systemName: "heart.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
            }
            .frame(width: 180, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.60), radius: 16, y: 6)

            // Titel & Metadaten
            VStack(spacing: 5) {
                Text("Lieblingssongs")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Text("\(favorites.count) Songs")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.70))

                    if !favorites.isEmpty {
                        Text("•")
                            .foregroundColor(Color.white.opacity(0.40))
                        Text(totalDurationString)
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.55))
                    }
                }
            }
        }
    }

    // MARK: - Action Bar Section
    private var actionBarSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                // Play All Button
                Button(action: {
                    let tracks = processedTracks
                    guard !tracks.isEmpty else { return }
                    if isPlayingFavorites {
                        player.togglePlayPause()
                    } else {
                        player.playAll(tracks: tracks, shuffle: false, serverURL: serverURL)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isPlayingFavorites ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(isPlayingFavorites ? "Pause" : "Alle abspielen")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.3), radius: 6, y: 2)
                }
                .buttonStyle(PlainButtonStyle())

                // Shuffle Button
                Button(action: {
                    let tracks = processedTracks
                    guard !tracks.isEmpty else { return }
                    player.playAll(tracks: tracks, shuffle: true, serverURL: serverURL)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Download All Liked Songs Toggle
                Button(action: toggleDownloadLikedSongs) {
                    Image(systemName: isAllLikedDownloaded ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isAllLikedDownloaded ? Color(hex: "#00d26a") : .white)
                        .padding(12)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())

                // Sort Dropdown Menu
                Menu {
                    ForEach(LikedSongsSortMode.allCases) { mode in
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            sortMode = mode
                        }) {
                            HStack {
                                Text(mode.rawValue)
                                if sortMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Inline Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.40))

                TextField("In Lieblingssongs suchen...", text: $searchQuery)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.40))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
    }

    // MARK: - Tracklist Section
    private var tracklistSection: some View {
        VStack(spacing: 4) {
            let tracks = processedTracks

            if tracks.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 40))
                        .foregroundColor(Color.white.opacity(0.25))
                    Text(searchQuery.isEmpty ? "Noch keine Lieblingssongs markiert" : "Keine Treffer gefunden")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        TrackRowView(
                            track: track,
                            index: index,
                            contextQueue: tracks,
                            serverURL: serverURL,
                            isLiked: true,
                            isDownloaded: false,
                            showCover: true,
                            onToggleLike: {
                                if let idx = favorites.firstIndex(where: { $0.id == track.id }) {
                                    favorites.remove(at: idx)
                                }
                            },
                            onSelectArtist: { artist in
                                selectedArtist = artist
                            },
                            onSelectAlbum: { album in
                                selectedAlbum = album
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Load Favorites
    private func loadFavorites() async {
        isLoading = true
        let cacheKey = "port_music_cached_favorites_v1"

        // Sofort Cache (inkl. lokaler Offline-Likes/-Unlikes) vorladen
        if !FavoritesManager.shared.cachedFavoriteTracks.isEmpty {
            await MainActor.run {
                self.favorites = FavoritesManager.shared.cachedFavoriteTracks
            }
        } else if let data = UserDefaults.standard.data(forKey: cacheKey),
                  let cached = try? JSONDecoder().decode([Track].self, from: data), !cached.isEmpty {
            await MainActor.run {
                self.favorites = cached
            }
        }

        if SessionManager.shared.isOfflineMode {
            let offlineFavs = OfflineDownloadManager.shared.allDownloadedTracks().filter {
                FavoritesManager.shared.isFavorite(trackId: $0.id)
            }
            await MainActor.run {
                if !FavoritesManager.shared.cachedFavoriteTracks.isEmpty {
                    self.favorites = FavoritesManager.shared.cachedFavoriteTracks
                } else if self.favorites.isEmpty {
                    self.favorites = offlineFavs
                }
                self.isLoading = false
            }
            return
        }

        let token = SessionManager.shared.currentToken
        let fetched = await MusicService.shared.fetchFavorites(serverURL: serverURL, token: token)
        await MainActor.run {
            if !SessionManager.shared.isOfflineMode {
                self.favorites = fetched
                if let encoded = try? JSONEncoder().encode(fetched) {
                    UserDefaults.standard.set(encoded, forKey: cacheKey)
                }
            } else if !FavoritesManager.shared.cachedFavoriteTracks.isEmpty {
                self.favorites = FavoritesManager.shared.cachedFavoriteTracks
            } else if self.favorites.isEmpty {
                self.favorites = OfflineDownloadManager.shared.allDownloadedTracks().filter {
                    FavoritesManager.shared.isFavorite(trackId: $0.id)
                }
            }
            self.isLoading = false
        }
    }
}
