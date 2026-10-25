//
//  ForYouShelves.swift
//  Port Music
//

import SwiftUI

struct ForYouShelves: View {
    @Environment(AudioPlayer.self) private var player

    let mixes = [
        ("Mix der Woche", "Basierend auf deinen Favoriten"),
        ("Dein Flow", "Non-Stop Musik für dich"),
        ("Entdeckungs-Mix", "Neue Songs aus deinen Lieblingsgenres"),
        ("Wiederholungen", "Deine meistgehörten Tracks"),
        ("Top-Empfehlungen", "Frische Trends für deinen Geschmack")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Für dich zusammengestellt")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(mixes, id: \.0) { mix in
                        HomeCardItem(
                            title: mix.0,
                            subtitle: mix.1,
                            imageURL: nil
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
