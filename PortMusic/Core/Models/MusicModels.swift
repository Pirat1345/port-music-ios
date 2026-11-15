import Foundation

// MARK: - Unified App Track Model
public struct Track: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: String
    public let durationSeconds: Double
    public let coverUrl: String?
    public let isLive: Bool // Invariante: Immer false fuer Musik-Tracks
    public let isExplicit: Bool

    public init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        duration: String = "0:00",
        durationSeconds: Double = 0,
        coverUrl: String? = nil,
        isLive: Bool = false,
        isExplicit: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.durationSeconds = durationSeconds
        self.coverUrl = coverUrl
        self.isLive = isLive
        self.isExplicit = isExplicit
    }
}

// MARK: - Discovery API Models
public struct DiscoveryTrack: Codable, Identifiable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: String?
    public let durationSeconds: Int?
    public let cover: String?
    public let sourceUrl: String?
    public let storageType: String?
    public let sourceType: String?
    public let isExplicit: Bool?

    public func toTrack() -> Track {
        Track(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: duration ?? "0:00",
            durationSeconds: Double(durationSeconds ?? 0),
            coverUrl: cover,
            isLive: false,
            isExplicit: isExplicit ?? false
        )
    }
}

public struct DiscoveryChartTrack: Codable, Identifiable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: String?
    public let durationSeconds: Int?
    public let cover: String?
    public let rank: Int?
    public let isExplicit: Bool?

    public func toTrack() -> Track {
        Track(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: duration ?? "0:00",
            durationSeconds: Double(durationSeconds ?? 0),
            coverUrl: cover,
            isLive: false,
            isExplicit: isExplicit ?? false
        )
    }
}

public struct DiscoveryAlbum: Codable, Identifiable {
    public let id: String
    public let title: String
    public let artist: String
    public let cover: String?
    public let nbTracks: Int?
}

public struct DiscoveryArtist: Codable, Identifiable {
    public let id: String
    public let name: String
    public let picture: String?
    public let nbFan: Int?
}

public struct DiscoveryPosterPick: Codable, Identifiable {
    public let id: String
    public let tag: String
    public let title: String
    public let subtitle: String
    public let cover: String
    public let kind: String
    public let targetUrl: String

    public func toTrack() -> Track {
        Track(
            id: id,
            title: title,
            artist: subtitle,
            album: nil,
            duration: "0:00",
            durationSeconds: 0,
            coverUrl: cover,
            isLive: false,
            isExplicit: false
        )
    }
}

public struct DiscoveryPlaylist: Codable, Identifiable {
    public let id: String
    public let title: String
    public let cover: String
    public let nbTracks: Int?
    public let user: String?
}

public struct DiscoveryMoodGenre: Codable, Identifiable {
    public let id: String
    public let title: String
    public let cover: String
    public let bgColor: String
}

public struct DiscoveryHomeResponse: Codable {
    public let topPicks: [DiscoveryPosterPick]?
    public let trendingEverywhere: [DiscoveryTrack]?
    public let newMusic: [DiscoveryAlbum]?
    public let todaysTopHits: [DiscoveryChartTrack]?
    public let top100Global: [DiscoveryChartTrack]?
    public let topAlbums: [DiscoveryAlbum]?
    public let topPlaylists: [DiscoveryPlaylist]?
    public let trendingArtists: [DiscoveryArtist]?
    public let trendingAlbums: [DiscoveryAlbum]?
    public let moodsAndGenres: [DiscoveryMoodGenre]?
}

public struct DiscoverySearchResponse: Codable {
    public let tracks: [DiscoveryTrack]?
    public let albums: [DiscoveryAlbum]?
    public let artists: [DiscoveryArtist]?
    public let playlists: [DiscoveryPlaylist]?
}
