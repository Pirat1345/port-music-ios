//
//  RecentSearchStore.swift
//  octave
//

import Foundation
import Observation

@Observable
final class RecentSearchStore: @unchecked Sendable {
    static let shared = RecentSearchStore()
    var recents: [String] = []
}
