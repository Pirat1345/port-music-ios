//
//  AlbumDetailView.swift
//  octave
//

import SwiftUI

struct AlbumDetailView: View {
    let albumTitle: String
    let artist: String
    let artworkURL: String?
    @Environment(AudioPlayer.self) private var player
    @State private var tracks: [SongEntity] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ArtworkView(urlString: artworkURL)
                    .frame(width: 240, height: 240)
                    .cornerRadius(16)
                    .shadow(radius: 12)

                VStack(spacing: 4) {
                    Text(albumTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(artist)
                        .font(.headline)
                        .foregroundColor(.purple)
                }

                HStack(spacing: 20) {
                    Button {
                        if let first = tracks.first {
                            player.play(song: first, in: tracks)
                        }
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button {
                        // Shuffle
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.15))
                            .foregroundColor(.purple)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                LazyVStack(spacing: 0) {
                    ForEach(tracks) { song in
                        TrackListRow(song: song) {
                            player.play(song: song, in: tracks)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
