//
//  AccountStore.swift
//  octave
//

import Foundation
import Observation

@Observable
final class AccountStore: @unchecked Sendable {
    static let shared = AccountStore()

    private let userDefaultsUsernameKey = "port_music_saved_username"
    private let userDefaultsDisplayNameKey = "port_music_saved_display_name"
    private let userDefaultsEmailKey = "port_music_saved_email"

    var isAuthenticated: Bool = false
    var currentUser: UserInfo?
    var username: String = "Listener"
    var displayName: String = "Listener"
    var email: String = ""
    var serverURL: String = "http://192.168.178.19:3000"

    var isLoading: Bool = false
    var errorMessage: String?

    init() {
        self.serverURL = OctaveBackend.shared.serverBaseURLString
        if let token = OctaveBackend.shared.authToken, !token.isEmpty {
            self.isAuthenticated = true
            self.username = UserDefaults.standard.string(forKey: userDefaultsUsernameKey) ?? "Listener"
            self.displayName = UserDefaults.standard.string(forKey: userDefaultsDisplayNameKey) ?? self.username
            self.email = UserDefaults.standard.string(forKey: userDefaultsEmailKey) ?? ""
            self.currentUser = UserInfo(
                userId: "saved",
                username: self.username,
                displayName: self.displayName,
                email: self.email
            )
        }
    }

    func updateServerURL(_ newURL: String) {
        OctaveBackend.shared.setServerBaseURL(newURL)
        self.serverURL = OctaveBackend.shared.serverBaseURLString
    }

    @MainActor
    func login(identifier: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await OctaveBackend.shared.login(identifier: identifier, password: password)
            self.currentUser = result.user
            self.username = result.user.username
            self.displayName = result.user.displayName
            self.email = result.user.email ?? ""
            self.isAuthenticated = true

            UserDefaults.standard.set(self.username, forKey: userDefaultsUsernameKey)
            UserDefaults.standard.set(self.displayName, forKey: userDefaultsDisplayNameKey)
            UserDefaults.standard.set(self.email, forKey: userDefaultsEmailKey)

            isLoading = false
            return true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func register(username: String, email: String, password: String, displayName: String? = nil) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await OctaveBackend.shared.register(
                username: username,
                email: email,
                password: password,
                displayName: displayName
            )
            self.currentUser = result.user
            self.username = result.user.username
            self.displayName = result.user.displayName
            self.email = result.user.email ?? email
            self.isAuthenticated = true

            UserDefaults.standard.set(self.username, forKey: userDefaultsUsernameKey)
            UserDefaults.standard.set(self.displayName, forKey: userDefaultsDisplayNameKey)
            UserDefaults.standard.set(self.email, forKey: userDefaultsEmailKey)

            isLoading = false
            return true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func restoreSession() async {
        guard OctaveBackend.shared.authToken != nil else {
            isAuthenticated = false
            return
        }
        if let user = try? await OctaveBackend.shared.checkSession() {
            self.currentUser = user
            self.username = user.username
            self.displayName = user.displayName
            self.email = user.email ?? ""
            self.isAuthenticated = true
        }
    }

    @MainActor
    func signOut() {
        OctaveBackend.shared.authToken = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsUsernameKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsDisplayNameKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsEmailKey)

        self.currentUser = nil
        self.username = "Listener"
        self.displayName = "Listener"
        self.email = ""
        self.isAuthenticated = false
        self.errorMessage = nil
    }
}
