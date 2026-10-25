//
//  NeuroVectorize.swift
//  octave
//

import Foundation

final class NeuroVectorize {
    static func embed(features: [Double]) -> [Float] {
        features.map { Float($0) }
    }
}
