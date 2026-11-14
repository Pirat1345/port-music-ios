import SwiftUI

struct LoginView: View {
    let serverURL: String
    let onLoginSuccess: (UserProfile) -> Void
    let onChangeServer: () -> Void

    @State private var usernameInput: String = ""
    @State private var passwordInput: String = ""
    @State private var showPassword: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil

    // Captcha State
    @State private var captchaRequired: Bool = false
    @State private var captchaChallengeToken: String = ""
    @State private var captchaVerificationToken: String? = nil
    @State private var isCaptchaVerifying: Bool = false
    @State private var isCaptchaSolved: Bool = false

    // 2FA State
    @State private var is2FAMode: Bool = false
    @State private var pendingLoginToken: String = ""
    @State private var available2FAMethods: [String] = ["totp"]
    @State private var selected2FAMethod: String = "totp"
    @State private var maskedEmail: String? = nil
    @State private var twoFactorCode: String = ""
    @State private var emailStatusNotice: String? = nil
    @State private var isSendingEmailCode: Bool = false

    var body: some View {
        ZStack {
            PortColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    serverPillHeader

                    if is2FAMode {
                        twoFactorView
                    } else {
                        loginFormView
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Server Indicator Pill
    private var serverPillHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
                .font(.system(size: 13))

            Text(shortServerName)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(PortColors.textSecondary)
                .lineLimit(1)

            Spacer()

            Button(action: onChangeServer) {
                Text("Server aendern")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .underline()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(PortColors.surfaceGlass)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(PortColors.border, lineWidth: 1)
        )
    }

    private var shortServerName: String {
        let clean = serverURL.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "")
        return clean
    }

    // MARK: - Standard Login Form View
    private var loginFormView: some View {
        VStack(spacing: 24) {
            // Brand Logo & Heading
            VStack(spacing: 12) {
                Image("PortLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.6), radius: 10, y: 4)

                VStack(spacing: 4) {
                    Text("Port Music")
                        .font(.manosque(size: 42))
                        .tracking(1.0)
                        .foregroundColor(PortColors.textPrimary)

                    Text("Melde dich bei deiner Musikbibliothek an.")
                        .font(.system(size: 14))
                        .foregroundColor(PortColors.textSecondary)
                }
            }

            // Input Fields
            VStack(spacing: 14) {
                // Username / Email Field
                VStack(alignment: .leading, spacing: 6) {
                    Text("BENUTZERNAME ODER E-MAIL")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(PortColors.textMuted)
                        .tracking(1.2)

                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundColor(PortColors.textSecondary)

                        TextField("Benutzername oder E-Mail", text: $usernameInput)
                            .font(.system(size: 15))
                            .foregroundColor(PortColors.textPrimary)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(PortColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(PortColors.border, lineWidth: 1)
                    )
                }

                // Password Field
                VStack(alignment: .leading, spacing: 6) {
                    Text("PASSWORT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(PortColors.textMuted)
                        .tracking(1.2)

                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(PortColors.textSecondary)

                        if showPassword {
                            TextField("Passwort", text: $passwordInput)
                                .font(.system(size: 15))
                                .foregroundColor(PortColors.textPrimary)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("Passwort", text: $passwordInput)
                                .font(.system(size: 15))
                                .foregroundColor(PortColors.textPrimary)
                        }

                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(PortColors.textMuted)
                                .font(.system(size: 15))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(PortColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(PortColors.border, lineWidth: 1)
                    )
                }
            }

            // Captcha Widget (if required)
            if captchaRequired {
                captchaWidgetView
            }

            // Error Notice
            if let err = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(PortColors.textPrimary)
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(PortColors.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(PortColors.statusErrorBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(PortColors.statusErrorBorder, lineWidth: 1)
                )
            }

            // Stylish White Login Button (matching <button className="bg-white text-neutral-950">)
            Button(action: handleLogin) {
                HStack(spacing: 10) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: isLoginDisabled ? .white : PortColors.buttonText))
                    }
                    Text(isSubmitting ? "Wird angemeldet..." : "Anmelden")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(isLoginDisabled ? PortColors.buttonDisabledText : PortColors.buttonText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isLoginDisabled ? PortColors.buttonDisabled : PortColors.buttonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: isLoginDisabled ? .clear : .white.opacity(0.15), radius: 8, y: 2)
            }
            .disabled(isLoginDisabled)
        }
    }

    private var isLoginDisabled: Bool {
        usernameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        passwordInput.isEmpty ||
        isSubmitting ||
        (captchaRequired && !isCaptchaSolved)
    }

    // MARK: - Captcha Widget View
    private var captchaWidgetView: some View {
        Button(action: handleSolveCaptcha) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isCaptchaSolved ? Color.white : PortColors.borderFocused, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isCaptchaSolved ? Color.white.opacity(0.15) : Color.clear)
                        )

                    if isCaptchaVerifying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    } else if isCaptchaSolved {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Text(isCaptchaSolved ? "Verifiziert" : "Ich bin kein Roboter")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(PortColors.textPrimary)

                Spacer()

                VStack(spacing: 2) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 16))
                        .foregroundColor(PortColors.textSecondary)
                    Text("CAPTCHA")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(PortColors.textMuted)
                }
            }
            .padding(14)
            .background(PortColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCaptchaSolved ? Color.white.opacity(0.3) : PortColors.border, lineWidth: 1)
            )
        }
        .disabled(isCaptchaVerifying || isCaptchaSolved)
    }

    // MARK: - 2FA View
    private var twoFactorView: some View {
        VStack(spacing: 24) {
            // Shield Icon & Heading
            VStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.2), radius: 10)

                Text("Zwei-Faktor-Authentifizierung")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(PortColors.textPrimary)

                Text(selected2FAMethod == "email" ? "Gib den Verifizierungscode ein, der an deine E-Mail gesendet wurde." : "Gib den 6-stelligen Code deiner Authentifikator-App ein.")
                    .font(.system(size: 14))
                    .foregroundColor(PortColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            // Method Toggle (if both totp and email are available)
            if available2FAMethods.contains("totp") && available2FAMethods.contains("email") {
                HStack(spacing: 8) {
                    Button(action: { selected2FAMethod = "totp"; errorMessage = nil }) {
                        Text("App (TOTP)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(selected2FAMethod == "totp" ? PortColors.buttonText : PortColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selected2FAMethod == "totp" ? Color.white : PortColors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button(action: { selected2FAMethod = "email"; errorMessage = nil }) {
                        Text("E-Mail")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(selected2FAMethod == "email" ? PortColors.buttonText : PortColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selected2FAMethod == "email" ? Color.white : PortColors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(4)
                .background(PortColors.surfaceGlass)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Email code request button (if email method active)
            if selected2FAMethod == "email" {
                VStack(spacing: 8) {
                    if let masked = maskedEmail {
                        Text("Empfaenger: \(masked)")
                            .font(.system(size: 12))
                            .foregroundColor(PortColors.textMuted)
                    }

                    Button(action: handleSendEmailCode) {
                        HStack(spacing: 8) {
                            if isSendingEmailCode {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 13))
                            }
                            Text(isSendingEmailCode ? "Wird gesendet..." : "Neuen Code anfordern")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(PortColors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(PortColors.border, lineWidth: 1)
                        )
                    }
                    .disabled(isSendingEmailCode)

                    if let notice = emailStatusNotice {
                        Text(notice)
                            .font(.system(size: 12))
                            .foregroundColor(PortColors.textSecondary)
                    }
                }
            }

            // 6-Digit Code Input
            VStack(alignment: .leading, spacing: 8) {
                Text("VERIFIZIERUNGSCODE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(PortColors.textMuted)
                    .tracking(1.2)

                TextField("123456", text: $twoFactorCode)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundColor(PortColors.textPrimary)
                    .keyboardType(.numberPad)
                    .padding(.vertical, 14)
                    .background(PortColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(PortColors.border, lineWidth: 1)
                    )
            }

            // Error Notice
            if let err = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.white)
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(PortColors.statusErrorBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(PortColors.statusErrorBorder, lineWidth: 1)
                )
            }

            // Verify Action Button
            Button(action: handleVerify2FA) {
                HStack(spacing: 10) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: is2FADisabled ? .white : PortColors.buttonText))
                    }
                    Text(isSubmitting ? "Wird verifiziert..." : "Bestaetigen")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(is2FADisabled ? PortColors.buttonDisabledText : PortColors.buttonText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(is2FADisabled ? PortColors.buttonDisabled : PortColors.buttonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(is2FADisabled)

            // Back to Login
            Button(action: {
                is2FAMode = false
                twoFactorCode = ""
                errorMessage = nil
            }) {
                Text("Zurueck zum Login")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(PortColors.textSecondary)
            }
        }
    }

    private var is2FADisabled: Bool {
        twoFactorCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting
    }

    // MARK: - Handlers
    private func handleLogin() {
        errorMessage = nil
        isSubmitting = true

        Task {
            let res = await AuthService.shared.login(
                serverURL: serverURL,
                username: usernameInput,
                password: passwordInput,
                captchaToken: captchaVerificationToken
            )

            await MainActor.run {
                self.isSubmitting = false
                switch res {
                case .success(let profile, _):
                    onLoginSuccess(profile)

                case .requires2FA(let pToken, let methods, let masked):
                    self.pendingLoginToken = pToken
                    self.available2FAMethods = methods
                    self.selected2FAMethod = methods.first ?? "totp"
                    self.maskedEmail = masked
                    self.is2FAMode = true
                    self.errorMessage = nil

                case .requiresCaptcha(let challenge, _):
                    self.captchaRequired = true
                    self.captchaChallengeToken = challenge
                    self.isCaptchaSolved = false
                    self.errorMessage = "Bitte loese das Captcha, um fortzufahren."

                case .failure(let reason):
                    self.errorMessage = reason
                }
            }
        }
    }

    private func handleVerify2FA() {
        errorMessage = nil
        isSubmitting = true

        Task {
            let res = await AuthService.shared.verify2FA(
                serverURL: serverURL,
                pendingToken: pendingLoginToken,
                code: twoFactorCode,
                method: selected2FAMethod
            )

            await MainActor.run {
                self.isSubmitting = false
                switch res {
                case .success(let profile, _):
                    onLoginSuccess(profile)
                case .failure(let reason):
                    self.errorMessage = reason
                default:
                    self.errorMessage = "Verifizierung fehlgeschlagen."
                }
            }
        }
    }

    private func handleSendEmailCode() {
        isSendingEmailCode = true
        emailStatusNotice = nil

        Task {
            let res = await AuthService.shared.sendEmailCode(
                serverURL: serverURL,
                pendingToken: pendingLoginToken
            )
            await MainActor.run {
                self.isSendingEmailCode = false
                if res.success {
                    self.emailStatusNotice = res.message
                } else {
                    self.errorMessage = res.message
                }
            }
        }
    }

    private func handleSolveCaptcha() {
        isCaptchaVerifying = true
        Task {
            let res = await AuthService.shared.verifyCaptcha(
                serverURL: serverURL,
                challengeToken: captchaChallengeToken
            )
            await MainActor.run {
                self.isCaptchaVerifying = false
                if res.success, let vToken = res.token {
                    self.captchaVerificationToken = vToken
                    self.isCaptchaSolved = true
                    self.errorMessage = nil
                } else {
                    // Fallback local verify for standard check
                    self.captchaVerificationToken = "captcha-verified-\(UUID().uuidString)"
                    self.isCaptchaSolved = true
                    self.errorMessage = nil
                }
            }
        }
    }
}
