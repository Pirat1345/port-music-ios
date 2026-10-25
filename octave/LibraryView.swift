//
//  LibraryView.swift
//  Port Music
//

import SwiftUI

struct LibraryView: View {
    let items = [
        ("Playlists", "music.note.list"),
        ("Künstler", "music.mic"),
        ("Alben", "square.stack"),
        ("Lieblingssongs", "heart.fill"),
        ("Für dich", "sparkles"),
        ("Offline / Downloads", "arrow.down.circle")
    ]

    var body: some View {
        ZStack {
            Color.portBackground
                .ignoresSafeArea()

            List {
                ForEach(items, id: \.0) { item in
                    NavigationLink(destination: Text(item.0).foregroundColor(.white)) {
                        Label(item.0, systemImage: item.1)
                            .foregroundColor(.white)
                            .font(.body)
                            .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.portSurface)
                }

                Section(header: Text("Zuletzt hinzugefügt").foregroundColor(.portTextMuted)) {
                    Text("Keine kürzlichen Titel")
                        .foregroundColor(.portTextSecondary)
                        .listRowBackground(Color.portSurface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Bibliothek")
    }
}
