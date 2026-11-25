import SwiftUI

public struct SettingsMainView: View {
    public let user: UserProfile
    public let serverURL: String
    public let onLogout: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileManager = ServerProfileManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared

    @State private var searchQuery: String = ""
    @State private var showLogoutAlert: Bool = false

    public init(user: UserProfile, serverURL: String, onLogout: @escaping () -> Void) {
        self.user = user
        self.serverURL = serverURL
        self.onLogout = onLogout
    }

    private enum SettingsDestination {
        case playback
        case equalizer
        case appearance
        case playerLayout
        case downloads
        case profile
        case devices
        case language
        case security
        case servers
        case debug
    }

    private struct SettingsNavRow: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let icon: String
        let destination: SettingsDestination
        let trailingBadge: String?
    }

    private struct SettingsNavGroup: Identifiable {
        let id: String
        let title: String
        let rows: [SettingsNavRow]
    }

    private var groups: [SettingsNavGroup] {
        let activeServer = profileManager.activeServerURL.isEmpty ? serverURL : profileManager.activeServerURL
        let netLabel = sessionManager.isOfflineMode ? "Offline" : sessionManager.networkInterface.rawValue

        let allGroups: [SettingsNavGroup] = [
            SettingsNavGroup(
                id: "audio",
                title: "Audio und Wiedergabe",
                rows: [
                    SettingsNavRow(
                        id: "playback",
                        title: "Wiedergabe",
                        subtitle: "Autoplay, Überspringen und Audioqualität",
                        icon: "waveform",
                        destination: .playback,
                        trailingBadge: nil
                    ),
                    SettingsNavRow(
                        id: "equalizer",
                        title: "Equalizer & Klang",
                        subtitle: "Mobile Audio-Engine und Normalisierung",
                        icon: "slider.horizontal.3",
                        destination: .equalizer,
                        trailingBadge: nil
                    ),
                ]
            ),
            SettingsNavGroup(
                id: "appearance",
                title: "Erscheinungsbild",
                rows: [
                    SettingsNavRow(
                        id: "appearance",
                        title: "Design & Bedienung",
                        subtitle: "Navigationsleiste, Akzente, Haptik & Bildschirm",
                        icon: "paintbrush",
                        destination: .appearance,
                        trailingBadge: nil
                    ),
                    SettingsNavRow(
                        id: "player-layout",
                        title: "Player-Layout",
                        subtitle: "Player-Modi und Anzeigeoptionen",
                        icon: "play.rectangle",
                        destination: .playerLayout,
                        trailingBadge: nil
                    ),
                ]
            ),
            SettingsNavGroup(
                id: "library",
                title: "Mediathek und Speicher",
                rows: [
                    SettingsNavRow(
                        id: "downloads",
                        title: "Offline-Downloads",
                        subtitle: "\(offlineManager.downloadedTrackIds.count) gespeicherte Medien · \(offlineManager.formattedTotalStorage())",
                        icon: "arrow.down.circle",
                        destination: .downloads,
                        trailingBadge: nil
                    ),
                ]
            ),
            SettingsNavGroup(
                id: "account",
                title: "Konto und Zugriff",
                rows: [
                    SettingsNavRow(
                        id: "profile",
                        title: "Mein Profil",
                        subtitle: "Profilbild, Name und Kontoinformationen",
                        icon: "person",
                        destination: .profile,
                        trailingBadge: nil
                    ),
                    SettingsNavRow(
                        id: "devices",
                        title: "Verbundene Geräte",
                        subtitle: "Aktive Sitzungen anzeigen und beenden",
                        icon: "laptopcomputer.and.iphone",
                        destination: .devices,
                        trailingBadge: nil
                    ),
                    SettingsNavRow(
                        id: "language",
                        title: "Sprache",
                        subtitle: "Sprache der Benutzeroberfläche",
                        icon: "globe",
                        destination: .language,
                        trailingBadge: nil
                    ),
                    SettingsNavRow(
                        id: "security",
                        title: "Sicherheit",
                        subtitle: "Zwei-Faktor-Authentifizierung und Passwort",
                        icon: "checkmark.shield",
                        destination: .security,
                        trailingBadge: nil
                    ),
                ]
            ),
            SettingsNavGroup(
                id: "system",
                title: "Verwaltung und System",
                rows: [
                    SettingsNavRow(
                        id: "servers",
                        title: "Server & Verbindung",
                        subtitle: activeServer.isEmpty ? "Server konfigurieren" : activeServer,
                        icon: "server.rack",
                        destination: .servers,
                        trailingBadge: nil
                    ),
                    SettingsNavRow(
                        id: "debug",
                        title: "Diagnose (Debug)",
                        subtitle: "Netzwerkstatus, Playback- & Stream-Protokoll",
                        icon: "terminal",
                        destination: .debug,
                        trailingBadge: netLabel
                    ),
                ]
            ),
        ]

        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allGroups }
        return allGroups.compactMap { group in
            let matched = group.rows.filter {
                $0.title.lowercased().contains(q) || $0.subtitle.lowercased().contains(q)
            }
            return matched.isEmpty ? nil : SettingsNavGroup(id: group.id, title: group.title, rows: matched)
        }
    }

    private var appVersionDisplay: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build)) · Port Music iOS"
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        // Web-ähnliche Überschrift + Suchfeld
                        VStack(alignment: .leading, spacing: 14) {
                            searchFieldBar
                            profileBannerCard
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 8)

                        if groups.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color.white.opacity(0.30))
                                Text("Keine passenden Einstellungen gefunden")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.55))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(groups) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(group.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color.white.opacity(0.48))
                                        .textCase(.uppercase)
                                        .tracking(0.8)
                                        .padding(.horizontal, 22)

                                    VStack(spacing: 0) {
                                        ForEach(Array(group.rows.enumerated()), id: \.element.id) { idx, row in
                                            NavigationLink {
                                                destinationView(for: row.destination)
                                            } label: {
                                                settingsRowContent(row)
                                            }
                                            .buttonStyle(PlainButtonStyle())

                                            if idx < group.rows.count - 1 {
                                                Divider()
                                                    .background(Color.white.opacity(0.07))
                                                    .padding(.leading, 56)
                                            }
                                        }
                                    }
                                    .background(Color(hex: "#111114"))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                                    .padding(.horizontal, 18)
                                }
                            }
                        }

                        // Über & Abmelden
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color.white.opacity(0.50))
                                Text(appVersionDisplay)
                                    .font(.system(size: 12.5))
                                    .foregroundColor(Color.white.opacity(0.50))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#111114"))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                            )

                            Button(action: {
                                showLogoutAlert = true
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Abmelden")
                                        .font(.system(size: 15.5, weight: .semibold))
                                        .foregroundColor(Color(hex: "#ff5a5a"))
                                    Spacer()
                                }
                                .padding(.vertical, 14)
                                .background(Color(hex: "#ef4444").opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color(hex: "#ef4444").opacity(0.24), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 18)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color.white.opacity(0.55))
                    }
                }
            }
            .alert("Abmelden?", isPresented: $showLogoutAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Abmelden", role: .destructive) {
                    dismiss()
                    onLogout()
                }
            } message: {
                Text("Möchtest du dich wirklich von Port Music abmelden?")
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }

    private var searchFieldBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.45))

            TextField("Einstellungen durchsuchen...", text: $searchQuery)
                .font(.system(size: 14.5))
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.45))
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(Color(hex: "#111114"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var profileBannerCard: some View {
        NavigationLink {
            EditProfileView(user: user, serverURL: serverURL)
        } label: {
            HStack(spacing: 14) {
                PortUserAvatarView(
                    rawAvatar: user.avatar,
                    username: user.username,
                    serverURL: serverURL,
                    size: 52
                )
                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(user.displayName ?? user.username)
                            .font(.system(size: 16.5, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text((user.role ?? "user").uppercased())
                            .font(.system(size: 9.5, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Capsule())
                            .foregroundColor(Color.white.opacity(0.75))
                    }

                    Text(user.email?.isEmpty == false ? (user.email ?? "") : "@\(user.username)")
                        .font(.system(size: 12.5))
                        .foregroundColor(Color.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.32))
            }
            .padding(14)
            .background(Color(hex: "#111114"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func settingsRowContent(_ row: SettingsNavRow) -> some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 34, height: 34)
                Image(systemName: row.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.88))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(row.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.50))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let badge = row.trailingBadge {
                Text(badge)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(sessionManager.isPathSatisfied ? Color(hex: "#57e389") : Color(hex: "#ff5a5a"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (sessionManager.isPathSatisfied ? Color(hex: "#57e389") : Color(hex: "#ff5a5a"))
                            .opacity(0.14)
                    )
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.28))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func destinationView(for dest: SettingsDestination) -> some View {
        switch dest {
        case .playback:
            SettingsPlaybackView()
        case .equalizer:
            SettingsEqualizerView()
        case .appearance:
            SettingsAppearanceView()
        case .playerLayout:
            SettingsPlayerLayoutView()
        case .downloads:
            SettingsDownloadsView()
        case .profile:
            EditProfileView(user: user, serverURL: serverURL)
        case .devices:
            DeviceManagementView()
        case .language:
            SettingsLanguageView()
        case .security:
            SecuritySettingsView()
        case .servers:
            ServerManagementView()
        case .debug:
            SettingsDebugView(serverURL: serverURL)
        }
    }
}
