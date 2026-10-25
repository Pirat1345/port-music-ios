//
//  LyricsShareSheet.swift
//  octave
//

import SwiftUI

struct LyricsShareSheet: View {
    let lines: [LyricLine]

    var body: some View {
        VStack {
            Text("Share Lyrics")
                .font(.headline)
            Spacer()
        }
        .padding()
    }
}
