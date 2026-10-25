//
//  AudioCache.swift
//  octave
//

import Foundation

final class AudioCache: @unchecked Sendable {
    static let shared = AudioCache()
    private let cacheDir: URL

    init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDir = paths[0].appendingPathComponent("OctaveAudioCache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func cachedURL(for trackId: String) -> URL? {
        let file = cacheDir.appendingPathComponent("\(trackId).m4a")
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }
}
