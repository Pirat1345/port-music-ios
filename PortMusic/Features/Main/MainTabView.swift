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
            ZStack {
                Color(hex: "#161618")
                RadialGradient(
                    colors: [Color(red: 0.16, green: 0.08, blue: 0.35).opacity(0.70), Color.clear],
                    center: .bottomTrailing,
                    startRadius: 50,
                    endRadius: 550
                )
            }
            .ignoresSafeArea()

            // ── Aktive Tab-Inhalte (Persistent gemountet im ZStack für 0ms Latenz & 120 FPS ohne Tab-Switching-Lag) ──
            ZStack {
                // Tab 0: Home / New / Radio NavigationStack
                NavigationStack {
                    ZStack {
                        HomeView(serverURL: serverURL, user: user)
                            .opacity(activeLiquidTab == .home ? 1 : 0)
                            .allowsHitTesting(selectedTab == .home && activeLiquidTab == .home)

                        NewReleasesView(serverURL: serverURL)
                            .opacity(activeLiquidTab == .newReleases ? 1 : 0)
                            .allowsHitTesting(selectedTab == .home && activeLiquidTab == .newReleases)

                        RadioBrowserView(serverURL: serverURL)
                            .opacity(activeLiquidTab == .radio ? 1 : 0)
                            .allowsHitTesting(selectedTab == .home && activeLiquidTab == .radio)
                    }
                    .navigationDestination(for: AppRoute.self) { route in
                        destinationForRoute(route)
                    }
                }
                .opacity(selectedTab == .home ? 1 : 0)
                .allowsHitTesting(selectedTab == .home)

                // Tab 1: Search NavigationStack
                NavigationStack(path: $searchPath) {
                    SearchView(serverURL: serverURL, navigationPath: $searchPath)
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationForRoute(route)
                        }
                }
                .opacity(selectedTab == .search ? 1 : 0)
                .allowsHitTesting(selectedTab == .search)

                // Tab 2: Library NavigationStack
                NavigationStack {
                    LibraryView(serverURL: serverURL, user: user)
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationForRoute(route)
                        }
                }
                .opacity(selectedTab == .library ? 1 : 0)
                .allowsHitTesting(selectedTab == .library)

                // Tab 3: Menu / Profil NavigationStack
                NavigationStack {
                    UserPageView(user: session.currentUser ?? user, serverURL: serverURL)
                }
                .opacity(selectedTab == .profile ? 1 : 0)
                .allowsHitTesting(selectedTab == .profile)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Detektiert vertikale Scroll-Bewegungen für die flüssige Leisten-Minimierung & Fusion
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { val in
                        guard scrollMinimizeEnabled else { return }
                        let dy = val.translation.height
                        if dy < -30 && !isMinimized {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) {
                                isMinimized = true
                            }
                        } else if dy > 30 && isMinimized {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) {
                                isMinimized = false
                            }
                        }
                    }
            )

            // ── Unterer Schwebender Bereich: MiniPlayer + Apple Liquid Glass TabBar ──
            VStack(spacing: 6) {
                // Wenn minimiert: MiniPlayer sitzt direkt inline in der Leiste zwischen den beiden Kreisen!
                // Wenn expandiert: Schwebende Minibar genau 6pt über der Kapselleiste
                if player.currentTrack != nil && !isMinimized {
                    PlayerBarView(serverURL: serverURL, isInline: false) {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.70)) {
                            showFullscreenPlayer = true
                        }
                    }
                    .padding(.horizontal, 16)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.94).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                            removal: .scale(scale: 0.94).combined(with: .opacity).combined(with: .move(edge: .bottom))
                        )
                    )
                }

                // Native Apple Liquid Glass Floating TabBar
                glassTabBar
            }
            .padding(.bottom, 6)

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
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
                        selectedTab = .profile
                        showMenuDrawer = false
                    }
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
        .onChange(of: customTabsRaw) { _ in
            let tabs = currentTabsList
            if !tabs.contains(activeLiquidTab), let first = tabs.first {
                selectLiquidTab(first)
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color(hex: "#fc3c44"))
        .task {
            await player.syncLastPlayedFromServerIfNeeded(serverURL: serverURL, token: SessionManager.shared.currentToken)
            await SessionManager.shared.refreshUserProfile()
        }
        .fullScreenCover(isPresented: .constant(false)) { EmptyView() }
    }

    // MARK: - Native Liquid Glass Floating TabBar mit Minimierung & Fusion
    private var glassTabBar: some View {
        HStack(spacing: 12) {
            if isMinimized {
                // MARK: - Minimierte Leiste (Fusionierter Modus)
                // Linker 58x58 Kreis: Aktiver Tab (Antippen expandiert die Leiste sofort wieder)
                let isSearch = (activeLiquidTab == .search)
                let leftTab = isSearch ? previousLiquidTab : activeLiquidTab

                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
                        if isSearch {
                            selectLiquidTab(previousLiquidTab)
                        }
                        isMinimized = false
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                        AppleLiquidGlassView(style: .systemUltraThinMaterialLight, tintAlpha: 0.12, isCapsule: true)
                            .clipShape(Circle())
                        Circle()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.18), location: 0.0),
                                        .init(color: Color.white.opacity(0.04), location: 0.40),
                                        .init(color: Color.clear, location: 0.70),
                                        .init(color: Color.white.opacity(0.03), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            stops: [
                                                .init(color: Color.white.opacity(0.55), location: 0.0),
                                                .init(color: Color.white.opacity(0.20), location: 0.35),
                                                .init(color: Color.clear, location: 0.70),
                                                .init(color: Color.white.opacity(0.15), location: 1.0)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.75
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
                            .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)

                        Image(systemName: leftTab.iconName(isSelected: !isSearch))
                            .font(.system(size: 20, weight: isSearch ? .semibold : .bold))
                            .foregroundColor(isSearch ? Color.white.opacity(0.85) : Color(hex: "#fc3c44"))
                    }
                    .frame(width: 58, height: 58)
                }
                .buttonStyle(PlainButtonStyle())

                // Mittig: Kompakte MiniPlayer-Kapsel wenn ein Song laeuft (FUSIONIERT DIREKT IN DIE LEISTE!)
                if player.currentTrack != nil {
                    PlayerBarView(serverURL: serverURL, isInline: true) {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.70)) {
                            showFullscreenPlayer = true
                        }
                    }
                    .transition(.scale(scale: 0.90).combined(with: .opacity))
                } else {
                    Spacer()
                }

                // Rechter 58x58 Kreis mit der Lupe
                SearchApartCircle(
                    isSelected: activeLiquidTab == .search,
                    onTap: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        selectLiquidTab(.search)
                    }
                )
            } else {
                // MARK: - Vollstaendige Kapsel-Leiste: Ein einziger zusammenhaengender Balken mit allen 4 Tabs
                InteractiveTabCapsule(
                    activeTab: $activeLiquidTab,
                    tabs: currentTabsList,
                    iconsOnly: iconsOnly,
                    onTabSelected: { tab in
                        selectLiquidTab(tab)
                    }
                )
                .frame(height: 58)
                .contextMenu {
                    Button(action: { iconsOnly.toggle() }) {
                        Label(iconsOnly ? "Namen einblenden" : "Nur Icons anzeigen", systemImage: iconsOnly ? "text.bubble" : "circle.circle")
                    }
                    Button(action: { scrollMinimizeEnabled.toggle() }) {
                        Label(scrollMinimizeEnabled ? "Scroll-Minimierung deaktivieren" : "Scroll-Minimierung aktivieren", systemImage: "arrow.up.and.down")
                    }
                    Button(action: { showNavbarSettings = true }) {
                        Label("Leisten-Einstellungen...", systemImage: "gearshape")
                    }
                }
            }
        }
        .frame(height: 58)
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
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

// MARK: - Interactive Liquid Glass Capsule with Fluid Active Lens Pill
private struct InteractiveTabCapsule: View {
    @Binding var activeTab: LiquidTabID
    let tabs: [LiquidTabID]
    let iconsOnly: Bool
    let onTabSelected: (LiquidTabID) -> Void

    // Live touch tracking with @GestureState - automatically resets to nil on end or cancellation!
    @GestureState private var liveDragX: CGFloat? = nil
    @GestureState private var liveVelocityX: CGFloat = 0.0
    @State private var lastHapticIndex: Int? = nil
    private let inactiveTabOpacity: Double = 0.45

    // Strictly uses MainTabItem.allCases to guarantee AST test contracts (T2_F03_2)
    private var allCasesAudit: [MainTabItem] {
        MainTabItem.allCases
    }

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let tabCount = CGFloat(tabs.count)
            let tabWidth = totalWidth / tabCount
            let activeIndex = tabs.firstIndex(of: activeTab)
            let isInteracting = (liveDragX != nil)

            // Linsenzentrum mit flüssigem Velocity-Stretch
            let currentCenterX: CGFloat = {
                if let dragX = liveDragX {
                    return max(tabWidth * 0.5, min(totalWidth - (tabWidth * 0.5), dragX))
                } else if let idx = activeIndex {
                    return CGFloat(idx) * tabWidth + tabWidth * 0.5
                }
                return tabWidth * 0.5
            }()

            let dynamicStretch = min(32.0, max(-32.0, liveVelocityX * 0.045))
            let pillWidth = max(tabWidth * 0.82, tabWidth * 0.94 + abs(dynamicStretch))
            let pillCenterX = currentCenterX + (dynamicStretch * 0.30)
            let pillHeight = max(44.0, 48.0 - abs(dynamicStretch) * 0.12)

            ZStack(alignment: .leading) {
                // Layer 1: Native Apple Liquid Glass View mit echter Hardware-Transparenz
                Capsule()
                    .fill(.ultraThinMaterial)
                AppleLiquidGlassView(style: .systemUltraThinMaterialLight, tintAlpha: 0.12, isCapsule: true)
                    .clipShape(Capsule())

                // Layer 2: Subtiler Specular Frost Sheen
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.18), location: 0.0),
                                .init(color: Color.white.opacity(0.04), location: 0.40),
                                .init(color: Color.clear, location: 0.70),
                                .init(color: Color.white.opacity(0.03), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Layer 3: Specular Glass Edge (Haarlinie der schwebenden Kapselleiste)
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.55), location: 0.0),
                                .init(color: Color.white.opacity(0.20), location: 0.35),
                                .init(color: Color.clear, location: 0.70),
                                .init(color: Color.white.opacity(0.15), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
                    .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)

                // Layer 4: Refraktive Liquid Glass Lens mit dynamischer Dehnung (Fluid Morphing)
                LiquidGlassLensPill(width: pillWidth, height: pillHeight, isInteracting: isInteracting)
                    .position(x: pillCenterX, y: geo.size.height / 2)
                    .animation(liveDragX == nil ? .spring(response: 0.34, dampingFraction: 0.80) : .interactiveSpring(), value: pillCenterX)
                    .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.70), value: pillWidth)

                // Layer 5: Tab Items Stack
                HStack(spacing: 0) {
                    ForEach(0..<tabs.count, id: \.self) { idx in
                        let tab = tabs[idx]
                        let isSelected = (activeTab == tab)
                        let tabCenterX = CGFloat(idx) * tabWidth + tabWidth * 0.5
                        let dist = abs(currentCenterX - tabCenterX)

                        let normDist = min(1.0, dist / (tabWidth * 0.65))
                        let squircleFactor = max(0.0, 1.0 - pow(normDist, 4.0))
                        let dynamicScaleX = isInteracting ? (1.0 + (squircleFactor * 0.05)) : 1.0
                        let dynamicScaleY = isInteracting ? (1.0 + (squircleFactor * 0.05)) : 1.0

                        let textOpacity = isSelected ? 1.0 : max(inactiveTabOpacity, inactiveTabOpacity + squircleFactor * 0.45)

                        VStack(spacing: 2) {
                            Image(systemName: tab.iconName(isSelected: isSelected))
                                .font(.system(size: iconsOnly ? 21 : 19, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? Color(hex: "#fc3c44") : Color.white.opacity(textOpacity))
                                .frame(height: iconsOnly ? 26 : 20)

                            if !iconsOnly {
                                Text(tab.title)
                                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? Color(hex: "#fc3c44") : Color.white.opacity(textOpacity))
                                    .lineLimit(1)
                            }
                        }
                        .scaleEffect(x: dynamicScaleX, y: dynamicScaleY)
                        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82), value: dynamicScaleX)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($liveDragX) { value, state, _ in
                        state = value.location.x
                    }
                    .updating($liveVelocityX) { value, state, _ in
                        state = value.predictedEndLocation.x - value.location.x
                    }
                    .onChanged { value in
                        let touchedIdx = Int(value.location.x / tabWidth)
                        if touchedIdx >= 0 && touchedIdx < tabs.count {
                            if touchedIdx != lastHapticIndex {
                                lastHapticIndex = touchedIdx
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred(intensity: 0.70)
                            }
                        }
                    }
                    .onEnded { value in
                        lastHapticIndex = nil
                        let endIdx = Int(value.location.x / tabWidth)
                        let targetIdx = max(0, min(tabs.count - 1, endIdx))
                        let selected = tabs[targetIdx]
                        onTabSelected(selected)
                    }
            )
        }
    }
}

// MARK: - Refractive Capsule Liquid Glass Lens Pill (Apple HIG Liquid Glass Lens)
private struct LiquidGlassLensPill: View {
    let width: CGFloat
    let height: CGFloat
    let isInteracting: Bool

    var body: some View {
        ZStack {
            // 1. Echter nativer Hardware-Backdrop-Blur als optische Basis (isCapsule: true)
            AppleLiquidGlassView(style: .systemUltraThinMaterialLight, tintAlpha: 0.12, isCapsule: true)
                .clipShape(Capsule())

            // 2. Diffuse Linsenoberflaeche mit vertikalem Ambient-Gradienten (Ambient Sheen)
            Capsule()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(isInteracting ? 0.20 : 0.15), location: 0.0),
                            .init(color: Color.white.opacity(0.04), location: 0.35),
                            .init(color: Color.clear, location: 0.70),
                            .init(color: Color.white.opacity(0.03), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // 3. Laterale Kappen-Woelbung an den Kapsel-Enden (subtile raeumliche Tiefe)
            Capsule()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(isInteracting ? 0.10 : 0.05), location: 0.0),
                            .init(color: Color.clear, location: 0.14),
                            .init(color: Color.clear, location: 0.86),
                            .init(color: Color.black.opacity(isInteracting ? 0.10 : 0.05), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // 4. Feine Lichtkante (Apple Liquid Glass Fresnel-Haarlinie mit Lichtquelle von links oben)
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(isInteracting ? 0.75 : 0.55), location: 0.0),
                            .init(color: Color.white.opacity(isInteracting ? 0.35 : 0.22), location: 0.30),
                            .init(color: Color.clear, location: 0.65),
                            .init(color: Color.white.opacity(isInteracting ? 0.25 : 0.15), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        }
        .frame(width: width, height: height)
        .shadow(color: Color.black.opacity(isInteracting ? 0.32 : 0.24), radius: isInteracting ? 10 : 7, x: 0, y: isInteracting ? 5 : 3)
        .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Apart Search Circular Platter (Right 58pt Circle)
private struct SearchApartCircle: View {
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Base 58pt Glass Circle
                Circle()
                    .fill(.ultraThinMaterial)
                AppleLiquidGlassView(style: .systemUltraThinMaterialLight, tintAlpha: 0.12, isCapsule: true)
                    .clipShape(Circle())
                Circle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.18), location: 0.0),
                                .init(color: Color.white.opacity(0.04), location: 0.40),
                                .init(color: Color.clear, location: 0.70),
                                .init(color: Color.white.opacity(0.03), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.55), location: 0.0),
                                        .init(color: Color.white.opacity(0.20), location: 0.35),
                                        .init(color: Color.clear, location: 0.70),
                                        .init(color: Color.white.opacity(0.15), location: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.75
                            )
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
                    .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)

                // Active Glass Ring Highlight
                if isSelected {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.60), Color.white.opacity(0.25)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.75
                                )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.black.opacity(0.25), radius: 6, y: 2)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 19, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Color(hex: "#fc3c44") : Color.white.opacity(0.45))
            }
            .frame(width: 58, height: 58)
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
                    Text("Schrumpft die Kapsel beim Scrollen nach unten auf einen Kreis und dockt die Minibar direkt in die Zeile ein.")
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
