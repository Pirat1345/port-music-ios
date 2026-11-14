import SwiftUI

struct ServerSetupView: View {
    @State private var serverInput: String = ""
    @State private var status: PingStatus = .idle
    @State private var hasSavedServer: Bool = false
    @State private var savedServerURL: String = ""

    private let storageKey = "portmusic_server_url"

    var body: some View {
        ZStack {
            PortColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    inputCardSection
                    statusSection
                    actionButtonSection
                    savedServerNotice
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadExistingServer()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            Image("port-logo")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .shadow(color: PortColors.brand.opacity(0.3), radius: 18, y: 6)

            VStack(spacing: 6) {
                Text("Port Music")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(PortColors.textPrimary)

                Text("Gib die IP-Adresse deines Servers ein, um fortzufahren.")
                    .font(.system(size: 15))
                    .foregroundColor(PortColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
    }

    private var inputCardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SERVER-ADRESSE")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(PortColors.textMuted)
                .tracking(1)

            HStack(spacing: 12) {
                Image(systemName: "server.rack")
                    .font(.system(size: 18))
                    .foregroundColor(PortColors.textSecondary)

                TextField("z. B. 192.168.1.100:3000", text: $serverInput)
                    .font(.system(size: 16))
                    .foregroundColor(PortColors.textPrimary)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: serverInput) { _ in
                        if case .failure = status {
                            status = .idle
                        }
                    }

                if !serverInput.isEmpty {
                    Button(action: {
                        serverInput = ""
                        status = .idle
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(PortColors.textMuted)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(PortColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: 1)
            )

            Text("Hinweis: Unterstuetzt lokale IPs, Hostnamen und Domains (HTTP & HTTPS).")
                .font(.system(size: 12))
                .foregroundColor(PortColors.textMuted)
                .padding(.horizontal, 4)
        }
    }

    private var borderColor: Color {
        switch status {
        case .idle, .pinging:
            return PortColors.border
        case .success:
            return PortColors.success.opacity(0.6)
        case .failure:
            return PortColors.error.opacity(0.6)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch status {
        case .idle:
            EmptyView()

        case .pinging:
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: PortColors.brand))

                Text("Verbindung wird geprueft...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(PortColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(PortColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))

        case .success(let url, let latency, let detail):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(PortColors.success)
                        .font(.system(size: 18))

                    Text("Server erfolgreich erreichbar!")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(PortColors.success)
                }

                Text("\(url) • \(latency) ms Latenz")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(PortColors.textPrimary)

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(PortColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(PortColors.successBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(PortColors.success.opacity(0.35), lineWidth: 1)
            )

        case .failure(let reason):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(PortColors.error)
                        .font(.system(size: 18))

                    Text("Server nicht erreichbar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(PortColors.error)
                }

                Text(reason)
                    .font(.system(size: 13))
                    .foregroundColor(PortColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(PortColors.errorBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(PortColors.error.opacity(0.35), lineWidth: 1)
            )
        }
    }

    private var actionButtonSection: some View {
        Button(action: handleAction) {
            HStack(spacing: 10) {
                if status == .pinging {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if case .success = status {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18))
                }

                Text(buttonTitle)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isButtonDisabled ? PortColors.surfaceElevated : PortColors.brand)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: isButtonDisabled ? .clear : PortColors.brand.opacity(0.35), radius: 10, y: 4)
        }
        .disabled(isButtonDisabled)
    }

    private var buttonTitle: String {
        switch status {
        case .idle:
            return "Weiter"
        case .pinging:
            return "Wird geprueft..."
        case .success:
            return "Server speichern"
        case .failure:
            return "Erneut versuchen"
        }
    }

    private var isButtonDisabled: Bool {
        serverInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || status == .pinging
    }

    @ViewBuilder
    private var savedServerNotice: some View {
        if hasSavedServer && !savedServerURL.isEmpty {
            VStack(spacing: 4) {
                Text("Aktuell gespeicherter Server:")
                    .font(.system(size: 12))
                    .foregroundColor(PortColors.textMuted)

                Text(savedServerURL)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(PortColors.textSecondary)
            }
            .padding(.top, 10)
        }
    }

    private func handleAction() {
        if case .success(let verifiedURL, _, _) = status {
            saveServer(url: verifiedURL)
            return
        }

        status = .pinging
        let raw = serverInput
        Task {
            let result = await ServerPingService.shared.ping(rawInput: raw)
            await MainActor.run {
                self.status = result
            }
        }
    }

    private func loadExistingServer() {
        if let stored = UserDefaults.standard.string(forKey: storageKey), !stored.isEmpty {
            self.savedServerURL = stored
            self.hasSavedServer = true
            if serverInput.isEmpty {
                self.serverInput = stored
            }
        }
    }

    private func saveServer(url: String) {
        UserDefaults.standard.set(url, forKey: storageKey)
        self.savedServerURL = url
        self.hasSavedServer = true
    }
}
