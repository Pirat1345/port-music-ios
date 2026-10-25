//
//  HomeCards.swift
//  Port Music
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
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.portBorder, lineWidth: 1)
                )

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.portTextSecondary)
                .lineLimit(1)
        }
        .frame(width: 150)
    }
}
