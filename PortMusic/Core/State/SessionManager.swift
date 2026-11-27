import Foundation
import Combine
import Network

public extension Notification.Name {
    static let portMusicDidReconnect = Notification.Name("portMusicDidReconnect")
    static let portMusicNavigateToArtist = Notification.Name("portMusicNavigateToArtist")
}

@MainActor
public final class SessionManager: ObservableObject {
    public static let shared = SessionManager()

    public enum NetworkInterfaceKind: String, Equatable {
        case wifi = "WLAN (Wi-Fi)"
        case cellular = "Mobile Daten"
        case wiredEthernet = "Ethernet"
        case other = "Verbindung aktiv"
        case disconnected = "Kein Internet"
    }

    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: UserProfile? = nil
    @Published public var serverURL: String? = nil
    @Published public var isRestoringSession: Bool = false
    @Published public var isOfflineMode: Bool = false

    @Published public private(set) var isPathSatisfied: Bool = true
    @Published public private(set) var networkInterface: NetworkInterfaceKind = .other
    @Published public private(set) var isExpensiveConnection: Bool = false
    @Published public private(set) var isConstrainedConnection: Bool = false
    @Published public private(set) var networkStatusRaw: String = "wird geprüft"
    @Published public private(set) var lastNetworkUpdate: Date = Date()

    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.portmusic.network.monitor")
    private var lastPathSatisfied: Bool = true
    private var isProbingReconnect: Bool = false

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

        startNetworkMonitoring()
    }

    private func startNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let satisfied = (path.status == .satisfied)
            let iface: NetworkInterfaceKind
            if !satisfied {
                iface = .disconnected
            } else if path.usesInterfaceType(.wifi) {
                iface = .wifi
            } else if path.usesInterfaceType(.cellular) {
                iface = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                iface = .wiredEthernet
            } else {
                iface = .other
            }
            let rawStatus: String
            switch path.status {
            case .satisfied: rawStatus = "satisfied"
            case .unsatisfied: rawStatus = "unsatisfied"
            case .requiresConnection: rawStatus = "requiresConnection"
            @unknown default: rawStatus = "unknown"
            }
            let expensive = path.isExpensive
            let constrained = path.isConstrained

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let changed = (self.networkInterface != iface || self.isPathSatisfied != satisfied || self.networkStatusRaw != rawStatus)
                self.isPathSatisfied = satisfied
                self.networkInterface = iface
                self.isExpensiveConnection = expensive
                self.isConstrainedConnection = constrained
                self.networkStatusRaw = rawStatus
                self.lastNetworkUpdate = Date()

                if changed {
                    DebugLogStore.shared.log(
                        tag: "net:path",
                        category: .system,
                        message: "Status=\(rawStatus), Typ=\(iface.rawValue), teuer=\(expensive), sparmodus=\(constrained)"
                    )
                }

                let wasUnsatisfied = !self.lastPathSatisfied
                self.lastPathSatisfied = satisfied

                if !satisfied {
                    self.setOfflineMode(true)
                } else if (wasUnsatisfied || self.isOfflineMode) && self.isAuthenticated {
                    _ = await self.retryConnection()
                }
            }
        }
        pathMonitor.start(queue: monitorQueue)
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
            await handleOnlineSyncAfterReconnect(serverURL: storedURL, token: token)
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
        guard !isProbingReconnect,
              let storedURL = serverURL, !storedURL.isEmpty,
              let token = currentToken, !token.isEmpty else {
            return false
        }
        isProbingReconnect = true
        defer { isProbingReconnect = false }

        do {
            let profile = try await AuthService.shared.checkAuth(serverURL: storedURL, token: token, timeout: 4.0)
            let wasOffline = self.isOfflineMode
            self.currentUser = profile
            self.isAuthenticated = true
            self.isOfflineMode = false
            cacheUserProfile(profile)
            await handleOnlineSyncAfterReconnect(serverURL: storedURL, token: token)
            if wasOffline {
                NotificationCenter.default.post(name: .portMusicDidReconnect, object: nil)
            }
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

    private func handleOnlineSyncAfterReconnect(serverURL: String, token: String) async {
        await FavoritesManager.shared.syncPendingWithServer(serverURL: serverURL, token: token)
        _ = await MusicService.shared.fetchFavorites(serverURL: serverURL, token: token)
        await OfflineDownloadManager.shared.syncSavedPlaylistsOnReconnect(serverURL: serverURL, token: token)
        await OfflineDownloadManager.shared.repairMissingLyricsIfNeeded(serverURL: serverURL, token: token)
    }

    public func setOfflineMode(_ offline: Bool) {
        if self.isOfflineMode != offline {
            let becameOnline = (self.isOfflineMode == true && offline == false)
            self.isOfflineMode = offline
            if becameOnline, let url = serverURL, let tok = currentToken, !url.isEmpty, !tok.isEmpty {
                Task {
                    await handleOnlineSyncAfterReconnect(serverURL: url, token: tok)
                    NotificationCenter.default.post(name: .portMusicDidReconnect, object: nil)
                }
            }
        }
    }

    public static func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let nsErr = error as NSError
        return nsErr.domain == NSURLErrorDomain && nsErr.code == NSURLErrorCancelled
    }

    /// Vermeidet falschen Offline-Modus bei abgebrochenen Tasks oder einzelnen fehlerhaften Streams,
    /// solange iOS noch aktive Netzwerkverbindung meldet — prüft stattdessen zuerst /api/auth/check.
    public func reportSuspectedConnectionFailure(_ error: Error? = nil) {
        if let err = error, Self.isCancellationError(err) {
            return
        }
        if !isPathSatisfied {
            setOfflineMode(true)
            return
        }
        Task { @MainActor [weak self] in
            _ = await self?.retryConnection()
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
                self.reportSuspectedConnectionFailure(error)
            }
        } catch {
            self.reportSuspectedConnectionFailure(error)
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
