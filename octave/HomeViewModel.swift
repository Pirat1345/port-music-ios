//
//  HomeViewModel.swift
//  Port Music
//
//  ViewModel for Port Music Home: loads real Discovery data and user playlists.
//

import Foundation
import Observation

enum HomeFilterTab: String, CaseIterable, Identifiable {
    case all = "Alle"
    case music = "Musik"
    case playlists = "Playlists"
    case artists = "Künstler"

    var id: String { rawValue }
}

@Observable
final class HomeViewModel: @unchecked Sendable {
    var discovery: DiscoveryHomeResponse?
    var userPlaylists: [PlaylistRecord] = []
    var activeFilter: HomeFilterTab = .all
    var isLoading: Bool = false
    var errorMessage: String?

    func loadHomeData() async {
        isLoading = true
        errorMessage = nil

        async let discoveryFetch = try? OctaveBackend.shared.fetchDiscoveryHome()
        async let playlistsFetch = try? OctaveBackend.shared.fetchUserPlaylists()

        let (disc, pls) = await (discoveryFetch, playlistsFetch)
        self.discovery = disc
        self.userPlaylists = pls ?? []
        self.isLoading = false
    }

    func buildCombinedHomePool(initialSong: SongEntity) -> [SongEntity] {
        var pool: [SongEntity] = [initialSong]
        var seen = Set<String>([initialSong.id])

        if let picks = discovery?.topPicks {
            for p in picks {
                if !seen.contains(p.id) {
                    seen.insert(p.id)
                    pool.append(SongEntity(
                        id: p.id,
                        title: p.title,
                        artist: p.subtitle ?? "Port Music",
                        artworkURLString: p.cover
                    ))
                }
            }
        }
        if let trending = discovery?.trendingEverywhere {
            for t in trending {
                let entity = t.toSongEntity()
                if !seen.contains(entity.id) {
                    seen.insert(entity.id)
                    pool.append(entity)
                }
            }
        }
        if let hits = discovery?.todaysTopHits {
            for h in hits {
                let entity = h.track.toSongEntity()
                if !seen.contains(entity.id) {
                    seen.insert(entity.id)
                    pool.append(entity)
                }
            }
        }
        if let top100 = discovery?.top100Global {
            for t in top100 {
                let entity = t.track.toSongEntity()
                if !seen.contains(entity.id) {
                    seen.insert(entity.id)
                    pool.append(entity)
                }
            }
        }
        return pool
    }
}
