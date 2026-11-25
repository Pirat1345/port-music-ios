import SwiftUI
import UIKit

// MARK: - 1. Wiedergabe (Web SettingsPlayback.tsx Parity)
public struct SettingsPlaybackView: View {
    @AppStorage("playback_autoplay_enabled") private var autoplayEnabled: Bool = true
    @AppStorage("playback_skip_timeout") private var skipTimeout: Int = 10
    @AppStorage("portmusic_audio_quality") private var audioQuality: String = "high"

    private let skipOptions: [(value: Int, label: String)] = [
        (0, "Aus"), (3, "3s"), (5, "5s"), (7, "7s"), (9, "9s"), (10, "10s"), (15, "15s")
    ]

    public init() {}

    private var normalizedQuality: String {
        audioQuality == "low" || audioQuality == "normal" ? "low" : "high"
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wiedergabe")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Autoplay, Überspringen-Verhalten und Streaming-Qualität")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.55))
                }

                // Hauptkarte (entspricht SettingsPlayback.tsx)
                VStack(alignment: .leading, spacing: 20) {
                    // Autoplay
                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Autoplay")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Ähnliche Titel automatisch abspielen, wenn deine Warteschlange endet.")
                                .font(.system(size: 12.5))
                                .foregroundColor(Color.white.opacity(0.55))
                        }
                        Spacer()
                        Toggle("", isOn: $autoplayEnabled)
                            .labelsHidden()
                            .tint(Color(hex: "#1db954"))
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // Skip unplayable timeout
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Songs überspringen, die nicht abspielen")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text(skipTimeout == 0
                             ? "Deaktiviert. Bei Ladefehlern wird nicht automatisch übersprungen."
                             : "Wenn ein Titel nach \(skipTimeout)s nicht startet, wird zum nächsten Titel gewechselt.")
                            .font(.system(size: 12.5))
                            .foregroundColor(Color.white.opacity(0.55))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(skipOptions, id: \.value) { opt in
                                    let isSel = skipTimeout == opt.value
                                    Button(action: {
                                        skipTimeout = opt.value
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }) {
                                        Text(opt.label)
                                            .font(.system(size: 12.5, weight: isSel ? .semibold : .medium))
                                            .foregroundColor(isSel ? .black : Color.white.opacity(0.68))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(isSel ? Color.white : Color.white.opacity(0.06))
                                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(4)
                            .background(Color.black.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // Audioqualität
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Audioqualität")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Höhere Qualität verbraucht mehr mobile Daten.")
                            .font(.system(size: 12.5))
                            .foregroundColor(Color.white.opacity(0.55))

                        HStack(spacing: 4) {
                            Button(action: {
                                audioQuality = "low"
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                Text("Low")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(normalizedQuality == "low" ? .black : Color.white.opacity(0.68))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 7)
                                    .background(normalizedQuality == "low" ? Color.white : Color.clear)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                audioQuality = "high"
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                Text("High")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(normalizedQuality == "high" ? .black : Color.white.opacity(0.68))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 7)
                                    .background(normalizedQuality == "high" ? Color.white : Color.clear)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(4)
                        .background(Color(hex: "#18181b"))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))

                        HStack(spacing: 6) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.50))
                            Text(normalizedQuality == "high"
                                 ? "High Quality · bis zu 256 kbps AAC / HiFi"
                                 : "AAC · bis zu 130 kbps · datensparend")
                                .font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.50))
                        }
                    }
                }
                .padding(18)
                .background(Color(hex: "#111114"))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))

                Spacer(minLength: 80)
            }
            .padding(18)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Wiedergabe")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 2. Equalizer & Klang (Web Mobile Notice + Normalisierung)
public struct SettingsEqualizerView: View {
    @AppStorage("playback_normalization_enabled") private var normalizationEnabled: Bool = false

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Equalizer & Klang")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Hinweise zur mobilen iOS-Audio-Engine")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.55))
                }

                // Gelb/Amber Mobile Notice Card wie auf der Webseite
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "iphone")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#fbbf24"))
                        Text("Hinweis für Mobilgeräte (iOS)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "#fbbf24"))
                    }
                    Text("Der grafische 6-Band-Equalizer und das Desktop-Audio-Labor werden auf dem iPhone umgangen, damit eine unterbrechungsfreie Hintergrund- und Sperrbildschirm-Wiedergabe direkt über AVAudioSession garantiert bleibt.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#fde68a").opacity(0.90))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color(hex: "#f59e0b").opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: "#f59e0b").opacity(0.30), lineWidth: 1))

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Lautstärke-Normalisierung")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Einheitlicher Lautstärkepegel zwischen verschiedenen Alben")
                                .font(.system(size: 12.5))
                                .foregroundColor(Color.white.opacity(0.55))
                        }
                        Spacer()
                        Toggle("", isOn: $normalizationEnabled)
                            .labelsHidden()
                            .tint(Color(hex: "#1db954"))
                    }
                }
                .padding(18)
                .background(Color(hex: "#111114"))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))

                Spacer(minLength: 80)
            }
            .padding(18)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Equalizer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 3. Erscheinungsbild (Navigationsleiste, Haptik, Display)
public struct SettingsAppearanceView: View {
    @AppStorage("ui_haptics_enabled") private var hapticsEnabled: Bool = true
    @AppStorage("ui_keep_screen_awake") private var keepScreenAwake: Bool = false
    @AppStorage("navbar_icons_only") private var iconsOnly: Bool = false
    @AppStorage("navbar_scroll_minimize") private var scrollMinimize: Bool = true
    @AppStorage("navbar_custom_tabs") private var customTabsRaw: String = "home,library,radio,search"

    @State private var showNavbarSheet: Bool = false

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Design & Bedienung")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Navigationsleiste, Haptik und Bildschirmverhalten")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.55))
                }

                VStack(spacing: 14) {
                    Button(action: { showNavbarSheet = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "dock.rectangle")
                                .font(.system(size: 17))
                                .foregroundColor(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Untere Navigationsleiste anpassen")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Tabs (Startseite, Bibliothek, Radio, Podcasts, Suche) anordnen")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.white.opacity(0.55))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.35))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Divider().background(Color.white.opacity(0.08))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Haptisches Feedback")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Dezente Vibration beim Steuern und Antippen")
                                .font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.55))
                        }
                        Spacer()
                        Toggle("", isOn: $hapticsEnabled)
                            .labelsHidden()
                            .tint(Color(hex: "#1db954"))
                    }

                    Divider().background(Color.white.opacity(0.08))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Display bei Wiedergabe aktiv halten")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Verhindert automatische Sperre im Player")
                                .font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.55))
                        }
                        Spacer()
                        Toggle("", isOn: $keepScreenAwake)
                            .labelsHidden()
                            .tint(Color(hex: "#1db954"))
                            .onChange(of: keepScreenAwake) { enabled in
                                UIApplication.shared.isIdleTimerDisabled = enabled
                            }
                    }
                }
                .padding(18)
                .background(Color(hex: "#111114"))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))

                Spacer(minLength: 80)
            }
            .padding(18)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Design & Bedienung")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNavbarSheet) {
            NavbarSettingsSheet(
                iconsOnly: $iconsOnly,
                scrollMinimize: $scrollMinimize,
                customTabsRaw: $customTabsRaw
            )
        }
    }
}

// MARK: - 4. Player-Layout (Web SettingsDesignPlayer.tsx Parity)
public struct SettingsPlayerLayoutView: View {
    @AppStorage("port_music_player_design") private var playerDesign: String = "standard"

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Player-Layout")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Darstellung der Vollbild-Ansicht wählen")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.55))
                }

                layoutCard(
                    id: "standard",
                    title: "Standard-Player",
                    description: "Fokussiertes 1:1 Cover mit weichem Ambient-Verlauf, dynamischen Songtexten und kompakten Bedienelementen.",
                    icon: "rectangle.portrait.inset.filled"
                )

                layoutCard(
                    id: "big_cover",
                    title: "Cover-Fokus",
                    description: "Maximierte Artwork-Darstellung im Apple-Music-Stil mit Wischgesten zum Track-Wechsel.",
                    icon: "square.fill"
                )

                Spacer(minLength: 80)
            }
            .padding(18)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Player-Layout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func layoutCard(id: String, title: String, description: String, icon: String) -> some View {
        let isSelected = (playerDesign == id)
        return Button(action: {
            playerDesign = id
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.16) : Color.white.opacity(0.06))
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.system(size: 15.5, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Color(hex: "#1db954"))
                        }
                    }
                    Text(description)
                        .font(.system(size: 12.5))
                        .foregroundColor(Color.white.opacity(0.58))
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(16)
            .background(Color(hex: "#111114"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.50) : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 5. Offline-Downloads (Web SettingsDownloads.tsx Parity)
public struct SettingsDownloadsView: View {
    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @AppStorage("offline_wifi_only") private var offlineWifiOnly: Bool = true
    @State private var showClearDownloadsAlert: Bool = false
    @State private var showCacheClearedAlert: Bool = false

    public init() {}

    private var songDownloads: [Track] {
        offlineManager.allDownloadedTracks().filter { $0.album != "Podcast" && !$0.id.hasPrefix("pod_") }
    }

    private var podcastDownloads: [Track] {
        offlineManager.allDownloadedPodcastEpisodes()
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Offline-Downloads")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Heruntergeladene Titel, Podcast-Folgen und Speicherbelegung auf diesem iPhone")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.55))
                }

                // 3 KPI Karten wie auf SettingsDownloads.tsx
                HStack(spacing: 10) {
                    kpiCard(title: "Songs", value: "\(songDownloads.count)", icon: "music.note")
                    kpiCard(title: "Podcasts", value: "\(podcastDownloads.count)", icon: "mic.fill")
                    kpiCard(title: "Speicher", value: offlineManager.formattedTotalStorage(), icon: "internaldrive")
                }

                // Optionen Card
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nur über WLAN herunterladen")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Schont mobile Daten beim Speichern neuer Inhalte")
                                .font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.55))
                        }
                        Spacer()
                        Toggle("", isOn: $offlineWifiOnly)
                            .labelsHidden()
                            .tint(Color(hex: "#1db954"))
                    }

                    Divider().background(Color.white.opacity(0.08))

                    Button(action: {
                        URLCache.shared.removeAllCachedResponses()
                        PortImageCache.shared.clearAllCache()
                        showCacheClearedAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Temporären Bild- & Stream-Cache leeren")
                                .font(.system(size: 14.5, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    if !offlineManager.downloadedTrackIds.isEmpty {
                        Divider().background(Color.white.opacity(0.08))

                        Button(action: { showClearDownloadsAlert = true }) {
                            HStack {
                                Image(systemName: "trash")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "#ff5a5a"))
                                Text("Alle Downloads entfernen")
                                    .font(.system(size: 14.5, weight: .semibold))
                                    .foregroundColor(Color(hex: "#ff5a5a"))
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(18)
                .background(Color(hex: "#111114"))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))

                if !offlineManager.allDownloadedTracks().isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Heruntergeladene Inhalte (\(offlineManager.allDownloadedTracks().count))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.60))

                        VStack(spacing: 0) {
                            let all = offlineManager.allDownloadedTracks()
                            ForEach(Array(all.enumerated()), id: \.element.id) { idx, track in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text(track.album == "Podcast" ? "Podcast · \(track.artist)" : track.artist)
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.white.opacity(0.55))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Button(action: {
                                        offlineManager.removeDownload(trackId: track.id)
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.white.opacity(0.45))
                                            .frame(width: 32, height: 32)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)

                                if idx < all.count - 1 {
                                    Divider().background(Color.white.opacity(0.07))
                                }
                            }
                        }
                        .background(Color(hex: "#111114"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                }

                Spacer(minLength: 80)
            }
            .padding(18)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Offline-Downloads")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Alle Downloads löschen?", isPresented: $showClearDownloadsAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                offlineManager.removeAllDownloads()
            }
        } message: {
            Text("Möchtest du alle offline gespeicherten Songs und Podcast-Folgen von diesem iPhone entfernen?")
        }
        .alert("Cache geleert", isPresented: $showCacheClearedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Temporäre Zwischenspeicher für Bilder und Streams wurden erfolgreich bereinigt.")
        }
    }

    private func kpiCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11.5))
                    .foregroundColor(Color.white.opacity(0.55))
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.55))
            }
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color(hex: "#111114"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - 6. Sprache (Web SettingsLanguage.tsx Parity)
public struct SettingsLanguageView: View {
    @AppStorage("app_language") private var appLanguage: String = "de"

    private let languages: [(code: String, name: String, native: String)] = [
        ("de", "Deutsch", "Standard (Deutsch)"),
        ("en", "English", "English UI Labels")
    ]

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sprache")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Bevorzugte App-Sprache auswählen")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.55))
                }

                VStack(spacing: 0) {
                    ForEach(Array(languages.enumerated()), id: \.element.code) { idx, lang in
                        let isSel = appLanguage == lang.code
                        Button(action: {
                            appLanguage = lang.code
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lang.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(lang.native)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.white.opacity(0.50))
                                }
                                Spacer()
                                if isSel {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(hex: "#1db954"))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        if idx < languages.count - 1 {
                            Divider().background(Color.white.opacity(0.08))
                        }
                    }
                }
                .background(Color(hex: "#111114"))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))

                Spacer(minLength: 80)
            }
            .padding(18)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Sprache")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 7. Diagnose (Debug) mit Live NWPathMonitor Netzwerkstatus (Web SettingsDebug.tsx Parity + Network Monitor)
public struct SettingsDebugView: View {
    public let serverURL: String

    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var debugStore = DebugLogStore.shared

    private enum FilterCat: String, CaseIterable {
        case stream = "Playback / Stream"
        case system = "Netzwerk & System"
        case all = "Alle"
    }

    @State private var selectedCat: FilterCat = .all
    @State private var copiedFeedback: Bool = false
    @State private var isTestingServer: Bool = false
    @State private var serverCheckResult: String? = nil

    public init(serverURL: String) {
        self.serverURL = serverURL
    }

    private var filteredEntries: [DebugLogStore.Entry] {
        let base: [DebugLogStore.Entry]
        switch selectedCat {
        case .stream:
            base = debugStore.entries.filter { $0.category == .stream }
        case .system:
            base = debugStore.entries.filter { $0.category == .system }
        case .all:
            base = debugStore.entries
        }
        return base.reversed()
    }

    private var networkBadgeColor: Color {
        if !sessionManager.isPathSatisfied {
            return Color(hex: "#ff5a5a")
        }
        switch sessionManager.networkInterface {
        case .wifi, .wiredEthernet:
            return Color(hex: "#57e389")
        case .cellular:
            return Color(hex: "#38bdf8")
        case .other:
            return Color(hex: "#fbbf24")
        case .disconnected:
            return Color(hex: "#ff5a5a")
        }
    }

    private var networkIconName: String {
        if !sessionManager.isPathSatisfied { return "wifi.slash" }
        switch sessionManager.networkInterface {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .wiredEthernet: return "cable.connector"
        case .other: return "network"
        case .disconnected: return "wifi.slash"
        }
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Live-Netzwerkstatus und Diagnose-Protokoll (\(debugStore.entries.count) Ereignisse)")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.55))
                }

                // Live Netzwerk-Status Karte (WLAN / Mobile Daten / Kein Internet)
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(networkBadgeColor.opacity(0.16))
                                .frame(width: 40, height: 40)
                            Image(systemName: networkIconName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(networkBadgeColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Aktueller Netzwerkstatus")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text(sessionManager.networkInterface.rawValue)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(networkBadgeColor)
                        }

                        Spacer()

                        Text(sessionManager.isPathSatisfied ? "ONLINE" : "KEIN NETZ")
                            .font(.system(size: 10.5, weight: .bold))
                            .tracking(0.8)
                            .foregroundColor(networkBadgeColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(networkBadgeColor.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Divider().background(Color.white.opacity(0.08))

                    VStack(spacing: 8) {
                        statusMetricRow(label: "Verbindungsart", value: sessionManager.networkInterface.rawValue)
                        statusMetricRow(label: "NWPath Status", value: sessionManager.networkStatusRaw)
                        statusMetricRow(label: "App-Modus", value: sessionManager.isOfflineMode ? "Offline-Modus aktiv" : "Online (Streaming bereit)")
                        statusMetricRow(label: "Begrenzte Verbindung", value: sessionManager.isExpensiveConnection ? "Ja (Mobilfunk / Hotspot)" : "Nein")
                        statusMetricRow(label: "Datensparmodus", value: sessionManager.isConstrainedConnection ? "Aktiv" : "Deaktiviert")
                        statusMetricRow(
                            label: "Server-Adresse",
                            value: (sessionManager.serverURL ?? serverURL).isEmpty ? "-" : (sessionManager.serverURL ?? serverURL)
                        )
                    }

                    if let checkMsg = serverCheckResult {
                        Text(checkMsg)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.80))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button(action: { Task { await checkNetworkAndServer() } }) {
                        HStack(spacing: 8) {
                            if isTestingServer {
                                ProgressView().tint(.black).scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            Text("Netzwerk & Server jetzt prüfen")
                                .font(.system(size: 13.5, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isTestingServer)
                }
                .padding(16)
                .background(Color(hex: "#111114"))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))

                // Kategorie-Filter-Pills (wie SettingsDebug.tsx)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FilterCat.allCases, id: \.rawValue) { cat in
                            let count: Int = {
                                switch cat {
                                case .stream: return debugStore.entries.filter { $0.category == .stream }.count
                                case .system: return debugStore.entries.filter { $0.category == .system }.count
                                case .all: return debugStore.entries.count
                                }
                            }()
                            let isSel = selectedCat == cat
                            Button(action: { selectedCat = cat }) {
                                HStack(spacing: 5) {
                                    Text(cat.rawValue)
                                    Text("\(count)")
                                        .opacity(0.65)
                                }
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(isSel ? .black : Color.white.opacity(0.80))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .background(isSel ? Color.white : Color.white.opacity(0.06))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                // Aktionsleiste: Kopieren, Snapshot, Leeren
                HStack(spacing: 10) {
                    Button(action: copyLogs) {
                        HStack(spacing: 6) {
                            Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                            Text(copiedFeedback ? "Kopiert" : "Kopieren")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: recordSnapshot) {
                        HStack(spacing: 6) {
                            Image(systemName: "camera")
                            Text("Snapshot")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { debugStore.clear() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Leeren")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Monospace Log-Box (wie SettingsDebug.tsx)
                VStack(alignment: .leading, spacing: 6) {
                    if filteredEntries.isEmpty {
                        Text("Keine Ereignisse in dieser Kategorie.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.50))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(filteredEntries) { entry in
                            HStack(alignment: .top, spacing: 6) {
                                Text(debugStore.elapsedString(for: entry.timestamp))
                                    .foregroundColor(Color.white.opacity(0.35))
                                Text(entry.tag)
                                    .fontWeight(.bold)
                                    .foregroundColor(tagColor(entry.tag))
                                Text(entry.message)
                                    .foregroundColor(Color.white.opacity(0.86))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .font(.system(size: 11, design: .monospaced))
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#060608"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))

                Spacer(minLength: 80)
            }
            .padding(18)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Diagnose (Debug)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statusMetricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12.5))
                .foregroundColor(Color.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
        }
    }

    private func tagColor(_ tag: String) -> Color {
        if tag.contains("error") || tag.contains("fail") { return Color(hex: "#ff5a5a") }
        if tag.hasPrefix("net:") { return Color(hex: "#38bdf8") }
        if tag.hasPrefix("play:") { return Color(hex: "#57e389") }
        if tag.hasPrefix("call:") { return Color(hex: "#7ab8ff") }
        return Color(hex: "#e8eaed")
    }

    private func copyLogs() {
        UIPasteboard.general.string = debugStore.formattedAll(session: sessionManager, player: player)
        copiedFeedback = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copiedFeedback = false
        }
    }

    private func recordSnapshot() {
        let trackStr = player.currentTrack.map { "\($0.title) (\($0.artist)) live=\($0.isLive)" } ?? "kein Track"
        debugStore.log(
            tag: "snapshot",
            category: .system,
            message: "Netz=\(sessionManager.networkInterface.rawValue) (\(sessionManager.networkStatusRaw)), Offline=\(sessionManager.isOfflineMode), Player=\(player.isPlaying ? "playing" : "paused") · \(trackStr)"
        )
    }

    private func checkNetworkAndServer() async {
        isTestingServer = true
        let target = (sessionManager.serverURL ?? serverURL).trimmingCharacters(in: .whitespacesAndNewlines)
        let ping = await ServerPingService.shared.ping(rawInput: target)
        let reconnected = await sessionManager.retryConnection()

        await MainActor.run {
            self.isTestingServer = false
            switch ping {
            case .success(_, let latencyMs, let detail):
                let msg = "Netz: \(sessionManager.networkInterface.rawValue) · Server erreichbar in \(latencyMs) ms (\(detail))"
                self.serverCheckResult = msg
                debugStore.log(tag: "net:check", category: .system, message: msg)
            case .failure(let reason):
                let msg = "Netz: \(sessionManager.networkInterface.rawValue) · Serverfehler: \(reason)"
                self.serverCheckResult = msg
                debugStore.log(tag: "net:fail", category: .system, message: msg)
            case .idle, .pinging:
                self.serverCheckResult = "Prüfung abgeschlossen (reconnected=\(reconnected))."
            }
        }
    }
}
