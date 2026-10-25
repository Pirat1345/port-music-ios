//
//  TrackListRow.swift
//  Port Music
//

import SwiftUI

struct TrackListRow: View {
    @Environment(AudioPlayer.self) private var player
    let song: SongEntity
    var onPlay: () -> Void

    private var isCurrentTrack: Bool {
        player.currentTrack?.id == song.id
    }

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(urlString: song.artworkURLString)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isCurrentTrack && player.isPlaying {
                        Image(systemName: "waveform")
                            .font(.caption2)
                            .foregroundColor(.portBrand)
                    }
                    Text(song.title)
                        .font(.body)
                        .fontWeight(isCurrentTrack ? .bold : .medium)
                        .foregroundColor(isCurrentTrack ? .portBrand : .white)
                        .lineLimit(1)
                }

                Text(song.artist)
                    .font(.caption)
                    .foregroundColor(.portTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                Button("Als Nächstes abspielen", action: {})
                Button("Zur Playlist hinzufügen", action: {})
                Button("Titel teilen", action: {})
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.portTextMuted)
                    .padding(8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
    }
}
