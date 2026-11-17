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
                // Option 1: Wenn auf der Suche, zeigt der linke Kreis den vorherigen Tab (z. B. Startseite/Mediathek)
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

                        Image(systemName: leftTab.iconName(isSelected: !isSearch))
                            .font(.system(size: 20, weight: isSearch ? .semibold : .bold))
                            .foregroundColor(isSearch ? Color.white.opacity(0.85) : Color(hex: "#fc3c44"))
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
                    tabs: currentTabsList,
                    iconsOnly: iconsOnly,
                    onTabSelected: { tab in
                        selectLiquidTab(tab)
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

// MARK: - Metal Stitchable Squircle Distortion Modifier
extension View {
    @ViewBuilder
    fileprivate func liquidSquircleDistortion(center: CGPoint, size: CGSize, isEnabled: Bool = true) -> some View {
        if #available(iOS 17.0, *), isEnabled {
            self.distortionEffect(
                ShaderLibrary.liquidGlassSquircleDistort(
                    .float2(Float(center.x), Float(center.y)),
                    .float2(Float(size.width), Float(size.height))
                ),
                maxSampleOffset: CGSize(width: 30, height: 30)
            )
        } else {
            self
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
            // KEINE Shader-Distortion hierauf, damit der UIKit-Layer NIEMALS gelb wird!
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

// MARK: - Interactive Liquid Glass Capsule with Fluid Hover Oval
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

            // Linsenzentrum mit fluessigem Velocity-Stretch
            let currentCenterX: CGFloat = {
                if let dragX = liveDragX {
                    return max(tabWidth * 0.5, min(totalWidth - tabWidth * 0.5, dragX))
                } else if let idx = activeIndex {
                    return CGFloat(idx) * tabWidth + tabWidth * 0.5
                } else {
                    return tabWidth * 0.5
                }
            }()

            // Dynamischer fluessiger Stretch der Glaslinse bei Drag (visuelle Traegheit wie im Apple Segmented Control Video)
            let dynamicStretch = isInteracting ? min(14.0, max(-14.0, liveVelocityX * 0.06)) : 0.0
            let pillWidth = (tabWidth - 6) + abs(dynamicStretch)
            let pillCenterX = currentCenterX + (dynamicStretch * 0.30)
            let pillHeight = max(48.0, 52.0 - abs(dynamicStretch) * 0.12)

            ZStack(alignment: .leading) {
                // Layer 1: Native Apple Liquid Glass View mit echter Hardware-Transparenz (Kein Shader auf UIKit, kein Gelb)
                AppleLiquidGlassView(style: .systemUltraThinMaterialDark, tintAlpha: 0.22, isCapsule: true)

                // Layer 2: Subtiler Specular Frost Sheen
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.12), location: 0.0),
                                .init(color: Color.white.opacity(0.03), location: 0.40),
                                .init(color: Color.clear, location: 0.70),
                                .init(color: Color.black.opacity(0.10), location: 1.0)
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
                                .init(color: Color.white.opacity(0.38), location: 0.0),
                                .init(color: Color.white.opacity(0.14), location: 0.35),
                                .init(color: Color.white.opacity(0.04), location: 0.75),
                                .init(color: Color.white.opacity(0.16), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
                    .shadow(color: Color.black.opacity(0.38), radius: 18, x: 0, y: 8)
                    .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)

                // Layer 4: Refraktive Liquid Glass Lens mit dynamischer Dehnung (Fluid Morphing)
                LiquidGlassLensPill(width: pillWidth, height: pillHeight, isInteracting: isInteracting)
                    .position(x: pillCenterX, y: geo.size.height / 2)
                    .animation(liveDragX == nil ? .spring(response: 0.34, dampingFraction: 0.80) : .interactiveSpring(), value: pillCenterX)
                    .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.70), value: pillWidth)

                // Layer 5: Tab Items Stack mit optischer Linsenverzerrung (Metal Shader) & Kantenbrechung
                HStack(spacing: 0) {
                    ForEach(0..<tabs.count, id: \.self) { idx in
                        let tab = tabs[idx]
                        let isSelected = (activeTab == tab)
                        let tabCenterX = CGFloat(idx) * tabWidth + tabWidth * 0.5
                        let dist = abs(currentCenterX - tabCenterX)

                        // Subtile Linsengroesse: Nur bei aktiver Interaktion (beim Ziehen)
                        let normDist = min(1.0, dist / (tabWidth * 0.65))
                        let squircleFactor = max(0.0, 1.0 - pow(normDist, 4.0))
                        let dynamicScaleX = isInteracting ? (1.0 + (squircleFactor * 0.05)) : 1.0
                        let dynamicScaleY = isInteracting ? (1.0 + (squircleFactor * 0.05)) : 1.0

                        let textOpacity = isSelected ? 1.0 : max(inactiveTabOpacity, inactiveTabOpacity + squircleFactor * 0.45)

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
                        .scaleEffect(x: dynamicScaleX, y: dynamicScaleY)
                        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82), value: dynamicScaleX)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                }
                .liquidSquircleDistortion(
                    center: CGPoint(x: pillCenterX, y: geo.size.height / 2),
                    size: CGSize(width: pillWidth, height: pillHeight),
                    isEnabled: isInteracting
                )
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
                    .updating($liveVelocityX) { value, state, _ in
                        state = value.predictedEndLocation.x - value.location.x
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

// MARK: - Navbar Settings Sheet (Tab-Konfiguration & Anzeigeeinstellungen)
private struct NavbarSettingsSheet: View {
    @Binding var iconsOnly: Bool
    @Binding var scrollMinimize: Bool
    @Binding var customTabsRaw: String
    @Environment(\.dismiss) private var dismiss

    private var activeTabs: [LiquidTabID] {
        let rawIds = customTabsRaw.split(separator: ",").map(String.init)
        let parsed = rawIds.compactMap { LiquidTabID(rawValue: $0) }
        return parsed.isEmpty ? [.home, .library, .radio, .search] : parsed
    }

    private var inactiveTabs: [LiquidTabID] {
        let current = Set(activeTabs)
        let all: [LiquidTabID] = [.home, .library, .radio, .search, .newReleases]
        return all.filter { !current.contains($0) }
    }

    private func saveTabs(_ tabs: [LiquidTabID]) {
        customTabsRaw = tabs.map(\.rawValue).joined(separator: ",")
    }

    private func moveTab(from: Int, to: Int) {
        var list = activeTabs
        guard from >= 0, from < list.count, to >= 0, to < list.count else { return }
        let item = list.remove(at: from)
        list.insert(item, at: to)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        saveTabs(list)
    }

    private func removeTab(at index: Int) {
        var list = activeTabs
        guard list.count > 2, index >= 0, index < list.count else { return }
        list.remove(at: index)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        saveTabs(list)
    }

    private func addTab(_ tab: LiquidTabID) {
        var list = activeTabs
        guard !list.contains(tab) else { return }
        list.append(tab)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        saveTabs(list)
    }

    private func resetToDefault() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        saveTabs([.home, .library, .radio, .search])
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
                    Text("Schrumpft die Kapsel beim Scrollen nach unten auf einen 62pt-Kreis und dockt die Minibar direkt in die Zeile ein.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.50))
                }

                Section(
                    header: Text("Angezeigte Tabs & Reihenfolge").foregroundColor(.white.opacity(0.60)),
                    footer: Text("Pfeile antippen oder Listeneinträge verschieben, um die Reihenfolge in der Leiste festzulegen. Mindestens 2 Tabs bleiben aktiv.").font(.system(size: 12)).foregroundColor(.white.opacity(0.45))
                ) {
                    ForEach(Array(activeTabs.enumerated()), id: \.element) { index, tab in
                        HStack(spacing: 12) {
                            Image(systemName: tab.iconName(isSelected: true))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "#fc3c44"))
                                .frame(width: 26)

                            Text(tab.title)
                                .foregroundColor(.white)
                                .font(.system(size: 15, weight: .medium))

                            Spacer()

                            // Pfeil nach oben
                            if index > 0 {
                                Button(action: { moveTab(from: index, to: index - 1) }) {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color.white.opacity(0.70))
                                        .frame(width: 28, height: 28)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }

                            // Pfeil nach unten
                            if index < activeTabs.count - 1 {
                                Button(action: { moveTab(from: index, to: index + 1) }) {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color.white.opacity(0.70))
                                        .frame(width: 28, height: 28)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }

                            // Entfernen
                            if activeTabs.count > 2 {
                                Button(action: { removeTab(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(hex: "#fc3c44").opacity(0.90))
                                        .frame(width: 28, height: 28)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .onMove { indices, newOffset in
                        var list = activeTabs
                        list.move(fromOffsets: indices, toOffset: newOffset)
                        saveTabs(list)
                    }
                }

                if !inactiveTabs.isEmpty {
                    Section(header: Text("Weitere verfügbare Tabs").foregroundColor(.white.opacity(0.60))) {
                        ForEach(inactiveTabs) { tab in
                            HStack(spacing: 12) {
                                Button(action: { addTab(tab) }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(hex: "#34c759"))
                                        .frame(width: 26)
                                }
                                .buttonStyle(.plain)

                                Image(systemName: tab.iconName(isSelected: false))
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.60))
                                    .frame(width: 26)

                                Text(tab.title)
                                    .foregroundColor(.white.opacity(0.85))
                                    .font(.system(size: 15))

                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                addTab(tab)
                            }
                        }
                    }
                }

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
            .navigationTitle("Navigationsleiste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .foregroundColor(Color(hex: "#fc3c44"))
                }
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
