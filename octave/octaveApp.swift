//
//  octaveApp.swift
//  octave
//

import SwiftUI
import SwiftData

@main
struct PortMusicApp: App {
    @State private var theme = ThemeEngine.shared
    @State private var player = AudioPlayer.shared
    @State private var account = AccountStore.shared
    @State private var libraryIndex = LibraryIndex.shared

    var body: some Scene {
        WindowGroup {
            GateView {
                RootTabView()
            }
            .environment(theme)
            .environment(player)
            .environment(account)
            .environment(libraryIndex)
            .preferredColorScheme(.dark)
        }
    }
}
