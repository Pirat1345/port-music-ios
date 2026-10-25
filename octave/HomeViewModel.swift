//
//  HomeViewModel.swift
//  octave
//

import Foundation
import Observation

@Observable
final class HomeViewModel {
    var featuredSongs: [SongEntity] = []
    var stations: [String] = ["Lo-Fi Beats", "Today's Hits", "Synthwave", "Chill Vibes", "Acoustic Pop"]
    var isLoading: Bool = false

    func loadHomeData() async {
        isLoading = true
        // Fetch recommendations from Octave API
        featuredSongs = [
            SongEntity(id: "1", title: "Midnight City", artist: "M83", albumTitle: "Hurry Up, We're Dreaming", durationSec: 243),
            SongEntity(id: "2", title: "Starboy", artist: "The Weeknd", albumTitle: "Starboy", durationSec: 230),
            SongEntity(id: "3", title: "Get Lucky", artist: "Daft Punk", albumTitle: "Random Access Memories", durationSec: 248),
            SongEntity(id: "4", title: "Blinding Lights", artist: "The Weeknd", albumTitle: "After Hours", durationSec: 200)
        ]
        isLoading = false
    }
}
