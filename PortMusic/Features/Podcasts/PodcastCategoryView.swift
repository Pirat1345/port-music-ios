import SwiftUI

public struct PodcastCategoryView: View {
    public let genreId: Int
    public let title: String
    public let subtitle: String
    public let serverURL: String

    @ObservedObject private var sessionManager = SessionManager.shared
    @State private var shows: [PodcastItem] = []
    @State private var isLoading: Bool = true
    @State private var subscribedIds: Set<String> = []

    public init(genreId: Int, title: String, subtitle: String, serverURL: String) {
        self.genreId = genreId
        self.title = title
        self.subtitle = subtitle
        self.serverURL = serverURL
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13.5))
                        .foregroundColor(Color.white.opacity(0.58))
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

                if isLoading && shows.isEmpty {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 56)
                } else if shows.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: sessionManager.isOfflineMode ? "wifi.slash" : "mic.slash")
                            .font(.system(size: 34))
                            .foregroundColor(Color.white.opacity(0.30))
                        Text(sessionManager.isOfflineMode
                             ? "Kategorie offline nicht zwischengespeichert"
                             : "Keine Podcasts in dieser Kategorie gefunden")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 56)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                        spacing: 16
                    ) {
                        ForEach(shows) { pod in
                            NavigationLink(value: AppRoute.podcast(
                                id: pod.id,
                                title: pod.title,
                                artist: pod.artist,
                                coverUrl: pod.cover,
                                feedUrl: pod.feedUrl.isEmpty ? nil : pod.feedUrl
                            )) {
                                VStack(alignment: .leading, spacing: 6) {
                                    ZStack(alignment: .topTrailing) {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(hex: "#18181b"))
                                            .aspectRatio(1, contentMode: .fit)

                                        PortCachedAsyncImage(url: resolveCoverURL(pod.cover, serverURL: serverURL)) { img in
                                            img
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                        } placeholder: {
                                            ZStack {
                                                Color(hex: "#18181b")
                                                Image(systemName: "mic.fill")
                                                    .font(.system(size: 28))
                                                    .foregroundColor(Color.white.opacity(0.28))
                                            }
                                        }

                                        if subscribedIds.contains(pod.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.65)))
                                                .padding(8)
                                        }
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))

                                    Text(pod.title)
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Text(pod.artist.isEmpty ? "Podcast" : pod.artist)
                                        .font(.system(size: 11.5))
                                        .foregroundColor(Color.white.opacity(0.55))
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 140)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .tint(.white)
        .refreshable {
            await loadCategory()
        }
        .task {
            subscribedIds = Set(PodcastSubscriptionStore.load().map(\.id))
            await loadCategory()
        }
        .onAppear {
            subscribedIds = Set(PodcastSubscriptionStore.load().map(\.id))
        }
    }

    private func loadCategory() async {
        isLoading = true
        let token = SessionManager.shared.currentToken
        let list = await MusicService.shared.fetchPodcastCharts(
            genre: genreId,
            limit: 30,
            serverURL: serverURL,
            token: token
        )
        await MainActor.run {
            self.shows = list
            self.isLoading = false
        }
    }
}
