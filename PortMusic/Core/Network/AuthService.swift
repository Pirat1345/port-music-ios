import Foundation

public enum AuthError: LocalizedError, Equatable {
    case invalidCredentials(String)
    case unauthorized
    case sessionExpired
    case tooManyAttempts
    case invalidCode
    case captchaRequired
    case networkError(String)
    case serverError(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials(let msg):
            return msg.isEmpty ? "Ungültige Anmeldedaten. Bitte überprüfen Sie Benutzername und Passwort." : msg
        case .unauthorized:
            return "Nicht autorisiert. Bitte melden Sie sich an."
        case .sessionExpired:
            return "Die Sitzung ist abgelaufen. Bitte melden Sie sich erneut an."
        case .tooManyAttempts:
            return "Zu viele fehlgeschlagene Versuche. Bitte warten Sie einen Moment."
        case .invalidCode:
            return "Der eingegebene Code ist ungültig."
        case .captchaRequired:
            return "Menschliche Verifizierung erforderlich."
        case .networkError(let msg):
            return msg.isEmpty ? "Verbindung zum Server fehlgeschlagen. Bitte überprüfen Sie die Server-Adresse und Ihre Internetverbindung." : msg
        case .serverError(let msg):
            return msg.isEmpty ? "Ein Serverfehler ist aufgetreten. Bitte versuchen Sie es später erneut." : msg
        case .unknown(let msg):
            return msg.isEmpty ? "Ein unerwarteter Fehler ist aufgetreten." : msg
        }
    }
}

public struct LoginRequestPayload: Codable {
    public var email: String?
    public var password: String?
    public var visitorId: String?
    public var deviceName: String?
    public var captchaVerificationToken: String?
    public var pendingLoginToken: String?
    public var emailCode: String?
    public var totpCode: String?

    public init(
        email: String? = nil,
        password: String? = nil,
        visitorId: String? = nil,
        deviceName: String? = nil,
        captchaVerificationToken: String? = nil,
        pendingLoginToken: String? = nil,
        emailCode: String? = nil,
        totpCode: String? = nil
    ) {
        self.email = email
        self.password = password
        self.visitorId = visitorId
        self.deviceName = deviceName
        self.captchaVerificationToken = captchaVerificationToken
        self.pendingLoginToken = pendingLoginToken
        self.emailCode = emailCode
        self.totpCode = totpCode
    }

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let email = email {
            dict["email"] = email
        }
        if let password = password {
            dict["password"] = password
        }
        if let visitorId = visitorId {
            dict["visitorId"] = visitorId
        }
        if let deviceName = deviceName {
            dict["deviceName"] = deviceName
        }
        if let captchaVerificationToken = captchaVerificationToken {
            dict["captchaVerificationToken"] = captchaVerificationToken
        }
        if let pendingLoginToken = pendingLoginToken {
            dict["pendingLoginToken"] = pendingLoginToken
        }
        if let emailCode = emailCode {
            dict["emailCode"] = emailCode
        }
        if let totpCode = totpCode {
            dict["totpCode"] = totpCode
        }
        return dict
    }
}

public final class AuthService {
    public static let shared = AuthService()
    private init() {}

    private let tokenKey = "portmusic_auth_token"
    private let userKey = "portmusic_auth_user"
    private let deviceIdKey = "portmusic_device_id"
    private let visitorIdKey = "portmusic_visitor_id"

    public var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey) {
            return existing
        }
        let generated = "pm-ios-" + UUID().uuidString.lowercased()
        UserDefaults.standard.set(generated, forKey: deviceIdKey)
        return generated
    }

    public var visitorId: String {
        if let existing = UserDefaults.standard.string(forKey: visitorIdKey) {
            return existing
        }
        let generated = "vis-" + UUID().uuidString.lowercased()
        UserDefaults.standard.set(generated, forKey: visitorIdKey)
        return generated
    }

    public var currentToken: String? {
        KeychainHelper.shared.getToken() ?? UserDefaults.standard.string(forKey: tokenKey)
    }

    public var currentUser: UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: userKey) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    public func saveSession(user: UserProfile, token: String?) {
        if let token = token, !token.isEmpty {
            KeychainHelper.shared.saveToken(token)
            UserDefaults.standard.set(token, forKey: tokenKey)
        }
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    public func clearSession() {
        KeychainHelper.shared.deleteToken()
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    // MARK: - HTTP Request Vorbereitung

    private func makeRequest(
        url: URL,
        method: String,
        token: String? = nil,
        bodyData: Data? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("PortMusic-iOS", forHTTPHeaderField: "User-Agent")
        request.setValue("iPhone", forHTTPHeaderField: "X-Device-Model")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        request.setValue(visitorId, forHTTPHeaderField: "X-Visitor-ID")

        if let token = token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let bodyData = bodyData {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
        }

        return request
    }

    // MARK: - Fehler-Zuordnung

    public static func mapGermanError(code: String?, message: String?) -> String {
        let codeUpper = (code ?? "").uppercased()
        let msgUpper = (message ?? "").uppercased()
        let combined = "\(codeUpper) \(msgUpper)"

        if combined.contains("INVALID_CREDENTIALS") || combined.contains("INVALID USERNAME OR PASSWORD") {
            return "Ungültige Anmeldedaten. Bitte überprüfen Sie Benutzername und Passwort."
        }
        if combined.contains("TOO_MANY_ATTEMPTS") || combined.contains("TOO MANY") {
            return "Zu viele fehlgeschlagene Versuche. Bitte warten Sie einen Moment."
        }
        if combined.contains("PENDING_TOKEN_EXPIRED") || combined.contains("INVALID_PENDING_TOKEN") || combined.contains("TOKEN EXPIRED") {
            return "Die Sitzung ist abgelaufen. Bitte melden Sie sich erneut an."
        }
        if combined.contains("INVALID_CODE") || combined.contains("WRONG CODE") {
            return "Der eingegebene Code ist ungültig."
        }
        if combined.contains("CAPTCHA_REQUIRED") || combined.contains("REQUIRES_CAPTCHA") || combined.contains("VERIFIZIERUNG ERFORDERLICH") {
            return "Menschliche Verifizierung erforderlich."
        }
        if combined.contains("RATE_LIMITED") || combined.contains("COOLDOWN") {
            return "Bitte warten Sie vor dem erneuten Senden des Codes."
        }
        if let msg = message, !msg.isEmpty {
            return msg
        }
        if let cd = code, !cd.isEmpty {
            return cd
        }
        return "Ungültige Anmeldedaten. Bitte überprüfen Sie Benutzername und Passwort."
    }

    // MARK: - 1. Sitzungsprüfung (GET /api/auth/check)

    public func checkAuth(serverURL: String, token: String) async throws -> UserProfile {
        let base = ServerPingService.normalize(rawInput: serverURL)
        guard let url = URL(string: "\(base)/api/auth/check") else {
            throw AuthError.networkError("Ungültige Server-Adresse.")
        }

        let request = makeRequest(url: url, method: "GET", token: token)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10.0
        let session = URLSession(configuration: config)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.networkError("Verbindung zum Server fehlgeschlagen. Bitte überprüfen Sie die Server-Adresse und Ihre Internetverbindung.")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.serverError("Ungültige Antwort vom Server erhalten.")
        }

        if httpResponse.statusCode == 401 {
            throw AuthError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let err = json["error"] as? String
            let msg = json["message"] as? String
            throw AuthError.serverError(Self.mapGermanError(code: err, message: msg))
        }

        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let authenticated = (json["authenticated"] as? Bool) ?? false
        guard authenticated else {
            throw AuthError.unauthorized
        }

        if let userObj = json["user"] as? [String: Any] {
            let userId = (userObj["userId"] as? String) ?? (userObj["id"] as? String) ?? UUID().uuidString
            let username = (userObj["username"] as? String) ?? "Benutzer"
            let email = userObj["email"] as? String
            let role = userObj["role"] as? String
            let createdAt = userObj["createdAt"] as? String

            return UserProfile(
                id: userId,
                username: username,
                email: email,
                role: role,
                createdAt: createdAt
            )
        }

        throw AuthError.serverError("Benutzerprofil konnte nicht gelesen werden.")
    }

    // MARK: - 2. Login (POST /api/login)

    public func login(
        serverURL: String,
        request payload: LoginRequestPayload
    ) async throws -> LoginResult {
        let base = ServerPingService.normalize(rawInput: serverURL)
        guard let url = URL(string: "\(base)/api/login") else {
            throw AuthError.networkError("Ungültige Server-Adresse.")
        }

        var dict = payload.toDictionary()
        if dict["visitorId"] == nil {
            dict["visitorId"] = visitorId
        }
        if dict["deviceName"] == nil {
            dict["deviceName"] = "iPhone"
        }

        guard let httpBody = try? JSONSerialization.data(withJSONObject: dict) else {
            throw AuthError.serverError("Anfrage konnte nicht erstellt werden.")
        }

        let request = makeRequest(url: url, method: "POST", bodyData: httpBody)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12.0
        let session = URLSession(configuration: config)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            return .failure(reason: "Verbindung zum Server fehlgeschlagen. Bitte überprüfen Sie die Server-Adresse und Ihre Internetverbindung.")
        }

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

        // 2. Captcha Prüfung (400 Bad Request oder 200 mit requiresCaptcha: true)
        if let reqCaptcha = json["requiresCaptcha"] as? Bool, reqCaptcha {
            let challenge = (json["challengeToken"] as? String) ?? ""
            let cType = json["captchaType"] as? String ?? json["type"] as? String
            let target = json["target"] as? String
            return .requiresCaptcha(challengeToken: challenge, captchaType: cType, target: target)
        }

        // 3. Erfolgreiche Anmeldung (200..299)
        if (200...299).contains(httpResponse.statusCode) {
            let userObj = json["user"] as? [String: Any]
            let userId = (userObj?["userId"] as? String) ?? (userObj?["id"] as? String) ?? (json["userId"] as? String) ?? UUID().uuidString
            let uname = (userObj?["username"] as? String) ?? (json["username"] as? String) ?? payload.email ?? "Benutzer"
            let role = (userObj?["role"] as? String) ?? (json["role"] as? String) ?? "user"
            let email = (userObj?["email"] as? String) ?? (json["email"] as? String)
            let createdAt = (userObj?["createdAt"] as? String) ?? (json["createdAt"] as? String)
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
        let errCode = json["error"] as? String
        let errMsg = json["message"] as? String
        let mapped = Self.mapGermanError(code: errCode, message: errMsg)
        return .failure(reason: mapped)
    }

    // Komfort-Überladung für den bestehenden LoginView-Aufruf
    public func login(
        serverURL: String,
        username: String,
        password: String,
        captchaToken: String? = nil
    ) async -> LoginResult {
        let payload = LoginRequestPayload(
            email: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            visitorId: visitorId,
            deviceName: "iPhone",
            captchaVerificationToken: captchaToken
        )
        do {
            return try await login(serverURL: serverURL, request: payload)
        } catch {
            return .failure(reason: error.localizedDescription)
        }
    }

    // MARK: - 3. 2FA Code Verifizierung (POST /api/login und /api/auth/verify-2fa)

    public func verify2FA(
        serverURL: String,
        pendingLoginToken: String,
        code: String,
        isTotp: Bool
    ) async throws -> LoginResult {
        let payload = LoginRequestPayload(
            visitorId: visitorId,
            deviceName: "iPhone",
            pendingLoginToken: pendingLoginToken,
            emailCode: isTotp ? nil : code.trimmingCharacters(in: .whitespacesAndNewlines),
            totpCode: isTotp ? code.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        )

        return try await login(serverURL: serverURL, request: payload)
    }

    // Überladung mit Methoden-String ("totp" oder "email")
    public func verify2FA(
        serverURL: String,
        pendingToken: String,
        code: String,
        method: String
    ) async -> LoginResult {
        let isTotp = (method.lowercased() == "totp")
        do {
            return try await verify2FA(
                serverURL: serverURL,
                pendingLoginToken: pendingToken,
                code: code,
                isTotp: isTotp
            )
        } catch {
            return .failure(reason: error.localizedDescription)
        }
    }

    // MARK: - 4. 2FA Login-Code anfordern (POST /api/auth/send-login-code)

    public func sendLoginCode(
        serverURL: String,
        pendingLoginToken: String
    ) async throws -> String? {
        let base = ServerPingService.normalize(rawInput: serverURL)
        guard let url = URL(string: "\(base)/api/auth/send-login-code") else {
            throw AuthError.networkError("Ungültige Server-Adresse.")
        }

        let bodyDict = [
            "pendingLoginToken": pendingLoginToken
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: bodyDict) else {
            throw AuthError.serverError("Anfrage konnte nicht erstellt werden.")
        }

        let request = makeRequest(url: url, method: "POST", bodyData: bodyData)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10.0
        let session = URLSession(configuration: config)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.networkError("Verbindung zum Server fehlgeschlagen. Bitte überprüfen Sie die Server-Adresse und Ihre Internetverbindung.")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.serverError("Ungültige Server-Antwort.")
        }

        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

        if httpResponse.statusCode == 429 || httpResponse.statusCode == 400 {
            let code = json["error"] as? String
            if code == "RATE_LIMITED" || (json["message"] as? String ?? "").contains("wait") {
                throw AuthError.tooManyAttempts
            }
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let err = json["error"] as? String
            let msg = json["message"] as? String
            throw AuthError.serverError(Self.mapGermanError(code: err, message: msg))
        }

        return json["maskedEmail"] as? String
    }

    // Überladung für TwoFactorView
    public func sendEmailCode(
        serverURL: String,
        pendingToken: String
    ) async -> (success: Bool, message: String) {
        do {
            let masked = try await sendLoginCode(serverURL: serverURL, pendingLoginToken: pendingToken)
            let email = masked ?? "Ihre E-Mail-Adresse"
            return (true, "Code wurde an \(email) gesendet.")
        } catch let authError as AuthError {
            if authError == .tooManyAttempts {
                return (false, "Bitte warten Sie vor dem erneuten Senden des Codes.")
            }
            return (false, authError.localizedDescription)
        } catch {
            return (false, "Verbindung zum Server fehlgeschlagen. Bitte versuchen Sie es erneut.")
        }
    }

    // MARK: - 5. Captcha Status Abfrage (GET /api/auth/captcha/status)

    public func fetchCaptchaStatus(serverURL: String) async -> Bool {
        let base = ServerPingService.normalize(rawInput: serverURL)
        guard let url = URL(string: "\(base)/api/auth/captcha/status") else { return false }

        let request = makeRequest(url: url, method: "GET")
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

    // MARK: - 6. Captcha Challenge anfordern (POST /api/auth/captcha/challenge)

    public func fetchCaptchaChallenge(
        serverURL: String,
        preferredType: String? = nil,
        failedBefore: Bool = false
    ) async -> CaptchaChallengeResponse? {
        let base = ServerPingService.normalize(rawInput: serverURL)
        guard let url = URL(string: "\(base)/api/auth/captcha/challenge") else { return nil }

        let reqObj = CaptchaChallengeRequest(preferredType: preferredType, failedBefore: failedBefore)
        let bodyData = (try? JSONEncoder().encode(reqObj)) ?? "{}".data(using: .utf8)

        let request = makeRequest(url: url, method: "POST", bodyData: bodyData)
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

    // MARK: - 7. Captcha Verifizierung (POST /api/auth/captcha/verify)

    public func verifyCaptcha(
        serverURL: String,
        challengeToken: String,
        picked: String? = nil,
        clumpsRemaining: Int? = nil
    ) async -> (success: Bool, token: String?, error: String?) {
        let base = ServerPingService.normalize(rawInput: serverURL)
        guard let url = URL(string: "\(base)/api/auth/captcha/verify") else {
            return (false, nil, "Ungültige Server-URL.")
        }

        var solutionDict: [String: Any] = ["verified": true]
        if let p = picked {
            solutionDict["target"] = p
            solutionDict["picked"] = p
        }
        if let cr = clumpsRemaining {
            solutionDict["clumpsRemaining"] = cr
        }

        let body: [String: Any] = [
            "challengeToken": challengeToken,
            "solution": solutionDict
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return (false, nil, "Fehler beim Erstellen der Anfrage.")
        }

        let request = makeRequest(url: url, method: "POST", bodyData: httpBody)
        let session = URLSession(configuration: .ephemeral)
        do {
            let (data, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if (200...299).contains(httpRes.statusCode),
                       let vToken = json["verificationToken"] as? String {
                        return (true, vToken, nil)
                    } else {
                        let errCode = json["error"] as? String
                        let errMsg = json["message"] as? String
                        let mapped = Self.mapGermanError(code: errCode, message: errMsg)
                        return (false, nil, mapped)
                    }
                }
            }
            return (false, nil, "Verifizierung fehlgeschlagen.")
        } catch {
            return (false, nil, error.localizedDescription)
        }
    }

    // Abwärtskompatible Methode
    public func verifyCaptcha(
        serverURL: String,
        challengeToken: String,
        target: String? = nil
    ) async -> (success: Bool, token: String?) {
        let res = await verifyCaptcha(serverURL: serverURL, challengeToken: challengeToken, picked: target, clumpsRemaining: nil)
        return (res.success, res.token)
    }
}
