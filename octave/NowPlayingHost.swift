//
//  NowPlayingHost.swift
//  octave
//

import SwiftUI

struct NowPlayingHost: View {
    @Environment(AudioPlayer.self) private var player
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 12) {
                // Mini Artwork
                if let song = player.currentTrack {
                    NPPosterStill(artworkURL: song.artworkURLString)
                        .frame(width: 44, height: 44)
                        .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentTrack?.title ?? "")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(player.currentTrack?.artist ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(14)
            .shadow(radius: 8)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $isPresented) {
            NowPlayingView()
        }
    }
}
