import SwiftUI

public struct ServerSetupView: View {
    public let onServerVerified: (String) -> Void

    @State private var serverInput: String = ""
    @State private var status: PingStatus = .idle
    @State private var isPinging: Bool = false
    @State private var isTransitioning: Bool = false
    @State private var checkmarkScale: CGFloat = 0.4

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
                .opacity(isTransitioning ? 0.0 : 1.0)
                .scaleEffect(isTransitioning ? 0.96 : 1.0)
                .offset(y: isTransitioning ? -16 : 0)
                .animation(.easeInOut(duration: 0.32), value: isTransitioning)
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
                .foregroundColor(.white)
                .tracking(1.4)

            HStack(spacing: 12) {
                Image(systemName: "server.rack")
                    .font(.system(size: 16))
                    .foregroundColor(.white)

                TextField(
                    "",
                    text: $serverInput,
                    prompt: Text("z. B. 192.168.1.100:3000")
                        .foregroundColor(Color.white.opacity(0.60))
                )
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
                            .foregroundColor(.white)
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
                .foregroundColor(Color.white.opacity(0.85))
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
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(PortColors.successGreen.opacity(0.22))
                        .frame(width: 32, height: 32)

                    Image(systemName: "checkmark")
                        .foregroundColor(PortColors.successGreen)
                        .font(.system(size: 15, weight: .bold))
                        .scaleEffect(checkmarkScale)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Server erreichbar (\(latencyMs) ms)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.85))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PortColors.successGreen.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(PortColors.successGreen.opacity(0.40), lineWidth: 1.2)
            )
            .transition(.scale(scale: 0.95).combined(with: .opacity))

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
                if case .success = status {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .scaleEffect(checkmarkScale)
                    Text("Server verbunden")
                        .font(.system(size: 16, weight: .semibold))
                } else if isPinging {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.9)

                    Text("Überprüfe...")
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    Text("Weiter")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(PortColors.buttonPrimaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canSubmit ? PortColors.buttonPrimaryBg : PortColors.buttonPrimaryBg.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: canSubmit ? Color.white.opacity(0.15) : Color.clear, radius: 10, y: 3)
        }
        .disabled(!canSubmit || isPinging || isTransitioning)
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

                    let feedback = UINotificationFeedbackGenerator()
                    feedback.notificationOccurred(.success)

                    withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                        checkmarkScale = 1.0
                    }

                    // Sichtbare Verweilzeit (850ms), gefolgt von einer weichen Übergangsanimation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                        withAnimation(.easeInOut(duration: 0.32)) {
                            isTransitioning = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                            onServerVerified(verifiedURL)
                        }
                    }
                }
            }
        }
    }
}
