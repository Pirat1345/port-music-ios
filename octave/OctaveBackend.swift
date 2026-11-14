//
//  OctaveBackend.swift
//  Port Music
//
//  Full Port Music Backend API client: Discovery, Playlists, Streaming & Search.
//

import Foundation
import UIKit

public struct UserInfo: Codable, Sendable, Hashable {
    public let userId: String
    public let username: String
    public let displayName: String
    public let role: String
    public let avatar: String?
    public let email: String?

    public init(
        userId: String,
        username: String,
        displayName: String,
        role: String = "user",
        avatar: String? = nil,
        email: String? = nil
    ) {
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.role = role
        self.avatar = avatar
        self.email = email
    }
}

// MARK: - Port Music Discovery & Library Models

public struct DiscoveryTrack: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: String?
    public let durationSeconds: Int?
    public let cover: String?
    public let sourceUrl: String?
    public let isExplicit: Bool?

    public func toSongEntity() -> SongEntity {
        SongEntity(
            id: id,
            title: title,
            artist: artist,
            artworkURLString: cover,
            albumTitle: album,
            durationSec: Double(durationSeconds ?? 0)
        )
    }
}

public struct DiscoveryAlbum: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let cover: String?
    public let nbTracks: Int?
}

public struct DiscoveryArtist: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let picture: String?
    public let nbFan: Int?
}

public struct DiscoveryPlaylist: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let cover: String?
    public let nbTracks: Int?
    public let user: String?
}

public struct DiscoveryChartTrack: Codable, Identifiable, Sendable, Hashable {
    public var id: String { track.id }
    public let track: DiscoveryTrack
    public let rank: Int?

    public init(from decoder: Decoder) throws {
        // May be flattened or nested
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let t = try? container.decode(DiscoveryTrack.self, forKey: .track) {
            self.track = t
            self.rank = try? container.decode(Int.self, forKey: .rank)
        } else {
            let t = try DiscoveryTrack(from: decoder)
            self.track = t
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.rank = try? container.decode(Int.self, forKey: .rank)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case track
        case rank
    }
}

public struct DiscoveryMoodGenre: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let cover: String?
    public let bgColor: String?
}

public struct DiscoveryPosterPick: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let tag: String?
    public let title: String
    public let subtitle: String?
    public let cover: String?
    public let kind: String?
    public let targetUrl: String?
}

public struct DiscoveryHomeResponse: Codable, Sendable {
    public let topPicks: [DiscoveryPosterPick]?
    public let trendingEverywhere: [DiscoveryTrack]?
    public let newMusic: [DiscoveryAlbum]?
    public let todaysTopHits: [DiscoveryChartTrack]?
    public let top100Global: [DiscoveryChartTrack]?
    public let topAlbums: [DiscoveryAlbum]?
    public let topPlaylists: [DiscoveryPlaylist]?
    public let trendingArtists: [DiscoveryArtist]?
    public let moodsAndGenres: [DiscoveryMoodGenre]?
}

public struct DiscoverySearchResponse: Codable, Sendable {
    public let tracks: [DiscoveryTrack]?
    public let albums: [DiscoveryAlbum]?
    public let artists: [DiscoveryArtist]?
    public let playlists: [DiscoveryPlaylist]?
}

public struct PlaylistRecord: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let description: String?
    public let cover_url: String?
    public let folder_id: String?
    public let color: String?
    public let visibility: String?
    public let created_at: Int64?
    public let updated_at: Int64?
}

public struct TrackRecord: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: Double
    public let cover_url: String
    public let cached_at: Int64
    public let storage_type: String?
    public let file_path: String?
    public let file_hash: String?
    public let file_size: Int64?
    public let format: String?
    public let lyrics: String?
    public let genre: String?
    public let year: Int?
    public let owner_id: String?
    public let visibility: String?
    public let shared_with: String?
    public let track_number: Int?

    public init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        duration: Double = 0.0,
        cover_url: String = "",
        cached_at: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        storage_type: String? = "stream",
        file_path: String? = nil,
        file_hash: String? = nil,
        file_size: Int64? = nil,
        format: String? = nil,
        lyrics: String? = nil,
        genre: String? = nil,
        year: Int? = nil,
        owner_id: String? = nil,
        visibility: String? = "public",
        shared_with: String? = nil,
        track_number: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.cover_url = cover_url
        self.cached_at = cached_at
        self.storage_type = storage_type
        self.file_path = file_path
        self.file_hash = file_hash
        self.file_size = file_size
        self.format = format
        self.lyrics = lyrics
        self.genre = genre
        self.year = year
        self.owner_id = owner_id
        self.visibility = visibility
        self.shared_with = shared_with
        self.track_number = track_number
    }

    public init(from song: SongEntity) {
        self.init(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.albumTitle,
            duration: song.durationSec,
            cover_url: song.artworkURLString ?? "",
            cached_at: Int64(Date().timeIntervalSince1970 * 1000),
            storage_type: "stream"
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.artist = try container.decode(String.self, forKey: .artist)
        self.album = try container.decodeIfPresent(String.self, forKey: .album)
        self.duration = (try? container.decodeIfPresent(Double.self, forKey: .duration)) ?? 0.0
        self.cover_url = (try? container.decodeIfPresent(String.self, forKey: .cover_url)) ?? ""
        self.cached_at = (try? container.decodeIfPresent(Int64.self, forKey: .cached_at)) ?? Int64(Date().timeIntervalSince1970 * 1000)
        self.storage_type = try? container.decodeIfPresent(String.self, forKey: .storage_type)
        self.file_path = try? container.decodeIfPresent(String.self, forKey: .file_path)
        self.file_hash = try? container.decodeIfPresent(String.self, forKey: .file_hash)
        self.file_size = try? container.decodeIfPresent(Int64.self, forKey: .file_size)
        self.format = try? container.decodeIfPresent(String.self, forKey: .format)
        self.lyrics = try? container.decodeIfPresent(String.self, forKey: .lyrics)
        self.genre = try? container.decodeIfPresent(String.self, forKey: .genre)
        self.year = try? container.decodeIfPresent(Int.self, forKey: .year)
        self.owner_id = try? container.decodeIfPresent(String.self, forKey: .owner_id)
        self.visibility = try? container.decodeIfPresent(String.self, forKey: .visibility)
        self.shared_with = try? container.decodeIfPresent(String.self, forKey: .shared_with)
        self.track_number = try? container.decodeIfPresent(Int.self, forKey: .track_number)
    }

    public func toSongEntity() -> SongEntity {
        SongEntity(
            id: id,
            title: title,
            artist: artist,
            artworkURLString: cover_url.isEmpty ? nil : cover_url,
            albumTitle: album,
            albumId: nil,
            artistId: nil,
            durationSec: duration
        )
    }
}

// MARK: - State DTO Models (Matching backend /api/state)

public struct PortMusicTrackDto: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String?
    public let cover: String?
    public let coverFileId: String?
    public let duration: String?
    public let durationSeconds: Int?
    public let storageType: String?
    public let streamSource: String?
    public let sourceType: String?
    public let sourceUrl: String?
    public let sourceFileId: String?
    public let ownerId: String?
    public let lyrics: String?
    public let genre: String?
    public let year: Int?
    public let bpm: Double?
    public let trackNumber: Int?
    public let diskNumber: Int?
    public let explicitContent: Bool?
    public let isAudiobook: Bool?

    public init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        cover: String? = nil,
        coverFileId: String? = nil,
        duration: String? = nil,
        durationSeconds: Int? = nil,
        storageType: String? = "stream",
        streamSource: String? = "youtube",
        sourceType: String? = "stream",
        sourceUrl: String? = nil,
        sourceFileId: String? = nil,
        ownerId: String? = nil,
        lyrics: String? = nil,
        genre: String? = nil,
        year: Int? = nil,
        bpm: Double? = nil,
        trackNumber: Int? = nil,
        diskNumber: Int? = nil,
        explicitContent: Bool? = false,
        isAudiobook: Bool? = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.cover = cover
        self.coverFileId = coverFileId
        self.duration = duration
        self.durationSeconds = durationSeconds
        self.storageType = storageType
        self.streamSource = streamSource
        self.sourceType = sourceType
        self.sourceUrl = sourceUrl
        self.sourceFileId = sourceFileId
        self.ownerId = ownerId
        self.lyrics = lyrics
        self.genre = genre
        self.year = year
        self.bpm = bpm
        self.trackNumber = trackNumber
        self.diskNumber = diskNumber
        self.explicitContent = explicitContent
        self.isAudiobook = isAudiobook
    }

    public init(from song: SongEntity) {
        self.id = song.id
        self.title = song.title
        self.artist = song.artist
        self.album = song.albumTitle
        self.cover = song.artworkURLString
        self.coverFileId = nil
        let durSec = Int(song.durationSec)
        self.duration = "\(durSec / 60):\(String(format: "%02d", durSec % 60))"
        self.durationSeconds = durSec
        self.storageType = "stream"
        self.streamSource = "youtube"
        self.sourceType = "stream"
        self.sourceUrl = nil
        self.sourceFileId = nil
        self.ownerId = nil
        self.lyrics = nil
        self.genre = nil
        self.year = nil
        self.bpm = nil
        self.trackNumber = nil
        self.diskNumber = nil
        self.explicitContent = false
        self.isAudiobook = false
    }

    public func toSongEntity() -> SongEntity {
        SongEntity(
            id: id,
            title: title,
            artist: artist,
            artworkURLString: cover,
            albumTitle: album,
            albumId: nil,
            artistId: nil,
            durationSec: Double(durationSeconds ?? 0)
        )
    }
}

public struct PortMusicPlaylistDto: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let description: String?
    public let cover: String?
    public let tracks: [PortMusicTrackDto]
    public let folderId: String?
    public let color: String?
    public let visibility: String?
    public let ownerId: String?
    public let sharedWith: [String]?
    public let isAudiobook: Bool?
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        name: String,
        description: String? = nil,
        cover: String? = nil,
        tracks: [PortMusicTrackDto] = [],
        folderId: String? = nil,
        color: String? = nil,
        visibility: String? = "public",
        ownerId: String? = nil,
        sharedWith: [String]? = nil,
        isAudiobook: Bool? = false,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.cover = cover
        self.tracks = tracks
        self.folderId = folderId
        self.color = color
        self.visibility = visibility
        self.ownerId = ownerId
        self.sharedWith = sharedWith
        self.isAudiobook = isAudiobook
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct PortMusicFolderDto: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let parentId: String?
    public let parentFolderId: String?
    public let color: String?
    public let ownerId: String?
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        name: String,
        parentId: String? = nil,
        parentFolderId: String? = nil,
        color: String? = nil,
        ownerId: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.parentFolderId = parentFolderId
        self.color = color
        self.ownerId = ownerId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct PortMusicLibraryState: Codable, Sendable, Hashable {
    public var savedPlaylists: [String]
    public var playlistOrder: [String]
    public var folderOrder: [String]
    public var savedAlbums: [String]
    public var savedArtists: [String]
    public var albumFolderMapping: [String: String]?
    public var pinnedPlaylists: [String]
    public var pinnedFolders: [String]

    public init(
        savedPlaylists: [String] = [],
        playlistOrder: [String] = [],
        folderOrder: [String] = [],
        savedAlbums: [String] = [],
        savedArtists: [String] = [],
        albumFolderMapping: [String: String]? = nil,
        pinnedPlaylists: [String] = [],
        pinnedFolders: [String] = []
    ) {
        self.savedPlaylists = savedPlaylists
        self.playlistOrder = playlistOrder
        self.folderOrder = folderOrder
        self.savedAlbums = savedAlbums
        self.savedArtists = savedArtists
        self.albumFolderMapping = albumFolderMapping
        self.pinnedPlaylists = pinnedPlaylists
        self.pinnedFolders = pinnedFolders
    }
}

public struct PortMusicAudiobookBookmark: Codable, Sendable, Hashable {
    public let trackId: String
    public let positionSeconds: Double

    public init(trackId: String, positionSeconds: Double) {
        self.trackId = trackId
        self.positionSeconds = positionSeconds
    }
}

public struct PortMusicState: Codable, Sendable {
    public var playlists: [PortMusicPlaylistDto]
    public var folders: [PortMusicFolderDto]
    public var favorites: [PortMusicTrackDto]
    public var globalTracks: [PortMusicTrackDto]
    public var libraryState: PortMusicLibraryState?
    public var audiobookBookmarks: [String: PortMusicAudiobookBookmark]?
    public var ignoredDuplicatePairs: [String]?
    public var deletedPlaylistIds: [String]?
    public var deletedFolderIds: [String]?
    public var deletedFavoriteIds: [String]?
    public var replaceFavorites: Bool?

    enum CodingKeys: String, CodingKey {
        case playlists
        case folders
        case favorites
        case globalTracks
        case libraryState
        case audiobookBookmarks
        case ignoredDuplicatePairs
        case deletedPlaylistIds = "_deletedPlaylistIds"
        case deletedFolderIds = "_deletedFolderIds"
        case deletedFavoriteIds = "_deletedFavoriteIds"
        case replaceFavorites = "_replaceFavorites"
    }

    public init(
        playlists: [PortMusicPlaylistDto] = [],
        folders: [PortMusicFolderDto] = [],
        favorites: [PortMusicTrackDto] = [],
        globalTracks: [PortMusicTrackDto] = [],
        libraryState: PortMusicLibraryState? = nil,
        audiobookBookmarks: [String: PortMusicAudiobookBookmark]? = nil,
        ignoredDuplicatePairs: [String]? = nil,
        deletedPlaylistIds: [String]? = nil,
        deletedFolderIds: [String]? = nil,
        deletedFavoriteIds: [String]? = nil,
        replaceFavorites: Bool? = nil
    ) {
        self.playlists = playlists
        self.folders = folders
        self.favorites = favorites
        self.globalTracks = globalTracks
        self.libraryState = libraryState
        self.audiobookBookmarks = audiobookBookmarks
        self.ignoredDuplicatePairs = ignoredDuplicatePairs
        self.deletedPlaylistIds = deletedPlaylistIds
        self.deletedFolderIds = deletedFolderIds
        self.deletedFavoriteIds = deletedFavoriteIds
        self.replaceFavorites = replaceFavorites
    }
}

public struct PlaylistDetailsResponse: Codable, Sendable {
    public let playlist: PlaylistRecord
    public let tracks: [TrackRecord]
}

public struct DiscoveryArtistAlbum: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let year: Int?
    public let cover: String?
}

public struct DiscoveryArtistFull: Codable, Sendable {
    public let id: String?
    public let name: String
    public let cover: String?
    public let description: String?
    public let country: String?
    public let nbFan: Int?
    public let topTracks: [DiscoveryTrack]?
    public let albums: [DiscoveryArtistAlbum]?
    public let singles: [DiscoveryArtistAlbum]?
    public let playlists: [DiscoveryPlaylist]?
    public let relatedArtists: [DiscoveryArtist]?
}

// MARK: - Backend Client Class

final class OctaveBackend: @unchecked Sendable {
    static let shared = OctaveBackend()

    private let serverURLKey = "port_music_server_url"
    private let tokenKey = "port_music_auth_token"
    private let defaultServerURL = "http://192.168.178.19:3000"
    private let deviceIdKey = "port_music_device_id"

    var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey), !existing.isEmpty {
            return existing
        }
        let vendor = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let generated = "pm-ios-\(vendor.lowercased())"
        UserDefaults.standard.set(generated, forKey: deviceIdKey)
        return generated
    }

    var serverBaseURLString: String {
        get {
            let saved = UserDefaults.standard.string(forKey: serverURLKey) ?? defaultServerURL
            return saved.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        set {
            var clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !clean.starts(with: "http://") && !clean.starts(with: "https://") {
                clean = "http://" + clean
            }
            UserDefaults.standard.set(clean, forKey: serverURLKey)
        }
    }

    var apiBaseURL: URL {
        URL(string: serverBaseURLString) ?? URL(string: defaultServerURL)!
    }

    var authToken: String? {
        get {
            UserDefaults.standard.string(forKey: tokenKey)
        }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: tokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: tokenKey)
            }
        }
    }

    func setServerBaseURL(_ urlString: String) {
        self.serverBaseURLString = urlString
    }

    func streamURL(for trackId: String, quality: String = "320", title: String? = nil, artist: String? = nil, album: String? = nil) -> URL {
        let base = apiBaseURL.appendingPathComponent("audio").appendingPathComponent(quality).appendingPathComponent(trackId)
        guard title != nil || artist != nil || album != nil else {
            return base
        }
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = []
        if let title, !title.isEmpty { queryItems.append(URLQueryItem(name: "title", value: title)) }
        if let artist, !artist.isEmpty { queryItems.append(URLQueryItem(name: "artist", value: artist)) }
        if let album, !album.isEmpty { queryItems.append(URLQueryItem(name: "album", value: album)) }
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
            return components?.url ?? base
        }
        return base
    }

    func atmosStreamURL(for trackId: String) -> URL {
        apiBaseURL.appendingPathComponent("audio").appendingPathComponent("atmos").appendingPathComponent(trackId)
    }

    func fetchLyrics(for trackId: String) async throws -> Data {
        let url = apiBaseURL.appendingPathComponent("api").appendingPathComponent("lyrics").appendingPathComponent(trackId)
        var req = URLRequest(url: url)
        applyAuth(to: &req)
        let (data, response) = try await URLSession.shared.data(for: req)
        if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 401 {
            handle401()
        }
        return data
    }

    func applyAuth(to request: inout URLRequest) {
        // Geräte- und Lokalisierungs-Header
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        request.setValue(UIDevice.current.model, forHTTPHeaderField: "X-Device-Model")
        request.setValue("PortMusic-iOS", forHTTPHeaderField: "X-Browser")
        request.setValue("de", forHTTPHeaderField: "Accept-Language")

        // Authentifizierungs-Header
        if let token = authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(token, forHTTPHeaderField: "octave-account-key")
        }
    }

    // MARK: - Authentication API

    func login(identifier: String, password: String) async throws -> (user: UserInfo, token: String) {
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("auth").appendingPathComponent("login")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "email": identifier.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        if httpRes.statusCode == 401 {
            throw BackendError.invalidCredentials
        }
        guard (200...299).contains(httpRes.statusCode) else {
            throw BackendError.serverError("HTTP \(httpRes.statusCode)")
        }

        struct BackendLoginResponse: Codable {
            let authenticated: Bool?
            let token: String?
            let userId: String?
            let username: String?
            let displayName: String?
            let role: String?
            let avatar: String?
            let email: String?
            let user: BackendUserDto?
        }
        struct BackendUserDto: Codable {
            let userId: String
            let username: String
            let displayName: String
            let role: String
            let avatar: String?
            let email: String?
        }

        let decoded = try JSONDecoder().decode(BackendLoginResponse.self, from: data)
        guard let resolvedToken = decoded.token ?? extractSessionCookie(from: httpRes) else {
            throw BackendError.missingToken
        }

        let user: UserInfo
        if let u = decoded.user {
            user = UserInfo(userId: u.userId, username: u.username, displayName: u.displayName, role: u.role, avatar: u.avatar, email: u.email)
        } else {
            user = UserInfo(
                userId: decoded.userId ?? "user",
                username: decoded.username ?? identifier,
                displayName: decoded.displayName ?? identifier,
                role: decoded.role ?? "user",
                avatar: decoded.avatar,
                email: decoded.email
            )
        }

        self.authToken = resolvedToken
        return (user, resolvedToken)
    }

    func register(username: String, email: String, password: String, displayName: String? = nil) async throws -> (user: UserInfo, token: String) {
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("auth").appendingPathComponent("register")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "username": username.trimmingCharacters(in: .whitespacesAndNewlines),
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password,
            "displayName": displayName ?? username
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        guard (200...299).contains(httpRes.statusCode) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = json["message"] as? String ?? json["error"] as? String {
                throw BackendError.serverError(msg)
            }
            throw BackendError.serverError("HTTP \(httpRes.statusCode)")
        }

        struct BackendRegisterResponse: Codable {
            let success: Bool?
            let token: String?
            let userId: String?
            let displayName: String?
        }

        let decoded = try JSONDecoder().decode(BackendRegisterResponse.self, from: data)
        let resolvedToken = decoded.token ?? extractSessionCookie(from: httpRes) ?? ""
        self.authToken = resolvedToken

        let user = UserInfo(
            userId: decoded.userId ?? "user",
            username: username,
            displayName: decoded.displayName ?? username,
            email: email
        )
        return (user, resolvedToken)
    }

    func testConnection(customURLString: String? = nil) async -> Bool {
        let baseURL: URL
        if let custom = customURLString?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            var clean = custom.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !clean.starts(with: "http://") && !clean.starts(with: "https://") {
                clean = "http://" + clean
            }
            baseURL = URL(string: clean) ?? apiBaseURL
        } else {
            baseURL = apiBaseURL
        }

        let endpoint = baseURL.appendingPathComponent("api").appendingPathComponent("auth").appendingPathComponent("status")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpRes = response as? HTTPURLResponse else { return false }
            return (200...299).contains(httpRes.statusCode)
        } catch {
            return false
        }
    }

    func checkSession() async throws -> UserInfo {
        guard let token = authToken, !token.isEmpty else {
            throw BackendError.missingToken
        }
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("auth").appendingPathComponent("check")
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 8.0
        applyAuth(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        if httpRes.statusCode == 401 {
            handle401()
            throw BackendError.unauthorized
        }

        guard (200...299).contains(httpRes.statusCode) else {
            throw BackendError.serverError("HTTP \(httpRes.statusCode)")
        }

        struct CheckResponseDto: Codable {
            let authenticated: Bool?
            let userId: String?
            let username: String?
            let displayName: String?
            let role: String?
            let avatar: String?
            let email: String?
            let user: NestedUserDto?
        }
        struct NestedUserDto: Codable {
            let userId: String
            let username: String
            let displayName: String
            let role: String?
            let avatar: String?
            let email: String?
        }

        let decoded = try JSONDecoder().decode(CheckResponseDto.self, from: data)
        if let u = decoded.user {
            return UserInfo(
                userId: u.userId,
                username: u.username,
                displayName: u.displayName,
                role: u.role ?? "user",
                avatar: u.avatar,
                email: u.email
            )
        } else if let uid = decoded.userId, let un = decoded.username {
            return UserInfo(
                userId: uid,
                username: un,
                displayName: decoded.displayName ?? un,
                role: decoded.role ?? "user",
                avatar: decoded.avatar,
                email: decoded.email
            )
        } else {
            throw BackendError.invalidResponse
        }
    }

    func logout() async {
        guard let token = authToken, !token.isEmpty else { return }
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("auth").appendingPathComponent("logout")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 5.0
        applyAuth(to: &request)

        _ = try? await URLSession.shared.data(for: request)
    }

    func handle401() {
        Task { @MainActor in
            AccountStore.shared.signOut(notifyServer: false)
        }
    }

    private func extractSessionCookie(from response: HTTPURLResponse) -> String? {
        guard let rawCookie = response.value(forHTTPHeaderField: "Set-Cookie") else { return nil }
        for part in rawCookie.components(separatedBy: ";") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "pm_session=") {
                return String(trimmed.dropFirst("pm_session=".count))
            } else if trimmed.starts(with: "sessionId=") {
                return String(trimmed.dropFirst("sessionId=".count))
            }
        }
        return nil
    }

    // MARK: - Port Music Discovery & Home API

    func fetchDiscoveryHome() async throws -> DiscoveryHomeResponse {
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("discovery").appendingPathComponent("home")
        var req = URLRequest(url: endpoint)
        applyAuth(to: &req)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        if httpRes.statusCode == 401 {
            handle401()
            throw BackendError.unauthorized
        }
        guard (200...299).contains(httpRes.statusCode) else {
            throw BackendError.serverError("Discovery Home konnte nicht geladen werden")
        }
        return try JSONDecoder().decode(DiscoveryHomeResponse.self, from: data)
    }

    func fetchRecommendations(limit: Int = 10) async throws -> [DiscoveryTrack] {
        var components = URLComponents(url: apiBaseURL.appendingPathComponent("api").appendingPathComponent("discovery").appendingPathComponent("recommendations"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        guard let url = components?.url else { return [] }
        var req = URLRequest(url: url)
        applyAuth(to: &req)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse else {
            return []
        }
        if httpRes.statusCode == 401 {
            handle401()
            return []
        }
        guard (200...299).contains(httpRes.statusCode) else {
            return []
        }
        return (try? JSONDecoder().decode([DiscoveryTrack].self, from: data)) ?? []
    }

    func fetchUserPlaylists() async throws -> [PlaylistRecord] {
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("playlists")
        var req = URLRequest(url: endpoint)
        applyAuth(to: &req)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse else {
            return []
        }
        if httpRes.statusCode == 401 {
            handle401()
            return []
        }
        guard (200...299).contains(httpRes.statusCode) else {
            return []
        }
        return (try? JSONDecoder().decode([PlaylistRecord].self, from: data)) ?? []
    }

    func fetchPlaylistDetails(id: String) async throws -> PlaylistDetailsResponse {
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("playlists").appendingPathComponent(id)
        var req = URLRequest(url: endpoint)
        applyAuth(to: &req)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            throw BackendError.serverError("Playlist konnte nicht geladen werden")
        }
        return try JSONDecoder().decode(PlaylistDetailsResponse.self, from: data)
    }

    func fetchOnlinePlaylistTracks(id: String) async throws -> [SongEntity] {
        let endpoint = id.starts(with: "apple_")
            ? apiBaseURL.appendingPathComponent("api").appendingPathComponent("apple").appendingPathComponent("playlist").appendingPathComponent(id.replacingOccurrences(of: "apple_", with: ""))
            : apiBaseURL.appendingPathComponent("api").appendingPathComponent("discovery").appendingPathComponent("playlist").appendingPathComponent(id)

        var req = URLRequest(url: endpoint)
        applyAuth(to: &req)
        let (data, _) = try await URLSession.shared.data(for: req)

        struct OnlinePlaylistResponse: Codable {
            let tracks: [DiscoveryTrack]?
        }
        if let res = try? JSONDecoder().decode(OnlinePlaylistResponse.self, from: data), let tr = res.tracks {
            return tr.map { $0.toSongEntity() }
        }
        if let tr = try? JSONDecoder().decode([DiscoveryTrack].self, from: data) {
            return tr.map { $0.toSongEntity() }
        }
        return []
    }

    func fetchAlbumTracks(id: String) async throws -> [SongEntity] {
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("discovery").appendingPathComponent("album").appendingPathComponent(id)
        var req = URLRequest(url: endpoint)
        applyAuth(to: &req)
        let (data, _) = try await URLSession.shared.data(for: req)

        struct AlbumDetailDto: Codable {
            let tracks: [DiscoveryTrack]?
        }
        struct AlbumResponseDto: Codable {
            let album: AlbumDetailDto?
        }
        if let res = try? JSONDecoder().decode(AlbumResponseDto.self, from: data), let tr = res.album?.tracks {
            return tr.map { $0.toSongEntity() }
        }
        return []
    }

    func createPlaylist(title: String, description: String? = nil) async throws -> PlaylistRecord {
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("playlists")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(to: &req)
        let body: [String: Any] = [
            "title": title,
            "description": description as Any
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        if httpRes.statusCode == 401 {
            handle401()
            throw BackendError.unauthorized
        }
        guard (200...299).contains(httpRes.statusCode) else {
            throw BackendError.serverError("Playlist konnte nicht erstellt werden")
        }
        return try JSONDecoder().decode(PlaylistRecord.self, from: data)
    }

    // MARK: - Favorites API

    public func fetchFavorites() async throws -> [SongEntity] {
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("favorites")
        var req = URLRequest(url: endpoint)
        applyAuth(to: &req)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse else {
            return []
        }
        if httpRes.statusCode == 401 {
            handle401()
            return []
        }
        guard (200...299).contains(httpRes.statusCode) else {
            return []
        }
        let records = (try? JSONDecoder().decode([TrackRecord].self, from: data)) ?? []
        return records.map { $0.toSongEntity() }
    }

    public func addFavorite(song: SongEntity) async throws -> Bool {
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("favorites")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(to: &req)

        let record = TrackRecord(from: song)
        req.httpBody = try JSONEncoder().encode(record)

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse else {
            return false
        }
        if httpRes.statusCode == 401 {
            handle401()
            throw BackendError.unauthorized
        }
        return (200...299).contains(httpRes.statusCode)
    }

    public func removeFavorite(id: String) async throws -> Bool {
        guard let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let endpoint = URL(string: "\(serverBaseURLString)/api/favorites/\(encoded)") else {
            return false
        }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "DELETE"
        applyAuth(to: &req)

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse else {
            return false
        }
        if httpRes.statusCode == 401 {
            handle401()
            throw BackendError.unauthorized
        }
        return (200...299).contains(httpRes.statusCode) || httpRes.statusCode == 404
    }

    public func checkFavorite(id: String) async throws -> Bool {
        guard let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let endpoint = URL(string: "\(serverBaseURLString)/api/favorites/\(encoded)") else {
            return false
        }
        var req = URLRequest(url: endpoint)
        applyAuth(to: &req)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            return false
        }
        return (try? JSONDecoder().decode(Bool.self, from: data)) ?? false
    }

    // MARK: - State API

    public func fetchState() async throws -> PortMusicState? {
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("state")
        var req = URLRequest(url: endpoint)
        applyAuth(to: &req)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse else {
            return nil
        }
        if httpRes.statusCode == 401 {
            handle401()
            throw BackendError.unauthorized
        }
        guard (200...299).contains(httpRes.statusCode) else {
            return nil
        }
        return try? JSONDecoder().decode(PortMusicState.self, from: data)
    }

    public func saveState(_ state: PortMusicState) async throws -> Bool {
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("state")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
        applyAuth(to: &req)

        req.httpBody = try JSONEncoder().encode(state)

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse else {
            return false
        }
        if httpRes.statusCode == 401 {
            handle401()
            throw BackendError.unauthorized
        }
        return (200...299).contains(httpRes.statusCode)
    }

    func fetchDiscoveryArtist(name: String) async throws -> DiscoveryArtistFull {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw BackendError.serverError("Ungültiger Künstlername")
        }
        let url = URL(string: "\(serverBaseURLString)/api/discovery/artist/\(encoded)")!
        var req = URLRequest(url: url)
        applyAuth(to: &req)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            throw BackendError.serverError("Künstlerprofil konnte nicht geladen werden")
        }
        struct ArtistWrapper: Codable {
            let success: Bool?
            let artist: DiscoveryArtistFull?
        }
        let res = try JSONDecoder().decode(ArtistWrapper.self, from: data)
        guard let artist = res.artist else {
            throw BackendError.serverError("Künstler nicht gefunden")
        }
        return artist
    }

    // MARK: - Search Catalog (Backend Discovery Search First)

    func searchDiscovery(query: String) async throws -> DiscoverySearchResponse {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return DiscoverySearchResponse(tracks: [], albums: [], artists: [], playlists: [])
        }
        let url = URL(string: "\(serverBaseURLString)/api/discovery/search?q=\(encoded)")!
        var req = URLRequest(url: url)
        applyAuth(to: &req)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            throw BackendError.serverError("Suche fehlgeschlagen")
        }
        return try JSONDecoder().decode(DiscoverySearchResponse.self, from: data)
    }

    func search(query: String) async throws -> [SongEntity] {
        // 1. Try Port Music backend discovery search first
        if let res = try? await searchDiscovery(query: query), let tracks = res.tracks, !tracks.isEmpty {
            return tracks.map { $0.toSongEntity() }
        }

        // 2. Fallback to iTunes API
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=30") else {
            return []
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
        return response.results.map {
            SongEntity(
                id: String($0.trackId),
                title: $0.trackName,
                artist: $0.artistName,
                artworkURLString: $0.artworkUrl100?.replacingOccurrences(of: "100x100bb", with: "600x600bb"),
                albumTitle: $0.collectionName,
                albumId: $0.collectionId != nil ? String($0.collectionId!) : nil,
                artistId: $0.artistId != nil ? String($0.artistId!) : nil,
                durationSec: Double($0.trackTimeMillis ?? 0) / 1000.0
            )
        }
    }
}

public enum BackendError: LocalizedError {
    case invalidResponse
    case invalidCredentials
    case missingToken
    case unauthorized
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Ungültige Antwort vom Server."
        case .invalidCredentials:
            return "Ungültiger Benutzername oder Passwort."
        case .missingToken:
            return "Authentifizierungstoken nicht erhalten."
        case .unauthorized:
            return "Sitzung abgelaufen. Bitte erneut anmelden."
        case .serverError(let msg):
            return "Serverfehler: \(msg)"
        }
    }
}

private struct ITunesSearchResponse: Codable {
    let results: [ITunesItem]
}

private struct ITunesItem: Codable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let collectionName: String?
    let collectionId: Int?
    let artistId: Int?
    let artworkUrl100: String?
    let trackTimeMillis: Int?
}
