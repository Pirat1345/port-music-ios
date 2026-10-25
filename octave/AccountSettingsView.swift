//
//  AccountSettingsView.swift
//  octave
//

import SwiftUI

struct AccountSettingsView: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss

    @State private var serverAddress: String = ""
    @State private var isEditingServer: Bool = false
    @State private var showSignOutConfirm: Bool = false

    var body: some View {
        List {
            Section("Profil") {
                HStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.displayName.isEmpty ? account.username : account.displayName)
                            .font(.headline)
                        Text("@\(account.username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if !account.email.isEmpty {
                            Text(account.email)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Backend-Verbindung") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Server-Adresse")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if isEditingServer {
                            TextField("http://192.168.178.19:3000", text: $serverAddress)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .font(.subheadline)
                        } else {
                            Text(account.serverURL)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }

                    Spacer()

                    if isEditingServer {
                        Button("Fertig") {
                            account.updateServerURL(serverAddress)
                            isEditingServer = false
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    } else {
                        Button("Ändern") {
                            serverAddress = account.serverURL
                            isEditingServer = true
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                    }
                }

                HStack {
                    Text("Status")
                        .font(.subheadline)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(account.isAuthenticated ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(account.isAuthenticated ? "Verbunden" : "Getrennt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("App Einstellungen") {
                NavigationLink("Audioqualität & Streaming") { SettingsView() }
                NavigationLink("Mitteilungen") { NotificationSettingsCard() }
            }

            Section {
                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Abmelden")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Konto")
        .confirmationDialog(
            "Möchtest du dich wirklich abmelden?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Abmelden", role: .destructive) {
                account.signOut()
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        }
        .onAppear {
            self.serverAddress = account.serverURL
        }
    }
}
