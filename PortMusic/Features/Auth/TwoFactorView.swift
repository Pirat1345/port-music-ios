import SwiftUI

public struct TwoFactorView: View {
    public let serverURL: String
    public let pendingToken: String
    public let availableMethods: [String]
    public let maskedEmail: String?
    public let onVerificationSuccess: (UserProfile) -> Void
    public let onCancel: () -> Void

    @State private var selectedMethod: String = "totp"
    @State private var codeInput: String = ""
    @State private var isSubmitting: Bool = false
    @State private var isSendingEmail: Bool = false
    @State private var errorMessage: String? = nil
    @State private var statusNotice: String? = nil

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
        self.onVerificationSuccess = onVerificationSuccess
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
            VStack(spacing: 12) {
                TextField("000000", text: $codeInput)
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

                if selectedMethod == "email" {
                    Button(action: sendEmailCode) {
                        HStack(spacing: 6) {
                            if isSendingEmail {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            }
                            Text(isSendingEmail ? "Code wird gesendet..." : "Neuen Code anfordern")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(PortColors.textSecondary)
                                .underline()
                        }
                    }
                    .disabled(isSendingEmail)
                    .padding(.top, 4)
                }
            }

            // Fehlermeldung
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(PortColors.errorRed)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(PortColors.errorRed.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Statusmeldung
            if let notice = statusNotice {
                Text(notice)
                    .font(.system(size: 13))
                    .foregroundColor(PortColors.successGreen)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(PortColors.successGreen.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
                sendEmailCode()
            }
        }
    }

    private var subtitleText: String {
        if selectedMethod == "email" {
            let target = maskedEmail ?? "deine E-Mail-Adresse"
            return "Gib den 6-stelligen Code ein, der an \(target) gesendet wurde."
        } else {
            return "Gib den 6-stelligen Code aus deiner Authenticator-App ein."
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
            if id == "email" {
                sendEmailCode()
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

    private func sendEmailCode() {
        isSendingEmail = true
        errorMessage = nil
        statusNotice = nil

        Task {
            let res = await AuthService.shared.sendEmailCode(serverURL: serverURL, pendingToken: pendingToken)
            await MainActor.run {
                isSendingEmail = false
                if res.success {
                    statusNotice = res.message
                } else {
                    errorMessage = res.message
                }
            }
        }
    }

    private func verifyCode() {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            let result = await AuthService.shared.verify2FA(
                serverURL: serverURL,
                pendingToken: pendingToken,
                code: codeInput,
                method: selectedMethod
            )

            await MainActor.run {
                isSubmitting = false
                switch result {
                case .success(let user, _):
                    onVerificationSuccess(user)
                case .failure(let reason):
                    errorMessage = reason
                default:
                    errorMessage = "Verifizierung fehlgeschlagen."
                }
            }
        }
    }
}
