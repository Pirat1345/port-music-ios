//
//  LibraryIndex.swift
//  Port Music
//
//  Index and persistence for saved library items and favorites.
//

import Foundation
import Observation

@Observable
final class LibraryIndex: @unchecked Sendable {
    static let shared = LibraryIndex()

    var savedSongIds: Set<String> = []
    var savedSongs: [SongEntity] = []
    var savedAlbums: [String] = []

    private let userDefaultsIdsKey = "octave_saved_song_ids"
    private let userDefaultsSongsKey = "octave_saved_songs"

    init() {
        loadFromPersistence()
    }

    // MARK: - Query

    func isSaved(id: String) -> Bool {
        savedSongIds.contains(id)
    }

    func isSaved(songId: String) -> Bool {
        savedSongIds.contains(songId)
    }

    // MARK: - Bulk State Update (Aufgerufen von DataSyncManager)

    @MainActor
    func setFavorites(_ songs: [SongEntity]) {
        self.savedSongs = songs
        self.savedSongIds = Set(songs.map { $0.id })
        saveToPersistence()
    }

    // MARK: - Asynchrone Mutation mit optimistischem UI-Update und Rollback

    @MainActor
    func toggle(song: SongEntity) async {
        let wasSaved = isSaved(id: song.id)

        // 1. Optimistisches UI-Update
        if wasSaved {
            savedSongIds.remove(song.id)
            savedSongs.removeAll(where: { $0.id == song.id })
        } else {
            savedSongIds.insert(song.id)
            if !savedSongs.contains(where: { $0.id == song.id }) {
                savedSongs.append(song)
            }
        }
        saveToPersistence()

        // 2. Synchronisation mit Backend
        do {
            if wasSaved {
                _ = try await OctaveBackend.shared.removeFavorite(id: song.id)
            } else {
                _ = try await OctaveBackend.shared.addFavorite(song: song)
            }
        } catch {
            print("[LibraryIndex] Synchronisation des Favoriten fehlgeschlagen (\(error.localizedDescription)). Rollback wird ausgefuehrt...")
            // 3. Rollback bei Fehler
            if wasSaved {
                savedSongIds.insert(song.id)
                if !savedSongs.contains(where: { $0.id == song.id }) {
                    savedSongs.append(song)
                }
            } else {
                savedSongIds.remove(song.id)
                savedSongs.removeAll(where: { $0.id == song.id })
            }
            saveToPersistence()
        }
    }

    @MainActor
    func add(song: SongEntity) async {
        guard !isSaved(id: song.id) else { return }
        await toggle(song: song)
    }

    @MainActor
    func remove(id: String) async {
        guard isSaved(id: id) else { return }
        if let song = savedSongs.first(where: { $0.id == id }) {
            await toggle(song: song)
        } else {
            let placeholder = SongEntity(
                id: id,
                title: "",
                artist: "",
                artworkURLString: nil,
                albumTitle: nil,
                durationSec: 0.0
            )
            await toggle(song: placeholder)
        }
    }

    @MainActor
    func clear() {
        self.savedSongIds = []
        self.savedSongs = []
        saveToPersistence()
    }

    // MARK: - Lokale Persistenz

    private func loadFromPersistence() {
        if let ids = UserDefaults.standard.stringArray(forKey: userDefaultsIdsKey) {
            self.savedSongIds = Set(ids)
        }
        if let data = UserDefaults.standard.data(forKey: userDefaultsSongsKey),
           let decoded = try? JSONDecoder().decode([SongEntity].self, from: data) {
            self.savedSongs = decoded
        }
    }

    private func saveToPersistence() {
        UserDefaults.standard.set(Array(savedSongIds), forKey: userDefaultsIdsKey)
        if let data = try? JSONEncoder().encode(savedSongs) {
            UserDefaults.standard.set(data, forKey: userDefaultsSongsKey)
        }
    }
}
