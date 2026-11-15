import SwiftUI

public struct LoginView: View {
    public let serverURL: String
    public let onLoginSuccess: (UserProfile) -> Void
    public let onChangeServer: () -> Void

    @ObservedObject private var sessionManager = SessionManager.shared

    @State private var usernameInput: String = ""
    @State private var passwordInput: String = ""
    @State private var showPassword: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil

    // Captcha-Zustand
    @State private var captchaRequired: Bool = false
    @State private var captchaLoading: Bool = false
    @State private var captchaVerified: Bool = false
    @State private var captchaVerificationToken: String? = nil

    // Captcha-Modal
    @State private var showCaptchaModal: Bool = false
    @State private var activeChallengeToken: String = ""
    @State private var activeCaptchaType: String = "claw"
    @State private var activeTargetToy: String = "duck"

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

    private var activeServerURL: String {
        if !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return serverURL
        }
        return sessionManager.serverURL ?? ""
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            // Fluent Animated Seiden-Hintergrund
            FluentBackgroundView()

            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: is2FAMode ? 24 : 12)

                        if is2FAMode {
                            TwoFactorView(
                                serverURL: activeServerURL,
                                pendingToken: pendingLoginToken,
                                availableMethods: twoFactorMethods,
                                maskedEmail: maskedEmail,
                                onVerificationSuccess: { user, token in
                                    sessionManager.loginSuccess(
                                        user: user,
                                        token: token ?? "",
                                        serverURL: activeServerURL
                                    )
                                    onLoginSuccess(user)
                                },
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

                        Spacer(minLength: is2FAMode ? 32 : 24)
                    }
                    .frame(maxWidth: 440)
                    .frame(minHeight: geometry.size.height)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 24)
                    .padding(.top, 44)
                }
            }

            // Server-Button: Immer fest in der oberen rechten Ecke
            serverHeaderBadge
                .padding(.top, 16)
                .padding(.trailing, 24)
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .onAppear {
            checkCaptchaStatus()
        }
        .sheet(isPresented: $showCaptchaModal) {
            CaptchaChallengeContainerView(
                serverURL: activeServerURL,
                initialChallengeToken: activeChallengeToken,
                initialCaptchaType: activeCaptchaType,
                initialTarget: activeTargetToy,
                onSuccess: { token in
                    showCaptchaModal = false
                    captchaVerified = true
                    captchaVerificationToken = token
                    errorMessage = nil
                    // Nur automatisch anmelden, falls Anmeldedaten bereits eingetragen sind
                    let hasCreds = !usernameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && !passwordInput.isEmpty
                    if hasCreds {
                        performLogin(withCaptchaToken: token)
                    }
                },
                onCancel: {
                    showCaptchaModal = false
                    captchaLoading = false
                }
            )
        }
    }

    // MARK: - Dezenter Server-Indikator
    private var serverHeaderBadge: some View {
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
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(PortColors.surfaceGlass)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(PortColors.borderGlass, lineWidth: 1)
            )
        }
    }

    private var shortHostName: String {
        let clean = activeServerURL
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

                    Text("Melden Sie sich mit Ihrem Benutzerkonto an.")
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
                        .foregroundColor(.white)
                        .tracking(1.2)

                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.white)

                        TextField(
                            "",
                            text: $usernameInput,
                            prompt: Text("Benutzername oder E-Mail")
                                .foregroundColor(Color.white.opacity(0.60))
                        )
                            .font(.system(size: 15))
                            .foregroundColor(PortColors.textPrimary)
                            .tint(.white)
                            .accentColor(.white)
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
                        .foregroundColor(.white)
                        .tracking(1.2)

                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.white)

                        if showPassword {
                            TextField(
                                "",
                                text: $passwordInput,
                                prompt: Text("Passwort")
                                    .foregroundColor(Color.white.opacity(0.60))
                            )
                                .font(.system(size: 15))
                                .foregroundColor(PortColors.textPrimary)
                                .tint(.white)
                                .accentColor(.white)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField(
                                "",
                                text: $passwordInput,
                                prompt: Text("Passwort")
                                    .foregroundColor(Color.white.opacity(0.60))
                            )
                                .font(.system(size: 15))
                                .foregroundColor(PortColors.textPrimary)
                                .tint(.white)
                                .accentColor(.white)
                        }

                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.white)
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

                // Captcha-Feld
                if captchaRequired {
                    CaptchaWidgetView(
                        isVerified: captchaVerified,
                        isLoading: captchaLoading,
                        onCheckboxTapped: openInteractiveCaptcha
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
            Button(action: { performLogin() }) {
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
            let required = await AuthService.shared.fetchCaptchaStatus(serverURL: activeServerURL)
            await MainActor.run {
                if required {
                    self.captchaRequired = true
                }
            }
        }
    }

    private func openInteractiveCaptcha() {
        captchaLoading = true
        errorMessage = nil

        Task {
            guard let challenge = await AuthService.shared.fetchCaptchaChallenge(serverURL: activeServerURL),
                  let token = challenge.challengeToken else {
                await MainActor.run {
                    captchaLoading = false
                    errorMessage = "Sicherheitsabfrage konnte nicht geladen werden."
                }
                return
            }

            await MainActor.run {
                captchaLoading = false
                self.activeChallengeToken = token
                self.activeCaptchaType = challenge.effectiveType
                self.activeTargetToy = challenge.target ?? "duck"
                self.showCaptchaModal = true
            }
        }
    }

    private func performLogin(withCaptchaToken tokenOverride: String? = nil) {
        let hasCreds = !usernameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !passwordInput.isEmpty
        guard hasCreds else { return }
        if captchaRequired && !captchaVerified && tokenOverride == nil { return }
        isSubmitting = true
        errorMessage = nil

        let tokenToUse = tokenOverride ?? captchaVerificationToken

        Task {
            let result = await AuthService.shared.login(
                serverURL: activeServerURL,
                username: usernameInput,
                password: passwordInput,
                captchaToken: tokenToUse
            )

            await MainActor.run {
                isSubmitting = false
                switch result {
                case .success(let user, let token):
                    sessionManager.loginSuccess(
                        user: user,
                        token: token ?? "",
                        serverURL: activeServerURL
                    )
                    onLoginSuccess(user)

                case .requires2FA(let pendingToken, let methods, let masked):
                    self.pendingLoginToken = pendingToken
                    self.twoFactorMethods = methods
                    self.maskedEmail = masked
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        self.is2FAMode = true
                    }

                case .requiresCaptcha(let challengeToken, let cType, let target):
                    self.captchaRequired = true
                    self.captchaVerified = false
                    self.captchaVerificationToken = nil
                    self.activeChallengeToken = challengeToken
                    self.activeCaptchaType = cType ?? "claw"
                    self.activeTargetToy = target ?? "duck"
                    self.showCaptchaModal = true

                case .failure(let reason):
                    self.errorMessage = reason
                }
            }
        }
    }
}
