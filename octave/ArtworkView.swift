//
//  ArtworkView.swift
//  octave
//

import SwiftUI

struct ArtworkView: View {
    let urlString: String?

    var body: some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.purple.opacity(0.2))
                        .overlay(ProgressView())
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.purple.opacity(0.3))
            .overlay(
                Image(systemName: "music.note")
                    .font(.largeTitle)
                    .foregroundColor(.white.opacity(0.6))
            )
    }
}
