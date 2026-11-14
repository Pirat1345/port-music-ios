import Foundation
import Combine

@MainActor
public final class SessionManager: ObservableObject {
    public static let shared = SessionManager()

    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: UserProfile? = nil
    @Published public var serverURL: String? = nil
    @Published public var isRestoringSession: Bool = true

    private let serverURLStorageKey = "portmusic_server_url"
    private let userStorageKey = "portmusic_auth_user"

    public init() {
        let storedURL = UserDefaults.standard.string(forKey: serverURLStorageKey)
        if let url = storedURL, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.serverURL = url
        }
    }

    // MARK: - Sitzungswiederherstellung beim App-Start

    public func restoreSession() async {
        isRestoringSession = true
        defer {
            isRestoringSession = false
        }

        guard let storedURL = UserDefaults.standard.string(forKey: serverURLStorageKey),
              !storedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.serverURL = nil
            self.isAuthenticated = false
            self.currentUser = nil
            return
        }

        self.serverURL = storedURL

        guard let token = KeychainHelper.shared.getToken(), !token.isEmpty else {
            self.isAuthenticated = false
            self.currentUser = nil
            return
        }

        do {
            let profile = try await AuthService.shared.checkAuth(serverURL: storedURL, token: token)
            self.currentUser = profile
            self.isAuthenticated = true
            cacheUserProfile(profile)
        } catch let error as AuthError {
            switch error {
            case .unauthorized, .sessionExpired, .invalidCredentials:
                KeychainHelper.shared.deleteToken()
                clearCachedUserProfile()
                self.currentUser = nil
                self.isAuthenticated = false
            default:
                // Bei Netzwerkfehlern oder anderen Status Server beibehalten
                self.isAuthenticated = false
            }
        } catch {
            self.isAuthenticated = false
        }
    }

    // MARK: - Anmeldung & Abmeldung

    public func loginSuccess(user: UserProfile, token: String, serverURL: String) {
        if !token.isEmpty {
            KeychainHelper.shared.saveToken(token)
        }
        updateServerURL(serverURL)
        cacheUserProfile(user)

        self.currentUser = user
        self.isAuthenticated = true
    }

    public func logout() {
        KeychainHelper.shared.deleteToken()
        clearCachedUserProfile()

        self.currentUser = nil
        self.isAuthenticated = false
    }

    public func updateServerURL(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: serverURLStorageKey)
        self.serverURL = trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Lokaler Profil-Cache

    private func cacheUserProfile(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: userStorageKey)
        }
    }

    private func clearCachedUserProfile() {
        UserDefaults.standard.removeObject(forKey: userStorageKey)
    }

    public func loadCachedUserProfile() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: userStorageKey) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }
}
