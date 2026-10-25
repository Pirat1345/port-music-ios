//
//  ArtistDetailView.swift
//  octave
//

import SwiftUI

struct ArtistDetailView: View {
    let artistName: String

    var body: some View {
        ScrollView {
            VStack {
                Text(artistName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
        }
    }
}
