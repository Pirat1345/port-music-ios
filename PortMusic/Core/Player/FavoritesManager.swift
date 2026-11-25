import Foundation

public struct PendingFavoriteMutation: Codable, Equatable {
    public let track: Track
    public let isFavorite: Bool
    public let timestamp: Date
}

@MainActor
public final class FavoritesManager: ObservableObject {
    public static let shared = FavoritesManager()

    @Published public private(set) var favoritedTrackIds: Set<String> = []
    @Published public private(set) var cachedFavoriteTracks: [Track] = []
    @Published public private(set) var pendingMutations: [String: PendingFavoriteMutation] = [:]

    private let storageKey = "port_music_favorited_track_ids"
    private let cachedTracksKey = "port_music_cached_favorites_v1"
    private let pendingMutationsKey = "port_music_pending_fav_mutations_v1"
    private var isFlushingPending: Bool = false

    private init() {
        if let saved = UserDefaults.standard.stringArray(forKey: storageKey) {
            self.favoritedTrackIds = Set(saved)
        }
        if let cachedData = UserDefaults.standard.data(forKey: cachedTracksKey),
           let decoded = try? JSONDecoder().decode([Track].self, from: cachedData) {
            self.cachedFavoriteTracks = decoded
        }
        if let pendingData = UserDefaults.standard.data(forKey: pendingMutationsKey),
           let decodedPending = try? JSONDecoder().decode([String: PendingFavoriteMutation].self, from: pendingData) {
            self.pendingMutations = decodedPending
            // Stelle sicher, dass ausstehende Offline-Aenderungen auch in IDs/Liste sichtbar bleiben
            for (tid, mut) in decodedPending {
                if mut.isFavorite {
                    self.favoritedTrackIds.insert(tid)
                } else {
                    self.favoritedTrackIds.remove(tid)
                }
            }
        }
    }

    public func isFavorite(trackId: String) -> Bool {
        let trimmed = trackId.trimmingCharacters(in: .whitespacesAndNewlines)
        return favoritedTrackIds.contains(trimmed)
    }

    public func setFavorite(trackId: String, isFavorite: Bool) {
        let trimmed = trackId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if isFavorite {
            favoritedTrackIds.insert(trimmed)
        } else {
            favoritedTrackIds.remove(trimmed)
            cachedFavoriteTracks.removeAll { $0.id == trimmed }
        }
        persistState()
    }

    public func enqueueMutation(track: Track, isFavorite: Bool) {
        let trimmed = track.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if isFavorite {
            favoritedTrackIds.insert(trimmed)
            cachedFavoriteTracks.removeAll { $0.id == trimmed }
            cachedFavoriteTracks.insert(track, at: 0)
        } else {
            favoritedTrackIds.remove(trimmed)
            cachedFavoriteTracks.removeAll { $0.id == trimmed }
        }

        pendingMutations[trimmed] = PendingFavoriteMutation(
            track: track,
            isFavorite: isFavorite,
            timestamp: Date()
        )
        persistState()
    }

    public func resolveMutationOnline(trackId: String) {
        let trimmed = trackId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if pendingMutations.removeValue(forKey: trimmed) != nil {
            persistState()
        }
    }

    public func syncWithList(_ tracks: [Track]) {
        _ = syncWithServerList(tracks)
    }

    @discardableResult
    public func syncWithServerList(_ serverTracks: [Track]) -> [Track] {
        var merged = serverTracks
        var ids = Set(serverTracks.map { $0.id.trimmingCharacters(in: .whitespacesAndNewlines) })

        // Ausstehende lokale Offline-Mutationen auf die Serverliste anwenden (nichts geht verloren)
        let pendingSorted = pendingMutations.values.sorted { $0.timestamp > $1.timestamp }
        for mut in pendingSorted {
            let tid = mut.track.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if mut.isFavorite {
                ids.insert(tid)
                if !merged.contains(where: { $0.id == tid }) {
                    merged.insert(mut.track, at: 0)
                }
            } else {
                ids.remove(tid)
                merged.removeAll { $0.id == tid }
            }
        }

        self.favoritedTrackIds = ids
        self.cachedFavoriteTracks = merged
        persistState()
        return merged
    }

    public func syncPendingWithServer(serverURL: String, token: String?) async {
        guard !isFlushingPending, !pendingMutations.isEmpty else { return }
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !base.isEmpty else { return }

        isFlushingPending = true
        defer { isFlushingPending = false }

        let snapshot = pendingMutations.values.sorted { $0.timestamp < $1.timestamp }
        for mut in snapshot {
            let ok = await MusicService.shared.sendFavoriteRequest(
                track: mut.track,
                isFavorite: mut.isFavorite,
                serverURL: base,
                token: token
            )
            if ok {
                pendingMutations.removeValue(forKey: mut.track.id)
                persistState()
            } else {
                // Bei weiter bestehendem Verbindungsfehler Abgleich verschieben
                break
            }
        }
    }

    private func persistState() {
        UserDefaults.standard.set(Array(favoritedTrackIds), forKey: storageKey)
        if let encodedTracks = try? JSONEncoder().encode(cachedFavoriteTracks) {
            UserDefaults.standard.set(encodedTracks, forKey: cachedTracksKey)
        }
        if let encodedPending = try? JSONEncoder().encode(pendingMutations) {
            UserDefaults.standard.set(encodedPending, forKey: pendingMutationsKey)
        }
    }
}
