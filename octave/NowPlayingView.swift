//
//  NowPlayingView.swift
//  Port Music
//

import SwiftUI

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayer.self) private var player
    @Environment(ThemeEngine.self) private var theme
    @State private var presenter = NowPlayingPresenter()
    @State private var showLyrics: Bool = false
    @State private var showQueue: Bool = false

    var body: some View {
        ZStack {
            // Calm Dark Background
            Color.portBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Top Grabber & Controls
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    Text(player.currentTrack?.albumTitle ?? "Aktuelle Wiedergabe")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                    Spacer()
                    Menu {
                        Button("Titel teilen", action: {})
                        Button("Zur Playlist hinzufügen", action: {})
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Artwork Bed
                if let song = player.currentTrack {
                    ArtworkView(urlString: song.artworkURLString)
                        .frame(width: 320, height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.portBorder, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.6), radius: 25, x: 0, y: 15)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.portSurfaceElevated)
                        .frame(width: 320, height: 320)
                }

                Spacer()

                // Song Title & Artist
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.currentTrack?.title ?? "Kein Titel ausgewählt")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(player.currentTrack?.artist ?? "Port Music")
                            .font(.title3)
                            .foregroundColor(.portTextSecondary)
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
                    .tint(.portBrand)

                    HStack {
                        Text(formatTime(player.currentTime))
                            .font(.caption)
                            .foregroundColor(.portTextMuted)
                        Spacer()
                        Text("-" + formatTime(max(0, player.duration - player.currentTime)))
                            .font(.caption)
                            .foregroundColor(.portTextMuted)
                    }
                }
                .padding(.horizontal, 24)

                // Playback Controls
                HStack(spacing: 36) {
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
                        ZStack {
                            Circle()
                                .fill(Color.portBrand)
                                .frame(width: 68, height: 68)
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.black)
                        }
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
                            .foregroundColor(showLyrics ? .portBrand : .white.opacity(0.6))
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
                            .foregroundColor(showQueue ? .portBrand : .white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 28)
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
