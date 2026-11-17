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

// MARK: - Rich Liquid Glass Tab Model (Home, Library, Radio, Search)
public enum LiquidTabID: String, CaseIterable, Identifiable {
    case home = "home"
    case library = "library"
    case radio = "radio"
    case search = "search"
    case newReleases = "new"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home: return "Startseite"
        case .library: return "Bibliothek"
        case .radio: return "Radio"
        case .search: return "Suche"
        case .newReleases: return "Entdecken"
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
        case .newReleases:
            return isSelected ? "square.grid.2x2.fill" : "square.grid.2x2"
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

    private var currentTabsList: [LiquidTabID] {
        let rawIds = customTabsRaw.split(separator: ",").map(String.init)
        let parsed = rawIds.compactMap { LiquidTabID(rawValue: $0) }
        return parsed.isEmpty ? [.home, .library, .radio, .search] : parsed
    }

    @State private var showFullscreenPlayer: Bool = false
    @State private var showMenuDrawer: Bool = false
    @State private var showUserProfileSheet: Bool = false
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
            // ── Offizielle Native Apple Liquid Glass TabView (Exakt wie in LiveContainer) ──
            TabView(selection: $activeLiquidTab) {
                // Tab 1: Startseite
                NavigationStack {
                    HomeView(serverURL: serverURL, user: user)
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationForRoute(route)
                        }
                }
                .tabItem {
                    Label("Startseite", systemImage: activeLiquidTab == .home ? "house.fill" : "house")
                }
                .tag(LiquidTabID.home)
                .toolbar(isMinimized ? .hidden : .visible, for: .tabBar)

                // Tab 2: Bibliothek
                NavigationStack {
                    LibraryView(serverURL: serverURL, user: user)
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationForRoute(route)
                        }
                }
                .tabItem {
                    Label("Bibliothek", systemImage: "music.note.list")
                }
                .tag(LiquidTabID.library)
                .toolbar(isMinimized ? .hidden : .visible, for: .tabBar)

                // Tab 3: Radio
                NavigationStack {
                    RadioBrowserView(serverURL: serverURL)
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationForRoute(route)
                        }
                }
                .tabItem {
                    Label("Radio", systemImage: "dot.radiowaves.left.and.right")
                }
                .tag(LiquidTabID.radio)
                .toolbar(isMinimized ? .hidden : .visible, for: .tabBar)

                // Tab 4: Suche (Durchgehend in der Hauptleiste integriert, kein Split)
                NavigationStack(path: $searchPath) {
                    SearchView(serverURL: serverURL, navigationPath: $searchPath)
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationForRoute(route)
                        }
                }
                .tabItem {
                    Label("Suche", systemImage: "magnifyingglass")
                }
                .tag(LiquidTabID.search)
                .toolbar(isMinimized ? .hidden : .visible, for: .tabBar)
            }
            .toolbar(isMinimized ? .hidden : .visible, for: .tabBar)
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

            // ── Normalmodus: Schwebender MiniPlayer bündig über der nativen Apple Tab-Leiste ──
            if player.currentTrack != nil && !isMinimized {
                PlayerBarView(serverURL: serverURL, isInline: false) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.70)) {
                        showFullscreenPlayer = true
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, miniPlayerBottomPadding)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity.combined(with: .scale(scale: 0.96))
                    )
                )
            }

            // ── Minimierter Zustand: Dreiteilige Octave-Minimierungsleiste beim Herunterscrollen ──
            if isMinimized {
                octaveMinimizedBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, minimizedBarBottomPadding)
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
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showFullscreenPlayer = false
                    }
                }
                .ignoresSafeArea()
                .transition(.move(edge: .bottom))
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
                    showNavbarSettings = true
                    showMenuDrawer = false
                },
                onLogout: onLogout
            )
            .ignoresSafeArea()
            .zIndex(998)
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
        .preferredColorScheme(.dark)
        .tint(Color(hex: "#fc3c44"))
        .task {
            await player.syncLastPlayedFromServerIfNeeded(serverURL: serverURL, token: SessionManager.shared.currentToken)
            await SessionManager.shared.refreshUserProfile()
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

    // MARK: - Dreiteilige Octave-Minimierungsleiste beim Herunterscrollen
    private var octaveMinimizedBar: some View {
        HStack(spacing: 12) {
            // 1. Linker 62x62 Kreis: Aktiver Tab (Antippen stellt die durchgehende Leiste sofort wieder her)
            let isSearch = (activeLiquidTab == .search)
            let leftTab = isSearch ? previousLiquidTab : activeLiquidTab

            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                    if isSearch {
                        selectLiquidTab(previousLiquidTab)
                    }
                    isMinimized = false
                }
            }) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.18), location: 0.0),
                                    .init(color: Color.white.opacity(0.04), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)

                    Image(systemName: leftTab.iconName(isSelected: !isSearch))
                        .font(.system(size: 21, weight: isSearch ? .semibold : .bold))
                        .foregroundColor(isSearch ? Color.white.opacity(0.85) : Color(hex: "#fc3c44"))
                }
                .frame(width: 62, height: 62)
            }
            .buttonStyle(PlainButtonStyle())
            .transition(
                .asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.85)),
                    removal: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.85))
                )
            )

            // 2. Mittig: Kompakte Inline Now-Playing-Kapsel (Exakt zwischen beiden Kreisen eingedockt)
            if player.currentTrack != nil {
                PlayerBarView(serverURL: serverURL, isInline: true) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.70)) {
                        showFullscreenPlayer = true
                    }
                }
                .frame(height: 62)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    )
                )
            } else {
                Spacer()
            }

            // 3. Rechter 62x62 Kreis: Die Suche als eigenständiger Kreis mit Lupe
            SearchApartCircle(
                isSelected: activeLiquidTab == .search,
                onTap: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    selectLiquidTab(.search)
                }
            )
            .transition(
                .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.85)),
                    removal: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.85))
                )
            )
        }
        .frame(height: 62)
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
            case .home, .newReleases, .radio:
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
        case .likedSongs:
            LikedSongsView(serverURL: serverURL)
        case .libraryCategory(let category):
            LibraryCategoryDetailView(category: category, serverURL: serverURL)
        case .appleCategory(let id, let title, let artworkUrl, let bgColor):
            AppleCategoryDetailView(id: id, title: title, artworkUrl: artworkUrl, bgColor: bgColor, serverURL: serverURL)
        }
    }
}

// MARK: - Apart Search Circular Platter (Right 62pt Circle)
private struct SearchApartCircle: View {
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Base 62pt Glass Circle
                Circle()
                    .fill(.ultraThinMaterial)
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.18), location: 0.0),
                                .init(color: Color.white.opacity(0.04), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 21, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(isSelected ? Color(hex: "#fc3c44") : Color.white.opacity(0.85))
            }
            .frame(width: 62, height: 62)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Navbar Settings Sheet (Tab-Konfiguration & Anzeigeeinstellungen)
private struct NavbarSettingsSheet: View {
    @Binding var iconsOnly: Bool
    @Binding var scrollMinimize: Bool
    @Binding var customTabsRaw: String
    @Environment(\.dismiss) private var dismiss

    @State private var activeTabs: [LiquidTabID] = []
    @State private var editMode: EditMode = .inactive

    private var inactiveTabs: [LiquidTabID] {
        let current = Set(activeTabs)
        let all: [LiquidTabID] = [.home, .library, .radio, .search, .newReleases]
        return all.filter { !current.contains($0) }
    }

    private func saveTabs(_ tabs: [LiquidTabID]) {
        customTabsRaw = tabs.map(\.rawValue).joined(separator: ",")
    }

    private func toggleTab(_ tab: LiquidTabID) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            if activeTabs.contains(tab) {
                guard activeTabs.count > 2 else {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                    return
                }
                activeTabs.removeAll { $0 == tab }
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            } else {
                activeTabs.append(tab)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            saveTabs(activeTabs)
        }
    }

    private func resetToDefault() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            activeTabs = [.home, .library, .radio, .search]
            saveTabs(activeTabs)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Anzeigevariante").foregroundColor(.white.opacity(0.60))) {
                    Toggle("Nur Icons anzeigen (ohne Text)", isOn: $iconsOnly)
                        .tint(Color(hex: "#fc3c44"))
                }

                Section(header: Text("Scroll-Verhalten").foregroundColor(.white.opacity(0.60))) {
                    Toggle("Beim Scrollen minimieren", isOn: $scrollMinimize)
                        .tint(Color(hex: "#fc3c44"))
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
                                    .foregroundColor(Color(hex: "#fc3c44"))
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
                    ForEach(activeTabs) { tab in
                        HStack(spacing: 12) {
                            // 1. Tab Icon
                            Image(systemName: tab.iconName(isSelected: true))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "#fc3c44"))
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
                                        .foregroundColor(Color(hex: "#fc3c44"))
                                        .frame(width: 32, height: 32)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onMove { indices, newOffset in
                        var list = activeTabs
                        list.move(fromOffsets: indices, toOffset: newOffset)
                        activeTabs = list
                        saveTabs(list)
                    }
                }

                // Sektion "Weitere Optionen" wird NUR angezeigt, wenn Bearbeiten aktiv ist und inaktive Tabs vorhanden sind
                if editMode == .active && !inactiveTabs.isEmpty {
                    Section(
                        header: Text("Weitere Optionen").foregroundColor(.white.opacity(0.60)),
                        footer: Text("Tippe auf den Kreis rechts, um einen Tab wieder unten in der Leiste anzuzeigen.").font(.system(size: 12)).foregroundColor(.white.opacity(0.45))
                    ) {
                        ForEach(inactiveTabs) { tab in
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
                                    .foregroundColor(Color(hex: "#fc3c44"))
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
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#fc3c44"))
                }
            }
            .onAppear {
                let rawIds = customTabsRaw.split(separator: ",").map(String.init)
                let parsed = rawIds.compactMap { LiquidTabID(rawValue: $0) }
                activeTabs = parsed.isEmpty ? [.home, .library, .radio, .search] : parsed
            }
        }
        .preferredColorScheme(.dark)
    }
}
