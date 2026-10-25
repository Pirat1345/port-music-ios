//
//  TasteOnboardingView.swift
//  octave
//

import SwiftUI

struct TasteOnboardingView: View {
    let genres = ["Pop", "Rock", "Hip-Hop", "R&B", "Electronic", "Jazz", "Classical", "Metal", "Ambient", "Indie"]
    @State private var selected: Set<String> = []

    var body: some View {
        VStack(spacing: 20) {
            Text("What do you like to listen to?")
                .font(.title2)
                .fontWeight(.bold)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                ForEach(genres, id: \.self) { g in
                    Button {
                        if selected.contains(g) { selected.remove(g) }
                        else { selected.insert(g) }
                    } label: {
                        Text(g)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selected.contains(g) ? Color.purple : Color.secondary.opacity(0.15))
                            .foregroundColor(selected.contains(g) ? .white : .primary)
                            .cornerRadius(20)
                    }
                }
            }
            .padding()

            Button("Continue") {}
                .padding()
        }
        .padding()
    }
}
