//
//  AccountSettingsView.swift
//  Port Music
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
                        .foregroundColor(.portBrand)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.displayName.isEmpty ? account.username : account.displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("@\(account.username)")
                            .font(.caption)
                            .foregroundColor(.portTextSecondary)
                        if !account.email.isEmpty {
                            Text(account.email)
                                .font(.caption2)
                                .foregroundColor(.portTextMuted)
                        }
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.portSurface)
            }

            Section("Backend-Verbindung") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Server-Adresse")
                            .font(.caption)
                            .foregroundColor(.portTextMuted)
                        if isEditingServer {
                            TextField("http://192.168.178.19:3000", text: $serverAddress)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        } else {
                            Text(account.serverURL)
                                .font(.subheadline)
                                .foregroundColor(.white)
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
                        .foregroundColor(.portBrand)
                    } else {
                        Button("Ändern") {
                            serverAddress = account.serverURL
                            isEditingServer = true
                        }
                        .font(.caption)
                        .foregroundColor(.portBrand)
                    }
                }
                .listRowBackground(Color.portSurface)

                HStack {
                    Text("Status")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(account.isAuthenticated ? Color.portBrand : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(account.isAuthenticated ? "Verbunden" : "Getrennt")
                            .font(.caption)
                            .foregroundColor(.portTextSecondary)
                    }
                }
                .listRowBackground(Color.portSurface)
            }

            Section("App Einstellungen") {
                NavigationLink("Audioqualität & Streaming") { SettingsView() }
                    .listRowBackground(Color.portSurface)
                NavigationLink("Mitteilungen") { NotificationSettingsCard() }
                    .listRowBackground(Color.portSurface)
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
                .listRowBackground(Color.portSurface)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.portBackground.ignoresSafeArea())
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
