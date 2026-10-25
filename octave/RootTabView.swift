//
//  RootTabView.swift
//  Port Music
//

import SwiftUI

enum AppTab: Hashable {
    case home
    case browse
    case radio
    case library
    case search
}

typealias OctaveTab = AppTab

struct RootTabView: View {
    @Environment(ThemeEngine.self) private var theme
    @Environment(AudioPlayer.self) private var player
    @Environment(AccountStore.self) private var account

    @State private var tab: AppTab = .home
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
                .tag(AppTab.home)

                NavigationStack {
                    BrowseView()
                }
                .tabItem {
                    Label("Entdecken", systemImage: "sparkles")
                }
                .tag(AppTab.browse)

                NavigationStack {
                    RadioView()
                }
                .tabItem {
                    Label("Radio", systemImage: "dot.radiowaves.left.and.right")
                }
                .tag(AppTab.radio)

                NavigationStack {
                    LibraryView()
                }
                .tabItem {
                    Label("Bibliothek", systemImage: "music.note.list")
                }
                .tag(AppTab.library)

                NavigationStack {
                    SearchView(query: $searchQuery)
                }
                .tabItem {
                    Label("Suche", systemImage: "magnifyingglass")
                }
                .tag(AppTab.search)
            }
            .tint(Color.portBrand)

            // Floating Mini Player & Now Playing Host
            VStack(spacing: 0) {
                if player.currentIndex != nil {
                    NowPlayingHost(isPresented: $isNowPlayingPresented)
                        .padding(.bottom, 54)
                }
            }
        }
        .sheet(isPresented: $showTasteOnboarding) {
            TasteOnboardingView()
        }
    }
}
