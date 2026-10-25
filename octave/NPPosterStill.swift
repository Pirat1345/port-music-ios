//
//  NPPosterStill.swift
//  octave
//

import SwiftUI

struct NPPosterStill: View {
    let artworkURL: String?

    var body: some View {
        ArtworkView(urlString: artworkURL)
    }
}
