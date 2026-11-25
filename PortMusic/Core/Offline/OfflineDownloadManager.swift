import Foundation
import SwiftUI
import Combine
import AVFoundation

public struct OfflineTrackRecord: Codable, Identifiable, Equatable {
    public var id: String { track.id }
    public let track: Track
    public let localFileName: String
    public let localCoverFileName: String?
    public let sizeBytes: Int64
    public let downloadedAt: Date
    public var playlistIds: [String]

    public init(
        track: Track,
        localFileName: String,
        localCoverFileName: String? = nil,
        sizeBytes: Int64 = 0,
        downloadedAt: Date = Date(),
        playlistIds: [String] = []
    ) {
        self.track = track
        self.localFileName = localFileName
        self.localCoverFileName = localCoverFileName
        self.sizeBytes = sizeBytes
        self.downloadedAt = downloadedAt
        self.playlistIds = playlistIds
    }
}

public struct OfflinePlaylistMeta: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let coverUrl: String?
    public let downloadedAt: Date
}

@MainActor
public final class OfflineDownloadManager: ObservableObject {
    public static let shared = OfflineDownloadManager()

    @Published public private(set) var downloadedTrackIds: Set<String> = []
    @Published public private(set) var downloadingTrackIds: Set<String> = []
    @Published public private(set) var downloadProgressMap: [String: Double] = [:]

    private var records: [String: OfflineTrackRecord] = [:]
    private var playlistMetas: [String: OfflinePlaylistMeta] = [:]
    private let manifestFileName = "offline_manifest.json"
    private let playlistsMetaFileName = "offline_playlists.json"
    private let tracksSubdir = "OfflineTracks"
    private let coversSubdir = "OfflineCovers"

    private let downloadSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 45.0
        cfg.timeoutIntervalForResource = 300.0
        return URLSession(configuration: cfg)
    }()

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
                validRecords[id] = OfflineTrackRecord(
                    track: record.track,
                    localFileName: record.localFileName,
                    localCoverFileName: cleanCoverName,
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
            return
        }
        self.playlistMetas = decoded
    }

    private func savePlaylistMetas() {
        guard let data = try? JSONEncoder().encode(playlistMetas) else { return }
        try? data.write(to: playlistsMetaFileURL, options: .atomic)
    }

    // MARK: - Public Query Methods

    public func isDownloaded(trackId: String) -> Bool {
        downloadedTrackIds.contains(trackId)
    }

    public func isDownloading(trackId: String) -> Bool {
        downloadingTrackIds.contains(trackId)
    }

    public func downloadProgress(trackId: String) -> Double {
        downloadProgressMap[trackId] ?? 0.0
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

    public func allDownloadedTracks() -> [Track] {
        records.values
            .sorted(by: { $0.downloadedAt > $1.downloadedAt })
            .map { enrichTrackWithLocalCover($0) }
    }

    public func downloadedTracks(forPlaylistId playlistId: String) -> [Track] {
        records.values
            .filter { $0.playlistIds.contains(playlistId) }
            .sorted(by: { $0.downloadedAt < $1.downloadedAt })
            .map { enrichTrackWithLocalCover($0) }
    }

    public func downloadedPlaylistMeta(forPlaylistId playlistId: String) -> OfflinePlaylistMeta? {
        playlistMetas[playlistId]
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
        if isDownloaded(trackId: track.id) {
            if let pid = playlistId, var record = records[track.id], !record.playlistIds.contains(pid) {
                record.playlistIds.append(pid)
                records[track.id] = record
                saveManifest()
            }
            if localCoverFileURL(for: track.id) == nil {
                _ = await ensureCoverSavedForRecord(trackId: track.id, preferredCoverUrl: track.coverUrl, serverURL: serverURL, token: token)
            }
            return true
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

        var downloadedData: Data? = nil
        var detectedMime: String? = nil

        for cand in candidates {
            var req = URLRequest(url: cand)
            req.httpMethod = "GET"
            if let tok = token, !tok.isEmpty {
                req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
                req.setValue(tok, forHTTPHeaderField: "x-session-token")
            }

            do {
                downloadProgressMap[track.id] = 0.25
                let (data, response) = try await downloadSession.data(for: req)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), data.count > 10240 {
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

            // Mehrstufige Cover-Speicherung (Cache -> Authenticated URL -> Embedded Artwork -> Discovery Search)
            let localCoverName = await fetchAndPersistCover(
                track: track,
                safeTrackId: safeTrackId,
                audioFileURL: targetFileURL,
                serverURL: base,
                token: token
            )

            let size = Int64(validData.count)
            var pIds: [String] = []
            if let pid = playlistId { pIds.append(pid) }

            let record = OfflineTrackRecord(
                track: track,
                localFileName: fileName,
                localCoverFileName: localCoverName,
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
        playlistMetas[playlistId] = OfflinePlaylistMeta(
            id: playlistId,
            name: name,
            coverUrl: coverUrl,
            downloadedAt: Date()
        )
        savePlaylistMetas()

        Task {
            for track in tracks {
                _ = await downloadTrack(track: track, serverURL: serverURL, token: token, playlistId: playlistId)
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
        let safeId = trackId
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "&", with: "_")
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

        records.removeValue(forKey: trackId)
        downloadedTrackIds.remove(trackId)
        saveManifest()
    }

    public func removeAllDownloads() {
        try? FileManager.default.removeItem(at: tracksDirectoryURL)
        try? FileManager.default.removeItem(at: coversDirectoryURL)
        try? FileManager.default.removeItem(at: manifestFileURL)
        try? FileManager.default.removeItem(at: playlistsMetaFileURL)

        records.removeAll()
        playlistMetas.removeAll()
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
