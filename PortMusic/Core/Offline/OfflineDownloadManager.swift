import Foundation
import SwiftUI
import Combine

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

@MainActor
public final class OfflineDownloadManager: ObservableObject {
    public static let shared = OfflineDownloadManager()

    @Published public private(set) var downloadedTrackIds: Set<String> = []
    @Published public private(set) var downloadingTrackIds: Set<String> = []
    @Published public private(set) var downloadProgressMap: [String: Double] = [:]

    private var records: [String: OfflineTrackRecord] = [:]
    private let manifestFileName = "offline_manifest.json"
    private let tracksSubdir = "OfflineTracks"
    private let coversSubdir = "OfflineCovers"

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

    private init() {
        loadManifest()
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

        // Bereinige Einträge, deren Datei auf der Festplatte fehlt
        var validRecords: [String: OfflineTrackRecord] = [:]
        for (id, record) in decoded {
            let fileURL = tracksDirectoryURL.appendingPathComponent(record.localFileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                validRecords[id] = record
            }
        }

        self.records = validRecords
        self.downloadedTrackIds = Set(validRecords.keys)
    }

    private func saveManifest() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: manifestFileURL, options: .atomic)
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

    public func allDownloadedTracks() -> [Track] {
        records.values
            .sorted(by: { $0.downloadedAt > $1.downloadedAt })
            .map { $0.track }
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
            return true
        }

        if isDownloading(trackId: track.id) {
            return false
        }

        downloadingTrackIds.insert(track.id)
        downloadProgressMap[track.id] = 0.05

        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let safeTrackId = track.id.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        let fileName = "\(safeTrackId).m4a"
        let targetFileURL = tracksDirectoryURL.appendingPathComponent(fileName)

        // URL-Kandidaten zur Audiogewinnung (exakt wie im Web)
        var candidates: [URL] = []
        let encodedId = track.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? track.id
        if let u1 = URL(string: "\(base)/api/tracks/\(encodedId)/download") { candidates.pushCandidate(u1) }
        if let u2 = URL(string: "\(base)/api/stream/\(encodedId)") { candidates.pushCandidate(u2) }
        if let u3 = URL(string: "\(base)/audio/320/\(encodedId)") { candidates.pushCandidate(u3) }
        if let sf = track.sourceFileId, !sf.isEmpty, let u4 = URL(string: "\(base)/api/files/\(sf)") { candidates.pushCandidate(u4) }

        var downloadedData: Data? = nil
        let session = URLSession.shared

        for cand in candidates {
            var req = URLRequest(url: cand)
            req.httpMethod = "GET"
            if let tok = token, !tok.isEmpty {
                req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            }

            do {
                downloadProgressMap[track.id] = 0.20
                let (data, response) = try await session.data(for: req)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), data.count > 10240 {
                    downloadedData = data
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

        downloadProgressMap[track.id] = 0.85

        // Speichern auf Flash-Speicher
        do {
            try validData.write(to: targetFileURL, options: .atomic)

            // Optional Cover laden & lokal speichern
            var localCoverName: String? = nil
            if let coverStr = track.cover, let coverURL = URL(string: coverStr), !coverStr.isEmpty {
                if let (coverData, _) = try? await session.data(from: coverURL), !coverData.isEmpty {
                    let coverFileName = "\(safeTrackId).jpg"
                    let coverTargetURL = coversDirectoryURL.appendingPathComponent(coverFileName)
                    try? coverData.write(to: coverTargetURL, options: .atomic)
                    localCoverName = coverFileName
                }
            }

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

    public func downloadPlaylist(playlistId: String, name: String, tracks: [Track], serverURL: String, token: String?) {
        Task {
            for track in tracks {
                _ = await downloadTrack(track: track, serverURL: serverURL, token: token, playlistId: playlistId)
            }
        }
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

        records.removeAll()
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
