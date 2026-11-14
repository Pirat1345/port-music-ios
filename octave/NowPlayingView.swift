//
//  NowPlayingView.swift
//  Port Music
//

import SwiftUI

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayer.self) private var player
    @Environment(LibraryIndex.self) private var libraryIndex
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
                        if let current = player.currentTrack {
                            let isFav = libraryIndex.isSaved(id: current.id)
                            Button {
                                Task { await libraryIndex.toggle(song: current) }
                            } label: {
                                Label(
                                    isFav ? "Aus Favoriten entfernen" : "Zu Favoriten hinzufügen",
                                    systemImage: isFav ? "heart.fill" : "heart"
                                )
                            }
                        }
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
                        guard let current = player.currentTrack else { return }
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        Task {
                            await libraryIndex.toggle(song: current)
                        }
                    } label: {
                        let isFav = player.currentTrack.map { libraryIndex.isSaved(id: $0.id) } ?? false
                        Image(systemName: isFav ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundColor(isFav ? Color(red: 252/255, green: 60/255, blue: 68/255) : .white.opacity(0.8))
                            .scaleEffect(isFav ? 1.08 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isFav)
                    }
                    .accessibilityLabel(
                        player.currentTrack.map { libraryIndex.isSaved(id: $0.id) } == true
                        ? "Aus Favoriten entfernen"
                        : "Zu Favoriten hinzufügen"
                    )
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
        .sheet(isPresented: $showQueue) {
            PlayerQueueSheet()
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct PlayerQueueSheet: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Warteschlange")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Fertig") {
                            dismiss()
                        }
                        .foregroundColor(.portBrand)
                    }
                }
        }
    }

    private var contentView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let current = player.currentTrack {
                        currentTrackView(current)
                    }

                    let upcoming = player.upcomingQueue
                    if !upcoming.isEmpty {
                        upcomingListView(upcoming: upcoming)
                    } else {
                        emptyQueueView
                    }
                }
                .padding(.vertical, 16)
            }
        }
    }

    private func currentTrackView(_ current: SongEntity) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aktueller Titel")
                .font(.headline)
                .foregroundColor(.portTextSecondary)
                .padding(.horizontal)

            TrackListRow(song: current) {
                dismiss()
            }
            .padding(.horizontal)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private func upcomingListView(upcoming: [SongEntity]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Als Nächstes (\(upcoming.count))")
                .font(.headline)
                .foregroundColor(.portTextSecondary)
                .padding(.horizontal)

            LazyVStack(spacing: 4) {
                ForEach(upcoming) { song in
                    TrackListRow(song: song) {
                        if let globalIdx = player.queue.firstIndex(where: { $0.id == song.id }) {
                            player.currentIndex = globalIdx
                            player.loadAndPlayCurrent()
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var emptyQueueView: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundColor(.portTextMuted)
            Text("Keine weiteren Titel in der Warteschlange")
                .font(.subheadline)
                .foregroundColor(.portTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
