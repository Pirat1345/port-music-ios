//
//  AccountSettingsView.swift
//  Port Music
//

import SwiftUI

struct AccountSettingsView: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss

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
                NavigationLink {
                    ServerConfigurationView()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Server-Konfiguration")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            Text(account.serverURL)
                                .font(.caption)
                                .foregroundColor(.portTextMuted)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
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
                    .padding(.vertical, 2)
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
    }
}
