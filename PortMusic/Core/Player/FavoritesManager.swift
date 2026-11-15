import Foundation

public final class FavoritesManager: ObservableObject {
    public static let shared = FavoritesManager()

    @Published public private(set) var favoritedTrackIds: Set<String> = []
    private let storageKey = "port_music_favorited_track_ids"

    private init() {
        if let saved = UserDefaults.standard.stringArray(forKey: storageKey) {
            self.favoritedTrackIds = Set(saved)
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
        }
        UserDefaults.standard.set(Array(favoritedTrackIds), forKey: storageKey)
    }

    public func syncWithList(_ tracks: [Track]) {
        let ids = Set(tracks.map { $0.id.trimmingCharacters(in: .whitespacesAndNewlines) })
        favoritedTrackIds.formUnion(ids)
        UserDefaults.standard.set(Array(favoritedTrackIds), forKey: storageKey)
    }
}
