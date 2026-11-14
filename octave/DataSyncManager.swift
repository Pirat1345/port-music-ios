//
//  DataSyncManager.swift
//  Port Music
//
//  Orchestrates post-login and session restoration synchronization.
//

import Foundation
import Observation

@Observable
final class DataSyncManager: @unchecked Sendable {
    static let shared = DataSyncManager()

    var isSyncing: Bool = false
    var lastSyncTimestamp: Date? = nil
    var lastError: String? = nil

    private init() {}

    /// Führt die vollständige Datensynchronisation nach erfolgreicher Anmeldung oder Sitzungswiederherstellung durch.
    @MainActor
    func syncAfterLogin() async throws {
        guard !isSyncing else {
            print("[DataSyncManager] Synchronisation läuft bereits. Überspringe erneuten Aufruf.")
            return
        }

        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        print("[DataSyncManager] Starte Synchronisation nach Anmeldung...")

        // Schritt a: Sitzung und Benutzerprofil validieren
        do {
            let user = try await OctaveBackend.shared.checkSession()
            AccountStore.shared.currentUser = user
            AccountStore.shared.username = user.username
            AccountStore.shared.displayName = user.displayName
            AccountStore.shared.email = user.email ?? ""
            print("[DataSyncManager] Schritt a: Profil für '\(user.username)' bestätigt.")
        } catch {
            print("[DataSyncManager] Schritt a: Sitzungsüberprüfung fehlgeschlagen (\(error.localizedDescription)).")
            lastError = error.localizedDescription
            throw error
        }

        // Schritt b: Favoriten vom Server abrufen und LibraryIndex aktualisieren
        do {
            let favorites = try await OctaveBackend.shared.fetchFavorites()
            LibraryIndex.shared.setFavorites(favorites)
            print("[DataSyncManager] Schritt b: \(favorites.count) Favoriten erfolgreich synchronisiert.")
        } catch {
            print("[DataSyncManager] Schritt b: Fehler beim Abrufen der Favoriten: \(error.localizedDescription)")
            lastError = error.localizedDescription
            // Bei Netzwerk- oder Abruffehler nicht abbrechen, um Playlist-Sync zu versuchen
        }

        // Schritt c: Benutzer-Playlists abrufen
        do {
            let playlists = try await OctaveBackend.shared.fetchUserPlaylists()
            print("[DataSyncManager] Schritt c: \(playlists.count) Wiedergabelisten synchronisiert.")
        } catch {
            print("[DataSyncManager] Schritt c: Fehler beim Abrufen der Playlists: \(error.localizedDescription)")
            // Fehler protokollieren, aber nicht zwingend fehlschlagen lassen
        }

        // Schritt d: Gesamten App-Zustand abrufen (/api/state)
        do {
            if let state = try await OctaveBackend.shared.fetchState() {
                print("[DataSyncManager] Schritt d: App-Status synchronisiert (\(state.playlists.count) Playlists, \(state.folders.count) Ordner).")
            } else {
                print("[DataSyncManager] Schritt d: Kein entfernter Status vorhanden oder Status ist leer.")
            }
        } catch {
            print("[DataSyncManager] Schritt d: Fehler beim Abrufen des App-Status: \(error.localizedDescription)")
            // 404 oder leerer Status ist kein fataler Fehler
        }

        lastSyncTimestamp = Date()
        print("[DataSyncManager] Synchronisation erfolgreich abgeschlossen.")
    }
}
