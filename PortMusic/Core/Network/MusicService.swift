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

    // MARK: - Online Artist Discovery (/api/discovery/artist/:name)
    public func fetchArtist(name: String, serverURL: String, token: String?) async -> DiscoveryArtistDetailData? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let base = cleanURL(serverURL)
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        let encodedName = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) ?? trimmed
        guard let url = URL(string: "\(base)/api/discovery/artist/\(encodedName)") else {
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
            if let envelope = try? JSONDecoder().decode(DiscoveryArtistResponse.self, from: data),
               let artist = envelope.artist {
                return artist
            }
            if let direct = try? JSONDecoder().decode(DiscoveryArtistDetailData.self, from: data) {
                return direct
            }
            return nil
        } catch {
            print("MusicService.fetchArtist error: \(error)")
            return nil
        }
    }

    // MARK: - Online Album Discovery (/api/discovery/album/:id)
    public func fetchAlbum(id: String, serverURL: String, token: String?) async -> DiscoveryAlbumDetailData? {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let base = cleanURL(serverURL)
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        let encodedId = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) ?? trimmed
        guard let url = URL(string: "\(base)/api/discovery/album/\(encodedId)") else {
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
            if let envelope = try? JSONDecoder().decode(DiscoveryAlbumResponse.self, from: data),
               let album = envelope.album {
                return album
            }
            if let direct = try? JSONDecoder().decode(DiscoveryAlbumDetailData.self, from: data) {
                return direct
            }
            return nil
        } catch {
            print("MusicService.fetchAlbum error: \(error)")
            return nil
        }
    }

    // MARK: - Search History Sync (/api/user-settings/search-history)
    public func fetchSearchHistory(serverURL: String, token: String?) async -> [String] {
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/user-settings/search-history") else {
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
            if let decoded = try? JSONDecoder().decode([String].self, from: data) {
                return decoded
            }
            return []
        } catch {
            return []
        }
    }

    public func saveSearchHistory(_ history: [String], serverURL: String, token: String?) async {
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/user-settings/search-history") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        let cleanList = Array(history.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(30))
        guard let bodyData = try? JSONEncoder().encode(cleanList) else { return }
        request.httpBody = bodyData

        do {
            _ = try await session.data(for: request)
        } catch {
            // Silently handle network errors
        }
    }

    // MARK: - Apple Music Browse Categories (/api/categories)
    public func fetchCategories(serverURL: String) async -> [BrowseCategoryItem] {
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/categories") else {
            return BrowseCategoryItem.defaultCategories
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return BrowseCategoryItem.defaultCategories
            }
            let decoded = try JSONDecoder().decode([BrowseCategoryItem].self, from: data)
            let cleaned = decoded.filter { !$0.title.contains("3D") && $0.id != "1564180390" }
            return cleaned.isEmpty ? BrowseCategoryItem.defaultCategories : cleaned
        } catch {
            return BrowseCategoryItem.defaultCategories
        }
    }

    // MARK: - Category Detail (/api/category/:id)
    public func fetchCategoryDetail(id: String, serverURL: String, token: String?) async -> AppleCategoryDetailData? {
        let base = cleanURL(serverURL)
        guard let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(base)/api/category/\(encoded)") else {
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
            return try JSONDecoder().decode(AppleCategoryDetailData.self, from: data)
        } catch {
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

    // MARK: - Fetch User Playlists (/api/playlists & /api/state)
    public func fetchPlaylists(serverURL: String, token: String?) async -> [DiscoveryPlaylist] {
        let base = cleanURL(serverURL)
        var resultPlaylists: [DiscoveryPlaylist] = []

        // 1. Try /api/playlists
        if let url = URL(string: "\(base)/api/playlists") {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            if let tok = token, !tok.isEmpty {
                request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            }

            if let (data, response) = try? await session.data(for: request),
               let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                if let list = try? JSONDecoder().decode([DiscoveryPlaylist].self, from: data), !list.isEmpty {
                    resultPlaylists.append(contentsOf: list)
                } else if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    for item in jsonArray {
                        guard let id = item["id"] as? String else { continue }
                        let title = item["title"] as? String ?? item["name"] as? String ?? "Playlist"
                        let cover = item["cover_url"] as? String ?? item["cover"] as? String ?? ""
                        let user = item["owner_id"] as? String ?? item["user"] as? String
                        resultPlaylists.append(DiscoveryPlaylist(id: id, title: title, cover: cover, nbTracks: nil, user: user))
                    }
                }
            }
        }

        // 2. Also check /api/state if empty or to get full user playlists with track counts
        if resultPlaylists.isEmpty, let stateUrl = URL(string: "\(base)/api/state") {
            var request = URLRequest(url: stateUrl)
            request.httpMethod = "GET"
            if let tok = token, !tok.isEmpty {
                request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            }

            if let (data, response) = try? await session.data(for: request),
               let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let pls = json["playlists"] as? [[String: Any]] {
                for pl in pls {
                    guard let id = pl["id"] as? String else { continue }
                    let title = pl["name"] as? String ?? pl["title"] as? String ?? "Playlist"
                    let cover = pl["cover"] as? String ?? pl["cover_url"] as? String ?? ""
                    let tracks = pl["tracks"] as? [Any]
                    let nbTracks = tracks?.count
                    resultPlaylists.append(DiscoveryPlaylist(id: id, title: title, cover: cover, nbTracks: nbTracks, user: nil))
                }
            }
        }

        return resultPlaylists
    }

    // MARK: - Fetch Favorites (/api/favorites & /api/state)
    public func fetchFavorites(serverURL: String, token: String?) async -> [Track] {
        let base = cleanURL(serverURL)
        var resultTracks: [Track] = []

        // Helper to parse dynamic track dictionaries from backend TrackRecord / ApiTrackDto
        func parseTrackDict(_ item: [String: Any]) -> Track? {
            guard let id = item["id"] as? String, !id.isEmpty else { return nil }
            let title = item["title"] as? String ?? item["name"] as? String ?? "Kein Titel"
            let artist = item["artist"] as? String ?? "Unbekannter Interpret"
            let album = item["album"] as? String
            let cover = item["cover_url"] as? String ?? item["cover"] as? String ?? item["coverUrl"] as? String

            let durationSeconds: Double
            if let d = item["duration"] as? Double {
                durationSeconds = d
            } else if let d = item["durationSeconds"] as? Double {
                durationSeconds = d
            } else if let d = item["durationSeconds"] as? Int {
                durationSeconds = Double(d)
            } else if let d = item["duration_seconds"] as? Int {
                durationSeconds = Double(d)
            } else {
                durationSeconds = 0
            }

            let durationStr: String
            if let s = item["duration"] as? String, !s.isEmpty {
                durationStr = s
            } else {
                let sec = Int(max(0, durationSeconds))
                let m = sec / 60
                let s = sec % 60
                durationStr = String(format: "%d:%02d", m, s)
            }

            let isExp = (item["isExplicit"] as? Bool) ?? (item["explicit_content"] as? Bool) ?? false
            return Track(
                id: id,
                title: title,
                artist: artist,
                album: album,
                duration: durationStr,
                durationSeconds: durationSeconds,
                coverUrl: cover,
                isLive: false,
                isExplicit: isExp
            )
        }

        // 1. Try /api/favorites
        if let url = URL(string: "\(base)/api/favorites") {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            if let tok = token, !tok.isEmpty {
                request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            }

            if let (data, response) = try? await session.data(for: request),
               let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    for item in jsonArray {
                        if let track = parseTrackDict(item) {
                            resultTracks.append(track)
                        }
                    }
                } else if let tracks = try? JSONDecoder().decode([DiscoveryTrack].self, from: data) {
                    resultTracks.append(contentsOf: tracks.map { $0.toTrack() })
                } else if let directTracks = try? JSONDecoder().decode([Track].self, from: data) {
                    resultTracks.append(contentsOf: directTracks)
                }
            }
        }

        // 2. Also check /api/state if /api/favorites was empty
        if resultTracks.isEmpty, let stateUrl = URL(string: "\(base)/api/state") {
            var request = URLRequest(url: stateUrl)
            request.httpMethod = "GET"
            if let tok = token, !tok.isEmpty {
                request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            }

            if let (data, response) = try? await session.data(for: request),
               let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let favList = json["favorites"] as? [[String: Any]] {
                for item in favList {
                    if let track = parseTrackDict(item) {
                        resultTracks.append(track)
                    }
                }
            }
        }

        await MainActor.run {
            FavoritesManager.shared.syncWithList(resultTracks)
        }
        return resultTracks
    }

    // MARK: - Check Favorite (/api/favorites/:id)
    public func checkIsFavorite(trackId: String, serverURL: String, token: String?) async -> Bool {
        let trimmed = trackId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let base = cleanURL(serverURL)
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        let encodedId = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) ?? trimmed
        guard let url = URL(string: "\(base)/api/favorites/\(encodedId)") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return false
            }
            if let isFav = try? JSONDecoder().decode(Bool.self, from: data) {
                await MainActor.run {
                    FavoritesManager.shared.setFavorite(trackId: trimmed, isFavorite: isFav)
                }
                return isFav
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let isFav = (json["isFavorite"] as? Bool) ?? (json["favorite"] as? Bool) {
                await MainActor.run {
                    FavoritesManager.shared.setFavorite(trackId: trimmed, isFavorite: isFav)
                }
                return isFav
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Add Favorite (POST /api/favorites)
    public func addFavorite(track: Track, serverURL: String, token: String?) async -> Bool {
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/favorites") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        var durSec: Double = 210.0
        let parts = track.duration.split(separator: ":")
        if parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) {
            durSec = m * 60 + s
        }

        let body: [String: Any] = [
            "id": track.id,
            "title": track.title,
            "artist": track.artist,
            "album": track.album ?? "",
            "duration": durSec,
            "cover_url": track.coverUrl ?? "",
            "cached_at": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                await MainActor.run {
                    FavoritesManager.shared.setFavorite(trackId: track.id, isFavorite: true)
                }
                return true
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Remove Favorite (DELETE /api/favorites/:id)
    public func removeFavorite(trackId: String, serverURL: String, token: String?) async -> Bool {
        let trimmed = trackId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let base = cleanURL(serverURL)
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        let encodedId = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) ?? trimmed
        guard let url = URL(string: "\(base)/api/favorites/\(encodedId)") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                await MainActor.run {
                    FavoritesManager.shared.setFavorite(trackId: trimmed, isFavorite: false)
                }
                return true
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Toggle Favorite (/api/favorites)
    @discardableResult
    public func toggleFavorite(trackId: String, serverURL: String, token: String?) async -> Bool {
        let isCurrentlyFav = await checkIsFavorite(trackId: trackId, serverURL: serverURL, token: token)
        if isCurrentlyFav {
            return await removeFavorite(trackId: trackId, serverURL: serverURL, token: token)
        } else {
            let dummy = Track(id: trackId, title: "", artist: "")
            return await addFavorite(track: dummy, serverURL: serverURL, token: token)
        }
    }

    @discardableResult
    public func toggleFavorite(track: Track, serverURL: String, token: String?) async -> Bool {
        let isCurrentlyFav = await checkIsFavorite(trackId: track.id, serverURL: serverURL, token: token)
        if isCurrentlyFav {
            return await removeFavorite(trackId: track.id, serverURL: serverURL, token: token)
        } else {
            return await addFavorite(track: track, serverURL: serverURL, token: token)
        }
    }

    // MARK: - Online Playlist Discovery (/api/discovery/playlist/:id)
    public func fetchDiscoveryPlaylist(id: String, serverURL: String, token: String?) async -> DiscoveryPlaylistDetailData? {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let cleanId = trimmed
            .replacingOccurrences(of: "discovery:", with: "")
            .replacingOccurrences(of: "deezer:", with: "")
            .replacingOccurrences(of: "yt:", with: "")

        let base = cleanURL(serverURL)
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        let encodedId = cleanId.addingPercentEncoding(withAllowedCharacters: allowed) ?? cleanId
        guard let url = URL(string: "\(base)/api/discovery/playlist/\(encodedId)") else {
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
            if let envelope = try? JSONDecoder().decode(DiscoveryPlaylistResponse.self, from: data),
               let detail = envelope.toDetailData() {
                return detail
            }
            if let direct = try? JSONDecoder().decode(DiscoveryPlaylistDetailData.self, from: data) {
                return direct
            }
            return nil
        } catch {
            print("MusicService.fetchDiscoveryPlaylist error: \(error)")
            return nil
        }
    }

    // MARK: - Fetch User State Playlists & Tracks (/api/state)
    public func fetchUserState(serverURL: String, token: String?) async -> (playlists: [DiscoveryPlaylistDetailData], favorites: [Track]) {
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/state") else { return ([], []) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return ([], [])
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return ([], [])
            }

            var resultPlaylists: [DiscoveryPlaylistDetailData] = []
            if let pls = json["playlists"] as? [[String: Any]] {
                for p in pls {
                    let pid = (p["id"] as? String) ?? UUID().uuidString
                    let name = (p["name"] as? String) ?? (p["title"] as? String) ?? "Playlist"
                    let desc = p["description"] as? String
                    let cover = (p["cover"] as? String) ?? (p["cover_url"] as? String)
                    var trackItems: [DiscoveryTrack] = []
                    if let rawTracks = p["tracks"] as? [[String: Any]] {
                        for t in rawTracks {
                            if let id = t["id"] as? String, let title = t["title"] as? String {
                                let art = (t["artist"] as? String) ?? "Unbekannt"
                                let alb = t["album"] as? String
                                let cov = (t["cover"] as? String) ?? (t["cover_url"] as? String)
                                let dur = (t["duration"] as? String) ?? "0:00"
                                let durSec = (t["durationSeconds"] as? Int) ?? 0
                                let isExp = (t["isExplicit"] as? Bool) ?? false
                                trackItems.append(DiscoveryTrack(
                                    id: id,
                                    title: title,
                                    artist: art,
                                    album: alb,
                                    duration: dur,
                                    durationSeconds: durSec,
                                    cover: cov,
                                    sourceUrl: nil,
                                    storageType: nil,
                                    sourceType: nil,
                                    isExplicit: isExp
                                ))
                            }
                        }
                    }
                    resultPlaylists.append(DiscoveryPlaylistDetailData(
                        id: pid,
                        title: name,
                        description: desc,
                        cover: cover,
                        heroArtwork: nil,
                        motionVideo: nil,
                        user: nil,
                        nbTracks: trackItems.count,
                        tracks: trackItems
                    ))
                }
            }

            var resultFavorites: [Track] = []
            if let favs = json["favorites"] as? [[String: Any]] {
                for f in favs {
                    if let track = trackFromDictionary(f) {
                        resultFavorites.append(track)
                    }
                }
            }

            return (resultPlaylists, resultFavorites)
        } catch {
            return ([], [])
        }
    }

    // MARK: - Synchronized Lyrics Retrieval (Feature #18)
    public func fetchLyrics(trackId: String, title: String, artist: String, album: String? = nil, durationSeconds: Double? = nil, serverURL: String, token: String? = nil) async -> String? {
        guard !serverURL.isEmpty else { return nil }
        let cleanBase = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // Track-Informationen sicher auf dem MainActor auflösen
        let (currentAlbum, currentDur): (String?, Double?) = await MainActor.run {
            let tr = AudioPlayerManager.shared.currentTrack
            return (album ?? tr?.album, durationSeconds ?? tr?.durationSeconds)
        }

        // 1. Primärer Weg: POST /api/tracks/fetch-lyrics (wie in der Web-App fetchPortMusicLyrics)
        if let postUrl = URL(string: "\(cleanBase)/api/tracks/fetch-lyrics") {
            var postReq = URLRequest(url: postUrl)
            postReq.httpMethod = "POST"
            postReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let t = token, !t.isEmpty {
                postReq.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
            }

            var postBody: [String: Any] = [
                "title": title,
                "artist": artist,
                "trackId": trackId
            ]
            if let a = currentAlbum, !a.isEmpty {
                postBody["album"] = a
            }
            if let d = currentDur, d > 0 {
                postBody["duration_seconds"] = d
            }
            if trackId.hasPrefix("yt_") {
                let vid = trackId.replacingOccurrences(of: "yt_", with: "")
                postBody["youtubeUrl"] = "https://www.youtube.com/watch?v=\(vid)"
            }

            if let bodyData = try? JSONSerialization.data(withJSONObject: postBody),
               let (data, response) = try? await URLSession.shared.upload(for: postReq, from: bodyData),
               let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let lrc = json["lyrics"] as? String, !lrc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return lrc
                }
            }
        }

        // 2. Sekundärer Fallback: GET /api/lyrics?title=...&artist=...
        var comps = URLComponents(string: "\(cleanBase)/api/lyrics")
        var queryItems = [
            URLQueryItem(name: "trackId", value: trackId),
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "artist", value: artist)
        ]
        if let a = currentAlbum, !a.isEmpty {
            queryItems.append(URLQueryItem(name: "album", value: a))
        }
        if let d = currentDur, d > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: String(d)))
        }
        comps?.queryItems = queryItems

        guard let url = comps?.url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let t = token, !t.isEmpty {
            request.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let lrc = json["lyrics"] as? String ?? json["lrc"] as? String, !lrc.isEmpty {
                    return lrc
                }
                // Strukturierte Backend-Antwort (LyricsResponse mit lines: [{ text, start, end }])
                if let lines = json["lines"] as? [[String: Any]], !lines.isEmpty {
                    var lrcBuilder = ""
                    for line in lines {
                        let lineText = (line["text"] as? String ?? "").trimmingCharacters(in: .whitespaces)
                        let start = line["start"] as? Double ?? 0.0
                        let min = Int(start) / 60
                        let sec = Int(start) % 60
                        let hundredths = Int((start.truncatingRemainder(dividingBy: 1.0)) * 100)
                        lrcBuilder += String(format: "[%02d:%02d.%02d]%@\n", min, sec, hundredths, lineText)
                    }
                    if !lrcBuilder.isEmpty {
                        return lrcBuilder
                    }
                }
            }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    // MARK: - Similar Songs / Recommendations (Feature #20)
    public func fetchRecommendations(trackId: String, artist: String, title: String, serverURL: String, token: String? = nil) async -> [Track] {
        guard !serverURL.isEmpty else { return [] }
        var comps = URLComponents(string: "\(serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/api/discovery/recommendations")
        comps?.queryItems = [
            URLQueryItem(name: "exclude_ids", value: trackId),
            URLQueryItem(name: "artists", value: artist),
            URLQueryItem(name: "seed_tracks", value: title),
            URLQueryItem(name: "limit", value: "10")
        ]
        guard let url = comps?.url else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let t = token, !t.isEmpty {
            request.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            return parseTracksFromAnyJSON(data: data)
        } catch {
            return []
        }
    }
}
