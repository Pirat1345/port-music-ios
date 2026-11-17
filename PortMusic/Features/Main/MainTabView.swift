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

// MARK: - Rich Liquid Glass Tab Model (Exakt wie im Apple Music Referenz-Screenshot: Home, New, Radio, Library + Apart Search)
public enum LiquidTabID: String, CaseIterable, Identifiable {
    case home = "home"
    case newReleases = "new"
    case radio = "radio"
    case library = "library"
    case search = "search"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home: return "Startseite"
        case .newReleases: return "Entdecken"
        case .radio: return "Radio"
        case .library: return "Mediathek"
        case .search: return "Suchen"
        }
    }

    public func iconName(isSelected: Bool) -> String {
        switch self {
        case .home:
            return isSelected ? "house.fill" : "house"
        case .newReleases:
            return isSelected ? "square.grid.2x2.fill" : "square.grid.2x2"
        case .radio:
            return "dot.radiowaves.left.and.right"
        case .library:
            return "music.note.list"
        case .search:
            return "magnifyingglass"
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
    @State private var previousTab: MainTabItem = .home

    // Persistent Navbar Variants & Settings (NavbarSettings.m)
    @AppStorage("navbar_icons_only") private var iconsOnly: Bool = false
    @AppStorage("navbar_scroll_minimize") private var scrollMinimizeEnabled: Bool = true
    @State private var isMinimized: Bool = false
    @State private var showNavbarSettings: Bool = false

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

                // Tab 3: Profile & Settings
                ProfileSettingsView(user: user, serverURL: serverURL, onLogout: onLogout)
                    .opacity(selectedTab == .profile ? 1 : 0)
                    .allowsHitTesting(selectedTab == .profile)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Detektiert vertikale Scroll-Bewegungen für die flüssige Leisten-Minimierung
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

            // ── Unterer Schwebender Bereich: MiniPlayer + Custom Liquid Glass TabBar ──
            VStack(spacing: 8) {
                // Wenn minimiert: MiniPlayer sitzt direkt inline in der Leiste zwischen den beiden Kreisen!
                // Wenn expandiert: Schwebende Minibar über der Kapselleiste
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

                // Custom Liquid Glass Floating Split TabBar
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
            NavbarSettingsSheet(iconsOnly: $iconsOnly, scrollMinimize: $scrollMinimizeEnabled)
        }
        .preferredColorScheme(.dark)
        .task {
            await player.syncLastPlayedFromServerIfNeeded(serverURL: serverURL, token: SessionManager.shared.currentToken)
            await SessionManager.shared.refreshUserProfile()
        }
        .fullScreenCover(isPresented: .constant(false)) { EmptyView() }
    }

    // MARK: - Native Liquid Glass Floating Split TabBar
    private var glassTabBar: some View {
        HStack(spacing: 12) {
            if isMinimized {
                // MARK: - Minimierte Leiste (TabBarMinimize.x)
                // Linker 62x62 Kreis mit dem Icon des aktiven Tabs
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
                        isMinimized = false
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                        AppleLiquidGlassView(style: .systemChromeMaterialDark, tintAlpha: 0.40)
                            .clipShape(Circle())
                        Circle()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.14), location: 0.0),
                                        .init(color: Color.white.opacity(0.04), location: 0.45),
                                        .init(color: Color.black.opacity(0.06), location: 1.0)
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
                                                .init(color: Color.white.opacity(0.65), location: 0.0),
                                                .init(color: Color.white.opacity(0.24), location: 0.35),
                                                .init(color: Color.white.opacity(0.08), location: 1.0)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 0.85
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.45), radius: 16, x: 0, y: 8)
                            .shadow(color: Color.black.opacity(0.20), radius: 4, x: 0, y: 2)

                        Image(systemName: activeLiquidTab.iconName(isSelected: true))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "#fc3c44"))
                    }
                    .frame(width: 62, height: 62)
                }
                .buttonStyle(PlainButtonStyle())

                // Mittig: Kompakte MiniPlayer-Kapsel wenn ein Song laeuft
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

                // Rechter 62x62 Kreis mit der Lupe
                SearchApartCircle(
                    isSelected: activeLiquidTab == .search,
                    onTap: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        selectLiquidTab(.search)
                        NotificationCenter.default.post(name: NSNotification.Name("PortMusic_FocusSearchField"), object: nil)
                    }
                )
            } else {
                // MARK: - Vollstaendige Kapsel-Leiste: Ein einziger ovaler Balken mit allen Buttons (inkl. Search)
                InteractiveTabCapsule(
                    activeTab: $activeLiquidTab,
                    iconsOnly: iconsOnly,
                    onTabSelected: { tab in
                        selectLiquidTab(tab)
                    },
                    onOpenSettings: {
                        showNavbarSettings = true
                    }
                )
                .frame(height: 62)
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
        .frame(height: 62)
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
    }

    private func selectLiquidTab(_ tab: LiquidTabID) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
            activeLiquidTab = tab
            let targetItem: MainTabItem
            switch tab {
            case .home, .newReleases, .radio:
                targetItem = .home
            case .library:
                targetItem = .library
            case .search:
                targetItem = .search
                NotificationCenter.default.post(name: NSNotification.Name("PortMusic_FocusSearchField"), object: nil)
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

// MARK: - Refractive Liquid Glass Lens Pill (Auswahl-Linse mit nativer Lichtbrechung & 3D-Kantenkrümmung)
private struct LiquidGlassLensPill: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            // 1. Echter nativer UIGlassEffect für die Kapsel-Linse (Bricht das Licht des Hintergrunds)
            AppleLiquidGlassView(style: .systemUltraThinMaterialLight, tintAlpha: 0.12, isCapsule: true)

            // 2. 3D-Linsenbäuchung (Zylindrisch-konvexe Wölbung im Linsenzentrum)
            Capsule()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.24), location: 0.0),
                            .init(color: Color.white.opacity(0.08), location: 0.25),
                            .init(color: Color.clear, location: 0.60),
                            .init(color: Color.white.opacity(0.06), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // 3. Laterale Halbkugel-Wölbungen an den runden Enden (Radial Curvature der Kapselkappen)
            // Bringt die echte sphärische Lichtkrümmung an die linken und rechten Enden
            HStack(spacing: 0) {
                // Linke Kantenkrümmung: Bricht das Licht bogenförmig entlang des linken Halbkreises
                Circle()
                    .strokeBorder(
                        RadialGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.55), location: 0.60),
                                .init(color: Color.white.opacity(0.18), location: 0.85),
                                .init(color: Color.clear, location: 1.0)
                            ],
                            center: UnitPoint(x: 0.38, y: 0.38),
                            startRadius: height * 0.15,
                            endRadius: height * 0.50
                        ),
                        lineWidth: 2.2
                    )
                    .frame(width: height, height: height)
                    .blendMode(.plusLighter)

                Spacer(minLength: 0)

                // Rechte Kantenkrümmung: Bricht das Licht bogenförmig entlang des rechten Halbkreises
                Circle()
                    .strokeBorder(
                        RadialGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.40), location: 0.60),
                                .init(color: Color.white.opacity(0.12), location: 0.85),
                                .init(color: Color.clear, location: 1.0)
                            ],
                            center: UnitPoint(x: 0.62, y: 0.38),
                            startRadius: height * 0.15,
                            endRadius: height * 0.50
                        ),
                        lineWidth: 2.2
                    )
                    .frame(width: height, height: height)
                    .blendMode(.plusLighter)
            }
            .clipShape(Capsule())

            // 4. Primäre 3D-Kantenwölbung / Facettenschliff (Äußerer 1.0pt-Refraktionsrand)
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.90, green: 0.96, blue: 1.0, opacity: 0.75), location: 0.0), // Zartes spektrales Cyan-Highlight
                            .init(color: Color.white.opacity(0.35), location: 0.30),
                            .init(color: Color.white.opacity(0.12), location: 0.70),
                            .init(color: Color(red: 1.0, green: 0.96, blue: 0.90, opacity: 0.40), location: 1.0)  // Zartes warmes Austrittslicht
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )

            // 5. Konzentrische Kantenfase (1.5pt Inset - Tiefenrefraktion der Glaskrümmung)
            Capsule()
                .inset(by: 1.5)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.30), location: 0.0),
                            .init(color: Color.clear, location: 0.35),
                            .init(color: Color.black.opacity(0.20), location: 0.75),
                            .init(color: Color.black.opacity(0.32), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )

            // 6. Subtiler innerer Glas-Caustic-Schliff (3.0pt Inset - Lichtsammlung am Boden der Wölbung)
            Capsule()
                .inset(by: 3.0)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.16), location: 0.0),
                            .init(color: Color.clear, location: 0.50),
                            .init(color: Color.white.opacity(0.12), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.6
                )
        }
        .frame(width: width, height: height)
        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 5)
        .shadow(color: Color.black.opacity(0.20), radius: 3, x: 0, y: 1)
        .shadow(color: Color.white.opacity(0.12), radius: 1, x: 0, y: -1)
    }
}

// MARK: - Interactive Liquid Glass Capsule with Fluid Hover Oval
private struct InteractiveTabCapsule: View {
    @Binding var activeTab: LiquidTabID
    let iconsOnly: Bool
    let onTabSelected: (LiquidTabID) -> Void
    let onOpenSettings: () -> Void

    // Live touch tracking with @GestureState - automatically resets to nil on end or cancellation!
    @GestureState private var liveDragX: CGFloat? = nil
    @State private var lastHapticIndex: Int? = nil
    private let inactiveTabOpacity: Double = 0.45

    // Alle 5 Tabs in einer einzigen Schwebekapsel vereint (Home, New, Radio, Library, Search)
    private let tabs: [LiquidTabID] = [.home, .newReleases, .radio, .library, .search]

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

            ZStack(alignment: .leading) {
                // Layer 1: Native Apple Liquid Glass View mit echter Frost-Luminanz
                AppleLiquidGlassView(style: .systemUltraThinMaterialDark, tintAlpha: 0.22, isCapsule: true)

                // Layer 2: Subtiler Specular Frost Sheen
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.14), location: 0.0),
                                .init(color: Color.white.opacity(0.04), location: 0.35),
                                .init(color: Color.clear, location: 0.70),
                                .init(color: Color.black.opacity(0.08), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Layer 3: Specular Glass Edge (Lichtkante)
                Capsule()
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.50), location: 0.0),
                                .init(color: Color.white.opacity(0.20), location: 0.25),
                                .init(color: Color.white.opacity(0.08), location: 0.70),
                                .init(color: Color.white.opacity(0.18), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.85
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 7)
                    .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)

                // Layer 5: Refractive Liquid Glass Lens (Hover & Drag Tracking)
                let currentCenterX: CGFloat = {
                    if let dragX = liveDragX {
                        return max(tabWidth * 0.5, min(totalWidth - tabWidth * 0.5, dragX))
                    } else if let idx = activeIndex {
                        return CGFloat(idx) * tabWidth + tabWidth * 0.5
                    } else {
                        return tabWidth * 0.5
                    }
                }()

                LiquidGlassLensPill(width: tabWidth - 6, height: 52)
                    .position(x: currentCenterX, y: geo.size.height / 2)
                    .animation(liveDragX == nil ? .spring(response: 0.34, dampingFraction: 0.80) : .interactiveSpring(), value: currentCenterX)

                // Layer 6: Tab Items Stack mit optischer Linsen-Wölbungsreaktion (Magnification unter Glas)
                HStack(spacing: 0) {
                    ForEach(0..<tabs.count, id: \.self) { idx in
                        let tab = tabs[idx]
                        let isSelected = (activeTab == tab)
                        let tabCenterX = CGFloat(idx) * tabWidth + tabWidth * 0.5
                        let dist = abs(currentCenterX - tabCenterX)
                        let norm = min(1.0, dist / tabWidth)
                        let proximity = 1.0 - norm
                        let dynamicScale = 1.0 + (proximity * 0.07)
                        let textOpacity = isSelected ? 1.0 : max(inactiveTabOpacity, inactiveTabOpacity + proximity * 0.30)

                        VStack(spacing: 2) {
                            Image(systemName: tab.iconName(isSelected: isSelected))
                                .font(.system(size: iconsOnly ? 22 : 20, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? Color(hex: "#fc3c44") : Color.white.opacity(textOpacity))
                                .frame(height: iconsOnly ? 28 : 22)

                            if !iconsOnly {
                                Text(tab.title)
                                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                                    .foregroundColor(isSelected ? Color(hex: "#fc3c44") : Color.white.opacity(textOpacity))
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(1)
                            }
                        }
                        .scaleEffect(dynamicScale)
                        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: dynamicScale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                }
            }
            // Direct hover & drag tracking with 0ms touch latency
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($liveDragX) { value, state, _ in
                        state = value.location.x
                        let hoverIndex = max(0, min(tabs.count - 1, Int(value.location.x / tabWidth)))
                        if hoverIndex != lastHapticIndex {
                            DispatchQueue.main.async {
                                lastHapticIndex = hoverIndex
                            }
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    }
                    .onEnded { value in
                        lastHapticIndex = nil
                        let predictedX = value.predictedEndLocation.x
                        let finalIndex = max(0, min(tabs.count - 1, Int(predictedX / tabWidth)))
                        let targetTab = tabs[finalIndex]

                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()

                        onTabSelected(targetTab)
                    }
            )
            // Long Press to open settings (Gedrückt halten -> Settings)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onOpenSettings()
                    }
            )
        }
        .frame(height: 62)
    }
}

// MARK: - Apart Search Circular Platter (Right 62pt Circle, 12pt Gap)
private struct SearchApartCircle: View {
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Base 62pt Glass Circle
                Circle()
                    .fill(.ultraThinMaterial)
                AppleLiquidGlassView(style: .systemChromeMaterialDark, tintAlpha: 0.40)
                    .clipShape(Circle())
                Circle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.14), location: 0.0),
                                .init(color: Color.white.opacity(0.04), location: 0.45),
                                .init(color: Color.black.opacity(0.06), location: 1.0)
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
                                        .init(color: Color.white.opacity(0.65), location: 0.0),
                                        .init(color: Color.white.opacity(0.24), location: 0.35),
                                        .init(color: Color.white.opacity(0.08), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.85
                            )
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 16, x: 0, y: 8)
                    .shadow(color: Color.black.opacity(0.20), radius: 4, x: 0, y: 2)

                // Active Glass Ring Highlight
                if isSelected {
                    Circle()
                        .fill(Color.white.opacity(0.20))
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
                        .frame(width: 48, height: 48)
                        .shadow(color: Color.black.opacity(0.25), radius: 6, y: 2)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Color(hex: "#fc3c44") : Color.white.opacity(0.45))
            }
            .frame(width: 62, height: 62)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Navbar Settings Sheet (Exakt wie NavbarSettings.m)
private struct NavbarSettingsSheet: View {
    @Binding var iconsOnly: Bool
    @Binding var scrollMinimize: Bool
    @Environment(\.dismiss) private var dismiss

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
                    Text("Schrumpft die Kapsel beim Scrollen nach unten auf einen 62pt-Kreis und dockt die Minibar direkt in die Zeile ein.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.50))
                }

                Section(header: Text("Tab-Zusammenstellung").foregroundColor(.white.opacity(0.60))) {
                    HStack {
                        Text("Kapsel-Tabs:")
                        Spacer()
                        Text("Home, New, Radio, Library, Search")
                            .foregroundColor(Color.white.opacity(0.60))
                    }
                }
            }
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
        }
        .preferredColorScheme(.dark)
    }
}
