import SwiftUI

public enum MainTabItem: Int, CaseIterable {
    case home = 0
    case search = 1
    case library = 2
    case profile = 3

    var title: String {
        switch self {
        case .home: return "Startseite"
        case .search: return "Suche"
        case .library: return "Bibliothek"
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

            // ── Unterer Schwebender Bereich: MiniPlayer + Custom Glass TabBar ──
            VStack(spacing: 6) {
                // Schwebende Kapsel-Minibar (wenn Track aktiv)
                if player.currentTrack != nil {
                    PlayerBarView(serverURL: serverURL) {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.70)) {
                            showFullscreenPlayer = true
                        }
                    }
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.94).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                            removal: .scale(scale: 0.94).combined(with: .opacity).combined(with: .move(edge: .bottom))
                        )
                    )
                }

                // Custom Glass TabBar mit Safe-Area Unterstützung
                glassTabBar
            }

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

    // MARK: - Native Frosted Glass TabBar
    private var glassTabBar: some View {
        HStack(spacing: 0) {
            ForEach(MainTabItem.allCases, id: \.self) { tab in
                let isSelected = (selectedTab == tab)

                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    if tab == .profile {
                        // Menü öffnet/schließt ausschließlich die Seitenleiste (Drawer), ohne die aktuelle Hauptseite umzuschalten
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.70)) {
                            showMenuDrawer.toggle()
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = tab
                            showMenuDrawer = false
                        }
                    }
                }) {
                    VStack(spacing: 3) {
                        Image(systemName: tab.iconName(isSelected: isSelected))
                            .font(.system(size: 21, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? Color.white : Color.white.opacity(0.45))
                            .frame(height: 24)

                        Text(tab.title)
                            .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                            .foregroundColor(isSelected ? Color.white : Color.white.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(
            ZStack(alignment: .top) {
                // Frosted Glass Blur mit transluzenter Abdunklung
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Color(hex: "#121214").opacity(0.80)
                    )

                // 0.5pt Hairline-Border an der Oberkante
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 0.5)
            }
            .ignoresSafeArea(edges: .bottom)
        )
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
