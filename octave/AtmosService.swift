//
//  AtmosService.swift
//  octave
//

import Foundation

final class AtmosService: @unchecked Sendable {
    static let shared = AtmosService()
    var isAtmosAvailable: Bool = true
    var preferenceEnabled: Bool = true

    func probeAtmos(trackId: String) async -> Bool {
        return true
    }
}
