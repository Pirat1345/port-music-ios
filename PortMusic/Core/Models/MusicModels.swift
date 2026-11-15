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

// MARK: - Artist Detail Models (/api/discovery/artist/:name)
public struct DiscoveryArtistTrackItem: Codable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: String?
    public let durationSeconds: Double?
    public let cover: String?
    public let isExplicit: Bool?
    public let rank: Int?
    public let trackNumber: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, artist, album, duration, durationSeconds, cover, isExplicit, rank, trackNumber
    }

    public init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        duration: String? = "0:00",
        durationSeconds: Double? = 0,
        cover: String? = nil,
        isExplicit: Bool? = false,
        rank: Int? = nil,
        trackNumber: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.durationSeconds = durationSeconds
        self.cover = cover
        self.isExplicit = isExplicit
        self.rank = rank
        self.trackNumber = trackNumber
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = (try? container.decodeIfPresent(String.self, forKey: .artist)) ?? ""
        album = try container.decodeIfPresent(String.self, forKey: .album)
        duration = try container.decodeIfPresent(String.self, forKey: .duration)
        if let ds = try? container.decodeIfPresent(Double.self, forKey: .durationSeconds) {
            durationSeconds = ds
        } else if let dsInt = try? container.decodeIfPresent(Int.self, forKey: .durationSeconds) {
            durationSeconds = Double(dsInt)
        } else {
            durationSeconds = nil
        }
        cover = try container.decodeIfPresent(String.self, forKey: .cover)
        isExplicit = try container.decodeIfPresent(Bool.self, forKey: .isExplicit)
        rank = try container.decodeIfPresent(Int.self, forKey: .rank)
        trackNumber = try container.decodeIfPresent(Int.self, forKey: .trackNumber)
    }

    public func toTrack(fallbackCover: String? = nil, fallbackAlbum: String? = nil) -> Track {
        Track(
            id: id,
            title: title,
            artist: artist,
            album: album ?? fallbackAlbum,
            duration: duration ?? "0:00",
            durationSeconds: durationSeconds ?? 0,
            coverUrl: cover ?? fallbackCover,
            isLive: false,
            isExplicit: isExplicit ?? false
        )
    }
}

public struct DiscoveryArtistAlbumItem: Codable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let artist: String?
    public let cover: String?
    public let year: Int?
    public let nbTracks: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, name, artist, cover, year, nbTracks
    }

    public init(
        id: String,
        title: String,
        artist: String? = nil,
        cover: String? = nil,
        year: Int? = nil,
        nbTracks: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.cover = cover
        self.year = year
        self.nbTracks = nbTracks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        if let t = try container.decodeIfPresent(String.self, forKey: .title) {
            title = t
        } else if let n = try container.decodeIfPresent(String.self, forKey: .name) {
            title = n
        } else {
            title = "Album"
        }
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        cover = try container.decodeIfPresent(String.self, forKey: .cover)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        nbTracks = try container.decodeIfPresent(Int.self, forKey: .nbTracks)
    }
}

public struct DiscoveryRelatedArtistItem: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let picture: String?
    public let nbFan: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, picture, cover, nbFan
    }

    public init(id: String, name: String, picture: String? = nil, nbFan: Int? = nil) {
        self.id = id
        self.name = name
        self.picture = picture
        self.nbFan = nbFan
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        if let pic = try container.decodeIfPresent(String.self, forKey: .picture) {
            picture = pic
        } else {
            picture = try container.decodeIfPresent(String.self, forKey: .cover)
        }
        nbFan = try container.decodeIfPresent(Int.self, forKey: .nbFan)
    }
}

public struct DiscoveryArtistDetailData: Codable, Identifiable {
    public let id: String
    public let name: String
    public let picture: String?
    public let nbFan: Int?
    public let description: String?
    public let topTracks: [DiscoveryArtistTrackItem]
    public let albums: [DiscoveryArtistAlbumItem]
    public let singles: [DiscoveryArtistAlbumItem]
    public let related: [DiscoveryRelatedArtistItem]

    enum CodingKeys: String, CodingKey {
        case id, name, picture, cover, nbFan, description, topTracks, albums, singles, related, relatedArtists
    }

    public init(
        id: String,
        name: String,
        picture: String? = nil,
        nbFan: Int? = nil,
        description: String? = nil,
        topTracks: [DiscoveryArtistTrackItem] = [],
        albums: [DiscoveryArtistAlbumItem] = [],
        singles: [DiscoveryArtistAlbumItem] = [],
        related: [DiscoveryRelatedArtistItem] = []
    ) {
        self.id = id
        self.name = name
        self.picture = picture
        self.nbFan = nbFan
        self.description = description
        self.topTracks = topTracks
        self.albums = albums
        self.singles = singles
        self.related = related
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        if let pic = try container.decodeIfPresent(String.self, forKey: .picture) {
            picture = pic
        } else {
            picture = try container.decodeIfPresent(String.self, forKey: .cover)
        }
        nbFan = try container.decodeIfPresent(Int.self, forKey: .nbFan)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        topTracks = (try? container.decodeIfPresent([DiscoveryArtistTrackItem].self, forKey: .topTracks)) ?? []
        albums = (try? container.decodeIfPresent([DiscoveryArtistAlbumItem].self, forKey: .albums)) ?? []
        singles = (try? container.decodeIfPresent([DiscoveryArtistAlbumItem].self, forKey: .singles)) ?? []
        if let rel = try? container.decodeIfPresent([DiscoveryRelatedArtistItem].self, forKey: .related) {
            related = rel
        } else if let relArtists = try? container.decodeIfPresent([DiscoveryRelatedArtistItem].self, forKey: .relatedArtists) {
            related = relArtists
        } else {
            related = []
        }
    }
}

public struct DiscoveryArtistResponse: Codable {
    public let success: Bool?
    public let artist: DiscoveryArtistDetailData?
}

// MARK: - Album Detail Models (/api/discovery/album/:id)
public struct DiscoveryAlbumDetailData: Codable, Identifiable {
    public let id: String
    public let title: String
    public let artist: String
    public let cover: String?
    public let year: Int?
    public let trackCount: Int?
    public let duration: String?
    public let durationSeconds: Double?
    public let tracks: [DiscoveryArtistTrackItem]

    enum CodingKeys: String, CodingKey {
        case id, title, name, artist, cover, year, trackCount, duration, durationSeconds, tracks
    }

    public init(
        id: String,
        title: String,
        artist: String,
        cover: String? = nil,
        year: Int? = nil,
        trackCount: Int? = nil,
        duration: String? = nil,
        durationSeconds: Double? = nil,
        tracks: [DiscoveryArtistTrackItem] = []
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.cover = cover
        self.year = year
        self.trackCount = trackCount
        self.duration = duration
        self.durationSeconds = durationSeconds
        self.tracks = tracks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        if let t = try container.decodeIfPresent(String.self, forKey: .title) {
            title = t
        } else if let n = try container.decodeIfPresent(String.self, forKey: .name) {
            title = n
        } else {
            title = "Album"
        }
        artist = (try? container.decodeIfPresent(String.self, forKey: .artist)) ?? "Unbekannt"
        cover = try container.decodeIfPresent(String.self, forKey: .cover)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        trackCount = try container.decodeIfPresent(Int.self, forKey: .trackCount)
        duration = try container.decodeIfPresent(String.self, forKey: .duration)
        if let ds = try? container.decodeIfPresent(Double.self, forKey: .durationSeconds) {
            durationSeconds = ds
        } else if let dsInt = try? container.decodeIfPresent(Int.self, forKey: .durationSeconds) {
            durationSeconds = Double(dsInt)
        } else {
            durationSeconds = nil
        }
        tracks = (try? container.decodeIfPresent([DiscoveryArtistTrackItem].self, forKey: .tracks)) ?? []
    }
}

public struct DiscoveryAlbumResponse: Codable {
    public let success: Bool?
    public let album: DiscoveryAlbumDetailData?
}

// MARK: - Playlist Detail Models (/api/discovery/playlist/:id)
public struct DiscoveryPlaylistDetailData: Codable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let description: String?
    public let cover: String?
    public let heroArtwork: String?
    public let motionVideo: String?
    public let user: String?
    public let nbTracks: Int?
    public let tracks: [DiscoveryTrack]

    enum CodingKeys: String, CodingKey {
        case id, title, name, description, cover, heroArtwork, motionVideo, user, nbTracks, tracks
    }

    public init(
        id: String,
        title: String,
        description: String? = nil,
        cover: String? = nil,
        heroArtwork: String? = nil,
        motionVideo: String? = nil,
        user: String? = nil,
        nbTracks: Int? = nil,
        tracks: [DiscoveryTrack] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.cover = cover
        self.heroArtwork = heroArtwork
        self.motionVideo = motionVideo
        self.user = user
        self.nbTracks = nbTracks
        self.tracks = tracks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        if let t = try container.decodeIfPresent(String.self, forKey: .title) {
            title = t
        } else if let n = try container.decodeIfPresent(String.self, forKey: .name) {
            title = n
        } else {
            title = "Playlist"
        }
        description = try container.decodeIfPresent(String.self, forKey: .description)
        cover = try container.decodeIfPresent(String.self, forKey: .cover)
        heroArtwork = try container.decodeIfPresent(String.self, forKey: .heroArtwork)
        motionVideo = try container.decodeIfPresent(String.self, forKey: .motionVideo)
        user = try container.decodeIfPresent(String.self, forKey: .user)
        nbTracks = try container.decodeIfPresent(Int.self, forKey: .nbTracks)
        tracks = (try? container.decodeIfPresent([DiscoveryTrack].self, forKey: .tracks)) ?? []
    }
}

public struct DiscoveryPlaylistResponse: Codable {
    public let success: Bool?
    public let id: String?
    public let title: String?
    public let description: String?
    public let cover: String?
    public let heroArtwork: String?
    public let motionVideo: String?
    public let tracks: [DiscoveryTrack]?

    public func toDetailData() -> DiscoveryPlaylistDetailData? {
        guard let id = id else { return nil }
        return DiscoveryPlaylistDetailData(
            id: id,
            title: title ?? "Playlist",
            description: description,
            cover: cover,
            heroArtwork: heroArtwork,
            motionVideo: motionVideo,
            user: nil,
            nbTracks: tracks?.count,
            tracks: tracks ?? []
        )
    }
}

// MARK: - Synchronized Lyrics Model (Feature #18)
public struct LyricLine: Identifiable, Equatable, Hashable {
    public let id: String
    public let time: Double
    public let text: String

    public init(id: String = UUID().uuidString, time: Double, text: String) {
        self.id = id
        self.time = time
        self.text = text
    }
}

public func parseLRC(_ lrc: String) -> [LyricLine] {
    var lines: [LyricLine] = []
    let rawLines = lrc.components(separatedBy: .newlines)
    let pattern = "\\[(\\d{2}):(\\d{2})(?:\\.(\\d{2,3}))?\\](.*)"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

    for line in rawLines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        if let match = regex.firstMatch(in: trimmed, options: [], range: range) {
            if let minRange = Range(match.range(at: 1), in: trimmed),
               let secRange = Range(match.range(at: 2), in: trimmed),
               let textRange = Range(match.range(at: 4), in: trimmed) {
                let min = Double(trimmed[minRange]) ?? 0
                let sec = Double(trimmed[secRange]) ?? 0
                var frac = 0.0
                if match.range(at: 3).location != NSNotFound,
                   let fracRange = Range(match.range(at: 3), in: trimmed) {
                    let fracStr = "0." + trimmed[fracRange]
                    frac = Double(fracStr) ?? 0
                }
                let totalSec = min * 60 + sec + frac
                let text = String(trimmed[textRange]).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    lines.append(LyricLine(time: totalSec, text: text))
                }
            }
        }
    }
    return lines.sorted { $0.time < $1.time }
}


