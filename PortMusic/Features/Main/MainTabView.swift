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
        case .library: return "Mediathek"
        case .profile: return "Profil"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .library: return "books.vertical.fill"
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
            // Aktiver Tab-Inhalt
            Group {
                switch selectedTab {
                case .home:
                    HomeView(serverURL: serverURL, user: user)
                case .search:
                    SearchView(serverURL: serverURL)
                case .library:
                    LibraryView(serverURL: serverURL, user: user)
                case .profile:
                    LoggedInView(user: user, serverURL: serverURL, onLogout: onLogout)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Unterer Schwebender Bereich: MiniPlayer + Custom Glass TabBar
            VStack(spacing: 0) {
                // Schwebende MiniPlayer-Leiste (sofern Track aktiv)
                if player.currentTrack != nil {
                    MiniPlayerBar(serverURL: serverURL) {
                        showFullscreenPlayer = true
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Custom Glass TabBar
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

    // MARK: - Custom Glass TabBar
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
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : Color.white.opacity(0.45))
                            .frame(height: 24)

                        Text(tab.title)
                            .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? .white : Color.white.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            Color.black.opacity(0.75)
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
}
