//
//  RecentSearchStore.swift
//  octave
//

import Foundation
import Observation

@Observable
final class RecentSearchStore {
    static let shared = RecentSearchStore()
    var recents: [String] = []
}
