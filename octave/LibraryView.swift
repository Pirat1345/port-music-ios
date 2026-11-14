//
//  LibraryView.swift
//  Port Music
//
//  Complete user music library:
//  - Real user playlists from /api/playlists
//  - Create new playlist (+ button)
//  - Lieblingssongs (Favorites)
//  - Offline downloads filter and cached playback
//  - Clean dark glassmorphism styling
//

import SwiftUI

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "Alle"
    case playlists = "Playlists"
    case favorites = "Lieblingssongs"
    case downloaded = "Heruntergeladen"
    case artists = "Künstler"
    case albums = "Alben"

    var id: String { rawValue }
}

struct LibraryView: View {
    @Environment(AudioPlayer.self) private var player
    @State private var userPlaylists: [PlaylistRecord] = []
    @State private var favorites: [SongEntity] = []
    @State private var isLoading: Bool = true
    @State private var activeFilter: LibraryFilter = NetworkMonitor.shared.isConnected ? .all : .downloaded
    @State private var showCreatePlaylistSheet: Bool = false
    @State private var newPlaylistTitle: String = ""
    @State private var isCreating: Bool = false

    private var libraryArtists: [String] {
        var names = Set<String>()
        for song in favorites {
            let parts = song.artist.components(separatedBy: CharacterSet(charactersIn: ",/&"))
            for p in parts {
                let trimmed = p.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { names.insert(trimmed) }
            }
        }
        return names.sorted()
    }

    private var libraryAlbums: [SongEntity] {
        var seen = Set<String>()
        var res: [SongEntity] = []
        for song in favorites {
            if let alb = song.albumTitle, !alb.isEmpty, !seen.contains(alb) {
                seen.insert(alb)
                res.append(song)
            }
        }
        return res
    }

    var body: some View {
        ZStack {
            Color.portBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                filterChipsBar

                if isLoading && userPlaylists.isEmpty && favorites.isEmpty {
                    loadingView
                } else {
                    mainScrollView
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
            if !NetworkMonitor.shared.isConnected {
                activeFilter = .downloaded
            }
            await loadLibraryData()
        }
        .onChange(of: NetworkMonitor.shared.isConnected) { _, isConnected in
            if !isConnected {
                activeFilter = .downloaded
            }
        }
    }

    // MARK: - Subviews

    private var filterChipsBar: some View {
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
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.portBrand)
            Text("Bibliothek wird geladen...")
                .font(.subheadline)
                .foregroundColor(.portTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mainScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if activeFilter == .downloaded {
                    downloadedSection
                } else {
                    if activeFilter == .all || activeFilter == .favorites {
                        favoritesBanner
                    }
                    if activeFilter == .all || activeFilter == .playlists {
                        playlistsSection
                    }
                    if (activeFilter == .all || activeFilter == .artists) && !libraryArtists.isEmpty {
                        artistsSection
                    }
                    if (activeFilter == .all || activeFilter == .albums) && !libraryAlbums.isEmpty {
                        albumsSection
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

    @ViewBuilder
    private var downloadedSection: some View {
        let dm = DownloadManager.shared
        if dm.downloadedTracks.isEmpty && dm.downloadedPlaylists.isEmpty {
            emptyDownloadsView
        } else {
            VStack(alignment: .leading, spacing: 20) {
                if !dm.downloadedPlaylists.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Heruntergeladene Playlists")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 18) {
                            ForEach(dm.downloadedPlaylists) { pl in
                                NavigationLink(destination: PlaylistDetailView(
                                    playlistId: pl.id,
                                    title: pl.title,
                                    description: nil,
                                    coverURL: pl.coverURL,
                                    isUserPlaylist: true
                                )) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ZStack {
                                            if let cover = pl.coverURL, !cover.isEmpty {
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

                                        Text("Playlist · Offline")
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

                if !dm.downloadedTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Heruntergeladene Titel")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(dm.downloadedTracks.count) Titel")
                                .font(.caption)
                                .foregroundColor(.portTextMuted)
                        }
                        .padding(.horizontal, 16)

                        LazyVStack(spacing: 4) {
                            ForEach(dm.downloadedTracks) { song in
                                TrackListRow(song: song) {
                                    player.play(song: song, in: dm.downloadedTracks)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyDownloadsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 40))
                .foregroundColor(.portTextMuted)
            Text("Keine Downloads vorhanden")
                .font(.headline)
                .foregroundColor(.white)
            Text("Lade Titel oder Playlists herunter, um sie offline ohne Internetverbindung anzuhören.")
                .font(.caption)
                .foregroundColor(.portTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
    }

    private var favoritesBanner: some View {
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

    private var playlistsSection: some View {
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
                emptyPlaylistsView
            } else {
                playlistsGridView
            }
        }
    }

    private var emptyPlaylistsView: some View {
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
    }

    private var playlistsGridView: some View {
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

    private var artistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Deine Künstler")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(libraryArtists, id: \.self) { artistName in
                        NavigationLink(destination: ArtistDetailView(artistName: artistName)) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(Color.portSurfaceElevated)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "mic.fill")
                                            .font(.title2)
                                            .foregroundColor(.portBrand)
                                    )
                                    .overlay(Circle().stroke(Color.portBorder, lineWidth: 1))

                                Text(artistName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .frame(width: 84)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var albumsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Deine Alben")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(libraryAlbums) { song in
                        NavigationLink(destination: AlbumDetailView(
                            albumId: song.id,
                            albumTitle: song.albumTitle ?? "",
                            artist: song.artist,
                            artworkURL: song.artworkURLString
                        )) {
                            VStack(alignment: .leading, spacing: 8) {
                                ArtworkView(urlString: song.artworkURLString)
                                    .frame(width: 130, height: 130)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.portBorder, lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.4), radius: 6, y: 3)

                                Text(song.albumTitle ?? "")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Text(song.artist)
                                    .font(.caption2)
                                    .foregroundColor(.portTextMuted)
                                    .lineLimit(1)
                            }
                            .frame(width: 130)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
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
