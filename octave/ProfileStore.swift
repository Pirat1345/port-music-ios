//
//  ProfileStore.swift
//  octave
//

import Foundation
import Observation

@Observable
final class ProfileStore: @unchecked Sendable {
    static let shared = ProfileStore()
    var bio: String = ""
    var favoriteArtists: [String] = []
}
