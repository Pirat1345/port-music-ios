//
//  PlaylistDetailView.swift
//  Port Music
//
//  Rich playlist tracklist view for user playlists and online discovery playlists.
//

import SwiftUI

struct PlaylistDetailView: View {
    let playlistId: String
    let title: String
    var description: String? = nil
    var coverURL: String? = nil
    var isUserPlaylist: Bool = false

    @Environment(AudioPlayer.self) private var player
    @State private var tracks: [SongEntity] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color.portBackground
                .ignoresSafeArea()

            if isLoading {
                ProgressView("Playlist wird geladen...")
                    .tint(.portBrand)
                    .foregroundColor(.portTextSecondary)
            } else if let err = errorMessage, tracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(err)
                        .foregroundColor(.portTextSecondary)
                    Button("Erneut versuchen") {
                        Task { await loadTracks() }
                    }
                    .foregroundColor(.portBrand)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Artwork & Metadata
                        HStack(spacing: 16) {
                            ArtworkView(urlString: coverURL)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.portBorder, lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.5), radius: 10, y: 4)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .lineLimit(2)

                                if let desc = description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.portTextSecondary)
                                        .lineLimit(2)
                                }

                                Text("\(tracks.count) Titel")
                                    .font(.caption2)
                                    .foregroundColor(.portTextMuted)

                                Spacer()

                                if !tracks.isEmpty {
                                    Button {
                                        if let first = tracks.first {
                                            player.play(song: first, in: tracks)
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "play.fill")
                                                .font(.caption)
                                            Text("Abspielen")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.portBrand)
                                        .foregroundColor(.black)
                                        .cornerRadius(20)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Divider()
                            .background(Color.portBorder)
                            .padding(.horizontal, 16)

                        // Tracklist
                        if tracks.isEmpty {
                            VStack(spacing: 8) {
                                Text("Diese Playlist enthält noch keine Titel")
                                    .font(.subheadline)
                                    .foregroundColor(.portTextMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 4) {
                                ForEach(tracks) { song in
                                    TrackListRow(song: song) {
                                        player.play(song: song, in: tracks)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadTracks()
        }
    }

    private func loadTracks() async {
        isLoading = true
        errorMessage = nil
        do {
            if isUserPlaylist {
                let details = try await OctaveBackend.shared.fetchPlaylistDetails(id: playlistId)
                self.tracks = details.tracks.map { $0.toSongEntity() }
            } else {
                self.tracks = try await OctaveBackend.shared.fetchOnlinePlaylistTracks(id: playlistId)
            }
        } catch {
            self.errorMessage = "Titel konnten nicht geladen werden"
        }
        isLoading = false
    }
}
