//
//  LibraryView.swift
//  octave
//

import SwiftUI

struct LibraryView: View {
    let items = [
        ("Playlists", "music.note.list"),
        ("Artists", "music.mic"),
        ("Albums", "square.stack"),
        ("Songs", "music.note"),
        ("Made for You", "person.crop.square"),
        ("Downloaded", "arrow.down.circle")
    ]

    var body: some View {
        List {
            ForEach(items, id: \.0) { item in
                NavigationLink(destination: Text(item.0)) {
                    Label(item.0, systemImage: item.1)
                        .font(.body)
                        .padding(.vertical, 4)
                }
            }

            Section(header: Text("Recently Added")) {
                Text("No recent additions")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Library")
    }
}
