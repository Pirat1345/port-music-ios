import SwiftUI

// MARK: - Library Category Detail View (Web Library Subpages Parity)
public struct LibraryCategoryDetailView: View {
    public let category: String
    public let serverURL: String

    private enum PlaylistViewMode: String, CaseIterable {
        case grid = "Raster"
        case list = "Liste"
    }

    private enum PlaylistSort: String, CaseIterable {
        case title = "Titel"
        case dateAdded = "Hinzugefügt am"
        case lastPlayed = "Letztes Abspieldatum"
        case newestDate = "Aktuellstes Datum"
        case playlistType = "Art der Playlist"
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
    @State private var pinnedFolderIds: Set<String> = []
    @State private var selectedFolderId: String? = nil
    @State private var artists: [DiscoveryArtist] = []
    @State private var tracks: [Track] = []
    @State private var favoriteIds: Set<String> = []
    @State private var isLoading: Bool = true
    @State private var searchQuery: String = ""

    @AppStorage("library_playlists_view_mode") private var playlistViewModeRaw: String = PlaylistViewMode.grid.rawValue
    @AppStorage("library_playlists_sort") private var playlistSortRaw: String = PlaylistSort.newestDate.rawValue
    @State private var historyFilter: HistoryFilter = .all
    @State private var trackSort: TrackSort = .recent

    private var playlistViewMode: PlaylistViewMode {
        PlaylistViewMode(rawValue: playlistViewModeRaw) ?? .grid
    }

    private var playlistSort: PlaylistSort {
        PlaylistSort(rawValue: playlistSortRaw) ?? .newestDate
    }

    private var playlistViewModeBinding: Binding<PlaylistViewMode> {
        Binding(
            get: { playlistViewMode },
            set: { newValue in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                playlistViewModeRaw = newValue.rawValue
            }
        )
    }

    private var playlistSortBinding: Binding<PlaylistSort> {
        Binding(
            get: { playlistSort },
            set: { newValue in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                playlistSortRaw = newValue.rawValue
            }
        )
    }

    @State private var showCreatePlaylistSheet: Bool = false
    @State private var showImportPlaylistSheet: Bool = false
    @State private var showCreateFolderAlert: Bool = false
    @State private var newFolderName: String = ""

    public init(category: String, serverURL: String) {
        self.category = category
        self.serverURL = serverURL
    }

    private var normalizedCategory: String {
        switch category {
        case "playlists", "Playlists", "Wiedergabelisten": return "playlists"
        case "artists", "Artists", "Künstler": return "artists"
        case "albums", "Albums", "Alben": return "albums"
        case "podcasts", "Podcasts": return "podcasts"
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
        case "podcasts": return "Podcasts"
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
            } else if normalizedCategory == "podcasts" {
                LibraryPodcastsView(serverURL: serverURL)
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
                                .padding(.top, normalizedCategory == "playlists" ? 4 : 14)
                        } else {
                            Spacer().frame(height: 6)
                        }

                        categoryContentSection
                            .padding(.horizontal, 20)

                        Spacer(minLength: 120)
                    }
                }
                .portScrollEdgeEffectSoftTop()
                .refreshable {
                    await loadCategoryData()
                }
            }
        }
        .navigationTitle(viewTitle)
        .navigationBarTitleDisplayMode(normalizedCategory == "playlists" ? .large : .inline)
        .preferredColorScheme(.dark)
        .tint(.white)
        .toolbar {
            if normalizedCategory == "playlists" {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showCreatePlaylistSheet = true
                        } label: {
                            Label("Neue Playlist", systemImage: "music.note.list")
                        }

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            newFolderName = ""
                            showCreateFolderAlert = true
                        } label: {
                            Label("Neuer Ordner", systemImage: "folder.badge.plus")
                        }

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showImportPlaylistSheet = true
                        } label: {
                            Label("Playlist importieren", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }

                    Menu {
                        Picker("Ansicht", selection: playlistViewModeBinding) {
                            Label("Raster", systemImage: "square.grid.2x2")
                                .tag(PlaylistViewMode.grid)
                            Label("Liste", systemImage: "list.bullet")
                                .tag(PlaylistViewMode.list)
                        }
                        .pickerStyle(.inline)

                        Divider()

                        Picker("Sortieren nach", selection: playlistSortBinding) {
                            Text("Titel")
                                .tag(PlaylistSort.title)
                            Text("Hinzugefügt am")
                                .tag(PlaylistSort.dateAdded)
                            Text("Letztes Abspieldatum")
                                .tag(PlaylistSort.lastPlayed)
                            Text("Aktuellstes Datum")
                                .tag(PlaylistSort.newestDate)
                            Text("Art der Playlist")
                                .tag(PlaylistSort.playlistType)
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
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
                PlaylistActivityStore.shared.markAdded(playlistId: created.id)
                playlists.insert(created, at: 0)
            }
        }
        .sheet(isPresented: $showImportPlaylistSheet) {
            ImportPlaylistSheet(serverURL: serverURL) { imported in
                PlaylistActivityStore.shared.markAdded(playlistId: imported.id)
                playlists.insert(imported, at: 0)
            }
        }
    }

    // MARK: - Search Bar
    private var searchBarSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.white.opacity(0.45))

            TextField(normalizedCategory == "playlists" ? "Suchen" : "\(viewTitle) durchsuchen...", text: $searchQuery)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .autocorrectionDisabled()

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Color.white.opacity(0.45))
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(Color.white.opacity(0.09))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
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

    // MARK: - Playlists View (With Mac-Style FolderCover & Nested Navigation)
    private var folderBreadcrumbs: [LibraryFolder] {
        var trail: [LibraryFolder] = []
        var currentId = selectedFolderId
        var guardSet = Set<String>()
        while let cid = currentId, !guardSet.contains(cid),
              let folder = folders.first(where: { $0.id == cid }) {
            guardSet.insert(cid)
            trail.insert(folder, at: 0)
            currentId = folder.parentId
        }
        return trail
    }

    private var displayFolders: [LibraryFolder] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered: [LibraryFolder]
        if !q.isEmpty {
            filtered = folders.filter { $0.name.lowercased().contains(q) }
        } else if let currentId = selectedFolderId {
            filtered = folders.filter { $0.parentId == currentId }
        } else {
            filtered = folders.filter { ($0.parentId ?? "").isEmpty }
        }
        return filtered.sorted { a, b in
            let pA = pinnedFolderIds.contains(a.id)
            let pB = pinnedFolderIds.contains(b.id)
            if pA != pB { return pA }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private func playlistTypeRank(_ pl: DiscoveryPlaylist) -> Int {
        let lowerId = pl.id.lowercased()
        if lowerId.hasPrefix("import_") || lowerId.contains("import") {
            return 1
        }
        if lowerId.hasPrefix("apple_") || lowerId.hasPrefix("deezer_") || lowerId.hasPrefix("dz_") {
            let isDownloaded = !offlineManager.downloadedTracks(forPlaylistId: pl.id).isEmpty || offlineManager.downloadedPlaylistMeta(forPlaylistId: pl.id) != nil
            return isDownloaded ? 2 : 3
        }
        return 0
    }

    private var sortedPlaylists: [DiscoveryPlaylist] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base: [DiscoveryPlaylist]
        if !q.isEmpty {
            base = playlists.filter { $0.title.lowercased().contains(q) }
        } else if let currentId = selectedFolderId {
            base = playlists.filter { $0.folderId == currentId }
        } else {
            let folderIds = Set(folders.map { $0.id })
            base = playlists.filter {
                guard let fid = $0.folderId, !fid.isEmpty else { return true }
                return !folderIds.contains(fid)
            }
        }

        let activity = PlaylistActivityStore.shared
        return base.sorted { a, b in
            let pinA = pinnedIds.contains(a.id)
            let pinB = pinnedIds.contains(b.id)
            if pinA != pinB { return pinA }

            switch playlistSort {
            case .title:
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case .dateAdded:
                let tA = activity.addedTimestamp(for: a.id)
                let tB = activity.addedTimestamp(for: b.id)
                if tA != tB { return tA > tB }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case .lastPlayed:
                let pA = activity.lastPlayedTimestamp(for: a.id)
                let pB = activity.lastPlayedTimestamp(for: b.id)
                if pA != pB { return pA > pB }
                let tA = activity.addedTimestamp(for: a.id)
                let tB = activity.addedTimestamp(for: b.id)
                if tA != tB { return tA > tB }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case .newestDate:
                let nA = activity.newestTimestamp(for: a.id)
                let nB = activity.newestTimestamp(for: b.id)
                if nA != nB { return nA > nB }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case .playlistType:
                let rA = playlistTypeRank(a)
                let rB = playlistTypeRank(b)
                if rA != rB { return rA < rB }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        }
    }

    private func playlistsInFolder(_ folderId: String) -> [DiscoveryPlaylist] {
        playlists.filter { $0.folderId == folderId }
    }

    private var playlistsView: some View {
        let items = sortedPlaylists
        let visibleFolders = displayFolders

        return VStack(alignment: .leading, spacing: 14) {
            if selectedFolderId != nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                selectedFolderId = nil
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Playlists")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.75))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())

                        ForEach(Array(folderBreadcrumbs.enumerated()), id: \.element.id) { idx, crumb in
                            let isLast = idx == folderBreadcrumbs.count - 1
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.35))

                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                    selectedFolderId = crumb.id
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: isLast ? "folder.fill" : "folder")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(crumb.name)
                                        .font(.system(size: 13, weight: isLast ? .bold : .medium))
                                        .foregroundColor(isLast ? .white : Color.white.opacity(0.75))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isLast ? Color.white.opacity(0.14) : Color.white.opacity(0.07))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }

            if isLoading && playlists.isEmpty && folders.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
            } else if visibleFolders.isEmpty && items.isEmpty && selectedFolderId != nil {
                emptyPlaceholder(icon: "folder", message: "Dieser Ordner ist leer")
            } else if visibleFolders.isEmpty && items.isEmpty && !searchQuery.isEmpty {
                emptyPlaceholder(icon: "music.note.list", message: "Keine Playlists gefunden")
            } else if playlistViewMode == .list {
                LazyVStack(spacing: 0) {
                    if selectedFolderId == nil && searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        NavigationLink(value: AppRoute.likedSongs) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "#450af5"), Color(hex: "#6a4df0"), Color(hex: "#8e8ee5")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 56, height: 56)

                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Lieblingssongs")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text("Playlist")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "#a0a0a0"))
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.30))
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        Divider()
                            .background(Color.white.opacity(0.12))
                            .padding(.leading, 68)
                    }

                    ForEach(visibleFolders) { folder in
                        let inFolder = playlistsInFolder(folder.id)
                        let subCount = folders.filter { $0.parentId == folder.id }.count
                        let isPinned = pinnedFolderIds.contains(folder.id)
                        let subText: String = {
                            if subCount > 0 && !inFolder.isEmpty {
                                return "\(subCount) Ordner • \(inFolder.count) \(inFolder.count == 1 ? "Playlist" : "Playlists")"
                            } else if subCount > 0 {
                                return "\(subCount) Unterordner"
                            } else {
                                return "\(inFolder.count) \(inFolder.count == 1 ? "Playlist" : "Playlists")"
                            }
                        }()

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                selectedFolderId = folder.id
                            }
                        }) {
                            HStack(spacing: 12) {
                                FolderCoverView(
                                    folder: folder,
                                    playlists: inFolder,
                                    serverURL: serverURL
                                )
                                .frame(width: 56, height: 56)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(folder.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(subText)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "#a0a0a0"))
                                        .lineLimit(1)
                                }

                                Spacer()

                                if isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.white.opacity(0.55))
                                }

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.30))
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        Divider()
                            .background(Color.white.opacity(0.12))
                            .padding(.leading, 68)
                    }

                    ForEach(items) { pl in
                        NavigationLink(value: AppRoute.playlist(
                            id: pl.id,
                            title: pl.title,
                            coverUrl: pl.cover
                        )) {
                            HStack(spacing: 12) {
                                PlaylistArtworkView(
                                    coverUrl: pl.cover,
                                    trackCovers: pl.trackCovers,
                                    cornerRadius: 10,
                                    iconSize: 20,
                                    serverURL: serverURL
                                )
                                .frame(width: 56, height: 56)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(pl.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    let count = pl.nbTracks.map { "\(String($0)) Songs" } ?? "Playlist"
                                    Text(count)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "#a0a0a0"))
                                        .lineLimit(1)
                                }

                                Spacer()

                                if pinnedIds.contains(pl.id) {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.white.opacity(0.55))
                                }

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.30))
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        if pl.id != items.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.12))
                                .padding(.leading, 68)
                        }
                    }
                }
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 16
                ) {
                    // Lieblingssongs Kachel auf Hauptebene (analog Web LibraryPlaylistsPage)
                    if selectedFolderId == nil && searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        NavigationLink(value: AppRoute.likedSongs) {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "#450af5"), Color(hex: "#6a4df0"), Color(hex: "#8e8ee5")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .aspectRatio(1, contentMode: .fit)

                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 46))
                                        .foregroundColor(.white)
                                        .shadow(color: Color.black.opacity(0.30), radius: 6, y: 3)
                                }
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                )
                                .shadow(color: Color(hex: "#450af5").opacity(0.35), radius: 8, y: 4)

                                Text("Lieblingssongs")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Text("Playlist")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#a0a0a0"))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // MacBook / macOS Folder Tiles
                    ForEach(visibleFolders) { folder in
                        let inFolder = playlistsInFolder(folder.id)
                        let subCount = folders.filter { $0.parentId == folder.id }.count
                        let isPinned = pinnedFolderIds.contains(folder.id)

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                selectedFolderId = folder.id
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .topTrailing) {
                                    FolderCoverView(
                                        folder: folder,
                                        playlists: inFolder,
                                        serverURL: serverURL
                                    )

                                    if isPinned {
                                        Image(systemName: "pin.fill")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background(Color.black.opacity(0.65))
                                            .clipShape(Circle())
                                            .padding(8)
                                    }
                                }

                                Text(folder.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                let subText: String = {
                                    if subCount > 0 && !inFolder.isEmpty {
                                        return "\(subCount) Ordner • \(inFolder.count) \(inFolder.count == 1 ? "Playlist" : "Playlists")"
                                    } else if subCount > 0 {
                                        return "\(subCount) Unterordner"
                                    } else {
                                        return "\(inFolder.count) \(inFolder.count == 1 ? "Playlist" : "Playlists")"
                                    }
                                }()
                                Text(subText)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#a0a0a0"))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Playlists Grid Cards
                    ForEach(items) { pl in
                        NavigationLink(value: AppRoute.playlist(
                            id: pl.id,
                            title: pl.title,
                            coverUrl: pl.cover
                        )) {
                            VStack(alignment: .leading, spacing: 6) {
                                PlaylistArtworkView(
                                    coverUrl: pl.cover,
                                    trackCovers: pl.trackCovers,
                                    cornerRadius: 12,
                                    iconSize: 34,
                                    serverURL: serverURL
                                )
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(alignment: .topTrailing) {
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
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.40), radius: 6, y: 3)

                                Text(pl.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                let count = pl.nbTracks.map { "\(String($0)) Songs" } ?? "Playlist"
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
        .alert("Neuer Ordner", isPresented: $showCreateFolderAlert) {
            TextField("Ordnername", text: $newFolderName)
            Button("Abbrechen", role: .cancel) {}
            Button("Erstellen") {
                let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                let parentId = selectedFolderId
                Task {
                    let token = SessionManager.shared.currentToken
                    if let created = await MusicService.shared.createFolder(
                        name: name,
                        parentFolderId: parentId,
                        serverURL: serverURL,
                        token: token
                    ) {
                        await MainActor.run {
                            folders.append(created)
                        }
                    }
                }
            }
        } message: {
            Text(selectedFolderId == nil ? "Name für den neuen Ordner eingeben." : "Name für den neuen Unterordner eingeben.")
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
            // Sofort Offline- & Cache-Playlists anzeigen
            let cachedCollections = await MusicService.shared.cachedLibraryCollections()
            let immediatePls = await MainActor.run {
                let merged = offlineManager.mergeOfflinePlaylists(with: cachedCollections.playlists)
                PlaylistActivityStore.shared.recordDiscovered(playlistIds: merged.map(\.id))
                return merged
            }
            if !immediatePls.isEmpty {
                await MainActor.run {
                    self.playlists = immediatePls
                    self.folders = cachedCollections.folders
                    self.pinnedIds = Set(cachedCollections.pinnedPlaylists)
                    self.pinnedFolderIds = Set(cachedCollections.pinnedFolders)
                    self.isLoading = false
                }
            }
            if await MainActor.run(body: { SessionManager.shared.isOfflineMode }) {
                await MainActor.run { self.isLoading = false }
                return
            }

            async let plsTask = MusicService.shared.fetchPlaylists(serverURL: serverURL, token: token)
            async let colTask = MusicService.shared.fetchLibraryCollections(serverURL: serverURL, token: token)
            let (userPls, collections) = await (plsTask, colTask)
            let stateById = Dictionary(uniqueKeysWithValues: collections.playlists.map { ($0.id, $0) })
            let rawMerged: [DiscoveryPlaylist]
            if userPls.isEmpty {
                rawMerged = collections.playlists
            } else {
                var enriched = userPls.map { pl -> DiscoveryPlaylist in
                    if let st = stateById[pl.id] {
                        let mergedTrackCovers: [String]?
                        if let existingTc = pl.trackCovers, !existingTc.isEmpty {
                            mergedTrackCovers = existingTc
                        } else {
                            mergedTrackCovers = st.trackCovers
                        }
                        return DiscoveryPlaylist(
                            id: pl.id,
                            title: pl.title,
                            cover: pl.cover.isEmpty ? st.cover : pl.cover,
                            nbTracks: pl.nbTracks ?? st.nbTracks,
                            user: pl.user ?? st.user,
                            folderId: pl.folderId ?? st.folderId,
                            trackCovers: mergedTrackCovers
                        )
                    }
                    return pl
                }
                for st in collections.playlists where !enriched.contains(where: { $0.id == st.id }) {
                    enriched.append(st)
                }
                rawMerged = enriched
            }
            let finalMerged = await MainActor.run {
                let merged = offlineManager.mergeOfflinePlaylists(with: rawMerged.isEmpty ? immediatePls : rawMerged)
                PlaylistActivityStore.shared.recordDiscovered(playlistIds: merged.map(\.id))
                return merged
            }
            await MainActor.run {
                self.playlists = finalMerged
                if !collections.folders.isEmpty || !SessionManager.shared.isOfflineMode {
                    self.folders = collections.folders
                    self.pinnedIds = Set(collections.pinnedPlaylists)
                    self.pinnedFolderIds = Set(collections.pinnedFolders)
                }
                self.isLoading = false
            }

        case "artists":
            // Wie Web LibraryArtistsPage: NUR explizit gefolgte Künstler anzeigen (keine Song/Verlauf-Verschmutzung)
            let collections = await MusicService.shared.fetchLibraryCollections(serverURL: serverURL, token: token)
            let localSaved = UserDefaults.standard.stringArray(forKey: "port_music_saved_artists") ?? []

            var artistList: [DiscoveryArtist] = []
            var seen = Set<String>()

            for rawName in (collections.savedArtists + localSaved) {
                let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, name.lowercased() != "unbekannter interpret" else { continue }
                let key = name.lowercased()
                guard seen.insert(key).inserted else { continue }
                artistList.append(DiscoveryArtist(id: "art_\(key)", name: name, picture: nil, nbFan: nil))
            }

            await MainActor.run {
                self.artists = artistList
                self.isLoading = false
            }

            if !artistList.isEmpty && !SessionManager.shared.isOfflineMode {
                // Batch lookup über /api/artists/lookup-batch (sofortige Profilbilder wie im Web)
                let batchMap = await MusicService.shared.lookupArtistImagesBatch(
                    names: artistList.map(\.name),
                    serverURL: serverURL,
                    token: token
                )
                if !batchMap.isEmpty {
                    await MainActor.run {
                        self.artists = self.artists.map { existing in
                            if let pic = batchMap[existing.name.lowercased()], !pic.isEmpty {
                                return DiscoveryArtist(id: existing.id, name: existing.name, picture: pic, nbFan: existing.nbFan)
                            }
                            return existing
                        }
                    }
                }

                // Fallback für noch fehlende Künstlerbilder über /api/discovery/artist/:name
                let stillMissing = await MainActor.run {
                    self.artists.filter { ($0.picture?.isEmpty ?? true) }.prefix(24)
                }
                for art in stillMissing {
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
