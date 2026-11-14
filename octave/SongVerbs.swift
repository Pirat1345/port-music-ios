//
//  SongVerbs.swift
//  Port Music
//

import Foundation

struct SongVerbs {
    @MainActor
    static func playNext(song: SongEntity) {
        AudioPlayer.shared.insertNext(song: song)
    }

    @MainActor
    static func addToLibrary(song: SongEntity) {
        Task {
            await LibraryIndex.shared.add(song: song)
        }
    }

    @MainActor
    static func toggleFavorite(song: SongEntity) {
        Task {
            await LibraryIndex.shared.toggle(song: song)
        }
    }
}
