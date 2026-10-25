//
//  OctaveAudioURL.swift
//  octave
//

import Foundation

struct OctaveAudioURL {
    static func resolve(trackId: String, quality: String = "320") -> URL {
        OctaveBackend.shared.streamURL(for: trackId, quality: quality)
    }
}
