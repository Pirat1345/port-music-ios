//
//  SearchView.swift
//  Port Music
//
//  Search view matching the Port Music web application:
//  - Backend Discovery Search (/api/discovery/search)
//  - Category Filter Pills (Alle, Titel, Künstler, Alben, Playlists)
//  - Bester Treffer (Top Result) Card
//  - Songs, Artists, Albums & Playlists sections
//  - Browse categories pre-search state
//

import SwiftUI

enum SearchFilter: String, CaseIterable, Identifiable {
    case all = "Alle"
    case songs = "Titel"
    case artists = "Künstler"
    case albums = "Alben"
    case playlists = "Playlists"

    var id: String { rawValue }
}

struct SearchView: View {
    @Binding var query: String
    @Environment(AudioPlayer.self) private var player
    @State private var activeFilter: SearchFilter = .all
    @State private var isSearching: Bool = false
    @State private var searchResponse: DiscoverySearchResponse?
    @State private var searchError: String?

    // Quick browse categories when query is empty
    let browseCategories = [
        ("Charts & Trends", "flame.fill"),
        ("Neuerscheinungen", "sparkles"),
        ("Pop", "music.mic"),
        ("Hip-Hop & Rap", "headphones"),
        ("Rock & Alternative", "guitars.fill"),
        ("Dance & Electronic", "waveform.path.ecg"),
        ("Chill & Lofi", "cup.and.saucer.fill"),
        ("Workout & Fokus", "bolt.fill")
    ]

    var body: some View {
        ZStack {
            Color.portBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Search Input Field
                OctaveSearchField(text: $query, onCommit: {
                    Task { await performSearch() }
                })
                .padding(.horizontal)
                .padding(.top, 8)

                // Category Filter Pills (Visible when query is not empty)
                if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SearchFilter.allCases) { filter in
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
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                }

                if isSearching {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.portBrand)
                        Text("Suche läuft...")
                            .font(.subheadline)
                            .foregroundColor(.portTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Empty Query: Browse Hub
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Alles durchsuchen")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                                .padding(.top, 16)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                                ForEach(browseCategories, id: \.0) { cat in
                                    Button {
                                        query = cat.0
                                    } label: {
                                        ZStack(alignment: .bottomLeading) {
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(Color.portSurface)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .stroke(Color.portBorder, lineWidth: 1)
                                                )
                                                .frame(height: 90)

                                            VStack(alignment: .leading, spacing: 6) {
                                                HStack {
                                                    Spacer()
                                                    Image(systemName: cat.1)
                                                        .font(.title2)
                                                        .foregroundColor(.portBrand.opacity(0.85))
                                                }
                                                Spacer()
                                                Text(cat.0)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.white)
                                            }
                                            .padding(12)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 120)
                    }
                } else {
                    // Results View
                    let tracks = searchResponse?.tracks ?? []
                    let artists = searchResponse?.artists ?? []
                    let albums = searchResponse?.albums ?? []
                    let playlists = searchResponse?.playlists ?? []

                    if tracks.isEmpty && artists.isEmpty && albums.isEmpty && playlists.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.portTextMuted)
                            Text("Keine Ergebnisse für '\(query)'")
                                .foregroundColor(.portTextSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                // 1. Bester Treffer (Top Match) in 'Alle' Filter
                                if activeFilter == .all {
                                    let trimmedQuery = query.trimmingCharacters(in: .whitespaces).lowercased()
                                    let matchedArtist = artists.first(where: { $0.name.lowercased().contains(trimmedQuery) })
                                    
                                    if let topArtist = matchedArtist ?? (artists.first != nil && tracks.isEmpty ? artists.first : nil) {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text("Bester Treffer")
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)

                                            NavigationLink(destination: ArtistDetailView(artistName: topArtist.name)) {
                                                HStack(spacing: 16) {
                                                    ArtworkView(urlString: topArtist.picture)
                                                        .frame(width: 88, height: 88)
                                                        .clipShape(Circle())
                                                        .overlay(Circle().stroke(Color.portBorder, lineWidth: 1))

                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(topArtist.name)
                                                            .font(.headline)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(.white)
                                                            .lineLimit(1)

                                                        Text("Künstler")
                                                            .font(.caption2)
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 3)
                                                            .background(Color.white.opacity(0.12))
                                                            .cornerRadius(6)
                                                            .foregroundColor(.white)
                                                    }
                                                    Spacer()

                                                    Image(systemName: "chevron.right")
                                                        .foregroundColor(.portTextMuted)
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
                                        }
                                        .padding(.horizontal)
                                    } else if let top = tracks.first {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text("Bester Treffer")
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)

                                            Button {
                                                let songList = tracks.map { $0.toSongEntity() }
                                                player.play(song: top.toSongEntity(), in: songList)
                                            } label: {
                                                HStack(spacing: 16) {
                                                    ArtworkView(urlString: top.cover)
                                                        .frame(width: 88, height: 88)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))

                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(top.title)
                                                            .font(.headline)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(.white)
                                                            .lineLimit(1)

                                                        Text(top.artist)
                                                            .font(.subheadline)
                                                            .foregroundColor(.portTextSecondary)
                                                            .lineLimit(1)

                                                        HStack(spacing: 6) {
                                                            Text("Song")
                                                                .font(.caption2)
                                                                .padding(.horizontal, 8)
                                                                .padding(.vertical, 3)
                                                                .background(Color.white.opacity(0.12))
                                                                .cornerRadius(6)
                                                                .foregroundColor(.white)
                                                        }
                                                        .padding(.top, 4)
                                                    }
                                                    Spacer()

                                                    Image(systemName: "play.circle.fill")
                                                        .font(.system(size: 40))
                                                        .foregroundColor(.portBrand)
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
                                        }
                                        .padding(.horizontal)
                                    }
                                }

                                // 2. Titel (Songs)
                                if (activeFilter == .all || activeFilter == .songs) && !tracks.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Titel")
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                            Spacer()
                                            if activeFilter == .all && tracks.count > 5 {
                                                Button("Alle anzeigen") {
                                                    activeFilter = .songs
                                                }
                                                .font(.subheadline)
                                                .foregroundColor(.portBrand)
                                            }
                                        }
                                        .padding(.horizontal)

                                        let songList = tracks.map { $0.toSongEntity() }
                                        LazyVStack(spacing: 4) {
                                            let displayTracks = activeFilter == .all ? Array(songList.prefix(5)) : songList
                                            ForEach(displayTracks) { song in
                                                TrackListRow(song: song) {
                                                    player.play(song: song, in: songList)
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 4)
                                            }
                                        }
                                    }
                                }

                                // 3. Künstler (Artists)
                                if (activeFilter == .all || activeFilter == .artists) && !artists.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text("Künstler")
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                            Spacer()
                                            if activeFilter == .all && artists.count > 4 {
                                                Button("Alle anzeigen") {
                                                    activeFilter = .artists
                                                }
                                                .font(.subheadline)
                                                .foregroundColor(.portBrand)
                                            }
                                        }
                                        .padding(.horizontal)

                                        if activeFilter == .artists {
                                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 16)], spacing: 20) {
                                                ForEach(artists) { art in
                                                    NavigationLink(destination: ArtistDetailView(artistName: art.name)) {
                                                        VStack(spacing: 8) {
                                                            ArtworkView(urlString: art.picture)
                                                                .frame(width: 90, height: 90)
                                                                .clipShape(Circle())
                                                                .overlay(Circle().stroke(Color.portBorder, lineWidth: 1))
                                                                .shadow(color: .black.opacity(0.35), radius: 6)

                                                            Text(art.name)
                                                                .font(.subheadline)
                                                                .fontWeight(.semibold)
                                                                .foregroundColor(.white)
                                                                .lineLimit(1)
                                                                .frame(width: 90)

                                                            Text("Künstler")
                                                                .font(.caption2)
                                                                .foregroundColor(.portTextMuted)
                                                        }
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.horizontal)
                                        } else {
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 16) {
                                                    ForEach(artists) { art in
                                                        NavigationLink(destination: ArtistDetailView(artistName: art.name)) {
                                                            VStack(spacing: 8) {
                                                                ArtworkView(urlString: art.picture)
                                                                    .frame(width: 100, height: 100)
                                                                    .clipShape(Circle())
                                                                    .overlay(Circle().stroke(Color.portBorder, lineWidth: 1))
                                                                    .shadow(color: .black.opacity(0.4), radius: 6)

                                                                Text(art.name)
                                                                    .font(.subheadline)
                                                                    .fontWeight(.semibold)
                                                                    .foregroundColor(.white)
                                                                    .lineLimit(1)
                                                                    .frame(width: 100)

                                                                Text("Künstler")
                                                                    .font(.caption2)
                                                                    .foregroundColor(.portTextMuted)
                                                            }
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                                .padding(.horizontal)
                                            }
                                        }
                                    }
                                }

                                // 4. Alben (Albums)
                                if (activeFilter == .all || activeFilter == .albums) && !albums.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text("Alben")
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                            Spacer()
                                            if activeFilter == .all && albums.count > 4 {
                                                Button("Alle anzeigen") {
                                                    activeFilter = .albums
                                                }
                                                .font(.subheadline)
                                                .foregroundColor(.portBrand)
                                            }
                                        }
                                        .padding(.horizontal)

                                        if activeFilter == .albums {
                                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 14)], spacing: 18) {
                                                ForEach(albums) { alb in
                                                    NavigationLink(destination: AlbumDetailView(
                                                        albumId: alb.id,
                                                        albumTitle: alb.title,
                                                        artist: alb.artist,
                                                        artworkURL: alb.cover
                                                    )) {
                                                        VStack(alignment: .leading, spacing: 6) {
                                                            ArtworkView(urlString: alb.cover)
                                                                .frame(maxWidth: .infinity)
                                                                .aspectRatio(1.0, contentMode: .fill)
                                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                                .overlay(
                                                                    RoundedRectangle(cornerRadius: 12)
                                                                        .stroke(Color.portBorder, lineWidth: 1)
                                                                )

                                                            Text(alb.title)
                                                                .font(.subheadline)
                                                                .fontWeight(.semibold)
                                                                .foregroundColor(.white)
                                                                .lineLimit(1)

                                                            Text(alb.artist)
                                                                .font(.caption)
                                                                .foregroundColor(.portTextSecondary)
                                                                .lineLimit(1)
                                                        }
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.horizontal)
                                        } else {
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 16) {
                                                    ForEach(albums) { alb in
                                                        NavigationLink(destination: AlbumDetailView(
                                                            albumId: alb.id,
                                                            albumTitle: alb.title,
                                                            artist: alb.artist,
                                                            artworkURL: alb.cover
                                                        )) {
                                                            VStack(alignment: .leading, spacing: 6) {
                                                                ArtworkView(urlString: alb.cover)
                                                                    .frame(width: 130, height: 130)
                                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                                                    .overlay(
                                                                        RoundedRectangle(cornerRadius: 12)
                                                                            .stroke(Color.portBorder, lineWidth: 1)
                                                                    )

                                                                Text(alb.title)
                                                                    .font(.subheadline)
                                                                    .fontWeight(.semibold)
                                                                    .foregroundColor(.white)
                                                                    .lineLimit(1)

                                                                Text(alb.artist)
                                                                    .font(.caption)
                                                                    .foregroundColor(.portTextSecondary)
                                                                    .lineLimit(1)
                                                            }
                                                            .frame(width: 130)
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                                .padding(.horizontal)
                                            }
                                        }
                                    }
                                }

                                // 5. Playlists
                                if (activeFilter == .all || activeFilter == .playlists) && !playlists.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text("Playlists")
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                            Spacer()
                                            if activeFilter == .all && playlists.count > 4 {
                                                Button("Alle anzeigen") {
                                                    activeFilter = .playlists
                                                }
                                                .font(.subheadline)
                                                .foregroundColor(.portBrand)
                                            }
                                        }
                                        .padding(.horizontal)

                                        if activeFilter == .playlists {
                                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 14)], spacing: 18) {
                                                ForEach(playlists) { pl in
                                                    NavigationLink(destination: PlaylistDetailView(
                                                        playlistId: pl.id,
                                                        title: pl.title,
                                                        description: pl.user != nil ? "Von \(pl.user!)" : nil,
                                                        coverURL: pl.cover,
                                                        isUserPlaylist: false
                                                    )) {
                                                        VStack(alignment: .leading, spacing: 6) {
                                                            ArtworkView(urlString: pl.cover)
                                                                .frame(maxWidth: .infinity)
                                                                .aspectRatio(1.0, contentMode: .fill)
                                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                                .overlay(
                                                                    RoundedRectangle(cornerRadius: 12)
                                                                        .stroke(Color.portBorder, lineWidth: 1)
                                                                )

                                                            Text(pl.title)
                                                                .font(.subheadline)
                                                                .fontWeight(.semibold)
                                                                .foregroundColor(.white)
                                                                .lineLimit(1)

                                                            if let count = pl.nbTracks {
                                                                Text("\(count) Titel")
                                                                    .font(.caption2)
                                                                    .foregroundColor(.portTextMuted)
                                                            }
                                                        }
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.horizontal)
                                        } else {
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 16) {
                                                    ForEach(playlists) { pl in
                                                        NavigationLink(destination: PlaylistDetailView(
                                                            playlistId: pl.id,
                                                            title: pl.title,
                                                            description: pl.user != nil ? "Von \(pl.user!)" : nil,
                                                            coverURL: pl.cover,
                                                            isUserPlaylist: false
                                                        )) {
                                                            VStack(alignment: .leading, spacing: 6) {
                                                                ArtworkView(urlString: pl.cover)
                                                                    .frame(width: 130, height: 130)
                                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                                                    .overlay(
                                                                        RoundedRectangle(cornerRadius: 12)
                                                                            .stroke(Color.portBorder, lineWidth: 1)
                                                                    )

                                                                Text(pl.title)
                                                                    .font(.subheadline)
                                                                    .fontWeight(.semibold)
                                                                    .foregroundColor(.white)
                                                                    .lineLimit(1)

                                                                if let count = pl.nbTracks {
                                                                    Text("\(count) Titel")
                                                                        .font(.caption2)
                                                                        .foregroundColor(.portTextMuted)
                                                                }
                                                            }
                                                            .frame(width: 130)
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                                .padding(.horizontal)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 120)
                        }
                    }
                }
            }
        }
        .navigationTitle("Suche")
        .onChange(of: query) { _, newQuery in
            Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                if query == newQuery {
                    await performSearch()
                }
            }
        }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResponse = nil
            return
        }
        isSearching = true
        searchError = nil
        do {
            let res = try await OctaveBackend.shared.searchDiscovery(query: trimmed)
            self.searchResponse = res
        } catch {
            // Fallback to basic song search if discovery endpoint is unreachable
            if let songs = try? await OctaveBackend.shared.search(query: trimmed) {
                let discTracks = songs.map {
                    DiscoveryTrack(
                        id: $0.id,
                        title: $0.title,
                        artist: $0.artist,
                        album: $0.albumTitle,
                        duration: nil,
                        durationSeconds: Int($0.durationSec),
                        cover: $0.artworkURLString,
                        sourceUrl: nil,
                        isExplicit: nil
                    )
                }
                self.searchResponse = DiscoverySearchResponse(tracks: discTracks, albums: [], artists: [], playlists: [])
            } else {
                self.searchError = error.localizedDescription
            }
        }
        isSearching = false
    }
}
