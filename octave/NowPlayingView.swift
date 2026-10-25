//
//  NowPlayingView.swift
//  octave
//

import SwiftUI

struct NowPlayingView: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(ThemeEngine.self) private var theme
    @State private var presenter = NowPlayingPresenter()
    @State private var showLyrics: Bool = false
    @State private var showQueue: Bool = false

    var body: some View {
        ZStack {
            // Metal backdrop or dark gradient
            NPMetalBackdropView()
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Top Grabber & Controls
                HStack {
                    Button {
                        // Dismiss
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    Text(player.currentTrack?.albumTitle ?? "Playing")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                    Spacer()
                    Menu {
                        Button("View Album", action: {})
                        Button("View Artist", action: {})
                        Button("Share Song", action: {})
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Artwork Bed
                NPArtworkBed(song: player.currentTrack)
                    .frame(width: 320, height: 320)
                    .shadow(color: .black.opacity(0.5), radius: 25, x: 0, y: 15)

                Spacer()

                // Song Title & Artist
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.currentTrack?.title ?? "No Track")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(player.currentTrack?.artist ?? "Octave")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        // Toggle favorite
                    } label: {
                        Image(systemName: "heart")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 24)

                // Scrubber Slider
                VStack(spacing: 6) {
                    Slider(value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ), in: 0...max(player.duration, 1.0))
                    .tint(.white)

                    HStack {
                        Text(formatTime(player.currentTime))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("-" + formatTime(max(0, player.duration - player.currentTime)))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 24)

                // Playback Controls
                HStack(spacing: 40) {
                    Button {
                        player.previous()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }

                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }

                    Button {
                        player.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .padding(.vertical, 8)

                // Bottom Action Bar: Lyrics, AirPlay, Queue
                HStack {
                    Button {
                        showLyrics.toggle()
                    } label: {
                        Image(systemName: "quote.bubble")
                            .font(.title3)
                            .foregroundColor(showLyrics ? .white : .white.opacity(0.6))
                    }

                    Spacer()

                    Button {
                        // Airplay route
                    } label: {
                        Image(systemName: "airplayaudio")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    Button {
                        showQueue.toggle()
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .foregroundColor(showQueue ? .white : .white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showLyrics) {
            LyricsView()
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
