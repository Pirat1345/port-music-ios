import SwiftUI

struct LoggedInView: View {
    let user: UserProfile
    let serverURL: String
    let onLogout: () -> Void

    var body: some View {
        ZStack {
            PortColors.background
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Profile Avatar / Initials
                ZStack {
                    Circle()
                        .fill(PortColors.surfaceElevated)
                        .frame(width: 88, height: 88)
                        .overlay(
                            Circle()
                                .stroke(PortColors.border, lineWidth: 1.5)
                        )

                    Text(initials)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.5), radius: 10, y: 4)

                // Welcome texts
                VStack(spacing: 6) {
                    Text("Willkommen zurueck,")
                        .font(.system(size: 15))
                        .foregroundColor(PortColors.textSecondary)

                    Text(user.displayName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(PortColors.textPrimary)

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 13))

                        Text("Angemeldet als \(user.role)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(PortColors.textSecondary)
                    }
                    .padding(.top, 4)
                }

                // Connected Server Card
                VStack(spacing: 6) {
                    Text("VERBUNDENER SERVER")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(PortColors.textMuted)
                        .tracking(1.2)

                    Text(serverURL)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(PortColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(PortColors.border, lineWidth: 1)
                        )
                }
                .padding(.top, 8)

                Spacer()

                // Logout Button
                Button(action: onLogout) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 15))
                        Text("Abmelden")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PortColors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(PortColors.border, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var initials: String {
        let name = user.displayName.isEmpty ? user.username : user.displayName
        let parts = name.split(separator: " ")
        if let first = parts.first?.first {
            if parts.count > 1, let second = parts[1].first {
                return "\(first)\(second)".uppercased()
            }
            return String(first).uppercased()
        }
        return "P"
    }
}
