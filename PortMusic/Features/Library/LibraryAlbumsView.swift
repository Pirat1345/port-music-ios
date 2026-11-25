import SwiftUI

// MARK: - Library Albums View (Mirrors Web LibraryAlbumsPage.tsx)
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
            $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
        }
    }

    public var body: some View {
        Group {
            if isLoading && albums.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
            } else if filteredAlbums.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.stack")
                        .font(.system(size: 36))
                        .foregroundColor(Color.white.opacity(0.30))
                    Text(albums.isEmpty ? "Noch keine Alben in deiner Mediathek" : "Keine Alben gefunden")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.60))
                    Text("Speichere Alben oder like Songs, um sie hier gesammelt anzuzeigen.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.40))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 16
                ) {
                    ForEach(filteredAlbums) { album in
                        NavigationLink(value: AppRoute.album(
                            id: album.id,
                            title: album.title,
                            artist: album.artist,
                            coverUrl: album.cover
                        )) {
                            VStack(alignment: .leading, spacing: 6) {
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
                                        Image(systemName: "square.stack")
                                            .font(.system(size: 30))
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

                                Text(album.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Text(album.artist.isEmpty ? "Album" : album.artist)
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
        .task {
            await loadSavedAlbums()
        }
    }

    private func loadSavedAlbums() async {
        isLoading = true
        let token = SessionManager.shared.currentToken

        async let collectionsTask = MusicService.shared.fetchLibraryCollections(serverURL: serverURL, token: token)
        async let historyTask = MusicService.shared.fetchStatsAndHistory(serverURL: serverURL, token: token)
        let (collections, history) = await (collectionsTask, historyTask)

        var albumMap: [String: DiscoveryAlbum] = [:]
        var orderedKeys: [String] = []

        func registerTrackAlbum(_ t: Track) {
            guard let alb = t.album?.trimmingCharacters(in: .whitespacesAndNewlines), !alb.isEmpty else { return }
            let key = alb.lowercased()
            if albumMap[key] == nil {
                albumMap[key] = DiscoveryAlbum(
                    id: "search:\(alb) \(t.artist)",
                    title: alb,
                    artist: t.artist,
                    cover: t.coverUrl,
                    nbTracks: nil
                )
                orderedKeys.append(key)
            } else if let existing = albumMap[key], (existing.cover?.isEmpty ?? true), let cov = t.coverUrl, !cov.isEmpty {
                albumMap[key] = DiscoveryAlbum(
                    id: existing.id,
                    title: existing.title,
                    artist: existing.artist,
                    cover: cov,
                    nbTracks: existing.nbTracks
                )
            }
        }

        // 1. Gespeicherte Alben aus /api/state (savedAlbums)
        let allKnownTracks = OfflineDownloadManager.shared.allDownloadedTracks()
            + collections.favorites
            + collections.globalTracks
            + collections.playlistTracksMap.values.flatMap { $0 }
            + history

        for rawEntry in collections.savedAlbums {
            let trimmed = rawEntry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            // Unterstuetzt sowohl "Album Name" als auch "Artist — Album" / IDs
            let titlePart: String
            let artistPart: String
            if let range = trimmed.range(of: " - ") {
                artistPart = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                titlePart = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else {
                artistPart = ""
                titlePart = trimmed
            }
            let key = titlePart.lowercased()
            if albumMap[key] == nil {
                let matchingTrack = allKnownTracks.first { ($0.album?.lowercased() ?? "") == key }
                albumMap[key] = DiscoveryAlbum(
                    id: trimmed.hasPrefix("apple_") || trimmed.hasPrefix("dz_") ? trimmed : "search:\(titlePart) \(artistPart)",
                    title: titlePart,
                    artist: matchingTrack?.artist ?? artistPart,
                    cover: matchingTrack?.coverUrl,
                    nbTracks: nil
                )
                orderedKeys.append(key)
            }
        }

        // 2. Alben aus Favoriten, Downloads, Playlists und Verlauf
        for t in allKnownTracks {
            registerTrackAlbum(t)
        }

        let initialList = orderedKeys.compactMap { albumMap[$0] }
        await MainActor.run {
            self.albums = initialList
            self.isLoading = false
        }
    }
}
