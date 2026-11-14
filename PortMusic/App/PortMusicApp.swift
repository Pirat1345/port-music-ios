import SwiftUI

public enum AppScreen: Equatable {
    case serverSetup
    case login(serverURL: String)
    case loggedIn(user: UserProfile, serverURL: String)
}

@main
struct PortMusicApp: App {
    @State private var screen: AppScreen = .serverSetup

    var body: some Scene {
        WindowGroup {
            ZStack {
                switch screen {
                case .serverSetup:
                    ServerSetupView(onServerVerified: { url in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            screen = .login(serverURL: url)
                        }
                    })
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity
                    ))

                case .login(let serverURL):
                    LoginView(
                        serverURL: serverURL,
                        onLoginSuccess: { user in
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                screen = .loggedIn(user: user, serverURL: serverURL)
                            }
                        },
                        onChangeServer: {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                screen = .serverSetup
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity
                    ))

                case .loggedIn(let user, let serverURL):
                    LoggedInView(
                        user: user,
                        serverURL: serverURL,
                        onLogout: {
                            AuthService.shared.clearSession()
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                screen = .login(serverURL: serverURL)
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity
                    ))
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
