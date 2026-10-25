//
//  LibraryIndex.swift
//  octave
//

import Foundation
import Observation

@Observable
final class LibraryIndex {
    static let shared = LibraryIndex()
    var savedSongIds: Set<String> = []
    var savedAlbums: [String] = []

    func isSaved(songId: String) -> Bool {
        savedSongIds.contains(songId)
    }

    func toggleSave(songId: String) {
        if savedSongIds.contains(songId) {
            savedSongIds.remove(songId)
        } else {
            savedSongIds.insert(songId)
        }
    }
}
