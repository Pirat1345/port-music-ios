//
//  OctaveWidgets.swift
//  OctaveWidgets
//
//  Now Playing and Interactive Music Widgets
//

import WidgetKit
import SwiftUI
import AppIntents

struct OctaveWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let artist: String
    let album: String
    let artworkURLString: String?
    let isPlaying: Bool
    let isLiked: Bool
}

struct OctaveWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> OctaveWidgetEntry {
        OctaveWidgetEntry(
            date: Date(),
            title: "Port Music Streaming",
            artist: "High-Fidelity Audio",
            album: "Spatial Sound",
            artworkURLString: nil,
            isPlaying: true,
            isLiked: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (OctaveWidgetEntry) -> Void) {
        completion(fetchCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OctaveWidgetEntry>) -> Void) {
        let entry = fetchCurrentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchCurrentEntry() -> OctaveWidgetEntry {
        let defaults = UserDefaults(suiteName: "group.streaming.portmusic.app") ?? UserDefaults(suiteName: "group.streaming.octave.dev")
        let title = defaults?.string(forKey: "portmusic.nowPlaying.title") ?? defaults?.string(forKey: "octave.nowPlaying.title") ?? "No Music Playing"
        let artist = defaults?.string(forKey: "portmusic.nowPlaying.artist") ?? defaults?.string(forKey: "octave.nowPlaying.artist") ?? "Port Music"
        let album = defaults?.string(forKey: "portmusic.nowPlaying.album") ?? defaults?.string(forKey: "octave.nowPlaying.album") ?? "Tap to start"
        let art = defaults?.string(forKey: "portmusic.nowPlaying.artwork") ?? defaults?.string(forKey: "octave.nowPlaying.artwork")
        let isPlaying = defaults?.bool(forKey: "portmusic.isPlaying") ?? defaults?.bool(forKey: "octave.isPlaying") ?? false
        let isLiked = defaults?.bool(forKey: "portmusic.isCurrentLiked") ?? defaults?.bool(forKey: "octave.isCurrentLiked") ?? false

        return OctaveWidgetEntry(
            date: Date(),
            title: title,
            artist: artist,
            album: album,
            artworkURLString: art,
            isPlaying: isPlaying,
            isLiked: isLiked
        )
    }
}

struct OctaveNowPlayingWidgetView: View {
    var entry: OctaveWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color("WidgetBackground", bundle: nil))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.purple.opacity(0.3))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.title2)
                                .foregroundColor(Color("AccentColor", bundle: nil))
                        )
                        .frame(width: 50, height: 50)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                            .font(.headline)
                            .lineLimit(1)
                            .foregroundColor(.white)
                        Text(entry.artist)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    Spacer()
                }

                Spacer()

                HStack {
                    Button(intent: PreviousTrackIntent()) {
                        Image(systemName: "backward.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(intent: TogglePlayPauseIntent()) {
                        Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(intent: NextTrackIntent()) {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(intent: ToggleLikeIntent()) {
                        Image(systemName: entry.isLiked ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundColor(entry.isLiked ? .red : .white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
            .padding()
        }
    }
}

struct OctaveNowPlayingWidget: Widget {
    let kind: String = "streaming.octave.dev.OctaveNowPlaying"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OctaveWidgetProvider()) { entry in
            OctaveNowPlayingWidgetView(entry: entry)
        }
        .configurationDisplayName("Now Playing")
        .description("Control music and see the current playing track.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct OctaveQuickActionsWidget: Widget {
    let kind: String = "streaming.octave.dev.OctaveQuickActions"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OctaveWidgetProvider()) { entry in
            HStack(spacing: 12) {
                Button(intent: PlayLikedSongsIntent()) {
                    VStack {
                        Image(systemName: "heart.fill")
                            .font(.title)
                            .foregroundColor(.red)
                        Text("Liked Songs")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button(intent: PlayRecommendationsIntent()) {
                    VStack {
                        Image(systemName: "sparkles")
                            .font(.title)
                            .foregroundColor(.yellow)
                        Text("For You")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .containerBackground(for: .widget) {
                Color("WidgetBackground", bundle: nil)
            }
        }
        .configurationDisplayName("Quick Actions")
        .description("Jump straight to Liked Songs or Personalized Recs.")
        .supportedFamilies([.systemMedium])
    }
}
