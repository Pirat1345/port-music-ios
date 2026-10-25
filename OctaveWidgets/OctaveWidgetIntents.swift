//
//  OctaveWidgetIntents.swift
//  OctaveWidgets
//
//  App Intents extracted from OctaveWidgetsExtension.appex
//

import AppIntents
import Foundation

struct TogglePlayPauseIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Toggle Play / Pause"
    static let description = IntentDescription("Play or pause the current playback in Octave")

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.streaming.octave.dev")
        let isPlaying = defaults?.bool(forKey: "octave.isPlaying") ?? false
        defaults?.set(!isPlaying, forKey: "octave.isPlaying")
        return .result()
    }
}

struct NextTrackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Next Track"
    static let description = IntentDescription("Skip to the next song in the queue")

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.streaming.octave.dev")
        defaults?.set(Date().timeIntervalSince1970, forKey: "octave.intent.next")
        return .result()
    }
}

struct PreviousTrackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Previous Track"
    static let description = IntentDescription("Go back to the previous track or restart current")

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.streaming.octave.dev")
        defaults?.set(Date().timeIntervalSince1970, forKey: "octave.intent.prev")
        return .result()
    }
}

struct PauseIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Pause"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.streaming.octave.dev")
        defaults?.set(false, forKey: "octave.isPlaying")
        return .result()
    }
}

struct ResumeIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Resume"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.streaming.octave.dev")
        defaults?.set(true, forKey: "octave.isPlaying")
        return .result()
    }
}

struct ToggleLikeIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Like"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.streaming.octave.dev")
        let liked = defaults?.bool(forKey: "octave.isCurrentLiked") ?? false
        defaults?.set(!liked, forKey: "octave.isCurrentLiked")
        return .result()
    }
}

struct PlayLikedSongsIntent: AppIntent {
    static let title: LocalizedStringResource = "Play Liked Songs"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.streaming.octave.dev")
        defaults?.set("liked_songs", forKey: "octave.intent.playCollection")
        return .result()
    }
}

struct PlayRecommendationsIntent: AppIntent {
    static let title: LocalizedStringResource = "Play Recommendations"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.streaming.octave.dev")
        defaults?.set("recommendations", forKey: "octave.intent.playCollection")
        return .result()
    }
}

struct PlayTrackIntent: AppIntent {
    static let title: LocalizedStringResource = "Play Track"

    @Parameter(title: "Track ID")
    var trackId: String

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.streaming.octave.dev")
        defaults?.set(trackId, forKey: "octave.intent.playTrackId")
        return .result()
    }
}

struct ShuffleLibraryIntent: AppIntent {
    static let title: LocalizedStringResource = "Shuffle Library"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.streaming.octave.dev")
        defaults?.set(true, forKey: "octave.intent.shuffleLibrary")
        return .result()
    }
}

struct ToggleShuffleIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Shuffle"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.streaming.octave.dev")
        let shuffled = defaults?.bool(forKey: "octave.isShuffled") ?? false
        defaults?.set(!shuffled, forKey: "octave.isShuffled")
        return .result()
    }
}

struct PlayOnRepeatIntent: AppIntent {
    static let title: LocalizedStringResource = "Play On Repeat"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.streaming.octave.dev")
        defaults?.set(true, forKey: "octave.isRepeat")
        return .result()
    }
}

struct SetPlayingIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Playing"

    @Parameter(title: "Playing")
    var isPlaying: Bool

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.streaming.octave.dev")
        defaults?.set(isPlaying, forKey: "octave.isPlaying")
        return .result()
    }
}
