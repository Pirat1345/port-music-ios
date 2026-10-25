//
//  HomeCards.swift
//  octave
//

import SwiftUI

struct HomeCardItem: View {
    let title: String
    let subtitle: String
    let imageURL: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkView(urlString: imageURL)
                .frame(width: 150, height: 150)
                .cornerRadius(12)

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 150)
    }
}
