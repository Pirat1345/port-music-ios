//
//  ArtistDetailView.swift
//  Port Music
//
//  Online Discovery Artist Discography Page (Rule 1):
//  - Full discography fetched from /api/discovery/artist/:name
//  - Top Tracks (15+ tracks)
//  - Complete Albums & Singles/EPs
//  - Related Artists
//  - Featured Playlists
//

import SwiftUI

struct ArtistDetailView: View {
    let artistName: String

    @Environment(AudioPlayer.self) private var player
    @State private var artistFull: DiscoveryArtistFull?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    private func formatFans(_ count: Int?) -> String {
        guard let count = count, count > 0 else { return "" }
        if count >= 1_000_000 {
            return String(format: "%.1fM monatliche Hörer", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return "\(count / 1000)k monatliche Hörer"
        } else {
            return "\(count) monatliche Hörer"
        }
    }

    var body: some View {
        ZStack {
            Color.portBackground
                .ignoresSafeArea()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.portBrand)
                    Text("\(artistName) wird geladen...")
                        .font(.subheadline)
                        .foregroundColor(.portTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, artistFull == nil {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.portTextSecondary)
                    Button("Erneut versuchen") {
                        Task { await loadArtistData() }
                    }
                    .foregroundColor(.portBrand)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let artist = artistFull {
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        // Hero Header
                        ZStack(alignment: .bottomLeading) {
                            ArtworkView(urlString: artist.cover)
                                .frame(height: 280)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .overlay(
                                    LinearGradient(
                                        colors: [.clear, Color.portBackground.opacity(0.4), Color.portBackground],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption)
                                        .foregroundColor(.portBrand)
                                    Text("Verifizierter Künstler")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white.opacity(0.9))
                                }

                                Text(artist.name)
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                let fans = formatFans(artist.nbFan)
                                if !fans.isEmpty {
                                    Text(fans)
                                        .font(.subheadline)
                                        .foregroundColor(.portTextSecondary)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.bottom, 16)
                        }

                        // Playback Action Buttons
                        let topSongList = (artist.topTracks ?? []).map { $0.toSongEntity() }
                        if !topSongList.isEmpty {
                            HStack(spacing: 16) {
                                Button {
                                    if let first = topSongList.first {
                                        player.play(song: first, in: topSongList)
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "play.fill")
                                            .font(.subheadline)
                                        Text("Abspielen")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.portBrand)
                                    .foregroundColor(.black)
                                    .cornerRadius(24)
                                }

                                Button {
                                    let shuffled = topSongList.shuffled()
                                    if let first = shuffled.first {
                                        player.play(song: first, in: shuffled)
                                    }
                                } label: {
                                    Image(systemName: "shuffle")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(Color.portSurface)
                                        .overlay(Circle().stroke(Color.portBorder, lineWidth: 1))
                                        .clipShape(Circle())
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 18)
                        }

                        // Top Tracks (Beliebte Titel)
                        if !topSongList.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Beliebte Titel")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 18)

                                LazyVStack(spacing: 4) {
                                    ForEach(Array(topSongList.prefix(15).enumerated()), id: \.element.id) { index, song in
                                        HStack(spacing: 12) {
                                            Text("\(index + 1)")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.portTextMuted)
                                                .frame(width: 24, alignment: .center)

                                            TrackListRow(song: song) {
                                                player.play(song: song, in: topSongList)
                                            }
                                        }
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 3)
                                    }
                                }
                            }
                        }

                        // Complete Albums (Alben)
                        if let albums = artist.albums, !albums.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Alben")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 18)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(albums) { alb in
                                            NavigationLink(destination: AlbumDetailView(
                                                albumId: alb.id,
                                                albumTitle: alb.name,
                                                artist: artist.name,
                                                artworkURL: alb.cover
                                            )) {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    ArtworkView(urlString: alb.cover)
                                                        .frame(width: 140, height: 140)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.portBorder, lineWidth: 1))
                                                        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)

                                                    Text(alb.name)
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.white)
                                                        .lineLimit(1)

                                                    if let yr = alb.year {
                                                        Text("\(yr) • Album")
                                                            .font(.caption2)
                                                            .foregroundColor(.portTextMuted)
                                                    }
                                                }
                                                .frame(width: 140)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 18)
                                }
                            }
                        }

                        // Singles & EPs
                        if let singles = artist.singles, !singles.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Singles & EPs")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 18)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(singles) { single in
                                            NavigationLink(destination: AlbumDetailView(
                                                albumId: single.id,
                                                albumTitle: single.name,
                                                artist: artist.name,
                                                artworkURL: single.cover
                                            )) {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    ArtworkView(urlString: single.cover)
                                                        .frame(width: 130, height: 130)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.portBorder, lineWidth: 1))

                                                    Text(single.name)
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.white)
                                                        .lineLimit(1)

                                                    if let yr = single.year {
                                                        Text("\(yr) • Single")
                                                            .font(.caption2)
                                                            .foregroundColor(.portTextMuted)
                                                    }
                                                }
                                                .frame(width: 130)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 18)
                                }
                            }
                        }

                        // Playlists
                        if let pls = artist.playlists, !pls.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Playlists mit \(artist.name)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 18)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(pls) { pl in
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
                                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.portBorder, lineWidth: 1))

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
                                    .padding(.horizontal, 18)
                                }
                            }
                        }

                        // Related Artists (Ähnliche Künstler)
                        if let related = artist.relatedArtists, !related.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Fans gefällt auch")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 18)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(related) { rel in
                                            NavigationLink(destination: ArtistDetailView(artistName: rel.name)) {
                                                VStack(spacing: 8) {
                                                    ArtworkView(urlString: rel.picture)
                                                        .frame(width: 90, height: 90)
                                                        .clipShape(Circle())
                                                        .shadow(color: .black.opacity(0.3), radius: 5)

                                                    Text(rel.name)
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
                                    .padding(.horizontal, 18)
                                }
                            }
                        }

                        // Biography / Description
                        if let desc = artist.description, !desc.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Über \(artist.name)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)

                                Text(desc)
                                    .font(.subheadline)
                                    .foregroundColor(.portTextSecondary)
                                    .lineSpacing(4)
                            }
                            .padding(18)
                            .background(Color.portSurface)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.portBorder, lineWidth: 1))
                            .cornerRadius(16)
                            .padding(.horizontal, 18)
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadArtistData()
        }
    }

    private func loadArtistData() async {
        isLoading = true
        errorMessage = nil
        do {
            self.artistFull = try await OctaveBackend.shared.fetchDiscoveryArtist(name: artistName)
        } catch {
            self.errorMessage = "Künstlerprofil konnte nicht geladen werden"
        }
        isLoading = false
    }
}
