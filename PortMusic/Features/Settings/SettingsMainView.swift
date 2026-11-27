import SwiftUI

public struct SettingsMainView: View {
    public let user: UserProfile
    public let serverURL: String
    public let onLogout: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileManager = ServerProfileManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared

    @AppStorage("ui_haptics_enabled") private var hapticsEnabled: Bool = true
    @AppStorage("ui_keep_screen_awake") private var keepScreenAwake: Bool = false
    @AppStorage("navbar_icons_only") private var iconsOnly: Bool = false
    @AppStorage("navbar_scroll_minimize") private var scrollMinimize: Bool = true
    @AppStorage("navbar_custom_tabs") private var customTabsRaw: String = "home,library,radio,search"

    @State private var searchQuery: String = ""
    @State private var showNavbarSheet: Bool = false
    @State private var showLogoutAlert: Bool = false

    public init(user: UserProfile, serverURL: String, onLogout: @escaping () -> Void) {
        self.user = user
        self.serverURL = serverURL
        self.onLogout = onLogout
    }

    private var activeUser: UserProfile {
        sessionManager.currentUser ?? user
    }

    private var activeServerHost: String {
        let raw = profileManager.activeServerURL.isEmpty ? serverURL : profileManager.activeServerURL
        if let u = URL(string: raw), let host = u.host {
            return u.port.map { "\(host):\($0)" } ?? host
        }
        return raw.isEmpty ? "Nicht eingerichtet" : raw
    }

    private var appVersionDisplay: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    private var networkShortLabel: String {
        if !sessionManager.isPathSatisfied { return "Kein Netz" }
        switch sessionManager.networkInterface {
        case .wifi: return "WLAN"
        case .cellular: return "Mobilfunk"
        case .wiredEthernet: return "Ethernet"
        case .other: return "Verbunden"
        case .disconnected: return "Kein Netz"
        }
    }

    private var networkPolicyFooterText: String {
        if sessionManager.isManualOfflineMode {
            return "100 % Offline aktiv: Laufende Streams und Downloads wurden abgebrochen, jede externe Netzwerkanfrage ist gesperrt."
        }
        if sessionManager.networkInterface == .cellular {
            switch sessionManager.cellularStreamingMode {
            case .offlineOnly:
                return "Aktuell über Mobile Daten: Mobilfunk-Schutz aktiv (nur Offline-Songs). Im WLAN automatisch wieder online."
            case .dataSaver:
                return "Aktuell über Mobile Daten: Datensparmodus aktiv (Low ~48–64 kbps, kein Hintergrund-Prefetch)."
            case .unlimited:
                return "Aktuell über Mobile Daten: Ungedrosselt (wie im WLAN)."
            }
        }
        if sessionManager.networkInterface == .wifi || sessionManager.networkInterface == .wiredEthernet {
            return "Verbunden über \(sessionManager.networkInterface.rawValue) – volle Server-Verbindung aktiv."
        }
        return "Offline-Switch kappt jederzeit sofort sämtliche externen Verbindungen."
    }

    private func matches(_ text: String...) -> Bool {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return text.contains { $0.lowercased().contains(q) }
    }

    public var body: some View {
        NavigationStack {
            List {
                // 1. Apple-ID-Stil Konto-Banner (Namen, Mail, Passwort, 2FA & Bild ändern)
                if matches("profil", "konto", "name", "email", "mail", "passwort", "2fa", "bild", "avatar", activeUser.username, activeUser.displayName ?? "") {
                    Section {
                        NavigationLink {
                            AccountSettingsView(user: activeUser, serverURL: serverURL)
                        } label: {
                            HStack(spacing: 14) {
                                PortUserAvatarView(
                                    rawAvatar: activeUser.avatar,
                                    username: activeUser.username,
                                    serverURL: serverURL,
                                    size: 58
                                )
                                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 0.8))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(activeUser.displayName ?? activeUser.username)
                                        .font(.system(size: 19, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Text("Name, E-Mail, Passwort, 2FA & Bild")
                                        .font(.system(size: 12.5))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listRowBackground(Color(white: 0.11))
                }

                // 1b. Netzwerk & Datenvolumen
                let showOfflineSwitch = matches("offline", "flugzeug", "0 bytes", "netzwerk", "internet")
                let showCellularQuality = matches("mobile daten", "mobilfunk", "lte", "5g", "datensparmodus", "datenvolumen", "qualität", "streaming", "high", "low", "wlan")
                if showOfflineSwitch || showCellularQuality {
                    Section(
                        header: Text("Netzwerk & Offline"),
                        footer: Text(networkPolicyFooterText)
                    ) {
                        if showOfflineSwitch {
                            Toggle(isOn: Binding(
                                get: { sessionManager.isManualOfflineMode },
                                set: { sessionManager.setManualOfflineMode($0) }
                            )) {
                                HStack(spacing: 12) {
                                    appleIcon(
                                        sessionManager.isManualOfflineMode ? "wifi.slash" : "antenna.radiowaves.left.and.right.circle.fill",
                                        color: sessionManager.isManualOfflineMode ? Color(hex: "#ff453a") : Color(hex: "#30d158")
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Offline-Modus (0 Bytes)")
                                            .foregroundColor(.white)
                                        Text(sessionManager.isManualOfflineMode ? "Alle externen Aufrufe hart blockiert" : "Nur lokale Titel oder regulär verbinden")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .tint(Color(hex: "#ff9f0a"))
                        }

                        if showCellularQuality {
                            NavigationLink {
                                SettingsNetworkDataView()
                            } label: {
                                HStack(spacing: 12) {
                                    appleIcon("cellularbars", color: Color(hex: "#0a84ff"))
                                    Text("Mobile Daten & Qualität")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(sessionManager.cellularStreamingMode.shortLabel)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.11))
                }

                // 2. Auf diesem Gerät (Separate On-Device-Kategorie: Downloads, Server & Netzwerkstatus)
                let showDownloads = matches("offline", "downloads", "speicher", "cache", "wlan", "gerät", "on device")
                let showServer = matches("server", "verbindung", "adresse", "host", "ip", "on device")
                let showDebug = matches("debug", "diagnose", "netzwerk", "status", "wlan", "mobil", "internet", "log", "on device")

                if showDownloads || showServer || showDebug {
                    Section(
                        header: Text("Auf diesem Gerät"),
                        footer: Text("Lokale Downloads, gespeicherte Server-Adressen sowie Netzwerk- und Stream-Diagnose bleiben direkt auf diesem iPhone.")
                    ) {
                        if showDownloads {
                            NavigationLink {
                                SettingsDownloadsView(serverURL: serverURL)
                            } label: {
                                HStack(spacing: 12) {
                                    appleIcon("arrow.down.circle.fill", color: Color(hex: "#0a84ff"))
                                    Text("Offline-Downloads")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(offlineManager.formattedTotalStorage())
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        if showServer {
                            NavigationLink {
                                ServerManagementView()
                            } label: {
                                HStack(spacing: 12) {
                                    appleIcon("server.rack", color: Color(hex: "#30d158"))
                                    Text("Server & Verbindung")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(activeServerHost)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }

                        if showDebug {
                            NavigationLink {
                                SettingsDebugView(serverURL: serverURL)
                            } label: {
                                HStack(spacing: 12) {
                                    appleIcon("antenna.radiowaves.left.and.right", color: Color(hex: "#ff9f0a"))
                                    Text("Diagnose (Debug)")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(networkShortLabel)
                                        .font(.system(size: 13.5, weight: .medium))
                                        .foregroundColor(sessionManager.isPathSatisfied ? Color(hex: "#30d158") : Color(hex: "#ff453a"))
                                }
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.11))
                }

                // 3. Audio & Wiedergabe
                let showPlayback = matches("wiedergabe", "autoplay", "audio", "überspringen", "defekte")
                let showEqualizer = matches("equalizer", "klang", "normalisierung", "lautstärke")

                if showPlayback || showEqualizer {
                    Section(header: Text("Audio & Wiedergabe")) {
                        if showPlayback {
                            NavigationLink {
                                SettingsPlaybackView()
                            } label: {
                                HStack(spacing: 12) {
                                    appleIcon("waveform", color: Color(hex: "#ff375f"))
                                    Text("Wiedergabe")
                                        .foregroundColor(.white)
                                }
                            }
                        }

                        if showEqualizer {
                            NavigationLink {
                                SettingsEqualizerView()
                            } label: {
                                HStack(spacing: 12) {
                                    appleIcon("slider.horizontal.3", color: Color(hex: "#5e5ce6"))
                                    Text("Klang & Normalisierung")
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.11))
                }

                // 4. Darstellung & Bedienung
                let showNavbar = matches("navigationsleiste", "tabs", "leiste", "darstellung")
                let showPlayerLayout = matches("player", "layout", "cover")
                let showLanguage = matches("sprache", "deutsch", "english")
                let showToggles = matches("haptik", "vibration", "display", "bildschirm", "aktiv")

                if showNavbar || showPlayerLayout || showLanguage || showToggles {
                    Section(header: Text("Darstellung & Bedienung")) {
                        if showNavbar {
                            Button(action: { showNavbarSheet = true }) {
                                HStack(spacing: 12) {
                                    appleIcon("dock.rectangle", color: Color(hex: "#0a84ff"))
                                    Text("Navigationsleiste")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color(white: 0.40))
                                }
                            }
                        }

                        if showPlayerLayout {
                            NavigationLink {
                                SettingsPlayerLayoutView()
                            } label: {
                                HStack(spacing: 12) {
                                    appleIcon("play.rectangle.fill", color: Color(hex: "#bf5af2"))
                                    Text("Player-Layout")
                                        .foregroundColor(.white)
                                }
                            }
                        }

                        if showLanguage {
                            NavigationLink {
                                SettingsLanguageView()
                            } label: {
                                HStack(spacing: 12) {
                                    appleIcon("globe", color: Color(hex: "#64d2ff"))
                                    Text("Sprache")
                                        .foregroundColor(.white)
                                }
                            }
                        }

                        if showToggles {
                            Toggle(isOn: $hapticsEnabled) {
                                HStack(spacing: 12) {
                                    appleIcon("iphone.radiowaves.left.and.right", color: Color(hex: "#5e5ce6"))
                                    Text("Haptisches Feedback")
                                        .foregroundColor(.white)
                                }
                            }
                            .tint(Color(hex: "#30d158"))

                            Toggle(isOn: $keepScreenAwake) {
                                HStack(spacing: 12) {
                                    appleIcon("sun.max.fill", color: Color(hex: "#ff9f0a"))
                                    Text("Display aktiv halten")
                                        .foregroundColor(.white)
                                }
                            }
                            .tint(Color(hex: "#30d158"))
                            .onChange(of: keepScreenAwake) { enabled in
                                UIApplication.shared.isIdleTimerDisabled = enabled
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.11))
                }

                // 5. Sicherheit & Info
                devicesAndInfoSection

                // 6. Abmelden
                if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Button(role: .destructive) {
                            showLogoutAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Abmelden")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.11))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Einstellungen durchsuchen")
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showNavbarSheet) {
                NavbarSettingsSheet(
                    iconsOnly: $iconsOnly,
                    scrollMinimize: $scrollMinimize,
                    customTabsRaw: $customTabsRaw
                )
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

    @ViewBuilder
    private var devicesAndInfoSection: some View {
        let showDevices = matches("geräte", "sitzungen", "sessions", "abmelden")
        let showAbout = matches("über", "version", "info", "port music")

        if showDevices || showAbout {
            Section(header: Text("Geräte & Info")) {
                if showDevices {
                    NavigationLink {
                        DeviceManagementView()
                    } label: {
                        HStack(spacing: 12) {
                            appleIcon("laptopcomputer.and.iphone", color: Color(hex: "#64d2ff"))
                            Text("Angemeldete Geräte")
                                .foregroundColor(.white)
                        }
                    }
                }

                if showAbout {
                    HStack(spacing: 12) {
                        appleIcon("info.circle.fill", color: Color(white: 0.42))
                        Text("Version")
                            .foregroundColor(.white)
                        Spacer()
                        Text(appVersionDisplay)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listRowBackground(Color(white: 0.11))
        }
    }

    private func appleIcon(_ systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color)
                .frame(width: 29, height: 29)
            Image(systemName: systemName)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}
