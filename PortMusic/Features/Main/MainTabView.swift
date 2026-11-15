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
        case .library: return "Bibliothek"
        case .profile: return "Profil"
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
    @State private var showFullscreenPlayer: Bool = false
    @ObservedObject private var player = AudioPlayerManager.shared

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
                    NavigationStack {
                        SearchView(serverURL: serverURL)
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
                        showFullscreenPlayer = true
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Custom Octave Glass TabBar mit Glow & Safe-Area Unterstützung
                glassTabBar
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showFullscreenPlayer) {
            FullscreenPlayerView(serverURL: serverURL) {
                showFullscreenPlayer = false
            }
        }
    }

    // MARK: - Custom Octave Glass TabBar
    private var glassTabBar: some View {
        HStack(spacing: 0) {
            ForEach(MainTabItem.allCases, id: \.self) { tab in
                let isSelected = (selectedTab == tab)

                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            // Subtiler Active Glow hinter dem aktiven Icon
                            if isSelected {
                                Circle()
                                    .fill(Color.white.opacity(0.14))
                                    .frame(width: 38, height: 38)
                                    .blur(radius: 4)
                            }

                            Image(systemName: tab.icon)
                                .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : Color.white.opacity(0.45))
                                .shadow(color: isSelected ? Color.white.opacity(0.35) : Color.clear, radius: 4)
                        }
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
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            Color.black.opacity(0.85)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            Rectangle()
                .fill(PortColors.borderGlass)
                .frame(height: 0.8),
            alignment: .top
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
