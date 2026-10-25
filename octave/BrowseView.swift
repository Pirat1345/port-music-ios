//
//  BrowseView.swift
//  octave
//

import SwiftUI

struct BrowseView: View {
    let categories = ["Spatial Audio", "Pop", "Hip-Hop", "Rock", "Electronic", "Classical", "Jazz", "R&B", "Indie", "Dance"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Browse")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(categories, id: \.self) { cat in
                        ZStack(alignment: .bottomLeading) {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearGradient(colors: [.purple.opacity(0.8), .pink.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 100)

                            Text(cat)
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
    }
}
