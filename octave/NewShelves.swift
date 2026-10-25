//
//  NewShelves.swift
//  Port Music
//

import SwiftUI

struct NewShelves: View {
    let releases = [
        ("Top Hits Deutschland", "Die beliebtesten Songs der Woche"),
        ("Club & Electro Neuheiten", "Frische Bässe und Beats"),
        ("Acoustic Morning", "Ruhiger Start in den Tag"),
        ("Pop Rising", "Die Hits von morgen"),
        ("Hip-Hop Rotation", "Aktuelle Releases im Deutsch- & US-Rap")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Neuerscheinungen & Trends")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(releases, id: \.0) { item in
                        HomeCardItem(
                            title: item.0,
                            subtitle: item.1,
                            imageURL: nil
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
