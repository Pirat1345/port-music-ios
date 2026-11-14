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
                VStack(spacing: 24) {
                    Spacer().frame(height: 24)
                    headerSection
                    inputCardSection
                    statusSection
                    actionButtonSection
                    savedServerNotice
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadExistingServer()
        }
    }

    // MARK: - Header (matching Web Login Page: Logo + Manosque Font)
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Port Music Logo
            logoView
                .frame(width: 68, height: 68)
                .shadow(color: .black.opacity(0.6), radius: 10, y: 4)

            VStack(spacing: 6) {
                // Headline in Manosque custom font (matching <h1 className="font-manosque text-5xl">)
                Text("Port Music")
                    .font(.manosque(size: 44))
                    .tracking(1.0)
                    .foregroundColor(PortColors.textPrimary)
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 2)

                Text("Gib die IP-Adresse deines Servers ein, um fortzufahren.")
                    .font(.system(size: 14))
                    .foregroundColor(PortColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }

    private var logoView: some View {
        Image("PortLogo")
            .resizable()
            .scaledToFit()
    }

    // MARK: - Input Section
    private var inputCardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SERVER-ADRESSE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(PortColors.textMuted)
                .tracking(1.2)

            HStack(spacing: 12) {
                Image(systemName: "server.rack")
                    .font(.system(size: 17))
                    .foregroundColor(PortColors.textSecondary)

                TextField("z. B. 192.168.1.100:3000", text: $serverInput)
                    .font(.system(size: 15))
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
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(PortColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(inputBorderColor, lineWidth: 1)
            )

            Text("Unterstuetzt lokale IPs, Hostnamen und Domains (HTTP & HTTPS).")
                .font(.system(size: 12))
                .foregroundColor(PortColors.textMuted)
                .padding(.horizontal, 4)
        }
    }

    private var inputBorderColor: Color {
        switch status {
        case .idle, .pinging:
            return PortColors.border
        case .success:
            return PortColors.statusSuccessBorder
        case .failure:
            return PortColors.statusErrorBorder
        }
    }

    // MARK: - Status Badge (Stylistically White & Monochromatic)
    @ViewBuilder
    private var statusSection: some View {
        switch status {
        case .idle:
            EmptyView()

        case .pinging:
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))

                Text("Verbindung wird geprueft...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(PortColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(PortColors.surfaceGlass)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(PortColors.border, lineWidth: 1)
            )

        case .success(let url, let latency, let detail):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 17))

                    Text("Server erreichbar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text("\(url) • \(latency) ms Latenz")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(PortColors.textSecondary)

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(PortColors.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(PortColors.statusSuccessBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(PortColors.statusSuccessBorder, lineWidth: 1)
            )

        case .failure(let reason):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(Color(red: 239/255, green: 68/255, blue: 68/255))
                        .font(.system(size: 17))

                    Text("Verbindung fehlgeschlagen")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(reason)
                    .font(.system(size: 13))
                    .foregroundColor(PortColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(PortColors.statusErrorBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(PortColors.statusErrorBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Stylish White Action Button (matching <button className="bg-white text-neutral-950">)
    private var actionButtonSection: some View {
        Button(action: handleAction) {
            HStack(spacing: 10) {
                if status == .pinging {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: isButtonDisabled ? .white : PortColors.buttonText))
                } else if case .success = status {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 17))
                }

                Text(buttonTitle)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(isButtonDisabled ? PortColors.buttonDisabledText : PortColors.buttonText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isButtonDisabled ? PortColors.buttonDisabled : PortColors.buttonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: isButtonDisabled ? .clear : .white.opacity(0.15), radius: 8, y: 2)
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
                Text("Gespeicherter Server:")
                    .font(.system(size: 12))
                    .foregroundColor(PortColors.textMuted)

                Text(savedServerURL)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(PortColors.textSecondary)
            }
            .padding(.top, 8)
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
