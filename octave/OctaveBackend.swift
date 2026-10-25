//
//  OctaveBackend.swift
//  Port Music
//
//  Full Port Music Backend API client: Discovery, Playlists, Streaming & Search.
//

import Foundation

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
    public let duration: Double?
    public let cover_url: String?

    public func toSongEntity() -> SongEntity {
        SongEntity(
            id: id,
            title: title,
            artist: artist,
            artworkURLString: cover_url,
            albumTitle: album,
            durationSec: duration ?? 0.0
        )
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

    func streamURL(for trackId: String, quality: String = "320") -> URL {
        apiBaseURL.appendingPathComponent("audio").appendingPathComponent(quality).appendingPathComponent(trackId)
    }

    func atmosStreamURL(for trackId: String) -> URL {
        apiBaseURL.appendingPathComponent("audio").appendingPathComponent("atmos").appendingPathComponent(trackId)
    }

    func fetchLyrics(for trackId: String) async throws -> Data {
        let url = apiBaseURL.appendingPathComponent("api").appendingPathComponent("lyrics").appendingPathComponent(trackId)
        var req = URLRequest(url: url)
        applyAuth(to: &req)
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    func applyAuth(to request: inout URLRequest) {
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

    func checkSession() async throws -> UserInfo? {
        guard let token = authToken, !token.isEmpty else { return nil }
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("auth").appendingPathComponent("me")
        var request = URLRequest(url: endpoint)
        applyAuth(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            return nil
        }

        struct MeResponse: Codable {
            let authenticated: Bool
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

        if let me = try? JSONDecoder().decode(MeResponse.self, from: data), me.authenticated, let u = me.user {
            return UserInfo(userId: u.userId, username: u.username, displayName: u.displayName, role: u.role, avatar: u.avatar, email: u.email)
        }
        return nil
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
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            throw BackendError.serverError("Discovery Home konnte nicht geladen werden")
        }
        return try JSONDecoder().decode(DiscoveryHomeResponse.self, from: data)
    }

    func fetchUserPlaylists() async throws -> [PlaylistRecord] {
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("playlists")
        var req = URLRequest(url: endpoint)
        applyAuth(to: &req)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
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
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            throw BackendError.serverError("Playlist konnte nicht erstellt werden")
        }
        return try JSONDecoder().decode(PlaylistRecord.self, from: data)
    }

    func fetchFavorites() async throws -> [SongEntity] {
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("favorites")
        var req = URLRequest(url: endpoint)
        applyAuth(to: &req)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            return []
        }
        let records = (try? JSONDecoder().decode([TrackRecord].self, from: data)) ?? []
        return records.map { $0.toSongEntity() }
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
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Ungültige Antwort vom Server."
        case .invalidCredentials:
            return "Ungültiger Benutzername oder Passwort."
        case .missingToken:
            return "Authentifizierungstoken nicht erhalten."
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
