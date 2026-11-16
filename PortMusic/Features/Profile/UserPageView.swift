import SwiftUI

// MARK: - User Profile Page (1:1 Web-App UserPage.tsx)
// Öffentliche Benutzerprofilseite mit großem Avatar, Name, Statistiken,
// öffentlichen Playlists und Lieblingssongs mit direkter Wiedergabesteuerung.
public struct UserPageView: View {
    public let user: UserProfile
    public let serverURL: String
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var session = SessionManager.shared

    @State private var favoriteTracks: [Track] = []
    @State private var playlists: [DiscoveryPlaylist] = []
    @State private var isLoading: Bool = true
    @State private var navPath: [AppRoute] = []

    public init(user: UserProfile, serverURL: String) {
        self.user = user
        self.serverURL = serverURL
    }

    private var memberSinceText: String {
        guard let raw = user.createdAt, !raw.isEmpty else {
            return "Kürzlich beigetreten"
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: raw)
        if date == nil {
            let fallbackFormatter = ISO8601DateFormatter()
            date = fallbackFormatter.date(from: raw)
        }
        if date == nil, let millis = Double(raw) {
            date = Date(timeIntervalSince1970: millis / 1000.0)
        }
        guard let validDate = date else {
            return "Kürzlich beigetreten"
        }
        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "de_DE")
        displayFormatter.dateFormat = "MMMM yyyy"
        return "Mitglied seit " + displayFormatter.string(from: validDate)
    }

    public var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                Color(hex: "#0b0b0e")
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // 1. Profil-Kopfbereich
                        profileHeaderSection
                            .padding(.top, 16)

                        // 2. Playlists des Benutzers
                        if !playlists.isEmpty {
                            userPlaylistsSection
                        }

                        // 3. Songs des Benutzers (Lieblingssongs)
                        if !favoriteTracks.isEmpty {
                            userTracksSection
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .playlist(let id, let title, let coverUrl):
                    PlaylistDetailView(playlistId: id, initialTitle: title, initialCover: coverUrl, serverURL: serverURL)
                case .artist(let name, let coverUrl):
                    ArtistDetailView(artistName: name, initialCover: coverUrl, serverURL: serverURL)
                case .album(let id, let title, let artist, let coverUrl):
                    AlbumDetailView(albumId: id, initialTitle: title, initialArtist: artist, initialCover: coverUrl, serverURL: serverURL)
                default:
                    EmptyView()
                }
            }
        }
        .task {
            await loadProfileData()
        }
    }

    // MARK: - 1. Profil Kopfbereich
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            PortUserAvatarView(
                rawAvatar: user.avatar,
                username: user.username,
                serverURL: serverURL,
                size: 96
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 12, y: 6)

            VStack(spacing: 6) {
                Text("PROFIL")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(Color.white.opacity(0.55))

                Text(user.displayName ?? user.username)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                if let display = user.displayName, display != user.username {
                    Text("@\(user.username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.50))
                }

                if let role = user.role, !role.isEmpty {
                    Text(role.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#6366f1").opacity(0.20))
                        .foregroundColor(Color(hex: "#a5b4fc"))
                        .clipShape(Capsule())
                        .padding(.top, 2)
                }

                // Statistiken: Playlists · Songs · Mitglied seit
                HStack(spacing: 8) {
                    Text("\(playlists.count) Playlists")
                    Text("·")
                    Text("\(favoriteTracks.count) Songs")
                    Text("·")
                    Text(memberSinceText)
                }
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color.white.opacity(0.55))
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - 2. Playlists Section
    private var userPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Öffentliche Playlists")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(playlists, id: \.id) { pl in
                        let coverUrl = pl.cover.isEmpty ? nil : pl.cover
                        Button(action: {
                            navPath.append(.playlist(id: pl.id, title: pl.title, coverUrl: coverUrl))
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                PortCoverImage(
                                    coverUrl: coverUrl,
                                    serverURL: serverURL,
                                    placeholderIcon: "music.note.list"
                                )
                                .frame(width: 140, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(color: .black.opacity(0.35), radius: 6, y: 3)

                                Text(pl.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .frame(width: 140, alignment: .leading)

                                if let nb = pl.nbTracks {
                                    Text("\(nb) Songs")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(Color.white.opacity(0.50))
                                        .lineLimit(1)
                                        .frame(width: 140, alignment: .leading)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - 3. Songs Section
    private var userTracksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Lieblingssongs")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if !favoriteTracks.isEmpty {
                    Button(action: {
                        if let first = favoriteTracks.first {
                            player.play(track: first, from: favoriteTracks, serverURL: serverURL)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Alle abspielen")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            VStack(spacing: 6) {
                ForEach(Array(favoriteTracks.prefix(25).enumerated()), id: \.element.id) { index, track in
                    let isCurrent = player.currentTrack?.id == track.id
                    Button(action: {
                        player.play(track: track, from: favoriteTracks, serverURL: serverURL)
                    }) {
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(isCurrent ? Color(hex: "#60a5fa") : Color.white.opacity(0.35))
                                .frame(width: 24, alignment: .center)

                            PortCoverImage(
                                coverUrl: track.coverUrl,
                                serverURL: serverURL,
                                placeholderIcon: "music.note"
                            )
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.system(size: 15, weight: isCurrent ? .bold : .medium))
                                    .foregroundColor(isCurrent ? Color(hex: "#60a5fa") : .white)
                                    .lineLimit(1)

                                Text(track.artist)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color.white.opacity(0.55))
                                    .lineLimit(1)
                            }

                            Spacer()

                            if isCurrent && player.isPlaying {
                                Image(systemName: "waveform")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "#60a5fa"))
                                    .padding(.trailing, 4)
                            }

                            if let dur = track.duration, !dur.isEmpty {
                                Text(dur)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(Color.white.opacity(0.40))
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(isCurrent ? Color.white.opacity(0.06) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Daten laden
    private func loadProfileData() async {
        isLoading = true
        let token = session.currentToken

        async let favFetch = MusicService.shared.fetchFavorites(serverURL: serverURL, token: token)
        async let playFetch = MusicService.shared.fetchPlaylists(serverURL: serverURL, token: token)

        let (favs, pls) = await (favFetch, playFetch)

        await MainActor.run {
            self.favoriteTracks = favs
            self.playlists = pls
            self.isLoading = false
        }
    }
}
