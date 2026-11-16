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
        case .profile: return "person.crop.circle.fill"
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

            // ── Unterer Schwebender Bereich: MiniPlayer + Custom Octave Glass TabBar ──
            VStack(spacing: 0) {
                // Schwebende Minibar-Leiste (wenn Track aktiv)
                if player.currentTrack != nil {
                    PlayerBarView(serverURL: serverURL) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showFullscreenPlayer = true
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Custom Octave Glass TabBar mit Safe-Area Unterstützung
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
            if showMenuDrawer {
                PortMenuDrawerView(
                    user: session.currentUser ?? user,
                    serverURL: serverURL,
                    isPresented: $showMenuDrawer,
                    onNavigateHome: {
                        selectedTab = .home
                    },
                    onOpenProfile: {
                        selectedTab = .profile
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
        }
        .overlay(alignment: .leading) {
            if !showMenuDrawer && !showFullscreenPlayer {
                Color.clear
                    .frame(width: 28)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 15, coordinateSpace: .local)
                            .onEnded { value in
                                if value.startLocation.x <= 28 && (value.translation.width > 45 || value.predictedEndTranslation.width > 80) {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        showMenuDrawer = true
                                    }
                                }
                            }
                    )
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await player.syncLastPlayedFromServerIfNeeded(serverURL: serverURL, token: SessionManager.shared.currentToken)
            await SessionManager.shared.refreshUserProfile()
        }
        .fullScreenCover(isPresented: .constant(false)) { EmptyView() }
    }

    // MARK: - Custom Octave TabBar (Clean Minimalist Dark - No Glow, No Separator Line)
    private var glassTabBar: some View {
        HStack(spacing: 0) {
            ForEach(MainTabItem.allCases, id: \.self) { tab in
                let isSelected = (selectedTab == tab)

                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    if tab == .profile {
                        // Menü öffnet/schließt ausschließlich die Seitenleiste (Drawer), ohne die aktuelle Hauptseite umzuschalten
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showMenuDrawer.toggle()
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = tab
                            showMenuDrawer = false
                        }
                    }
                }) {
                    VStack(spacing: 4) {
                        tabIconView(tab: tab, isSelected: isSelected)
                            .frame(height: 26)

                        Text(tab.title)
                            .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                            .foregroundColor(isSelected ? .white : Color.white.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(
            Color.black
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private func tabIconView(tab: MainTabItem, isSelected: Bool) -> some View {
        if tab == .profile {
            let curUser = session.currentUser ?? user
            PortUserAvatarView(
                rawAvatar: curUser.avatar,
                username: curUser.username,
                serverURL: serverURL,
                size: 26,
                isSelected: isSelected
            )
        } else {
            Image(systemName: tab.icon)
                .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : Color.white.opacity(0.45))
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
