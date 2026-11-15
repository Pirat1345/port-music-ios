import SwiftUI

// MARK: - Library Albums View (Feature #13)
public struct LibraryAlbumsView: View {
    public let serverURL: String

    @State private var albums: [DiscoveryAlbum] = []
    @State private var isLoading: Bool = true
    @State private var searchQuery: String = ""

    public init(serverURL: String) {
        self.serverURL = serverURL
    }

    private var filteredAlbums: [DiscoveryAlbum] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return albums }
        return albums.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q)
        }
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Search Bar
                    searchBarSection
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    // Albums Grid
                    albumsGridSection
                        .padding(.horizontal, 20)

                    // Spacer fuer Minibar
                    Spacer(minLength: 120)
                }
            }
            .refreshable {
                await loadAlbums()
            }
        }
        .navigationTitle("Alben")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .tint(.white)
        .task {
            await loadAlbums()
        }
    }

    // MARK: - Search Bar
    private var searchBarSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.40))

            TextField("Alben durchsuchen...", text: $searchQuery)
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

    // MARK: - Albums Grid Section
    private var albumsGridSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isLoading && albums.isEmpty {
                loadingSkeletonView
            } else if filteredAlbums.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.stack")
                        .font(.system(size: 40))
                        .foregroundColor(Color.white.opacity(0.30))
                    Text(searchQuery.isEmpty ? "Keine Alben in der Bibliothek vorhanden" : "Keine Alben gefunden")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.60))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 18
                ) {
                    ForEach(filteredAlbums) { album in
                        NavigationLink(value: AppRoute.album(
                            id: album.id,
                            title: album.title,
                            artist: album.artist,
                            coverUrl: album.cover
                        )) {
                            albumGridCard(album: album)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Album Grid Card
    private func albumGridCard(album: DiscoveryAlbum) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#18181b"))
                    .aspectRatio(1, contentMode: .fit)

                let resolved = resolveCoverURL(album.cover, serverURL: serverURL)
                PortCachedAsyncImage(url: resolved) { img in
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } placeholder: {
                    Image(systemName: "opticaldisc")
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

            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(album.artist)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#a0a0a0"))
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Loading Skeleton
    private var loadingSkeletonView: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ],
            spacing: 18
        ) {
            ForEach(0..<6, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .aspectRatio(1, contentMode: .fit)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 80, height: 10)
                }
            }
        }
    }

    // MARK: - Load Albums Data
    private func loadAlbums() async {
        isLoading = true
        let token = SessionManager.shared.currentToken

        // 1. Fetch Discovery Albums
        async let discoveryFetch = MusicService.shared.fetchHomeDiscovery(serverURL: serverURL, token: token)
        async let favFetch = MusicService.shared.fetchFavorites(serverURL: serverURL, token: token)
        async let historyFetch = MusicService.shared.fetchStatsAndHistory(serverURL: serverURL, token: token)

        let (discovery, favs, history) = await (discoveryFetch, favFetch, historyFetch)

        var combinedAlbums: [DiscoveryAlbum] = []
        var seenKeys = Set<String>()

        func addAlbum(id: String, title: String, artist: String, cover: String?) {
            let key = "\(title.lowercased())_\(artist.lowercased())"
            guard !seenKeys.contains(key), !title.isEmpty else { return }
            seenKeys.insert(key)
            combinedAlbums.append(DiscoveryAlbum(
                id: id,
                title: title,
                artist: artist,
                cover: cover,
                nbTracks: nil
            ))
        }

        // From Discovery
        if let topAlbums = discovery?.topAlbums {
            for a in topAlbums {
                addAlbum(id: a.id, title: a.title, artist: a.artist, cover: a.cover)
            }
        }
        if let newMusic = discovery?.newMusic {
            for a in newMusic {
                addAlbum(id: a.id, title: a.title, artist: a.artist, cover: a.cover)
            }
        }
        if let trendingAlbums = discovery?.trendingAlbums {
            for a in trendingAlbums {
                addAlbum(id: a.id, title: a.title, artist: a.artist, cover: a.cover)
            }
        }

        // From Favorites & History
        for t in (favs + history + AudioPlayerManager.shared.recentTracks) {
            if let albumName = t.album, !albumName.isEmpty {
                addAlbum(id: "alb_\(albumName.hashValue)", title: albumName, artist: t.artist, cover: t.coverUrl)
            }
        }

        await MainActor.run {
            self.albums = combinedAlbums
            self.isLoading = false
        }
    }
}
