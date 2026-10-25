//
//  HomeContinueChip.swift
//  Port Music
//

import SwiftUI

struct HomeContinueChip: View {
    @Environment(AudioPlayer.self) private var player

    var body: some View {
        if let current = player.currentTrack {
            HStack(spacing: 12) {
                ArtworkView(urlString: current.artworkURLString)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Weiterspielen")
                        .font(.caption2)
                        .foregroundColor(.portBrand)
                        .fontWeight(.semibold)
                    Text(current.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(current.artist)
                        .font(.caption)
                        .foregroundColor(.portTextSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.portBrand)
                }
            }
            .padding(12)
            .background(Color.portSurface)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.portBorder, lineWidth: 1))
            .cornerRadius(14)
        }
    }
}
