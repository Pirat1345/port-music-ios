import Foundation
import Combine

@MainActor
public final class SessionManager: ObservableObject {
    public static let shared = SessionManager()

    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: UserProfile? = nil
    @Published public var serverURL: String? = nil
    @Published public var isRestoringSession: Bool = false
    @Published public var isOfflineMode: Bool = false

    public var currentToken: String? {
        if let kc = KeychainHelper.shared.getToken(), !kc.isEmpty {
            return kc
        }
        if let ud = UserDefaults.standard.string(forKey: tokenBackupKey), !ud.isEmpty {
            return ud
        }
        return nil
    }

    private let serverURLStorageKey = "portmusic_server_url"
    private let userStorageKey = "portmusic_auth_user"
    private let tokenBackupKey = "portmusic_auth_token"

    public init() {
        let storedURL = UserDefaults.standard.string(forKey: serverURLStorageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = storedURL, !url.isEmpty {
            self.serverURL = url
        }

        let token = (KeychainHelper.shared.getToken() ?? UserDefaults.standard.string(forKey: tokenBackupKey)) ?? ""
        let cached = loadCachedUserProfile()

        if let url = storedURL, !url.isEmpty, (!token.isEmpty || cached != nil) {
            // Sofort mit lokal gespeichertem Konto starten (0 ms Start ohne blockierenden Ladebildschirm)
            self.currentUser = cached ?? UserProfile(
                id: "cached_user",
                username: "Offline-Konto",
                email: nil,
                role: "user",
                avatar: nil
            )
            self.isAuthenticated = true
            self.isRestoringSession = false
        } else {
            self.isAuthenticated = false
            self.isRestoringSession = false
        }
    }

    // MARK: - Sitzungswiederherstellung im Hintergrund (Offline-First)

    public func restoreSession() async {
        guard let storedURL = UserDefaults.standard.string(forKey: serverURLStorageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !storedURL.isEmpty else {
            self.serverURL = nil
            self.isAuthenticated = false
            self.currentUser = nil
            self.isRestoringSession = false
            return
        }

        self.serverURL = storedURL

        let token = currentToken ?? ""
        let cached = loadCachedUserProfile()

        if token.isEmpty && cached == nil {
            self.isAuthenticated = false
            self.currentUser = nil
            self.isRestoringSession = false
            return
        }

        // Sofort im eingeloggten Konto bleiben, waehrend im Hintergrund geprueft wird
        if self.currentUser == nil {
            self.currentUser = cached ?? UserProfile(
                id: "cached_user",
                username: "Offline-Konto",
                email: nil,
                role: "user",
                avatar: nil
            )
        }
        self.isAuthenticated = true
        self.isRestoringSession = false

        guard !token.isEmpty else {
            self.isOfflineMode = true
            return
        }

        do {
            let profile = try await AuthService.shared.checkAuth(serverURL: storedURL, token: token, timeout: 3.5)
            self.currentUser = profile
            self.isAuthenticated = true
            self.isOfflineMode = false
            cacheUserProfile(profile)
        } catch let error as AuthError {
            switch error {
            case .unauthorized, .sessionExpired, .invalidCredentials:
                // Nur abmelden, wenn der Server explizit 401/ungueltig geantwortet hat
                KeychainHelper.shared.deleteToken()
                UserDefaults.standard.removeObject(forKey: tokenBackupKey)
                clearCachedUserProfile()
                self.currentUser = nil
                self.isAuthenticated = false
                self.isOfflineMode = false
            case .networkError, .serverError, .tooManyAttempts, .invalidCode, .captchaRequired, .unknown:
                // Server nicht erreichbar / anderes WLAN / kein Internet -> Eingeloggt im Offline-Modus bleiben
                self.isOfflineMode = true
                self.isAuthenticated = true
            }
        } catch {
            // Transportfehler -> Konto behalten, Offline-Modus aktivieren
            self.isOfflineMode = true
            self.isAuthenticated = true
        }
    }

    @discardableResult
    public func retryConnection() async -> Bool {
        guard let storedURL = serverURL, !storedURL.isEmpty,
              let token = currentToken, !token.isEmpty else {
            return false
        }
        do {
            let profile = try await AuthService.shared.checkAuth(serverURL: storedURL, token: token, timeout: 4.0)
            self.currentUser = profile
            self.isAuthenticated = true
            self.isOfflineMode = false
            cacheUserProfile(profile)
            return true
        } catch let error as AuthError {
            switch error {
            case .unauthorized, .sessionExpired, .invalidCredentials:
                logout()
                return false
            default:
                self.isOfflineMode = true
                return false
            }
        } catch {
            self.isOfflineMode = true
            return false
        }
    }

    public func setOfflineMode(_ offline: Bool) {
        if self.isOfflineMode != offline {
            self.isOfflineMode = offline
        }
    }

    // MARK: - Anmeldung & Abmeldung

    public func loginSuccess(user: UserProfile, token: String, serverURL: String) {
        if !token.isEmpty {
            KeychainHelper.shared.saveToken(token)
            UserDefaults.standard.set(token, forKey: tokenBackupKey)
        }
        updateServerURL(serverURL)
        cacheUserProfile(user)

        self.currentUser = user
        self.isAuthenticated = true
        self.isOfflineMode = false
        self.isRestoringSession = false
    }

    public func logout() {
        KeychainHelper.shared.deleteToken()
        UserDefaults.standard.removeObject(forKey: tokenBackupKey)
        clearCachedUserProfile()

        self.currentUser = nil
        self.isAuthenticated = false
        self.isOfflineMode = false
        self.isRestoringSession = false
    }

    public func updateServerURL(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: serverURLStorageKey)
        self.serverURL = trimmed.isEmpty ? nil : trimmed
    }

    public func refreshUserProfile() async {
        guard let storedURL = serverURL ?? UserDefaults.standard.string(forKey: serverURLStorageKey),
              let token = currentToken, !token.isEmpty else { return }
        do {
            let profile = try await AuthService.shared.checkAuth(serverURL: storedURL, token: token, timeout: 4.5)
            self.currentUser = profile
            self.isOfflineMode = false
            cacheUserProfile(profile)
        } catch let error as AuthError {
            if case .networkError = error {
                self.isOfflineMode = true
            }
        } catch {
            self.isOfflineMode = true
        }
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
