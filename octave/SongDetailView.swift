//
//  SongDetailView.swift
//  octave
//

import SwiftUI

struct SongDetailView: View {
    let song: SongEntity

    var body: some View {
        VStack {
            Text(song.title)
                .font(.title)
        }
    }
}
