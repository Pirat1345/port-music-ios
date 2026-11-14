//
//  DownloadManager.swift
//  Port Music
//
//  Persistent offline download manager for audio tracks and playlists.
//

import Foundation
import Observation

// MARK: - Manifest Models

public struct DownloadedTrackRecord: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public var title: String
    public var artist: String
    public var albumTitle: String?
    public var artworkURLString: String?
    public var localAudioPath: String
    public var localArtworkPath: String?
    public var fileSize: Int64
    public var durationSec: Double
    public var downloadDate: String
    public var lyrics: String?
    public var playlistIds: [String]
    public var isSavedIndividually: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, artist, albumTitle, artworkURLString
        case localAudioPath, localArtworkPath, fileSize, durationSec
        case downloadDate, lyrics, playlistIds, isSavedIndividually
    }

    public init(
        id: String,
        title: String,
        artist: String,
        albumTitle: String? = nil,
        artworkURLString: String? = nil,
        localAudioPath: String,
        localArtworkPath: String? = nil,
        fileSize: Int64,
        durationSec: Double,
        downloadDate: String,
        lyrics: String? = nil,
        playlistIds: [String] = [],
        isSavedIndividually: Bool = true
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.artworkURLString = artworkURLString
        self.localAudioPath = localAudioPath
        self.localArtworkPath = localArtworkPath
        self.fileSize = fileSize
        self.durationSec = durationSec
        self.downloadDate = downloadDate
        self.lyrics = lyrics
        self.playlistIds = playlistIds
        self.isSavedIndividually = isSavedIndividually
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.artist = try container.decode(String.self, forKey: .artist)
        self.albumTitle = try container.decodeIfPresent(String.self, forKey: .albumTitle)
        self.artworkURLString = try container.decodeIfPresent(String.self, forKey: .artworkURLString)
        self.localAudioPath = try container.decode(String.self, forKey: .localAudioPath)
        self.localArtworkPath = try container.decodeIfPresent(String.self, forKey: .localArtworkPath)
        self.fileSize = try container.decode(Int64.self, forKey: .fileSize)
        self.durationSec = try container.decode(Double.self, forKey: .durationSec)
        self.downloadDate = try container.decode(String.self, forKey: .downloadDate)
        self.lyrics = try container.decodeIfPresent(String.self, forKey: .lyrics)
        self.playlistIds = try container.decodeIfPresent([String].self, forKey: .playlistIds) ?? []
        self.isSavedIndividually = try container.decodeIfPresent(Bool.self, forKey: .isSavedIndividually) ?? true
    }
}

public struct DownloadedPlaylistRecord: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public var title: String
    public var trackIds: [String]
    public var coverURL: String?
    public var localCoverFileName: String?
    public var downloadDate: String

    enum CodingKeys: String, CodingKey {
        case id, title, trackIds, coverURL, localCoverFileName, downloadDate
    }

    public init(
        id: String,
        title: String,
        trackIds: [String] = [],
        coverURL: String? = nil,
        localCoverFileName: String? = nil,
        downloadDate: String
    ) {
        self.id = id
        self.title = title
        self.trackIds = trackIds
        self.coverURL = coverURL
        self.localCoverFileName = localCoverFileName
        self.downloadDate = downloadDate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.trackIds = try container.decodeIfPresent([String].self, forKey: .trackIds) ?? []
        self.coverURL = try container.decodeIfPresent(String.self, forKey: .coverURL)
        self.localCoverFileName = try container.decodeIfPresent(String.self, forKey: .localCoverFileName)
        self.downloadDate = try container.decode(String.self, forKey: .downloadDate)
    }
}

public struct DownloadManifest: Codable, Sendable {
    public var version: Int = 1
    public var tracks: [DownloadedTrackRecord] = []
    public var playlists: [DownloadedPlaylistRecord] = []

    enum CodingKeys: String, CodingKey {
        case version, tracks, playlists
    }

    public init(version: Int = 1, tracks: [DownloadedTrackRecord] = [], playlists: [DownloadedPlaylistRecord] = []) {
        self.version = version
        self.tracks = tracks
        self.playlists = playlists
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.tracks = try container.decodeIfPresent([DownloadedTrackRecord].self, forKey: .tracks) ?? []
        self.playlists = try container.decodeIfPresent([DownloadedPlaylistRecord].self, forKey: .playlists) ?? []
    }
}

// MARK: - DownloadManager

@Observable
final class DownloadManager: @unchecked Sendable {
    static let shared = DownloadManager()

    // Reactive State
    var activeCount: Int = 0
    var smartDownloadsEnabled: Bool = true
    var downloadQuality: String = "320"
    var isExcludedFromBackup: Bool = true
    var downloadedTrackIds: Set<String> = []
    var downloadedTracks: [SongEntity] = []
    var downloadedPlaylists: [DownloadedPlaylistRecord] = []

    // Directory Paths
    private let fileManager = FileManager.default
    private let rootDirectory: URL
    private let tracksDirectory: URL
    private let artworkDirectory: URL
    private let manifestURL: URL
    private let lock = NSLock()

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = appSupport.appendingPathComponent("PortMusicDownloads", isDirectory: true)
        self.rootDirectory = root
        self.tracksDirectory = root.appendingPathComponent("tracks", isDirectory: true)
        self.artworkDirectory = root.appendingPathComponent("artwork", isDirectory: true)
        self.manifestURL = root.appendingPathComponent("manifest.json")

        setupDirectories()
        loadManifest()
    }

    // MARK: - Directory Setup & Backup Exclusion

    private func setupDirectories() {
        do {
            if !fileManager.fileExists(atPath: rootDirectory.path) {
                try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                var mutableRoot = rootDirectory
                try mutableRoot.setResourceValues(values)
            }
            if !fileManager.fileExists(atPath: tracksDirectory.path) {
                try fileManager.createDirectory(at: tracksDirectory, withIntermediateDirectories: true)
            }
            if !fileManager.fileExists(atPath: artworkDirectory.path) {
                try fileManager.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)
            }
        } catch {
            print("[DownloadManager] Fehler beim Erstellen der Download-Verzeichnisse: \(error.localizedDescription)")
        }
    }

    // MARK: - Manifest Persistence

    private func loadManifest() {
        lock.lock()
        defer { lock.unlock() }

        guard fileManager.fileExists(atPath: manifestURL.path),
              let data = try? Data(contentsOf: manifestURL) else {
            syncStateFromManifest(DownloadManifest(version: 1, tracks: [], playlists: []))
            return
        }

        do {
            let manifest = try JSONDecoder().decode(DownloadManifest.self, from: data)
            syncStateFromManifest(manifest)
        } catch {
            print("[DownloadManager] Korrupter Manifest-Zustand erkannt. Führe Wiederherstellung durch...")
            let emptyManifest = DownloadManifest(version: 1, tracks: [], playlists: [])
            saveManifestLocked(emptyManifest)
            syncStateFromManifest(emptyManifest)
        }
    }

    private func syncStateFromManifest(_ manifest: DownloadManifest) {
        var existingTrackIds = Set<String>()
        var validTracks: [SongEntity] = []

        for record in manifest.tracks {
            let audioFile = tracksDirectory.appendingPathComponent(sanitizeTrackFilename(record.id))
            if fileManager.fileExists(atPath: audioFile.path) {
                existingTrackIds.insert(record.id)
                validTracks.append(SongEntity(
                    id: record.id,
                    title: record.title,
                    artist: record.artist,
                    artworkURLString: record.artworkURLString,
                    albumTitle: record.albumTitle,
                    albumId: nil,
                    artistId: nil,
                    durationSec: record.durationSec
                ))
            }
        }

        let playlists = manifest.playlists

        if Thread.isMainThread {
            self.downloadedTrackIds = existingTrackIds
            self.downloadedTracks = validTracks
            self.downloadedPlaylists = playlists
        } else {
            DispatchQueue.main.async {
                self.downloadedTrackIds = existingTrackIds
                self.downloadedTracks = validTracks
                self.downloadedPlaylists = playlists
            }
        }
    }

    private func saveManifestLocked(_ manifest: DownloadManifest) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(manifest)
            try data.write(to: manifestURL, options: .atomic)
        } catch {
            print("[DownloadManager] Fehler beim Speichern des Manifests: \(error.localizedDescription)")
        }
    }

    private func currentManifestLocked() -> DownloadManifest {
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(DownloadManifest.self, from: data) else {
            return DownloadManifest(version: 1, tracks: [], playlists: [])
        }
        return manifest
    }

    // MARK: - Public Queries

    func isDownloaded(id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let audioFile = tracksDirectory.appendingPathComponent(sanitizeTrackFilename(id))
        return fileManager.fileExists(atPath: audioFile.path) && downloadedTrackIds.contains(id)
    }

    func isPlaylistDownloaded(playlistId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let manifest = currentManifestLocked()
        return manifest.playlists.contains(where: { $0.id == playlistId })
    }

    func localFileURL(for trackId: String) -> URL? {
        let fileURL = tracksDirectory.appendingPathComponent(sanitizeTrackFilename(trackId))
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return fileURL
    }

    func localArtworkURL(for trackId: String) -> URL? {
        let artworkURL = artworkDirectory.appendingPathComponent(sanitizeArtworkFilename(trackId))
        guard fileManager.fileExists(atPath: artworkURL.path) else {
            return nil
        }
        return artworkURL
    }

    func tracksForPlaylist(id: String) -> [SongEntity]? {
        lock.lock()
        defer { lock.unlock() }
        let manifest = currentManifestLocked()

        if let pl = manifest.playlists.first(where: { $0.id == id }) {
            let trackDict = Dictionary(uniqueKeysWithValues: manifest.tracks.map { ($0.id, $0) })
            let matched = pl.trackIds.compactMap { trackDict[$0] }
            let entities = matched.map { record in
                SongEntity(
                    id: record.id,
                    title: record.title,
                    artist: record.artist,
                    artworkURLString: record.artworkURLString,
                    albumTitle: record.albumTitle,
                    albumId: nil,
                    artistId: nil,
                    durationSec: record.durationSec
                )
            }
            return entities.isEmpty ? nil : entities
        }

        let matchedTracks = manifest.tracks.filter { $0.playlistIds.contains(id) }
        if !matchedTracks.isEmpty {
            return matchedTracks.map { record in
                SongEntity(
                    id: record.id,
                    title: record.title,
                    artist: record.artist,
                    artworkURLString: record.artworkURLString,
                    albumTitle: record.albumTitle,
                    albumId: nil,
                    artistId: nil,
                    durationSec: record.durationSec
                )
            }
        }

        return nil
    }

    var totalStorageBytes: Int64 {
        lock.lock()
        defer { lock.unlock() }
        let manifest = currentManifestLocked()
        return manifest.tracks.reduce(0) { $0 + $1.fileSize }
    }

    // MARK: - Sanitization Helpers

    private func sanitizeTrackFilename(_ trackId: String) -> String {
        guard !trackId.trimmingCharacters(in: .whitespaces).isEmpty else { return "track.m4a" }
        var sanitized = trackId
            .replacingOccurrences(of: "\0", with: "")
            .replacingOccurrences(of: "..", with: "__")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let scalars = sanitized.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        sanitized = String(scalars)
        return "\(sanitized.isEmpty ? "track" : sanitized).m4a"
    }

    private func sanitizeArtworkFilename(_ trackId: String) -> String {
        let trackName = sanitizeTrackFilename(trackId)
        return trackName.replacingOccurrences(of: ".m4a", with: ".jpg")
    }

    // MARK: - Download Execution

    func download(song: SongEntity, playlistId: String? = nil, savedIndividually: Bool = true) async throws {
        // Speicherplatzüberprüfung
        let estimatedBytes: Int64 = 10 * 1024 * 1024
        if let attrs = try? fileManager.attributesOfFileSystem(forPath: rootDirectory.path),
           let freeSpace = attrs[.systemFreeSize] as? Int64,
           freeSpace < estimatedBytes {
            throw NSError(domain: "DownloadManager", code: 507, userInfo: [
                NSLocalizedDescriptionKey: "Nicht genügend freier Speicherplatz für den Download verfügbar."
            ])
        }

        await MainActor.run { activeCount += 1 }
        defer {
            Task { @MainActor in activeCount = max(0, activeCount - 1) }
        }

        let audioFileName = sanitizeTrackFilename(song.id)
        let tempAudioURL = tracksDirectory.appendingPathComponent("\(audioFileName).tmp")
        let targetAudioURL = tracksDirectory.appendingPathComponent(audioFileName)

        let artworkFileName = sanitizeArtworkFilename(song.id)
        let targetArtworkURL = artworkDirectory.appendingPathComponent(artworkFileName)

        // 1. Audio Download via URLSession
        let streamURL = OctaveBackend.shared.streamURL(for: song.id, quality: downloadQuality)
        var req = URLRequest(url: streamURL)
        OctaveBackend.shared.applyAuth(to: &req)

        do {
            if fileManager.fileExists(atPath: tempAudioURL.path) {
                try? fileManager.removeItem(at: tempAudioURL)
            }

            let (tempDownloadedURL, response) = try await URLSession.shared.download(for: req)

            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode >= 400 {
                throw NSError(domain: "DownloadManager", code: httpRes.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Download fehlgeschlagen mit Statuscode \(httpRes.statusCode)."
                ])
            }

            try fileManager.moveItem(at: tempDownloadedURL, to: tempAudioURL)

            if fileManager.fileExists(atPath: targetAudioURL.path) {
                try fileManager.removeItem(at: targetAudioURL)
            }
            try fileManager.moveItem(at: tempAudioURL, to: targetAudioURL)

            let fileSize = (try? fileManager.attributesOfItem(atPath: targetAudioURL.path)[.size] as? Int64) ?? 0

            // 2. Artwork Download (optional / best-effort)
            var localArtworkRelPath: String? = nil
            if let artURLStr = song.artworkURLString, !artURLStr.isEmpty {
                let fullArtURL: URL?
                if artURLStr.hasPrefix("http://") || artURLStr.hasPrefix("https://") {
                    fullArtURL = URL(string: artURLStr)
                } else {
                    let base = OctaveBackend.shared.serverBaseURLString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    let path = artURLStr.hasPrefix("/") ? artURLStr : "/\(artURLStr)"
                    fullArtURL = URL(string: "\(base)\(path)")
                }

                if let validArtURL = fullArtURL {
                    var artReq = URLRequest(url: validArtURL)
                    OctaveBackend.shared.applyAuth(to: &artReq)
                    if let (artData, _) = try? await URLSession.shared.data(for: artReq) {
                        try? artData.write(to: targetArtworkURL)
                        localArtworkRelPath = "PortMusicDownloads/artwork/\(artworkFileName)"
                    }
                }
            }

            // 3. Manifest aktualisieren
            recordDownloadedTrack(
                song: song,
                playlistId: playlistId,
                savedIndividually: savedIndividually,
                audioFileName: audioFileName,
                localArtworkRelPath: localArtworkRelPath,
                fileSize: fileSize
            )

        } catch {
            if fileManager.fileExists(atPath: tempAudioURL.path) {
                try? fileManager.removeItem(at: tempAudioURL)
            }
            throw error
        }
    }

    private func recordDownloadedTrack(
        song: SongEntity,
        playlistId: String?,
        savedIndividually: Bool,
        audioFileName: String,
        localArtworkRelPath: String?,
        fileSize: Int64
    ) {
        lock.lock()
        defer { lock.unlock() }
        var manifest = currentManifestLocked()
        let nowStr = ISO8601DateFormatter().string(from: Date())

        if let idx = manifest.tracks.firstIndex(where: { $0.id == song.id }) {
            var existing = manifest.tracks[idx]
            var playlists = Set(existing.playlistIds)
            if let pid = playlistId { playlists.insert(pid) }
            existing.playlistIds = Array(playlists)
            existing.isSavedIndividually = savedIndividually || existing.isSavedIndividually
            existing.fileSize = fileSize
            existing.durationSec = song.durationSec > 0 ? song.durationSec : existing.durationSec
            manifest.tracks[idx] = existing
        } else {
            let record = DownloadedTrackRecord(
                id: song.id,
                title: song.title,
                artist: song.artist,
                albumTitle: song.albumTitle,
                artworkURLString: song.artworkURLString,
                localAudioPath: "PortMusicDownloads/tracks/\(audioFileName)",
                localArtworkPath: localArtworkRelPath,
                fileSize: fileSize,
                durationSec: song.durationSec,
                downloadDate: nowStr,
                lyrics: nil,
                playlistIds: playlistId != nil ? [playlistId!] : [],
                isSavedIndividually: savedIndividually
            )
            manifest.tracks.append(record)
        }

        saveManifestLocked(manifest)
        syncStateFromManifest(manifest)
    }

    func downloadPlaylist(playlist: PlaylistRecord, tracks: [SongEntity]) async throws {
        for track in tracks {
            try await download(song: track, playlistId: playlist.id, savedIndividually: false)
        }
        recordDownloadedPlaylist(playlist: playlist, trackIds: tracks.map { $0.id })
    }

    private func recordDownloadedPlaylist(playlist: PlaylistRecord, trackIds: [String]) {
        lock.lock()
        defer { lock.unlock() }
        var manifest = currentManifestLocked()
        let nowStr = ISO8601DateFormatter().string(from: Date())
        let plRecord = DownloadedPlaylistRecord(
            id: playlist.id,
            title: playlist.title,
            trackIds: trackIds,
            coverURL: playlist.cover_url,
            localCoverFileName: nil,
            downloadDate: nowStr
        )
        if let idx = manifest.playlists.firstIndex(where: { $0.id == playlist.id }) {
            manifest.playlists[idx] = plRecord
        } else {
            manifest.playlists.append(plRecord)
        }
        saveManifestLocked(manifest)
        syncStateFromManifest(manifest)
    }

    // MARK: - Deletion & Storage Purge

    func removeDownload(trackId: String) {
        lock.lock()
        var manifest = currentManifestLocked()
        manifest.tracks.removeAll(where: { $0.id == trackId })

        let audioFile = tracksDirectory.appendingPathComponent(sanitizeTrackFilename(trackId))
        let artworkFile = artworkDirectory.appendingPathComponent(sanitizeArtworkFilename(trackId))
        try? fileManager.removeItem(at: audioFile)
        try? fileManager.removeItem(at: artworkFile)

        saveManifestLocked(manifest)
        syncStateFromManifest(manifest)
        lock.unlock()
    }

    func removePlaylistDownload(playlistId: String) {
        lock.lock()
        var manifest = currentManifestLocked()
        manifest.playlists.removeAll(where: { $0.id == playlistId })

        var nextTracks: [DownloadedTrackRecord] = []
        for var track in manifest.tracks {
            track.playlistIds.removeAll(where: { $0 == playlistId })
            if !track.isSavedIndividually && track.playlistIds.isEmpty {
                let audioFile = tracksDirectory.appendingPathComponent(sanitizeTrackFilename(track.id))
                let artworkFile = artworkDirectory.appendingPathComponent(sanitizeArtworkFilename(track.id))
                try? fileManager.removeItem(at: audioFile)
                try? fileManager.removeItem(at: artworkFile)
            } else {
                nextTracks.append(track)
            }
        }
        manifest.tracks = nextTracks

        saveManifestLocked(manifest)
        syncStateFromManifest(manifest)
        lock.unlock()
    }

    func clearAllDownloads() {
        lock.lock()
        let emptyManifest = DownloadManifest(version: 1, tracks: [], playlists: [])
        try? fileManager.removeItem(at: tracksDirectory)
        try? fileManager.removeItem(at: artworkDirectory)
        try? fileManager.createDirectory(at: tracksDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)

        saveManifestLocked(emptyManifest)
        syncStateFromManifest(emptyManifest)
        lock.unlock()
    }
}
