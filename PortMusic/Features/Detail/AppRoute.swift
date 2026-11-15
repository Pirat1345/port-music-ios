import Foundation

public enum AppRoute: Hashable {
    case artist(name: String, coverUrl: String? = nil)
    case album(id: String, title: String? = nil, artist: String? = nil, coverUrl: String? = nil)
    case playlist(id: String, title: String? = nil, coverUrl: String? = nil)
    case likedSongs
    case libraryCategory(category: String)
    case appleCategory(id: String, title: String, artworkUrl: String? = nil, bgColor: String? = nil)
}
