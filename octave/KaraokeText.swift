//
//  KaraokeText.swift
//  octave
//

import SwiftUI

struct KaraokeText: View {
    let text: String
    let progress: Double

    var body: some View {
        Text(text)
            .foregroundColor(.white)
    }
}
