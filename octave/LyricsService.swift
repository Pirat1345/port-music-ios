//
//  LyricsService.swift
//  octave
//

import Foundation

public struct LyricLine: Identifiable, Sendable {
    public var id = UUID()
    public var time: Double
    public var text: String
    public var translation: String?
}

final class LyricsService: @unchecked Sendable {
    static let shared = LyricsService()

    func fetchLyrics(for trackId: String) async -> [LyricLine] {
        // Return structured lyrics
        return [
            LyricLine(time: 0.0, text: "♪ (Instrumental Intro) ♪"),
            LyricLine(time: 14.5, text: "Welcome to the Octave stream"),
            LyricLine(time: 19.0, text: "Crystal clear sound in your ears"),
            LyricLine(time: 24.2, text: "Feel the bass move through your veins"),
            LyricLine(time: 30.0, text: "Music flowing without limits"),
            LyricLine(time: 36.4, text: "Every beat, every note in sync"),
            LyricLine(time: 42.0, text: "Enjoy high-fidelity sound")
        ]
    }
}
