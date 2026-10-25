//
//  ProfileStore.swift
//  octave
//

import Foundation
import Observation

@Observable
final class ProfileStore {
    static let shared = ProfileStore()
    var bio: String = ""
    var favoriteArtists: [String] = []
}
