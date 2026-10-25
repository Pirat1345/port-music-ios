//
//  AudioSchemaIntents.swift
//  octave
//

import AppIntents

struct PlayAudioSiriIntent: AppIntent {
    static let title: LocalizedStringResource = "Play Music on Port Music"

    func perform() async throws -> some IntentResult {
        AudioPlayer.shared.resume()
        return .result()
    }
}


//
//  SongEntity.swift
//  octave
//

import Foundation

public struct SongEntity: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var artist: String
    public var artworkURLString: String?
    public var albumTitle: String?
    public var albumId: String?
    public var artistId: String?
    public var durationSec: Double

    public init(
        id: String,
        title: String,
        artist: String,
        artworkURLString: String? = nil,
        albumTitle: String? = nil,
        albumId: String? = nil,
        artistId: String? = nil,
        durationSec: Double = 0.0
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artworkURLString = artworkURLString
        self.albumTitle = albumTitle
        self.albumId = albumId
        self.artistId = artistId
        self.durationSec = durationSec
    }
}
