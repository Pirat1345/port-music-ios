//
//  CachedFillImage.swift
//  octave
//

import SwiftUI

struct CachedFillImage: View {
    let url: String?

    var body: some View {
        ArtworkView(urlString: url)
    }
}
