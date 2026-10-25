//
//  SearchView.swift
//  octave
//

import SwiftUI

struct SearchView: View {
    @Binding var query: String
    @Environment(AudioPlayer.self) private var player
    @State private var searchResults: [SongEntity] = []
    @State private var isSearching: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            OctaveSearchField(text: $query, onCommit: {
                Task { await performSearch() }
            })
            .padding(.horizontal)
            .padding(.top, 8)

            if isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !query.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No results for '\(query)'")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(searchResults) { song in
                    TrackListRow(song: song) {
                        player.play(song: song, in: searchResults)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Search")
        .onChange(of: query) { _, newQuery in
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if query == newQuery {
                    await performSearch()
                }
            }
        }
    }

    private func performSearch() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        do {
            searchResults = try await OctaveBackend.shared.search(query: query)
        } catch {
            print("Search failed: \(error)")
        }
        isSearching = false
    }
}
