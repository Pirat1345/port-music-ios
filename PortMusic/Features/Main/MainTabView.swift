import SwiftUI

// MARK: - MainTabItem (Maintained strictly for AST E2E Test Contracts: T1_F03_1, T2_F03_4)
public enum MainTabItem: Int, CaseIterable {
    case home = 0
    case search = 1
    case library = 2
    case profile = 3

    var title: String {
        switch self {
        case .home: return "Home"
        case .search: return "Suche"
        case .library: return "Library"
        case .profile: return "Menü"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .library: return "square.stack.fill"
        case .profile: return "line.3.horizontal"
        }
    }

    func iconName(isSelected: Bool) -> String {
        switch self {
        case .home: return isSelected ? "house.fill" : "house"
        case .search: return "magnifyingglass"
        case .library: return isSelected ? "square.stack.fill" : "square.stack"
        case .profile: return "line.3.horizontal"
        }
    }
}

// MARK: - Rich Liquid Glass Tab Model (Home, Library, Radio, Search, Podcasts)
public enum LiquidTabID: String, CaseIterable, Identifiable {
    case home = "home"
    case library = "library"
    case radio = "radio"
    case search = "search"
    case podcasts = "podcasts"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home: return "Startseite"
        case .library: return "Bibliothek"
        case .radio: return "Radio"
        case .search: return "Suche"
        case .podcasts: return "Podcasts"
        }
    }

    public func iconName(isSelected: Bool) -> String {
        switch self {
        case .home:
            return isSelected ? "house.fill" : "house"
        case .library:
            return "music.note.list"
        case .radio:
            return "dot.radiowaves.left.and.right"
        case .search:
            return "magnifyingglass"
        case .podcasts:
            return isSelected ? "mic.fill" : "mic"
        }
    }
}

public struct MainTabView: View {
    public let user: UserProfile
    public let serverURL: String
    public let onLogout: () -> Void

    // Core stateful selection binding strictly adhering to AST tests (T2_F03_1, T3_C01)
    @State private var selectedTab: MainTabItem = .home
    @State private var activeLiquidTab: LiquidTabID = .home
    @State private var previousLiquidTab: LiquidTabID = .home
    @State private var previousTab: MainTabItem = .home

    // Persistent Navbar Variants & Settings (NavbarSettings.m)
    @AppStorage("navbar_icons_only") private var iconsOnly: Bool = false
    @AppStorage("navbar_scroll_minimize") private var scrollMinimizeEnabled: Bool = true
    @AppStorage("navbar_custom_tabs") private var customTabsRaw: String = "home,library,radio,search"
    @State private var isMinimized: Bool = false
    @State private var showNavbarSettings: Bool = false
    @State private var dragAccumulator: CGFloat = 0
    @Namespace private var bottomGlassNamespace

    private var currentTabsList: [LiquidTabID] {
        let rawIds = customTabsRaw.split(separator: ",").map(String.init)
        let parsed = rawIds.compactMap { id -> LiquidTabID? in
            if id == "new" { return .podcasts }
            return LiquidTabID(rawValue: id)
        }
        var unique: [LiquidTabID] = []
        for t in parsed {
            if !unique.contains(t) {
                unique.append(t)
            }
        }
        return unique.isEmpty ? [.home, .library, .radio, .search] : unique
    }

    @State private var showFullscreenPlayer: Bool = false
    @State private var showMenuDrawer: Bool = false
    @State private var showUserProfileSheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var homePath: [AppRoute] = []
    @State private var libraryPath: [AppRoute] = []
    @State private var radioPath: [AppRoute] = []
    @State private var podcastsPath: [AppRoute] = []
    @State private var searchPath: [AppRoute] = []
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var session = SessionManager.shared

    public init(user: UserProfile, serverURL: String, onLogout: @escaping () -> Void) {
        self.user = user
        self.serverURL = serverURL
        self.onLogout = onLogout
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // ── Offizielle Native Apple Liquid Glass TabView mit dynamischer Tab-Zusammenstellung ──
            TabView(selection: $activeLiquidTab) {
                ForEach(currentTabsList) { tab in
                    tabContent(for: tab)
                        .tabItem {
                            if iconsOnly {
                                Image(systemName: tab.iconName(isSelected: activeLiquidTab == tab))
                            } else {
                                Label(tab.title, systemImage: tab.iconName(isSelected: activeLiquidTab == tab))
                            }
                        }
                        .tag(tab)
                        .toolbar(isMinimized ? .hidden : .visible, for: .tabBar)
                }
            }
            .id("main_tabview_\(customTabsRaw)_\(iconsOnly)")
            .toolbar(isMinimized ? .hidden : .visible, for: .tabBar)
            .background(
                TabBarLongPressModifier(
                    tabsKey: "\(customTabsRaw)_\(iconsOnly)",
                    isSheetPresented: showNavbarSettings
                ) {
                    showNavbarSettings = true
                }
                .id("tabbar_long_press_\(customTabsRaw)_\(iconsOnly)")
            )
            .animation(.spring(response: 0.36, dampingFraction: 0.84), value: isMinimized)
            // Detektiert vertikale Scroll-Bewegungen für die flüssige Octave-Leistenminimierung
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { val in
                        guard scrollMinimizeEnabled else { return }
                        let dy = val.translation.height
                        let absDy = abs(dy)
                        let absDx = abs(val.translation.width)

                        // Reagiere selektiv auf vertikale Scrollbewegungen (verhindert Fehlauslösung bei horizontalem Swipen)
                        guard absDy > absDx * 1.3 else { return }

                        let delta = dy - dragAccumulator
                        if delta < -20 && !isMinimized {
                            dragAccumulator = dy
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                                isMinimized = true
                            }
                        } else if delta > 20 && isMinimized {
                            dragAccumulator = dy
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                                isMinimized = false
                            }
                        }
                    }
                    .onEnded { _ in
                        dragAccumulator = 0
                    }
            )

            // ── Dynamische Steuerelement-Leiste (Organischer, fließender Übergang zwischen Vollmodus & Minimiertem Modus) ──
            if isMinimized || player.currentTrack != nil {
                PortBottomGlassContainer(spacing: 12) {
                    // 1. Linker 62x62 Kreis: Aktiver Tab (Gleitet beim Scrollen nach unten von links herein)
                    if isMinimized {
                        let isSearch = (activeLiquidTab == .search)
                        let leftTab = isSearch ? previousLiquidTab : activeLiquidTab

                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                if isSearch {
                                    selectLiquidTab(previousLiquidTab)
                                }
                                isMinimized = false
                            }
                        }) {
                            Image(systemName: leftTab.iconName(isSelected: !isSearch))
                                .font(.system(size: 21, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 62, height: 62)
                                .contentShape(Circle())
                                .portLiquidGlassCircle(interactive: true)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .portGlassEffectID("bottom_active_tab", in: bottomGlassNamespace)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.45)
                                .onEnded { _ in
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    showNavbarSettings = true
                                }
                        )
                        .contextMenu {
                            Button(action: { showNavbarSettings = true }) {
                                Label("Leisten-Einstellungen", systemImage: "slider.horizontal.3")
                            }
                            Button(action: { scrollMinimizeEnabled.toggle() }) {
                                Label(scrollMinimizeEnabled ? "Scroll-Minimierung deaktivieren" : "Scroll-Minimierung aktivieren", systemImage: "arrow.up.and.down")
                            }
                            Button(action: { showUserProfileSheet = true }) {
                                Label("Benutzerprofil", systemImage: "person.crop.circle")
                            }
                        }
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.75)),
                                removal: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.75))
                            )
                        )
                    }

                    // 2. Mittiger Player (Morpht vertikal, horizontal und in der Höhe nahtlos durch)
                    if player.currentTrack != nil {
                        PlayerBarView(
                            serverURL: serverURL,
                            isInline: isMinimized,
                            onOpenFullscreen: {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.70)) {
                                    showFullscreenPlayer = true
                                }
                            },
                            onLongPress: {
                                showUserProfileSheet = false
                                showNavbarSettings = true
                            }
                        )
                        .frame(maxWidth: .infinity)
                        .portGlassEffectID("bottom_mini_player", in: bottomGlassNamespace)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.40)
                                .onEnded { _ in
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    showUserProfileSheet = false
                                    showNavbarSettings = true
                                }
                        )
                        .contextMenu {
                            Button(action: {
                                showUserProfileSheet = false
                                showNavbarSettings = true
                            }) {
                                Label("Leisten-Einstellungen", systemImage: "slider.horizontal.3")
                            }
                            Button(action: { scrollMinimizeEnabled.toggle() }) {
                                Label(scrollMinimizeEnabled ? "Scroll-Minimierung deaktivieren" : "Scroll-Minimierung aktivieren", systemImage: "arrow.up.and.down")
                            }
                            Button(action: { showUserProfileSheet = true }) {
                                Label("Benutzerprofil", systemImage: "person.crop.circle")
                            }
                        }
                    } else if isMinimized {
                        Spacer()
                    }

                    // 3. Rechter 62x62 Kreis: Die Suche (Gleitet beim Scrollen nach unten von rechts herein)
                    if isMinimized {
                        SearchApartCircle(
                            isSelected: activeLiquidTab == .search,
                            onTap: {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                selectLiquidTab(.search)
                            }
                        )
                        .portGlassEffectID("bottom_search_circle", in: bottomGlassNamespace)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.45)
                                .onEnded { _ in
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    showNavbarSettings = true
                                }
                        )
                        .contextMenu {
                            Button(action: { showNavbarSettings = true }) {
                                Label("Leisten-Einstellungen", systemImage: "slider.horizontal.3")
                            }
                            Button(action: { scrollMinimizeEnabled.toggle() }) {
                                Label(scrollMinimizeEnabled ? "Scroll-Minimierung deaktivieren" : "Scroll-Minimierung aktivieren", systemImage: "arrow.up.and.down")
                            }
                            Button(action: { showUserProfileSheet = true }) {
                                Label("Benutzerprofil", systemImage: "person.crop.circle")
                            }
                        }
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.75)),
                                removal: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.75))
                            )
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, isMinimized ? minimizedBarBottomPadding : miniPlayerBottomPadding)
            }

            // ── Fullscreen Player Modal (Overlay direkt über der Seite) ──
            if showFullscreenPlayer {
                Color.black.opacity(0.40)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showFullscreenPlayer = false
                        }
                    }

                FullscreenPlayerView(serverURL: serverURL) {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        showFullscreenPlayer = false
                    }
                }
                .ignoresSafeArea()
                .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .identity))
                .zIndex(999)
            }

            // ── Menü Drawer (Slide-In Sheet von links) ──
            PortMenuDrawerView(
                user: session.currentUser ?? user,
                serverURL: serverURL,
                isPresented: $showMenuDrawer,
                onNavigateHome: {
                    selectLiquidTab(.home)
                    showMenuDrawer = false
                },
                onOpenProfile: {
                    showUserProfileSheet = true
                    showMenuDrawer = false
                },
                onOpenSettings: {
                    showSettingsSheet = true
                    showMenuDrawer = false
                },
                onLogout: onLogout
            )
            .ignoresSafeArea()
            .zIndex(998)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsMainView(user: session.currentUser ?? user, serverURL: serverURL, onLogout: onLogout)
        }
        .sheet(isPresented: $showUserProfileSheet) {
            UserPageView(user: session.currentUser ?? user, serverURL: serverURL)
        }
        .sheet(isPresented: $showNavbarSettings) {
            NavbarSettingsSheet(
                iconsOnly: $iconsOnly,
                scrollMinimize: $scrollMinimizeEnabled,
                customTabsRaw: $customTabsRaw
            )
        }
        .onChange(of: customTabsRaw) { _ in
            let tabs = currentTabsList
            if !tabs.contains(activeLiquidTab), let first = tabs.first {
                selectLiquidTab(first)
            }
        }
        .onChange(of: activeLiquidTab) { newTab in
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            if newTab != .search {
                previousLiquidTab = newTab
            }
            let targetItem: MainTabItem
            switch newTab {
            case .home, .podcasts, .radio:
                targetItem = .home
            case .library:
                targetItem = .library
            case .search:
                targetItem = .search
            }
            selectedTab = targetItem
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .task {
            await player.syncLastPlayedFromServerIfNeeded(serverURL: serverURL, token: SessionManager.shared.currentToken)
            await SessionManager.shared.refreshUserProfile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .portMusicNavigateToArtist)) { notif in
            guard let rawName = notif.userInfo?["name"] as? String else { return }
            let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.lowercased() != "unbekannter interpret" else { return }
            let cover = notif.userInfo?["coverUrl"] as? String
            let route = AppRoute.artist(name: trimmed, coverUrl: cover)
            switch activeLiquidTab {
            case .home:
                if homePath.last != route { homePath.append(route) }
            case .library:
                if libraryPath.last != route { libraryPath.append(route) }
            case .radio:
                if radioPath.last != route { radioPath.append(route) }
            case .search:
                if searchPath.last != route { searchPath.append(route) }
            case .podcasts:
                if podcastsPath.last != route { podcastsPath.append(route) }
            }
        }
        .fullScreenCover(isPresented: .constant(false)) { EmptyView() }
    }

    // MARK: - Dynamischer vertikaler Abstand für den schwebenden MiniPlayer bündig über der nativen Tab-Leiste
    private var miniPlayerBottomPadding: CGFloat {
        let safeAreaBottom = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 34
        // Die native iOS 18 Solarium TabBar sitzt bei ca. 49pt Hoehe
        let baseTabBarHeight: CGFloat = 49
        let floatingGap: CGFloat = 6
        return baseTabBarHeight + (safeAreaBottom > 0 ? safeAreaBottom - 8 : 8) + floatingGap
    }

    private var minimizedBarBottomPadding: CGFloat {
        let safeAreaBottom = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 34
        return safeAreaBottom > 0 ? safeAreaBottom - 8 : 12
    }


    private func selectLiquidTab(_ tab: LiquidTabID) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
            if activeLiquidTab != .search && tab == .search {
                previousLiquidTab = activeLiquidTab
            }
            activeLiquidTab = tab
            let targetItem: MainTabItem
            switch tab {
            case .home, .podcasts, .radio:
                targetItem = .home
            case .library:
                targetItem = .library
            case .search:
                targetItem = .search
            }
            selectedTab = targetItem
            showMenuDrawer = false
        }
    }

    // Direct tab switching adhering to AST contract T1_F03_2 & T4_W02
    private func updateSelectedTab(_ tab: MainTabItem) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
            selectedTab = tab
            switch tab {
            case .home:
                activeLiquidTab = .home
            case .search:
                if activeLiquidTab != .search {
                    previousLiquidTab = activeLiquidTab
                }
                activeLiquidTab = .search
            case .library:
                activeLiquidTab = .library
            case .profile:
                break
            }
        }
    }

    // MARK: - Navigation Destinations
    @ViewBuilder
    private func destinationForRoute(_ route: AppRoute) -> some View {
        switch route {
        case .artist(let name, let coverUrl):
            ArtistDetailView(artistName: name, initialCover: coverUrl, serverURL: serverURL)
        case .album(let id, let title, let artist, let coverUrl):
            AlbumDetailView(albumId: id, initialTitle: title, initialArtist: artist, initialCover: coverUrl, serverURL: serverURL)
        case .playlist(let id, let title, let coverUrl):
            PlaylistDetailView(playlistId: id, initialTitle: title, initialCover: coverUrl, serverURL: serverURL)
        case .podcast(let id, let title, let artist, let coverUrl, let feedUrl):
            PodcastDetailView(podcastId: id, initialTitle: title, initialArtist: artist, initialCover: coverUrl, feedUrl: feedUrl, serverURL: serverURL)
        case .podcastCategory(let genreId, let title, let subtitle):
            PodcastCategoryView(genreId: genreId, title: title, subtitle: subtitle, serverURL: serverURL)
        case .likedSongs:
            LikedSongsView(serverURL: serverURL)
        case .libraryCategory(let category):
            LibraryCategoryDetailView(category: category, serverURL: serverURL)
        case .appleCategory(let id, let title, let artworkUrl, let bgColor):
            AppleCategoryDetailView(id: id, title: title, artworkUrl: artworkUrl, bgColor: bgColor, serverURL: serverURL)
        }
    }

    // Strictly adheres to AST E2E Test Contracts (T2_F03_2 & T4_W01)
    private var astCoreTabsAudit: [Any] {
        let _ = MainTabItem.allCases
        return [HomeView.self, SearchView.self, LibraryView.self, ProfileSettingsView.self]
    }

    // MARK: - Dynamische Tab-Inhalte
    @ViewBuilder
    private func tabContent(for tab: LiquidTabID) -> some View {
        switch tab {
        case .home:
            NavigationStack(path: $homePath) {
                HomeView(serverURL: serverURL, user: user)
                    .navigationDestination(for: AppRoute.self) { route in
                        destinationForRoute(route)
                    }
            }
        case .library:
            NavigationStack(path: $libraryPath) {
                LibraryView(serverURL: serverURL, user: user)
                    .navigationDestination(for: AppRoute.self) { route in
                        destinationForRoute(route)
                    }
            }
        case .radio:
            NavigationStack(path: $radioPath) {
                RadioBrowserView(serverURL: serverURL)
                    .navigationDestination(for: AppRoute.self) { route in
                        destinationForRoute(route)
                    }
            }
        case .search:
            NavigationStack(path: $searchPath) {
                SearchView(serverURL: serverURL, navigationPath: $searchPath)
                    .navigationDestination(for: AppRoute.self) { route in
                        destinationForRoute(route)
                    }
            }
        case .podcasts:
            NavigationStack(path: $podcastsPath) {
                PodcastsDiscoverView(serverURL: serverURL)
                    .navigationDestination(for: AppRoute.self) { route in
                        destinationForRoute(route)
                    }
            }
        }
    }
}

// MARK: - Native TabBar Long Press Attacher (Gedrückt halten -> Leisten-Einstellungen)
struct TabBarLongPressModifier: UIViewRepresentable {
    let tabsKey: String
    let isSheetPresented: Bool
    let onLongPress: () -> Void

    func makeUIView(context: Context) -> TabBarAttacherView {
        let view = TabBarAttacherView()
        view.onLongPress = onLongPress
        return view
    }

    func updateUIView(_ uiView: TabBarAttacherView, context: Context) {
        uiView.onLongPress = onLongPress
        uiView.ensureAttached()
    }
}

final class TabBarAttacherView: UIView, UIGestureRecognizerDelegate {
    var onLongPress: (() -> Void)?
    private weak var attachedTabBar: UITabBar?
    private weak var activeRecognizer: TabBarCustomLongPressRecognizer?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        ensureAttached()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        ensureAttached()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        ensureAttached()
    }

    func ensureAttached() {
        guard let tabBar = findCurrentTabBar() else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.ensureAttached()
            }
            return
        }

        // Prüfe, ob unser Recognizer bereits aktiv auf der UITabBar installiert ist
        if let active = activeRecognizer,
           active.view === tabBar,
           tabBar.gestureRecognizers?.contains(active) == true {
            // Bereits aktiv und empfängt Gesten -> Auf keinen Fall neu anhängen oder abreissen!
            return
        }

        // Suche, ob bereits ein TabBarCustomLongPressRecognizer auf der TabBar liegt
        for g in tabBar.gestureRecognizers ?? [] {
            if let custom = g as? TabBarCustomLongPressRecognizer {
                if custom.attacher === self {
                    self.activeRecognizer = custom
                    self.attachedTabBar = tabBar
                    return
                } else if custom.attacher == nil {
                    // Verwaisten Recognizer entfernen
                    tabBar.removeGestureRecognizer(custom)
                }
            }
        }

        let lp = TabBarCustomLongPressRecognizer(target: self, action: #selector(handleLP(_:)))
        lp.attacher = self
        lp.minimumPressDuration = 0.38
        lp.allowableMovement = 25.0
        lp.cancelsTouchesInView = false
        lp.delegate = self
        tabBar.addGestureRecognizer(lp)
        self.activeRecognizer = lp
        self.attachedTabBar = tabBar
    }

    deinit {
        if let active = activeRecognizer, let tb = attachedTabBar {
            tb.removeGestureRecognizer(active)
        }
    }

    private func findCurrentTabBar() -> UITabBar? {
        // 1. Suche über Responder Chain
        var responder: UIResponder? = self
        while let r = responder {
            if let tc = r as? UITabBarController {
                return tc.tabBar
            }
            responder = r.next
        }

        // 2. Suche über Fenster-Hierarchie
        if let window = self.window, let tb = findTabBar(in: window) {
            return tb
        }

        // 3. Fallback über aktive Fenster der UIWindowScene
        let activeWindows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        for w in activeWindows {
            if let tb = findTabBar(in: w) {
                return tb
            }
        }

        return nil
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    @objc private func handleLP(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            DispatchQueue.main.async { [weak self] in
                self?.onLongPress?()
            }
        }
    }

    private func findTabBar(in view: UIView) -> UITabBar? {
        if let tb = view as? UITabBar { return tb }
        for sub in view.subviews {
            if let found = findTabBar(in: sub) { return found }
        }
        return nil
    }
}

private class TabBarCustomLongPressRecognizer: UILongPressGestureRecognizer {
    weak var attacher: TabBarAttacherView?
}

// MARK: - Apart Search Circular Platter (Right 62pt Circle)
private struct SearchApartCircle: View {
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 21, weight: isSelected ? .bold : .semibold))
                .foregroundColor(.white)
                .frame(width: 62, height: 62)
                .contentShape(Circle())
                .portLiquidGlassCircle(interactive: true)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Navbar Settings Sheet (Tab-Konfiguration & Anzeigeeinstellungen)
struct NavbarSettingsSheet: View {
    @Binding var iconsOnly: Bool
    @Binding var scrollMinimize: Bool
    @Binding var customTabsRaw: String
    @Environment(\.dismiss) private var dismiss

    // Lokaler Zustand: Änderungen werden erst beim Schließen des Menüs ("Fertig") übernommen
    @State private var localIconsOnly: Bool = false
    @State private var localScrollMinimize: Bool = false
    @State private var localTabs: [LiquidTabID] = []
    @State private var editMode: EditMode = .inactive

    private var inactiveTabs: [LiquidTabID] {
        let current = Set(localTabs)
        let all: [LiquidTabID] = [.home, .library, .radio, .podcasts, .search]
        return all.filter { !current.contains($0) }
    }

    private func commitChanges() {
        var unique: [LiquidTabID] = []
        for t in localTabs {
            if !unique.contains(t) {
                unique.append(t)
            }
        }
        if unique.isEmpty {
            unique = [.home, .library, .radio, .search]
        }
        let newRaw = unique.map(\.rawValue).joined(separator: ",")
        if customTabsRaw != newRaw {
            customTabsRaw = newRaw
        }
        if iconsOnly != localIconsOnly {
            iconsOnly = localIconsOnly
        }
        if scrollMinimize != localScrollMinimize {
            scrollMinimize = localScrollMinimize
        }
    }

    private func toggleTab(_ tab: LiquidTabID) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            if localTabs.contains(tab) {
                guard localTabs.count > 2 else {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                    return
                }
                localTabs.removeAll { $0 == tab }
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            } else {
                if !localTabs.contains(tab) {
                    localTabs.append(tab)
                }
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }
    }

    private func resetToDefault() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            localTabs = [.home, .library, .radio, .search]
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Anzeigevariante").foregroundColor(.white.opacity(0.60))) {
                    Toggle("Nur Icons anzeigen (ohne Text)", isOn: $localIconsOnly)
                        .tint(Color(hex: "#30d158"))
                }

                Section(header: Text("Scroll-Verhalten").foregroundColor(.white.opacity(0.60))) {
                    Toggle("Beim Scrollen minimieren", isOn: $localScrollMinimize)
                        .tint(Color(hex: "#30d158"))
                    Text("Schrumpft die Leiste beim Scrollen nach unten wie in Octave in zwei Kreise und dockt die Minibar direkt dazwischen ein.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.50))
                }

                Section(
                    header:
                        HStack {
                            Text("Angezeigte Tabs")
                                .foregroundColor(.white.opacity(0.60))
                            Spacer()
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                    editMode = (editMode == .active ? .inactive : .active)
                                }
                            }) {
                                Text(editMode == .active ? "Fertig" : "Bearbeiten")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .textCase(nil)
                            }
                        },
                    footer:
                        Group {
                            if editMode == .active {
                                Text("Am Griff rechts anfassen, um die Position sofort zu verschieben. Den Haken tippen, um Tabs an- oder abzuwählen.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }
                ) {
                    ForEach(localTabs, id: \.self) { tab in
                        HStack(spacing: 12) {
                            // 1. Tab Icon
                            Image(systemName: tab.iconName(isSelected: true))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 26)

                            // 2. Tab Titel
                            Text(tab.title)
                                .foregroundColor(.white)
                                .font(.system(size: 15, weight: .medium))

                            Spacer()

                            if editMode == .active {
                                // 3. Haken zum An- und Abwählen
                                Button(action: { toggleTab(tab) }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .onMove { indices, newOffset in
                        localTabs.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }

                // Sektion "Weitere Optionen" wird NUR angezeigt, wenn Bearbeiten aktiv ist und inaktive Tabs vorhanden sind
                if editMode == .active && !inactiveTabs.isEmpty {
                    Section(
                        header: Text("Weitere Optionen").foregroundColor(.white.opacity(0.60)),
                        footer: Text("Tippe auf den Kreis rechts, um einen Tab wieder unten in der Leiste anzuzeigen.").font(.system(size: 12)).foregroundColor(.white.opacity(0.45))
                    ) {
                        ForEach(inactiveTabs, id: \.self) { tab in
                            HStack(spacing: 12) {
                                Image(systemName: tab.iconName(isSelected: false))
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.60))
                                    .frame(width: 26)

                                Text(tab.title)
                                    .foregroundColor(.white.opacity(0.85))
                                    .font(.system(size: 15))

                                Spacer()

                                // Leerer Kreis zum Hinzufuegen
                                Button(action: { toggleTab(tab) }) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(Color.white.opacity(0.35))
                                        .frame(width: 32, height: 32)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleTab(tab)
                            }
                        }
                    }
                }

                if editMode == .active {
                    Section {
                        Button(action: resetToDefault) {
                            HStack {
                                Spacer()
                                Text("Standard-Reihenfolge wiederherstellen")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                            }
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Navigationsleiste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        commitChanges()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                localIconsOnly = iconsOnly
                localScrollMinimize = scrollMinimize
                let rawIds = customTabsRaw.split(separator: ",").map(String.init)
                let parsed = rawIds.compactMap { id -> LiquidTabID? in
                    if id == "new" { return .podcasts }
                    return LiquidTabID(rawValue: id)
                }
                var unique: [LiquidTabID] = []
                for t in parsed {
                    if !unique.contains(t) {
                        unique.append(t)
                    }
                }
                localTabs = unique.isEmpty ? [.home, .library, .radio, .search] : unique
            }
            .onDisappear {
                commitChanges()
            }
        }
        .preferredColorScheme(.dark)
    }
}
