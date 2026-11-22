import SwiftUI

public struct SettingsMainView: View {
    public let user: UserProfile
    public let serverURL: String
    public let onLogout: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileManager = ServerProfileManager.shared
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared

    @AppStorage("portmusic_audio_quality") private var audioQuality: String = "high"
    @AppStorage("offline_wifi_only") private var offlineWifiOnly: Bool = true
    @AppStorage("playback_autoplay_enabled") private var autoplayEnabled: Bool = true
    @AppStorage("playback_normalization_enabled") private var normalizationEnabled: Bool = false
    @AppStorage("ui_haptics_enabled") private var hapticsEnabled: Bool = true
    @AppStorage("ui_keep_screen_awake") private var keepScreenAwake: Bool = false

    @AppStorage("navbar_icons_only") private var iconsOnly: Bool = false
    @AppStorage("navbar_scroll_minimize") private var scrollMinimize: Bool = true
    @AppStorage("navbar_custom_tabs") private var customTabsRaw: String = "home,library,radio,search"

    @State private var showLogoutAlert: Bool = false
    @State private var showClearDownloadsAlert: Bool = false
    @State private var showCacheClearedBanner: Bool = false

    public init(user: UserProfile, serverURL: String, onLogout: @escaping () -> Void) {
        self.user = user
        self.serverURL = serverURL
        self.onLogout = onLogout
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                List {
                    // ── 1. BENUTZERPROFIL HEADER-KARTE ──
                    Section {
                        profileHeaderCard
                    }
                    .listRowBackground(Color(white: 0.10))

                    // ── 2. SERVER & VERBINDUNG ──
                    Section(header: Text("Server & Verbindung").foregroundColor(.gray)) {
                        NavigationLink(destination: ServerManagementView()) {
                            HStack(spacing: 14) {
                                settingsIcon(name: "server.rack", color: .blue)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Aktiver Server")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    Text(profileManager.activeServerURL.isEmpty ? serverURL : profileManager.activeServerURL)
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .listRowBackground(Color(white: 0.10))

                    // ── 3. OFFLINE-DOWNLOADS & SPEICHER ──
                    Section(header: Text("Offline-Downloads & Speicher").foregroundColor(.gray)) {
                        HStack(spacing: 14) {
                            settingsIcon(name: "arrow.down.circle.fill", color: Color(hex: "#00d26a"))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Offline-Speicherbelegung")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                Text("\(offlineManager.formattedTotalStorage()) belegt (\(offlineManager.downloadedTrackIds.count) Titel)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 2)

                        Toggle(isOn: $offlineWifiOnly) {
                            HStack(spacing: 14) {
                                settingsIcon(name: "wifi", color: .cyan)
                                Text("Nur über WLAN herunterladen")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                            }
                        }

                        if !offlineManager.downloadedTrackIds.isEmpty {
                            Button(role: .destructive, action: {
                                showClearDownloadsAlert = true
                            }) {
                                HStack(spacing: 14) {
                                    settingsIcon(name: "trash.fill", color: .red)
                                    Text("Alle Downloads löschen")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.red)
                                }
                            }
                        }

                        Button(action: {
                            URLCache.shared.removeAllCachedResponses()
                            PortImageCache.shared.clearCache()
                            showCacheClearedBanner = true
                        }) {
                            HStack(spacing: 14) {
                                settingsIcon(name: "arrow.clockwise", color: .orange)
                                Text("Temporären Bild- & Audio-Cache leeren")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.10))

                    // ── 4. AUDIO & WIEDERGABE ──
                    Section(header: Text("Audio & Wiedergabe").foregroundColor(.gray)) {
                        HStack(spacing: 14) {
                            settingsIcon(name: "speaker.wave.3.fill", color: Color(hex: "#fc3c44"))

                            Picker("Streaming-Qualität", selection: $audioQuality) {
                                Text("Normal (128 kbps)").tag("normal")
                                Text("Hoch (256 kbps)").tag("high")
                                Text("Lossless HiFi (FLAC)").tag("lossless")
                            }
                            .foregroundColor(.white)
                            .tint(.gray)
                        }

                        Toggle(isOn: $autoplayEnabled) {
                            HStack(spacing: 14) {
                                settingsIcon(name: "infinity", color: .pink)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Intelligentes Autoplay")
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                    Text("Ähnliche Titel nach Warteschlangen-Ende")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                            }
                        }

                        Toggle(isOn: $normalizationEnabled) {
                            HStack(spacing: 14) {
                                settingsIcon(name: "waveform", color: .yellow)
                                Text("Lautstärke-Normalisierung")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.10))

                    // ── 5. ERSCHEINUNGSBILD & BEDIENUNG ──
                    Section(header: Text("Erscheinungsbild & Bedienung").foregroundColor(.gray)) {
                        Toggle(isOn: $hapticsEnabled) {
                            HStack(spacing: 14) {
                                settingsIcon(name: "iphone.radiowaves.left.and.right", color: .indigo)
                                Text("Haptisches Feedback")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                            }
                        }

                        Toggle(isOn: $keepScreenAwake) {
                            HStack(spacing: 14) {
                                settingsIcon(name: "sun.max.fill", color: .orange)
                                Text("Display bei Wiedergabe aktiv halten")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                            }
                        }
                        .onChange(of: keepScreenAwake) { enabled in
                            UIApplication.shared.isIdleTimerDisabled = enabled
                        }
                    }
                    .listRowBackground(Color(white: 0.10))

                    // ── 6. ÜBER DIE APP ──
                    Section(header: Text("Über").foregroundColor(.gray)) {
                        HStack(spacing: 14) {
                            settingsIcon(name: "info.circle.fill", color: .gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Port Music iOS")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                Text("Version 1.0.3 · Native Octave Edition")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.10))

                    // ── 7. ABMELDEN BUTTON ──
                    Section {
                        Button(action: {
                            showLogoutAlert = true
                        }) {
                            HStack {
                                Spacer()
                                Text("Abmelden")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.10))
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
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
                            .foregroundColor(Color.white.opacity(0.60))
                    }
                }
            }
            .alert("Alle Downloads löschen?", isPresented: $showClearDownloadsAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    offlineManager.removeAllDownloads()
                }
            } message: {
                Text("Möchtest du alle offline gespeicherten Songs von diesem iPhone entfernen? Dein Online-Konto und deine Playlists bleiben unverändert.")
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
            .alert("Cache geleert", isPresented: $showCacheClearedBanner) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Temporäre Zwischenspeicher für Bilder und Streams wurden erfolgreich bereinigt.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var profileHeaderCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(white: 0.18))
                    .frame(width: 58, height: 58)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )

                if let avatar = user.avatar, !avatar.isEmpty,
                   let url = MusicService.shared.avatarURL(user: user, serverURL: serverURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill().frame(width: 58, height: 58).clipShape(Circle())
                        default:
                            initialsView
                        }
                    }
                } else {
                    initialsView
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(user.username)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text(user.role.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .foregroundColor(.white.opacity(0.80))
                }

                if let email = user.email, !email.isEmpty {
                    Text(email)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var initialsView: some View {
        let initial = String(user.username.prefix(1)).uppercased()
        return Text(initial.isEmpty ? "P" : initial)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundColor(.white)
    }

    private func settingsIcon(name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(color)
                .frame(width: 30, height: 30)

            Image(systemName: name)
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
    }
}
