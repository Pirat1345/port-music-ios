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

    // MARK: - Device Identifier for Sync
    public var currentDeviceId: String {
        let key = "port_music_device_id_ios"
        if let stored = UserDefaults.standard.string(forKey: key), !stored.isEmpty {
            return stored
        }
        let newId = "ios-" + UUID().uuidString.prefix(12).lowercased()
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    // MARK: - Universal Track Parser from JSON (Stats & History Resilient)
    public func parseTracksFromAnyJSON(data: Data) -> [Track] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var results: [Track] = []

        // Case 1: /api/stats -> { "currentDeviceId": "...", "devices": [ { "history": [ { "track": {...}, "timestamp": ... } ] } ] }
        if let dict = json as? [String: Any], let devices = dict["devices"] as? [[String: Any]] {
            var allEntries: [(track: Track, timestamp: Int64)] = []
            for dev in devices {
                if let hist = dev["history"] as? [[String: Any]] {
                    for item in hist {
                        let ts = (item["timestamp"] as? NSNumber)?.int64Value ?? 0
                        if let tDict = item["track"] as? [String: Any], let track = trackFromDictionary(tDict) {
                            allEntries.append((track, ts))
                        }
                    }
                }
            }
            allEntries.sort { $0.timestamp > $1.timestamp }
            var seen = Set<String>()
            for entry in allEntries {
                if !seen.contains(entry.track.id) {
                    seen.insert(entry.track.id)
                    results.append(entry.track)
                }
            }
            if !results.isEmpty { return results }
        }

        // Case 2: /api/history -> Array of { id: ..., track: { ... }, played_at: ... }
        if let arr = json as? [[String: Any]] {
            var seen = Set<String>()
            for item in arr {
                if let tDict = item["track"] as? [String: Any], let track = trackFromDictionary(tDict) {
                    if !seen.contains(track.id) {
                        seen.insert(track.id)
                        results.append(track)
                    }
                } else if let track = trackFromDictionary(item) {
                    // Case 3: Direct array of tracks
                    if !seen.contains(track.id) {
                        seen.insert(track.id)
                        results.append(track)
                    }
                }
            }
        }
        return results
    }

    private func trackFromDictionary(_ dict: [String: Any]) -> Track? {
        guard let id = (dict["id"] as? String) ?? (dict["trackId"] as? String), !id.isEmpty,
              let title = dict["title"] as? String, !title.isEmpty else {
            return nil
        }
        let artist = (dict["artist"] as? String) ?? "Unbekannt"
        let album = dict["album"] as? String
        let cover = (dict["cover"] as? String) ?? (dict["cover_url"] as? String) ?? (dict["artworkUrl"] as? String)

        var durSec: Double = 0.0
        var durStr = "0:00"
        if let dNum = dict["duration"] as? NSNumber {
            durSec = dNum.doubleValue
            let m = Int(durSec) / 60
            let s = Int(durSec) % 60
            durStr = String(format: "%d:%02d", m, s)
        } else if let dStr = dict["duration"] as? String {
            durStr = dStr
            let parts = dStr.split(separator: ":").compactMap { Double($0) }
            if parts.count == 2 { durSec = parts[0] * 60 + parts[1] }
            else if parts.count == 3 { durSec = parts[0] * 3600 + parts[1] * 60 + parts[2] }
        }
        if let dsNum = dict["durationSeconds"] as? NSNumber, durSec == 0 {
            durSec = dsNum.doubleValue
        }

        return Track(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: durStr,
            durationSeconds: durSec,
            coverUrl: cover,
            isLive: false,
            isExplicit: (dict["is_explicit"] as? Bool) ?? false
        )
    }

    // MARK: - Fetch Listening History (/api/stats + /api/history)
    public func fetchStats(serverURL: String, token: String?) async -> [Track] {
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/stats") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(currentDeviceId, forHTTPHeaderField: "X-Device-ID")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }
            return parseTracksFromAnyJSON(data: data)
        } catch {
            return []
        }
    }

    public func fetchHistory(serverURL: String, token: String?) async -> [Track] {
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/history") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(currentDeviceId, forHTTPHeaderField: "X-Device-ID")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }
            return parseTracksFromAnyJSON(data: data)
        } catch {
            return []
        }
    }

    public func fetchStatsAndHistory(serverURL: String, token: String?) async -> [Track] {
        async let statsFetch = fetchStats(serverURL: serverURL, token: token)
        async let historyFetch = fetchHistory(serverURL: serverURL, token: token)
        let (statsTracks, histTracks) = await (statsFetch, historyFetch)

        var combined: [Track] = []
        var seen = Set<String>()

        for t in statsTracks {
            if !seen.contains(t.id) {
                seen.insert(t.id)
                combined.append(t)
            }
        }
        for t in histTracks {
            if !seen.contains(t.id) {
                seen.insert(t.id)
                combined.append(t)
            }
        }
        return combined
    }

    // MARK: - Report Playback to Server (/api/stats + /api/playback)
    public func reportPlayback(track: Track, serverURL: String, token: String?) async {
        let base = cleanURL(serverURL)
        let devId = currentDeviceId
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

        // 1. Sync to /api/stats (Stores in user_settings for multi-device sync)
        if let statsURL = URL(string: "\(base)/api/stats") {
            var req = URLRequest(url: statsURL)
            req.httpMethod = "PUT"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(devId, forHTTPHeaderField: "X-Device-ID")
            if let tok = token, !tok.isEmpty {
                req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
                req.setValue(tok, forHTTPHeaderField: "x-session-token")
            }

            let trackDict: [String: Any] = [
                "id": track.id,
                "title": track.title,
                "artist": track.artist,
                "cover": track.coverUrl ?? "/default-cover.svg",
                "duration": track.duration,
                "durationSeconds": track.durationSeconds
            ]
            let payload: [String: Any] = [
                "history": [
                    [
                        "trackId": track.id,
                        "track": trackDict,
                        "timestamp": nowMs,
                        "durationListened": 0
                    ]
                ],
                "totalListenTime": 0
            ]
            if let bodyData = try? JSONSerialization.data(withJSONObject: payload) {
                req.httpBody = bodyData
                _ = try? await session.data(for: req)
            }
        }

        // 2. Sync to /api/playback (Updates active session playback)
        if let playbackURL = URL(string: "\(base)/api/playback") {
            var req = URLRequest(url: playbackURL)
            req.httpMethod = "PUT"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(devId, forHTTPHeaderField: "X-Device-ID")
            if let tok = token, !tok.isEmpty {
                req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
                req.setValue(tok, forHTTPHeaderField: "x-session-token")
            }

            let playbackPayload: [String: Any] = [
                "track": [
                    "id": track.id,
                    "title": track.title,
                    "artist": track.artist,
                    "cover": track.coverUrl ?? "/default-cover.svg",
                    "duration": track.duration,
                    "durationSeconds": track.durationSeconds
                ],
                "isPlaying": true,
                "progress": 0
            ]
            if let bodyData = try? JSONSerialization.data(withJSONObject: playbackPayload) {
                req.httpBody = bodyData
                _ = try? await session.data(for: req)
            }
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
