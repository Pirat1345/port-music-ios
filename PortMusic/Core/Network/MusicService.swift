import Foundation

public final class MusicService {
    public static let shared = MusicService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        self.session = URLSession(configuration: config)
    }

    private func cleanURL(_ raw: String) -> String {
        var base = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !base.hasPrefix("http://") && !base.hasPrefix("https://") {
            base = "http://" + base
        }
        return base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    // MARK: - Stream URL Builder
    public func streamURL(for track: Track, serverURL: String) -> URL? {
        let base = cleanURL(serverURL)
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        let encodedId = track.id.addingPercentEncoding(withAllowedCharacters: allowed) ?? track.id
        guard var components = URLComponents(string: "\(base)/api/stream/\(encodedId)") else {
            return nil
        }

        var items: [URLQueryItem] = [
            URLQueryItem(name: "title", value: track.title),
            URLQueryItem(name: "artist", value: track.artist)
        ]
        if let album = track.album, !album.isEmpty {
            items.append(URLQueryItem(name: "album", value: album))
        }
        if let cover = track.coverUrl, !cover.isEmpty {
            items.append(URLQueryItem(name: "cover", value: cover))
            items.append(URLQueryItem(name: "cover_url", value: cover))
        }
        components.queryItems = items
        return components.url
    }

    // MARK: - Fetch Home Discovery Shelves
    public func fetchHomeDiscovery(serverURL: String, token: String?) async -> DiscoveryHomeResponse? {
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/discovery/home") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(DiscoveryHomeResponse.self, from: data)
            return decoded
        } catch {
            print("MusicService.fetchHomeDiscovery error: \(error)")
            return nil
        }
    }

    // MARK: - Online Search
    public func search(query: String, serverURL: String, token: String?) async -> [Track] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let base = cleanURL(serverURL)
        guard var components = URLComponents(string: "\(base)/api/discovery/search") else {
            return []
        }
        components.queryItems = [URLQueryItem(name: "q", value: trimmed)]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }
            if let decoded = try? JSONDecoder().decode(DiscoverySearchResponse.self, from: data) {
                return decoded.tracks?.map { $0.toTrack() } ?? []
            }
            if let trackList = try? JSONDecoder().decode([DiscoveryTrack].self, from: data) {
                return trackList.map { $0.toTrack() }
            }
            return []
        } catch {
            print("MusicService.search error: \(error)")
            return []
        }
    }

    // MARK: - Discovery Full Search (/api/discovery/search?q={query})
    public func fetchDiscoverySearch(query: String, serverURL: String, token: String?) async -> DiscoverySearchResponse? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let base = cleanURL(serverURL)
        guard var components = URLComponents(string: "\(base)/api/discovery/search") else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "q", value: trimmed)]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return try JSONDecoder().decode(DiscoverySearchResponse.self, from: data)
        } catch {
            print("MusicService.fetchDiscoverySearch error: \(error)")
            return nil
        }
    }

    // MARK: - Fetch Listening History (/api/history)
    public struct HistoryEntry: Codable {
        public let track: DiscoveryTrack?
        public let timestamp: Int64?
    }

    public func fetchHistory(serverURL: String, token: String?) async -> [Track] {
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/history") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }
            if let entries = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
                return entries.compactMap { $0.track?.toTrack() }
            }
            if let directTracks = try? JSONDecoder().decode([DiscoveryTrack].self, from: data) {
                return directTracks.map { $0.toTrack() }
            }
            return []
        } catch {
            return []
        }
    }

    // MARK: - Fetch User Playlists (/api/playlists)
    public func fetchPlaylists(serverURL: String, token: String?) async -> [DiscoveryPlaylist] {
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/playlists") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }
            if let list = try? JSONDecoder().decode([DiscoveryPlaylist].self, from: data) {
                return list
            }
            return []
        } catch {
            return []
        }
    }

    // MARK: - Fetch Favorites (/api/favorites)
    public func fetchFavorites(serverURL: String, token: String?) async -> [Track] {
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/favorites") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }
            if let tracks = try? JSONDecoder().decode([DiscoveryTrack].self, from: data) {
                return tracks.map { $0.toTrack() }
            }
            if let directTracks = try? JSONDecoder().decode([Track].self, from: data) {
                return directTracks
            }
            return []
        } catch {
            return []
        }
    }

    // MARK: - Toggle Favorite (/api/favorites)
    public func toggleFavorite(track: Track, serverURL: String, token: String?) async -> Bool {
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/favorites") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "id": track.id,
            "title": track.title,
            "artist": track.artist,
            "album": track.album ?? "",
            "cover_url": track.coverUrl ?? ""
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                return true
            }
            return false
        } catch {
            return false
        }
    }
}
