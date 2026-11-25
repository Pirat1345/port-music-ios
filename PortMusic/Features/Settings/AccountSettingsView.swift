import SwiftUI
import PhotosUI
import UIKit

public struct AccountSettingsView: View {
    public let user: UserProfile
    public let serverURL: String

    @ObservedObject private var sessionManager = SessionManager.shared

    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var isSavingProfile: Bool = false
    @State private var profileMessage: String? = nil
    @State private var profileSuccess: Bool = false

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var previewAvatarImage: UIImage? = nil
    @State private var isUploadingAvatar: Bool = false
    @State private var avatarMessage: String? = nil
    @State private var avatarSuccess: Bool = false

    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isUpdatingPassword: Bool = false
    @State private var passwordMessage: String? = nil
    @State private var passwordSuccess: Bool = false

    @State private var is2FAEnabled: Bool = false
    @State private var isLoading2FA: Bool = true
    @State private var isWorking2FA: Bool = false
    @State private var setupQRCodeDataURL: String? = nil
    @State private var setupSecret: String? = nil
    @State private var totpVerifyCode: String = ""
    @State private var disablePassword: String = ""
    @State private var showDisable2FAForm: Bool = false
    @State private var backupCodes: [String] = []
    @State private var twoFAMessage: String? = nil
    @State private var twoFASuccess: Bool = false

    public init(user: UserProfile, serverURL: String) {
        self.user = user
        self.serverURL = serverURL
        _displayName = State(initialValue: user.displayName ?? user.username)
        _email = State(initialValue: user.email ?? "")
    }

    private var activeUser: UserProfile {
        sessionManager.currentUser ?? user
    }

    private var activeBaseURL: String {
        let s = ServerProfileManager.shared.activeServerURL.isEmpty
            ? (sessionManager.serverURL ?? serverURL)
            : ServerProfileManager.shared.activeServerURL
        return s.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    }

    private var canSubmitPassword: Bool {
        !currentPassword.isEmpty && newPassword.count >= 8 && newPassword == confirmPassword
    }

    public var body: some View {
        List {
            // 1. Apple-ID-Stil Avatar Kopf + Foto ändern
            Section {
                VStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        if let preview = previewAvatarImage {
                            Image(uiImage: preview)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 92, height: 92)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                        } else {
                            PortUserAvatarView(
                                rawAvatar: activeUser.avatar,
                                username: activeUser.username,
                                serverURL: serverURL,
                                size: 92
                            )
                            .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                        }

                        if isUploadingAvatar {
                            ProgressView()
                                .tint(.white)
                                .padding(6)
                                .background(Circle().fill(Color.black.opacity(0.75)))
                        }
                    }

                    VStack(spacing: 3) {
                        Text(activeUser.displayName ?? activeUser.username)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("@\(activeUser.username)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Text(isUploadingAvatar ? "Wird hochgeladen..." : "Profilbild ändern")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#0a84ff"))
                    }
                    .disabled(isUploadingAvatar || sessionManager.isOfflineMode)

                    if let msg = avatarMessage {
                        Text(msg)
                            .font(.system(size: 12.5))
                            .foregroundColor(avatarSuccess ? Color(hex: "#30d158") : Color(hex: "#ff453a"))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color(white: 0.11))

            // 2. Persönliche Daten (Name & E-Mail)
            Section(
                header: Text("Name & E-Mail"),
                footer: Text("Änderungen an deinem Namen und deiner E-Mail-Adresse werden direkt mit deinem Port-Music-Konto synchronisiert.")
            ) {
                HStack {
                    Text("Benutzername")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(activeUser.username)
                        .foregroundColor(.white)
                }

                HStack {
                    Text("Anzeigename")
                        .foregroundColor(.secondary)
                        .frame(width: 110, alignment: .leading)
                    TextField("Name eingeben", text: $displayName)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.white)
                }

                HStack {
                    Text("E-Mail")
                        .foregroundColor(.secondary)
                        .frame(width: 110, alignment: .leading)
                    TextField("E-Mail-Adresse", text: $email)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundColor(.white)
                }

                if let msg = profileMessage {
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundColor(profileSuccess ? Color(hex: "#30d158") : Color(hex: "#ff453a"))
                }

                Button(action: { Task { await saveProfile() } }) {
                    HStack {
                        Spacer()
                        if isSavingProfile {
                            ProgressView().tint(.white)
                        } else {
                            Text("Name & E-Mail speichern")
                                .font(.system(size: 15.5, weight: .semibold))
                                .foregroundColor(sessionManager.isOfflineMode ? .gray : Color(hex: "#0a84ff"))
                        }
                        Spacer()
                    }
                }
                .disabled(isSavingProfile || sessionManager.isOfflineMode)
            }
            .listRowBackground(Color(white: 0.11))

            // 3. Passwort ändern
            Section(
                header: Text("Passwort ändern"),
                footer: Text("Das neue Passwort muss mindestens 8 Zeichen lang sein.")
            ) {
                SecureField("Aktuelles Passwort", text: $currentPassword)
                SecureField("Neues Passwort", text: $newPassword)
                SecureField("Neues Passwort bestätigen", text: $confirmPassword)

                if let msg = passwordMessage {
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundColor(passwordSuccess ? Color(hex: "#30d158") : Color(hex: "#ff453a"))
                }

                Button(action: { Task { await updatePassword() } }) {
                    HStack {
                        Spacer()
                        if isUpdatingPassword {
                            ProgressView().tint(.white)
                        } else {
                            Text("Passwort ändern")
                                .font(.system(size: 15.5, weight: .semibold))
                                .foregroundColor(canSubmitPassword && !sessionManager.isOfflineMode ? Color(hex: "#0a84ff") : .gray)
                        }
                        Spacer()
                    }
                }
                .disabled(!canSubmitPassword || isUpdatingPassword || sessionManager.isOfflineMode)
            }
            .listRowBackground(Color(white: 0.11))

            // 4. Zwei-Faktor-Authentifizierung (2FA)
            Section(
                header: Text("Zwei-Faktor-Authentifizierung (2FA)"),
                footer: Text("Verwende Apple Passwörter oder eine Authenticator-App, um dein Konto zusätzlich per TOTP-Code abzusichern.")
            ) {
                HStack {
                    Label {
                        Text("2FA-Status")
                            .foregroundColor(.white)
                    } icon: {
                        Image(systemName: is2FAEnabled ? "checkmark.shield.fill" : "shield")
                            .foregroundColor(is2FAEnabled ? Color(hex: "#30d158") : .secondary)
                    }
                    Spacer()
                    if isLoading2FA {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Text(is2FAEnabled ? "Aktiviert" : "Aus")
                            .foregroundColor(is2FAEnabled ? Color(hex: "#30d158") : .secondary)
                    }
                }

                if let msg = twoFAMessage {
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundColor(twoFASuccess ? Color(hex: "#30d158") : Color(hex: "#ff453a"))
                }

                if !backupCodes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Backup-Wiederherstellungscodes (sicher aufbewahren)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text(backupCodes.joined(separator: "  ·  "))
                            .font(.system(size: 12.5, design: .monospaced))
                            .foregroundColor(Color(hex: "#30d158"))
                        Button("Backup-Codes kopieren") {
                            UIPasteboard.general.string = backupCodes.joined(separator: "\n")
                            twoFAMessage = "Backup-Codes in die Zwischenablage kopiert."
                            twoFASuccess = true
                        }
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(Color(hex: "#0a84ff"))
                    }
                    .padding(.vertical, 4)
                }

                if is2FAEnabled {
                    if showDisable2FAForm {
                        SecureField("Passwort zur Bestätigung", text: $disablePassword)
                        Button(role: .destructive, action: { Task { await disable2FA() } }) {
                            HStack {
                                Spacer()
                                if isWorking2FA {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("2FA jetzt deaktivieren")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                Spacer()
                            }
                        }
                        .disabled(disablePassword.isEmpty || isWorking2FA)
                    } else {
                        Button("2FA deaktivieren...", role: .destructive) {
                            showDisable2FAForm = true
                        }
                        .disabled(sessionManager.isOfflineMode)
                    }
                } else if let qrData = setupQRCodeDataURL, let secret = setupSecret {
                    VStack(spacing: 12) {
                        if let qrImage = decodeDataURLImage(qrData) {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 170, height: 170)
                                .padding(8)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(spacing: 4) {
                            Text("Setup-Schlüssel (manuell)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(secret)
                                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }

                        Button("Schlüssel kopieren") {
                            UIPasteboard.general.string = secret
                            twoFAMessage = "Secret-Schlüssel kopiert."
                            twoFASuccess = true
                        }
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(Color(hex: "#0a84ff"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)

                    TextField("6-stelliger Authenticator-Code", text: $totpVerifyCode)
                        .keyboardType(.numberPad)
                        .foregroundColor(.white)

                    Button(action: { Task { await verify2FASetup() } }) {
                        HStack {
                            Spacer()
                            if isWorking2FA {
                                ProgressView().tint(.white)
                            } else {
                                Text("Code bestätigen & 2FA aktivieren")
                                    .font(.system(size: 15.5, weight: .semibold))
                                    .foregroundColor(totpVerifyCode.count >= 6 ? Color(hex: "#0a84ff") : .gray)
                            }
                            Spacer()
                        }
                    }
                    .disabled(totpVerifyCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 6 || isWorking2FA)
                } else {
                    Button(action: { Task { await start2FASetup() } }) {
                        HStack {
                            Spacer()
                            if isWorking2FA {
                                ProgressView().tint(.white)
                            } else {
                                Text("2FA einrichten")
                                    .font(.system(size: 15.5, weight: .semibold))
                                    .foregroundColor(sessionManager.isOfflineMode ? .gray : Color(hex: "#0a84ff"))
                            }
                            Spacer()
                        }
                    }
                    .disabled(isWorking2FA || isLoading2FA || sessionManager.isOfflineMode)
                }
            }
            .listRowBackground(Color(white: 0.11))
        }
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .listStyle(.insetGrouped)
        .navigationTitle("Konto & Profil")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetch2FAStatus()
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let item = newItem else { return }
            Task { await handlePickedPhoto(item) }
        }
    }

    // MARK: - Networking Helpers
    private func authorizedRequest(path: String, method: String) -> URLRequest? {
        guard !activeBaseURL.isEmpty, let url = URL(string: "\(activeBaseURL)\(path)") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 12
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = sessionManager.currentToken, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue(token, forHTTPHeaderField: "x-session-token")
        }
        return req
    }

    private func handlePickedPhoto(_ item: PhotosPickerItem) async {
        await MainActor.run {
            isUploadingAvatar = true
            avatarMessage = nil
        }
        defer { Task { @MainActor in self.isUploadingAvatar = false } }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data),
              let dataUrl = resizeAndEncodeAvatar(uiImage) else {
            await MainActor.run {
                avatarSuccess = false
                avatarMessage = "Bild konnte nicht verarbeitet werden."
            }
            return
        }

        await MainActor.run {
            self.previewAvatarImage = uiImage
        }

        guard var req = authorizedRequest(path: "/api/auth/avatar", method: "PUT"),
              let body = try? JSONSerialization.data(withJSONObject: ["avatarDataUrl": dataUrl]) else {
            await MainActor.run {
                avatarSuccess = false
                avatarMessage = "Ungültige Server-URL."
            }
            return
        }
        req.httpBody = body

        do {
            let (respData, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 500
            if (200...299).contains(code) {
                PortImageCache.shared.clearAllCache()
                await sessionManager.refreshUserProfile()
                await MainActor.run {
                    avatarSuccess = true
                    avatarMessage = "Profilbild aktualisiert."
                }
            } else {
                let msg = parseErrorMessage(from: respData) ?? "Upload fehlgeschlagen (\(code))."
                await MainActor.run {
                    avatarSuccess = false
                    avatarMessage = msg
                }
            }
        } catch {
            await MainActor.run {
                avatarSuccess = false
                avatarMessage = "Netzwerkfehler beim Hochladen."
            }
        }
    }

    private func saveProfile() async {
        isSavingProfile = true
        profileMessage = nil
        defer { Task { @MainActor in self.isSavingProfile = false } }

        guard var req = authorizedRequest(path: "/api/auth/profile", method: "PUT") else { return }
        var payload: [String: String] = [:]
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanName.isEmpty { payload["displayName"] = cleanName }
        if !cleanEmail.isEmpty { payload["email"] = cleanEmail }
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 500
            if (200...299).contains(code) {
                await sessionManager.refreshUserProfile()
                await MainActor.run {
                    profileSuccess = true
                    profileMessage = "Name und E-Mail gespeichert."
                }
            } else {
                let err = parseErrorMessage(from: data) ?? "Speichern fehlgeschlagen."
                await MainActor.run {
                    profileSuccess = false
                    profileMessage = err
                }
            }
        } catch {
            await MainActor.run {
                profileSuccess = false
                profileMessage = "Verbindungsfehler zum Server."
            }
        }
    }

    private func updatePassword() async {
        guard canSubmitPassword else { return }
        isUpdatingPassword = true
        passwordMessage = nil
        defer { Task { @MainActor in self.isUpdatingPassword = false } }

        guard var req = authorizedRequest(path: "/api/auth/profile", method: "PUT") else { return }
        let payload: [String: String] = [
            "currentPassword": currentPassword,
            "newPassword": newPassword
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 500
            if (200...299).contains(code) {
                await MainActor.run {
                    passwordSuccess = true
                    passwordMessage = "Passwort erfolgreich geändert."
                    currentPassword = ""
                    newPassword = ""
                    confirmPassword = ""
                }
            } else {
                let rawErr = parseErrorMessage(from: data) ?? "Fehler beim Passwortwechsel."
                let friendly = rawErr.contains("CURRENT_PASSWORD_WRONG") ? "Aktuelles Passwort ist falsch." : rawErr
                await MainActor.run {
                    passwordSuccess = false
                    passwordMessage = friendly
                }
            }
        } catch {
            await MainActor.run {
                passwordSuccess = false
                passwordMessage = "Verbindungsfehler zum Server."
            }
        }
    }

    private func fetch2FAStatus() async {
        isLoading2FA = true
        defer { Task { @MainActor in self.isLoading2FA = false } }
        guard let req = authorizedRequest(path: "/api/auth/2fa/status", method: "GET") else { return }
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let enabled = json["enabled"] as? Bool {
            await MainActor.run {
                self.is2FAEnabled = enabled
            }
        }
    }

    private func start2FASetup() async {
        isWorking2FA = true
        twoFAMessage = nil
        defer { Task { @MainActor in self.isWorking2FA = false } }
        guard let req = authorizedRequest(path: "/api/auth/2fa/setup", method: "POST") else { return }
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            await MainActor.run {
                self.setupQRCodeDataURL = json["qrCode"] as? String
                self.setupSecret = json["secret"] as? String
            }
        } else {
            await MainActor.run {
                self.twoFASuccess = false
                self.twoFAMessage = "2FA-Einrichtung konnte nicht gestartet werden."
            }
        }
    }

    private func verify2FASetup() async {
        let codeClean = totpVerifyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !codeClean.isEmpty else { return }
        isWorking2FA = true
        twoFAMessage = nil
        defer { Task { @MainActor in self.isWorking2FA = false } }
        guard var req = authorizedRequest(path: "/api/auth/2fa/verify-setup", method: "POST") else { return }
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["code": codeClean])

        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse {
            if (200...299).contains(http.statusCode) {
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let codes = json?["backupCodes"] as? [String] ?? []
                await MainActor.run {
                    self.is2FAEnabled = true
                    self.setupQRCodeDataURL = nil
                    self.setupSecret = nil
                    self.totpVerifyCode = ""
                    self.backupCodes = codes
                    self.twoFASuccess = true
                    self.twoFAMessage = "2FA erfolgreich aktiviert."
                }
            } else {
                let err = parseErrorMessage(from: data) ?? "Ungültiger Bestätigungscode."
                await MainActor.run {
                    self.twoFASuccess = false
                    self.twoFAMessage = err
                }
            }
        }
    }

    private func disable2FA() async {
        isWorking2FA = true
        twoFAMessage = nil
        defer { Task { @MainActor in self.isWorking2FA = false } }
        guard var req = authorizedRequest(path: "/api/auth/2fa/disable", method: "POST") else { return }
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["password": disablePassword])

        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse {
            if (200...299).contains(http.statusCode) {
                await MainActor.run {
                    self.is2FAEnabled = false
                    self.showDisable2FAForm = false
                    self.disablePassword = ""
                    self.backupCodes = []
                    self.twoFASuccess = true
                    self.twoFAMessage = "2FA deaktiviert."
                }
            } else {
                let err = parseErrorMessage(from: data) ?? "Deaktivieren fehlgeschlagen."
                await MainActor.run {
                    self.twoFASuccess = false
                    self.twoFAMessage = err
                }
            }
        }
    }

    private func resizeAndEncodeAvatar(_ image: UIImage) -> String? {
        let maxSide: CGFloat = 512
        let scale = min(1.0, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        var quality: CGFloat = 0.85
        var data = resized.jpegData(compressionQuality: quality)
        while let d = data, d.count > 1_600_000, quality > 0.3 {
            quality -= 0.15
            data = resized.jpegData(compressionQuality: quality)
        }
        guard let finalData = data else { return nil }
        return "data:image/jpeg;base64,\(finalData.base64EncodedString())"
    }

    private func decodeDataURLImage(_ dataUrl: String) -> UIImage? {
        let parts = dataUrl.components(separatedBy: ",")
        guard let b64 = parts.last, let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return (json["message"] as? String) ?? (json["error"] as? String)
        }
        return String(data: data, encoding: .utf8)
    }
}
