import SwiftUI

public struct CaptchaChallengeSheetView: View {
    public let serverURL: String
    public let challengeToken: String
    public let captchaType: String
    public let targetId: String
    public let onSuccess: (String) -> Void
    public let onCancel: () -> Void

    public init(
        serverURL: String,
        challengeToken: String,
        captchaType: String = "claw",
        targetId: String = "duck",
        onSuccess: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.serverURL = serverURL
        self.challengeToken = challengeToken
        self.captchaType = captchaType
        self.targetId = targetId
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }

    public var body: some View {
        CaptchaChallengeContainerView(
            serverURL: serverURL,
            initialChallengeToken: challengeToken,
            initialCaptchaType: captchaType,
            initialTarget: targetId,
            onSuccess: onSuccess,
            onCancel: onCancel
        )
    }
}
