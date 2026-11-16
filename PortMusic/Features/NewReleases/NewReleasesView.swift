import SwiftUI

// MARK: - Native iOS New Releases & Discovery View (Port Music v2)
// Bietet brandneue Alben, Singles und Top-Charts aus dem Apple Music Discovery Katalog
public struct NewReleasesView: View {
    public let serverURL: String
    @ObservedObject private var player = AudioPlayerManager.shared

    @State private var newReleases: [DiscoveryAlbum] = []
    @State private var topTracks: [Track] = []
    @State private var isLoading: Bool = true

    public init(serverURL: String) {
        self.serverURL = serverURL
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Kopfzeile
                VStack(alignment: .leading, spacing: 4) {
                    Text("Neuheiten")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Text("Die heißesten Veröffentlichungen und Charts der Woche")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.60))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        Text("Neuheiten laden...")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.50))
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // Sektion 1: Frische Alben & EPs
                    if !newReleases.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Brandneue Alben")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(newReleases) { album in
                                        albumCard(album)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }

                    // Sektion 2: Neue Top-Tracks
                    if !topTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top Neuerscheinungen")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)

                            VStack(spacing: 8) {
                                ForEach(topTracks.prefix(10)) { track in
                                    trackRow(track)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }

                Spacer(minLength: 160)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color.black.ignoresSafeArea())
        .task {
            await loadData()
        }
    }

    private func albumCard(_ album: DiscoveryAlbum) -> some View {
        NavigationLink(value: AppRoute.album(id: album.id, title: album.title, artist: album.artist, coverUrl: album.cover)) {
            VStack(alignment: .leading, spacing: 6) {
                let resolved = resolveCoverURL(album.cover, serverURL: serverURL)
                PortCachedAsyncImage(url: resolved) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 140, height: 140)
                }
                .shadow(color: Color.black.opacity(0.35), radius: 6, y: 3)

                Text(album.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)

                Text(album.artist)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.60))
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func trackRow(_ track: Track) -> some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            player.play(track: track, from: topTracks, serverURL: serverURL)
        }) {
            HStack(spacing: 12) {
                let resolved = resolveCoverURL(track.coverUrl, serverURL: serverURL)
                PortCachedAsyncImage(url: resolved) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 48, height: 48)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(player.currentTrack?.id == track.id ? Color(hex: "#fc3c44") : .white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.60))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: player.currentTrack?.id == track.id && player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(player.currentTrack?.id == track.id ? Color(hex: "#fc3c44") : Color.white.opacity(0.70))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func loadData() async {
        isLoading = true
        let token = SessionManager.shared.currentToken
        let discovery = await MusicService.shared.fetchHomeDiscovery(serverURL: serverURL, token: token)
        await MainActor.run {
            self.newReleases = discovery?.newMusic ?? []
            self.topTracks = (discovery?.trendingEverywhere ?? []).map { $0.toTrack() }
            self.isLoading = false
        }
    }
}
