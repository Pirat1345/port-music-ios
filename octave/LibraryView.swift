//
//  LibraryView.swift
//  Port Music
//
//  Complete user music library:
//  - Real user playlists from /api/playlists
//  - Create new playlist (+ button)
//  - Lieblingssongs (Favorites)
//  - Clean dark glassmorphism styling
//

import SwiftUI

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "Alle"
    case playlists = "Playlists"
    case favorites = "Lieblingssongs"

    var id: String { rawValue }
}

struct LibraryView: View {
    @Environment(AudioPlayer.self) private var player
    @State private var userPlaylists: [PlaylistRecord] = []
    @State private var favorites: [SongEntity] = []
    @State private var isLoading: Bool = true
    @State private var activeFilter: LibraryFilter = .all
    @State private var showCreatePlaylistSheet: Bool = false
    @State private var newPlaylistTitle: String = ""
    @State private var isCreating: Bool = false

    var body: some View {
        ZStack {
            Color.portBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LibraryFilter.allCases) { filter in
                            Button {
                                activeFilter = filter
                            } label: {
                                Text(filter.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(activeFilter == filter ? .bold : .medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(activeFilter == filter ? Color.portBrand : Color.portSurface)
                                    .foregroundColor(activeFilter == filter ? .black : .white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(activeFilter == filter ? Color.portBrand : Color.portBorder, lineWidth: 1)
                                    )
                                    .cornerRadius(18)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                if isLoading && userPlaylists.isEmpty && favorites.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.portBrand)
                        Text("Bibliothek wird geladen...")
                            .font(.subheadline)
                            .foregroundColor(.portTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            // 1. Lieblingssongs Banner (Favorites)
                            if activeFilter == .all || activeFilter == .favorites {
                                NavigationLink(destination: FavoritesDetailView(tracks: favorites)) {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            LinearGradient(
                                                colors: [Color.portBrand, Color.portBrand.opacity(0.4), Color.portSurface],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))

                                            Image(systemName: "heart.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(.white)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Lieblingssongs")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)

                                            Text("\(favorites.count) Lieblingstitel")
                                                .font(.subheadline)
                                                .foregroundColor(.portTextSecondary)
                                        }

                                        Spacer()

                                        if !favorites.isEmpty {
                                            Button {
                                                if let first = favorites.first {
                                                    player.play(song: first, in: favorites)
                                                }
                                            } label: {
                                                Image(systemName: "play.circle.fill")
                                                    .font(.system(size: 38))
                                                    .foregroundColor(.portBrand)
                                            }
                                        }
                                    }
                                    .padding(14)
                                    .background(Color.portSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.portBorder, lineWidth: 1)
                                    )
                                    .cornerRadius(14)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                            }

                            // 2. Deine Playlists Section
                            if activeFilter == .all || activeFilter == .playlists {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack {
                                        Text("Deine Playlists")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)

                                        Spacer()

                                        Button {
                                            showCreatePlaylistSheet = true
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "plus.circle.fill")
                                                Text("Neu")
                                            }
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.portBrand)
                                        }
                                    }
                                    .padding(.horizontal, 16)

                                    if userPlaylists.isEmpty {
                                        VStack(spacing: 12) {
                                            Image(systemName: "music.note.list")
                                                .font(.system(size: 40))
                                                .foregroundColor(.portTextMuted)
                                            Text("Noch keine Playlists vorhanden")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text("Erstelle deine erste Playlist mit dem '+' Button oben.")
                                                .font(.caption)
                                                .foregroundColor(.portTextSecondary)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 36)
                                        .padding(.horizontal, 24)
                                    } else {
                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 18) {
                                            ForEach(userPlaylists) { pl in
                                                NavigationLink(destination: PlaylistDetailView(
                                                    playlistId: pl.id,
                                                    title: pl.title,
                                                    description: pl.description,
                                                    coverURL: pl.cover_url,
                                                    isUserPlaylist: true
                                                )) {
                                                    VStack(alignment: .leading, spacing: 8) {
                                                        ZStack {
                                                            if let cover = pl.cover_url, !cover.isEmpty {
                                                                ArtworkView(urlString: cover)
                                                                    .frame(maxWidth: .infinity)
                                                                    .aspectRatio(1.0, contentMode: .fill)
                                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                                            } else {
                                                                RoundedRectangle(cornerRadius: 12)
                                                                    .fill(Color.portSurfaceLight)
                                                                    .aspectRatio(1.0, contentMode: .fit)
                                                                    .overlay(
                                                                        Image(systemName: "music.note")
                                                                            .font(.system(size: 36))
                                                                            .foregroundColor(.portTextMuted)
                                                                    )
                                                            }
                                                        }
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 12)
                                                                .stroke(Color.portBorder, lineWidth: 1)
                                                        )
                                                        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)

                                                        Text(pl.title)
                                                            .font(.subheadline)
                                                            .fontWeight(.semibold)
                                                            .foregroundColor(.white)
                                                            .lineLimit(1)

                                                        Text("Playlist")
                                                            .font(.caption2)
                                                            .foregroundColor(.portTextMuted)
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 120)
                    }
                    .refreshable {
                        await loadLibraryData()
                    }
                }
            }
        }
        .navigationTitle("Bibliothek")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreatePlaylistSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                }
            }
        }
        .alert("Neue Playlist", isPresented: $showCreatePlaylistSheet) {
            TextField("Playlist-Titel", text: $newPlaylistTitle)
            Button("Erstellen") {
                Task {
                    let title = newPlaylistTitle.trimmingCharacters(in: .whitespaces)
                    guard !title.isEmpty else { return }
                    isCreating = true
                    if let newPl = try? await OctaveBackend.shared.createPlaylist(title: title) {
                        userPlaylists.insert(newPl, at: 0)
                    }
                    newPlaylistTitle = ""
                    isCreating = false
                }
            }
            Button("Abbrechen", role: .cancel) {
                newPlaylistTitle = ""
            }
        } message: {
            Text("Gib einen Namen für deine neue Playlist ein.")
        }
        .task {
            await loadLibraryData()
        }
    }

    private func loadLibraryData() async {
        isLoading = true
        async let plFetch = try? OctaveBackend.shared.fetchUserPlaylists()
        async let favFetch = try? OctaveBackend.shared.fetchFavorites()

        let (pls, favs) = await (plFetch, favFetch)
        self.userPlaylists = pls ?? []
        self.favorites = favs ?? []
        self.isLoading = false
    }
}

// Subview for Favorites Playlist
struct FavoritesDetailView: View {
    let tracks: [SongEntity]
    @Environment(AudioPlayer.self) private var player

    var body: some View {
        ZStack {
            Color.portBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 16) {
                        ZStack {
                            LinearGradient(
                                colors: [Color.portBrand, Color.portSurface],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                            Image(systemName: "heart.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.white)
                        }
                        .shadow(color: .black.opacity(0.5), radius: 10, y: 4)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Lieblingssongs")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text("\(tracks.count) Titel")
                                .font(.caption2)
                                .foregroundColor(.portTextMuted)

                            Spacer()

                            if !tracks.isEmpty {
                                Button {
                                    if let first = tracks.first {
                                        player.play(song: first, in: tracks)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.fill")
                                            .font(.caption)
                                        Text("Abspielen")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.portBrand)
                                    .foregroundColor(.black)
                                    .cornerRadius(20)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Divider()
                        .background(Color.portBorder)
                        .padding(.horizontal, 16)

                    if tracks.isEmpty {
                        Text("Noch keine Lieblingstitel vorhanden.")
                            .font(.subheadline)
                            .foregroundColor(.portTextMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 4) {
                            ForEach(tracks) { song in
                                TrackListRow(song: song) {
                                    player.play(song: song, in: tracks)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(.bottom, 120)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
