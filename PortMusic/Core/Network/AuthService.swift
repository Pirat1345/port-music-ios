import Foundation

public enum LoginResult {
    case success(user: UserProfile, token: String?)
    case requires2FA(pendingToken: String, methods: [String], maskedEmail: String?)
    case requiresCaptcha(challengeToken: String, captchaType: String?, target: String?)
    case failure(reason: String)
}

public final class AuthService {
    public static let shared = AuthService()
    private init() {}

    private let tokenKey = "portmusic_auth_token"
    private let userKey = "portmusic_auth_user"

    public var currentToken: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    public var currentUser: UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: userKey) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    public func saveSession(user: UserProfile, token: String?) {
        if let token = token, !token.isEmpty {
            UserDefaults.standard.set(token, forKey: tokenKey)
        }
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    public func clearSession() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    // MARK: - Captcha Status Abfrage
    public func fetchCaptchaStatus(serverURL: String) async -> Bool {
        let base = ServerPingService.normalize(rawInput: serverURL)
        guard let url = URL(string: "\(base)/api/auth/captcha/status") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("PortMusic-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let session = URLSession(configuration: .ephemeral)
        do {
            let (data, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let required = json["required"] as? Bool {
                    return required
                }
            }
        } catch {
            return false
        }
        return false
    }

    // MARK: - Captcha Challenge anfordern
    public func fetchCaptchaChallenge(serverURL: String) async -> CaptchaChallengeResponse? {
        let base = ServerPingService.normalize(rawInput: serverURL)
        guard let url = URL(string: "\(base)/api/auth/captcha/challenge") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("PortMusic-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = "{}".data(using: .utf8)

        let session = URLSession(configuration: .ephemeral)
        do {
            let (data, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                return try? JSONDecoder().decode(CaptchaChallengeResponse.self, from: data)
            }
        } catch {
            return nil
        }
        return nil
    }

    // MARK: - Captcha Verifizierung
    public func verifyCaptcha(serverURL: String, challengeToken: String, target: String? = nil) async -> (success: Bool, token: String?) {
        let base = ServerPingService.normalize(rawInput: serverURL)
        guard let url = URL(string: "\(base)/api/auth/captcha/verify") else {
            return (false, nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("PortMusic-iOS/1.0", forHTTPHeaderField: "User-Agent")

        var solutionDict: [String: Any] = ["verified": true]
        if let t = target {
            solutionDict["target"] = t
            solutionDict["picked"] = t
        }

        let body: [String: Any] = [
            "challengeToken": challengeToken,
            "solution": solutionDict
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return (false, nil)
        }
        request.httpBody = httpBody

        let session = URLSession(configuration: .ephemeral)
        do {
            let (data, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let vToken = json["verificationToken"] as? String {
                    return (true, vToken)
                }
            }
            return (false, nil)
        } catch {
            return (false, nil)
        }
    }

    // MARK: - Login
    public func login(
        serverURL: String,
        username: String,
        password: String,
        captchaToken: String? = nil
    ) async -> LoginResult {
        let base = ServerPingService.normalize(rawInput: serverURL)
        guard let url = URL(string: "\(base)/api/login") else {
            return .failure(reason: "Ungültige Server-URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("PortMusic-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("iPhone", forHTTPHeaderField: "X-Device-Model")

        var body: [String: Any] = [
            "email": username.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password
        ]
        if let ct = captchaToken, !ct.isEmpty {
            body["captchaVerificationToken"] = ct
        }

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return .failure(reason: "Anfrage konnte nicht erstellt werden.")
        }
        request.httpBody = httpBody

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10.0
        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(reason: "Ungültige Server-Antwort.")
            }

            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

            // 1. 2FA Prüfung
            let requiresVerification = (json["requiresVerification"] as? Bool) ?? (json["requires2FA"] as? Bool) ?? false
            if requiresVerification, let pendingToken = json["pendingLoginToken"] as? String {
                let methods = (json["methods"] as? [String]) ?? ["totp"]
                let masked = json["maskedEmail"] as? String
                return .requires2FA(pendingToken: pendingToken, methods: methods, maskedEmail: masked)
            }

            // 2. Captcha Prüfung
            if let reqCaptcha = json["requiresCaptcha"] as? Bool, reqCaptcha {
                let challenge = (json["challengeToken"] as? String) ?? ""
                let cType = json["captchaType"] as? String
                let target = json["target"] as? String
                return .requiresCaptcha(challengeToken: challenge, captchaType: cType, target: target)
            }

            // 3. Erfolgreiche Anmeldung (200..299)
            if (200...299).contains(httpResponse.statusCode) {
                let userId = (json["userId"] as? String) ?? (json["id"] as? String) ?? UUID().uuidString
                let uname = (json["username"] as? String) ?? username
                let role = (json["role"] as? String) ?? "user"
                let email = json["email"] as? String
                let createdAt = json["createdAt"] as? String
                let token = json["token"] as? String

                let profile = UserProfile(
                    id: userId,
                    username: uname,
                    email: email,
                    role: role,
                    createdAt: createdAt
                )
                saveSession(user: profile, token: token)
                return .success(user: profile, token: token)
            }

            // 4. Fehlermeldung
            let msg = (json["message"] as? String) ?? (json["error"] as? String) ?? "Ungültige Anmeldedaten."
            return .failure(reason: msg)
        } catch {
            return .failure(reason: "Verbindung zum Server fehlgeschlagen. Bitte Netzwerk überprüfen.")
        }
    }

    // MARK: - 2FA Code Überprüfung
    public func verify2FA(
        serverURL: String,
        pendingToken: String,
        code: String,
        method: String // "totp" oder "email"
    ) async -> LoginResult {
        let base = ServerPingService.normalize(rawInput: serverURL)
        guard let url = URL(string: "\(base)/api/login") else {
            return .failure(reason: "Ungültige Server-URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("PortMusic-iOS/1.0", forHTTPHeaderField: "User-Agent")

        var body: [String: Any] = [
            "pendingLoginToken": pendingToken
        ]
        if method == "email" {
            body["emailCode"] = code.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            body["totpCode"] = code.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return .failure(reason: "Anfrage konnte nicht erstellt werden.")
        }
        request.httpBody = httpBody

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10.0
        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(reason: "Ungültige Server-Antwort.")
            }

            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

            if (200...299).contains(httpResponse.statusCode) {
                let userId = (json["userId"] as? String) ?? UUID().uuidString
                let uname = (json["username"] as? String) ?? "Benutzer"
                let role = (json["role"] as? String) ?? "user"
                let email = json["email"] as? String
                let createdAt = json["createdAt"] as? String
                let token = json["token"] as? String

                let profile = UserProfile(
                    id: userId,
                    username: uname,
                    email: email,
                    role: role,
                    createdAt: createdAt
                )
                saveSession(user: profile, token: token)
                return .success(user: profile, token: token)
            }

            let msg = (json["message"] as? String) ?? (json["error"] as? String) ?? "Bestätigungscode ist ungültig."
            return .failure(reason: msg)
        } catch {
            return .failure(reason: "Verbindung fehlgeschlagen.")
        }
    }

    // MARK: - E-Mail Login-Code anfordern
    public func sendEmailCode(serverURL: String, pendingToken: String) async -> (success: Bool, message: String) {
        let base = ServerPingService.normalize(rawInput: serverURL)
        guard let url = URL(string: "\(base)/api/auth/send-login-code") else {
            return (false, "Ungültige Server-URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["pendingLoginToken": pendingToken]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return (false, "Anfrage konnte nicht erstellt werden.")
        }
        request.httpBody = httpBody

        let session = URLSession(configuration: .ephemeral)
        do {
            let (data, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                let masked = (json["maskedEmail"] as? String) ?? "deine E-Mail-Adresse"
                return (true, "Code wurde an \(masked) gesendet.")
            }
            return (false, "E-Mail-Code konnte nicht gesendet werden.")
        } catch {
            return (false, "Verbindung zum Server fehlgeschlagen.")
        }
    }
}
