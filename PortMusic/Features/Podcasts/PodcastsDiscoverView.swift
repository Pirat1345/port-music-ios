import SwiftUI

// MARK: - Apple-Style Podcasts Discover View (Web PodcastsPage.tsx Parity + Offline Mode)
public struct PodcastsDiscoverView: View {
    public let serverURL: String
    public let embeddedInLibrary: Bool

    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var progressStore = PodcastProgressStore.shared

    @State private var searchQuery: String = ""
    @State private var subscribed: [PodcastItem] = []
    @State private var shelfItems: [Int: [PodcastItem]] = [:]
    @State private var searchResults: [PodcastItem]? = nil
    @State private var resolvedLinkPodcast: PodcastItem? = nil
    @State private var navigateToResolved: Bool = false

    @State private var isLoadingShelves: Bool = true
    @State private var isSearching: Bool = false
    @State private var isResolvingLink: Bool = false
    @State private var statusBannerMessage: String? = nil
    @State private var searchDebounceTask: Task<Void, Never>? = nil

    public init(serverURL: String, embeddedInLibrary: Bool = false) {
        self.serverURL = serverURL
        self.embeddedInLibrary = embeddedInLibrary
    }

    private var downloadedEpisodes: [Track] {
        offlineManager.allDownloadedPodcastEpisodes()
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                if !embeddedInLibrary {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Podcasts")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        Text("Top-Shows, neue Folgen und deine heruntergeladenen Episoden")
                            .font(.system(size: 13.5))
                            .foregroundColor(Color.white.opacity(0.55))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }

                if sessionManager.isOfflineMode {
                    offlineBanner
                        .padding(.horizontal, embeddedInLibrary ? 0 : 20)
                }

                if let msg = statusBannerMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                        Text(msg)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { statusBannerMessage = nil }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, embeddedInLibrary ? 0 : 20)
                }

                // Weiterhören-Karte (wie PodcastResumeCard.tsx)
                if let resume = progressStore.resumeInfo {
                    resumeBannerCard(resume)
                        .padding(.horizontal, embeddedInLibrary ? 0 : 20)
                }

                // Suchleiste & Link-Resolver
                searchAndPillsSection

                if let results = searchResults {
                    searchResultsSection(results)
                } else {
                    // Offline heruntergeladene Podcast-Folgen
                    if !downloadedEpisodes.isEmpty {
                        downloadedEpisodesSection
                    }

                    // Abonnierte Podcasts
                    if !subscribed.isEmpty {
                        subscribedSection
                    }

                    // Themen-Shelves (Gesellschaft, Comedy, True Crime, Gesundheit, Nachrichten)
                    ForEach(PodcastCategories.discoverShelves, id: \.genreId) { shelf in
                        podcastShelfSection(
                            genreId: shelf.genreId,
                            title: "Top-Podcasts: \(shelf.title)",
                            subtitle: shelf.subtitle
                        )
                    }

                    // Alle 16 Apple-Podcast-Kategorien
                    categoriesGridSection
                }

                Spacer(minLength: 150)
            }
            .padding(.top, embeddedInLibrary ? 2 : 0)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationDestination(isPresented: $navigateToResolved) {
            if let pod = resolvedLinkPodcast {
                PodcastDetailView(
                    podcastId: pod.id,
                    initialTitle: pod.title,
                    initialArtist: pod.artist,
                    initialCover: pod.cover,
                    feedUrl: pod.feedUrl,
                    serverURL: serverURL
                )
            }
        }
        .refreshable {
            subscribed = PodcastSubscriptionStore.load()
            await loadAllShelves()
        }
        .task {
            subscribed = PodcastSubscriptionStore.load()
            await loadAllShelves()
        }
        .onAppear {
            subscribed = PodcastSubscriptionStore.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .portMusicDidReconnect)) { _ in
            Task { await loadAllShelves() }
        }
    }

    // MARK: - Offline Banner
    private var offlineBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline-Modus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text(downloadedEpisodes.isEmpty
                     ? "Lade Folgen im WLAN herunter, um sie offline zu hören."
                     : "\(downloadedEpisodes.count) heruntergeladene Folgen offline verfügbar")
                    .font(.system(size: 11.5))
                    .foregroundColor(Color.white.opacity(0.65))
            }
            Spacer()
            Button("Verbinden") {
                Task {
                    _ = await sessionManager.retryConnection()
                    await loadAllShelves()
                }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Color.white)
            .clipShape(Capsule())
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Resume Banner Card
    private func resumeBannerCard(_ resume: PodcastResumeInfo) -> some View {
        let remaining = max(0, resume.durationSeconds - resume.positionSeconds)
        let pct = min(1.0, max(0.0, resume.progress))
        let isOfflineAvailable = offlineManager.isDownloaded(trackId: resume.episodeId)
        let canPlayNow = !sessionManager.isOfflineMode || isOfflineAvailable

        return HStack(spacing: 12) {
            NavigationLink(value: AppRoute.podcast(
                id: resume.podcastId,
                title: resume.podcastTitle,
                artist: nil,
                coverUrl: resume.cover,
                feedUrl: resume.podcastFeedUrl
            )) {
                HStack(spacing: 12) {
                    PortCoverImage(
                        coverUrl: resume.cover,
                        serverURL: serverURL,
                        placeholderIcon: "mic.fill"
                    )
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("WEITERHÖREN · \(resume.podcastTitle)")
                            .font(.system(size: 10.5, weight: .bold))
                            .tracking(0.6)
                            .foregroundColor(Color.white.opacity(0.55))
                            .lineLimit(1)

                        Text(resume.episodeTitle)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.14))
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(width: max(4, g.size.width * pct))
                                }
                            }
                            .frame(maxWidth: 110, maxHeight: 3.5)

                            if resume.durationSeconds > 0 {
                                Text("noch \(formatShortRemaining(remaining))")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.white.opacity(0.55))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer(minLength: 4)

            Button(action: {
                guard canPlayNow else {
                    statusBannerMessage = "Diese Folge wurde noch nicht für den Offline-Modus heruntergeladen."
                    return
                }
                resumePodcastEpisode(resume)
            }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .offset(x: 1)
                    .frame(width: 38, height: 38)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(canPlayNow ? 1.0 : 0.45)

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                progressStore.clearResume()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Search & Category Pills
    private var searchAndPillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.45))

                TextField("Podcasts suchen oder Link einfügen...", text: $searchQuery)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .tint(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onChange(of: searchQuery) { newVal in
                        scheduleSearchOrResolve(newVal)
                    }
                    .onSubmit {
                        Task { await performSearchOrResolve(searchQuery) }
                    }

                if isSearching || isResolvingLink {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        searchResults = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color.white.opacity(0.45))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(hex: "#18181b"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
            .padding(.horizontal, embeddedInLibrary ? 0 : 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PodcastCategories.all.prefix(8)) { genre in
                        NavigationLink(value: AppRoute.podcastCategory(
                            genreId: genre.id,
                            title: genre.name,
                            subtitle: genre.description
                        )) {
                            Text(genre.name)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.85))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, embeddedInLibrary ? 0 : 20)
            }
        }
    }

    // MARK: - Downloaded Episodes Section (Offline Ready)
    private var downloadedEpisodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#10b981"))
                    Text("Heruntergeladene Folgen")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("\(downloadedEpisodes.count)")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.45))
            }
            .padding(.horizontal, embeddedInLibrary ? 0 : 20)

            VStack(spacing: 8) {
                ForEach(downloadedEpisodes.prefix(6)) { track in
                    let isPlayingThis = player.currentTrack?.id == track.id && player.isPlaying
                    let prog = progressStore.progress(for: track.id)
                    let resumePos = (prog != nil && !(prog?.isCompleted ?? false) && (prog?.positionSeconds ?? 0) > 5) ? prog?.positionSeconds : nil

                    HStack(spacing: 12) {
                        PortCoverImage(
                            coverUrl: offlineManager.localCoverFileURL(for: track.id)?.absoluteString ?? track.coverUrl,
                            serverURL: serverURL,
                            placeholderIcon: "mic.fill"
                        )
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            HStack(spacing: 6) {
                                Text(track.artist)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.white.opacity(0.55))
                                    .lineLimit(1)

                                if let p = prog, !p.isCompleted, p.durationSeconds > 0 {
                                    Text("· noch \(formatShortRemaining(max(0, p.durationSeconds - p.positionSeconds)))")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(Color.white.opacity(0.50))
                                        .lineLimit(1)
                                } else if !track.duration.isEmpty && track.duration != "0:00" {
                                    Text("· \(track.duration)")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(Color.white.opacity(0.45))
                                }
                            }
                        }

                        Spacer()

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if player.currentTrack?.id == track.id {
                                player.togglePlayPause()
                            } else {
                                player.play(track: track, from: downloadedEpisodes, serverURL: serverURL, startAt: resumePos)
                            }
                        }) {
                            Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.black)
                                .offset(x: isPlayingThis ? 0 : 1)
                                .frame(width: 34, height: 34)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .contextMenu {
                        Button(role: .destructive) {
                            offlineManager.removeDownload(trackId: track.id)
                        } label: {
                            Label("Download entfernen", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, embeddedInLibrary ? 0 : 20)
        }
    }

    // MARK: - Subscribed Section
    private var subscribedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.70))
                Text("Meine Podcasts")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, embeddedInLibrary ? 0 : 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(subscribed) { pod in
                        podcastSquareCard(pod)
                    }
                }
                .padding(.horizontal, embeddedInLibrary ? 0 : 20)
            }
        }
    }

    // MARK: - Topic Shelves
    private func podcastShelfSection(genreId: Int, title: String, subtitle: String) -> some View {
        let items = shelfItems[genreId] ?? []
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.50))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                NavigationLink(value: AppRoute.podcastCategory(
                    genreId: genreId,
                    title: title.replacingOccurrences(of: "Top-Podcasts: ", with: ""),
                    subtitle: subtitle
                )) {
                    HStack(spacing: 3) {
                        Text("Alle")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(Color.white.opacity(0.65))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, embeddedInLibrary ? 0 : 20)

            if isLoadingShelves && items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(0..<4, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 148, height: 148)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 120, height: 12)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.05))
                                    .frame(width: 85, height: 10)
                            }
                        }
                    }
                    .padding(.horizontal, embeddedInLibrary ? 0 : 20)
                }
            } else if !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(items) { pod in
                            podcastSquareCard(pod)
                        }
                    }
                    .padding(.horizontal, embeddedInLibrary ? 0 : 20)
                }
            }
        }
    }

    // MARK: - Search Results Section
    private func searchResultsSection(_ results: [PodcastItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Suchergebnisse (\(results.count))")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, embeddedInLibrary ? 0 : 20)

            if results.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: sessionManager.isOfflineMode ? "wifi.slash" : "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(Color.white.opacity(0.30))
                    Text(sessionManager.isOfflineMode
                         ? "Suche erfordert eine Internetverbindung"
                         : "Keine Podcasts für \"\(searchQuery)\" gefunden")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 44)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                    spacing: 16
                ) {
                    ForEach(results) { pod in
                        podcastGridCard(pod)
                    }
                }
                .padding(.horizontal, embeddedInLibrary ? 0 : 20)
            }
        }
    }

    // MARK: - Categories Grid
    private var categoriesGridSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Kategorien")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, embeddedInLibrary ? 0 : 20)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(PodcastCategories.all) { genre in
                    NavigationLink(value: AppRoute.podcastCategory(
                        genreId: genre.id,
                        title: genre.name,
                        subtitle: genre.description
                    )) {
                        HStack(spacing: 10) {
                            Image(systemName: genre.iconName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: genre.accentHex))
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text(genre.name)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 2)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.30))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, embeddedInLibrary ? 0 : 20)
        }
    }

    // MARK: - Shared Cards
    private func podcastSquareCard(_ pod: PodcastItem) -> some View {
        NavigationLink(value: AppRoute.podcast(
            id: pod.id,
            title: pod.title,
            artist: pod.artist,
            coverUrl: pod.cover,
            feedUrl: pod.feedUrl.isEmpty ? nil : pod.feedUrl
        )) {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    PortCoverImage(
                        coverUrl: pod.cover,
                        serverURL: serverURL,
                        placeholderIcon: "mic.fill"
                    )
                    .frame(width: 148, height: 148)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.35), radius: 8, y: 3)

                    if subscribed.contains(where: { $0.id == pod.id }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.65)))
                            .padding(7)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(pod.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(width: 148, alignment: .leading)

                    Text(pod.artist.isEmpty ? "Podcast" : pod.artist)
                        .font(.system(size: 11.5))
                        .foregroundColor(Color.white.opacity(0.55))
                        .lineLimit(1)
                        .frame(width: 148, alignment: .leading)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func podcastGridCard(_ pod: PodcastItem) -> some View {
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

                    if subscribed.contains(where: { $0.id == pod.id }) {
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

    // MARK: - Actions & Data Loading
    private func loadAllShelves() async {
        isLoadingShelves = true
        let token = SessionManager.shared.currentToken

        // Zuerst zwischengespeicherte Charts anzeigen, damit offline & beim Start sofort Inhalte erscheinen
        var initialMap: [Int: [PodcastItem]] = [:]
        for shelf in PodcastCategories.discoverShelves {
            let cached = MusicService.shared.cachedPodcastCharts(genre: shelf.genreId)
            if !cached.isEmpty {
                initialMap[shelf.genreId] = cached
            }
        }
        if !initialMap.isEmpty {
            await MainActor.run {
                self.shelfItems = initialMap
            }
        }

        if sessionManager.isOfflineMode {
            await MainActor.run { self.isLoadingShelves = false }
            return
        }

        await withTaskGroup(of: (Int, [PodcastItem]).self) { group in
            for shelf in PodcastCategories.discoverShelves {
                group.addTask {
                    let items = await MusicService.shared.fetchPodcastCharts(
                        genre: shelf.genreId,
                        limit: 12,
                        serverURL: serverURL,
                        token: token
                    )
                    return (shelf.genreId, items)
                }
            }
            var updated = initialMap
            for await (gId, items) in group {
                if !items.isEmpty {
                    updated[gId] = items
                }
            }
            await MainActor.run {
                self.shelfItems = updated
                self.isLoadingShelves = false
            }
        }
    }

    private func scheduleSearchOrResolve(_ query: String) {
        searchDebounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = nil
            isSearching = false
            return
        }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            searchDebounceTask = Task { await performSearchOrResolve(trimmed) }
            return
        }
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await performSearchOrResolve(trimmed)
        }
    }

    private func performSearchOrResolve(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let token = SessionManager.shared.currentToken

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            guard !sessionManager.isOfflineMode else {
                await MainActor.run {
                    self.statusBannerMessage = "Links können nur mit aktiver Internetverbindung aufgelöst werden."
                }
                return
            }
            await MainActor.run { self.isResolvingLink = true }
            let resolved = await MusicService.shared.resolvePodcastURL(url: trimmed, serverURL: serverURL, token: token)
            await MainActor.run {
                self.isResolvingLink = false
                if let feed = resolved?.feedUrl, !feed.isEmpty {
                    let pod = PodcastItem(
                        id: "custom_\(abs(feed.hashValue))",
                        title: resolved?.title ?? "Podcast",
                        artist: resolved?.artist ?? "",
                        feedUrl: feed,
                        cover: resolved?.cover ?? ""
                    )
                    self.resolvedLinkPodcast = pod
                    self.navigateToResolved = true
                } else {
                    self.statusBannerMessage = resolved?.message ?? "Podcast-Link konnte nicht aufgelöst werden."
                }
            }
            return
        }

        await MainActor.run { self.isSearching = true }
        let res = await MusicService.shared.searchPodcasts(query: trimmed, serverURL: serverURL, token: token)
        await MainActor.run {
            self.searchResults = res
            self.isSearching = false
        }
    }

    private func resumePodcastEpisode(_ resume: PodcastResumeInfo) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let safeQueryChars = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+?#"))
        let rawAudio = resume.audioUrl ?? ""
        let streamPath: String?
        if rawAudio.hasPrefix("/api/podcasts/stream") {
            streamPath = rawAudio
        } else if !rawAudio.isEmpty {
            let encoded = rawAudio.addingPercentEncoding(withAllowedCharacters: safeQueryChars) ?? rawAudio
            streamPath = "/api/podcasts/stream?url=\(encoded)"
        } else {
            streamPath = nil
        }

        let mins = Int(resume.durationSeconds) / 60
        let secs = Int(resume.durationSeconds) % 60
        let track = Track(
            id: resume.episodeId,
            title: resume.episodeTitle,
            artist: resume.podcastTitle,
            album: "Podcast",
            duration: resume.durationSeconds > 0 ? String(format: "%d:%02d", mins, secs) : "0:00",
            durationSeconds: resume.durationSeconds,
            coverUrl: resume.cover,
            isLive: false,
            isExplicit: false,
            sourceUrl: streamPath
        )
        PodcastProgressStore.shared.setActivePodcastContext(
            trackId: track.id,
            podcastId: resume.podcastId,
            podcastTitle: resume.podcastTitle,
            feedUrl: resume.podcastFeedUrl,
            audioUrl: resume.audioUrl
        )
        player.play(track: track, from: [track], serverURL: serverURL, startAt: resume.positionSeconds)
    }

    private func formatShortRemaining(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        let hrs = s / 3600
        let mins = (s % 3600) / 60
        if hrs > 0 {
            return "\(hrs) Std. \(mins) Min."
        }
        return "\(max(1, mins)) Min."
    }
}
