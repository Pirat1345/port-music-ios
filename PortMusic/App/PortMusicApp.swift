import SwiftUI

@main
struct PortMusicApp: App {
    @StateObject private var sessionManager = SessionManager.shared

    public init() {
        UITextField.appearance().tintColor = .white
        UITextView.appearance().tintColor = .white
        UIView.appearance().tintColor = .white
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if sessionManager.isRestoringSession {
                    splashLoadingView
                        .transition(.opacity)
                } else if sessionManager.isAuthenticated,
                          let user = sessionManager.currentUser,
                          let serverURL = sessionManager.serverURL {
                    LoggedInView(
                        user: user,
                        serverURL: serverURL,
                        onLogout: {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                sessionManager.logout()
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity
                    ))
                } else if let serverURL = sessionManager.serverURL, !serverURL.isEmpty {
                    LoginView(
                        serverURL: serverURL,
                        onLoginSuccess: { _ in
                            // Der SessionManager schaltet isAuthenticated auf true,
                            // wodurch automatisch auf LoggedInView umgeschaltet wird.
                        },
                        onChangeServer: {
                            withAnimation(.spring(response: 0.50, dampingFraction: 0.85)) {
                                sessionManager.updateServerURL("")
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
                } else {
                    ServerSetupView(onServerVerified: { url in
                        withAnimation(.spring(response: 0.50, dampingFraction: 0.85)) {
                            sessionManager.updateServerURL(url)
                        }
                    })
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
                }
            }
            .preferredColorScheme(.dark)
            .tint(.white)
            .task {
                await sessionManager.restoreSession()
            }
        }
    }

    private var splashLoadingView: some View {
        ZStack {
            FluentBackgroundView()

            VStack(spacing: 20) {
                PortLogoView(size: 76)

                Text("Port Music")
                    .font(.manosque(size: 48))
                    .foregroundColor(PortColors.textPrimary)
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 2)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.1)
                    .padding(.top, 12)
            }
        }
    }
}
