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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("portMusicSavedAlbumsChanged"))) { _ in
            Task {
                await loadSavedAlbums()
            }
        }
    }

    private func loadSavedAlbums() async {
        isLoading = true
        let token = SessionManager.shared.currentToken

        let collections = await MusicService.shared.fetchLibraryCollections(serverURL: serverURL, token: token)
        let localSaved = UserDefaults.standard.stringArray(forKey: "port_music_saved_albums") ?? []

        // Merge server savedAlbums + local saved albums without duplicates (case-insensitive)
        var rawEntries: [String] = []
        var rawSeen = Set<String>()
        for entry in (collections.savedAlbums + localSaved) {
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let lower = trimmed.lowercased()
            if rawSeen.insert(lower).inserted {
                rawEntries.append(trimmed)
            }
        }

        // Known tracks ONLY used as cover lookup fallback for saved albums (NOT to dump extra albums)
        let knownTracks = OfflineDownloadManager.shared.allDownloadedTracks()
            + collections.favorites
            + collections.globalTracks
            + collections.playlistTracksMap.values.flatMap { $0 }

        let lowerCoverMap: [String: String] = Dictionary(
            collections.albumCovers.map { ($0.key.lowercased(), $0.value) },
            uniquingKeysWith: { first, _ in first }
        )

        var parsedAlbums: [DiscoveryAlbum] = []
        var dedupKeys = Set<String>()

        for rawEntry in rawEntries {
            let titlePart: String
            let artistPart: String
            let targetAlbumId: String

            if rawEntry.contains("::") {
                let parts = rawEntry.components(separatedBy: "::")
                titlePart = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? rawEntry
                artistPart = parts.dropFirst().joined(separator: "::").trimmingCharacters(in: .whitespacesAndNewlines)
                targetAlbumId = "search:\(titlePart) \(artistPart)".trimmingCharacters(in: .whitespaces)
            } else if let range = rawEntry.range(of: " - ") {
                artistPart = String(rawEntry[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                titlePart = String(rawEntry[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                targetAlbumId = "search:\(titlePart) \(artistPart)".trimmingCharacters(in: .whitespaces)
            } else if rawEntry.hasPrefix("apple_") || rawEntry.hasPrefix("dz_") || rawEntry.allSatisfy(\.isNumber) {
                titlePart = rawEntry
                artistPart = ""
                targetAlbumId = rawEntry
            } else {
                titlePart = rawEntry
                artistPart = ""
                targetAlbumId = "search:\(titlePart)"
            }

            let dedupKey = "\(titlePart.lowercased())|\(artistPart.lowercased())"
            guard dedupKeys.insert(dedupKey).inserted else { continue }

            let mappedCover = collections.albumCovers[rawEntry] ?? lowerCoverMap[rawEntry.lowercased()]
            let fallbackTrack = knownTracks.first {
                ($0.album?.lowercased() ?? "") == titlePart.lowercased()
                && (artistPart.isEmpty || $0.artist.lowercased().contains(artistPart.lowercased()))
            }

            parsedAlbums.append(DiscoveryAlbum(
                id: targetAlbumId,
                title: titlePart,
                artist: artistPart.isEmpty ? (fallbackTrack?.artist ?? "") : artistPart,
                cover: (mappedCover?.isEmpty == false) ? mappedCover : fallbackTrack?.coverUrl,
                nbTracks: nil
            ))
        }

        await MainActor.run {
            self.albums = parsedAlbums
            self.isLoading = false
        }

        // Enrich any saved album whose cover or title is missing via discovery album lookup
        for item in parsedAlbums where (item.cover?.isEmpty ?? true) || item.id == item.title {
            if let detail = await MusicService.shared.fetchAlbum(id: item.id, serverURL: serverURL, token: token) {
                await MainActor.run {
                    if let idx = self.albums.firstIndex(where: { $0.id == item.id }) {
                        let existing = self.albums[idx]
                        self.albums[idx] = DiscoveryAlbum(
                            id: detail.id.isEmpty ? existing.id : detail.id,
                            title: existing.title == existing.id && !detail.title.isEmpty ? detail.title : existing.title,
                            artist: existing.artist.isEmpty ? detail.artist : existing.artist,
                            cover: (detail.cover?.isEmpty == false) ? detail.cover : existing.cover,
                            nbTracks: detail.nbTracks ?? existing.nbTracks
                        )
                    }
                }
            }
        }
    }
}
