import SwiftUI

public struct LoginView: View {
    public let serverURL: String
    public let onLoginSuccess: (UserProfile) -> Void
    public let onChangeServer: () -> Void

    @State private var usernameInput: String = ""
    @State private var passwordInput: String = ""
    @State private var showPassword: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil

    // Captcha-Status
    @State private var captchaRequired: Bool = false
    @State private var captchaLoading: Bool = false
    @State private var captchaVerified: Bool = false
    @State private var captchaVerificationToken: String? = nil

    // 2FA-Modus
    @State private var is2FAMode: Bool = false
    @State private var pendingLoginToken: String = ""
    @State private var twoFactorMethods: [String] = ["totp"]
    @State private var maskedEmail: String? = nil

    public init(
        serverURL: String,
        onLoginSuccess: @escaping (UserProfile) -> Void,
        onChangeServer: @escaping () -> Void
    ) {
        self.serverURL = serverURL
        self.onLoginSuccess = onLoginSuccess
        self.onChangeServer = onChangeServer
    }

    public var body: some View {
        ZStack {
            // Fluent Animated Seiden-Hintergrund
            FluentBackgroundView()

            ScrollView {
                VStack(spacing: 24) {
                    // Dezenter Server-Indikator oben
                    serverHeaderBadge

                    if is2FAMode {
                        TwoFactorView(
                            serverURL: serverURL,
                            pendingToken: pendingLoginToken,
                            availableMethods: twoFactorMethods,
                            maskedEmail: maskedEmail,
                            onVerificationSuccess: onLoginSuccess,
                            onCancel: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    is2FAMode = false
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)),
                            removal: .opacity
                        ))
                    } else {
                        loginFormContent
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96)),
                                removal: .opacity
                            ))
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            checkCaptchaStatus()
        }
    }

    // MARK: - Dezenter Server-Indikator (kein aufdringlicher Banner)
    private var serverHeaderBadge: some View {
        HStack {
            Button(action: onChangeServer) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(PortColors.successGreen)
                        .frame(width: 7, height: 7)

                    Text(shortHostName)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(PortColors.textSecondary)

                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundColor(PortColors.textMuted)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(PortColors.surfaceGlass)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(PortColors.borderGlass, lineWidth: 1)
                )
            }
            Spacer()
        }
    }

    private var shortHostName: String {
        let clean = serverURL
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
        return clean.components(separatedBy: "/").first ?? clean
    }

    // MARK: - Anmeldeformular
    private var loginFormContent: some View {
        VStack(spacing: 24) {
            // Offizielles Logo & Manosque-Schriftzug
            VStack(spacing: 12) {
                PortLogoView(size: 64)

                VStack(spacing: 6) {
                    Text("Port Music")
                        .font(.manosque(size: 44))
                        .foregroundColor(PortColors.textPrimary)
                        .shadow(color: .black.opacity(0.6), radius: 6, y: 2)

                    Text("Melde dich mit deinem Benutzerkonto an.")
                        .font(.system(size: 13))
                        .foregroundColor(PortColors.textSecondary)
                }
            }
            .padding(.top, 8)

            // Eingabefelder
            VStack(spacing: 16) {
                // Benutzername / E-Mail
                VStack(alignment: .leading, spacing: 8) {
                    Text("BENUTZERNAME ODER E-MAIL")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(PortColors.textMuted)
                        .tracking(1.2)

                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 15))
                            .foregroundColor(PortColors.textSecondary)

                        TextField("Benutzername oder E-Mail", text: $usernameInput)
                            .font(.system(size: 15))
                            .foregroundColor(PortColors.textPrimary)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(PortColors.surfaceGlass)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(PortColors.borderGlass, lineWidth: 1)
                    )
                }

                // Passwort
                VStack(alignment: .leading, spacing: 8) {
                    Text("PASSWORT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(PortColors.textMuted)
                        .tracking(1.2)

                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15))
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
                                .font(.system(size: 15))
                                .foregroundColor(PortColors.textMuted)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(PortColors.surfaceGlass)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(PortColors.borderGlass, lineWidth: 1)
                    )
                }

                // Captcha-Feld (wird angezeigt wenn vom Server verlangt)
                if captchaRequired {
                    CaptchaWidgetView(
                        isVerified: captchaVerified,
                        isLoading: captchaLoading,
                        onCheckboxTapped: solveCaptcha
                    )
                    .padding(.top, 4)
                }
            }
            .padding(20)
            .glassCard(cornerRadius: 22)

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

            // Anmelden-Button (Monochrom Weiß)
            Button(action: performLogin) {
                HStack(spacing: 10) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(0.85)
                    }

                    Text(isSubmitting ? "Wird angemeldet..." : "Anmelden")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PortColors.buttonPrimaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSubmit ? PortColors.buttonPrimaryBg : PortColors.buttonPrimaryBg.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: canSubmit ? Color.white.opacity(0.15) : Color.clear, radius: 10, y: 3)
            }
            .disabled(!canSubmit || isSubmitting)
        }
    }

    private var canSubmit: Bool {
        let hasCreds = !usernameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !passwordInput.isEmpty
        if captchaRequired && !captchaVerified {
            return false
        }
        return hasCreds
    }

    // MARK: - Server-Aktionen
    private func checkCaptchaStatus() {
        Task {
            let required = await AuthService.shared.fetchCaptchaStatus(serverURL: serverURL)
            await MainActor.run {
                if required {
                    self.captchaRequired = true
                }
            }
        }
    }

    private func solveCaptcha() {
        captchaLoading = true
        errorMessage = nil

        Task {
            // Challenge abrufen falls noch keine vorliegt
            guard let challenge = await AuthService.shared.fetchCaptchaChallenge(serverURL: serverURL),
                  let token = challenge.challengeToken else {
                await MainActor.run {
                    captchaLoading = false
                    errorMessage = "Sicherheitsabfrage konnte nicht geladen werden."
                }
                return
            }

            // Verifizierung durchführen
            let verifyRes = await AuthService.shared.verifyCaptcha(
                serverURL: serverURL,
                challengeToken: token,
                target: challenge.target
            )

            await MainActor.run {
                captchaLoading = false
                if verifyRes.success, let vToken = verifyRes.token {
                    self.captchaVerified = true
                    self.captchaVerificationToken = vToken
                } else {
                    self.errorMessage = "Captcha-Verifizierung fehlgeschlagen."
                }
            }
        }
    }

    private func performLogin() {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            let result = await AuthService.shared.login(
                serverURL: serverURL,
                username: usernameInput,
                password: passwordInput,
                captchaToken: captchaVerificationToken
            )

            await MainActor.run {
                isSubmitting = false
                switch result {
                case .success(let user, _):
                    onLoginSuccess(user)

                case .requires2FA(let pendingToken, let methods, let masked):
                    self.pendingLoginToken = pendingToken
                    self.twoFactorMethods = methods
                    self.maskedEmail = masked
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        self.is2FAMode = true
                    }

                case .requiresCaptcha(let challengeToken, _, let target):
                    self.captchaRequired = true
                    self.captchaVerified = false
                    self.captchaVerificationToken = nil
                    // Automatisch Challenge lösen
                    self.captchaLoading = true
                    Task {
                        let res = await AuthService.shared.verifyCaptcha(serverURL: serverURL, challengeToken: challengeToken, target: target)
                        await MainActor.run {
                            self.captchaLoading = false
                            if res.success, let vToken = res.token {
                                self.captchaVerified = true
                                self.captchaVerificationToken = vToken
                            }
                        }
                    }

                case .failure(let reason):
                    self.errorMessage = reason
                }
            }
        }
    }
}
