import SwiftUI

// MARK: - Library View (Feature #12 - Full Web Library Parity)
public struct LibraryView: View {
    public let serverURL: String
    public let user: UserProfile?

    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared

    @State private var favorites: [Track] = []
    @State private var playlists: [DiscoveryPlaylist] = []
    @State private var historyTracks: [Track] = []
    @State private var isLoading: Bool = false
    @State private var selectedTab: String = "Playlists"

    // Web Library Parity & Apple Music Inline Editing
    @State private var showCreatePlaylistSheet: Bool = false
    @State private var showImportPlaylistSheet: Bool = false
    @State private var showCreateFolderAlert: Bool = false
    @State private var newFolderName: String = ""
    @State private var showSettingsSheet: Bool = false
    @State private var isEditingCategories: Bool = false
    @State private var animateEditControls: Bool = false
    @State private var editingCategories: [LibraryCategoryConfig] = []
    @State private var categoriesConfig: [LibraryCategoryConfig] = LibraryView.defaultCategories()
    @Namespace private var topGlassNamespace

    private let tabs = ["Playlists", "Songs", "Alben", "Verlauf"]
    private static let categoriesStorageKey = "port_music_library_categories_config_v2"

    public init(serverURL: String, user: UserProfile? = nil) {
        self.serverURL = serverURL
        self.user = user
        let loaded = Self.loadSavedCategories()
        self._categoriesConfig = State(initialValue: loaded)
        self._editingCategories = State(initialValue: loaded)
    }

    private static func defaultCategories() -> [LibraryCategoryConfig] {
        [
            LibraryCategoryConfig(id: "playlists", label: "Playlists", iconName: "music.note.list", visible: true),
            LibraryCategoryConfig(id: "artists", label: "Künstler", iconName: "music.mic", visible: true),
            LibraryCategoryConfig(id: "albums", label: "Alben", iconName: "square.stack.fill", visible: true),
            LibraryCategoryConfig(id: "podcasts", label: "Podcasts", iconName: "mic.fill", visible: true),
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
            if def.id == "podcasts", let albumsIdx = result.firstIndex(where: { $0.id == "albums" }) {
                result.insert(def, at: albumsIdx + 1)
            } else {
                result.append(def)
            }
        }
        return result
    }

    private func persistCategories(_ list: [LibraryCategoryConfig]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: Self.categoriesStorageKey)
        }
    }

    private var activeProfileUser: UserProfile {
        sessionManager.currentUser ?? user ?? UserProfile(id: "me", username: "Port Music")
    }

    private func enterInlineEditMode() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        editingCategories = categoriesConfig
        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
            isEditingCategories = true
            animateEditControls = true
        }
    }

    private func saveInlineCategoriesAndExit() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var finalList = editingCategories
        if !finalList.contains(where: { $0.visible }), let firstIdx = finalList.indices.first {
            finalList[firstIdx].visible = true
        }
        categoriesConfig = finalList
        persistCategories(finalList)
        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
            animateEditControls = false
            isEditingCategories = false
        }
    }

    private func toggleInlineCategory(_ id: String) {
        guard let idx = editingCategories.firstIndex(where: { $0.id == id }) else { return }
        if editingCategories[idx].visible {
            let visibleCount = editingCategories.filter(\.visible).count
            guard visibleCount > 1 else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            editingCategories[idx].visible = false
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            editingCategories[idx].visible = true
        }
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color.black
                .ignoresSafeArea()

            mainLibraryScrollView
                .opacity(isEditingCategories ? 0 : 1)
                .offset(y: isEditingCategories ? 10 : 0)
                .allowsHitTesting(!isEditingCategories)
                .zIndex(1)

            inlineCategoryEditList
                .opacity(isEditingCategories ? 1 : 0)
                .offset(y: isEditingCategories ? 0 : 8)
                .allowsHitTesting(isEditingCategories)
                .zIndex(2)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            libraryHeaderBar
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            await loadLibraryData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .portMusicDidReconnect)) { _ in
            Task {
                await loadLibraryData()
            }
        }
        .onChange(of: offlineManager.downloadedTrackIds) { _ in
            let merged = offlineManager.mergeOfflinePlaylists(with: self.playlists)
            self.playlists = merged
        }
        .onChange(of: favoritesManager.favoritedTrackIds) { _ in
            Task {
                await refreshFavoritesOnly()
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
                Task { await loadLibraryData() }
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsMainView(user: activeProfileUser, serverURL: serverURL) {
                SessionManager.shared.logout()
            }
        }
        .alert("Neuer Ordner", isPresented: $showCreateFolderAlert) {
            TextField("Ordnername", text: $newFolderName)
            Button("Abbrechen", role: .cancel) {}
            Button("Erstellen") {
                let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                Task {
                    let token = SessionManager.shared.currentToken
                    _ = await MusicService.shared.createFolder(
                        name: name,
                        parentFolderId: nil,
                        serverURL: serverURL,
                        token: token
                    )
                }
            }
        } message: {
            Text("Name für den neuen Ordner eingeben.")
        }
    }

    private var mainLibraryScrollView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                if sessionManager.isOfflineMode {
                    offlineModeBanner
                }

                // Categorized Library Rows (Apple Music style direkt auf Schwarz)
                categoryLinksSection
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Hero Section: Liked Songs Card & Playlists Carousel
                heroCarouselSection

                // Segmented Sub-Tab Navigation Bar (Quick Switcher)
                segmentedTabBar
                    .padding(.horizontal, 20)

                // Dynamic Content Based on Selected Tab
                tabContentSection
                    .padding(.horizontal, 20)

                Spacer(minLength: 140)
            }
        }
        .accessibilityHint("Deine Musiksammlung")
        .background(Color.black.ignoresSafeArea())
        .refreshable {
            await loadLibraryData()
        }
    }

    private var offlineModeBanner: some View {
        let downloadedCount = offlineManager.downloadedTrackIds.count
        return HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(PortColors.accentOrange)
            Text("Offline-Modus · \(downloadedCount) Songs gespeichert")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(Color.white.opacity(0.85))
                .lineLimit(1)
            Spacer()
            Button("Verbinden") {
                Task {
                    _ = await sessionManager.retryConnection()
                    await loadLibraryData()
                }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    // MARK: - Single-Row Apple Music Header (Bibliothek + Liquid Glass Bubble + Avatar / Checkmark)
    private var libraryHeaderBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Bibliothek")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            PortBottomGlassContainer(spacing: 10) {
                if isEditingCategories {
                    doneEditToolbarButton
                        .portGlassEffectID("library_trailing_actions", in: topGlassNamespace)
                        .transition(.scale(scale: 0.72).combined(with: .opacity))
                } else {
                    libraryActionsGlassPill
                        .portGlassEffectID("library_trailing_actions", in: topGlassNamespace)
                        .transition(.scale(scale: 0.82).combined(with: .opacity))

                    profileToolbarButton
                        .portGlassEffectID("library_profile_btn", in: topGlassNamespace)
                        .transition(.scale(scale: 0.65).combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color.black, location: 0.0),
                    .init(color: Color.black.opacity(0.92), location: 0.78),
                    .init(color: Color.black.opacity(0.0), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    private var libraryActionsGlassPill: some View {
        HStack(spacing: 2) {
            createPlaylistToolbarMenu
            editCategoriesToolbarButton
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
        .portLiquidGlassCapsule(interactive: true)
    }

    private var createPlaylistToolbarMenu: some View {
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
            Image(systemName: "text.badge.plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 42)
                .contentShape(Rectangle())
        }
    }

    private var editCategoriesToolbarButton: some View {
        Button {
            enterInlineEditMode()
        } label: {
            Image(systemName: "checklist")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reihenfolge bearbeiten")
    }

    private var profileToolbarButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showSettingsSheet = true
        } label: {
            PortUserAvatarView(
                rawAvatar: activeProfileUser.avatar,
                username: activeProfileUser.username,
                serverURL: serverURL,
                size: 36
            )
            .clipShape(Circle())
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .portLiquidGlassCircle(interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Benutzerprofil")
    }

    @ViewBuilder
    private var doneEditToolbarButton: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            Button {
                saveInlineCategoriesAndExit()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(Color(hex: "#0a84ff")).interactive(), in: Circle())
            .accessibilityLabel("Fertig")
        } else {
            legacyDoneEditButton
        }
        #else
        legacyDoneEditButton
        #endif
    }

    private var legacyDoneEditButton: some View {
        Button {
            saveInlineCategoriesAndExit()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color(hex: "#0a84ff"))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fertig")
    }

    // MARK: - Inline Apple Music Category Edit List (Checkmarks + Drag Reorder)
    private var inlineCategoryEditList: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            List {
                ForEach(editingCategories) { cat in
                    HStack(spacing: 14) {
                        Button(action: {
                            toggleInlineCategory(cat.id)
                        }) {
                            Image(systemName: cat.visible ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 23))
                                .foregroundColor(cat.visible ? .white : Color.white.opacity(0.32))
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(animateEditControls ? 1.0 : 0.45)
                        .opacity(animateEditControls ? 1.0 : 0.0)
                        .offset(x: animateEditControls ? 0 : -14)

                        Image(systemName: cat.iconName)
                            .font(.system(size: 19, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 26, alignment: .center)
                            .offset(x: animateEditControls ? 0 : -18)

                        Text(cat.label)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.white)
                            .offset(x: animateEditControls ? 0 : -18)

                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.black)
                    .listRowSeparatorTint(Color.white.opacity(0.14))
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 16))
                }
                .onMove { indices, newOffset in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    editingCategories.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .environment(\.editMode, .constant(.active))
            .safeAreaInset(edge: .bottom) {
                Spacer().frame(height: 120)
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
                PlaylistArtworkView(
                    coverUrl: pl.cover,
                    trackCovers: pl.trackCovers,
                    cornerRadius: 12,
                    iconSize: 38,
                    serverURL: serverURL
                )
                .frame(width: 156, height: 156)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 8, y: 4)

                Text(pl.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                let countLabel = pl.nbTracks.map { "\(String($0)) Titel" } ?? (pl.user ?? "Port Music")
                Text(countLabel)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#a0a0a0"))
                    .lineLimit(1)
            }
            .frame(width: 156, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Category Links Section (Apple Music Flat Rows + Dividers)
    private var categoryLinksSection: some View {
        let visibleCats = categoriesConfig.filter { $0.visible }

        return VStack(spacing: 0) {
            ForEach(visibleCats) { cat in
                NavigationLink(value: AppRoute.libraryCategory(category: cat.id)) {
                    HStack(spacing: 16) {
                        Image(systemName: cat.iconName)
                            .font(.system(size: 19, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 26, alignment: .center)

                        Text(cat.label)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.white)

                        Spacer()

                        if cat.id == "downloaded", !offlineManager.downloadedTrackIds.isEmpty {
                            Text(String(offlineManager.downloadedTrackIds.count))
                                .font(.system(size: 14))
                                .foregroundColor(Color.white.opacity(0.45))
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.32))
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                Divider()
                    .background(Color.white.opacity(0.14))
                    .padding(.leading, 42)
            }
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
                                PlaylistArtworkView(
                                    coverUrl: pl.cover,
                                    trackCovers: pl.trackCovers,
                                    cornerRadius: 8,
                                    iconSize: 20,
                                    serverURL: serverURL
                                )
                                .frame(width: 52, height: 52)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pl.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    let countStr = pl.nbTracks.map { "\(String($0)) Titel" } ?? (pl.user ?? "Port Music")
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

                let offlineCover = offlineManager.localCoverFileURL(for: track.id)
                let resolvedCover = offlineCover ?? resolveCoverURL(track.coverUrl, serverURL: serverURL)
                PortCachedAsyncImage(url: resolvedCover) { img in
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
                        .foregroundColor(.white)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if offlineManager.isDownloaded(trackId: track.id) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10.5))
                            .foregroundColor(Color(hex: "#10b981"))
                    }
                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#a0a0a0"))
                        .lineLimit(1)
                }
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

    // MARK: - Data Loading (With Instant Offline & Cache Support)
    private func loadLibraryData() async {
        let favCacheKey = "port_music_cached_favorites_v1"
        let plCacheKey = "port_music_cached_playlists_v1"

        // 1. Sofort (0 ms) lokale Downloads & Caches laden, bevor ein Netzwerkwunsch wartet
        var initialFavs: [Track] = favoritesManager.cachedFavoriteTracks
        if initialFavs.isEmpty,
           let fData = UserDefaults.standard.data(forKey: favCacheKey),
           let cachedFavs = try? JSONDecoder().decode([Track].self, from: fData) {
            initialFavs = cachedFavs
        }
        if initialFavs.isEmpty {
            initialFavs = offlineManager.allDownloadedTracks().filter {
                FavoritesManager.shared.isFavorite(trackId: $0.id)
            }
        }

        var cachedPls: [DiscoveryPlaylist] = []
        if let pData = UserDefaults.standard.data(forKey: plCacheKey),
           let decoded = try? JSONDecoder().decode([DiscoveryPlaylist].self, from: pData) {
            cachedPls = decoded
        }
        let initialPls = offlineManager.mergeOfflinePlaylists(with: cachedPls)

        await MainActor.run {
            if !initialFavs.isEmpty {
                self.favorites = initialFavs
            }
            if !initialPls.isEmpty {
                self.playlists = initialPls
            }
            if self.historyTracks.isEmpty && !player.recentTracks.isEmpty {
                self.historyTracks = player.recentTracks
            }
            self.isLoading = !sessionManager.isOfflineMode && (initialPls.isEmpty && initialFavs.isEmpty)
        }

        if sessionManager.isOfflineMode {
            await MainActor.run {
                self.isLoading = false
            }
            return
        }

        let token = SessionManager.shared.currentToken

        async let favTask = MusicService.shared.fetchFavorites(serverURL: serverURL, token: token)
        async let plTask = MusicService.shared.fetchPlaylists(serverURL: serverURL, token: token)
        async let histTask = MusicService.shared.fetchStatsAndHistory(serverURL: serverURL, token: token)

        let (favs, pls, hist) = await (favTask, plTask, histTask)

        await MainActor.run {
            if !sessionManager.isOfflineMode {
                self.favorites = favs
                if let encoded = try? JSONEncoder().encode(favs) {
                    UserDefaults.standard.set(encoded, forKey: favCacheKey)
                }
            } else if !favoritesManager.cachedFavoriteTracks.isEmpty {
                self.favorites = favoritesManager.cachedFavoriteTracks
            }

            let mergedPls = offlineManager.mergeOfflinePlaylists(with: pls.isEmpty ? self.playlists : pls)
            if !mergedPls.isEmpty {
                self.playlists = mergedPls
                if !pls.isEmpty, let encoded = try? JSONEncoder().encode(mergedPls) {
                    UserDefaults.standard.set(encoded, forKey: plCacheKey)
                }
            }
            if !hist.isEmpty {
                self.historyTracks = hist
            }
            self.isLoading = false
        }
    }

    private func refreshFavoritesOnly() async {
        if sessionManager.isOfflineMode {
            await MainActor.run {
                self.favorites = favoritesManager.cachedFavoriteTracks
            }
            return
        }
        let token = SessionManager.shared.currentToken
        let favs = await MusicService.shared.fetchFavorites(serverURL: serverURL, token: token)
        await MainActor.run {
            self.favorites = favs
        }
    }
}
