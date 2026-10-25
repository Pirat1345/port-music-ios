//
//  HomeView.swift
//  Port Music
//
//  Complete start page matching the Port Music web application:
//  - Filter tabs (Alle, Musik, Playlists, Künstler)
//  - Top-Picks für dich (Hero Posters with Play Button)
//  - Deine Playlists & Quick Access
//  - Trending überall
//  - Heute beliebte Hits
//  - Neue Alben & Veröffentlichungen
//  - Beliebte Playlists
//  - Trending Künstler (linking to ArtistDetailView)
//  - Stimmungen & Genres
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Environment(AudioPlayer.self) private var player

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Guten Morgen"
        } else if hour < 18 {
            return "Guten Tag"
        } else {
            return "Guten Abend"
        }
    }

    var body: some View {
        ZStack {
            Color.portBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 1. Header Bar: Greeting & Account
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            Text("Willkommen bei Port Music")
                                .font(.subheadline)
                                .foregroundColor(.portTextSecondary)
                        }
                        Spacer()
                        NavigationLink(destination: AccountSettingsView()) {
                            Image(systemName: "person.crop.circle")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)

                    // 2. Filter Pills (Alle, Musik, Playlists, Künstler)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(HomeFilterTab.allCases) { filter in
                                Button {
                                    viewModel.activeFilter = filter
                                } label: {
                                    Text(filter.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(viewModel.activeFilter == filter ? .bold : .medium)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(viewModel.activeFilter == filter ? Color.portBrand : Color.portSurface)
                                        .foregroundColor(viewModel.activeFilter == filter ? .black : .white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(viewModel.activeFilter == filter ? Color.portBrand : Color.portBorder, lineWidth: 1)
                                        )
                                        .cornerRadius(18)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Continue Playing Chip (if playing)
                    HomeContinueChip()
                        .padding(.horizontal)

                    // 3. User Playlists Section (Deine Playlists) - Visible in .all and .playlists
                    if (viewModel.activeFilter == .all || viewModel.activeFilter == .playlists) && !viewModel.userPlaylists.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Deine Playlists")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(viewModel.userPlaylists) { pl in
                                        NavigationLink(destination: PlaylistDetailView(
                                            playlistId: pl.id,
                                            title: pl.title,
                                            description: pl.description,
                                            coverURL: pl.cover_url,
                                            isUserPlaylist: true
                                        )) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                ArtworkView(urlString: pl.cover_url)
                                                    .frame(width: 140, height: 140)
                                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 14)
                                                            .stroke(Color.portBorder, lineWidth: 1)
                                                    )
                                                    .shadow(color: .black.opacity(0.4), radius: 8, y: 3)

                                                Text(pl.title)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)

                                                Text("Playlist")
                                                    .font(.caption2)
                                                    .foregroundColor(.portTextMuted)
                                            }
                                            .frame(width: 140)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // 4. Top-Picks für dich (Hero Posters) - Visible in .all and .music
                    if (viewModel.activeFilter == .all || viewModel.activeFilter == .music),
                       let picks = viewModel.discovery?.topPicks, !picks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top-Picks für dich")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(picks) { pick in
                                        ZStack(alignment: .bottomLeading) {
                                            ArtworkView(urlString: pick.cover)
                                                .frame(width: 280, height: 160)
                                                .aspectRatio(contentMode: .fill)
                                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                                .overlay(
                                                    LinearGradient(
                                                        colors: [.clear, .black.opacity(0.85)],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(Color.portBorder, lineWidth: 1)
                                                )

                                            HStack(alignment: .bottom) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    if let tag = pick.tag, !tag.isEmpty {
                                                        Text(tag.uppercased())
                                                            .font(.caption2)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(.portBrand)
                                                    }
                                                    Text(pick.title)
                                                        .font(.headline)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.white)
                                                        .lineLimit(1)
                                                    if let sub = pick.subtitle, !sub.isEmpty {
                                                        Text(sub)
                                                            .font(.caption)
                                                            .foregroundColor(.white.opacity(0.8))
                                                            .lineLimit(1)
                                                    }
                                                }
                                                Spacer()

                                                Button {
                                                    let song = SongEntity(
                                                        id: pick.id,
                                                        title: pick.title,
                                                        artist: pick.subtitle ?? "Port Music",
                                                        artworkURLString: pick.cover
                                                    )
                                                    player.play(song: song, in: [song])
                                                } label: {
                                                    Image(systemName: "play.circle.fill")
                                                        .font(.system(size: 38))
                                                        .foregroundColor(.portBrand)
                                                        .background(Color.black.opacity(0.5))
                                                        .clipShape(Circle())
                                                }
                                            }
                                            .padding(14)
                                        }
                                        .frame(width: 280, height: 160)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // 5. Trending überall - Visible in .all and .music
                    if (viewModel.activeFilter == .all || viewModel.activeFilter == .music),
                       let trending = viewModel.discovery?.trendingEverywhere, !trending.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Trending überall")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal)

                            let songList = trending.map { $0.toSongEntity() }
                            LazyVStack(spacing: 4) {
                                ForEach(songList.prefix(8)) { song in
                                    TrackListRow(song: song) {
                                        player.play(song: song, in: songList)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }

                    // 6. Heute beliebte Hits (Charts) - Visible in .all and .music
                    if (viewModel.activeFilter == .all || viewModel.activeFilter == .music),
                       let hits = viewModel.discovery?.todaysTopHits, !hits.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Heute beliebte Hits")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)

                            let songList = hits.map { $0.track.toSongEntity() }
                            LazyVStack(spacing: 4) {
                                ForEach(Array(songList.prefix(6).enumerated()), id: \.element.id) { index, song in
                                    HStack(spacing: 12) {
                                        Text("\(index + 1)")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.portTextMuted)
                                            .frame(width: 24, alignment: .center)

                                        TrackListRow(song: song) {
                                            player.play(song: song, in: songList)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }

                    // 7. Neue Alben & Veröffentlichungen - Visible in .all and .music
                    if (viewModel.activeFilter == .all || viewModel.activeFilter == .music),
                       let albums = viewModel.discovery?.newMusic ?? viewModel.discovery?.topAlbums, !albums.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Neue Alben & Veröffentlichungen")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(albums) { album in
                                        NavigationLink(destination: AlbumDetailView(
                                            albumId: album.id,
                                            albumTitle: album.title,
                                            artist: album.artist,
                                            artworkURL: album.cover
                                        )) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                ArtworkView(urlString: album.cover)
                                                    .frame(width: 150, height: 150)
                                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 14)
                                                            .stroke(Color.portBorder, lineWidth: 1)
                                                    )
                                                    .shadow(color: .black.opacity(0.4), radius: 8, y: 3)

                                                Text(album.title)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)

                                                Text(album.artist)
                                                    .font(.caption)
                                                    .foregroundColor(.portTextSecondary)
                                                    .lineLimit(1)
                                            }
                                            .frame(width: 150)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // 8. Beliebte Playlists - Visible in .all and .playlists
                    if (viewModel.activeFilter == .all || viewModel.activeFilter == .playlists),
                       let topPlaylists = viewModel.discovery?.topPlaylists, !topPlaylists.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Beliebte Playlists")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(topPlaylists) { pl in
                                        NavigationLink(destination: PlaylistDetailView(
                                            playlistId: pl.id,
                                            title: pl.title,
                                            description: pl.user != nil ? "Von \(pl.user!)" : nil,
                                            coverURL: pl.cover,
                                            isUserPlaylist: false
                                        )) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                ArtworkView(urlString: pl.cover)
                                                    .frame(width: 150, height: 150)
                                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 14)
                                                            .stroke(Color.portBorder, lineWidth: 1)
                                                    )
                                                    .shadow(color: .black.opacity(0.4), radius: 8, y: 3)

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
                                            .frame(width: 150)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // 9. Trending Künstler (Artists) - Visible in .all and .artists
                    if (viewModel.activeFilter == .all || viewModel.activeFilter == .artists),
                       let artists = viewModel.discovery?.trendingArtists, !artists.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Beliebte Künstler")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)

                            if viewModel.activeFilter == .artists {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 16)], spacing: 20) {
                                    ForEach(artists) { art in
                                        NavigationLink(destination: ArtistDetailView(artistName: art.name)) {
                                            VStack(spacing: 8) {
                                                ArtworkView(urlString: art.picture)
                                                    .frame(width: 100, height: 100)
                                                    .clipShape(Circle())
                                                    .overlay(Circle().stroke(Color.portBorder, lineWidth: 1))
                                                    .shadow(color: .black.opacity(0.35), radius: 6)

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
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
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
                                }
                            }
                        }
                    }

                    // 10. Stimmungen & Genres - Visible in .all
                    if viewModel.activeFilter == .all,
                       let genres = viewModel.discovery?.moodsAndGenres, !genres.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Stimmungen & Genres")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(genres) { g in
                                        HStack(spacing: 10) {
                                            ArtworkView(urlString: g.cover)
                                                .frame(width: 38, height: 38)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                            Text(g.title)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.portSurface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.portBorder, lineWidth: 1)
                                        )
                                        .cornerRadius(12)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.bottom, 120)
            }
            .refreshable {
                await viewModel.loadHomeData()
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadHomeData()
        }
    }
}
