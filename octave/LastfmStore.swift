//
//  LastfmStore.swift
//  octave
//

import Foundation
import Observation

@Observable
final class LastfmStore: @unchecked Sendable {
    static let shared = LastfmStore()
    var isConnected: Bool = false
    var username: String? = nil

    func scrobble(song: SongEntity) {}
}
