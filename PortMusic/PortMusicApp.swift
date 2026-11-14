import SwiftUI

@main
struct PortMusicApp: App {
    var body: some Scene {
        WindowGroup {
            ServerSetupView()
                .preferredColorScheme(.dark)
        }
    }
}
