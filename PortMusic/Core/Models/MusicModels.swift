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
    public let sourceUrl: String?

    public init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        duration: String = "0:00",
        durationSeconds: Double = 0,
        coverUrl: String? = nil,
        isLive: Bool = false,
        isExplicit: Bool = false,
        sourceUrl: String? = nil
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
        self.sourceUrl = sourceUrl
    }

    public var cover: String? { coverUrl }

    enum CodingKeys: String, CodingKey {
        case id, title, name, artist, album, duration, durationSeconds
        case duration_seconds, duration_secs, durationSecs
        case coverUrl = "cover_url"
        case coverUrlAlt = "coverUrl"
        case cover, artworkUrl
        case isLive = "is_live"
        case isExplicit = "is_explicit"
        case isExplicitAlt = "isExplicit"
        case explicitContent = "explicit_content"
        case sourceUrl
        case sourceUrlSnake = "source_url"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.title = (try? container.decode(String.self, forKey: .title))
            ?? (try? container.decode(String.self, forKey: .name))
            ?? "Unbekannter Titel"
        self.artist = (try? container.decode(String.self, forKey: .artist)) ?? "Unbekannter Interpret"
        self.album = try? container.decodeIfPresent(String.self, forKey: .album)

        var durSec: Double = 0.0
        if let ds = try? container.decodeIfPresent(Double.self, forKey: .durationSeconds) {
            durSec = ds
        } else if let dsInt = try? container.decodeIfPresent(Int.self, forKey: .durationSeconds) {
            durSec = Double(dsInt)
        } else if let dsSnake = try? container.decodeIfPresent(Double.self, forKey: .duration_seconds) {
            durSec = dsSnake
        } else if let dsSnakeInt = try? container.decodeIfPresent(Int.self, forKey: .duration_seconds) {
            durSec = Double(dsSnakeInt)
        } else if let dsSecs = try? container.decodeIfPresent(Double.self, forKey: .duration_secs) {
            durSec = dsSecs
        } else if let dsSecsInt = try? container.decodeIfPresent(Int.self, forKey: .duration_secs) {
            durSec = Double(dsSecsInt)
        }

        var durStr: String = "0:00"
        if let dStr = try? container.decodeIfPresent(String.self, forKey: .duration) {
            durStr = dStr
            if durSec <= 0 {
                let clean = dStr.trimmingCharacters(in: .whitespacesAndNewlines)
                if let direct = Double(clean), direct > 0 {
                    durSec = direct
                } else {
                    let parts = clean.split(separator: ":").compactMap { Double($0) }
                    if parts.count == 2 {
                        durSec = parts[0] * 60.0 + parts[1]
                    } else if parts.count == 3 {
                        durSec = parts[0] * 3600.0 + parts[1] * 60.0 + parts[2]
                    }
                }
            }
        } else if let dNum = try? container.decodeIfPresent(Double.self, forKey: .duration) {
            durSec = durSec > 0 ? durSec : dNum
            let m = Int(durSec) / 60
            let s = Int(durSec) % 60
            durStr = String(format: "%d:%02d", m, s)
        } else if let dInt = try? container.decodeIfPresent(Int.self, forKey: .duration) {
            durSec = durSec > 0 ? durSec : Double(dInt)
            let m = Int(durSec) / 60
            let s = Int(durSec) % 60
            durStr = String(format: "%d:%02d", m, s)
        }

        if durStr == "0:00" && durSec > 0 {
            let m = Int(durSec) / 60
            let s = Int(durSec) % 60
            durStr = String(format: "%d:%02d", m, s)
        }

        self.duration = durStr
        self.durationSeconds = durSec

        var cov = try? container.decodeIfPresent(String.self, forKey: .coverUrl)
        if cov == nil {
            cov = try? container.decodeIfPresent(String.self, forKey: .coverUrlAlt)
        }
        if cov == nil {
            cov = try? container.decodeIfPresent(String.self, forKey: .cover)
        }
        if cov == nil {
            cov = try? container.decodeIfPresent(String.self, forKey: .artworkUrl)
        }
        self.coverUrl = cov

        self.isLive = false

        var exp = try? container.decodeIfPresent(Bool.self, forKey: .isExplicit)
        if exp == nil {
            exp = try? container.decodeIfPresent(Bool.self, forKey: .isExplicitAlt)
        }
        if exp == nil {
            exp = try? container.decodeIfPresent(Bool.self, forKey: .explicitContent)
        }
        self.isExplicit = exp ?? false
        self.sourceUrl = (try? container.decodeIfPresent(String.self, forKey: .sourceUrl))
            ?? (try? container.decodeIfPresent(String.self, forKey: .sourceUrlSnake))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(artist, forKey: .artist)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encode(duration, forKey: .duration)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encodeIfPresent(coverUrl, forKey: .coverUrl)
        try container.encode(isLive, forKey: .isLive)
        try container.encode(isExplicit, forKey: .isExplicit)
        try container.encodeIfPresent(sourceUrl, forKey: .sourceUrl)
    }
}

// MARK: - Discovery API Models
public struct DiscoveryTrack: Codable, Identifiable, Equatable {
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

    enum CodingKeys: String, CodingKey {
        case id, title, name, artist, album, duration, durationSeconds
        case duration_seconds, duration_secs, durationSecs
        case durationStr = "duration_str"
        case cover, coverUrl = "cover_url"
        case sourceUrl = "source_url"
        case sourceUrlAlt = "sourceUrl"
        case storageType = "storage_type"
        case storageTypeAlt = "storageType"
        case sourceType = "source_type"
        case sourceTypeAlt = "sourceType"
        case isExplicit = "is_explicit"
        case isExplicitAlt = "isExplicit"
        case explicitContent = "explicit_content"
    }

    public init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        duration: String? = nil,
        durationSeconds: Int? = nil,
        cover: String? = nil,
        sourceUrl: String? = nil,
        storageType: String? = nil,
        sourceType: String? = nil,
        isExplicit: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.durationSeconds = durationSeconds
        self.cover = cover
        self.sourceUrl = sourceUrl
        self.storageType = storageType
        self.sourceType = sourceType
        self.isExplicit = isExplicit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.title = (try? container.decode(String.self, forKey: .title))
            ?? (try? container.decode(String.self, forKey: .name))
            ?? "Unbekannter Titel"
        self.artist = (try? container.decode(String.self, forKey: .artist)) ?? "Unbekannter Interpret"
        self.album = try? container.decodeIfPresent(String.self, forKey: .album)

        var sec: Int? = nil
        if let ds = try? container.decodeIfPresent(Int.self, forKey: .durationSeconds) {
            sec = ds
        } else if let dsDouble = try? container.decodeIfPresent(Double.self, forKey: .durationSeconds) {
            sec = Int(dsDouble)
        } else if let dsSnake = try? container.decodeIfPresent(Int.self, forKey: .duration_seconds) {
            sec = dsSnake
        } else if let dsSnakeDbl = try? container.decodeIfPresent(Double.self, forKey: .duration_seconds) {
            sec = Int(dsSnakeDbl)
        } else if let dsSecs = try? container.decodeIfPresent(Int.self, forKey: .duration_secs) {
            sec = dsSecs
        } else if let dsSecsDbl = try? container.decodeIfPresent(Double.self, forKey: .duration_secs) {
            sec = Int(dsSecsDbl)
        }

        var dString: String? = (try? container.decodeIfPresent(String.self, forKey: .duration))
            ?? (try? container.decodeIfPresent(String.self, forKey: .durationStr))
        if dString == nil {
            if let dNum = try? container.decodeIfPresent(Double.self, forKey: .duration) {
                sec = sec ?? Int(dNum)
                dString = String(format: "%d:%02d", Int(dNum) / 60, Int(dNum) % 60)
            } else if let dInt = try? container.decodeIfPresent(Int.self, forKey: .duration) {
                sec = sec ?? dInt
                dString = String(format: "%d:%02d", dInt / 60, dInt % 60)
            }
        }

        if (sec == nil || sec == 0), let str = dString {
            let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if let direct = Int(clean), direct > 0 {
                sec = direct
            } else {
                let parts = clean.split(separator: ":").compactMap { Int($0) }
                if parts.count == 2 {
                    sec = parts[0] * 60 + parts[1]
                } else if parts.count == 3 {
                    sec = parts[0] * 3600 + parts[1] * 60 + parts[2]
                }
            }
        }

        if (dString == nil || dString == "0:00"), let s = sec, s > 0 {
            dString = String(format: "%d:%02d", s / 60, s % 60)
        }

        self.duration = dString
        self.durationSeconds = sec

        self.cover = (try? container.decodeIfPresent(String.self, forKey: .cover))
            ?? (try? container.decodeIfPresent(String.self, forKey: .coverUrl))

        self.sourceUrl = (try? container.decodeIfPresent(String.self, forKey: .sourceUrl))
            ?? (try? container.decodeIfPresent(String.self, forKey: .sourceUrlAlt))

        self.storageType = (try? container.decodeIfPresent(String.self, forKey: .storageType))
            ?? (try? container.decodeIfPresent(String.self, forKey: .storageTypeAlt))

        self.sourceType = (try? container.decodeIfPresent(String.self, forKey: .sourceType))
            ?? (try? container.decodeIfPresent(String.self, forKey: .sourceTypeAlt))

        self.isExplicit = (try? container.decodeIfPresent(Bool.self, forKey: .isExplicit))
            ?? (try? container.decodeIfPresent(Bool.self, forKey: .isExplicitAlt))
            ?? (try? container.decodeIfPresent(Bool.self, forKey: .explicitContent))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(artist, forKey: .artist)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try container.encodeIfPresent(cover, forKey: .cover)
        try container.encodeIfPresent(sourceUrl, forKey: .sourceUrl)
        try container.encodeIfPresent(storageType, forKey: .storageType)
        try container.encodeIfPresent(sourceType, forKey: .sourceType)
        try container.encodeIfPresent(isExplicit, forKey: .isExplicit)
    }

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

    enum CodingKeys: String, CodingKey {
        case id, title, name, artist, album, duration, durationSeconds
        case duration_seconds, duration_secs
        case cover, coverUrl = "cover_url"
        case rank
        case isExplicit = "is_explicit"
        case isExplicitAlt = "isExplicit"
    }

    public init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        duration: String? = nil,
        durationSeconds: Int? = nil,
        cover: String? = nil,
        rank: Int? = nil,
        isExplicit: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.durationSeconds = durationSeconds
        self.cover = cover
        self.rank = rank
        self.isExplicit = isExplicit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.title = (try? container.decode(String.self, forKey: .title))
            ?? (try? container.decode(String.self, forKey: .name))
            ?? "Unbekannter Titel"
        self.artist = (try? container.decode(String.self, forKey: .artist)) ?? "Unbekannter Interpret"
        self.album = try? container.decodeIfPresent(String.self, forKey: .album)

        var sec: Int? = nil
        if let ds = try? container.decodeIfPresent(Int.self, forKey: .durationSeconds) {
            sec = ds
        } else if let dsDouble = try? container.decodeIfPresent(Double.self, forKey: .durationSeconds) {
            sec = Int(dsDouble)
        } else if let dsSnake = try? container.decodeIfPresent(Int.self, forKey: .duration_seconds) {
            sec = dsSnake
        } else if let dsSecs = try? container.decodeIfPresent(Int.self, forKey: .duration_secs) {
            sec = dsSecs
        }

        var dString: String? = try? container.decodeIfPresent(String.self, forKey: .duration)
        if (sec == nil || sec == 0), let str = dString {
            let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if let direct = Int(clean), direct > 0 {
                sec = direct
            } else {
                let parts = clean.split(separator: ":").compactMap { Int($0) }
                if parts.count == 2 {
                    sec = parts[0] * 60 + parts[1]
                }
            }
        }
        if (dString == nil || dString == "0:00"), let s = sec, s > 0 {
            dString = String(format: "%d:%02d", s / 60, s % 60)
        }

        self.duration = dString
        self.durationSeconds = sec
        self.cover = (try? container.decodeIfPresent(String.self, forKey: .cover))
            ?? (try? container.decodeIfPresent(String.self, forKey: .coverUrl))
        self.rank = try? container.decodeIfPresent(Int.self, forKey: .rank)
        self.isExplicit = (try? container.decodeIfPresent(Bool.self, forKey: .isExplicit))
            ?? (try? container.decodeIfPresent(Bool.self, forKey: .isExplicitAlt))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(artist, forKey: .artist)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try container.encodeIfPresent(cover, forKey: .cover)
        try container.encodeIfPresent(rank, forKey: .rank)
        try container.encodeIfPresent(isExplicit, forKey: .isExplicit)
    }

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
    public let folderId: String?
    public let trackCovers: [String]?

    public init(
        id: String,
        title: String,
        cover: String = "",
        nbTracks: Int? = nil,
        user: String? = nil,
        folderId: String? = nil,
        trackCovers: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.cover = cover
        self.nbTracks = nbTracks
        self.user = user
        self.folderId = folderId
        self.trackCovers = trackCovers
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case name
        case cover
        case coverUrl = "cover_url"
        case nbTracks
        case trackCount
        case user
        case owner = "owner_id"
        case folderId
        case folderIdSnake = "folder_id"
        case trackCovers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        if let t = try? container.decode(String.self, forKey: .title) {
            self.title = t
        } else if let n = try? container.decode(String.self, forKey: .name) {
            self.title = n
        } else {
            self.title = "Playlist"
        }

        if let c = try? container.decode(String.self, forKey: .cover) {
            self.cover = c
        } else if let cu = try? container.decode(String.self, forKey: .coverUrl) {
            self.cover = cu
        } else {
            self.cover = ""
        }

        if let nb = try? container.decode(Int.self, forKey: .nbTracks) {
            self.nbTracks = nb
        } else if let tc = try? container.decode(Int.self, forKey: .trackCount) {
            self.nbTracks = tc
        } else {
            self.nbTracks = nil
        }

        if let u = try? container.decode(String.self, forKey: .user) {
            self.user = u
        } else if let o = try? container.decode(String.self, forKey: .owner) {
            self.user = o
        } else {
            self.user = nil
        }

        self.folderId = (try? container.decodeIfPresent(String.self, forKey: .folderId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .folderIdSnake))
        self.trackCovers = try? container.decodeIfPresent([String].self, forKey: .trackCovers)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(cover, forKey: .cover)
        try container.encodeIfPresent(nbTracks, forKey: .nbTracks)
        try container.encodeIfPresent(user, forKey: .user)
        try container.encodeIfPresent(folderId, forKey: .folderId)
        try container.encodeIfPresent(trackCovers, forKey: .trackCovers)
    }
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
    public let sourceUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, title, artist, album, duration, durationSeconds
        case duration_seconds, duration_secs
        case cover, isExplicit = "is_explicit", isExplicitAlt = "isExplicit", rank, trackNumber
        case sourceUrl, source_url
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
        trackNumber: Int? = nil,
        sourceUrl: String? = nil
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
        self.sourceUrl = sourceUrl
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = (try? container.decodeIfPresent(String.self, forKey: .artist)) ?? ""
        album = try container.decodeIfPresent(String.self, forKey: .album)
        var durStr = try? container.decodeIfPresent(String.self, forKey: .duration)

        var ds: Double? = nil
        if let d = try? container.decodeIfPresent(Double.self, forKey: .durationSeconds) {
            ds = d
        } else if let dInt = try? container.decodeIfPresent(Int.self, forKey: .durationSeconds) {
            ds = Double(dInt)
        } else if let dSnake = try? container.decodeIfPresent(Double.self, forKey: .duration_seconds) {
            ds = dSnake
        } else if let dSnakeInt = try? container.decodeIfPresent(Int.self, forKey: .duration_seconds) {
            ds = Double(dSnakeInt)
        } else if let dSecs = try? container.decodeIfPresent(Double.self, forKey: .duration_secs) {
            ds = dSecs
        } else if let dSecsInt = try? container.decodeIfPresent(Int.self, forKey: .duration_secs) {
            ds = Double(dSecsInt)
        }

        if (ds == nil || ds == 0), let str = durStr {
            let parts = str.split(separator: ":").compactMap { Double($0) }
            if parts.count == 2 {
                ds = parts[0] * 60.0 + parts[1]
            } else if parts.count == 3 {
                ds = parts[0] * 3600.0 + parts[1] * 60.0 + parts[2]
            }
        }

        if (durStr == nil || durStr == "0:00"), let s = ds, s > 0 {
            durStr = String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
        }

        duration = durStr
        durationSeconds = ds
        cover = try container.decodeIfPresent(String.self, forKey: .cover)
        isExplicit = (try? container.decodeIfPresent(Bool.self, forKey: .isExplicit))
            ?? (try? container.decodeIfPresent(Bool.self, forKey: .isExplicitAlt))
        rank = try container.decodeIfPresent(Int.self, forKey: .rank)
        trackNumber = try container.decodeIfPresent(Int.self, forKey: .trackNumber)
        sourceUrl = (try? container.decodeIfPresent(String.self, forKey: .sourceUrl))
            ?? (try? container.decodeIfPresent(String.self, forKey: .source_url))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(artist, forKey: .artist)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try container.encodeIfPresent(cover, forKey: .cover)
        try container.encodeIfPresent(isExplicit, forKey: .isExplicit)
        try container.encodeIfPresent(rank, forKey: .rank)
        try container.encodeIfPresent(trackNumber, forKey: .trackNumber)
        try container.encodeIfPresent(sourceUrl, forKey: .sourceUrl)
    }

    public func toTrack(fallbackCover: String? = nil, fallbackAlbum: String? = nil) -> Track {
        var calculatedSec: Double = durationSeconds ?? 0
        if calculatedSec <= 0, let d = duration {
            let parts = d.split(separator: ":").compactMap { Double($0) }
            if parts.count == 2 {
                calculatedSec = parts[0] * 60.0 + parts[1]
            }
        }
        return Track(
            id: id,
            title: title,
            artist: artist,
            album: album ?? fallbackAlbum,
            duration: duration ?? "0:00",
            durationSeconds: calculatedSec,
            coverUrl: cover ?? fallbackCover,
            isLive: false,
            isExplicit: isExplicit ?? false,
            sourceUrl: sourceUrl
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(artist, forKey: .artist)
        try container.encodeIfPresent(cover, forKey: .cover)
        try container.encodeIfPresent(year, forKey: .year)
        try container.encodeIfPresent(nbTracks, forKey: .nbTracks)
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(picture, forKey: .picture)
        try container.encodeIfPresent(nbFan, forKey: .nbFan)
    }
}

public struct DiscoveryArtistPlaylistItem: Codable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let cover: String?

    public init(id: String, title: String, cover: String? = nil) {
        self.id = id
        self.title = title
        self.cover = cover
    }
}

public struct DiscoveryArtistVideoItem: Codable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let artist: String
    public let thumbnail: String?
    public let previewUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, title, artist, thumbnail, previewUrl, preview_url
    }

    public init(
        id: String,
        title: String,
        artist: String,
        thumbnail: String? = nil,
        previewUrl: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.thumbnail = thumbnail
        self.previewUrl = previewUrl
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = (try? container.decodeIfPresent(String.self, forKey: .artist)) ?? ""
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        previewUrl = (try? container.decodeIfPresent(String.self, forKey: .previewUrl))
            ?? (try? container.decodeIfPresent(String.self, forKey: .preview_url))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(artist, forKey: .artist)
        try container.encodeIfPresent(thumbnail, forKey: .thumbnail)
        try container.encodeIfPresent(previewUrl, forKey: .previewUrl)
    }
}

public struct DiscoveryArtistTracksResponse: Codable {
    public let success: Bool?
    public let tracks: [DiscoveryArtistTrackItem]?
    public let total: Int?
}

public struct DiscoveryArtistDetailData: Codable, Identifiable {
    public let id: String
    public let name: String
    public let picture: String?
    public let nbFan: Int?
    public let description: String?
    public let country: String?
    public let beginDate: String?
    public let artistType: String?
    public let mbid: String?
    public let wikiUrl: String?
    public let isCustomCover: Bool
    public let topTracks: [DiscoveryArtistTrackItem]
    public let albums: [DiscoveryArtistAlbumItem]
    public let singles: [DiscoveryArtistAlbumItem]
    public let related: [DiscoveryRelatedArtistItem]
    public let playlists: [DiscoveryArtistPlaylistItem]
    public let videos: [DiscoveryArtistVideoItem]

    enum CodingKeys: String, CodingKey {
        case id, name, picture, cover, nbFan, description
        case country, beginDate, artistType, mbid, wikiUrl, isCustomCover
        case topTracks, albums, singles, related, relatedArtists, playlists, videos
    }

    public init(
        id: String,
        name: String,
        picture: String? = nil,
        nbFan: Int? = nil,
        description: String? = nil,
        country: String? = nil,
        beginDate: String? = nil,
        artistType: String? = nil,
        mbid: String? = nil,
        wikiUrl: String? = nil,
        isCustomCover: Bool = false,
        topTracks: [DiscoveryArtistTrackItem] = [],
        albums: [DiscoveryArtistAlbumItem] = [],
        singles: [DiscoveryArtistAlbumItem] = [],
        related: [DiscoveryRelatedArtistItem] = [],
        playlists: [DiscoveryArtistPlaylistItem] = [],
        videos: [DiscoveryArtistVideoItem] = []
    ) {
        self.id = id
        self.name = name
        self.picture = picture
        self.nbFan = nbFan
        self.description = description
        self.country = country
        self.beginDate = beginDate
        self.artistType = artistType
        self.mbid = mbid
        self.wikiUrl = wikiUrl
        self.isCustomCover = isCustomCover
        self.topTracks = topTracks
        self.albums = albums
        self.singles = singles
        self.related = related
        self.playlists = playlists
        self.videos = videos
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
        country = try container.decodeIfPresent(String.self, forKey: .country)
        beginDate = try container.decodeIfPresent(String.self, forKey: .beginDate)
        artistType = try container.decodeIfPresent(String.self, forKey: .artistType)
        mbid = try container.decodeIfPresent(String.self, forKey: .mbid)
        wikiUrl = try container.decodeIfPresent(String.self, forKey: .wikiUrl)
        isCustomCover = (try? container.decodeIfPresent(Bool.self, forKey: .isCustomCover)) ?? false
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
        playlists = (try? container.decodeIfPresent([DiscoveryArtistPlaylistItem].self, forKey: .playlists)) ?? []
        videos = (try? container.decodeIfPresent([DiscoveryArtistVideoItem].self, forKey: .videos)) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(picture, forKey: .picture)
        try container.encodeIfPresent(nbFan, forKey: .nbFan)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(country, forKey: .country)
        try container.encodeIfPresent(beginDate, forKey: .beginDate)
        try container.encodeIfPresent(artistType, forKey: .artistType)
        try container.encodeIfPresent(mbid, forKey: .mbid)
        try container.encodeIfPresent(wikiUrl, forKey: .wikiUrl)
        try container.encode(isCustomCover, forKey: .isCustomCover)
        try container.encode(topTracks, forKey: .topTracks)
        try container.encode(albums, forKey: .albums)
        try container.encode(singles, forKey: .singles)
        try container.encode(related, forKey: .related)
        try container.encode(playlists, forKey: .playlists)
        try container.encode(videos, forKey: .videos)
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(artist, forKey: .artist)
        try container.encodeIfPresent(cover, forKey: .cover)
        try container.encodeIfPresent(year, forKey: .year)
        try container.encodeIfPresent(trackCount, forKey: .trackCount)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try container.encode(tracks, forKey: .tracks)
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(cover, forKey: .cover)
        try container.encodeIfPresent(heroArtwork, forKey: .heroArtwork)
        try container.encodeIfPresent(motionVideo, forKey: .motionVideo)
        try container.encodeIfPresent(user, forKey: .user)
        try container.encodeIfPresent(nbTracks, forKey: .nbTracks)
        try container.encode(tracks, forKey: .tracks)
    }

    public static func == (lhs: DiscoveryPlaylistDetailData, rhs: DiscoveryPlaylistDetailData) -> Bool {
        lhs.id == rhs.id
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
    let trimmedInput = lrc.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedInput.isEmpty else { return [] }

    // 1. Wenn die Antwort bereits ein JSON-Objekt mit einem "lines"-Array ist
    if trimmedInput.first == Character(UnicodeScalar(123)) && trimmedInput.contains("\"lines\""),
       let data = trimmedInput.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let rawLines = json["lines"] as? [[String: Any]] {
        var parsed: [LyricLine] = []
        for line in rawLines {
            let text = (line["text"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let start = line["start"] as? Double ?? 0.0
            if !text.isEmpty {
                parsed.append(LyricLine(time: start, text: text))
            }
        }
        if !parsed.isEmpty {
            return parsed.sorted { $0.time < $1.time }
        }
    }

    var lines: [LyricLine] = []
    let rawLines = trimmedInput.components(separatedBy: .newlines)
    let pattern = "\\[(\\d{1,2}):(\\d{2})(?:\\.(\\d{1,3}))?\\](.*)"
    let regex = try? NSRegularExpression(pattern: pattern)

    for line in rawLines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { continue }
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        if let regex = regex, let match = regex.firstMatch(in: trimmed, options: [], range: range) {
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
                var text = String(trimmed[textRange]).trimmingCharacters(in: .whitespaces)
                // Wort-Tags <mm:ss.xx> aus Text entfernen
                text = text.replacingOccurrences(of: "<\\d{1,2}:\\d{2}(?:\\.\\d{1,3})?>", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    lines.append(LyricLine(time: totalSec, text: text))
                }
            }
        }
    }

    // 2. Falls keine LRC-Zeitstempel vorhanden waren, aber Textzeilen existieren (reiner Text-Songtext)
    if lines.isEmpty {
        var lineTime = 0.0
        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("[ti:") && !trimmed.hasPrefix("[ar:") && !trimmed.hasPrefix("[al:") {
                lines.append(LyricLine(time: lineTime, text: trimmed))
                lineTime += 4.0 // Standard-Intervall für Textzeilen
            }
        }
    }

    return lines.sorted { $0.time < $1.time }
}

// MARK: - Library & Radio Models (Web Library Parity)
public struct LibraryRadioStation: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let url: String
    public let favicon: String?
    public let tags: [String]?
    public let country: String?
    public let codec: String?
    public let bitrate: Int?

    public init(
        id: String,
        name: String,
        url: String,
        favicon: String? = nil,
        tags: [String]? = nil,
        country: String? = nil,
        codec: String? = nil,
        bitrate: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.favicon = favicon
        self.tags = tags
        self.country = country
        self.codec = codec
        self.bitrate = bitrate
    }
}

public struct LibraryFolder: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let parentId: String?
    public let color: String?

    public init(id: String, name: String, parentId: String? = nil, color: String? = nil) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.color = color
    }
}

public struct LibraryCollectionsData {
    public var playlists: [DiscoveryPlaylist]
    public var folders: [LibraryFolder]
    public var savedArtists: [String]
    public var savedAlbums: [String]
    public var albumCovers: [String: String]
    public var pinnedPlaylists: [String]
    public var pinnedFolders: [String]
    public var playlistTracksMap: [String: [Track]]
    public var favorites: [Track]
    public var globalTracks: [Track]

    public init(
        playlists: [DiscoveryPlaylist] = [],
        folders: [LibraryFolder] = [],
        savedArtists: [String] = [],
        savedAlbums: [String] = [],
        albumCovers: [String: String] = [:],
        pinnedPlaylists: [String] = [],
        pinnedFolders: [String] = [],
        playlistTracksMap: [String: [Track]] = [:],
        favorites: [Track] = [],
        globalTracks: [Track] = []
    ) {
        self.playlists = playlists
        self.folders = folders
        self.savedArtists = savedArtists
        self.savedAlbums = savedAlbums
        self.albumCovers = albumCovers
        self.pinnedPlaylists = pinnedPlaylists
        self.pinnedFolders = pinnedFolders
        self.playlistTracksMap = playlistTracksMap
        self.favorites = favorites
        self.globalTracks = globalTracks
    }
}

// MARK: - Podcast Models (/api/podcasts/*)
public struct PodcastItem: Codable, Identifiable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let feedUrl: String
    public let cover: String
    public let genres: [String]
    public let trackCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, artist, feedUrl, feed_url, cover, genres, trackCount, track_count
    }

    public init(
        id: String,
        title: String,
        artist: String = "",
        feedUrl: String = "",
        cover: String = "",
        genres: [String] = [],
        trackCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.feedUrl = feedUrl
        self.cover = cover
        self.genres = genres
        self.trackCount = trackCount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.title = (try? c.decode(String.self, forKey: .title)) ?? "Podcast"
        self.artist = (try? c.decode(String.self, forKey: .artist)) ?? ""
        self.feedUrl = (try? c.decodeIfPresent(String.self, forKey: .feedUrl))
            ?? (try? c.decodeIfPresent(String.self, forKey: .feed_url))
            ?? ""
        self.cover = (try? c.decode(String.self, forKey: .cover)) ?? ""
        self.genres = (try? c.decodeIfPresent([String].self, forKey: .genres)) ?? []
        self.trackCount = (try? c.decodeIfPresent(Int.self, forKey: .trackCount))
            ?? (try? c.decodeIfPresent(Int.self, forKey: .track_count))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(artist, forKey: .artist)
        try c.encode(feedUrl, forKey: .feedUrl)
        try c.encode(cover, forKey: .cover)
        try c.encode(genres, forKey: .genres)
        try c.encodeIfPresent(trackCount, forKey: .trackCount)
    }
}

public struct PodcastEpisodeItem: Codable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let description: String
    public let publishedAt: String
    public let durationSeconds: Int
    public let audioUrl: String
    public let cover: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case publishedAt, published_at
        case durationSeconds, duration_seconds
        case audioUrl, audio_url
        case cover
    }

    public init(
        id: String,
        title: String,
        description: String = "",
        publishedAt: String = "",
        durationSeconds: Int = 0,
        audioUrl: String = "",
        cover: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.publishedAt = publishedAt
        self.durationSeconds = durationSeconds
        self.audioUrl = audioUrl
        self.cover = cover
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.title = (try? c.decode(String.self, forKey: .title)) ?? "Folge"
        self.description = (try? c.decode(String.self, forKey: .description)) ?? ""
        self.publishedAt = (try? c.decodeIfPresent(String.self, forKey: .publishedAt))
            ?? (try? c.decodeIfPresent(String.self, forKey: .published_at))
            ?? ""
        self.durationSeconds = (try? c.decodeIfPresent(Int.self, forKey: .durationSeconds))
            ?? (try? c.decodeIfPresent(Int.self, forKey: .duration_seconds))
            ?? 0
        self.audioUrl = (try? c.decodeIfPresent(String.self, forKey: .audioUrl))
            ?? (try? c.decodeIfPresent(String.self, forKey: .audio_url))
            ?? ""
        self.cover = try? c.decodeIfPresent(String.self, forKey: .cover)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encode(publishedAt, forKey: .publishedAt)
        try c.encode(durationSeconds, forKey: .durationSeconds)
        try c.encode(audioUrl, forKey: .audioUrl)
        try c.encodeIfPresent(cover, forKey: .cover)
    }
}

public struct PodcastFeedDetail: Codable {
    public let id: String
    public let title: String
    public let author: String
    public let description: String
    public let cover: String
    public let feedUrl: String
    public let episodes: [PodcastEpisodeItem]

    enum CodingKeys: String, CodingKey {
        case id, title, author, description, cover
        case feedUrl, feed_url, episodes
    }

    public init(
        id: String,
        title: String,
        author: String = "",
        description: String = "",
        cover: String = "",
        feedUrl: String = "",
        episodes: [PodcastEpisodeItem] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.description = description
        self.cover = cover
        self.feedUrl = feedUrl
        self.episodes = episodes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? ""
        self.title = (try? c.decode(String.self, forKey: .title)) ?? "Podcast"
        self.author = (try? c.decode(String.self, forKey: .author)) ?? ""
        self.description = (try? c.decode(String.self, forKey: .description)) ?? ""
        self.cover = (try? c.decode(String.self, forKey: .cover)) ?? ""
        self.feedUrl = (try? c.decodeIfPresent(String.self, forKey: .feedUrl))
            ?? (try? c.decodeIfPresent(String.self, forKey: .feed_url))
            ?? ""
        self.episodes = (try? c.decodeIfPresent([PodcastEpisodeItem].self, forKey: .episodes)) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(author, forKey: .author)
        try c.encode(description, forKey: .description)
        try c.encode(cover, forKey: .cover)
        try c.encode(feedUrl, forKey: .feedUrl)
        try c.encode(episodes, forKey: .episodes)
    }
}

public struct PodcastResolveResult: Codable {
    public let status: String?
    public let source: String?
    public let title: String?
    public let artist: String?
    public let feedUrl: String?
    public let cover: String?
    public let message: String?
}

public struct PodcastResumeInfo: Codable, Equatable {
    public let podcastId: String
    public let podcastTitle: String
    public let podcastFeedUrl: String?
    public let episodeId: String
    public let episodeTitle: String
    public let cover: String?
    public let audioUrl: String?
    public let positionSeconds: Double
    public let durationSeconds: Double
    public let progress: Double
    public let updatedAt: Double
}

public struct PodcastEpisodeProgress: Codable, Equatable {
    public let episodeId: String
    public let podcastId: String?
    public let positionSeconds: Double
    public let durationSeconds: Double
    public let progress: Double
    public let isCompleted: Bool
    public let updatedAt: Double
}

// MARK: - Curated & Directory Radio Models (/api/radio/*)
public struct RadioBrowserStation: Codable, Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let url: String?
    public let favicon: String?
    public let tags: [String]?
    public let country: String?
    public let codec: String?
    public let bitrate: Int?
    public let votes: Int?
    public let hls: Bool?
    public let description: String?
    public let time: String?
    public let badge: String?

    public func toLibraryStation() -> LibraryRadioStation {
        LibraryRadioStation(
            id: id,
            name: name,
            url: url ?? "",
            favicon: favicon,
            tags: tags,
            country: country,
            codec: codec,
            bitrate: bitrate
        )
    }
}

public struct RadioStationsListResponse: Codable {
    public let stations: [RadioBrowserStation]
    public let hasMore: Bool?

    enum CodingKeys: String, CodingKey {
        case stations
        case hasMore = "has_more"
    }
}

public struct RadioHeroStation: Codable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let time: String
    public let badge: String
    public let cover: String
    public let streamUrl: String
    public let hls: Bool?
    public let scheduleUrl: String?
}

public struct RadioOnAirStation: Codable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let time: String
    public let cover: String
    public let streamUrl: String
    public let hls: Bool?
}

public struct RadioShelfItem: Codable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let cover: String
    public let streamUrl: String
    public let hls: Bool?
    public let radioField: String?
    public let artistCollages: [String]?
}

public struct RadioShelf: Codable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let items: [RadioShelfItem]
}

public struct RadioFeaturedMix: Codable, Identifiable, Equatable {
    public let id: String
    public let deezerRadioId: Int?
    public let title: String
    public let subtitle: String
    public let cover: String
    public let gradient: String?
}

public struct RadioExploreCategory: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let tag: String
}

public struct CuratedRadioResponse: Codable {
    public let heroes: [RadioHeroStation]
    public let onAirNow: [RadioOnAirStation]
    public let stationsForYou: [RadioShelfItem]
    public let shelves: [RadioShelf]
    public let featuredMixes: [RadioFeaturedMix]
    public let explore: [RadioExploreCategory]
}

public struct PlaylistImportPreview: Codable {
    public let success: Bool
    public let type: String?
    public let playlistName: String
    public let playlistCover: String?
    public let playlistOwner: String?
    public let trackCount: Int
    public let tracks: [DiscoveryTrack]
}



