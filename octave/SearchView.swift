//
//  SearchView.swift
//  Port Music
//

import SwiftUI

struct SearchView: View {
    @Binding var query: String
    @Environment(AudioPlayer.self) private var player
    @State private var searchResults: [SongEntity] = []
    @State private var isSearching: Bool = false

    var body: some View {
        ZStack {
            Color.portBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                OctaveSearchField(text: $query, onCommit: {
                    Task { await performSearch() }
                })
                .padding(.horizontal)
                .padding(.top, 8)

                if isSearching {
                    ProgressView("Suche läuft...")
                        .tint(.portBrand)
                        .foregroundColor(.portTextSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && !query.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.portTextMuted)
                        Text("Keine Ergebnisse für '\(query)'")
                            .foregroundColor(.portTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.portTextMuted)
                        Text("Finde deine Lieblingsmusik")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Suche nach Millionen Titeln, Künstlern und Alben online")
                            .font(.subheadline)
                            .foregroundColor(.portTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(searchResults) { song in
                        TrackListRow(song: song) {
                            player.play(song: song, in: searchResults)
                        }
                        .listRowBackground(Color.portBackground)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Suche")
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
