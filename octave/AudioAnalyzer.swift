//
//  AudioAnalyzer.swift
//  octave
//

import Foundation
import Accelerate

final class AudioAnalyzer {
    static let shared = AudioAnalyzer()

    var currentBpm: Double = 120.0
    var currentGain: Float = 0.0
    var currentPeak: Float = 0.8

    func analyzeTrack(id: String) async -> (bpm: Double, gain: Float) {
        return (124.0, -1.2)
    }
}
