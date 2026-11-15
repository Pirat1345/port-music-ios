import SwiftUI

public struct LoggedInView: View {
    public let user: UserProfile
    public let serverURL: String
    public let onLogout: () -> Void

    public init(user: UserProfile, serverURL: String, onLogout: @escaping () -> Void) {
        self.user = user
        self.serverURL = serverURL
        self.onLogout = onLogout
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 30)

                    // Logo & Marken-Headline
                    VStack(spacing: 12) {
                        PortLogoView(size: 68)

                        Text("Port Music")
                            .font(.manosque(size: 46))
                            .foregroundColor(PortColors.textPrimary)
                            .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
                    }

                    // Benutzerprofil-Karte
                    VStack(spacing: 20) {
                        // Avatar / Profil-Symbol
                        ZStack {
                            Circle()
                                .fill(PortColors.surfaceGlassStrong)
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Circle()
                                        .stroke(PortColors.borderGlass, lineWidth: 1.5)
                                )

                            Text(String(user.username.prefix(1)).uppercased())
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(PortColors.textPrimary)
                        }

                        VStack(spacing: 6) {
                            Text(user.username)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(PortColors.textPrimary)

                            if let email = user.email, !email.isEmpty {
                                Text(email)
                                    .font(.system(size: 13))
                                    .foregroundColor(PortColors.textSecondary)
                            }

                            if let role = user.role, !role.isEmpty {
                                Text(role.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.4)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    )
                                    .padding(.top, 4)
                            }
                        }

                        Divider()
                            .background(PortColors.borderGlass)

                        // Server-Details
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("VERBUNDENER SERVER")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(1.2)
                                    .foregroundColor(.white)

                                Text(serverURL)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            Spacer()

                            Circle()
                                .fill(PortColors.successGreen)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(24)
                    .glassCard(cornerRadius: 24)

                    // Abmelden-Button (Monochrom Weiß)
                    Button(action: onLogout) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 15))
                            Text("Abmelden")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(PortColors.buttonPrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(PortColors.buttonPrimaryBg)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.white.opacity(0.12), radius: 8, y: 2)
                    }

                    Spacer()
                }
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }
}
