//
//  BrowseView.swift
//  Port Music
//

import SwiftUI

struct BrowseCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}

struct BrowseView: View {
    let categories: [BrowseCategory] = [
        BrowseCategory(name: "Charts & Trends", icon: "flame.fill"),
        BrowseCategory(name: "Neuerscheinungen", icon: "sparkles"),
        BrowseCategory(name: "Pop", icon: "music.mic"),
        BrowseCategory(name: "Hip-Hop & Rap", icon: "headphones"),
        BrowseCategory(name: "Rock & Alternative", icon: "guitars.fill"),
        BrowseCategory(name: "Electronic & Dance", icon: "waveform.path.ecg"),
        BrowseCategory(name: "Chill & Lofi", icon: "cup.and.saucer.fill"),
        BrowseCategory(name: "Klassik & Klavier", icon: "pianokeys"),
        BrowseCategory(name: "Workout & Fokus", icon: "bolt.fill"),
        BrowseCategory(name: "Indie & R&B", icon: "heart.text.square.fill")
    ]

    var body: some View {
        ZStack {
            Color.portBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Entdecken")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.top, 16)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(categories) { cat in
                            ZStack(alignment: .bottomLeading) {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.portSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.portBorder, lineWidth: 1)
                                    )
                                    .frame(height: 100)

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Spacer()
                                        Image(systemName: cat.icon)
                                            .font(.title2)
                                            .foregroundColor(.portBrand.opacity(0.85))
                                    }
                                    Spacer()
                                    Text(cat.name)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .padding(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 120)
            }
        }
        .navigationBarHidden(true)
    }
}
