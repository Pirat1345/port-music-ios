import SwiftUI

public struct ServerSetupView: View {
    public let onServerVerified: (String) -> Void

    @State private var serverInput: String = ""
    @State private var status: PingStatus = .idle
    @State private var isPinging: Bool = false

    private let storageKey = "portmusic_server_url"

    public init(onServerVerified: @escaping (String) -> Void) {
        self.onServerVerified = onServerVerified
    }

    public var body: some View {
        ZStack {
            // Fluent Animated Seiden-Hintergrund
            FluentBackgroundView()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 36)

                    // Kopfbereich mit offiziellem Logo & Manosque-Schriftzug
                    headerSection

                    // Eingabefeld für die Server-Adresse
                    inputCardSection

                    // Statusmeldung bei Überprüfung oder Fehler
                    statusSection

                    // Monochrom weißer Aktions-Button
                    actionButtonSection

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadSavedServer()
        }
    }

    // MARK: - Kopfbereich
    private var headerSection: some View {
        VStack(spacing: 14) {
            PortLogoView(size: 72)

            VStack(spacing: 8) {
                Text("Port Music")
                    .font(.manosque(size: 48))
                    .tracking(0.5)
                    .foregroundColor(PortColors.textPrimary)
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 2)

                Text("Gib die IP-Adresse deines Servers ein, um fortzufahren.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(PortColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Eingabekarte
    private var inputCardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SERVER-ADRESSE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(PortColors.textMuted)
                .tracking(1.4)

            HStack(spacing: 12) {
                Image(systemName: "server.rack")
                    .font(.system(size: 16))
                    .foregroundColor(PortColors.textSecondary)

                TextField("z. B. 192.168.1.100:3000", text: $serverInput)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(PortColors.textPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .onSubmit {
                        performPing()
                    }

                if !serverInput.isEmpty {
                    Button(action: { serverInput = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(PortColors.textMuted)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(PortColors.surfaceGlass)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColorForStatus, lineWidth: 1.2)
            )

            Text("Unterstützt IP-Adressen (z. B. 192.168.1.50:3000) oder Domainnamen.")
                .font(.system(size: 11))
                .foregroundColor(PortColors.textMuted)
                .padding(.horizontal, 4)
        }
        .padding(20)
        .glassCard(cornerRadius: 22)
    }

    private var borderColorForStatus: Color {
        switch status {
        case .failure:
            return PortColors.errorRed.opacity(0.8)
        case .success:
            return PortColors.successGreen.opacity(0.8)
        default:
            return PortColors.borderGlass
        }
    }

    // MARK: - Statusanzeige
    @ViewBuilder
    private var statusSection: some View {
        switch status {
        case .idle:
            EmptyView()

        case .pinging:
            HStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.85)

                Text("Server wird überprüft...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(PortColors.textSecondary)
            }
            .padding(.vertical, 4)

        case .success(_, let latencyMs, let detail):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(PortColors.successGreen)
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Server erreichbar (\(latencyMs) ms)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(PortColors.textPrimary)

                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(PortColors.textSecondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PortColors.successGreen.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(PortColors.successGreen.opacity(0.35), lineWidth: 1)
            )

        case .failure(let reason):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(PortColors.errorRed)
                    .font(.system(size: 16))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Verbindung fehlgeschlagen")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(PortColors.textPrimary)

                    Text(reason)
                        .font(.system(size: 12))
                        .foregroundColor(PortColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PortColors.errorRed.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(PortColors.errorRed.opacity(0.35), lineWidth: 1)
            )
        }
    }

    // MARK: - Weiter-Button (Monochrom Weiß)
    private var actionButtonSection: some View {
        Button(action: performPing) {
            HStack(spacing: 10) {
                if isPinging {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.9)
                }

                Text(isPinging ? "Überprüfe..." : "Weiter")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(PortColors.buttonPrimaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canSubmit ? PortColors.buttonPrimaryBg : PortColors.buttonPrimaryBg.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: canSubmit ? Color.white.opacity(0.15) : Color.clear, radius: 10, y: 3)
        }
        .disabled(!canSubmit || isPinging)
    }

    private var canSubmit: Bool {
        !serverInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Logik
    private func loadSavedServer() {
        if let stored = UserDefaults.standard.string(forKey: storageKey), !stored.isEmpty {
            serverInput = stored
        }
    }

    private func performPing() {
        let trimmed = serverInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isPinging = true
        status = .pinging

        Task {
            let res = await ServerPingService.shared.ping(rawInput: trimmed)
            await MainActor.run {
                isPinging = false
                status = res

                if case .success(let verifiedURL, _, _) = res {
                    UserDefaults.standard.set(verifiedURL, forKey: storageKey)
                    // Sanfter Übergang zur Anmeldeseite
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onServerVerified(verifiedURL)
                    }
                }
            }
        }
    }
}
