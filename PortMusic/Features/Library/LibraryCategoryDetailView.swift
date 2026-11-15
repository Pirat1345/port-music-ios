import SwiftUI

// MARK: - Library Category Detail View
public struct LibraryCategoryDetailView: View {
    public let category: String
    public let serverURL: String

    @ObservedObject private var player = AudioPlayerManager.shared
    @State private var playlists: [DiscoveryPlaylist] = []
    @State private var artists: [DiscoveryArtist] = []
    @State private var tracks: [Track] = []
    @State private var isLoading: Bool = true
    @State private var searchQuery: String = ""

    public init(category: String, serverURL: String) {
        self.category = category
        self.serverURL = serverURL
    }

    private var viewTitle: String {
        switch category {
        case "playlists", "Playlists", "Wiedergabelisten":
            return "Wiedergabelisten"
        case "artists", "Artists", "Künstler":
            return "Künstler"
        case "albums", "Albums", "Alben":
            return "Alben"
        case "songs", "Songs", "Titel":
            return "Titel"
        case "downloaded", "Downloads", "Heruntergeladen":
            return "Heruntergeladen"
        case "history", "Verlauf", "Zuletzt gehört":
            return "Zuletzt gehört"
        default:
            return category
        }
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // Search Bar
                    searchBarSection
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    // Category Specific Content
                    categoryContentSection
                        .padding(.horizontal, 20)

                    Spacer(minLength: 120)
                }
            }
            .refreshable {
                await loadCategoryData()
            }
        }
        .navigationTitle(viewTitle)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .tint(.white)
        .task {
            await loadCategoryData()
        }
    }

    // MARK: - Search Bar
    private var searchBarSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.40))

            TextField("\(viewTitle) durchsuchen...", text: $searchQuery)
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
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Category Content Switcher
    @ViewBuilder
    private var categoryContentSection: some View {
        switch category {
        case "playlists", "Playlists", "Wiedergabelisten":
            playlistsView
        case "artists", "Artists", "Künstler":
            artistsView
        case "albums", "Albums", "Alben":
            LibraryAlbumsView(serverURL: serverURL)
        case "songs", "Songs", "Titel":
            tracksListView
        case "downloaded", "Downloads", "Heruntergeladen":
            tracksListView
        case "history", "Verlauf", "Zuletzt gehört":
            tracksListView
        default:
            tracksListView
        }
    }

    // MARK: - Playlists View
    private var playlistsView: some View {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = q.isEmpty ? playlists : playlists.filter { $0.title.lowercased().contains(q) }

        return Group {
            if isLoading && playlists.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
            } else if filtered.isEmpty {
                emptyPlaceholder(icon: "music.note.list", message: "Keine Playlists gefunden")
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 16
                ) {
                    ForEach(filtered) { pl in
                        NavigationLink(value: AppRoute.playlist(
                            id: pl.id,
                            title: pl.title,
                            coverUrl: pl.cover
                        )) {
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
                                .shadow(color: Color.black.opacity(0.40), radius: 6, y: 3)

                                Text(pl.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                let count = pl.nbTracks.map { "\($0) Songs" } ?? "Playlist"
                                Text(count)
                                    .font(.system(size: 12))
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

    // MARK: - Artists View
    private var artistsView: some View {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = q.isEmpty ? artists : artists.filter { $0.name.lowercased().contains(q) }

        return Group {
            if isLoading && artists.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
            } else if filtered.isEmpty {
                emptyPlaceholder(icon: "person.2", message: "Keine Künstler gefunden")
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 16
                ) {
                    ForEach(filtered) { artist in
                        NavigationLink(value: AppRoute.artist(name: artist.name, coverUrl: artist.picture)) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "#18181b"))
                                        .frame(width: 90, height: 90)

                                    let resolved = resolveCoverURL(artist.picture, serverURL: serverURL)
                                    PortCachedAsyncImage(url: resolved) { img in
                                        img
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 90, height: 90)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(Color.white.opacity(0.30))
                                    }
                                }
                                .frame(width: 90, height: 90)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.40), radius: 6, y: 3)

                                Text(artist.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Tracks List View
    private var tracksListView: some View {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = q.isEmpty ? tracks : tracks.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q) ||
            ($0.album?.lowercased().contains(q) ?? false)
        }

        return Group {
            if isLoading && tracks.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
            } else if filtered.isEmpty {
                emptyPlaceholder(icon: "music.note", message: "Keine Titel vorhanden")
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, track in
                        TrackRowView(
                            track: track,
                            index: index,
                            contextQueue: filtered,
                            serverURL: serverURL,
                            isLiked: false,
                            isDownloaded: category == "downloaded" || category == "Heruntergeladen",
                            showCover: true,
                            showTrackNumber: false
                        )
                    }
                }
            }
        }
    }

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

    // MARK: - Load Category Data
    private func loadCategoryData() async {
        isLoading = true
        let token = SessionManager.shared.currentToken

        switch category {
        case "playlists", "Playlists", "Wiedergabelisten":
            let userPls = await MusicService.shared.fetchPlaylists(serverURL: serverURL, token: token)
            await MainActor.run {
                self.playlists = userPls
                self.isLoading = false
            }

        case "artists", "Artists", "Künstler":
            var artistList: [DiscoveryArtist] = []
            var seen = Set<String>()
            if let discovery = await MusicService.shared.fetchHomeDiscovery(serverURL: serverURL, token: token),
               let trend = discovery.trendingArtists {
                for a in trend {
                    seen.insert(a.name.lowercased())
                    artistList.append(a)
                }
            }
            let favs = await MusicService.shared.fetchFavorites(serverURL: serverURL, token: token)
            for f in favs {
                let name = f.artist
                if !seen.contains(name.lowercased()) && !name.isEmpty {
                    seen.insert(name.lowercased())
                    artistList.append(DiscoveryArtist(id: "art_\(name.hashValue)", name: name, picture: f.coverUrl, nbFan: nil))
                }
            }
            await MainActor.run {
                self.artists = artistList
                self.isLoading = false
            }

        case "songs", "Songs", "Titel":
            let favs = await MusicService.shared.fetchFavorites(serverURL: serverURL, token: token)
            let history = await MusicService.shared.fetchStatsAndHistory(serverURL: serverURL, token: token)
            var combined = favs
            for h in history {
                if !combined.contains(where: { $0.id == h.id }) {
                    combined.append(h)
                }
            }
            await MainActor.run {
                self.tracks = combined
                self.isLoading = false
            }

        case "downloaded", "Downloads", "Heruntergeladen":
            // Offline downloaded tracks
            let recent = AudioPlayerManager.shared.recentTracks
            await MainActor.run {
                self.tracks = recent
                self.isLoading = false
            }

        case "history", "Verlauf", "Zuletzt gehört":
            let hists = await MusicService.shared.fetchStatsAndHistory(serverURL: serverURL, token: token)
            let tracksToUse = !hists.isEmpty ? hists : AudioPlayerManager.shared.recentTracks
            await MainActor.run {
                self.tracks = tracksToUse
                self.isLoading = false
            }

        default:
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
