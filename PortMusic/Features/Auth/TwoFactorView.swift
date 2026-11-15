import SwiftUI

public struct TwoFactorView: View {
    public let serverURL: String
    public let pendingToken: String
    public let availableMethods: [String]
    public let maskedEmail: String?
    public let onVerificationSuccess: (UserProfile, String?) -> Void
    public let onCancel: () -> Void

    @State private var selectedMethod: String = "totp"
    @State private var codeInput: String = ""
    @State private var isSubmitting: Bool = false
    @State private var isSendingEmail: Bool = false
    @State private var errorMessage: String? = nil
    @State private var statusNotice: String? = nil
    @State private var cooldownSeconds: Int = 0

    public init(
        serverURL: String,
        pendingToken: String,
        availableMethods: [String] = ["totp"],
        maskedEmail: String? = nil,
        onVerificationSuccess: @escaping (UserProfile, String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.serverURL = serverURL
        self.pendingToken = pendingToken
        self.availableMethods = availableMethods
        self.maskedEmail = maskedEmail
        self.onVerificationSuccess = onVerificationSuccess
        self.onCancel = onCancel
    }

    // Abwärtskompatibler Initialisierer
    public init(
        serverURL: String,
        pendingToken: String,
        availableMethods: [String],
        maskedEmail: String?,
        onVerificationSuccess: @escaping (UserProfile) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.serverURL = serverURL
        self.pendingToken = pendingToken
        self.availableMethods = availableMethods
        self.maskedEmail = maskedEmail
        self.onVerificationSuccess = { profile, _ in onVerificationSuccess(profile) }
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Zurück-Button
            HStack {
                Button(action: onCancel) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Zurück")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(PortColors.textSecondary)
                }
                Spacer()
            }

            // Titel & Icon
            VStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44))
                    .foregroundColor(PortColors.textPrimary)
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 2)

                Text("Zwei-Faktor-Authentifizierung")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(PortColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitleText)
                    .font(.system(size: 13))
                    .foregroundColor(PortColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            // Methoden-Auswahl (falls mehrere verfügbar)
            if availableMethods.count > 1 {
                HStack(spacing: 12) {
                    if availableMethods.contains("totp") {
                        methodButton(id: "totp", title: "Authenticator", icon: "shield")
                    }
                    if availableMethods.contains("email") {
                        methodButton(id: "email", title: "E-Mail Code", icon: "envelope")
                    }
                }
            }

            // Eingabefeld für den 6-stelligen Code
            VStack(spacing: 14) {
                TextField(
                    "",
                    text: $codeInput,
                    prompt: Text("000000")
                        .foregroundColor(Color.white.opacity(0.55))
                )
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .foregroundColor(PortColors.textPrimary)
                    .padding(.vertical, 16)
                    .background(PortColors.surfaceGlass)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(PortColors.borderGlass, lineWidth: 1)
                    )
                    .onChange(of: codeInput) { newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered.count > 6 {
                            codeInput = String(filtered.prefix(6))
                        } else {
                            codeInput = filtered
                        }
                    }

                // Code erneut senden mit 60-Sekunden Countdown
                if selectedMethod == "email" {
                    Button(action: requestEmailCode) {
                        HStack(spacing: 6) {
                            if isSendingEmail {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            }

                            if cooldownSeconds > 0 {
                                Text("Code erneut senden in \(cooldownSeconds)s")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(PortColors.textMuted)
                            } else {
                                Text(isSendingEmail ? "Code wird gesendet..." : "Code erneut senden")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(PortColors.textSecondary)
                                    .underline()
                            }
                        }
                    }
                    .disabled(isSendingEmail || cooldownSeconds > 0)
                    .padding(.top, 4)
                }
            }

            // Fehlermeldung
            if let error = errorMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(PortColors.errorRed)
                        .font(.system(size: 16))

                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(PortColors.textPrimary)
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

            // Statusmeldung
            if let notice = statusNotice {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(PortColors.successGreen)
                        .font(.system(size: 16))

                    Text(notice)
                        .font(.system(size: 13))
                        .foregroundColor(PortColors.textPrimary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PortColors.successGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(PortColors.successGreen.opacity(0.35), lineWidth: 1)
                )
            }

            // Bestätigen-Button (Weiß)
            Button(action: verifyCode) {
                HStack(spacing: 10) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(0.85)
                    }
                    Text(isSubmitting ? "Wird überprüft..." : "Bestätigen")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PortColors.buttonPrimaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSubmit ? PortColors.buttonPrimaryBg : PortColors.buttonPrimaryBg.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canSubmit || isSubmitting)
        }
        .padding(24)
        .glassCard(cornerRadius: 24)
        .onAppear {
            if !availableMethods.contains(selectedMethod), let first = availableMethods.first {
                selectedMethod = first
            }
            if selectedMethod == "email" {
                requestEmailCode()
            }
        }
    }

    private var subtitleText: String {
        if selectedMethod == "email" {
            let target = maskedEmail ?? "Ihre E-Mail-Adresse"
            return "Geben Sie den 6-stelligen Code ein, der an \(target) gesendet wurde."
        } else {
            return "Geben Sie den 6-stelligen Code aus Ihrer Authenticator-App ein."
        }
    }

    private var canSubmit: Bool {
        codeInput.count >= 6
    }

    private func methodButton(id: String, title: String, icon: String) -> some View {
        Button(action: {
            selectedMethod = id
            errorMessage = nil
            statusNotice = nil
            if id == "email" && cooldownSeconds == 0 {
                requestEmailCode()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundColor(selectedMethod == id ? .black : PortColors.textSecondary)
            .background(selectedMethod == id ? Color.white : PortColors.surfaceGlass)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedMethod == id ? Color.clear : PortColors.borderGlass, lineWidth: 1)
            )
        }
    }

    private func requestEmailCode() {
        guard !isSendingEmail && cooldownSeconds == 0 else { return }
        isSendingEmail = true
        errorMessage = nil
        statusNotice = nil

        Task {
            do {
                let masked = try await AuthService.shared.sendLoginCode(
                    serverURL: serverURL,
                    pendingLoginToken: pendingToken
                )
                await MainActor.run {
                    isSendingEmail = false
                    let target = masked ?? self.maskedEmail ?? "Ihre E-Mail-Adresse"
                    self.statusNotice = "Code wurde an \(target) gesendet."
                    startCooldownTimer(seconds: 60)
                }
            } catch let authError as AuthError {
                await MainActor.run {
                    isSendingEmail = false
                    if authError == .tooManyAttempts {
                        self.errorMessage = "Bitte warten Sie vor dem erneuten Senden des Codes."
                        startCooldownTimer(seconds: 30)
                    } else {
                        self.errorMessage = authError.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    isSendingEmail = false
                    self.errorMessage = "Verbindung zum Server fehlgeschlagen."
                }
            }
        }
    }

    private func startCooldownTimer(seconds: Int) {
        cooldownSeconds = seconds
        Task {
            while cooldownSeconds > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    if cooldownSeconds > 0 {
                        cooldownSeconds -= 1
                    }
                }
            }
        }
    }

    private func verifyCode() {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            let isTotp = (selectedMethod.lowercased() == "totp")
            do {
                let result = try await AuthService.shared.verify2FA(
                    serverURL: serverURL,
                    pendingLoginToken: pendingToken,
                    code: codeInput,
                    isTotp: isTotp
                )

                await MainActor.run {
                    isSubmitting = false
                    switch result {
                    case .success(let user, let token):
                        onVerificationSuccess(user, token)
                    case .failure(let reason):
                        errorMessage = reason
                    default:
                        errorMessage = "Verifizierung fehlgeschlagen."
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
