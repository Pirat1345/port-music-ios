//
//  SpectrumEngine.swift
//  octave
//

import Foundation
import Observation

@Observable
final class SpectrumEngine {
    static let shared = SpectrumEngine()
    var bands: [Float] = Array(repeating: 0.1, count: 16)
    var power: Float = 0.5
}
