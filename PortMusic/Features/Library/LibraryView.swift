import SwiftUI

// MARK: - Library Category Configuration (Mirrors Web LibraryPage DEFAULT_CATEGORY_ORDER)
private struct LibraryCategoryConfig: Identifiable, Codable, Equatable {
    let id: String
    let label: String
    let iconName: String
    var visible: Bool
}

public struct LibraryView: View {
    public let serverURL: String
    public let user: UserProfile?

    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared

    @State private var favorites: [Track] = []
    @State private var playlists: [DiscoveryPlaylist] = []
    @State private var historyTracks: [Track] = []
    @State private var isLoading: Bool = false
    @State private var selectedTab: String = "Playlists"

    // Web Library Parity: Action Modals & Inline Customizable Category Order
    @State private var showCreatePlaylistSheet: Bool = false
    @State private var showImportPlaylistSheet: Bool = false
    @State private var isEditingCategories: Bool = false
    @State private var categoriesConfig: [LibraryCategoryConfig] = LibraryView.defaultCategories()

    private let tabs = ["Playlists", "Songs", "Alben", "Verlauf"]
    private static let categoriesStorageKey = "port_music_library_categories_config_v2"

    public init(serverURL: String, user: UserProfile? = nil) {
        self.serverURL = serverURL
        self.user = user
        self._categoriesConfig = State(initialValue: Self.loadSavedCategories())
    }

    private static func defaultCategories() -> [LibraryCategoryConfig] {
        [
            LibraryCategoryConfig(id: "playlists", label: "Playlists", iconName: "music.note.list", visible: true),
            LibraryCategoryConfig(id: "artists", label: "Künstler", iconName: "mic.fill", visible: true),
            LibraryCategoryConfig(id: "albums", label: "Alben", iconName: "square.stack.fill", visible: true),
            LibraryCategoryConfig(id: "radio", label: "Radio", iconName: "dot.radiowaves.left.and.right", visible: true),
            LibraryCategoryConfig(id: "songs", label: "Songs", iconName: "music.note", visible: true),
            LibraryCategoryConfig(id: "downloaded", label: "Heruntergeladen", iconName: "arrow.down.circle.fill", visible: true),
            LibraryCategoryConfig(id: "local-files", label: "Lokale Dateien", iconName: "doc.badge.gearshape.fill", visible: true),
            LibraryCategoryConfig(id: "history", label: "Zuletzt gehört", iconName: "clock.arrow.circlepath", visible: true)
        ]
    }

    private static func loadSavedCategories() -> [LibraryCategoryConfig] {
        let defaults = defaultCategories()
        guard let data = UserDefaults.standard.data(forKey: categoriesStorageKey),
              let saved = try? JSONDecoder().decode([LibraryCategoryConfig].self, from: data),
              !saved.isEmpty else {
            return defaults
        }
        var result: [LibraryCategoryConfig] = []
        let defaultsById = Dictionary(uniqueKeysWithValues: defaults.map { ($0.id, $0) })
        for item in saved {
            if let def = defaultsById[item.id] {
                result.append(LibraryCategoryConfig(id: def.id, label: def.label, iconName: def.iconName, visible: item.visible))
            }
        }
        for def in defaults where !result.contains(where: { $0.id == def.id }) {
            result.append(def)
        }
        return result
    }

    private func persistCategories(_ list: [LibraryCategoryConfig]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: Self.categoriesStorageKey)
        }
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                // Header + Web Action Pills (Bearbeiten, Importieren, Neu)
                headerSection
                    .padding(.top, 12)
                    .padding(.horizontal, 20)

                // Hero Section: Liked Songs Card & Playlists Carousel
                heroCarouselSection

                // Categorized Library Rows (Customizable like Web LibraryPage)
                categoryLinksSection
                    .padding(.horizontal, 20)

                // Segmented Sub-Tab Navigation Bar (Quick Switcher)
                segmentedTabBar
                    .padding(.horizontal, 20)

                // Dynamic Content Based on Selected Tab
                tabContentSection
                    .padding(.horizontal, 20)

                Spacer(minLength: 140)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarHidden(true)
        .refreshable {
            await loadLibraryData()
        }
        .task {
            await loadLibraryData()
        }
        .onChange(of: favoritesManager.favoritedTrackIds) { _ in
            Task {
                await refreshFavoritesOnly()
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
                Task { await loadLibraryData() }
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bibliothek")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Text("Deine Musiksammlung")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.45))
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                }
            }

            // Action Buttons row (Importieren, Neu)
            HStack(spacing: 8) {

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showImportPlaylistSheet = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Importieren")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showCreatePlaylistSheet = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Neu")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
        }
    }

    // MARK: - Hero Carousel (Lieblingssongs + Playlists)
    private var heroCarouselSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                likedSongsHeroCard

                ForEach(playlists) { pl in
                    playlistHeroCard(pl)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var likedSongsHeroCard: some View {
        let isPlayingFav = player.isPlaying && favorites.contains(where: { $0.id == player.currentTrack?.id })

        return NavigationLink(value: AppRoute.likedSongs) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#450af5"), Color(hex: "#6a4df0"), Color(hex: "#8e8ee5")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 156, height: 156)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.28), radius: 8, y: 4)
                        .frame(width: 156, height: 156)

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if isPlayingFav {
                            player.togglePlayPause()
                        } else if !favorites.isEmpty {
                            player.play(track: favorites[0], from: favorites, serverURL: serverURL)
                        }
                    }) {
                        Image(systemName: isPlayingFav ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 34, height: 34)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.35), radius: 6, y: 3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(10)
                }
                .frame(width: 156, height: 156)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color(hex: "#450af5").opacity(0.35), radius: 10, y: 5)

                Text("Lieblingssongs")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(favorites.count) \(favorites.count == 1 ? "Song" : "Songs")")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#a0a0a0"))
                    .lineLimit(1)
            }
            .frame(width: 156, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func playlistHeroCard(_ pl: DiscoveryPlaylist) -> some View {
        NavigationLink(value: AppRoute.playlist(
            id: pl.id,
            title: pl.title,
            coverUrl: pl.cover
        )) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#18181b"))
                        .frame(width: 156, height: 156)

                    let resolved = resolveCoverURL(pl.cover, serverURL: serverURL)
                    PortCachedAsyncImage(url: resolved) { img in
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 156, height: 156)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } placeholder: {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 36))
                            .foregroundColor(Color.white.opacity(0.28))
                    }
                }
                .frame(width: 156, height: 156)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 8, y: 4)

                Text(pl.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                let countLabel = pl.nbTracks.map { "\($0) Titel" } ?? (pl.user ?? "Port Music")
                Text(countLabel)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#a0a0a0"))
                    .lineLimit(1)
            }
            .frame(width: 156, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Category Links Section (Inline Apple Drag & Drop Edit Mode)
    private var categoryLinksSection: some View {
        let visibleCats = categoriesConfig.filter { $0.visible }
        let hiddenCats = categoriesConfig.filter { !$0.visible }
        let rowHeight: CGFloat = 50
        let listHeight = CGFloat(visibleCats.count) * rowHeight
            + (hiddenCats.isEmpty ? 0 : (CGFloat(hiddenCats.count) * rowHeight + 40))

        return VStack(alignment: .leading, spacing: 8) {
            // Rechts über der obersten Option ("Playlists"): Bearbeiten <-> Fertig
            HStack {
                if isEditingCategories {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                            let defaults = Self.defaultCategories()
                            categoriesConfig = defaults
                            persistCategories(defaults)
                        }
                    }) {
                        Text("Zurücksetzen")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.55))
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                        isEditingCategories.toggle()
                    }
                }) {
                    Text(isEditingCategories ? "Fertig" : "Bearbeiten")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#fc3c44"))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 4)

            if isEditingCategories {
                List {
                    Section {
                        ForEach(visibleCats) { cat in
                            HStack(spacing: 12) {
                                Button(action: {
                                    toggleCategoryInline(cat)
                                }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 21))
                                        .foregroundColor(Color(hex: "#fc3c44"))
                                        .frame(width: 28, height: 28)
                                }
                                .buttonStyle(.plain)

                                Image(systemName: cat.iconName)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(Color(hex: "#fc3c44"))
                                    .frame(width: 24, alignment: .center)

                                Text(cat.label)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white)

                                Spacer()
                            }
                            .frame(height: rowHeight)
                            .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
                            .listRowBackground(Color.white.opacity(0.04))
                            .listRowSeparatorTint(Color.white.opacity(0.08))
                            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .onMove { indices, newOffset in
                            var updatedVisible = visibleCats
                            updatedVisible.move(fromOffsets: indices, toOffset: newOffset)
                            categoriesConfig = updatedVisible + hiddenCats
                            persistCategories(categoriesConfig)
                        }
                    }

                    if !hiddenCats.isEmpty {
                        Section(
                            header: Text("Weitere Optionen")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.50))
                        ) {
                            ForEach(hiddenCats) { cat in
                                HStack(spacing: 12) {
                                    Button(action: {
                                        toggleCategoryInline(cat)
                                    }) {
                                        Image(systemName: "circle")
                                            .font(.system(size: 21))
                                            .foregroundColor(Color.white.opacity(0.35))
                                            .frame(width: 28, height: 28)
                                    }
                                    .buttonStyle(.plain)

                                    Image(systemName: cat.iconName)
                                        .font(.system(size: 17))
                                        .foregroundColor(.white.opacity(0.45))
                                        .frame(width: 24, alignment: .center)

                                    Text(cat.label)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.65))

                                    Spacer()
                                }
                                .frame(height: rowHeight)
                                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
                                .listRowBackground(Color.white.opacity(0.03))
                                .listRowSeparatorTint(Color.white.opacity(0.08))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleCategoryInline(cat)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .environment(\.editMode, .constant(.active))
                .environment(\.defaultMinListRowHeight, rowHeight)
                .frame(height: listHeight)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visibleCats.enumerated()), id: \.element.id) { index, cat in
                        NavigationLink(value: AppRoute.libraryCategory(category: cat.id)) {
                            HStack(spacing: 14) {
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Color(hex: "#fc3c44"))
                                    .frame(width: 24, alignment: .center)

                                Text(cat.label)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.white)

                                Spacer()

                                if cat.id == "downloaded", !offlineManager.downloadedTrackIds.isEmpty {
                                    Text("\(offlineManager.downloadedTrackIds.count)")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color.white.opacity(0.45))
                                }

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.32))
                            }
                            .padding(.vertical, 13)
                            .padding(.horizontal, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        if index < visibleCats.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.08))
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }

    private func toggleCategoryInline(_ cat: LibraryCategoryConfig) {
        let visibleCount = categoriesConfig.filter { $0.visible }.count
        guard let idx = categoriesConfig.firstIndex(where: { $0.id == cat.id }) else { return }
        if categoriesConfig[idx].visible && visibleCount <= 1 {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            categoriesConfig[idx].visible.toggle()
            let visible = categoriesConfig.filter { $0.visible }
            let hidden = categoriesConfig.filter { !$0.visible }
            categoriesConfig = visible + hidden
            persistCategories(categoriesConfig)
        }
    }

    // MARK: - Segmented Tab Bar
    private var segmentedTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabs, id: \.self) { tab in
                    let isSelected = selectedTab == tab
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    }) {
                        Text(tab)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .black : Color.white.opacity(0.75))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.white : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(isSelected ? 0 : 0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Tab Content Switcher
    @ViewBuilder
    private var tabContentSection: some View {
        switch selectedTab {
        case "Playlists":
            playlistsTabContent
        case "Songs":
            favoritesTabContent
        case "Alben":
            albumsTabContent
        case "Verlauf":
            recentTabContent
        default:
            EmptyView()
        }
    }

    // MARK: - Tab: Playlists
    private var playlistsTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if playlists.isEmpty {
                emptyPlaceholder(icon: "music.note.list", message: "Noch keine Playlists angelegt")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(playlists) { pl in
                        NavigationLink(value: AppRoute.playlist(
                            id: pl.id,
                            title: pl.title,
                            coverUrl: pl.cover
                        )) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: "#18181b"))
                                        .frame(width: 52, height: 52)
                                    PortCachedAsyncImage(url: resolveCoverURL(pl.cover, serverURL: serverURL)) { img in
                                        img
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 52, height: 52)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } placeholder: {
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 18))
                                            .foregroundColor(Color.white.opacity(0.30))
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pl.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    let countStr = pl.nbTracks.map { "\($0) Titel" } ?? (pl.user ?? "Port Music")
                                    Text(countStr)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#a0a0a0"))
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.30))
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Tab: Songs (Lieblingssongs)
    private var favoritesTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if favorites.isEmpty {
                emptyPlaceholder(icon: "heart.slash", message: "Noch keine Lieblingssongs markiert")
            } else {
                HStack(spacing: 12) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if !favorites.isEmpty {
                            player.play(track: favorites[0], from: favorites, serverURL: serverURL)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13))
                            Text("Abspielen")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if !favorites.isEmpty {
                            player.isShuffle = true
                            let idx = Int.random(in: 0..<favorites.count)
                            player.play(track: favorites[idx], from: favorites, serverURL: serverURL)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 13))
                            Text("Mischen")
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
                }
                .padding(.bottom, 4)

                LazyVStack(spacing: 4) {
                    ForEach(favorites) { track in
                        trackRowItem(track: track, queue: favorites, isFav: true)
                    }
                }
            }
        }
    }

    // MARK: - Tab: Alben
    private var albumsTabContent: some View {
        let uniqueAlbums = extractUniqueAlbums()
        return VStack(alignment: .leading, spacing: 12) {
            if uniqueAlbums.isEmpty {
                emptyPlaceholder(icon: "square.stack", message: "Noch keine Alben in der Bibliothek")
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 16
                ) {
                    ForEach(uniqueAlbums) { album in
                        PortAlbumCard(
                            title: album.album ?? album.title,
                            subtitle: album.artist,
                            coverUrl: album.coverUrl,
                            serverURL: serverURL,
                            onTap: {
                                player.play(track: album, from: uniqueAlbums, serverURL: serverURL)
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Tab: Verlauf (Zuletzt gehoert)
    private var recentTabContent: some View {
        let displayTracks = historyTracks.isEmpty ? player.recentTracks : historyTracks
        return VStack(alignment: .leading, spacing: 10) {
            if displayTracks.isEmpty {
                emptyPlaceholder(icon: "clock", message: "Noch keine zuletzt gehörten Titel")
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(displayTracks) { track in
                        let isFav = favoritesManager.isFavorite(trackId: track.id)
                        trackRowItem(track: track, queue: displayTracks, isFav: isFav)
                    }
                }
            }
        }
    }

    // MARK: - Track Row Item Helper
    private func trackRowItem(track: Track, queue: [Track], isFav: Bool) -> some View {
        let isPlayingThis = player.currentTrack?.id == track.id
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "#18181b"))
                    .frame(width: 48, height: 48)

                PortCachedAsyncImage(url: resolveCoverURL(track.coverUrl, serverURL: serverURL)) { img in
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } placeholder: {
                    Image(systemName: "music.note")
                        .font(.system(size: 16))
                        .foregroundColor(Color.white.opacity(0.25))
                }

                if isPlayingThis && player.isPlaying {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.45))
                        .frame(width: 48, height: 48)
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#fc3c44"))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isPlayingThis ? Color(hex: "#fc3c44") : .white)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#a0a0a0"))
                    .lineLimit(1)
            }

            Spacer()

            Text(track.duration)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.40))

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task {
                    let token = SessionManager.shared.currentToken
                    _ = await MusicService.shared.toggleFavorite(track: track, serverURL: serverURL, token: token)
                }
            }) {
                Image(systemName: isFav ? "heart.fill" : "heart")
                    .font(.system(size: 16))
                    .foregroundColor(isFav ? Color(hex: "#fc3c44") : Color.white.opacity(0.45))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            player.play(track: track, from: queue, serverURL: serverURL)
        }
    }

    private func emptyPlaceholder(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(Color.white.opacity(0.28))
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    // MARK: - Album Extraction Helper
    private func extractUniqueAlbums() -> [Track] {
        let all = favorites + historyTracks + player.recentTracks
        var seenTitles = Set<String>()
        var result: [Track] = []
        for t in all {
            if let alb = t.album, !alb.isEmpty {
                let key = "\(alb.lowercased())|\(t.artist.lowercased())"
                if !seenTitles.contains(key) {
                    seenTitles.insert(key)
                    result.append(t)
                }
            }
        }
        return result
    }

    // MARK: - Data Loading
    private func loadLibraryData() async {
        isLoading = true
        let token = SessionManager.shared.currentToken

        async let favTask = MusicService.shared.fetchFavorites(serverURL: serverURL, token: token)
        async let plTask = MusicService.shared.fetchPlaylists(serverURL: serverURL, token: token)
        async let histTask = MusicService.shared.fetchStatsAndHistory(serverURL: serverURL, token: token)

        let (favs, pls, hist) = await (favTask, plTask, histTask)

        await MainActor.run {
            self.favorites = favs
            self.playlists = pls
            self.historyTracks = hist
            for f in favs {
                FavoritesManager.shared.setFavorite(trackId: f.id, isFavorite: true)
            }
            self.isLoading = false
        }
    }

    private func refreshFavoritesOnly() async {
        let token = SessionManager.shared.currentToken
        let favs = await MusicService.shared.fetchFavorites(serverURL: serverURL, token: token)
        await MainActor.run {
            self.favorites = favs
        }
    }
}
