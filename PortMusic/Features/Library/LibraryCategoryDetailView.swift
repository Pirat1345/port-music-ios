import SwiftUI

// MARK: - Library Category Detail View (Web Library Subpages Parity)
public struct LibraryCategoryDetailView: View {
    public let category: String
    public let serverURL: String

    private enum PlaylistSort: String, CaseIterable {
        case recents = "Zuletzt"
        case alphabetical = "Alphabetisch"
        case creator = "Ersteller"
    }

    private enum HistoryFilter: String, CaseIterable {
        case all = "Alle"
        case favorites = "Favoriten"
        case downloads = "Downloads"
    }

    private enum TrackSort: String, CaseIterable {
        case recent = "Zuletzt"
        case title = "Titel"
        case artist = "Künstler"
        case album = "Album"
    }

    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared

    @State private var playlists: [DiscoveryPlaylist] = []
    @State private var folders: [LibraryFolder] = []
    @State private var pinnedIds: Set<String> = []
    @State private var artists: [DiscoveryArtist] = []
    @State private var tracks: [Track] = []
    @State private var favoriteIds: Set<String> = []
    @State private var isLoading: Bool = true
    @State private var searchQuery: String = ""

    @State private var playlistSort: PlaylistSort = .recents
    @State private var historyFilter: HistoryFilter = .all
    @State private var trackSort: TrackSort = .recent

    @State private var showCreatePlaylistSheet: Bool = false
    @State private var showImportPlaylistSheet: Bool = false

    public init(category: String, serverURL: String) {
        self.category = category
        self.serverURL = serverURL
    }

    private var normalizedCategory: String {
        switch category {
        case "playlists", "Playlists", "Wiedergabelisten": return "playlists"
        case "artists", "Artists", "Künstler": return "artists"
        case "albums", "Albums", "Alben": return "albums"
        case "radio", "Radio": return "radio"
        case "songs", "Songs", "Titel": return "songs"
        case "downloaded", "Downloads", "Heruntergeladen": return "downloaded"
        case "local-files", "Lokale Dateien", "Local Files": return "local-files"
        case "history", "recently-played", "Verlauf", "Zuletzt gehört": return "history"
        default: return category.lowercased()
        }
    }

    private var viewTitle: String {
        switch normalizedCategory {
        case "playlists": return "Playlists"
        case "artists": return "Künstler"
        case "albums": return "Alben"
        case "radio": return "Radio"
        case "songs": return "Songs"
        case "downloaded": return "Heruntergeladen"
        case "local-files": return "Lokale Dateien"
        case "history": return "Zuletzt gehört"
        default: return category
        }
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if normalizedCategory == "radio" {
                LibraryRadioView(serverURL: serverURL)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
            } else if normalizedCategory == "local-files" {
                LibraryLocalFilesView(serverURL: serverURL)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if normalizedCategory != "albums" {
                            searchBarSection
                                .padding(.horizontal, 20)
                                .padding(.top, 14)
                        } else {
                            Spacer().frame(height: 6)
                        }

                        categoryContentSection
                            .padding(.horizontal, 20)

                        Spacer(minLength: 120)
                    }
                }
                .refreshable {
                    await loadCategoryData()
                }
            }
        }
        .navigationTitle(viewTitle)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .tint(.white)
        .task {
            await loadCategoryData()
        }
        .onChange(of: offlineManager.downloadedTrackIds) { _ in
            if normalizedCategory == "downloaded" {
                self.tracks = offlineManager.allDownloadedTracks()
            }
        }
        .sheet(isPresented: $showCreatePlaylistSheet) {
            CreatePlaylistSheet(serverURL: serverURL) { created in
                playlists.insert(created, at: 0)
            }
        }
        .sheet(isPresented: $showImportPlaylistSheet) {
            ImportPlaylistSheet(serverURL: serverURL) { imported in
                playlists.insert(imported, at: 0)
            }
        }
    }

    // MARK: - Search Bar
    private var searchBarSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.40))

            TextField("\(viewTitle) durchsuchen...", text: $searchQuery)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .autocorrectionDisabled()

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.40))
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

    // MARK: - Category Content Switcher
    @ViewBuilder
    private var categoryContentSection: some View {
        switch normalizedCategory {
        case "playlists":
            playlistsView
        case "artists":
            artistsView
        case "albums":
            LibraryAlbumsView(serverURL: serverURL)
        case "songs", "downloaded", "history":
            tracksListView
        default:
            tracksListView
        }
    }

    // MARK: - Playlists View
    private var sortedPlaylists: [DiscoveryPlaylist] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = q.isEmpty ? playlists : playlists.filter { $0.title.lowercased().contains(q) }
        return base.sorted { a, b in
            let pinA = pinnedIds.contains(a.id)
            let pinB = pinnedIds.contains(b.id)
            if pinA != pinB { return pinA }
            switch playlistSort {
            case .recents:
                return false
            case .alphabetical:
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case .creator:
                let uA = a.user ?? "Port Music"
                let uB = b.user ?? "Port Music"
                return uA.localizedCaseInsensitiveCompare(uB) == .orderedAscending
            }
        }
    }

    private var playlistsView: some View {
        let items = sortedPlaylists

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(PlaylistSort.allCases, id: \.self) { mode in
                        Button(action: { playlistSort = mode }) {
                            Label(mode.rawValue, systemImage: playlistSort == mode ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12, weight: .semibold))
                        Text(playlistSort.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }

                Spacer()

                Button(action: { showImportPlaylistSheet = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Importieren")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { showCreatePlaylistSheet = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Neu")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }

            if !folders.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(folders) { folder in
                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#fc3c44"))
                                Text(folder.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.10), lineWidth: 1))
                        }
                    }
                }
            }

            if isLoading && playlists.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
            } else if items.isEmpty {
                emptyPlaceholder(icon: "music.note.list", message: "Keine Playlists gefunden")
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 16
                ) {
                    ForEach(items) { pl in
                        NavigationLink(value: AppRoute.playlist(
                            id: pl.id,
                            title: pl.title,
                            coverUrl: pl.cover
                        )) {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .topTrailing) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: "#18181b"))
                                        .aspectRatio(1, contentMode: .fit)

                                    let resolved = resolveCoverURL(pl.cover, serverURL: serverURL)
                                    PortCachedAsyncImage(url: resolved) { img in
                                        img
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    } placeholder: {
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 32))
                                            .foregroundColor(Color.white.opacity(0.25))
                                    }

                                    if pinnedIds.contains(pl.id) {
                                        Image(systemName: "pin.fill")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background(Color.black.opacity(0.65))
                                            .clipShape(Circle())
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

                                Text(pl.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                let count = pl.nbTracks.map { "\($0) Songs" } ?? "Playlist"
                                Text(count)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#a0a0a0"))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Artists View
    private var artistsView: some View {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = q.isEmpty ? artists : artists.filter { $0.name.lowercased().contains(q) }

        return Group {
            if isLoading && artists.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
            } else if filtered.isEmpty {
                emptyPlaceholder(icon: "person.2", message: "Noch keine Künstler in deiner Mediathek")
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 16
                ) {
                    ForEach(filtered) { artist in
                        NavigationLink(value: AppRoute.artist(name: artist.name, coverUrl: artist.picture)) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "#18181b"))
                                        .frame(width: 90, height: 90)

                                    let resolved = resolveCoverURL(artist.picture, serverURL: serverURL)
                                    PortCachedAsyncImage(url: resolved) { img in
                                        img
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 90, height: 90)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(Color.white.opacity(0.30))
                                    }
                                }
                                .frame(width: 90, height: 90)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.40), radius: 6, y: 3)

                                Text(artist.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Tracks List View (Songs, Downloaded, History)
    private var processedTracks: [Track] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result = tracks

        if normalizedCategory == "history" {
            switch historyFilter {
            case .all:
                break
            case .favorites:
                result = result.filter { favoriteIds.contains($0.id) || FavoritesManager.shared.isFavorite(trackId: $0.id) }
            case .downloads:
                result = result.filter { offlineManager.isDownloaded(trackId: $0.id) }
            }
        }

        if !q.isEmpty {
            result = result.filter {
                $0.title.lowercased().contains(q)
                || $0.artist.lowercased().contains(q)
                || ($0.album?.lowercased().contains(q) ?? false)
            }
        }

        switch trackSort {
        case .recent:
            break
        case .title:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .artist:
            result.sort { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
        case .album:
            result.sort { ($0.album ?? "").localizedCaseInsensitiveCompare($1.album ?? "") == .orderedAscending }
        }

        return result
    }

    private var tracksListView: some View {
        let filtered = processedTracks

        return VStack(alignment: .leading, spacing: 12) {
            if normalizedCategory == "history" {
                HStack(spacing: 8) {
                    ForEach(HistoryFilter.allCases, id: \.self) { f in
                        Button(action: { historyFilter = f }) {
                            Text(f.rawValue)
                                .font(.system(size: 13, weight: historyFilter == f ? .semibold : .medium))
                                .foregroundColor(historyFilter == f ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(historyFilter == f ? Color.white : Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer()

                    Menu {
                        ForEach(TrackSort.allCases, id: \.self) { s in
                            Button(action: { trackSort = s }) {
                                Label(s.rawValue, systemImage: trackSort == s ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 11, weight: .semibold))
                            Text(trackSort.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                }
            }

            if !filtered.isEmpty {
                HStack(spacing: 12) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if let first = filtered.first {
                            player.play(track: first, from: filtered, serverURL: serverURL)
                        }
                    }) {
                        HStack(spacing: 7) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Abspielen")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        let shuffled = filtered.shuffled()
                        if let first = shuffled.first {
                            player.play(track: first, from: shuffled, serverURL: serverURL)
                        }
                    }) {
                        HStack(spacing: 7) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 13, weight: .bold))
                            Text("Zufallswiedergabe")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if isLoading && tracks.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
            } else if filtered.isEmpty {
                emptyPlaceholder(icon: "music.note", message: "Keine Titel vorhanden")
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, track in
                        TrackRowView(
                            track: track,
                            index: index,
                            contextQueue: filtered,
                            serverURL: serverURL,
                            isLiked: favoriteIds.contains(track.id) || FavoritesManager.shared.isFavorite(trackId: track.id),
                            isDownloaded: offlineManager.isDownloaded(trackId: track.id),
                            showCover: true,
                            showTrackNumber: false
                        )
                    }
                }
            }
        }
    }

    private func emptyPlaceholder(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(Color.white.opacity(0.30))
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.60))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    // MARK: - Load Category Data
    private func loadCategoryData() async {
        isLoading = true
        let token = SessionManager.shared.currentToken

        switch normalizedCategory {
        case "playlists":
            async let plsTask = MusicService.shared.fetchPlaylists(serverURL: serverURL, token: token)
            async let colTask = MusicService.shared.fetchLibraryCollections(serverURL: serverURL, token: token)
            let (userPls, collections) = await (plsTask, colTask)
            let mergedPls = userPls.isEmpty ? collections.playlists : userPls
            await MainActor.run {
                self.playlists = mergedPls
                self.folders = collections.folders
                self.pinnedIds = Set(collections.pinnedPlaylists)
                self.isLoading = false
            }

        case "artists":
            async let colTask = MusicService.shared.fetchLibraryCollections(serverURL: serverURL, token: token)
            async let favTask = MusicService.shared.fetchFavorites(serverURL: serverURL, token: token)
            let (collections, favs) = await (colTask, favTask)

            var artistList: [DiscoveryArtist] = []
            var seen = Set<String>()
            let allLibraryTracks = collections.favorites + favs + collections.globalTracks + collections.playlistTracksMap.values.flatMap { $0 }

            func addArtistName(_ rawName: String, preferredCover: String? = nil) {
                let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, name.lowercased() != "unbekannter interpret" else { return }
                let key = name.lowercased()
                guard !seen.contains(key) else { return }
                seen.insert(key)
                let fallbackCover = preferredCover ?? allLibraryTracks.first(where: { $0.artist.lowercased() == key })?.coverUrl
                artistList.append(DiscoveryArtist(id: "art_\(key.hashValue)", name: name, picture: fallbackCover, nbFan: nil))
            }

            for savedName in collections.savedArtists {
                addArtistName(savedName)
            }
            for tr in allLibraryTracks {
                addArtistName(tr.artist, preferredCover: tr.coverUrl)
            }

            await MainActor.run {
                self.artists = artistList
                self.isLoading = false
            }

            // Enrich missing artist portraits via discovery artist endpoint
            let needCover = artistList.prefix(12).filter { ($0.picture?.isEmpty ?? true) }
            for art in needCover {
                if let detail = await MusicService.shared.fetchArtist(name: art.name, serverURL: serverURL, token: token),
                   let pic = detail.picture, !pic.isEmpty {
                    await MainActor.run {
                        if let idx = self.artists.firstIndex(where: { $0.name.lowercased() == art.name.lowercased() }) {
                            let existing = self.artists[idx]
                            self.artists[idx] = DiscoveryArtist(id: existing.id, name: existing.name, picture: pic, nbFan: detail.nbFan)
                        }
                    }
                }
            }

        case "songs":
            async let colTask = MusicService.shared.fetchLibraryCollections(serverURL: serverURL, token: token)
            async let favTask = MusicService.shared.fetchFavorites(serverURL: serverURL, token: token)
            async let localFilesTask = MusicService.shared.fetchLocalAudioFiles(serverURL: serverURL, token: token)
            let (collections, favs, localFiles) = await (colTask, favTask, localFilesTask)

            let downloaded = OfflineDownloadManager.shared.allDownloadedTracks()
            let playlistTracks = collections.playlistTracksMap.values.flatMap { $0 }
            let mergedFavs = favs.isEmpty ? collections.favorites : favs
            self.favoriteIds = Set(mergedFavs.map { $0.id })

            var combined: [Track] = []
            var seen = Set<String>()
            for t in (downloaded + localFiles + mergedFavs + collections.globalTracks + playlistTracks) {
                if !seen.contains(t.id) {
                    seen.insert(t.id)
                    combined.append(t)
                }
            }
            await MainActor.run {
                self.tracks = combined
                self.isLoading = false
            }

        case "downloaded":
            let downloaded = OfflineDownloadManager.shared.allDownloadedTracks()
            await MainActor.run {
                self.tracks = downloaded
                self.isLoading = false
            }

        case "history":
            async let histTask = MusicService.shared.fetchStatsAndHistory(serverURL: serverURL, token: token)
            async let favTask = MusicService.shared.fetchFavorites(serverURL: serverURL, token: token)
            let (hists, favs) = await (histTask, favTask)
            let localRecent = AudioPlayerManager.shared.recentTracks
            var combined: [Track] = []
            var seen = Set<String>()
            for t in (localRecent + hists) {
                if !seen.contains(t.id) {
                    seen.insert(t.id)
                    combined.append(t)
                }
            }
            await MainActor.run {
                self.favoriteIds = Set(favs.map { $0.id })
                self.tracks = combined
                self.isLoading = false
            }

        default:
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
