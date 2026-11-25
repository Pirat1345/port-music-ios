import Foundation

public final class MusicService {
    public static let shared = MusicService()

    private let session: URLSession
    private let discoverySession: URLSession
    private let artistCacheStorageKey = "port_music_artist_detail_cache_v1"
    private let curatedRadioCacheKey = "port_music_curated_radio_cache_v1"
    private let radioFavoritesCacheKey = "port_music_radio_favorites_cache_v1"
    private let podcastChartsCacheKey = "port_music_podcast_charts_cache_v1"
    private let podcastFeedCacheKey = "port_music_podcast_feeds_cache_v1"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6.0
        config.timeoutIntervalForResource = 15.0
        self.session = URLSession(configuration: config)

        let discConfig = URLSessionConfiguration.default
        discConfig.timeoutIntervalForRequest = 20.0
        discConfig.timeoutIntervalForResource = 35.0
        self.discoverySession = URLSession(configuration: discConfig)
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

        // Live-Radio-Sender explizit ueber /api/radio/stream routen (HLS .m3u8 direkt fuer AVPlayer)
        if track.isLive, let src = track.sourceUrl, !src.isEmpty {
            if src.lowercased().contains(".m3u8"), let directHls = URL(string: src) {
                return directHls
            }
            if src.hasPrefix("http://") || src.hasPrefix("https://") {
                var comps = URLComponents(string: "\(base)/api/radio/stream")
                comps?.queryItems = [URLQueryItem(name: "url", value: src)]
                return comps?.url
            }
            if src.hasPrefix("/api/radio/stream") {
                return URL(string: "\(base)\(src)")
            }
        }

        // Hochgeladene lokale Server-Audiodateien sowie Podcast-Folgen über ihren Server-Endpunkt abspielen
        if !track.isLive, let src = track.sourceUrl, !src.isEmpty {
            if src.hasPrefix("/api/files/audio/") || src.hasPrefix("/api/podcasts/stream") {
                return URL(string: "\(base)\(src)")
            }
            if track.album == "Podcast", src.hasPrefix("http://") || src.hasPrefix("https://") {
                var comps = URLComponents(string: "\(base)/api/podcasts/stream")
                comps?.queryItems = [URLQueryItem(name: "url", value: src)]
                return comps?.url
            }
        }

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
        if track.durationSeconds > 0 {
            items.append(URLQueryItem(name: "duration", value: "\(track.durationSeconds)"))
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
            let (data, response) = try await discoverySession.data(for: request)
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
        request.timeoutInterval = 20.0
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await discoverySession.data(for: request)
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
        request.timeoutInterval = 20.0
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await discoverySession.data(for: request)
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
    public func cachedArtist(name: String) -> DiscoveryArtistDetailData? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty,
              let data = UserDefaults.standard.data(forKey: artistCacheStorageKey),
              let dict = try? JSONDecoder().decode([String: DiscoveryArtistDetailData].self, from: data) else {
            return nil
        }
        return dict[key]
    }

    private func persistCachedArtist(_ artist: DiscoveryArtistDetailData, lookupKey: String) {
        var dict: [String: DiscoveryArtistDetailData] = [:]
        if let data = UserDefaults.standard.data(forKey: artistCacheStorageKey),
           let existing = try? JSONDecoder().decode([String: DiscoveryArtistDetailData].self, from: data) {
            dict = existing
        }
        let cleanLookup = lookupKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let canonicalKey = artist.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleanLookup.isEmpty { dict[cleanLookup] = artist }
        if !canonicalKey.isEmpty { dict[canonicalKey] = artist }
        if dict.count > 20 {
            let trimmedKeys = Array(dict.keys.prefix(15))
            var compact: [String: DiscoveryArtistDetailData] = [:]
            for k in trimmedKeys { compact[k] = dict[k] }
            if !cleanLookup.isEmpty { compact[cleanLookup] = artist }
            if !canonicalKey.isEmpty { compact[canonicalKey] = artist }
            dict = compact
        }
        if let encoded = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(encoded, forKey: artistCacheStorageKey)
        }
    }

    private static func extractPrimaryArtistName(_ raw: String) -> String {
        var working = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            "\\s+(?:feat\\.?|ft\\.?|featuring|mit|with)\\s+.*$",
            "\\s*[,;]\\s+.*$",
            "\\s+[x×]\\s+.*$",
            "\\s+/\\s+.*$"
        ]
        for pat in patterns {
            working = working.replacingOccurrences(of: pat, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return working.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func performSingleArtistFetch(target: String, base: String, token: String?) async -> DiscoveryArtistDetailData? {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        let encodedName = target.addingPercentEncoding(withAllowedCharacters: allowed) ?? target
        guard let url = URL(string: "\(base)/api/discovery/artist/\(encodedName)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 22.0
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await discoverySession.data(for: request)
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

    public func fetchArtist(name: String, serverURL: String, token: String?) async -> DiscoveryArtistDetailData? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if await MainActor.run(body: { SessionManager.shared.isOfflineMode }) {
            return cachedArtist(name: trimmed)
        }

        let base = cleanURL(serverURL)
        if let exact = await performSingleArtistFetch(target: trimmed, base: base, token: token) {
            persistCachedArtist(exact, lookupKey: trimmed)
            return exact
        }

        // Kollaborationen ("Artist A, Artist B" / "Artist A feat. B") auf Hauptkuenstler aufloesen
        let primary = Self.extractPrimaryArtistName(trimmed)
        if !primary.isEmpty, primary.lowercased() != trimmed.lowercased(),
           let fallback = await performSingleArtistFetch(target: primary, base: base, token: token) {
            persistCachedArtist(fallback, lookupKey: trimmed)
            return fallback
        }

        // Letzter Versuch bei Band-/Collab-Trenner "&" falls volle Schreibweise nichts ergab
        if let ampIdx = trimmed.range(of: " & ") {
            let beforeAmp = String(trimmed[..<ampIdx.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !beforeAmp.isEmpty,
               let ampArtist = await performSingleArtistFetch(target: beforeAmp, base: base, token: token) {
                persistCachedArtist(ampArtist, lookupKey: trimmed)
                return ampArtist
            }
        }

        return cachedArtist(name: trimmed)
    }

    public func fetchArtistTracks(name: String, serverURL: String, token: String?) async -> [DiscoveryArtistTrackItem] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let base = cleanURL(serverURL)
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        let candidates = [trimmed, Self.extractPrimaryArtistName(trimmed)].filter { !$0.isEmpty }
        var tried = Set<String>()

        for cand in candidates {
            let key = cand.lowercased()
            if tried.contains(key) { continue }
            tried.insert(key)

            let encoded = cand.addingPercentEncoding(withAllowedCharacters: allowed) ?? cand
            guard let url = URL(string: "\(base)/api/discovery/artist/\(encoded)/tracks") else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 22.0
            if let tok = token, !tok.isEmpty {
                request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
                request.setValue(tok, forHTTPHeaderField: "x-session-token")
            }

            if let (data, response) = try? await discoverySession.data(for: request),
               let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let decoded = try? JSONDecoder().decode(DiscoveryArtistTracksResponse.self, from: data),
               let list = decoded.tracks, !list.isEmpty {
                return list
            }
        }
        return []
    }

    public func lookupArtistImagesBatch(names: [String], serverURL: String, token: String?) async -> [String: String] {
        let cleanNames = Array(Set(names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).prefix(60)
        guard !cleanNames.isEmpty else { return [:] }
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/artists/lookup-batch") else { return [:] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["names": Array(cleanNames)])

        do {
            let (data, response) = try await discoverySession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
                return [:]
            }
            var result: [String: String] = [:]
            for (key, obj) in json {
                if let img = obj["image"] as? String, !img.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result[key.lowercased()] = img
                }
            }
            return result
        } catch {
            return [:]
        }
    }

    public func syncSavedAlbumState(
        albumTitle: String,
        artistName: String,
        coverUrl: String?,
        isSaved: Bool,
        serverURL: String,
        token: String?
    ) async {
        let titleClean = albumTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let artistClean = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !titleClean.isEmpty else { return }
        let compositeKey = "\(titleClean)::\(artistClean)"

        let base = cleanURL(serverURL)
        guard let getUrl = URL(string: "\(base)/api/state"),
              let tok = token, !tok.isEmpty else { return }

        var getReq = URLRequest(url: getUrl)
        getReq.httpMethod = "GET"
        getReq.timeoutInterval = 6.0
        getReq.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        getReq.setValue(tok, forHTTPHeaderField: "x-session-token")

        guard let (data, resp) = try? await session.data(for: getReq),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        var libState = (json["libraryState"] as? [String: Any]) ?? [:]
        var savedAlbums = (libState["savedAlbums"] as? [String]) ?? []
        var albumCovers = (libState["albumCovers"] as? [String: String]) ?? [:]

        if isSaved {
            if !savedAlbums.contains(where: { $0.lowercased() == compositeKey.lowercased() }) {
                savedAlbums.append(compositeKey)
            }
            if let cov = coverUrl, !cov.isEmpty {
                albumCovers[compositeKey] = cov
            }
        } else {
            savedAlbums.removeAll {
                $0.lowercased() == compositeKey.lowercased()
                || $0.lowercased() == titleClean.lowercased()
            }
        }
        libState["savedAlbums"] = savedAlbums
        if !albumCovers.isEmpty { libState["albumCovers"] = albumCovers }

        var payload: [String: Any] = [
            "playlists": [],
            "folders": [],
            "favorites": [],
            "libraryState": libState
        ]
        if let bookmarks = json["audiobookBookmarks"] { payload["audiobookBookmarks"] = bookmarks }
        if let ignored = json["ignoredDuplicatePairs"] { payload["ignoredDuplicatePairs"] = ignored }

        var putReq = URLRequest(url: getUrl)
        putReq.httpMethod = "PUT"
        putReq.timeoutInterval = 8.0
        putReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        putReq.setValue(currentDeviceId, forHTTPHeaderField: "X-Device-ID")
        putReq.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        putReq.setValue(tok, forHTTPHeaderField: "x-session-token")
        putReq.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        _ = try? await session.data(for: putReq)
    }

    // MARK: - Podcasts API (/api/podcasts/*)
    public func cachedPodcastCharts(genre: Int? = nil) -> [PodcastItem] {
        let key = genre.map { "genre_\($0)" } ?? "all"
        guard let data = UserDefaults.standard.data(forKey: podcastChartsCacheKey),
              let dict = try? JSONDecoder().decode([String: [PodcastItem]].self, from: data),
              let list = dict[key] else {
            return []
        }
        return list
    }

    private func persistPodcastCharts(_ list: [PodcastItem], genre: Int?) {
        let key = genre.map { "genre_\($0)" } ?? "all"
        var dict: [String: [PodcastItem]] = [:]
        if let data = UserDefaults.standard.data(forKey: podcastChartsCacheKey),
           let existing = try? JSONDecoder().decode([String: [PodcastItem]].self, from: data) {
            dict = existing
        }
        dict[key] = list
        if let encoded = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(encoded, forKey: podcastChartsCacheKey)
        }
    }

    public func cachedPodcastFeed(id: String? = nil, feedUrl: String? = nil) -> PodcastFeedDetail? {
        guard let data = UserDefaults.standard.data(forKey: podcastFeedCacheKey),
              let dict = try? JSONDecoder().decode([String: PodcastFeedDetail].self, from: data) else {
            return nil
        }
        if let fUrl = feedUrl?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !fUrl.isEmpty, let found = dict[fUrl] {
            return found
        }
        if let pId = id?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !pId.isEmpty, let found = dict[pId] {
            return found
        }
        return nil
    }

    private func persistPodcastFeed(_ detail: PodcastFeedDetail, id: String?, feedUrl: String?) {
        var dict: [String: PodcastFeedDetail] = [:]
        if let data = UserDefaults.standard.data(forKey: podcastFeedCacheKey),
           let existing = try? JSONDecoder().decode([String: PodcastFeedDetail].self, from: data) {
            dict = existing
        }
        let keys = [
            id?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            feedUrl?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            detail.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            detail.feedUrl.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ].compactMap { $0 }.filter { !$0.isEmpty }
        for k in keys {
            dict[k] = detail
        }
        if dict.count > 30 {
            let keepKeys = Array(dict.keys.prefix(20))
            var compact: [String: PodcastFeedDetail] = [:]
            for k in keepKeys { compact[k] = dict[k] }
            for k in keys { compact[k] = detail }
            dict = compact
        }
        if let encoded = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(encoded, forKey: podcastFeedCacheKey)
        }
    }

    public func fetchPodcastCharts(genre: Int? = nil, limit: Int = 25, serverURL: String, token: String?) async -> [PodcastItem] {
        if await MainActor.run(body: { SessionManager.shared.isOfflineMode }) {
            return cachedPodcastCharts(genre: genre)
        }
        let base = cleanURL(serverURL)
        guard var comps = URLComponents(string: "\(base)/api/podcasts/charts") else {
            return cachedPodcastCharts(genre: genre)
        }
        var qItems = [
            URLQueryItem(name: "country", value: "de"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let g = genre {
            qItems.append(URLQueryItem(name: "genre", value: "\(g)"))
        }
        comps.queryItems = qItems
        guard let url = comps.url else { return cachedPodcastCharts(genre: genre) }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 12.0
        if let tok = token, !tok.isEmpty {
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            req.setValue(tok, forHTTPHeaderField: "x-session-token")
        }
        guard let (data, resp) = try? await discoverySession.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let wrapper = try? JSONDecoder().decode(PodcastChartsListResponse.self, from: data),
              let results = wrapper.results else {
            return cachedPodcastCharts(genre: genre)
        }
        if !results.isEmpty {
            persistPodcastCharts(results, genre: genre)
        }
        return results
    }

    public func searchPodcasts(query: String, serverURL: String, token: String?) async -> [PodcastItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if await MainActor.run(body: { SessionManager.shared.isOfflineMode }) {
            return []
        }
        let base = cleanURL(serverURL)
        guard var comps = URLComponents(string: "\(base)/api/podcasts/search") else { return [] }
        comps.queryItems = [URLQueryItem(name: "q", value: trimmed), URLQueryItem(name: "country", value: "DE")]
        guard let url = comps.url else { return [] }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 12.0
        if let tok = token, !tok.isEmpty {
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            req.setValue(tok, forHTTPHeaderField: "x-session-token")
        }
        guard let (data, resp) = try? await discoverySession.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let wrapper = try? JSONDecoder().decode(PodcastChartsListResponse.self, from: data) else {
            return []
        }
        return wrapper.results ?? []
    }

    public func resolvePodcastURL(url inputUrl: String, serverURL: String, token: String?) async -> PodcastResolveResult? {
        let trimmed = inputUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let base = cleanURL(serverURL)
        guard var comps = URLComponents(string: "\(base)/api/podcasts/resolve") else { return nil }
        comps.queryItems = [URLQueryItem(name: "url", value: trimmed)]
        guard let url = comps.url else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 14.0
        if let tok = token, !tok.isEmpty {
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            req.setValue(tok, forHTTPHeaderField: "x-session-token")
        }
        guard let (data, resp) = try? await discoverySession.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }
        return try? JSONDecoder().decode(PodcastResolveResult.self, from: data)
    }

    public func fetchPodcastFeed(id: String? = nil, feedUrl: String? = nil, serverURL: String, token: String?) async -> PodcastFeedDetail? {
        if await MainActor.run(body: { SessionManager.shared.isOfflineMode }) {
            return cachedPodcastFeed(id: id, feedUrl: feedUrl)
        }
        let base = cleanURL(serverURL)
        guard var comps = URLComponents(string: "\(base)/api/podcasts/feed") else {
            return cachedPodcastFeed(id: id, feedUrl: feedUrl)
        }
        if let fUrl = feedUrl, !fUrl.isEmpty {
            comps.queryItems = [URLQueryItem(name: "url", value: fUrl)]
        } else if let pId = id, !pId.isEmpty {
            comps.queryItems = [URLQueryItem(name: "id", value: pId)]
        } else {
            return cachedPodcastFeed(id: id, feedUrl: feedUrl)
        }
        guard let url = comps.url else { return cachedPodcastFeed(id: id, feedUrl: feedUrl) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 18.0
        if let tok = token, !tok.isEmpty {
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            req.setValue(tok, forHTTPHeaderField: "x-session-token")
        }
        guard let (data, resp) = try? await discoverySession.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let detail = try? JSONDecoder().decode(PodcastFeedDetail.self, from: data) else {
            return cachedPodcastFeed(id: id, feedUrl: feedUrl)
        }
        persistPodcastFeed(detail, id: id, feedUrl: feedUrl)
        return detail
    }

    public func syncSavedArtistState(artistName: String, isSaved: Bool, serverURL: String, token: String?) async {
        let trimmed = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let base = cleanURL(serverURL)
        guard let getUrl = URL(string: "\(base)/api/state"),
              let tok = token, !tok.isEmpty else { return }

        var getReq = URLRequest(url: getUrl)
        getReq.httpMethod = "GET"
        getReq.timeoutInterval = 6.0
        getReq.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        getReq.setValue(tok, forHTTPHeaderField: "x-session-token")

        guard let (data, resp) = try? await session.data(for: getReq),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        var libState = (json["libraryState"] as? [String: Any]) ?? [:]
        var savedArtists = (libState["savedArtists"] as? [String]) ?? []
        if isSaved {
            if !savedArtists.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
                savedArtists.append(trimmed)
            }
        } else {
            savedArtists.removeAll { $0.lowercased() == trimmed.lowercased() }
        }
        libState["savedArtists"] = savedArtists

        var payload: [String: Any] = [
            "playlists": [],
            "folders": [],
            "favorites": [],
            "libraryState": libState
        ]
        if let bookmarks = json["audiobookBookmarks"] {
            payload["audiobookBookmarks"] = bookmarks
        }
        if let ignored = json["ignoredDuplicatePairs"] {
            payload["ignoredDuplicatePairs"] = ignored
        }

        var putReq = URLRequest(url: getUrl)
        putReq.httpMethod = "PUT"
        putReq.timeoutInterval = 8.0
        putReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        putReq.setValue(currentDeviceId, forHTTPHeaderField: "X-Device-ID")
        putReq.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        putReq.setValue(tok, forHTTPHeaderField: "x-session-token")
        putReq.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        _ = try? await session.data(for: putReq)
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
        request.timeoutInterval = 20.0
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await discoverySession.data(for: request)
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
        request.timeoutInterval = 20.0
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await discoverySession.data(for: request)
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

    // MARK: - Category Detail (/api/category/:id) mit Offline-Cache
    private let categoryDetailCacheKey = "port_music_category_detail_cache_v1"

    public func cachedCategoryDetail(id: String) -> AppleCategoryDetailData? {
        let key = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty,
              let data = UserDefaults.standard.data(forKey: categoryDetailCacheKey),
              let dict = try? JSONDecoder().decode([String: AppleCategoryDetailData].self, from: data) else {
            return nil
        }
        return dict[key]
    }

    private func persistCategoryDetail(_ detail: AppleCategoryDetailData, for id: String) {
        let key = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return }
        var dict: [String: AppleCategoryDetailData] = [:]
        if let data = UserDefaults.standard.data(forKey: categoryDetailCacheKey),
           let existing = try? JSONDecoder().decode([String: AppleCategoryDetailData].self, from: data) {
            dict = existing
        }
        dict[key] = detail
        if dict.count > 25 {
            let keep = Array(dict.keys.prefix(15))
            var trimmed: [String: AppleCategoryDetailData] = [:]
            for k in keep { trimmed[k] = dict[k] }
            trimmed[key] = detail
            dict = trimmed
        }
        if let encoded = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(encoded, forKey: categoryDetailCacheKey)
        }
    }

    public func fetchCategoryDetail(id: String, serverURL: String, token: String?) async -> AppleCategoryDetailData? {
        if await MainActor.run(body: { SessionManager.shared.isOfflineMode }) {
            return cachedCategoryDetail(id: id)
        }
        let base = cleanURL(serverURL)
        guard let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(base)/api/category/\(encoded)") else {
            return cachedCategoryDetail(id: id)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20.0
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await discoverySession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return cachedCategoryDetail(id: id)
            }
            let decoded = try JSONDecoder().decode(AppleCategoryDetailData.self, from: data)
            persistCategoryDetail(decoded, for: id)
            return decoded
        } catch {
            return cachedCategoryDetail(id: id)
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

        // Case 2: Object containing tracks array e.g. { "tracks": [ ... ] } or { "data": [ ... ] }
        if let dict = json as? [String: Any] {
            let rawList = (dict["tracks"] as? [[String: Any]]) ?? (dict["data"] as? [[String: Any]])
            if let list = rawList {
                var seen = Set<String>()
                for item in list {
                    if let track = trackFromDictionary(item) {
                        if !seen.contains(track.id) {
                            seen.insert(track.id)
                            results.append(track)
                        }
                    }
                }
                if !results.isEmpty { return results }
            }
        }

        // Case 3: /api/history -> Array of { id: ..., track: { ... }, played_at: ... }
        if let arr = json as? [[String: Any]] {
            var seen = Set<String>()
            for item in arr {
                if let tDict = item["track"] as? [String: Any], let track = trackFromDictionary(tDict) {
                    if !seen.contains(track.id) {
                        seen.insert(track.id)
                        results.append(track)
                    }
                } else if let track = trackFromDictionary(item) {
                    // Case 4: Direct array of tracks
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

    public static func extractPlaylistTrackCovers(from rawTracks: [[String: Any]]) -> [String] {
        var seen = Set<String>()
        var covers: [String] = []
        for track in rawTracks {
            let rawCover = (track["cover_url"] as? String)
                ?? (track["cover"] as? String)
                ?? (track["coverUrl"] as? String)
                ?? ""
            let trimmed = rawCover.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  !trimmed.contains("cover-1."),
                  trimmed != "/default-cover.svg",
                  !trimmed.hasSuffix("/default-cover.svg") else {
                continue
            }
            if seen.insert(trimmed).inserted {
                covers.append(trimmed)
                if covers.count >= 4 { break }
            }
        }
        return covers
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
                let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                var extraTrackCoversById: [String: [String]] = [:]
                if let jsonArray {
                    for item in jsonArray {
                        if let id = item["id"] as? String,
                           let rawTracks = item["tracks"] as? [[String: Any]] {
                            let tc = Self.extractPlaylistTrackCovers(from: rawTracks)
                            if !tc.isEmpty {
                                extraTrackCoversById[id] = tc
                            }
                        }
                    }
                }

                if let list = try? JSONDecoder().decode([DiscoveryPlaylist].self, from: data), !list.isEmpty {
                    let enriched = list.map { pl in
                        if pl.trackCovers?.isEmpty != false, let tc = extraTrackCoversById[pl.id] {
                            return DiscoveryPlaylist(
                                id: pl.id,
                                title: pl.title,
                                cover: pl.cover,
                                nbTracks: pl.nbTracks,
                                user: pl.user,
                                folderId: pl.folderId,
                                trackCovers: tc
                            )
                        }
                        return pl
                    }
                    resultPlaylists.append(contentsOf: enriched)
                } else if let jsonArray {
                    for item in jsonArray {
                        guard let id = item["id"] as? String else { continue }
                        let title = item["title"] as? String ?? item["name"] as? String ?? "Playlist"
                        let cover = item["cover_url"] as? String ?? item["cover"] as? String ?? ""
                        let user = item["owner_id"] as? String ?? item["user"] as? String
                        let tc = extraTrackCoversById[id]
                        resultPlaylists.append(DiscoveryPlaylist(id: id, title: title, cover: cover, nbTracks: nil, user: user, trackCovers: tc))
                    }
                }
            }
        }

        // 2. Also fetch /api/state to enrich track counts & covers (or populate if /api/playlists returned empty)
        if let stateUrl = URL(string: "\(base)/api/state") {
            var request = URLRequest(url: stateUrl)
            request.httpMethod = "GET"
            if let tok = token, !tok.isEmpty {
                request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            }

            if let (data, response) = try? await session.data(for: request),
               let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let pls = json["playlists"] as? [[String: Any]] {
                var stateMap: [String: (title: String, cover: String, count: Int, owner: String?, folderId: String?, trackCovers: [String])] = [:]
                for pl in pls {
                    guard let id = pl["id"] as? String else { continue }
                    let title = pl["name"] as? String ?? pl["title"] as? String ?? "Playlist"
                    let cover = pl["cover"] as? String ?? pl["cover_url"] as? String ?? ""
                    let rawTracks = pl["tracks"] as? [[String: Any]] ?? []
                    let tracksCount = rawTracks.isEmpty ? ((pl["tracks"] as? [Any])?.count ?? 0) : rawTracks.count
                    let tc = Self.extractPlaylistTrackCovers(from: rawTracks)
                    let owner = pl["ownerId"] as? String ?? pl["owner_id"] as? String
                    let folderId = pl["folderId"] as? String ?? pl["folder_id"] as? String
                    stateMap[id] = (title, cover, tracksCount, owner, folderId, tc)
                }

                if resultPlaylists.isEmpty {
                    for pl in pls {
                        guard let id = pl["id"] as? String, let info = stateMap[id] else { continue }
                        resultPlaylists.append(DiscoveryPlaylist(
                            id: id,
                            title: info.title,
                            cover: info.cover,
                            nbTracks: info.count,
                            user: info.owner,
                            folderId: info.folderId,
                            trackCovers: info.trackCovers.isEmpty ? nil : info.trackCovers
                        ))
                    }
                } else {
                    resultPlaylists = resultPlaylists.map { existing in
                        if let info = stateMap[existing.id] {
                            let mergedTrackCovers: [String]?
                            if let existingTc = existing.trackCovers, !existingTc.isEmpty {
                                mergedTrackCovers = existingTc
                            } else {
                                mergedTrackCovers = info.trackCovers.isEmpty ? nil : info.trackCovers
                            }
                            return DiscoveryPlaylist(
                                id: existing.id,
                                title: existing.title,
                                cover: existing.cover.isEmpty ? info.cover : existing.cover,
                                nbTracks: existing.nbTracks ?? info.count,
                                user: existing.user ?? info.owner,
                                folderId: existing.folderId ?? info.folderId,
                                trackCovers: mergedTrackCovers
                            )
                        }
                        return existing
                    }
                }
            }
        }

        return resultPlaylists
    }

    // MARK: - Fetch Favorites (/api/favorites & /api/state) + Offline Sync Flush
    public func fetchFavorites(serverURL: String, token: String?) async -> [Track] {
        // Zuerst ausstehende Offline-Likes/-Unlikes an den Server uebertragen
        await FavoritesManager.shared.syncPendingWithServer(serverURL: serverURL, token: token)

        let base = cleanURL(serverURL)
        var resultTracks: [Track] = []
        var serverResponded = false
        var hadTransportError = false

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
            request.timeoutInterval = 6.0
            if let tok = token, !tok.isEmpty {
                request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
                request.setValue(tok, forHTTPHeaderField: "x-session-token")
            }

            do {
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    serverResponded = true
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
            } catch {
                hadTransportError = true
            }
        }

        // 2. Also check /api/state if /api/favorites was empty
        if resultTracks.isEmpty, let stateUrl = URL(string: "\(base)/api/state") {
            var request = URLRequest(url: stateUrl)
            request.httpMethod = "GET"
            request.timeoutInterval = 6.0
            if let tok = token, !tok.isEmpty {
                request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
                request.setValue(tok, forHTTPHeaderField: "x-session-token")
            }

            do {
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    serverResponded = true
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let favList = json["favorites"] as? [[String: Any]] {
                        for item in favList {
                            if let track = parseTrackDict(item) {
                                resultTracks.append(track)
                            }
                        }
                    }
                }
            } catch {
                hadTransportError = true
            }
        }

        if serverResponded {
            return await MainActor.run {
                SessionManager.shared.setOfflineMode(false)
                return FavoritesManager.shared.syncWithServerList(resultTracks)
            }
        } else {
            return await MainActor.run {
                if hadTransportError {
                    SessionManager.shared.setOfflineMode(true)
                }
                return FavoritesManager.shared.cachedFavoriteTracks
            }
        }
    }

    // MARK: - Check Favorite (/api/favorites/:id)
    public func checkIsFavorite(trackId: String, serverURL: String, token: String?) async -> Bool {
        let trimmed = trackId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Lokale ausstehende Offline-Aenderung hat Vorrang bis zum Server-Abgleich
        if let pendingVal = await MainActor.run(body: { FavoritesManager.shared.pendingMutations[trimmed]?.isFavorite }) {
            return pendingVal
        }
        if await MainActor.run(body: { SessionManager.shared.isOfflineMode }) {
            return await MainActor.run { FavoritesManager.shared.isFavorite(trackId: trimmed) }
        }

        let base = cleanURL(serverURL)
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        let encodedId = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) ?? trimmed
        guard let url = URL(string: "\(base)/api/favorites/\(encodedId)") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return await MainActor.run {
                    FavoritesManager.shared.isFavorite(trackId: trimmed)
                }
            }
            if let isFav = try? JSONDecoder().decode(Bool.self, from: data) {
                return await MainActor.run {
                    if let pendingVal = FavoritesManager.shared.pendingMutations[trimmed]?.isFavorite {
                        return pendingVal
                    }
                    FavoritesManager.shared.setFavorite(trackId: trimmed, isFavorite: isFav)
                    return isFav
                }
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let isFav = (json["isFavorite"] as? Bool) ?? (json["favorite"] as? Bool) {
                return await MainActor.run {
                    if let pendingVal = FavoritesManager.shared.pendingMutations[trimmed]?.isFavorite {
                        return pendingVal
                    }
                    FavoritesManager.shared.setFavorite(trackId: trimmed, isFavorite: isFav)
                    return isFav
                }
            }
            return await MainActor.run {
                FavoritesManager.shared.isFavorite(trackId: trimmed)
            }
        } catch {
            return await MainActor.run {
                FavoritesManager.shared.isFavorite(trackId: trimmed)
            }
        }
    }

    // MARK: - Direct Server Request for Favorites (POST /api/favorites, DELETE /api/favorites/:id)
    public func sendFavoriteRequest(track: Track, isFavorite: Bool, serverURL: String, token: String?) async -> Bool {
        let trimmed = track.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let base = cleanURL(serverURL)
        guard !base.isEmpty else { return false }

        if isFavorite {
            guard let url = URL(string: "\(base)/api/favorites") else { return false }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 6.0
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let tok = token, !tok.isEmpty {
                request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
                request.setValue(tok, forHTTPHeaderField: "x-session-token")
            }

            var durSec: Double = track.durationSeconds > 0 ? track.durationSeconds : 210.0
            let parts = track.duration.split(separator: ":")
            if parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]), (m * 60 + s) > 0 {
                durSec = m * 60 + s
            }

            let body: [String: Any] = [
                "id": trimmed,
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
                    return true
                }
                return false
            } catch {
                return false
            }
        } else {
            let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
            let encodedId = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) ?? trimmed
            guard let url = URL(string: "\(base)/api/favorites/\(encodedId)") else { return false }

            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.timeoutInterval = 6.0
            if let tok = token, !tok.isEmpty {
                request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
                request.setValue(tok, forHTTPHeaderField: "x-session-token")
            }

            do {
                let (_, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, ((200...299).contains(http.statusCode) || http.statusCode == 404) {
                    return true
                }
                return false
            } catch {
                return false
            }
        }
    }

    // MARK: - Unified Offline-Capable Favorite State Setter
    @discardableResult
    public func setFavoriteState(track: Track, isFavorite: Bool, serverURL: String, token: String?) async -> Bool {
        let trimmed = track.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // 1. Sofort lokal anwenden & fuer Reconnect-Sync vormerken
        await MainActor.run {
            FavoritesManager.shared.enqueueMutation(track: track, isFavorite: isFavorite)
        }

        // 2. Falls offline: direkt als lokal gesichert bestaetigen
        if await MainActor.run(body: { SessionManager.shared.isOfflineMode }) {
            return true
        }

        // 3. Direkt an Server senden; bei Transportfehler bleibt Mutation in Queue
        let synced = await sendFavoriteRequest(track: track, isFavorite: isFavorite, serverURL: serverURL, token: token)
        if synced {
            await MainActor.run {
                FavoritesManager.shared.resolveMutationOnline(trackId: trimmed)
            }
        } else {
            await MainActor.run {
                SessionManager.shared.setOfflineMode(true)
            }
        }
        return true
    }

    // MARK: - Add Favorite (POST /api/favorites)
    public func addFavorite(track: Track, serverURL: String, token: String?) async -> Bool {
        await setFavoriteState(track: track, isFavorite: true, serverURL: serverURL, token: token)
    }

    // MARK: - Remove Favorite (DELETE /api/favorites/:id)
    public func removeFavorite(trackId: String, serverURL: String, token: String?) async -> Bool {
        let trimmed = trackId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let dummy = Track(id: trimmed, title: "", artist: "")
        return await setFavoriteState(track: dummy, isFavorite: false, serverURL: serverURL, token: token)
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
    public func toggleFavorite(track: Track, desiredState: Bool? = nil, serverURL: String, token: String?) async -> Bool {
        let targetState: Bool
        if let explicit = desiredState {
            targetState = explicit
        } else {
            let currentFav = await checkIsFavorite(trackId: track.id, serverURL: serverURL, token: token)
            targetState = !currentFav
        }
        return await setFavoriteState(track: track, isFavorite: targetState, serverURL: serverURL, token: token)
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
        request.timeoutInterval = 20.0
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await discoverySession.data(for: request)
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
        request.timeoutInterval = 20.0
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await discoverySession.data(for: request)
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
        let cleanBase = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanBase)/api/discovery/recommendations") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = token, !t.isEmpty {
            request.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }

        var artistsList: [String] = []
        if !artist.isEmpty && artist != "Unbekannt" {
            artistsList.append(artist)
        }
        var seedTracksList: [String] = []
        if !title.isEmpty {
            seedTracksList.append(title)
        }
        var excludeIdsList: [String] = []
        if !trackId.isEmpty {
            excludeIdsList.append(trackId)
        }

        let body: [String: Any] = [
            "artists": artistsList,
            "seed_tracks": seedTracksList,
            "exclude_ids": excludeIdsList,
            "limit": 15
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
            return parseTracksFromAnyJSON(data: data)
        } catch {
            return []
        }
    }

    // MARK: - Library Collections (/api/state)
    public func fetchLibraryCollections(serverURL: String, token: String?) async -> LibraryCollectionsData {
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/state") else { return LibraryCollectionsData() }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(currentDeviceId, forHTTPHeaderField: "X-Device-ID")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        var result = LibraryCollectionsData()
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return result
            }

            if let pls = json["playlists"] as? [[String: Any]] {
                for pl in pls {
                    guard let id = pl["id"] as? String else { continue }
                    let title = pl["name"] as? String ?? pl["title"] as? String ?? "Playlist"
                    let cover = pl["cover"] as? String ?? pl["cover_url"] as? String ?? ""
                    let owner = pl["ownerId"] as? String ?? pl["owner_id"] as? String
                    let folderId = pl["folderId"] as? String ?? pl["folder_id"] as? String
                    let rawTracks = pl["tracks"] as? [[String: Any]] ?? []
                    let parsedTracks = rawTracks.compactMap { parseLibraryTrackDict($0) }
                    let tc = Self.extractPlaylistTrackCovers(from: rawTracks)
                    result.playlistTracksMap[id] = parsedTracks
                    result.playlists.append(DiscoveryPlaylist(
                        id: id,
                        title: title,
                        cover: cover,
                        nbTracks: parsedTracks.count,
                        user: owner,
                        folderId: folderId,
                        trackCovers: tc.isEmpty ? nil : tc
                    ))
                }
            }

            if let foldersArr = json["folders"] as? [[String: Any]] {
                for f in foldersArr {
                    guard let id = f["id"] as? String else { continue }
                    let name = f["name"] as? String ?? "Ordner"
                    let parentId = f["parentId"] as? String ?? f["parentFolderId"] as? String
                    let color = f["color"] as? String
                    result.folders.append(LibraryFolder(id: id, name: name, parentId: parentId, color: color))
                }
            }

            if let favs = json["favorites"] as? [[String: Any]] {
                result.favorites = favs.compactMap { parseLibraryTrackDict($0) }
            }
            if let globals = json["globalTracks"] as? [[String: Any]] {
                result.globalTracks = globals.compactMap { parseLibraryTrackDict($0) }
            }

            if let libState = json["libraryState"] as? [String: Any] {
                result.savedArtists = libState["savedArtists"] as? [String] ?? []
                result.savedAlbums = libState["savedAlbums"] as? [String] ?? []
                result.albumCovers = libState["albumCovers"] as? [String: String] ?? [:]
                result.pinnedPlaylists = libState["pinnedPlaylists"] as? [String] ?? []
                result.pinnedFolders = libState["pinnedFolders"] as? [String] ?? []
            }
        } catch {
            print("MusicService.fetchLibraryCollections error: \(error)")
        }
        return result
    }

    public func createFolder(name: String, parentFolderId: String? = nil, serverURL: String, token: String?) async -> LibraryFolder? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/state") else { return nil }

        let folderId = "folder_\(Int64(Date().timeIntervalSince1970 * 1000))_\(Int.random(in: 100...999))"
        var folderObj: [String: Any] = [
            "id": folderId,
            "name": trimmed
        ]
        if let pid = parentFolderId, !pid.isEmpty {
            folderObj["parentFolderId"] = pid
        }

        let payload: [String: Any] = [
            "playlists": [],
            "folders": [folderObj],
            "favorites": []
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(currentDeviceId, forHTTPHeaderField: "X-Device-ID")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                return LibraryFolder(id: folderId, name: trimmed, parentId: parentFolderId, color: nil)
            }
            return nil
        } catch {
            return nil
        }
    }

    private func parseLibraryTrackDict(_ item: [String: Any]) -> Track? {
        guard let id = item["id"] as? String, !id.isEmpty else { return nil }
        let title = item["title"] as? String ?? item["name"] as? String ?? "Kein Titel"
        let artist = item["artist"] as? String ?? "Unbekannter Interpret"
        let album = item["album"] as? String
        let cover = item["cover_url"] as? String ?? item["cover"] as? String ?? item["coverUrl"] as? String
        let sourceUrl = item["sourceUrl"] as? String ?? item["source_url"] as? String ?? item["url"] as? String

        var durSec: Double = 0
        if let d = item["durationSeconds"] as? Double {
            durSec = d
        } else if let d = item["durationSeconds"] as? Int {
            durSec = Double(d)
        } else if let d = item["duration"] as? Double {
            durSec = d
        } else if let s = item["duration"] as? String {
            let parts = s.split(separator: ":").compactMap { Double($0) }
            if parts.count == 2 { durSec = parts[0] * 60 + parts[1] }
            else if parts.count == 3 { durSec = parts[0] * 3600 + parts[1] * 60 + parts[2] }
        }

        let formattedDur: String
        if let s = item["duration"] as? String, !s.isEmpty, s != "LIVE" {
            formattedDur = s
        } else {
            let m = Int(durSec) / 60
            let sec = Int(durSec) % 60
            formattedDur = String(format: "%d:%02d", m, sec)
        }

        return Track(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: formattedDur,
            durationSeconds: durSec,
            coverUrl: cover,
            isLive: false,
            isExplicit: (item["explicitContent"] as? Bool) ?? (item["is_explicit"] as? Bool) ?? false,
            sourceUrl: sourceUrl
        )
    }

    // MARK: - Create & Import Playlists
    public func createPlaylist(title: String, description: String? = nil, serverURL: String, token: String?) async -> DiscoveryPlaylist? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/playlists") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(currentDeviceId, forHTTPHeaderField: "X-Device-ID")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        var body: [String: Any] = ["title": trimmed]
        if let desc = description?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
            body["description"] = desc
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = json["id"] as? String else {
                return nil
            }
            let plTitle = json["title"] as? String ?? trimmed
            let cover = json["cover_url"] as? String ?? json["cover"] as? String ?? ""
            let owner = json["owner_id"] as? String
            return DiscoveryPlaylist(id: id, title: plTitle, cover: cover, nbTracks: 0, user: owner)
        } catch {
            return nil
        }
    }

    public func addTrackToPlaylist(playlistId: String, track: Track, serverURL: String, token: String?) async -> Bool {
        let base = cleanURL(serverURL)
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        let encodedId = playlistId.addingPercentEncoding(withAllowedCharacters: allowed) ?? playlistId
        guard let url = URL(string: "\(base)/api/playlists/\(encodedId)/tracks") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(currentDeviceId, forHTTPHeaderField: "X-Device-ID")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        var durSec = track.durationSeconds
        if durSec <= 0 {
            let parts = track.duration.split(separator: ":")
            if parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) {
                durSec = m * 60 + s
            }
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
            return (response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false
        } catch {
            return false
        }
    }

    public func previewImportPlaylist(url inputUrl: String, serverURL: String, token: String?) async -> (preview: PlaylistImportPreview?, error: String?) {
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/discovery/playlist-preview") else {
            return (nil, "Ungültige Server-URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(currentDeviceId, forHTTPHeaderField: "X-Device-ID")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["url": inputUrl])

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (nil, "Keine Antwort vom Server")
            }
            if !(200...299).contains(http.statusCode) {
                if let errJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let msg = errJson["error"] as? String ?? errJson["message"] as? String {
                    return (nil, msg)
                }
                return (nil, "Playlist konnte nicht geladen werden (HTTP \(http.statusCode))")
            }
            let decoded = try JSONDecoder().decode(PlaylistImportPreview.self, from: data)
            if !decoded.success {
                return (nil, "Playlist-Vorschau fehlgeschlagen")
            }
            return (decoded, nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }

    // MARK: - Local Uploaded Audio Files (/api/files/audio)
    public func fetchLocalAudioFiles(serverURL: String, token: String?) async -> [Track] {
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/files/audio") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(currentDeviceId, forHTTPHeaderField: "X-Device-ID")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }
            return items.compactMap { item -> Track? in
                guard let id = item["id"] as? String, !id.isEmpty else { return nil }
                let title = item["title"] as? String ?? "Audiodatei"
                let artist = item["artist"] as? String ?? "Lokale Datei"
                let album = item["album"] as? String
                let durSec = (item["duration"] as? Double) ?? 0
                let durFmt = item["duration_formatted"] as? String ?? {
                    let m = Int(durSec) / 60
                    let s = Int(durSec) % 60
                    return String(format: "%d:%02d", m, s)
                }()
                let cover = item["cover_url"] as? String
                let streamPath = item["url"] as? String ?? "/api/files/audio/\(id)"
                return Track(
                    id: id,
                    title: title,
                    artist: artist,
                    album: album,
                    duration: durFmt,
                    durationSeconds: durSec,
                    coverUrl: cover,
                    isLive: false,
                    isExplicit: false,
                    sourceUrl: streamPath
                )
            }
        } catch {
            return []
        }
    }

    // MARK: - Curated & Directory Radio API (/api/radio/*)
    public func cachedCuratedRadio() -> CuratedRadioResponse? {
        guard let data = UserDefaults.standard.data(forKey: curatedRadioCacheKey),
              let decoded = try? JSONDecoder().decode(CuratedRadioResponse.self, from: data) else {
            return nil
        }
        return decoded
    }

    public func fetchCuratedRadio(serverURL: String, token: String?) async -> CuratedRadioResponse? {
        if await MainActor.run(body: { SessionManager.shared.isOfflineMode }) {
            return cachedCuratedRadio()
        }
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/radio/stations") else { return cachedCuratedRadio() }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15.0
        request.setValue(currentDeviceId, forHTTPHeaderField: "X-Device-ID")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await discoverySession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let decoded = try? JSONDecoder().decode(CuratedRadioResponse.self, from: data) else {
                return cachedCuratedRadio()
            }
            if let encoded = try? JSONEncoder().encode(decoded) {
                UserDefaults.standard.set(encoded, forKey: curatedRadioCacheKey)
            }
            return decoded
        } catch {
            return cachedCuratedRadio()
        }
    }

    public func fetchTopRadioStations(country: String = "", limit: Int = 60, offset: Int = 0, serverURL: String, token: String?) async -> [RadioBrowserStation] {
        var items = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        if !country.isEmpty {
            items.append(URLQueryItem(name: "country", value: country))
        }
        return await performRadioDirectoryQuery(endpoint: "/api/radio/top", queryItems: items, serverURL: serverURL, token: token)
    }

    public func searchRadioStations(query: String, country: String = "", limit: Int = 60, offset: Int = 0, serverURL: String, token: String?) async -> [RadioBrowserStation] {
        var items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        if !country.isEmpty {
            items.append(URLQueryItem(name: "country", value: country))
        }
        return await performRadioDirectoryQuery(endpoint: "/api/radio/search", queryItems: items, serverURL: serverURL, token: token)
    }

    public func fetchRadioStationsByTag(tag: String, country: String = "", limit: Int = 60, offset: Int = 0, serverURL: String, token: String?) async -> [RadioBrowserStation] {
        var items = [
            URLQueryItem(name: "tag", value: tag),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        if !country.isEmpty {
            items.append(URLQueryItem(name: "country", value: country))
        }
        return await performRadioDirectoryQuery(endpoint: "/api/radio/bytag", queryItems: items, serverURL: serverURL, token: token)
    }

    private func performRadioDirectoryQuery(endpoint: String, queryItems: [URLQueryItem], serverURL: String, token: String?) async -> [RadioBrowserStation] {
        if await MainActor.run(body: { SessionManager.shared.isOfflineMode }) {
            return []
        }
        let base = cleanURL(serverURL)
        guard var comps = URLComponents(string: "\(base)\(endpoint)") else { return [] }
        comps.queryItems = queryItems
        guard let url = comps.url else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15.0
        request.setValue(currentDeviceId, forHTTPHeaderField: "X-Device-ID")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await discoverySession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let decoded = try? JSONDecoder().decode(RadioStationsListResponse.self, from: data) else {
                return []
            }
            return decoded.stations
        } catch {
            return []
        }
    }

    public func fetchRadioMixTracks(mixId: Int, mixTitle: String, fallbackCover: String?, serverURL: String, token: String?) async -> [Track] {
        if await MainActor.run(body: { SessionManager.shared.isOfflineMode }) {
            return []
        }
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/radio/mix/\(mixId)") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15.0
        request.setValue(currentDeviceId, forHTTPHeaderField: "X-Device-ID")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await discoverySession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let rawTracks = try? JSONDecoder().decode([DiscoveryTrack].self, from: data) else {
                return []
            }
            return rawTracks.map { item in
                Track(
                    id: item.id,
                    title: item.title,
                    artist: item.artist,
                    album: item.album ?? mixTitle,
                    duration: item.duration ?? "0:00",
                    durationSeconds: Double(item.durationSeconds ?? 0),
                    coverUrl: item.cover ?? fallbackCover,
                    isLive: false,
                    isExplicit: item.isExplicit ?? false
                )
            }
        } catch {
            return []
        }
    }

    // MARK: - Radio Favorites (/api/radio/favorites)
    public func cachedRadioFavorites() -> [LibraryRadioStation] {
        guard let data = UserDefaults.standard.data(forKey: radioFavoritesCacheKey),
              let decoded = try? JSONDecoder().decode([LibraryRadioStation].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persistRadioFavoritesCache(_ stations: [LibraryRadioStation]) {
        if let encoded = try? JSONEncoder().encode(stations) {
            UserDefaults.standard.set(encoded, forKey: radioFavoritesCacheKey)
        }
    }

    public func fetchRadioFavorites(serverURL: String, token: String?) async -> [LibraryRadioStation] {
        if await MainActor.run(body: { SessionManager.shared.isOfflineMode }) {
            return cachedRadioFavorites()
        }
        let base = cleanURL(serverURL)
        guard let url = URL(string: "\(base)/api/radio/favorites") else { return cachedRadioFavorites() }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(currentDeviceId, forHTTPHeaderField: "X-Device-ID")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let stationsData = json["stations"],
                  let rawData = try? JSONSerialization.data(withJSONObject: stationsData),
                  let list = try? JSONDecoder().decode([LibraryRadioStation].self, from: rawData) else {
                return cachedRadioFavorites()
            }
            persistRadioFavoritesCache(list)
            return list
        } catch {
            return cachedRadioFavorites()
        }
    }

    public func toggleRadioFavorite(station: LibraryRadioStation, isFavorite: Bool, serverURL: String, token: String?) async -> Bool {
        let base = cleanURL(serverURL)
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+?#"))
        let encodedId = station.id.addingPercentEncoding(withAllowedCharacters: allowed) ?? station.id

        let urlString = isFavorite ? "\(base)/api/radio/favorites?id=\(encodedId)" : "\(base)/api/radio/favorites"
        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = isFavorite ? "DELETE" : "POST"
        request.setValue(currentDeviceId, forHTTPHeaderField: "X-Device-ID")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }
        if !isFavorite {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONEncoder().encode(["station": station])
        }

        do {
            let (data, response) = try await session.data(for: request)
            let ok = (response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false
            if ok,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let stationsData = json["stations"],
               let rawData = try? JSONSerialization.data(withJSONObject: stationsData),
               let updated = try? JSONDecoder().decode([LibraryRadioStation].self, from: rawData) {
                persistRadioFavoritesCache(updated)
            }
            return ok
        } catch {
            return false
        }
    }
}
