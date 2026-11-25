import SwiftUI

// MARK: - Apple-Style Podcast Detail & Episodes View (Web PodcastDetailPage.tsx Parity + Offline Support)
public struct PodcastDetailView: View {
    public let podcastId: String
    public let initialTitle: String?
    public let initialArtist: String?
    public let initialCover: String?
    public let feedUrl: String?
    public let serverURL: String

    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var playerProgress = AudioPlayerProgress.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @ObservedObject private var progressStore = PodcastProgressStore.shared

    @State private var feedDetail: PodcastFeedDetail? = nil
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var searchQuery: String = ""
    @State private var isDescriptionExpanded: Bool = false
    @State private var expandedEpisodeIds: Set<String> = []
    @State private var isSubscribed: Bool = false
    @State private var offlineNoticeText: String? = nil

    public init(
        podcastId: String,
        initialTitle: String? = nil,
        initialArtist: String? = nil,
        initialCover: String? = nil,
        feedUrl: String? = nil,
        serverURL: String
    ) {
        self.podcastId = podcastId
        self.initialTitle = initialTitle
        self.initialArtist = initialArtist
        self.initialCover = initialCover
        self.feedUrl = feedUrl
        self.serverURL = serverURL
    }

    private var displayTitle: String {
        if let t = feedDetail?.title, !t.isEmpty { return t }
        return initialTitle ?? "Podcast"
    }

    private var displayAuthor: String {
        if let a = feedDetail?.author, !a.isEmpty { return a }
        return initialArtist ?? ""
    }

    private var displayCover: String? {
        if let c = feedDetail?.cover, !c.isEmpty { return c }
        return initialCover
    }

    private var effectiveFeedUrl: String {
        if let f = feedDetail?.feedUrl, !f.isEmpty { return f }
        return feedUrl ?? ""
    }

    private var podcastItemModel: PodcastItem {
        PodcastItem(
            id: feedDetail?.id.isEmpty == false ? (feedDetail?.id ?? podcastId) : podcastId,
            title: displayTitle,
            artist: displayAuthor,
            feedUrl: effectiveFeedUrl,
            cover: displayCover ?? "",
            genres: [],
            trackCount: feedDetail?.episodes.count
        )
    }

    private var filteredEpisodes: [PodcastEpisodeItem] {
        let all = feedDetail?.episodes ?? []
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.title.lowercased().contains(q) || $0.description.lowercased().contains(q)
        }
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    heroHeaderCard

                    if sessionManager.isOfflineMode {
                        offlineInfoBanner
                    }

                    if let notice = offlineNoticeText {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                            Text(notice)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: { offlineNoticeText = nil }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color.white.opacity(0.65))
                            }
                        }
                        .padding(11)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if isLoading && feedDetail == nil {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else if let error = errorMessage, feedDetail == nil {
                        errorView(error)
                    } else if let detail = feedDetail {
                        episodesSection(detail: detail)
                    }

                    Spacer(minLength: 140)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .refreshable {
                await loadFeed()
            }
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .tint(.white)
        .task {
            isSubscribed = PodcastSubscriptionStore.isSubscribed(podcastItemModel)
            await loadFeed()
        }
        .onReceive(NotificationCenter.default.publisher(for: .portMusicDidReconnect)) { _ in
            Task { await loadFeed() }
        }
    }

    // MARK: - Hero Card
    private var heroHeaderCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                PortCoverImage(
                    coverUrl: displayCover,
                    serverURL: serverURL,
                    placeholderIcon: "mic.fill"
                )
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.14), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.50), radius: 12, y: 4)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("PODCAST")
                            .font(.system(size: 10.5, weight: .heavy))
                            .tracking(0.8)
                    }
                    .foregroundColor(Color.white.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())

                    Text(displayTitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(3)

                    if !displayAuthor.isEmpty {
                        Text(displayAuthor)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.65))
                            .lineLimit(2)
                    }

                    if let count = feedDetail?.episodes.count, count > 0 {
                        Text("\(count) Folgen")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.45))
                    }
                }

                Spacer(minLength: 0)
            }

            // Action Buttons
            HStack(spacing: 10) {
                Button(action: playLatestEpisode) {
                    HStack(spacing: 7) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Neueste Folge")
                            .font(.system(size: 13.5, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled((feedDetail?.episodes ?? []).isEmpty)
                .opacity((feedDetail?.episodes ?? []).isEmpty ? 0.55 : 1.0)

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    isSubscribed = PodcastSubscriptionStore.toggle(podcastItemModel)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isSubscribed ? "checkmark" : "plus")
                            .font(.system(size: 12.5, weight: .bold))
                        Text(isSubscribed ? "Abonniert" : "Abonnieren")
                            .font(.system(size: 13.5, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(isSubscribed ? Color.white.opacity(0.18) : Color.white.opacity(0.10))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())
            }

            if let desc = feedDetail?.description, !desc.isEmpty {
                let clean = stripHTML(desc)
                if !clean.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(clean)
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.70))
                            .lineSpacing(3)
                            .lineLimit(isDescriptionExpanded ? nil : 3)

                        if clean.count > 160 {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isDescriptionExpanded.toggle()
                                }
                            }) {
                                Text(isDescriptionExpanded ? "Weniger anzeigen" : "Mehr anzeigen")
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    // MARK: - Offline Banner
    private var offlineInfoBanner: some View {
        let dlCount = (feedDetail?.episodes ?? []).filter { ep in
            offlineManager.isDownloaded(trackId: "pod_\(ep.id)")
        }.count
        return HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            Text(dlCount > 0
                 ? "Offline-Modus · \(dlCount) Folgen dieses Podcasts verfügbar"
                 : "Offline-Modus · Keine Folge dieses Podcasts heruntergeladen")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(Color.white.opacity(0.85))
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    // MARK: - Episodes Section
    private func episodesSection(detail: PodcastFeedDetail) -> some View {
        let allEpisodes = detail.episodes
        let allTracks = buildEpisodeTracks(episodes: allEpisodes, detail: detail)
        let trackMap = Dictionary(uniqueKeysWithValues: zip(allEpisodes.map(\.id), allTracks))

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Alle Folgen (\(allEpisodes.count))")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }

            if allEpisodes.count > 4 {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.42))
                    TextField("Folgen durchsuchen...", text: $searchQuery)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Color.white.opacity(0.42))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.10), lineWidth: 1))
            }

            if filteredEpisodes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "waveform")
                        .font(.system(size: 30))
                        .foregroundColor(Color.white.opacity(0.30))
                    Text("Keine passenden Folgen gefunden")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredEpisodes) { ep in
                        if let tr = trackMap[ep.id] {
                            episodeRow(episode: ep, track: tr, queue: allTracks, detail: detail)
                        }
                    }
                }
            }
        }
    }

    private func episodeRow(
        episode: PodcastEpisodeItem,
        track: Track,
        queue: [Track],
        detail: PodcastFeedDetail
    ) -> some View {
        let isThisTrack = player.currentTrack?.id == track.id
        let isThisPlaying = isThisTrack && player.isPlaying
        let isDownloaded = offlineManager.isDownloaded(trackId: track.id)
        let isDownloading = offlineManager.isDownloading(trackId: track.id)
        let isUnavailableOffline = sessionManager.isOfflineMode && !isDownloaded
        let isFav = favoritesManager.isFavorite(trackId: track.id)
        let isExpanded = expandedEpisodeIds.contains(episode.id)

        let savedProg = progressStore.progress(for: track.id)
        let pos = isThisTrack ? playerProgress.currentTime : (savedProg?.positionSeconds ?? 0)
        let dur = isThisTrack
            ? (player.duration > 0 ? player.duration : Double(episode.durationSeconds))
            : (episode.durationSeconds > 0 ? Double(episode.durationSeconds) : (savedProg?.durationSeconds ?? 0))
        let isCompleted = !isThisTrack && ((savedProg?.isCompleted == true) || (dur > 30 && pos >= dur - 15))
        let hasStarted = pos > 5 && !isCompleted
        let ratio = dur > 0 ? min(1.0, max(0.0, pos / dur)) : 0
        let remaining = max(0, dur - pos)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                PortCoverImage(
                    coverUrl: offlineManager.localCoverFileURL(for: track.id)?.absoluteString
                        ?? ((episode.cover?.isEmpty == false) ? episode.cover : displayCover),
                    serverURL: serverURL,
                    placeholderIcon: "mic.fill"
                )
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.10), lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    let cleanDesc = stripHTML(episode.description)
                    if !cleanDesc.isEmpty {
                        Text(cleanDesc)
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.58))
                            .lineLimit(isExpanded ? nil : 2)

                        if cleanDesc.count > 120 {
                            Button(action: {
                                if isExpanded {
                                    expandedEpisodeIds.remove(episode.id)
                                } else {
                                    expandedEpisodeIds.insert(episode.id)
                                }
                            }) {
                                Text(isExpanded ? "Weniger" : "Mehr")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.75))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    HStack(spacing: 6) {
                        if !episode.publishedAt.isEmpty {
                            Text(formatEpisodeDate(episode.publishedAt))
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.45))
                        }

                        if isCompleted {
                            Text("·")
                                .foregroundColor(Color.white.opacity(0.35))
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Angehört")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "#10b981"))
                        } else if hasStarted {
                            Text("· noch \(formatClock(remaining))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.75))
                        } else if dur > 0 {
                            Text("· \(formatClock(dur))")
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.48))
                        }
                    }

                    if hasStarted && dur > 0 {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.16))
                                Capsule().fill(Color.white)
                                    .frame(width: max(4, g.size.width * ratio))
                            }
                        }
                        .frame(maxWidth: 140, maxHeight: 3)
                        .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                // Favorit (+)
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    let desired = !isFav
                    FavoritesManager.shared.enqueueMutation(track: track, isFavorite: desired)
                    let token = SessionManager.shared.currentToken
                    Task {
                        _ = await MusicService.shared.toggleFavorite(
                            track: track,
                            desiredState: desired,
                            serverURL: serverURL,
                            token: token
                        )
                    }
                }) {
                    Image(systemName: isFav ? "checkmark" : "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isFav ? Color(hex: "#10b981") : Color.white.opacity(0.75))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(isFav ? Color(hex: "#10b981").opacity(0.45) : Color.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())

                // Offline Download
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if isDownloaded {
                        offlineManager.removeDownload(trackId: track.id)
                    } else if !isDownloading && !sessionManager.isOfflineMode {
                        Task {
                            await offlineManager.downloadTrack(
                                track: track,
                                serverURL: serverURL,
                                token: SessionManager.shared.currentToken
                            )
                        }
                    } else if sessionManager.isOfflineMode {
                        offlineNoticeText = "Downloads benötigen eine aktive Internetverbindung."
                    }
                }) {
                    Group {
                        if isDownloading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: isDownloaded ? "arrow.down.circle.fill" : "arrow.down.circle")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(isDownloaded ? Color(hex: "#10b981") : Color.white.opacity(0.70))
                        }
                    }
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Button(action: {
                    playEpisode(episode: episode, track: track, queue: queue, detail: detail)
                }) {
                    Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .offset(x: isThisPlaying ? 0 : 1)
                        .frame(width: 38, height: 38)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(isUnavailableOffline ? 0.45 : 1.0)
            }
        }
        .padding(14)
        .background(isThisTrack ? Color.white.opacity(0.09) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isThisTrack ? Color.white.opacity(0.24) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .opacity(isUnavailableOffline ? 0.55 : 1.0)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: sessionManager.isOfflineMode ? "wifi.slash" : "mic.slash")
                .font(.system(size: 36))
                .foregroundColor(Color.white.opacity(0.35))
            Text(error)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.65))
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") {
                Task { await loadFeed() }
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Playback & Data
    private func buildEpisodeTracks(episodes: [PodcastEpisodeItem], detail: PodcastFeedDetail) -> [Track] {
        let safeQueryChars = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+?#"))
        return episodes.compactMap { ep in
            guard !ep.audioUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let encoded = ep.audioUrl.addingPercentEncoding(withAllowedCharacters: safeQueryChars) ?? ep.audioUrl
            let mins = ep.durationSeconds / 60
            let secs = ep.durationSeconds % 60
            let formatted = String(format: "%d:%02d", mins, secs)
            let rawCover = (ep.cover?.isEmpty == false) ? ep.cover : detail.cover
            return Track(
                id: "pod_\(ep.id)",
                title: ep.title,
                artist: detail.title,
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

    private func playLatestEpisode() {
        guard let detail = feedDetail, let first = detail.episodes.first else { return }
        let tracks = buildEpisodeTracks(episodes: detail.episodes, detail: detail)
        guard let firstTrack = tracks.first else { return }
        playEpisode(episode: first, track: firstTrack, queue: tracks, detail: detail)
    }

    private func playEpisode(
        episode: PodcastEpisodeItem,
        track: Track,
        queue: [Track],
        detail: PodcastFeedDetail
    ) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if sessionManager.isOfflineMode && !offlineManager.isDownloaded(trackId: track.id) {
            offlineNoticeText = "Diese Folge ist nicht heruntergeladen und offline nicht abspielbar."
            return
        }

        if player.currentTrack?.id == track.id {
            player.togglePlayPause()
            return
        }

        PodcastProgressStore.shared.setActivePodcastContext(
            trackId: track.id,
            podcastId: detail.id.isEmpty ? podcastId : detail.id,
            podcastTitle: detail.title,
            feedUrl: detail.feedUrl.isEmpty ? feedUrl : detail.feedUrl,
            audioUrl: episode.audioUrl
        )

        let prog = progressStore.progress(for: track.id)
        let startAt: Double? = (prog != nil && !(prog?.isCompleted ?? false) && (prog?.positionSeconds ?? 0) > 5)
            ? prog?.positionSeconds
            : nil

        player.play(track: track, from: queue, serverURL: serverURL, startAt: startAt)
    }

    private func loadFeed() async {
        isLoading = true
        errorMessage = nil
        let token = SessionManager.shared.currentToken
        let detail = await MusicService.shared.fetchPodcastFeed(
            id: podcastId,
            feedUrl: feedUrl,
            serverURL: serverURL,
            token: token
        )
        await MainActor.run {
            self.feedDetail = detail
            self.isLoading = false
            if detail == nil {
                self.errorMessage = sessionManager.isOfflineMode
                    ? "Dieser Podcast wurde noch nicht zwischengespeichert."
                    : "Podcast-Feed konnte nicht geladen werden."
            } else {
                self.isSubscribed = PodcastSubscriptionStore.isSubscribed(self.podcastItemModel)
            }
        }
    }

    private func stripHTML(_ raw: String) -> String {
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

    private func formatClock(_ totalSeconds: Double) -> String {
        let s = max(0, Int(totalSeconds))
        let hours = s / 3600
        let mins = (s % 3600) / 60
        if hours > 0 {
            return mins > 0 ? "\(hours) Std. \(mins) Min." : "\(hours) Std."
        }
        return "\(max(1, mins)) Min."
    }

    private func formatEpisodeDate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 10 {
            return String(trimmed.prefix(10))
        }
        return trimmed
    }
}
