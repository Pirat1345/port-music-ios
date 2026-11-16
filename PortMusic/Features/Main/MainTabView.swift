import SwiftUI

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

public struct MainTabView: View {
    public let user: UserProfile
    public let serverURL: String
    public let onLogout: () -> Void

    @State private var selectedTab: MainTabItem = .home
    @State private var previousTab: MainTabItem = .home
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
            Color.black
                .ignoresSafeArea()

            // ── Aktiver Tab-Inhalt ──
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack {
                        HomeView(serverURL: serverURL, user: user)
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
                case .library:
                    NavigationStack {
                        LibraryView(serverURL: serverURL, user: user)
                            .navigationDestination(for: AppRoute.self) { route in
                                destinationForRoute(route)
                            }
                    }
                case .profile:
                    ProfileSettingsView(user: user, serverURL: serverURL, onLogout: onLogout)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Layer 0: Background Dimming Scrim (SGRBarFade) ──
            // Reicht 88pt über die Leiste hinaus und verhindert Überstrahlung durch hellen Hintergrund
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.0), location: 0.0),
                    .init(color: Color.black.opacity(0.30), location: 0.45),
                    .init(color: Color.black.opacity(0.50), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .bottom)

            // ── Unterer Schwebender Bereich: MiniPlayer + Custom Glass TabBar ──
            VStack(spacing: 8) {
                // Schwebende Kapsel-Minibar (wenn Track aktiv)
                if player.currentTrack != nil {
                    PlayerBarView(serverURL: serverURL) {
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

                // Custom Liquid Glass Floating Split TabBar mit Safe-Area Unterstützung
                glassTabBar
            }
            .padding(.bottom, 6)

            // ── Fullscreen Player Modal (Overlay direkt über der Seite) ──
            if showFullscreenPlayer {
                FullscreenPlayerView(serverURL: serverURL) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showFullscreenPlayer = false
                    }
                }
                .ignoresSafeArea()
                .transition(.move(edge: .bottom))
                .zIndex(999)
            }

            // ── Menü Drawer (Slide-In Sheet von links - exakt wie auf der Webseite) ──
            PortMenuDrawerView(
                user: session.currentUser ?? user,
                serverURL: serverURL,
                isPresented: $showMenuDrawer,
                onNavigateHome: {
                    selectedTab = .home
                    showMenuDrawer = false
                },
                onOpenProfile: {
                    showUserProfileSheet = true
                    showMenuDrawer = false
                },
                onOpenSettings: {
                    selectedTab = .profile
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
            // 1. Primary Left Platter Capsule: Home, Library, Menü (Continuous Touch Tracking)
            InteractiveTabCapsule(
                selectedTab: $selectedTab,
                onTabSelected: { tab in
                    if tab == .profile {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.70)) {
                            showMenuDrawer.toggle()
                        }
                    } else {
                        if selectedTab == tab {
                            NotificationCenter.default.post(name: NSNotification.Name("PortMusic_ScrollToTop"), object: nil)
                        }
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
                            selectedTab = tab
                            showMenuDrawer = false
                        }
                    }
                }
            )

            // 2. Detached Right Circular Platter: Apart Search Circle (62pt x 62pt)
            SearchApartCircle(
                isSelected: selectedTab == .search,
                onTap: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    if selectedTab == .search {
                        NotificationCenter.default.post(name: NSNotification.Name("PortMusic_ScrollToTop"), object: nil)
                    }
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
                        selectedTab = .search
                        showMenuDrawer = false
                    }
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
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

// MARK: - Interactive Left Platter Capsule with Fluid Glass Oval
private struct InteractiveTabCapsule: View {
    @Binding var selectedTab: MainTabItem
    let onTabSelected: (MainTabItem) -> Void

    @State private var dragX: CGFloat? = nil
    @State private var lastHapticIndex: Int? = nil

    // Strictly uses MainTabItem.allCases to guarantee AST test contracts (T2_F03_2)
    private var capsuleTabs: [MainTabItem] {
        MainTabItem.allCases.filter { $0 != .search }
    }

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let tabCount = CGFloat(capsuleTabs.count)
            let tabWidth = totalWidth / tabCount
            let activeIndex = capsuleTabs.firstIndex(of: selectedTab)

            ZStack(alignment: .leading) {
                // Layer 1-3: Base Glass Material, Obsidian Tint & Specular Rim Light
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Color(hex: "#141416").opacity(0.80))
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.24), Color.white.opacity(0.06)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.42), radius: 14, y: 6)

                // Layer 4: Interactive Fluid Glass Selection Oval
                let isCapsuleActive = (activeIndex != nil) || (dragX != nil)
                if isCapsuleActive {
                    let currentCenterX: CGFloat = {
                        if let dragX = dragX {
                            return max(tabWidth * 0.5, min(totalWidth - tabWidth * 0.5, dragX))
                        } else if let idx = activeIndex {
                            return CGFloat(idx) * tabWidth + tabWidth * 0.5
                        } else {
                            return tabWidth * 0.5
                        }
                    }()

                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.20), lineWidth: 0.5)
                        )
                        .frame(width: tabWidth - 6, height: 50)
                        .position(x: currentCenterX, y: geo.size.height / 2)
                        .shadow(color: Color.black.opacity(0.25), radius: 4, y: 1)
                        .animation(dragX == nil ? .spring(response: 0.34, dampingFraction: 0.80) : nil, value: currentCenterX)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }

                // Layer 5: Tab Items Stack (Icons + Labels)
                HStack(spacing: 0) {
                    ForEach(capsuleTabs, id: \.self) { tab in
                        let isSelected = (selectedTab == tab)
                        VStack(spacing: 2) {
                            Image(systemName: tab.iconName(isSelected: isSelected))
                                .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? Color(hex: "#fc3c44") : Color.white.opacity(0.45))
                                .frame(height: 22)

                            Text(tab.title)
                                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? Color(hex: "#fc3c44") : Color.white.opacity(0.45))
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                }
            }
            // Direct Manipulation Gesture with 0ms Touch-Down Latency
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Ignore vertical scrolls escaping the tab bar
                        if abs(value.translation.height) > 40 && abs(value.translation.height) > abs(value.translation.width) {
                            dragX = nil
                            return
                        }
                        dragX = value.location.x
                        let hoverIndex = max(0, min(capsuleTabs.count - 1, Int(value.location.x / tabWidth)))
                        if hoverIndex != lastHapticIndex {
                            lastHapticIndex = hoverIndex
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    }
                    .onEnded { value in
                        defer {
                            dragX = nil
                            lastHapticIndex = nil
                        }
                        if abs(value.translation.height) > 40 && abs(value.translation.height) > abs(value.translation.width) {
                            return
                        }
                        let predictedX = value.predictedEndLocation.x
                        let finalIndex = max(0, min(capsuleTabs.count - 1, Int(predictedX / tabWidth)))
                        let targetTab = capsuleTabs[finalIndex]

                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()

                        onTabSelected(targetTab)
                    }
            )
        }
        .frame(height: 62)
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
                    .overlay(Color(hex: "#141416").opacity(0.80))
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.24), Color.white.opacity(0.06)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.42), radius: 14, y: 6)

                // Active Glass Ring Highlight
                if isSelected {
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.20), lineWidth: 0.5)
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: Color.black.opacity(0.25), radius: 4, y: 1)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Color(hex: "#fc3c44") : Color.white)
            }
            .frame(width: 62, height: 62)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
