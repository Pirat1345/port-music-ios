//
//  NPArtworkBed.swift
//  octave
//

import SwiftUI

struct NPArtworkBed: View {
    let song: SongEntity?

    var body: some View {
        ArtworkView(urlString: song?.artworkURLString)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}
