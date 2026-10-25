//
//  OctaveBackend.swift
//  octave
//

import Foundation

public struct UserInfo: Codable, Sendable, Hashable {
    public let userId: String
    public let username: String
    public let displayName: String
    public let role: String
    public let avatar: String?
    public let email: String?

    public init(
        userId: String,
        username: String,
        displayName: String,
        role: String = "user",
        avatar: String? = nil,
        email: String? = nil
    ) {
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.role = role
        self.avatar = avatar
        self.email = email
    }
}

final class OctaveBackend: @unchecked Sendable {
    static let shared = OctaveBackend()

    private let serverURLKey = "port_music_server_url"
    private let tokenKey = "port_music_auth_token"
    private let defaultServerURL = "http://192.168.178.19:3000"

    var serverBaseURLString: String {
        get {
            let saved = UserDefaults.standard.string(forKey: serverURLKey) ?? defaultServerURL
            return saved.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        set {
            var clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !clean.starts(with: "http://") && !clean.starts(with: "https://") {
                clean = "http://" + clean
            }
            UserDefaults.standard.set(clean, forKey: serverURLKey)
        }
    }

    var apiBaseURL: URL {
        URL(string: serverBaseURLString) ?? URL(string: defaultServerURL)!
    }

    var authToken: String? {
        get {
            UserDefaults.standard.string(forKey: tokenKey)
        }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: tokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: tokenKey)
            }
        }
    }

    func setServerBaseURL(_ urlString: String) {
        self.serverBaseURLString = urlString
    }

    func streamURL(for trackId: String, quality: String = "320") -> URL {
        apiBaseURL.appendingPathComponent("audio").appendingPathComponent(quality).appendingPathComponent(trackId)
    }

    func atmosStreamURL(for trackId: String) -> URL {
        apiBaseURL.appendingPathComponent("audio").appendingPathComponent("atmos").appendingPathComponent(trackId)
    }

    func fetchLyrics(for trackId: String) async throws -> Data {
        let url = apiBaseURL.appendingPathComponent("api").appendingPathComponent("lyrics").appendingPathComponent(trackId)
        var req = URLRequest(url: url)
        applyAuth(to: &req)
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    func applyAuth(to request: inout URLRequest) {
        if let token = authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(token, forHTTPHeaderField: "octave-account-key")
        }
    }

    // MARK: - Authentication API

    func login(identifier: String, password: String) async throws -> (user: UserInfo, token: String) {
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("auth").appendingPathComponent("login")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "email": identifier.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        if httpRes.statusCode == 401 {
            throw BackendError.invalidCredentials
        }
        guard (200...299).contains(httpRes.statusCode) else {
            throw BackendError.serverError("HTTP \(httpRes.statusCode)")
        }

        struct BackendLoginResponse: Codable {
            let authenticated: Bool?
            let token: String?
            let userId: String?
            let username: String?
            let displayName: String?
            let role: String?
            let avatar: String?
            let email: String?
            let user: BackendUserDto?
        }
        struct BackendUserDto: Codable {
            let userId: String
            let username: String
            let displayName: String
            let role: String
            let avatar: String?
            let email: String?
        }

        let decoded = try JSONDecoder().decode(BackendLoginResponse.self, from: data)
        guard let resolvedToken = decoded.token ?? extractSessionCookie(from: httpRes) else {
            throw BackendError.missingToken
        }

        let user: UserInfo
        if let u = decoded.user {
            user = UserInfo(userId: u.userId, username: u.username, displayName: u.displayName, role: u.role, avatar: u.avatar, email: u.email)
        } else {
            user = UserInfo(
                userId: decoded.userId ?? "user",
                username: decoded.username ?? identifier,
                displayName: decoded.displayName ?? identifier,
                role: decoded.role ?? "user",
                avatar: decoded.avatar,
                email: decoded.email
            )
        }

        self.authToken = resolvedToken
        return (user, resolvedToken)
    }

    func register(username: String, email: String, password: String, displayName: String? = nil) async throws -> (user: UserInfo, token: String) {
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("auth").appendingPathComponent("register")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "username": username.trimmingCharacters(in: .whitespacesAndNewlines),
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password,
            "displayName": displayName ?? username
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        guard (200...299).contains(httpRes.statusCode) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = json["message"] as? String ?? json["error"] as? String {
                throw BackendError.serverError(msg)
            }
            throw BackendError.serverError("HTTP \(httpRes.statusCode)")
        }

        struct BackendRegisterResponse: Codable {
            let success: Bool?
            let token: String?
            let userId: String?
            let displayName: String?
        }

        let decoded = try JSONDecoder().decode(BackendRegisterResponse.self, from: data)
        let resolvedToken = decoded.token ?? extractSessionCookie(from: httpRes) ?? ""
        self.authToken = resolvedToken

        let user = UserInfo(
            userId: decoded.userId ?? "user",
            username: username,
            displayName: decoded.displayName ?? username,
            email: email
        )
        return (user, resolvedToken)
    }

    func checkSession() async throws -> UserInfo? {
        guard let token = authToken, !token.isEmpty else { return nil }
        let endpoint = apiBaseURL.appendingPathComponent("api").appendingPathComponent("auth").appendingPathComponent("me")
        var request = URLRequest(url: endpoint)
        applyAuth(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            return nil
        }

        struct MeResponse: Codable {
            let authenticated: Bool
            let user: BackendUserDto?
        }
        struct BackendUserDto: Codable {
            let userId: String
            let username: String
            let displayName: String
            let role: String
            let avatar: String?
            let email: String?
        }

        if let me = try? JSONDecoder().decode(MeResponse.self, from: data), me.authenticated, let u = me.user {
            return UserInfo(userId: u.userId, username: u.username, displayName: u.displayName, role: u.role, avatar: u.avatar, email: u.email)
        }
        return nil
    }

    private func extractSessionCookie(from response: HTTPURLResponse) -> String? {
        guard let rawCookie = response.value(forHTTPHeaderField: "Set-Cookie") else { return nil }
        for part in rawCookie.components(separatedBy: ";") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "pm_session=") {
                return String(trimmed.dropFirst("pm_session=".count))
            } else if trimmed.starts(with: "sessionId=") {
                return String(trimmed.dropFirst("sessionId=".count))
            }
        }
        return nil
    }

    // MARK: - Search Catalog

    func search(query: String) async throws -> [SongEntity] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=30") else {
            return []
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
        return response.results.map {
            SongEntity(
                id: String($0.trackId),
                title: $0.trackName,
                artist: $0.artistName,
                artworkURLString: $0.artworkUrl100?.replacingOccurrences(of: "100x100bb", with: "600x600bb"),
                albumTitle: $0.collectionName,
                albumId: $0.collectionId != nil ? String($0.collectionId!) : nil,
                artistId: $0.artistId != nil ? String($0.artistId!) : nil,
                durationSec: Double($0.trackTimeMillis ?? 0) / 1000.0
            )
        }
    }
}

public enum BackendError: LocalizedError {
    case invalidResponse
    case invalidCredentials
    case missingToken
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Ungültige Antwort vom Server."
        case .invalidCredentials:
            return "Ungültiger Benutzername oder Passwort."
        case .missingToken:
            return "Authentifizierungstoken nicht erhalten."
        case .serverError(let msg):
            return "Serverfehler: \(msg)"
        }
    }
}

private struct ITunesSearchResponse: Codable {
    let results: [ITunesItem]
}

private struct ITunesItem: Codable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let collectionName: String?
    let collectionId: Int?
    let artistId: Int?
    let artworkUrl100: String?
    let trackTimeMillis: Int?
}
