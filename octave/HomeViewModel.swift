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
}
