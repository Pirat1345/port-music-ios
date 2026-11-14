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

public enum LoginResult: Equatable {
    case success(user: UserProfile, token: String?)
    case requires2FA(pendingToken: String, methods: [String], maskedEmail: String?)
    case requiresCaptcha(challengeToken: String, captchaType: String?, target: String?)
    case failure(reason: String)
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

public struct CaptchaChallengeRequest: Codable {
    public let preferredType: String?
    public let failedBefore: Bool?

    public init(preferredType: String? = nil, failedBefore: Bool? = nil) {
        self.preferredType = preferredType
        self.failedBefore = failedBefore
    }
}

public struct CaptchaSolution: Codable {
    public let verified: Bool
    public let picked: String?
    public let clumpsRemaining: Int?

    public init(verified: Bool, picked: String? = nil, clumpsRemaining: Int? = nil) {
        self.verified = verified
        self.picked = picked
        self.clumpsRemaining = clumpsRemaining
    }
}

public struct CaptchaChallengeResponse: Codable {
    public let challengeToken: String?
    public let type: String?
    public let captchaType: String?
    public let target: String?

    public init(challengeToken: String?, type: String? = nil, captchaType: String? = nil, target: String? = nil) {
        self.challengeToken = challengeToken
        self.type = type
        self.captchaType = captchaType
        self.target = target
    }

    public var effectiveType: String {
        return captchaType ?? type ?? "claw"
    }
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
