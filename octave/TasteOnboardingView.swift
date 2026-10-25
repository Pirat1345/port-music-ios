//
//  TasteOnboardingView.swift
//  Port Music
//

import SwiftUI

struct TasteOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    let genres = ["Pop", "Rock", "Hip-Hop", "R&B", "Electronic", "Jazz", "Klassik", "Metal", "Ambient", "Indie"]
    @State private var selected: Set<String> = []

    var body: some View {
        ZStack {
            Color.portBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Was hörst du am liebsten?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Wähle deine Lieblingsgenres für personalisierte Empfehlungen")
                    .font(.subheadline)
                    .foregroundColor(.portTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                    ForEach(genres, id: \.self) { g in
                        Button {
                            if selected.contains(g) { selected.remove(g) }
                            else { selected.insert(g) }
                        } label: {
                            Text(g)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selected.contains(g) ? Color.portBrand : Color.portSurfaceElevated)
                                .foregroundColor(selected.contains(g) ? .black : .white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(selected.contains(g) ? Color.portBrand : Color.portBorder, lineWidth: 1)
                                )
                                .cornerRadius(20)
                        }
                    }
                }
                .padding()

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Weiter")
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color.portBrand)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .padding(.top, 24)
        }
    }
}
