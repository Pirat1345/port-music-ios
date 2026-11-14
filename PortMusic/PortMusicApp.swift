import SwiftUI

enum AppScreen {
    case serverSetup
    case login(serverURL: String)
    case loggedIn(user: UserProfile, serverURL: String)
}

@main
struct PortMusicApp: App {
    @State private var screen: AppScreen = .serverSetup

    var body: some Scene {
        WindowGroup {
            Group {
                switch screen {
                case .serverSetup:
                    ServerSetupView(onServerVerified: { url in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            screen = .login(serverURL: url)
                        }
                    })

                case .login(let serverURL):
                    LoginView(
                        serverURL: serverURL,
                        onLoginSuccess: { user in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                screen = .loggedIn(user: user, serverURL: serverURL)
                            }
                        },
                        onChangeServer: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                screen = .serverSetup
                            }
                        }
                    )

                case .loggedIn(let user, let serverURL):
                    LoggedInView(
                        user: user,
                        serverURL: serverURL,
                        onLogout: {
                            AuthService.shared.clearSession()
                            withAnimation(.easeInOut(duration: 0.25)) {
                                screen = .login(serverURL: serverURL)
                            }
                        }
                    )
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                checkInitialState()
            }
        }
    }

    private func checkInitialState() {
        if let storedURL = UserDefaults.standard.string(forKey: "portmusic_server_url"), !storedURL.isEmpty {
            if let user = AuthService.shared.currentUser {
                self.screen = .loggedIn(user: user, serverURL: storedURL)
            } else {
                self.screen = .login(serverURL: storedURL)
            }
        }
    }
}
