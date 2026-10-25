//
//  PlaybackCommandBus.swift
//  octave
//

import Foundation

final class PlaybackCommandBus {
    static let shared = PlaybackCommandBus()
    func dispatchSkip() {}
    func dispatchToggle() {}
}
