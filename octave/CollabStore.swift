//
//  CollabStore.swift
//  octave
//

import Foundation
import Observation

@Observable
final class CollabStore {
    static let shared = CollabStore()
    var playlists: [String] = []
    var loading: Bool = false
    var error: String?
    var accountKey: String?
}
