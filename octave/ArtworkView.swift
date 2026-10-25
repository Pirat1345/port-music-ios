//
//  ArtworkView.swift
//  Port Music
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
                        .fill(Color.portSurfaceElevated)
                        .overlay(
                            ProgressView()
                                .tint(.portBrand)
                        )
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
            .fill(Color.portSurfaceElevated)
            .overlay(
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundColor(.portTextMuted)
            )
    }
}
