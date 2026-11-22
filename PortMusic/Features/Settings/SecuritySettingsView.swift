import SwiftUI

public struct SecuritySettingsView: View {
    @State private var is2FAEnabled: Bool = false
    @State private var isLoading2FA: Bool = true

    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isUpdatingPassword: Bool = false
    @State private var passwordMessage: String? = nil
    @State private var passwordSuccess: Bool = false

    private var serverURL: String {
        ServerProfileManager.shared.activeServerURL.isEmpty
            ? (SessionManager.shared.serverURL ?? "")
            : ServerProfileManager.shared.activeServerURL
    }

    private var token: String? {
        SessionManager.shared.currentToken
    }

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            List {
                // MARK: - 1. Zwei-Faktor-Authentifizierung (2FA)
                Section(
                    header: Text("Zwei-Faktor-Authentifizierung (2FA)").foregroundColor(.gray),
                    footer: Text("Schütze dein Konto zusätzlich mit einem 6-stelligen Authenticator-Code (TOTP, z. B. Apple Passwords oder Google Authenticator).")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                ) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(is2FAEnabled ? Color.green : Color.gray)
                                .frame(width: 30, height: 30)

                            Image(systemName: is2FAEnabled ? "checkmark.shield.fill" : "shield.slash")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("2FA-Status")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)

                            if isLoading2FA {
                                Text("Wird geprüft...")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            } else {
                                Text(is2FAEnabled ? "Aktiviert und geschützt" : "Nicht eingerichtet")
                                    .font(.system(size: 12))
                                    .foregroundColor(is2FAEnabled ? .green : .gray)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(Color(white: 0.10))

                // MARK: - 2. Passwort ändern
                Section(
                    header: Text("Passwort ändern").foregroundColor(.gray),
                    footer: Text("Das neue Passwort muss mindestens 8 Zeichen lang sein.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                ) {
                    SecureField("Aktuelles Passwort", text: $currentPassword)
                        .foregroundColor(.white)

                    SecureField("Neues Passwort", text: $newPassword)
                        .foregroundColor(.white)

                    SecureField("Neues Passwort bestätigen", text: $confirmPassword)
                        .foregroundColor(.white)

                    if let msg = passwordMessage {
                        Text(msg)
                            .font(.system(size: 13))
                            .foregroundColor(passwordSuccess ? .green : .red)
                    }

                    Button(action: {
                        Task { await performPasswordChange() }
                    }) {
                        HStack {
                            Spacer()
                            if isUpdatingPassword {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Passwort aktualisieren")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(canSubmitPassword ? .blue : .gray)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmitPassword || isUpdatingPassword)
                }
                .listRowBackground(Color(white: 0.10))
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Sicherheit & 2FA")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .task {
            await fetch2FAStatus()
        }
    }

    private var canSubmitPassword: Bool {
        !currentPassword.isEmpty && newPassword.count >= 8 && newPassword == confirmPassword
    }

    private func fetch2FAStatus() async {
        isLoading2FA = true
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: "\(base)/api/auth/2fa/status") else {
            isLoading2FA = false
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if let tok = token, !tok.isEmpty {
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let enabled = json["enabled"] as? Bool {
                    await MainActor.run {
                        self.is2FAEnabled = enabled
                        self.isLoading2FA = false
                    }
                    return
                }
            }
        } catch {}

        await MainActor.run {
            self.isLoading2FA = false
        }
    }

    private func performPasswordChange() async {
        guard canSubmitPassword else { return }
        isUpdatingPassword = true
        passwordMessage = nil
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: "\(base)/api/auth/profile") else {
            isUpdatingPassword = false
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let tok = token, !tok.isEmpty {
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        let payload: [String: String] = [
            "current_password": currentPassword,
            "password": newPassword
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            isUpdatingPassword = false
            return
        }
        req.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
            if (200...299).contains(statusCode) {
                await MainActor.run {
                    self.passwordSuccess = true
                    self.passwordMessage = "Passwort erfolgreich geändert"
                    self.currentPassword = ""
                    self.newPassword = ""
                    self.confirmPassword = ""
                    self.isUpdatingPassword = false
                }
            } else {
                let errStr = String(data: data, encoding: .utf8) ?? "Fehler beim Ändern des Passworts"
                await MainActor.run {
                    self.passwordSuccess = false
                    self.passwordMessage = errStr.contains("Password") ? "Aktuelles Passwort ist ungültig" : errStr
                    self.isUpdatingPassword = false
                }
            }
        } catch {
            await MainActor.run {
                self.passwordSuccess = false
                self.passwordMessage = "Verbindungsfehler zum Server"
                self.isUpdatingPassword = false
            }
        }
    }
}
