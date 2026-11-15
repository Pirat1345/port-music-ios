import SwiftUI

public struct CaptchaChallengeContainerView: View {
    public let serverURL: String
    public let initialChallengeToken: String?
    public let initialCaptchaType: String?
    public let initialTarget: String?
    public let onSuccess: (String) -> Void
    public let onCancel: () -> Void

    @State private var challengeToken: String = ""
    @State private var currentCaptchaType: String = "claw"
    @State private var targetToy: String = "duck"

    @State private var isLoading: Bool = false
    @State private var isVerifying: Bool = false
    @State private var errorMessage: String? = nil
    @State private var failureCount: Int = 0

    public init(
        serverURL: String,
        initialChallengeToken: String? = nil,
        initialCaptchaType: String? = nil,
        initialTarget: String? = nil,
        onSuccess: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.serverURL = serverURL
        self.initialChallengeToken = initialChallengeToken
        self.initialCaptchaType = initialCaptchaType
        self.initialTarget = initialTarget
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            FluentBackgroundView()

            VStack(spacing: 0) {
                // Top Navigation Bar
                topBarView
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                // Error Banner if present
                if let err = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(PortColors.errorRed)

                        Text(err)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(PortColors.textPrimary)

                        Spacer()

                        Button(action: { errorMessage = nil }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12))
                                .foregroundColor(PortColors.textMuted)
                        }
                    }
                    .padding(12)
                    .background(PortColors.errorRed.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(PortColors.errorRed.opacity(0.35), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }

                // Fallback / Type Switcher Banner (if repeated failure or user choice)
                if failureCount >= 2 {
                    fallbackPromptView
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                // Main Challenge Content Area
                ZStack {
                    if isLoading {
                        VStack(spacing: 14) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            Text("Sicherheitsaufgabe wird geladen...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(PortColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if currentCaptchaType == "litter" {
                        LitterCaptchaView(
                            onVerify: { solution in
                                handleLitterSolution(solution)
                            },
                            onFail: {
                                handleFailure()
                            },
                            onReset: {
                                loadFreshChallenge(preferredType: "litter")
                            }
                        )
                        .id("litter-\(challengeToken)")
                    } else {
                        ClawMachineView(
                            targetId: targetToy,
                            onVerify: { pickedToy in
                                handleClawSolution(pickedToy: pickedToy)
                            },
                            onFail: {
                                handleFailure()
                            }
                        )
                        .id("claw-\(challengeToken)-\(targetToy)")
                    }

                    // Verification Overlay
                    if isVerifying {
                        ZStack {
                            Color.black.opacity(0.65)
                                .ignoresSafeArea()

                            VStack(spacing: 14) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.3)

                                Text("Verifizierung läuft...")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(28)
                            .background(PortColors.surfaceGlassStrong)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(PortColors.borderGlass, lineWidth: 1.5)
                            )
                        }
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            initializeChallenge()
        }
    }

    // MARK: - Top Navigation Bar
    private var topBarView: some View {
        HStack {
            // Modus-Badge (ohne umbrechende Überschrift)
            HStack(spacing: 6) {
                Image(systemName: currentCaptchaType == "litter" ? "sparkles" : "arcade.stick.console")
                    .font(.system(size: 13, weight: .semibold))
                Text(currentCaptchaType == "litter" ? "Partikel-Muster" : "Greifarm")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(PortColors.surfaceGlass)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(PortColors.borderGlass, lineWidth: 1)
            )

            Spacer()

            // Reload Button ("Neue Aufgabe")
            Button(action: {
                loadFreshChallenge(preferredType: currentCaptchaType)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Neue Aufgabe")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(PortColors.surfaceGlass)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(PortColors.borderGlass, lineWidth: 1)
                )
            }
            .disabled(isLoading || isVerifying)

            // Close Button
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }
            .padding(.leading, 6)
        }
    }

    // MARK: - Fallback Switcher Banner
    private var fallbackPromptView: some View {
        HStack {
            Image(systemName: "questionmark.circle.fill")
                .foregroundColor(Color(hex: "#ffd60a"))

            Text("Schwierigkeiten?")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button(action: {
                let nextType = (currentCaptchaType == "claw") ? "litter" : "claw"
                loadFreshChallenge(preferredType: nextType)
            }) {
                Text(currentCaptchaType == "claw" ? "Zu Partikel-Muster wechseln" : "Zum Greifarm wechseln")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#ffd60a"))
                    .underline()
            }
        }
        .padding(10)
        .background(Color(hex: "#ffd60a").opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Initialization & Challenge Fetch
    private func initializeChallenge() {
        if let token = initialChallengeToken, !token.isEmpty {
            self.challengeToken = token
            self.currentCaptchaType = initialCaptchaType ?? "claw"
            self.targetToy = initialTarget ?? "duck"
        } else {
            loadFreshChallenge()
        }
    }

    private func loadFreshChallenge(preferredType: String? = nil) {
        isLoading = true
        errorMessage = nil

        Task {
            let pref = preferredType ?? currentCaptchaType
            let failedBefore = (failureCount > 0)
            let response = await AuthService.shared.fetchCaptchaChallenge(
                serverURL: serverURL,
                preferredType: pref,
                failedBefore: failedBefore
            )

            await MainActor.run {
                isLoading = false
                if let res = response, let token = res.challengeToken {
                    self.challengeToken = token
                    self.currentCaptchaType = res.effectiveType
                    self.targetToy = res.target ?? "duck"
                } else {
                    self.errorMessage = "Sicherheitsaufgabe konnte nicht geladen werden. Bitte versuche es erneut."
                }
            }
        }
    }

    // MARK: - Solution Verification
    private func handleClawSolution(pickedToy: String) {
        guard !isVerifying else { return }
        isVerifying = true
        errorMessage = nil

        Task {
            let res = await AuthService.shared.verifyCaptcha(
                serverURL: serverURL,
                challengeToken: challengeToken,
                picked: pickedToy,
                clumpsRemaining: nil
            )

            await MainActor.run {
                isVerifying = false
                if res.success, let vToken = res.token {
                    // Success!
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onSuccess(vToken)
                    }
                } else {
                    handleFailure()
                    self.errorMessage = res.error ?? "Verifizierung fehlgeschlagen. Bitte erneut versuchen."
                    loadFreshChallenge()
                }
            }
        }
    }

    private func handleLitterSolution(_ solution: CaptchaSolution) {
        guard !isVerifying else { return }
        isVerifying = true
        errorMessage = nil

        Task {
            let res = await AuthService.shared.verifyCaptcha(
                serverURL: serverURL,
                challengeToken: challengeToken,
                picked: nil,
                clumpsRemaining: solution.clumpsRemaining ?? 0
            )

            await MainActor.run {
                isVerifying = false
                if res.success, let vToken = res.token {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onSuccess(vToken)
                    }
                } else {
                    handleFailure()
                    self.errorMessage = res.error ?? "Verifizierung fehlgeschlagen. Bitte erneut versuchen."
                    loadFreshChallenge()
                }
            }
        }
    }

    private func handleFailure() {
        failureCount += 1
    }
}
