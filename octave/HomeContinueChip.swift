//
//  HomeContinueChip.swift
//  octave
//

import SwiftUI

struct HomeContinueChip: View {
    @Environment(AudioPlayer.self) private var player

    var body: some View {
        if let current = player.currentTrack {
            HStack(spacing: 12) {
                ArtworkView(urlString: current.artworkURLString)
                    .frame(width: 48, height: 48)
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Jump back in")
                        .font(.caption2)
                        .foregroundColor(.purple)
                        .fontWeight(.semibold)
                    Text(current.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                    Text(current.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                }
            }
            .padding(12)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(14)
        }
    }
}
