//
//  AlbumDetailView.swift
//  Port Music
//
//  Album detail view fetching real album tracklist from backend discovery.
//

import SwiftUI

struct AlbumDetailView: View {
    let albumId: String
    let albumTitle: String
    let artist: String
    let artworkURL: String?

    @Environment(AudioPlayer.self) private var player
    @State private var tracks: [SongEntity] = []
    @State private var isLoading: Bool = true

    private var isAlbumDownloaded: Bool {
        !tracks.isEmpty && tracks.allSatisfy { DownloadManager.shared.isDownloaded(id: $0.id) }
    }

    var body: some View {
        ZStack {
            Color.portBackground
                .ignoresSafeArea()

            if isLoading {
                ProgressView("Album wird geladen...")
                    .tint(.portBrand)
                    .foregroundColor(.portTextSecondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Album Header
                        HStack(spacing: 16) {
                            ArtworkView(urlString: artworkURL)
                                .frame(width: 130, height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.portBorder, lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.6), radius: 12, y: 4)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(albumTitle)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .lineLimit(2)

                                Text(artist)
                                    .font(.subheadline)
                                    .foregroundColor(.portBrand)
                                    .lineLimit(1)

                                Text("\(tracks.count) Titel")
                                    .font(.caption2)
                                    .foregroundColor(.portTextMuted)

                                Spacer()

                                if !tracks.isEmpty {
                                    HStack(spacing: 8) {
                                        Button {
                                            if let first = tracks.first {
                                                player.play(song: first, in: tracks)
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "play.fill")
                                                    .font(.caption)
                                                Text("Album abspielen")
                                                    .font(.subheadline)
                                                    .fontWeight(.bold)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.portBrand)
                                            .foregroundColor(.black)
                                            .cornerRadius(20)
                                        }

                                        Button {
                                            Task {
                                                if isAlbumDownloaded {
                                                    for track in tracks {
                                                        DownloadManager.shared.removeDownload(trackId: track.id)
                                                    }
                                                    DownloadManager.shared.removePlaylistDownload(playlistId: "album_\(albumId)")
                                                } else {
                                                    let record = PlaylistRecord(
                                                        id: "album_\(albumId)",
                                                        title: albumTitle,
                                                        description: artist,
                                                        cover_url: artworkURL,
                                                        folder_id: nil,
                                                        color: nil,
                                                        visibility: nil,
                                                        created_at: nil,
                                                        updated_at: nil
                                                    )
                                                    try? await DownloadManager.shared.downloadPlaylist(playlist: record, tracks: tracks)
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: isAlbumDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                                                    .font(.caption)
                                                Text(isAlbumDownloaded ? "Download entfernen" : "Herunterladen")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Color.portSurfaceElevated)
                                            .foregroundColor(isAlbumDownloaded ? .portBrand : .white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color.portBorder, lineWidth: 1)
                                            )
                                            .cornerRadius(20)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Divider()
                            .background(Color.portBorder)
                            .padding(.horizontal, 16)

                        // Tracks
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
                    .padding(.bottom, 120)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAlbum()
        }
    }

    private func loadAlbum() async {
        isLoading = true
        do {
            self.tracks = try await OctaveBackend.shared.fetchAlbumTracks(id: albumId)
        } catch {
            if let offlineTracks = DownloadManager.shared.tracksForPlaylist(id: "album_\(albumId)"), !offlineTracks.isEmpty {
                self.tracks = offlineTracks
            } else {
                print("Failed to load album tracks: \(error)")
            }
        }
        isLoading = false
    }
}
