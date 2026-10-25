//
//  NewShelves.swift
//  octave
//

import SwiftUI

struct NewShelves: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "New Releases")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(1...5, id: \.self) { i in
                        HomeCardItem(
                            title: "New Song \(i)",
                            subtitle: "Popular Artist",
                            imageURL: nil
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
