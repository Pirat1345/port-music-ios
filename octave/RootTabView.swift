//
//  RootTabView.swift
//  octave
//

import SwiftUI

enum OctaveTab: Hashable {
    case home
    case browse
    case radio
    case library
    case search
}

struct RootTabView: View {
    @Environment(ThemeEngine.self) private var theme
    @Environment(AudioPlayer.self) private var player
    @Environment(AccountStore.self) private var account

    @State private var tab: OctaveTab = .home
    @State private var searchQuery: String = ""
    @State private var showSplash: Bool = false
    @State private var showPermissionsIntro: Bool = false
    @State private var showTasteOnboarding: Bool = false
    @State private var isNowPlayingPresented: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tab) {
                NavigationStack {
                    HomeView()
                }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(OctaveTab.home)

                NavigationStack {
                    BrowseView()
                }
                .tabItem {
                    Label("Browse", systemImage: "square.grid.2x2.fill")
                }
                .tag(OctaveTab.browse)

                NavigationStack {
                    RadioView()
                }
                .tabItem {
                    Label("Radio", systemImage: "dot.radiowaves.left.and.right")
                }
                .tag(OctaveTab.radio)

                NavigationStack {
                    LibraryView()
                }
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .tag(OctaveTab.library)

                NavigationStack {
                    SearchView(query: $searchQuery)
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(OctaveTab.search)
            }
            .tint(Color.accentColor)

            // Floating Mini Player & Now Playing Host
            VStack(spacing: 0) {
                if player.currentIndex != nil {
                    NowPlayingHost(isPresented: $isNowPlayingPresented)
                        .padding(.bottom, 50)
                }
            }
        }
        .sheet(isPresented: $showTasteOnboarding) {
            TasteOnboardingView()
        }
    }
}
