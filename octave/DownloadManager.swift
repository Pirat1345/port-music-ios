//
//  DownloadManager.swift
//  octave
//

import Foundation
import Observation

@Observable
final class DownloadManager {
    static let shared = DownloadManager()

    var activeCount: Int = 0
    var smartDownloadsEnabled: Bool = true
    var downloadQuality: String = "320"

    func download(song: SongEntity) {
        print("Downloading song: \(song.title)")
    }

    func isDownloaded(id: String) -> Bool {
        return false
    }
}
