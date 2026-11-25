import SwiftUI

// MARK: - Library Podcasts View (Mirrors Web LibraryPodcastsPage.tsx)
public struct LibraryPodcastsView: View {
    public let serverURL: String

    @ObservedObject private var player = AudioPlayerManager.shared

    @State private var searchQuery: String = ""
    @State private var subscribed: [PodcastItem] = []
    @State private var charts: [PodcastItem] = []
    @State private var searchResults: [PodcastItem] = []

    @State private var selectedPodcast: PodcastItem? = nil
    @State private var feedDetail: PodcastFeedDetail? = nil

    @State private var isLoadingCharts: Bool = true
    @State private var isLoadingSearch: Bool = false
    @State private var isLoadingFeed: Bool = false
    @State private var searchDebounceTask: Task<Void, Never>? = nil

    private static let subscribedStorageKey = "port_music_subscribed_podcasts"

    public init(serverURL: String) {
        self.serverURL = serverURL
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let selected = selectedPodcast {
                feedDetailView(for: selected)
            } else {
                podcastsHomeView
            }
        }
        .task {
            loadSubscriptions()
            await loadCharts()
        }
    }

    // MARK: - Home / Discovery & Subscriptions
    private var podcastsHomeView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                searchFieldSection

                let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedQuery.isEmpty {
                    searchResultsSection
                } else {
                    if !subscribed.isEmpty {
                        subscribedSection
                    }
                    chartsSection
                }

                Spacer(minLength: 120)
            }
            .padding(.top, 2)
        }
        .refreshable {
            await loadCharts()
        }
    }

    private var searchFieldSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.45))

            TextField("Podcasts & Shows suchen...", text: $searchQuery)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .tint(.white)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onChange(of: searchQuery) { newVal in
                    scheduleSearch(newVal)
                }
                .onSubmit {
                    Task { await performSearch(searchQuery) }
                }

            if isLoadingSearch {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.75)
            } else if !searchQuery.isEmpty {
                Button(action: {
                    searchQuery = ""
                    searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.45))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var subscribedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Abonniert")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            podcastGrid(items: subscribed)
        }
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top-Podcasts")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            if isLoadingCharts && charts.isEmpty {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
            } else if charts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "mic.slash")
                        .font(.system(size: 34))
                        .foregroundColor(Color.white.opacity(0.30))
                    Text("Keine Podcasts verfügbar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 44)
            } else {
                podcastGrid(items: charts)
            }
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suchergebnisse")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            if isLoadingSearch && searchResults.isEmpty {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
            } else if searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(Color.white.opacity(0.30))
                    Text("Keine Podcasts gefunden")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 44)
            } else {
                podcastGrid(items: searchResults)
            }
        }
    }

    private func podcastGrid(items: [PodcastItem]) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ],
            spacing: 16
        ) {
            ForEach(items) { podcast in
                Button(action: {
                    openPodcast(podcast)
                }) {
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "#18181b"))
                                .aspectRatio(1, contentMode: .fit)

                            PortCachedAsyncImage(url: resolveCoverURL(podcast.cover, serverURL: serverURL)) { img in
                                img
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } placeholder: {
                                ZStack(alignment: .center) {
                                    Color(hex: "#18181b")
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(Color.white.opacity(0.28))
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }

                            if isSubscribed(podcast) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.65)))
                                    .padding(8)
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.40), radius: 6, y: 3)

                        Text(podcast.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(podcast.artist.isEmpty ? "Podcast" : podcast.artist)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#a0a0a0"))
                            .lineLimit(1)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Podcast Detail & Episode Feed View
    private func feedDetailView(for podcast: PodcastItem) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            selectedPodcast = nil
                            feedDetail = nil
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                            Text("Alle Podcasts")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    Button(action: {
                        toggleSubscribe(podcast)
                    }) {
                        let active = isSubscribed(podcast)
                        HStack(spacing: 5) {
                            Image(systemName: active ? "checkmark" : "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text(active ? "Abonniert" : "Abonnieren")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(active ? .black : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(active ? Color.white : Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Show Header
                HStack(alignment: .top, spacing: 14) {
                    PortCoverImage(
                        coverUrl: feedDetail?.cover.isEmpty == false ? feedDetail?.cover : podcast.cover,
                        placeholderIcon: "mic.fill",
                        serverURL: serverURL
                    )
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(feedDetail?.title.isEmpty == false ? (feedDetail?.title ?? podcast.title) : podcast.title)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(3)

                        let author = (feedDetail?.author.isEmpty == false ? feedDetail?.author : nil) ?? podcast.artist
                        if !author.isEmpty {
                            Text(author)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.65))
                                .lineLimit(1)
                        }

                        if let detail = feedDetail, !detail.episodes.isEmpty {
                            Text("\(String(detail.episodes.count)) Folgen")
                                .font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.45))
                        }
                    }
                    Spacer()
                }

                if let desc = feedDetail?.description, !desc.isEmpty {
                    let cleanDesc = stripHTMLTags(desc)
                    if !cleanDesc.isEmpty {
                        Text(cleanDesc)
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.70))
                            .lineLimit(4)
                    }
                }

                Text("Folgen")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 4)

                if isLoadingFeed {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 44)
                } else if let episodes = feedDetail?.episodes, !episodes.isEmpty {
                    let episodeTracks = buildEpisodeTracks(episodes: episodes, showTitle: feedDetail?.title ?? podcast.title, fallbackCover: feedDetail?.cover ?? podcast.cover)
                    LazyVStack(spacing: 8) {
                        ForEach(Array(episodes.enumerated()), id: \.element.id) { idx, ep in
                            episodeRow(ep, track: episodeTracks[idx], allTracks: episodeTracks)
                        }
                    }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "waveform")
                            .font(.system(size: 30))
                            .foregroundColor(Color.white.opacity(0.30))
                        Text("Keine abspielbaren Folgen gefunden")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }

                Spacer(minLength: 120)
            }
            .padding(.top, 2)
        }
    }

    private func episodeRow(_ episode: PodcastEpisodeItem, track: Track, allTracks: [Track]) -> some View {
        let isPlayingThis = player.currentTrack?.id == track.id
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isPlayingThis && player.isPlaying {
                        EqualizerBarsView(color: .white)
                    }
                    Text(episode.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }

                let epDesc = stripHTMLTags(episode.description)
                if !epDesc.isEmpty {
                    Text(epDesc)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.55))
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if !episode.publishedAt.isEmpty {
                        Text(formatEpisodeDate(episode.publishedAt))
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.42))
                    }
                    if episode.durationSeconds > 0 {
                        Text(formatDurationLabel(episode.durationSeconds))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.52))
                    }
                }
            }

            Spacer(minLength: 8)

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if isPlayingThis {
                    player.togglePlayPause()
                } else {
                    player.play(track: track, from: allTracks, serverURL: serverURL)
                }
            }) {
                Image(systemName: isPlayingThis && player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isPlayingThis ? .black : .white)
                    .frame(width: 36, height: 36)
                    .background(isPlayingThis ? Color.white : Color.white.opacity(0.14))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(isPlayingThis ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPlayingThis ? Color.white.opacity(0.24) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isPlayingThis {
                player.togglePlayPause()
            } else {
                player.play(track: track, from: allTracks, serverURL: serverURL)
            }
        }
    }

    // MARK: - Helpers
    private func buildEpisodeTracks(episodes: [PodcastEpisodeItem], showTitle: String, fallbackCover: String?) -> [Track] {
        let safeQueryChars = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+?#"))
        return episodes.compactMap { ep in
            guard !ep.audioUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let encoded = ep.audioUrl.addingPercentEncoding(withAllowedCharacters: safeQueryChars) ?? ep.audioUrl
            let mins = ep.durationSeconds / 60
            let secs = ep.durationSeconds % 60
            let formatted = String(format: "%d:%02d", mins, secs)
            let rawCover = (ep.cover?.isEmpty == false) ? ep.cover : fallbackCover
            return Track(
                id: "pod_\(ep.id)",
                title: ep.title,
                artist: showTitle,
                album: "Podcast",
                duration: ep.durationSeconds > 0 ? formatted : "0:00",
                durationSeconds: Double(ep.durationSeconds),
                coverUrl: rawCover,
                isLive: false,
                isExplicit: false,
                sourceUrl: "/api/podcasts/stream?url=\(encoded)"
            )
        }
    }

    private func openPodcast(_ podcast: PodcastItem) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        selectedPodcast = podcast
        feedDetail = nil
        isLoadingFeed = true
        Task {
            let token = SessionManager.shared.currentToken
            let detail = await MusicService.shared.fetchPodcastFeed(
                id: podcast.id,
                feedUrl: podcast.feedUrl,
                serverURL: serverURL,
                token: token
            )
            await MainActor.run {
                self.feedDetail = detail
                self.isLoadingFeed = false
            }
        }
    }

    private func loadSubscriptions() {
        guard let data = UserDefaults.standard.data(forKey: Self.subscribedStorageKey),
              let saved = try? JSONDecoder().decode([PodcastItem].self, from: data) else {
            return
        }
        subscribed = saved
    }

    private func isSubscribed(_ podcast: PodcastItem) -> Bool {
        subscribed.contains(where: { $0.id == podcast.id || $0.title.lowercased() == podcast.title.lowercased() })
    }

    private func toggleSubscribe(_ podcast: PodcastItem) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if isSubscribed(podcast) {
            subscribed.removeAll { $0.id == podcast.id || $0.title.lowercased() == podcast.title.lowercased() }
        } else {
            subscribed.insert(podcast, at: 0)
        }
        if let encoded = try? JSONEncoder().encode(subscribed) {
            UserDefaults.standard.set(encoded, forKey: Self.subscribedStorageKey)
        }
    }

    private func loadCharts() async {
        isLoadingCharts = true
        let token = SessionManager.shared.currentToken
        let list = await MusicService.shared.fetchPodcastCharts(limit: 25, serverURL: serverURL, token: token)
        await MainActor.run {
            self.charts = list
            self.isLoadingCharts = false
        }
    }

    private func scheduleSearch(_ query: String) {
        searchDebounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isLoadingSearch = false
            return
        }
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(trimmed)
        }
    }

    private func performSearch(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await MainActor.run { self.isLoadingSearch = true }
        let token = SessionManager.shared.currentToken
        let res = await MusicService.shared.searchPodcasts(query: trimmed, serverURL: serverURL, token: token)
        await MainActor.run {
            self.searchResults = res
            self.isLoadingSearch = false
        }
    }

    private func stripHTMLTags(_ raw: String) -> String {
        guard raw.contains("<") else {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatDurationLabel(_ seconds: Int) -> String {
        let mins = seconds / 60
        let hrs = mins / 60
        let remMins = mins % 60
        if hrs > 0 {
            return "\(String(hrs)) Std. \(String(remMins)) Min."
        }
        return "\(String(max(1, mins))) Min."
    }

    private func formatEpisodeDate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 10 {
            return String(trimmed.prefix(10))
        }
        return trimmed
    }
}
