//
//  ForYouShelves.swift
//  octave
//

import SwiftUI

struct ForYouShelves: View {
    @Environment(AudioPlayer.self) private var player

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Made For You")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(1...5, id: \.self) { i in
                        HomeCardItem(
                            title: "Daily Mix \(i)",
                            subtitle: "Personalized to your taste",
                            imageURL: nil
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
