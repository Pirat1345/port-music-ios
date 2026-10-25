//
//  PlaybackCommandBus.swift
//  octave
//

import Foundation

final class PlaybackCommandBus: @unchecked Sendable {
    static let shared = PlaybackCommandBus()
    func dispatchSkip() {}
    func dispatchToggle() {}
}
