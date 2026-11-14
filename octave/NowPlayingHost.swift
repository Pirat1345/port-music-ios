//
//  NowPlayingHost.swift
//  Port Music
//

import SwiftUI

struct NowPlayingHost: View {
    @Environment(AudioPlayer.self) private var player
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented = true
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Mini Artwork
                    if let song = player.currentTrack {
                        ArtworkView(urlString: song.artworkURLString)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.portSurfaceElevated)
                            .frame(width: 44, height: 44)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.currentTrack?.title ?? "Kein Titel")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(player.currentTrack?.artist ?? "Port Music")
                            .font(.caption)
                            .foregroundColor(.portTextSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        player.previous()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)

                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundColor(.portBrand)
                    }
                    .buttonStyle(.plain)

                    Button {
                        player.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                // Track Progress Line
                if player.duration > 0 {
                    GeometryReader { geo in
                        let progress = min(max(player.currentTime / player.duration, 0.0), 1.0)
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                            Rectangle()
                                .fill(Color.portBrand)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 2)
                }
            }
            .background(Color.portSurfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.portBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.6), radius: 10, y: 4)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $isPresented) {
            NowPlayingView()
        }
    }
}
