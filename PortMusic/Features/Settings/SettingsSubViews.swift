import SwiftUI
import UIKit

// MARK: - 1. Apple-like Offline-Downloads & Speicher (Settings -> Auf diesem Gerät)
public struct SettingsDownloadsView: View {
    public let serverURL: String

    @ObservedObject private var offlineManager = OfflineDownloadManager.shared
    @AppStorage("offline_wifi_only") private var offlineWifiOnly: Bool = true
    @State private var cacheSizeBytes: Int64 = 0
    @State private var showClearDownloadsAlert: Bool = false
    @State private var showCacheClearedAlert: Bool = false

    public init(serverURL: String = "") {
        self.serverURL = serverURL
    }

    private var songBytes: Int64 { offlineManager.songsStorageBytes() }
    private var podcastBytes: Int64 { offlineManager.podcastsStorageBytes() }
    private var totalWithCache: Int64 { max(1, songBytes + podcastBytes + cacheSizeBytes) }

    private var allDownloaded: [Track] {
        offlineManager.allDownloadedTracks()
    }

    private var songCount: Int {
        allDownloaded.filter { $0.album != "Podcast" && !$0.id.hasPrefix("pod_") }.count
    }

    private var podcastCount: Int {
        offlineManager.allDownloadedPodcastEpisodes().count
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: max(0, bytes))
    }

    public var body: some View {
        List {
            // 1. Apple iPhone-Speicher Stil Grafik
            Section(
                header: Text("Speicher auf diesem iPhone"),
                footer: Text("Heruntergeladene Titel und Podcast-Folgen stehen auch komplett ohne Internetverbindung zur Verfügung.")
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Port Music Speicher")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(formatBytes(songBytes + podcastBytes + cacheSizeBytes))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    // Mehrfarbige Apple Speicherleiste
                    GeometryReader { geo in
                        let w = max(1, geo.size.width)
                        let sRatio = CGFloat(songBytes) / CGFloat(totalWithCache)
                        let pRatio = CGFloat(podcastBytes) / CGFloat(totalWithCache)
                        let cRatio = CGFloat(cacheSizeBytes) / CGFloat(totalWithCache)
                        let hasAny = (songBytes + podcastBytes + cacheSizeBytes) > 0

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.10))

                            if hasAny {
                                HStack(spacing: 1.5) {
                                    if songBytes > 0 {
                                        Rectangle()
                                            .fill(Color(hex: "#0a84ff"))
                                            .frame(width: max(4, w * sRatio))
                                    }
                                    if podcastBytes > 0 {
                                        Rectangle()
                                            .fill(Color(hex: "#bf5af2"))
                                            .frame(width: max(4, w * pRatio))
                                    }
                                    if cacheSizeBytes > 0 {
                                        Rectangle()
                                            .fill(Color(hex: "#ff9f0a"))
                                            .frame(width: max(4, w * cRatio))
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }
                    }
                    .frame(height: 14)

                    // Legende
                    HStack(spacing: 14) {
                        legendItem(color: Color(hex: "#0a84ff"), label: "Songs (\(songCount))")
                        legendItem(color: Color(hex: "#bf5af2"), label: "Podcasts (\(podcastCount))")
                        legendItem(color: Color(hex: "#ff9f0a"), label: "Cache (\(formatBytes(cacheSizeBytes)))")
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color(white: 0.11))

            // 2. Einstellungen & Cache
            Section(header: Text("Download-Einstellungen")) {
                Toggle("Nur über WLAN herunterladen", isOn: $offlineWifiOnly)
                    .tint(Color(hex: "#30d158"))

                Button {
                    URLCache.shared.removeAllCachedResponses()
                    PortImageCache.shared.clearAllCache()
                    cacheSizeBytes = PortImageCache.shared.calculateDiskCacheSize()
                    showCacheClearedAlert = true
                } label: {
                    HStack {
                        Text("Bild- & Stream-Cache leeren")
                            .foregroundColor(.white)
                        Spacer()
                        Text(formatBytes(cacheSizeBytes))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                if !allDownloaded.isEmpty {
                    Button(role: .destructive) {
                        showClearDownloadsAlert = true
                    } label: {
                        Text("Alle Offline-Downloads entfernen")
                    }
                }
            }
            .listRowBackground(Color(white: 0.11))

            // 3. Heruntergeladene Inhalte Liste (mit Wisch-Löschen)
            if !allDownloaded.isEmpty {
                Section(header: Text("Geladene Medien (\(allDownloaded.count))")) {
                    ForEach(allDownloaded) { track in
                        HStack(spacing: 12) {
                            PortCoverImage(
                                coverUrl: track.coverUrl,
                                serverURL: serverURL,
                                placeholderIcon: track.album == "Podcast" ? "mic.fill" : "music.note",
                                trackId: track.id
                            )
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(track.album == "Podcast" ? "Podcast · \(track.artist)" : track.artist)
                                    .font(.system(size: 12.5))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                offlineManager.removeDownload(trackId: track.id)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
                .listRowBackground(Color(white: 0.11))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Offline-Downloads")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            cacheSizeBytes = PortImageCache.shared.calculateDiskCacheSize()
        }
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
            Text("Zwischengespeicherte Bilder und Streams wurden erfolgreich entfernt.")
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - 2. Wiedergabe & Qualität (Apple insetGrouped + Web Parity)
public struct SettingsPlaybackView: View {
    @AppStorage("playback_autoplay_enabled") private var autoplayEnabled: Bool = true
    @AppStorage("playback_skip_timeout") private var skipTimeout: Int = 10
    @AppStorage("portmusic_audio_quality") private var audioQuality: String = "high"

    private let skipOptions: [(value: Int, label: String)] = [
        (0, "Aus"), (3, "3 Sekunden"), (5, "5 Sekunden"), (7, "7 Sekunden"), (9, "9 Sekunden"), (10, "10 Sekunden"), (15, "15 Sekunden")
    ]

    public init() {}

    private var normalizedQuality: String {
        audioQuality == "low" || audioQuality == "normal" ? "low" : "high"
    }

    public var body: some View {
        List {
            Section(
                header: Text("Wiedergabeverhalten"),
                footer: Text("Autoplay spielt passende Empfehlungen weiter, sobald deine aktuelle Warteschlange endet.")
            ) {
                Toggle("Autoplay", isOn: $autoplayEnabled)
                    .tint(Color(hex: "#30d158"))

                Picker("Defekte Songs überspringen", selection: $skipTimeout) {
                    ForEach(skipOptions, id: \.value) { opt in
                        Text(opt.label).tag(opt.value)
                    }
                }
                .foregroundColor(.white)
            }
            .listRowBackground(Color(white: 0.11))

            Section(
                header: Text("Streaming-Qualität"),
                footer: Text(normalizedQuality == "high"
                             ? "High Quality liefert maximal verfügbare AAC/MP4-Qualität (128–256 kbps)."
                             : "Low Quality nutzt gezielt den sparsamen Low-Bitrate-Stream (~48–64 kbps HE-AAC).")
            ) {
                qualityRow(id: "high", title: "High", subtitle: "Beste Klangqualität (128–256 kbps AAC)")
                qualityRow(id: "low", title: "Low", subtitle: "Datensparend (~48–64 kbps HE-AAC)")
            }
            .listRowBackground(Color(white: 0.11))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Wiedergabe")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func qualityRow(id: String, title: String, subtitle: String) -> some View {
        Button {
            audioQuality = id
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if normalizedQuality == id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#0a84ff"))
                }
            }
        }
    }
}

// MARK: - 3. Klang & Normalisierung
public struct SettingsEqualizerView: View {
    @AppStorage("playback_normalization_enabled") private var normalizationEnabled: Bool = false

    public init() {}

    public var body: some View {
        List {
            Section(
                header: Text("Lautstärke"),
                footer: Text("Passt unterschiedliche Titel und Alben an ein gleichmäßiges Lautstärkeniveau an.")
            ) {
                Toggle("Lautstärke-Normalisierung", isOn: $normalizationEnabled)
                    .tint(Color(hex: "#30d158"))
            }
            .listRowBackground(Color(white: 0.11))

            Section(
                header: Text("Mobilgerät-Hinweis"),
                footer: Text("Der 6-Band-Equalizer der Web-App wird auf dem iPhone umgangen, damit eine unterbrechungsfreie Hintergrund- und Sperrbildschirm-Wiedergabe über iOS AVAudioSession gewährleistet bleibt.")
            ) {
                HStack(spacing: 12) {
                    Image(systemName: "iphone.gen3")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#ff9f0a"))
                    Text("Hardware-optimierte iOS Audio-Wiedergabe aktiv")
                        .font(.system(size: 14.5))
                        .foregroundColor(.white)
                }
            }
            .listRowBackground(Color(white: 0.11))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Klang & Normalisierung")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 4. Player-Layout
public struct SettingsPlayerLayoutView: View {
    @AppStorage("port_music_player_design") private var playerDesign: String = "standard"

    public init() {}

    public var body: some View {
        List {
            Section(header: Text("Vollbild-Player")) {
                layoutRow(
                    id: "standard",
                    title: "Standard-Player",
                    subtitle: "1:1 Cover mit weichem Hintergrundverlauf und Songtext-Ansicht"
                )
                layoutRow(
                    id: "big_cover",
                    title: "Cover-Fokus",
                    subtitle: "Vergrößerte Artwork-Darstellung im Apple-Music-Stil"
                )
            }
            .listRowBackground(Color(white: 0.11))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Player-Layout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func layoutRow(id: String, title: String, subtitle: String) -> some View {
        Button {
            playerDesign = id
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if playerDesign == id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#0a84ff"))
                }
            }
        }
    }
}

// MARK: - 5. Sprache
public struct SettingsLanguageView: View {
    @AppStorage("app_language") private var appLanguage: String = "de"

    private let languages: [(code: String, name: String, detail: String)] = [
        ("de", "Deutsch", "Systemstandard"),
        ("en", "English", "English UI")
    ]

    public init() {}

    public var body: some View {
        List {
            Section(header: Text("App-Sprache")) {
                ForEach(languages, id: \.code) { lang in
                    Button {
                        appLanguage = lang.code
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                Text(lang.detail)
                                    .font(.system(size: 12.5))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if appLanguage == lang.code {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: "#0a84ff"))
                            }
                        }
                    }
                }
            }
            .listRowBackground(Color(white: 0.11))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Sprache")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 6. Diagnose (Debug) mit Live NWPathMonitor Netzwerkstatus (Apple insetGrouped Style)
public struct SettingsDebugView: View {
    public let serverURL: String

    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var debugStore = DebugLogStore.shared

    private enum FilterCat: String, CaseIterable {
        case all = "Alle"
        case stream = "Playback / Stream"
        case system = "Netzwerk & System"
    }

    @State private var selectedCat: FilterCat = .all
    @State private var copiedFeedback: Bool = false
    @State private var isTestingServer: Bool = false
    @State private var serverCheckResult: String? = nil

    public init(serverURL: String) {
        self.serverURL = serverURL
    }

    private var filteredEntries: [DebugLogStore.Entry] {
        switch selectedCat {
        case .stream:
            return debugStore.entries.filter { $0.category == .stream }.reversed()
        case .system:
            return debugStore.entries.filter { $0.category == .system }.reversed()
        case .all:
            return debugStore.entries.reversed()
        }
    }

    private var statusColor: Color {
        if !sessionManager.isPathSatisfied { return Color(hex: "#ff453a") }
        switch sessionManager.networkInterface {
        case .wifi, .wiredEthernet: return Color(hex: "#30d158")
        case .cellular: return Color(hex: "#0a84ff")
        case .other: return Color(hex: "#ff9f0a")
        case .disconnected: return Color(hex: "#ff453a")
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
        List {
            // 1. Live Netzwerkstatus
            Section(
                header: Text("Netzwerkstatus (Live)"),
                footer: Text("Überwacht laufend mit Apple NWPathMonitor, ob WLAN, Mobile Daten oder keine Internetverbindung anliegt.")
            ) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(statusColor.opacity(0.18))
                            .frame(width: 34, height: 34)
                        Image(systemName: networkIconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(statusColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sessionManager.networkInterface.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Text("NWPath: \(sessionManager.networkStatusRaw)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(sessionManager.isPathSatisfied ? "ONLINE" : "OFFLINE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.16))
                        .clipShape(Capsule())
                }
                .padding(.vertical, 3)

                metricRow("App-Modus", sessionManager.isOfflineMode ? "Offline-Modus aktiv" : "Online (Streaming bereit)")
                metricRow("Mobilfunk / Begrenzt", sessionManager.isExpensiveConnection ? "Ja" : "Nein")
                metricRow("Datensparmodus", sessionManager.isConstrainedConnection ? "Aktiv" : "Aus")
                metricRow("Server-URL", (sessionManager.serverURL ?? serverURL).isEmpty ? "-" : (sessionManager.serverURL ?? serverURL))

                if let check = serverCheckResult {
                    Text(check)
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                }

                Button {
                    Task { await checkNetworkAndServer() }
                } label: {
                    HStack {
                        if isTestingServer {
                            ProgressView().tint(Color(hex: "#0a84ff")).scaleEffect(0.85)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(Color(hex: "#0a84ff"))
                        }
                        Text("Netzwerk & Server testen")
                            .foregroundColor(Color(hex: "#0a84ff"))
                            .fontWeight(.medium)
                    }
                }
                .disabled(isTestingServer)
            }
            .listRowBackground(Color(white: 0.11))

            // 2. Diagnose-Protokoll Steuerung
            Section(header: Text("Diagnose-Protokoll (\(debugStore.entries.count))")) {
                Picker("Filter", selection: $selectedCat) {
                    ForEach(FilterCat.allCases, id: \.rawValue) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    copyLogs()
                } label: {
                    Label(copiedFeedback ? "In Zwischenablage kopiert" : "Protokoll kopieren", systemImage: copiedFeedback ? "checkmark" : "doc.on.doc")
                        .foregroundColor(.white)
                }

                Button {
                    recordSnapshot()
                } label: {
                    Label("Zustands-Snapshot aufnehmen", systemImage: "camera")
                        .foregroundColor(.white)
                }

                Button(role: .destructive) {
                    debugStore.clear()
                } label: {
                    Label("Protokoll leeren", systemImage: "trash")
                }
            }
            .listRowBackground(Color(white: 0.11))

            // 3. Log-Einträge
            Section(header: Text("Ereignisse")) {
                if filteredEntries.isEmpty {
                    Text("Keine Einträge in dieser Kategorie.")
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filteredEntries.prefix(120)) { entry in
                        HStack(alignment: .top, spacing: 6) {
                            Text(debugStore.elapsedString(for: entry.timestamp))
                                .foregroundColor(.secondary)
                            Text(entry.tag)
                                .fontWeight(.bold)
                                .foregroundColor(tagColor(entry.tag))
                            Text(entry.message)
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.system(size: 11, design: .monospaced))
                    }
                }
            }
            .listRowBackground(Color(white: 0.08))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Diagnose (Debug)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .font(.system(size: 14))
    }

    private func tagColor(_ tag: String) -> Color {
        if tag.contains("error") || tag.contains("fail") { return Color(hex: "#ff453a") }
        if tag.hasPrefix("net:") { return Color(hex: "#0a84ff") }
        if tag.hasPrefix("play:") { return Color(hex: "#30d158") }
        return .white
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
                let msg = "\(sessionManager.networkInterface.rawValue) · Server OK in \(latencyMs) ms (\(detail))"
                self.serverCheckResult = msg
                debugStore.log(tag: "net:check", category: .system, message: msg)
            case .failure(let reason):
                let msg = "\(sessionManager.networkInterface.rawValue) · Fehler: \(reason)"
                self.serverCheckResult = msg
                debugStore.log(tag: "net:fail", category: .system, message: msg)
            case .idle, .pinging:
                self.serverCheckResult = "Prüfung abgeschlossen (reconnected=\(reconnected))."
            }
        }
    }
}
