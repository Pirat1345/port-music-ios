//
//  TrackListRow.swift
//  octave
//

import SwiftUI

struct TrackListRow: View {
    let song: SongEntity
    var onPlay: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(urlString: song.artworkURLString)
                .frame(width: 44, height: 44)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                Button("Play Next", action: {})
                Button("Add to Playlist", action: {})
                Button("Share", action: {})
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
                    .padding(8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
    }
}
