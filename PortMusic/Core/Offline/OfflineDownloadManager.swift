import Foundation
import SwiftUI
import Combine
import AVFoundation

public struct OfflineTrackRecord: Codable, Identifiable, Equatable {
    public var id: String { track.id }
    public let track: Track
    public let localFileName: String
    public let localCoverFileName: String?
    public let localLyricsFileName: String?
    public let sizeBytes: Int64
    public let downloadedAt: Date
    public var playlistIds: [String]

    public init(
        track: Track,
        localFileName: String,
        localCoverFileName: String? = nil,
        localLyricsFileName: String? = nil,
        sizeBytes: Int64 = 0,
        downloadedAt: Date = Date(),
        playlistIds: [String] = []
    ) {
        self.track = track
        self.localFileName = localFileName
        self.localCoverFileName = localCoverFileName
        self.localLyricsFileName = localLyricsFileName
        self.sizeBytes = sizeBytes
        self.downloadedAt = downloadedAt
        self.playlistIds = playlistIds
    }
}

public struct OfflinePlaylistMeta: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var coverUrl: String?
    public var downloadedAt: Date
    public var orderedTrackIds: [String]
    public var autoSync: Bool

    public init(
        id: String,
        name: String,
        coverUrl: String? = nil,
        downloadedAt: Date = Date(),
        orderedTrackIds: [String] = [],
        autoSync: Bool = true
    ) {
        self.id = id
        self.name = name
        self.coverUrl = coverUrl
        self.downloadedAt = downloadedAt
        self.orderedTrackIds = orderedTrackIds
        self.autoSync = autoSync
    }

    enum CodingKeys: String, CodingKey {
        case id, name, coverUrl, downloadedAt, orderedTrackIds, autoSync
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
        downloadedAt = try container.decodeIfPresent(Date.self, forKey: .downloadedAt) ?? Date()
        orderedTrackIds = try container.decodeIfPresent([String].self, forKey: .orderedTrackIds) ?? []
        autoSync = try container.decodeIfPresent(Bool.self, forKey: .autoSync) ?? true
    }
}

@MainActor
public final class OfflineDownloadManager: ObservableObject {
    public static let shared = OfflineDownloadManager()

    @Published public private(set) var downloadedTrackIds: Set<String> = []
    @Published public private(set) var downloadingTrackIds: Set<String> = []
    @Published public private(set) var downloadProgressMap: [String: Double] = [:]
    @Published public private(set) var downloadingPlaylistIds: Set<String> = []
    @Published public private(set) var markedOfflinePlaylistIds: Set<String> = []

    private var records: [String: OfflineTrackRecord] = [:]
    private var playlistMetas: [String: OfflinePlaylistMeta] = [:]
    private var playlistDownloadTasks: [String: Task<Void, Never>] = [:]
    private static let singleManualMarker = "_single_"
    private let manifestFileName = "offline_manifest.json"
    private let playlistsMetaFileName = "offline_playlists.json"
    private let tracksSubdir = "OfflineTracks"
    private let coversSubdir = "OfflineCovers"
    private let lyricsSubdir = "OfflineLyrics"

    private let downloadSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 45.0
        cfg.timeoutIntervalForResource = 300.0
        PortNetworkFirewall.applyPolicy(to: cfg, isDownload: true)
        return URLSession(configuration: cfg)
    }()

    public func cancelAllActiveDownloads(keepUserMarks: Bool = true) {
        for task in playlistDownloadTasks.values {
            task.cancel()
        }
        playlistDownloadTasks.removeAll()
        downloadingPlaylistIds.removeAll()
        downloadingTrackIds.removeAll()
        downloadProgressMap.removeAll()

        downloadSession.getAllTasks { tasks in
            for task in tasks {
                task.cancel()
            }
        }

        if !keepUserMarks {
            markedOfflinePlaylistIds.removeAll()
        }
    }

    private var tracksDirectoryURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(tracksSubdir, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var coversDirectoryURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(coversSubdir, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var lyricsDirectoryURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(lyricsSubdir, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func safeTrackId(for trackId: String) -> String {
        trackId
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "&", with: "_")
    }

    private var manifestFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(manifestFileName)
    }

    private var playlistsMetaFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(playlistsMetaFileName)
    }

    private init() {
        loadManifest()
        loadPlaylistMetas()
        Task {
            await repairMissingCoversIfNeeded()
        }
    }

    // MARK: - Manifest Persistence

    private func loadManifest() {
        let url = manifestFileURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: OfflineTrackRecord].self, from: data) else {
            self.records = [:]
            self.downloadedTrackIds = []
            return
        }

        // Bereinige Eintraege, deren Audio-Datei auf der Festplatte fehlt
        var validRecords: [String: OfflineTrackRecord] = [:]
        for (id, record) in decoded {
            let fileURL = tracksDirectoryURL.appendingPathComponent(record.localFileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                // Pruefe ob Cover-Datei wirklich noch ein gueltiges Bild ist
                var cleanCoverName = record.localCoverFileName
                if let cov = cleanCoverName {
                    let covURL = coversDirectoryURL.appendingPathComponent(cov)
                    if !FileManager.default.fileExists(atPath: covURL.path) || UIImage(contentsOfFile: covURL.path) == nil {
                        try? FileManager.default.removeItem(at: covURL)
                        cleanCoverName = nil
                    }
                }
                // Pruefe ob Lyrics-Datei existiert (inkl. Self-Healing per Safe-ID)
                var cleanLyricsName = record.localLyricsFileName
                if let lrcName = cleanLyricsName {
                    let lrcURL = lyricsDirectoryURL.appendingPathComponent(lrcName)
                    if !FileManager.default.fileExists(atPath: lrcURL.path) {
                        cleanLyricsName = nil
                    }
                } else {
                    let fallbackName = "\(safeTrackId(for: id)).lrc"
                    let fallbackURL = lyricsDirectoryURL.appendingPathComponent(fallbackName)
                    if FileManager.default.fileExists(atPath: fallbackURL.path) {
                        cleanLyricsName = fallbackName
                    }
                }
                validRecords[id] = OfflineTrackRecord(
                    track: record.track,
                    localFileName: record.localFileName,
                    localCoverFileName: cleanCoverName,
                    localLyricsFileName: cleanLyricsName,
                    sizeBytes: record.sizeBytes,
                    downloadedAt: record.downloadedAt,
                    playlistIds: record.playlistIds
                )
            }
        }

        self.records = validRecords
        self.downloadedTrackIds = Set(validRecords.keys)
    }

    private func saveManifest() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: manifestFileURL, options: .atomic)
    }

    private func loadPlaylistMetas() {
        let url = playlistsMetaFileURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: OfflinePlaylistMeta].self, from: data) else {
            self.playlistMetas = [:]
            self.markedOfflinePlaylistIds = []
            return
        }
        self.playlistMetas = decoded
        self.markedOfflinePlaylistIds = Set(decoded.values.filter(\.autoSync).map(\.id))
    }

    private func savePlaylistMetas() {
        self.markedOfflinePlaylistIds = Set(playlistMetas.values.filter(\.autoSync).map(\.id))
        guard let data = try? JSONEncoder().encode(playlistMetas) else { return }
        try? data.write(to: playlistsMetaFileURL, options: .atomic)
    }

    // MARK: - Public Query Methods

    public func isDownloaded(trackId: String) -> Bool {
        guard downloadedTrackIds.contains(trackId), let record = records[trackId] else {
            return false
        }
        let fileURL = tracksDirectoryURL.appendingPathComponent(record.localFileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    public func isDownloading(trackId: String) -> Bool {
        downloadingTrackIds.contains(trackId)
    }

    public func downloadProgress(trackId: String) -> Double {
        downloadProgressMap[trackId] ?? 0.0
    }

    public func isPlaylistMarkedForOffline(_ playlistId: String) -> Bool {
        playlistMetas[playlistId]?.autoSync == true
    }

    public func isPlaylistDownloading(_ playlistId: String, tracks: [Track] = []) -> Bool {
        if downloadingPlaylistIds.contains(playlistId) {
            return true
        }
        return tracks.contains { downloadingTrackIds.contains($0.id) }
    }

    public func downloadedCount(forPlaylistTracks tracks: [Track]) -> Int {
        tracks.filter { isDownloaded(trackId: $0.id) }.count
    }

    public func areAllTracksDownloaded(_ tracks: [Track]) -> Bool {
        !tracks.isEmpty && tracks.allSatisfy { isDownloaded(trackId: $0.id) }
    }

    public func cancelPlaylistDownload(_ playlistId: String) {
        playlistDownloadTasks[playlistId]?.cancel()
        playlistDownloadTasks.removeValue(forKey: playlistId)
        downloadingPlaylistIds.remove(playlistId)
    }

    public func localAudioFileURL(for trackId: String) -> URL? {
        guard let record = records[trackId] else { return nil }
        let fileURL = tracksDirectoryURL.appendingPathComponent(record.localFileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }

    public func localCoverFileURL(for trackId: String) -> URL? {
        guard let record = records[trackId], let coverName = record.localCoverFileName else { return nil }
        let fileURL = coversDirectoryURL.appendingPathComponent(coverName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }

    public func localCoverImage(for trackId: String) -> UIImage? {
        guard let url = localCoverFileURL(for: trackId) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    public func localLyricsFileURL(for trackId: String) -> URL? {
        if let record = records[trackId], let lrcName = record.localLyricsFileName {
            let fileURL = lyricsDirectoryURL.appendingPathComponent(lrcName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }
        let fallbackURL = lyricsDirectoryURL.appendingPathComponent("\(safeTrackId(for: trackId)).lrc")
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
            return fallbackURL
        }
        return nil
    }

    public func localLyrics(for trackId: String) -> String? {
        guard let url = localLyricsFileURL(for: trackId),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : content
    }

    public func saveLyrics(_ lrc: String, for trackId: String) {
        let trimmed = lrc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var record = records[trackId] else { return }
        let fileName = "\(safeTrackId(for: trackId)).lrc"
        let targetURL = lyricsDirectoryURL.appendingPathComponent(fileName)
        try? lrc.write(to: targetURL, atomically: true, encoding: .utf8)
        if record.localLyricsFileName != fileName {
            record = OfflineTrackRecord(
                track: record.track,
                localFileName: record.localFileName,
                localCoverFileName: record.localCoverFileName,
                localLyricsFileName: fileName,
                sizeBytes: record.sizeBytes,
                downloadedAt: record.downloadedAt,
                playlistIds: record.playlistIds
            )
            records[trackId] = record
            saveManifest()
        }
    }

    public func allDownloadedTracks() -> [Track] {
        records.values
            .sorted(by: { $0.downloadedAt > $1.downloadedAt })
            .map { enrichTrackWithLocalCover($0) }
    }

    public func allDownloadedPodcastEpisodes() -> [Track] {
        allDownloadedTracks().filter {
            $0.id.hasPrefix("pod_")
                || ($0.sourceUrl?.hasPrefix("/api/podcasts/stream") == true)
                || $0.album == "Podcast"
        }
    }

    public func downloadedTracks(forPlaylistId playlistId: String) -> [Track] {
        let linked = records.values.filter { $0.playlistIds.contains(playlistId) }
        guard !linked.isEmpty else { return [] }

        let order = playlistMetas[playlistId]?.orderedTrackIds ?? []
        if !order.isEmpty {
            let byId = Dictionary(uniqueKeysWithValues: linked.map { ($0.track.id, $0) })
            var ordered: [Track] = []
            var seen = Set<String>()
            for tid in order {
                if let rec = byId[tid], seen.insert(tid).inserted {
                    ordered.append(enrichTrackWithLocalCover(rec))
                }
            }
            for rec in linked.sorted(by: { $0.downloadedAt < $1.downloadedAt }) where seen.insert(rec.track.id).inserted {
                ordered.append(enrichTrackWithLocalCover(rec))
            }
            return ordered
        }

        return linked
            .sorted(by: { $0.downloadedAt < $1.downloadedAt })
            .map { enrichTrackWithLocalCover($0) }
    }

    public func downloadedPlaylistMeta(forPlaylistId playlistId: String) -> OfflinePlaylistMeta? {
        playlistMetas[playlistId]
    }

    public func allDownloadedPlaylists(includeLikedSongs: Bool = false) -> [DiscoveryPlaylist] {
        var playlistIds = Set(playlistMetas.keys)
        for rec in records.values {
            for pid in rec.playlistIds where !pid.isEmpty {
                playlistIds.insert(pid)
            }
        }

        var result: [(playlist: DiscoveryPlaylist, sortDate: Date)] = []
        for pid in playlistIds {
            if pid == Self.singleManualMarker || pid == "favorites" {
                continue
            }
            if !includeLikedSongs && pid == "liked_songs" {
                continue
            }
            let dlTracks = downloadedTracks(forPlaylistId: pid)
            let meta = playlistMetas[pid]
            // Nur Playlists anzeigen, die Metadaten oder mindestens einen geladenen Track besitzen
            guard meta != nil || !dlTracks.isEmpty else { continue }

            var trackCovers: [String] = []
            var seenCov = Set<String>()
            for t in dlTracks {
                if let cov = t.coverUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !cov.isEmpty,
                   seenCov.insert(cov).inserted {
                    trackCovers.append(cov)
                    if trackCovers.count >= 4 { break }
                }
            }

            let title = meta?.name ?? "Offline-Playlist"
            let cover = meta?.coverUrl ?? trackCovers.first ?? ""
            let pl = DiscoveryPlaylist(
                id: pid,
                title: title,
                cover: cover,
                nbTracks: dlTracks.count,
                user: "Offline gespeichert",
                folderId: nil,
                trackCovers: trackCovers.isEmpty ? nil : trackCovers
            )
            result.append((pl, meta?.downloadedAt ?? Date.distantPast))
        }

        return result
            .sorted { $0.sortDate > $1.sortDate }
            .map { $0.playlist }
    }

    public func mergeOfflinePlaylists(with baseList: [DiscoveryPlaylist]) -> [DiscoveryPlaylist] {
        // Lieblingssongs ("liked_songs") hat eine eigene dedizierte Karte in Bibliothek & Startseite
        // und darf niemals ein zweites Mal als normale Playlist erscheinen.
        let excludedSystemIds: Set<String> = ["liked_songs", "favorites", Self.singleManualMarker]
        let isSystemLikedEntry: (DiscoveryPlaylist) -> Bool = { pl in
            excludedSystemIds.contains(pl.id)
                || pl.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "lieblingssongs"
        }
        let filteredBase = baseList.filter { !isSystemLikedEntry($0) }
        let offline = allDownloadedPlaylists(includeLikedSongs: false).filter { !isSystemLikedEntry($0) }
        guard !offline.isEmpty else { return filteredBase }
        let offlineById = Dictionary(uniqueKeysWithValues: offline.map { ($0.id, $0) })

        var merged: [DiscoveryPlaylist] = []
        var seen = Set<String>()
        for pl in filteredBase {
            if let off = offlineById[pl.id] {
                let mergedCover = pl.cover.isEmpty ? off.cover : pl.cover
                let mergedTrackCovers = (pl.trackCovers?.isEmpty == false) ? pl.trackCovers : off.trackCovers
                merged.append(DiscoveryPlaylist(
                    id: pl.id,
                    title: pl.title.isEmpty ? off.title : pl.title,
                    cover: mergedCover,
                    nbTracks: pl.nbTracks ?? off.nbTracks,
                    user: pl.user ?? off.user,
                    folderId: pl.folderId,
                    trackCovers: mergedTrackCovers
                ))
            } else {
                merged.append(pl)
            }
            seen.insert(pl.id)
        }
        for off in offline where !seen.contains(off.id) {
            merged.insert(off, at: 0)
        }
        return merged
    }

    private func enrichTrackWithLocalCover(_ record: OfflineTrackRecord) -> Track {
        if let covURL = localCoverFileURL(for: record.track.id) {
            return Track(
                id: record.track.id,
                title: record.track.title,
                artist: record.track.artist,
                album: record.track.album,
                duration: record.track.duration,
                durationSeconds: record.track.durationSeconds,
                coverUrl: covURL.absoluteString,
                isLive: false,
                isExplicit: record.track.isExplicit,
                sourceUrl: record.track.sourceUrl
            )
        }
        return record.track
    }

    public func totalStorageBytes() -> Int64 {
        records.values.reduce(0) { $0 + $1.sizeBytes }
    }

    public func podcastsStorageBytes() -> Int64 {
        records.values.reduce(0) { sum, rec in
            let t = rec.track
            let isPod = t.id.hasPrefix("pod_")
                || (t.sourceUrl?.hasPrefix("/api/podcasts/stream") == true)
                || t.album == "Podcast"
            return sum + (isPod ? rec.sizeBytes : 0)
        }
    }

    public func songsStorageBytes() -> Int64 {
        max(0, totalStorageBytes() - podcastsStorageBytes())
    }

    public func formattedTotalStorage() -> String {
        let bytes = Double(totalStorageBytes())
        if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024.0)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", bytes / (1024.0 * 1024.0))
        } else {
            return String(format: "%.2f GB", bytes / (1024.0 * 1024.0 * 1024.0))
        }
    }

    // MARK: - Download Execution

    @discardableResult
    public func downloadTrack(track: Track, serverURL: String, token: String?, playlistId: String? = nil) async -> Bool {
        let marker = playlistId ?? Self.singleManualMarker
        if isDownloaded(trackId: track.id) {
            if var record = records[track.id], !record.playlistIds.contains(marker) {
                record.playlistIds.append(marker)
                records[track.id] = record
                saveManifest()
            }
            if localCoverFileURL(for: track.id) == nil, SessionManager.shared.allowsOnlineRequests {
                _ = await ensureCoverSavedForRecord(trackId: track.id, preferredCoverUrl: track.coverUrl, serverURL: serverURL, token: token)
            }
            if localLyrics(for: track.id) == nil,
               SessionManager.shared.allowsOnlineRequests,
               !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let safeId = safeTrackId(for: track.id)
                if let lrcName = await fetchAndPersistLyrics(track: track, safeTrackId: safeId, serverURL: serverURL, token: token),
                   var record = records[track.id] {
                    record = OfflineTrackRecord(
                        track: record.track,
                        localFileName: record.localFileName,
                        localCoverFileName: record.localCoverFileName,
                        localLyricsFileName: lrcName,
                        sizeBytes: record.sizeBytes,
                        downloadedAt: record.downloadedAt,
                        playlistIds: record.playlistIds
                    )
                    records[track.id] = record
                    saveManifest()
                }
            }
            return true
        }

        guard SessionManager.shared.allowsDownloads else {
            return false
        }

        if isDownloading(trackId: track.id) {
            return false
        }

        downloadingTrackIds.insert(track.id)
        downloadProgressMap[track.id] = 0.05

        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let safeTrackId = track.id
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "&", with: "_")

        // URL-Kandidaten zur Audiogewinnung (exakt wie im Web mit vollen Metadaten)
        var candidates: [URL] = []
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        let encodedId = track.id.addingPercentEncoding(withAllowedCharacters: allowed) ?? track.id
        let isPodcastEpisode = track.id.hasPrefix("pod_")
            || (track.sourceUrl?.hasPrefix("/api/podcasts/stream") == true)
            || track.album == "Podcast"

        if isPodcastEpisode {
            // Podcast-Folgen direkt über den Podcast-Stream-Endpunkt herunterladen (niemals Musik-Endpunkte abfragen)
            if let uPodStream = MusicService.shared.streamURL(for: track, serverURL: base) {
                candidates.pushCandidate(uPodStream)
            }
            if let src = track.sourceUrl, (src.hasPrefix("http://") || src.hasPrefix("https://")),
               let uDirectPod = URL(string: src) {
                candidates.pushCandidate(uDirectPod)
            }
        } else {
            // 0. Falls lokale Server-Datei ueber sourceUrl bekannt ist
            if let src = track.sourceUrl, src.hasPrefix("/api/files/audio/"),
               let uDirect = URL(string: "\(base)\(src)") {
                candidates.pushCandidate(uDirect)
            }

            // 1. Primaerer Download-Endpunkt mit Metadaten (fuer sauberes M4A im Backend)
            if var dlComponents = URLComponents(string: "\(base)/api/tracks/\(encodedId)/download") {
                var qItems: [URLQueryItem] = [
                    URLQueryItem(name: "title", value: track.title),
                    URLQueryItem(name: "artist", value: track.artist)
                ]
                if let alb = track.album, !alb.isEmpty { qItems.append(URLQueryItem(name: "album", value: alb)) }
                if let cov = track.coverUrl ?? track.cover, !cov.isEmpty { qItems.append(URLQueryItem(name: "cover", value: cov)) }
                if track.durationSeconds > 0 { qItems.append(URLQueryItem(name: "duration", value: "\(track.durationSeconds)")) }
                dlComponents.queryItems = qItems
                if let uDl = dlComponents.url { candidates.pushCandidate(uDl) }
            }

            // 2. Stream-Endpunkt mit vollen Metadaten als Fallback
            if let uStream = MusicService.shared.streamURL(for: track, serverURL: base) {
                candidates.pushCandidate(uStream)
            }

            // 3. Lokale Server-Dateien (Uploads)
            if let uFile = URL(string: "\(base)/api/files/audio/\(encodedId)") { candidates.pushCandidate(uFile) }
            if let uFile2 = URL(string: "\(base)/api/files/\(encodedId)") { candidates.pushCandidate(uFile2) }
            if let uAudio = URL(string: "\(base)/audio/320/\(encodedId)") { candidates.pushCandidate(uAudio) }
        }

        var downloadedData: Data? = nil
        var detectedMime: String? = nil

        for cand in candidates {
            guard SessionManager.shared.allowsDownloads else { break }
            var req = URLRequest(url: cand)
            req.httpMethod = "GET"
            req.allowsCellularAccess = PortNetworkFirewall.shared.allowsDownloadsCellular
            if let tok = token, !tok.isEmpty {
                req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
                req.setValue(tok, forHTTPHeaderField: "x-session-token")
            }

            do {
                downloadProgressMap[track.id] = 0.25
                let (data, response) = try await downloadSession.data(for: req)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), data.count > 10240 {
                    let mime = (http.mimeType ?? "").lowercased()
                    if mime.contains("text/html") || mime.contains("application/json") || mime.contains("text/plain") {
                        continue
                    }
                    downloadedData = data
                    detectedMime = http.mimeType
                    break
                }
            } catch {
                continue
            }
        }

        guard let validData = downloadedData else {
            downloadingTrackIds.remove(track.id)
            downloadProgressMap.removeValue(forKey: track.id)
            return false
        }

        downloadProgressMap[track.id] = 0.80
        let ext = Self.detectAudioExtension(data: validData, mimeType: detectedMime)
        let fileName = "\(safeTrackId).\(ext)"
        let targetFileURL = tracksDirectoryURL.appendingPathComponent(fileName)

        do {
            try validData.write(to: targetFileURL, options: .atomic)

            // Mehrstufige Cover- & Lyrics-Speicherung parallel ausfuehren
            async let coverNameTask = fetchAndPersistCover(
                track: track,
                safeTrackId: safeTrackId,
                audioFileURL: targetFileURL,
                serverURL: base,
                token: token
            )
            async let lyricsNameTask = fetchAndPersistLyrics(
                track: track,
                safeTrackId: safeTrackId,
                serverURL: base,
                token: token
            )

            downloadProgressMap[track.id] = 0.90
            let (localCoverName, localLyricsName) = await (coverNameTask, lyricsNameTask)

            let size = Int64(validData.count)
            let existingPlaylistIds = records[track.id]?.playlistIds ?? []
            var pIds = existingPlaylistIds
            let marker = playlistId ?? Self.singleManualMarker
            if !pIds.contains(marker) {
                pIds.append(marker)
            }

            let record = OfflineTrackRecord(
                track: track,
                localFileName: fileName,
                localCoverFileName: localCoverName,
                localLyricsFileName: localLyricsName,
                sizeBytes: size,
                downloadedAt: Date(),
                playlistIds: pIds
            )

            self.records[track.id] = record
            self.downloadedTrackIds.insert(track.id)
            self.downloadingTrackIds.remove(track.id)
            self.downloadProgressMap.removeValue(forKey: track.id)
            self.saveManifest()
            return true
        } catch {
            downloadingTrackIds.remove(track.id)
            downloadProgressMap.removeValue(forKey: track.id)
            return false
        }
    }

    public func downloadPlaylist(playlistId: String, name: String, coverUrl: String? = nil, tracks: [Track], serverURL: String, token: String?) {
        let trackIds = tracks.map(\.id)
        let prevDate = playlistMetas[playlistId]?.downloadedAt ?? Date()
        playlistMetas[playlistId] = OfflinePlaylistMeta(
            id: playlistId,
            name: name,
            coverUrl: coverUrl,
            downloadedAt: prevDate,
            orderedTrackIds: trackIds,
            autoSync: true
        )
        savePlaylistMetas()
        UserDefaults.standard.set(true, forKey: "port_playlist_downloaded_\(playlistId)")

        // Verknüpfe bereits lokal vorhandene Songs sofort sauber mit dieser Playlist
        var linkedExisting = false
        for t in tracks where isDownloaded(trackId: t.id) {
            if var rec = records[t.id], !rec.playlistIds.contains(playlistId) {
                rec.playlistIds.append(playlistId)
                records[t.id] = rec
                linkedExisting = true
            }
        }
        if linkedExisting {
            saveManifest()
        }

        let missing = tracks.filter { !isDownloaded(trackId: $0.id) }
        guard !missing.isEmpty else {
            downloadingPlaylistIds.remove(playlistId)
            return
        }

        guard SessionManager.shared.allowsDownloads else {
            downloadingPlaylistIds.remove(playlistId)
            return
        }

        playlistDownloadTasks[playlistId]?.cancel()
        downloadingPlaylistIds.insert(playlistId)

        let task = Task { [weak self] in
            guard let self = self else { return }
            defer {
                self.downloadingPlaylistIds.remove(playlistId)
                self.playlistDownloadTasks.removeValue(forKey: playlistId)
            }
            for track in missing {
                if Task.isCancelled || !SessionManager.shared.allowsDownloads {
                    break
                }
                _ = await self.downloadTrack(track: track, serverURL: serverURL, token: token, playlistId: playlistId)
            }
        }
        playlistDownloadTasks[playlistId] = task
    }

    /// Synchronisiert eine offline vorgemerkte Playlist gegen die aktuelle Server-Trackliste:
    /// - Entfernt gelöschte Songs aus der Playlist-Zuordnung (und löscht verwaiste Dateien)
    /// - Lädt neu hinzugekommene oder bisher unvollständige Songs automatisch herunter
    public func syncPlaylistIfMarked(
        playlistId: String,
        name: String,
        coverUrl: String? = nil,
        latestTracks: [Track],
        serverURL: String,
        token: String?
    ) {
        guard isPlaylistMarkedForOffline(playlistId) else { return }

        let latestIds = latestTracks.map(\.id)
        let latestIdSet = Set(latestIds)
        let prevDate = playlistMetas[playlistId]?.downloadedAt ?? Date()
        playlistMetas[playlistId] = OfflinePlaylistMeta(
            id: playlistId,
            name: name.isEmpty ? (playlistMetas[playlistId]?.name ?? "Playlist") : name,
            coverUrl: (coverUrl?.isEmpty == false) ? coverUrl : playlistMetas[playlistId]?.coverUrl,
            downloadedAt: prevDate,
            orderedTrackIds: latestIds,
            autoSync: true
        )
        savePlaylistMetas()

        // 1. Entfernte Songs aus dieser Playlist lösen (nur löschen, wenn nirgends sonst genutzt)
        var manifestChanged = false
        let previouslyLinkedIds = records.values.filter { $0.playlistIds.contains(playlistId) }.map(\.id)
        for tid in previouslyLinkedIds where !latestIdSet.contains(tid) {
            guard var rec = records[tid] else { continue }
            rec.playlistIds.removeAll { $0 == playlistId }
            if rec.playlistIds.isEmpty {
                removeDownload(trackId: tid)
            } else {
                records[tid] = rec
                manifestChanged = true
            }
        }
        if manifestChanged {
            saveManifest()
        }

        // 2. Fehlende oder neu hinzugekommene Songs herunterladen (wenn online, WLAN erlaubt & nicht bereits laufend)
        if SessionManager.shared.allowsDownloads && !isPlaylistDownloading(playlistId) {
            let hasMissing = latestTracks.contains { !isDownloaded(trackId: $0.id) }
            if hasMissing {
                downloadPlaylist(
                    playlistId: playlistId,
                    name: playlistMetas[playlistId]?.name ?? name,
                    coverUrl: playlistMetas[playlistId]?.coverUrl,
                    tracks: latestTracks,
                    serverURL: serverURL,
                    token: token
                )
            }
        }
    }

    public func syncSavedPlaylistsOnReconnect(serverURL: String, token: String?) async {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !base.isEmpty, SessionManager.shared.allowsDownloads else { return }

        let markedMetas = playlistMetas.values.filter(\.autoSync)
        guard !markedMetas.isEmpty else { return }

        let (statePlaylists, _) = await MusicService.shared.fetchUserState(serverURL: base, token: token)
        let stateById = Dictionary(uniqueKeysWithValues: statePlaylists.map { ($0.id, $0) })

        for meta in markedMetas {
            if !SessionManager.shared.allowsDownloads { break }

            if meta.id == "liked_songs" {
                let favs = await MusicService.shared.fetchFavorites(serverURL: base, token: token)
                if !favs.isEmpty {
                    syncPlaylistIfMarked(
                        playlistId: meta.id,
                        name: meta.name,
                        coverUrl: meta.coverUrl,
                        latestTracks: favs,
                        serverURL: base,
                        token: token
                    )
                }
                continue
            }

            if let userPl = stateById[meta.id] {
                let latestTracks = userPl.tracks.map { $0.toTrack() }
                syncPlaylistIfMarked(
                    playlistId: meta.id,
                    name: userPl.title,
                    coverUrl: userPl.cover,
                    latestTracks: latestTracks,
                    serverURL: base,
                    token: token
                )
            } else if let discPl = await MusicService.shared.fetchDiscoveryPlaylist(id: meta.id, serverURL: base, token: token) {
                let latestTracks = discPl.tracks.map { $0.toTrack() }
                syncPlaylistIfMarked(
                    playlistId: meta.id,
                    name: discPl.title,
                    coverUrl: discPl.cover,
                    latestTracks: latestTracks,
                    serverURL: base,
                    token: token
                )
            } else if let album = await MusicService.shared.fetchAlbum(id: meta.id, serverURL: base, token: token) {
                let latestTracks = album.tracks.map { $0.toTrack(fallbackCover: album.cover, fallbackAlbum: album.title) }
                syncPlaylistIfMarked(
                    playlistId: meta.id,
                    name: album.title,
                    coverUrl: album.cover,
                    latestTracks: latestTracks,
                    serverURL: base,
                    token: token
                )
            }
        }
    }

    // MARK: - Robust Multi-Source Cover Persistence

    private func fetchAndPersistCover(
        track: Track,
        safeTrackId: String,
        audioFileURL: URL,
        serverURL: String,
        token: String?
    ) async -> String? {
        let coverFileName = "\(safeTrackId).jpg"
        let coverTargetURL = coversDirectoryURL.appendingPathComponent(coverFileName)

        // 1. Falls Cover-URL vorhanden: erst Memory/Disk-Cache pruefen, sonst authentifiziert laden
        if let coverStr = track.coverUrl ?? track.cover, !coverStr.isEmpty,
           let cUrl = resolveCoverURL(coverStr, serverURL: serverURL) {
            if let cachedData = PortImageCache.shared.cachedImageData(for: cUrl),
               let img = UIImage(data: cachedData),
               let jpeg = img.jpegData(compressionQuality: 0.90) {
                try? jpeg.write(to: coverTargetURL, options: .atomic)
                PortImageCache.shared.storeImage(img, for: coverTargetURL)
                return coverFileName
            }

            if let img = await downloadValidatedImage(from: cUrl, token: token),
               let jpeg = img.jpegData(compressionQuality: 0.90) {
                try? jpeg.write(to: coverTargetURL, options: .atomic)
                PortImageCache.shared.storeImage(img, for: cUrl)
                PortImageCache.shared.storeImage(img, for: coverTargetURL)
                return coverFileName
            }
        }

        // 2. Fallback: Eingebettetes Artwork direkt aus der M4A/MP3-Audiodatei extrahieren
        if let embeddedImg = await extractEmbeddedArtwork(from: audioFileURL),
           let jpeg = embeddedImg.jpegData(compressionQuality: 0.90) {
            try? jpeg.write(to: coverTargetURL, options: .atomic)
            PortImageCache.shared.storeImage(embeddedImg, for: coverTargetURL)
            return coverFileName
        }

        // 3. Fallback: Discovery-Suche nach Track-Cover
        let searchQuery = "\(track.title) \(track.artist)".trimmingCharacters(in: .whitespacesAndNewlines)
        if !searchQuery.isEmpty,
           let searchRes = await MusicService.shared.fetchDiscoverySearch(query: searchQuery, serverURL: serverURL, token: token),
           let matchedCover = searchRes.tracks?.first?.cover, !matchedCover.isEmpty,
           let mUrl = resolveCoverURL(matchedCover, serverURL: serverURL),
           let img = await downloadValidatedImage(from: mUrl, token: token),
           let jpeg = img.jpegData(compressionQuality: 0.90) {
            try? jpeg.write(to: coverTargetURL, options: .atomic)
            PortImageCache.shared.storeImage(img, for: coverTargetURL)
            return coverFileName
        }

        return nil
    }

    private func downloadValidatedImage(from url: URL, token: String?) async -> UIImage? {
        var req = URLRequest(url: url)
        req.timeoutInterval = 12.0
        req.setValue("PortMusic-iOS", forHTTPHeaderField: "User-Agent")
        if let tok = token, !tok.isEmpty {
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            req.setValue(tok, forHTTPHeaderField: "x-session-token")
        }
        guard let (data, resp) = try? await downloadSession.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let img = UIImage(data: data) else {
            return nil
        }
        return img
    }

    public func extractAndCacheArtwork(for trackId: String) async -> UIImage? {
        if let img = localCoverImage(for: trackId) {
            return img
        }
        guard let audioURL = localAudioFileURL(for: trackId),
              let embedded = await extractEmbeddedArtwork(from: audioURL),
              let jpeg = embedded.jpegData(compressionQuality: 0.90),
              var record = records[trackId] else {
            return nil
        }
        let safeId = trackId
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "&", with: "_")
        let coverName = "\(safeId).jpg"
        let coverURL = coversDirectoryURL.appendingPathComponent(coverName)
        try? jpeg.write(to: coverURL, options: .atomic)
        PortImageCache.shared.storeImage(embedded, for: coverURL)
        record = OfflineTrackRecord(
            track: record.track,
            localFileName: record.localFileName,
            localCoverFileName: coverName,
            localLyricsFileName: record.localLyricsFileName,
            sizeBytes: record.sizeBytes,
            downloadedAt: record.downloadedAt,
            playlistIds: record.playlistIds
        )
        records[trackId] = record
        saveManifest()
        objectWillChange.send()
        return embedded
    }

    @discardableResult
    private func ensureCoverSavedForRecord(trackId: String, preferredCoverUrl: String?, serverURL: String, token: String?) async -> Bool {
        guard var record = records[trackId] else { return false }
        let safeId = safeTrackId(for: trackId)
        let audioURL = tracksDirectoryURL.appendingPathComponent(record.localFileName)
        let trackForLookup = Track(
            id: record.track.id,
            title: record.track.title,
            artist: record.track.artist,
            album: record.track.album,
            duration: record.track.duration,
            durationSeconds: record.track.durationSeconds,
            coverUrl: preferredCoverUrl ?? record.track.coverUrl,
            isLive: false,
            isExplicit: record.track.isExplicit,
            sourceUrl: record.track.sourceUrl
        )
        if let newCoverName = await fetchAndPersistCover(
            track: trackForLookup,
            safeTrackId: safeId,
            audioFileURL: audioURL,
            serverURL: serverURL,
            token: token
        ) {
            record = OfflineTrackRecord(
                track: trackForLookup,
                localFileName: record.localFileName,
                localCoverFileName: newCoverName,
                localLyricsFileName: record.localLyricsFileName,
                sizeBytes: record.sizeBytes,
                downloadedAt: record.downloadedAt,
                playlistIds: record.playlistIds
            )
            records[trackId] = record
            saveManifest()
            return true
        }
        return false
    }

    private func fetchAndPersistLyrics(
        track: Track,
        safeTrackId: String,
        serverURL: String,
        token: String?
    ) async -> String? {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !base.isEmpty else { return nil }

        let dur: Double? = track.durationSeconds > 0 ? track.durationSeconds : nil
        guard let rawLrc = await MusicService.shared.fetchLyrics(
            trackId: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album,
            durationSeconds: dur,
            serverURL: base,
            token: token
        ) else {
            return nil
        }

        let trimmed = rawLrc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lyricsFileName = "\(safeTrackId).lrc"
        let targetURL = lyricsDirectoryURL.appendingPathComponent(lyricsFileName)
        do {
            try rawLrc.write(to: targetURL, atomically: true, encoding: .utf8)
            return lyricsFileName
        } catch {
            return nil
        }
    }

    public func repairMissingLyricsIfNeeded(serverURL: String, token: String?) async {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !base.isEmpty, SessionManager.shared.allowsOnlineRequests else { return }

        let missingRecords = records.values.filter { localLyrics(for: $0.track.id) == nil }
        guard !missingRecords.isEmpty else { return }

        for rec in missingRecords {
            if !SessionManager.shared.allowsOnlineRequests { break }
            let safeId = safeTrackId(for: rec.track.id)
            if let lrcName = await fetchAndPersistLyrics(track: rec.track, safeTrackId: safeId, serverURL: base, token: token),
               let latestRecord = records[rec.track.id] {
                records[rec.track.id] = OfflineTrackRecord(
                    track: latestRecord.track,
                    localFileName: latestRecord.localFileName,
                    localCoverFileName: latestRecord.localCoverFileName,
                    localLyricsFileName: lrcName,
                    sizeBytes: latestRecord.sizeBytes,
                    downloadedAt: latestRecord.downloadedAt,
                    playlistIds: latestRecord.playlistIds
                )
                saveManifest()
            }
        }
    }

    private func repairMissingCoversIfNeeded() async {
        let missingIds = records.values
            .filter { $0.localCoverFileName == nil }
            .map { $0.track.id }
        guard !missingIds.isEmpty else { return }
        for tid in missingIds {
            _ = await extractAndCacheArtwork(for: tid)
        }
    }

    private func extractEmbeddedArtwork(from fileURL: URL) async -> UIImage? {
        let asset = AVURLAsset(url: fileURL)
        do {
            let items: [AVMetadataItem]
            if #available(iOS 15.0, *) {
                items = try await asset.load(.commonMetadata)
            } else {
                items = asset.commonMetadata
            }
            for item in items where item.commonKey == .commonKeyArtwork {
                if #available(iOS 15.0, *) {
                    if let data = try? await item.load(.dataValue), let img = UIImage(data: data) {
                        return img
                    }
                } else if let data = item.dataValue, let img = UIImage(data: data) {
                    return img
                }
            }
        } catch {}
        return nil
    }

    private static func detectAudioExtension(data: Data, mimeType: String?) -> String {
        if data.count >= 8 {
            let bytes = [UInt8](data.prefix(8))
            if bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70 {
                return "m4a"
            }
            if bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33 {
                return "mp3"
            }
            if bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0 {
                return "mp3"
            }
            if bytes[0] == 0x66 && bytes[1] == 0x4C && bytes[2] == 0x61 && bytes[3] == 0x43 {
                return "flac"
            }
        }
        if let mime = mimeType?.lowercased() {
            if mime.contains("mpeg") || mime.contains("mp3") { return "mp3" }
            if mime.contains("flac") { return "flac" }
            if mime.contains("wav") { return "wav" }
        }
        return "m4a"
    }

    public func removeDownload(trackId: String) {
        guard let record = records[trackId] else { return }
        let audioURL = tracksDirectoryURL.appendingPathComponent(record.localFileName)
        try? FileManager.default.removeItem(at: audioURL)

        if let coverName = record.localCoverFileName {
            let coverURL = coversDirectoryURL.appendingPathComponent(coverName)
            try? FileManager.default.removeItem(at: coverURL)
        }

        if let lrcName = record.localLyricsFileName {
            let lrcURL = lyricsDirectoryURL.appendingPathComponent(lrcName)
            try? FileManager.default.removeItem(at: lrcURL)
        } else {
            let fallbackLrc = lyricsDirectoryURL.appendingPathComponent("\(safeTrackId(for: trackId)).lrc")
            try? FileManager.default.removeItem(at: fallbackLrc)
        }

        records.removeValue(forKey: trackId)
        downloadedTrackIds.remove(trackId)
        saveManifest()
    }

    public func removePlaylistDownload(playlistId: String) {
        cancelPlaylistDownload(playlistId)
        playlistMetas.removeValue(forKey: playlistId)
        savePlaylistMetas()
        UserDefaults.standard.set(false, forKey: "port_playlist_downloaded_\(playlistId)")

        let affectedIds = records.values.filter { $0.playlistIds.contains(playlistId) }.map(\.id)
        for tid in affectedIds {
            guard var rec = records[tid] else { continue }
            rec.playlistIds.removeAll { $0 == playlistId }
            if rec.playlistIds.isEmpty {
                removeDownload(trackId: tid)
            } else {
                records[tid] = rec
            }
        }
        saveManifest()
    }

    public func removeAllDownloads() {
        for pid in Array(playlistDownloadTasks.keys) {
            cancelPlaylistDownload(pid)
        }
        try? FileManager.default.removeItem(at: tracksDirectoryURL)
        try? FileManager.default.removeItem(at: coversDirectoryURL)
        try? FileManager.default.removeItem(at: lyricsDirectoryURL)
        try? FileManager.default.removeItem(at: manifestFileURL)
        try? FileManager.default.removeItem(at: playlistsMetaFileURL)

        records.removeAll()
        playlistMetas.removeAll()
        markedOfflinePlaylistIds.removeAll()
        downloadingPlaylistIds.removeAll()
        downloadedTrackIds.removeAll()
        downloadingTrackIds.removeAll()
        downloadProgressMap.removeAll()
    }
}

private extension Array where Element == URL {
    mutating func pushCandidate(_ url: URL) {
        if !self.contains(url) {
            self.append(url)
        }
    }
}
