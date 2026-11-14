import Foundation

public struct UserProfile: Codable, Identifiable, Equatable {
    public let id: String
    public let username: String
    public let email: String?
    public let role: String?
    public let createdAt: String?

    public init(id: String, username: String, email: String? = nil, role: String? = nil, createdAt: String? = nil) {
        self.id = id
        self.username = username
        self.email = email
        self.role = role
        self.createdAt = createdAt
    }
}

public struct LoginResponseData: Codable {
    public let token: String?
    public let user: UserProfile?
    public let requires2FA: Bool?
    public let pendingLoginToken: String?
    public let twoFactorMethods: [String]?
    public let maskedEmail: String?
    public let requiresCaptcha: Bool?
    public let challengeToken: String?
    public let captchaType: String?
    public let target: String?
    public let message: String?
    public let error: String?
}

public struct CaptchaStatusResponse: Codable {
    public let required: Bool?
    public let enabled: Bool?
}

public struct CaptchaChallengeResponse: Codable {
    public let challengeToken: String?
    public let type: String?
    public let captchaType: String?
    public let target: String?
}

public struct CaptchaVerifyResponse: Codable {
    public let success: Bool?
    public let verificationToken: String?
    public let error: String?
    public let message: String?
}

public struct HealthResponse: Codable {
    public let status: String?
    public let version: String?
}
