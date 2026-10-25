//
//  EpisodeProgressStore.swift
//  octave
//

import Foundation
import Observation

@Observable
final class EpisodeProgressStore: @unchecked Sendable {
    static let shared = EpisodeProgressStore()
    var progressMap: [String: Double] = [:]
}
