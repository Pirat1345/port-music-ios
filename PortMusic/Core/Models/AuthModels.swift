import Foundation

public struct UserProfile: Codable, Identifiable, Equatable {
    public let id: String
    public let username: String
    public let email: String?
    public let role: String?
    public let createdAt: String?
    public let avatar: String?

    enum CodingKeys: String, CodingKey {
        case id, userId, user_id
        case username
        case email
        case role
        case createdAt, created_at
        case avatar, picture, avatarUrl, avatar_url
    }

    public init(
        id: String,
        username: String,
        email: String? = nil,
        role: String? = nil,
        createdAt: String? = nil,
        avatar: String? = nil
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.role = role
        self.createdAt = createdAt
        self.avatar = avatar
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var decodedId = try? container.decode(String.self, forKey: .id)
        if decodedId == nil {
            decodedId = try? container.decode(String.self, forKey: .userId)
        }
        if decodedId == nil {
            decodedId = try? container.decode(String.self, forKey: .user_id)
        }
        self.id = decodedId ?? UUID().uuidString

        self.username = (try? container.decode(String.self, forKey: .username)) ?? "Benutzer"
        self.email = try? container.decodeIfPresent(String.self, forKey: .email)
        self.role = try? container.decodeIfPresent(String.self, forKey: .role)

        var created = try? container.decodeIfPresent(String.self, forKey: .createdAt)
        if created == nil {
            created = try? container.decodeIfPresent(String.self, forKey: .created_at)
        }
        self.createdAt = created

        var av = try? container.decodeIfPresent(String.self, forKey: .avatar)
        if av == nil {
            av = try? container.decodeIfPresent(String.self, forKey: .picture)
        }
        if av == nil {
            av = try? container.decodeIfPresent(String.self, forKey: .avatarUrl)
        }
        if av == nil {
            av = try? container.decodeIfPresent(String.self, forKey: .avatar_url)
        }
        self.avatar = av
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(avatar, forKey: .avatar)
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
