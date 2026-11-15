import SwiftUI

public struct HomeView: View {
    public let serverURL: String
    public let user: UserProfile

    @ObservedObject private var player = AudioPlayerManager.shared
    @State private var discovery: DiscoveryHomeResponse? = nil
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil

    public init(serverURL: String, user: UserProfile) {
        self.serverURL = serverURL
        self.user = user
    }

    public var body: some View {
        ZStack {
            FluentBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header-Bereich
                    headerSection
                        .padding(.top, 16)

                    if isLoading && discovery == nil {
                        loadingSkeletonView
                            .padding(.top, 40)
                    } else if let error = errorMessage, discovery == nil {
                        errorStateView(error)
                    } else if let data = discovery {
                        // Top-Picks Hero Banner
                        if let topPicks = data.topPicks, let firstPick = topPicks.first {
                            heroTopPick(firstPick, allTrending: data.trendingEverywhere ?? [])
                        }

                        // Shelf: Trending überall
                        if let trending = data.trendingEverywhere, !trending.isEmpty {
                            trendingSection(tracks: trending)
                        }

                        // Shelf: Top Hits heute
                        if let topHits = data.todaysTopHits, !topHits.isEmpty {
                            topHitsSection(tracks: topHits)
                        }

                        // Shelf: Neuheiten
                        if let newMusic = data.newMusic, !newMusic.isEmpty {
                            newMusicSection(albums: newMusic)
                        }

                        // Shelf: Angesagte Künstler
                        if let artists = data.trendingArtists, !artists.isEmpty {
                            trendingArtistsSection(artists: artists)
                        }
                    }

                    // Ausreichend Abstand am Ende, damit der MiniPlayer nichts verdeckt
                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 20)
            }
            .refreshable {
                await loadHomeData()
            }
        }
        .task {
            if discovery == nil {
                await loadHomeData()
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Willkommen zurück")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.65))

                Text(user.username)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(PortColors.textPrimary)
            }

            Spacer()

            // Server-Status-Pill
            HStack(spacing: 6) {
                Circle()
                    .fill(PortColors.successGreen)
                    .frame(width: 7, height: 7)

                Text("Online")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(PortColors.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(PortColors.surfaceGlass)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(PortColors.borderGlass, lineWidth: 1)
            )
        }
    }

    // MARK: - Hero Top-Pick
    private func heroTopPick(_ pick: DiscoveryPosterPick, allTrending: [DiscoveryTrack]) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Hintergrund-Cover
            if let url = URL(string: pick.cover) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: 220)
                            .clipped()
                    default:
                        Rectangle()
                            .fill(PortColors.surfaceGlassStrong)
                            .frame(height: 220)
                    }
                }
            }

            // Dunkler Verlauf für perfekte Lesbarkeit
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.4), Color.black.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Text & Play-Button
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(pick.tag.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(PortColors.accentOrange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(PortColors.accentOrange.opacity(0.2))
                        .clipShape(Capsule())

                    Text(pick.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(pick.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.75))
                        .lineLimit(1)
                }

                Spacer()

                Button(action: {
                    let heroTrack = pick.toTrack()
                    let fullQueue = [heroTrack] + allTrending.map { $0.toTrack() }
                    player.play(track: heroTrack, from: fullQueue, serverURL: serverURL)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 52, height: 52)
                            .shadow(color: Color.white.opacity(0.3), radius: 8, y: 3)

                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                            .offset(x: 2)
                    }
                }
            }
            .padding(18)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(PortColors.borderGlass, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 14, y: 6)
    }

    // MARK: - Trending Überall Shelf
    private func trendingSection(tracks: [DiscoveryTrack]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Trending überall", subtitle: "Weltweit am meisten gehört")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(tracks) { item in
                        let track = item.toTrack()
                        Button(action: {
                            let queue = tracks.map { $0.toTrack() }
                            player.play(track: track, from: queue, serverURL: serverURL)
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(PortColors.surfaceGlassStrong)
                                        .frame(width: 140, height: 140)

                                    if let cover = track.coverUrl, let url = URL(string: cover) {
                                        AsyncImage(url: url) { phase in
                                            if case .success(let image) = phase {
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 140, height: 140)
                                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                            }
                                        }
                                    }
                                }
                                .frame(width: 140, height: 140)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )

                                Text(track.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(PortColors.textPrimary)
                                    .lineLimit(1)
                                    .frame(width: 140, alignment: .leading)

                                Text(track.artist)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(Color.white.opacity(0.65))
                                    .lineLimit(1)
                                    .frame(width: 140, alignment: .leading)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Top Hits Heute Shelf
    private func topHitsSection(tracks: [DiscoveryChartTrack]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Top Hits heute", subtitle: "Die aktuellen Chartstürmer")

            VStack(spacing: 8) {
                ForEach(Array(tracks.prefix(5))) { item in
                    let track = item.toTrack()
                    Button(action: {
                        let queue = tracks.map { $0.toTrack() }
                        player.play(track: track, from: queue, serverURL: serverURL)
                    }) {
                        HStack(spacing: 12) {
                            if let rank = item.rank {
                                Text("\(rank)")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(rank <= 3 ? PortColors.accentOrange : Color.white.opacity(0.5))
                                    .frame(width: 24)
                            }

                            if let cover = track.coverUrl, let url = URL(string: cover) {
                                AsyncImage(url: url) { phase in
                                    if case .success(let image) = phase {
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                                .frame(width: 44, height: 44)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(track.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(PortColors.textPrimary)
                                    .lineLimit(1)

                                Text(track.artist)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.white.opacity(0.65))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(track.duration)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.50))
                        }
                        .padding(10)
                        .background(PortColors.surfaceGlass)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(PortColors.borderGlass, lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Neuheiten Shelf
    private func newMusicSection(albums: [DiscoveryAlbum]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Neuheiten", subtitle: "Frisch veröffentlichte Alben & EPs")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(albums) { album in
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(PortColors.surfaceGlassStrong)
                                    .frame(width: 140, height: 140)

                                if let cover = album.cover, let url = URL(string: cover) {
                                    AsyncImage(url: url) { phase in
                                        if case .success(let image) = phase {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 140, height: 140)
                                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                        }
                                    }
                                }
                            }
                            .frame(width: 140, height: 140)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )

                            Text(album.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(PortColors.textPrimary)
                                .lineLimit(1)
                                .frame(width: 140, alignment: .leading)

                            Text(album.artist)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(Color.white.opacity(0.65))
                                .lineLimit(1)
                                .frame(width: 140, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Angesagte Künstler Shelf
    private func trendingArtistsSection(artists: [DiscoveryArtist]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Angesagte Künstler", subtitle: "Aktuell am meisten gestreamt")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(artists) { artist in
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(PortColors.surfaceGlassStrong)
                                    .frame(width: 86, height: 86)

                                if let pic = artist.picture, let url = URL(string: pic) {
                                    AsyncImage(url: url) { phase in
                                        if case .success(let image) = phase {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 86, height: 86)
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                            }
                            .frame(width: 86, height: 86)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )

                            Text(artist.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(PortColors.textPrimary)
                                .lineLimit(1)
                                .frame(width: 90)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sektions-Überschrift
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(PortColors.textPrimary)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.60))
        }
    }

    // MARK: - Lade- & Fehleranzeige
    private var loadingSkeletonView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            Text("Entdeckungen werden geladen...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(PortColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func errorStateView(_ msg: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 32))
                .foregroundColor(PortColors.errorRed)

            Text(msg)
                .font(.system(size: 14))
                .foregroundColor(PortColors.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: {
                Task { await loadHomeData() }
            }) {
                Text("Erneut versuchen")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(PortColors.surfaceGlass)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 40)
    }

    // MARK: - API Abruf
    private func loadHomeData() async {
        isLoading = true
        errorMessage = nil

        let token = SessionManager.shared.currentToken
        let res = await MusicService.shared.fetchHomeDiscovery(serverURL: serverURL, token: token)

        await MainActor.run {
            self.isLoading = false
            if let data = res {
                self.discovery = data
            } else {
                self.errorMessage = "Startseite konnte nicht geladen werden. Bitte Netzwerkverbindung prüfen."
            }
        }
    }
}
