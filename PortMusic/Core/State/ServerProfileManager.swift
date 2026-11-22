import Foundation
import Combine

public struct ServerProfile: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var url: String
    public var username: String?
    public var lastConnected: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        url: String,
        username: String? = nil,
        lastConnected: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.username = username
        self.lastConnected = lastConnected
    }
}

@MainActor
public final class ServerProfileManager: ObservableObject {
    public static let shared = ServerProfileManager()

    @Published public private(set) var profiles: [ServerProfile] = []
    @Published public private(set) var activeServerURL: String = ""

    private let profilesStorageKey = "portmusic_saved_server_profiles"

    private init() {
        loadProfiles()
    }

    private func loadProfiles() {
        let current = SessionManager.shared.serverURL ?? ""
        self.activeServerURL = current

        if let data = UserDefaults.standard.data(forKey: profilesStorageKey),
           let saved = try? JSONDecoder().decode([ServerProfile].self, from: data) {
            self.profiles = saved
        } else {
            // Falls noch keine Profile gespeichert sind, erstelle automatisch eines für den aktuellen Server
            if !current.isEmpty {
                let initial = ServerProfile(
                    name: "Standard-Server",
                    url: current,
                    username: SessionManager.shared.currentUser?.username,
                    lastConnected: Date()
                )
                self.profiles = [initial]
                saveProfiles()
            }
        }
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesStorageKey)
        }
    }

    public func addOrUpdateProfile(name: String, url: String, username: String? = nil) {
        let cleanURL = url.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !cleanURL.isEmpty else { return }

        if let idx = profiles.firstIndex(where: { $0.url.lowercased() == cleanURL.lowercased() }) {
            profiles[idx].name = name.isEmpty ? profiles[idx].name : name
            if let u = username { profiles[idx].username = u }
            profiles[idx].lastConnected = Date()
        } else {
            let newProfile = ServerProfile(
                name: name.isEmpty ? "Server \(profiles.count + 1)" : name,
                url: cleanURL,
                username: username,
                lastConnected: Date()
            )
            profiles.append(newProfile)
        }
        saveProfiles()
    }

    public func removeProfile(id: String) {
        profiles.removeAll(where: { $0.id == id })
        saveProfiles()
    }

    public func switchServer(to profile: ServerProfile) {
        let cleanURL = profile.url.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !cleanURL.isEmpty else { return }

        self.activeServerURL = cleanURL
        SessionManager.shared.updateServerURL(cleanURL)

        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx].lastConnected = Date()
            saveProfiles()
        }

        // Versuche das gespeicherte Token für diesen spezifischen Server zu laden
        let serverTokenKey = "portmusic_token_\(cleanURL.lowercased())"
        if let token = KeychainHelper.shared.get(forKey: serverTokenKey), !token.isEmpty {
            KeychainHelper.shared.saveToken(token)
            Task {
                await SessionManager.shared.restoreSession()
            }
        } else {
            // Kein Token vorhanden -> Benutzer muss sich für diesen Server anmelden
            SessionManager.shared.logout()
        }
    }

    public func testConnection(url: String) async -> (reachable: Bool, latencyMs: Int?) {
        let clean = url.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let testURL = URL(string: "\(clean)/api/auth/status") else {
            return (false, nil)
        }

        var request = URLRequest(url: testURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 6.0

        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                return (true, elapsed)
            }
            return (false, nil)
        } catch {
            return (false, nil)
        }
    }
}
