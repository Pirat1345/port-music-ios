import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

public struct JamView: View {
    public let serverURL: String

    @ObservedObject private var jam = JamManager.shared
    @State private var newJamName: String = ""
    @State private var selectedMode: String = "democratic"
    @State private var isPublicRoom: Bool = true
    @State private var joinCodeInput: String = ""
    @State private var nudgeStepMs: Double = 10.0
    @State private var showQRSheet: Bool = false
    @State private var showLeaveConfirm: Bool = false
    @State private var showTimingDetails: Bool = false
    @State private var copiedCode: Bool = false

    private let stepOptions: [Double] = [5, 10, 25, 50]

    public init(serverURL: String) {
        self.serverURL = serverURL
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if jam.isInJam {
                        activeSessionContent
                    } else {
                        lobbyContent
                    }

                    Spacer(minLength: 160)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .refreshable {
                await jam.fetchActiveJams(serverURL: serverURL)
            }
        }
        .navigationTitle("Jam")
        .navigationBarTitleDisplayMode(.large)
        .task(id: jam.isInJam) {
            await jam.fetchActiveJams(serverURL: serverURL)
            // Automatische Aktualisierung in der Lobby alle 5 Sekunden, damit andere Jams sofort erscheinen
            while !Task.isCancelled && !jam.isInJam {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled || jam.isInJam { break }
                await jam.fetchActiveJams(serverURL: serverURL)
            }
        }
        .sheet(isPresented: $showQRSheet) {
            qrCodeSheet
        }
        .confirmationDialog(
            "Jam-Session wirklich verlassen?",
            isPresented: $showLeaveConfirm,
            titleVisibility: .visible
        ) {
            Button("Jam verlassen", role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                jam.leaveJam()
            }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    // MARK: - Lobby

    private var lobbyContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. Neuen Jam erstellen
            VStack(alignment: .leading, spacing: 14) {
                Text("Jam starten")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text("Höre gemeinsam in Echtzeit synchronisiert. Jedes Gerät kann Songs wählen, spulen, skippen, die Queue bearbeiten und die Raumlautstärke regeln.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.62))

                TextField("Raumname (optional)", text: $newJamName)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.white)

                Picker("Steuerung", selection: $selectedMode) {
                    Text("Alle steuern").tag("democratic")
                    Text("Nur Host").tag("master")
                }
                .pickerStyle(.segmented)

                Toggle("Öffentlich in Liste anzeigen", isOn: $isPublicRoom)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .tint(PortColors.successGreen)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task {
                        await jam.createJam(
                            name: newJamName,
                            mode: selectedMode,
                            isPublic: isPublicRoom,
                            serverURL: serverURL
                        )
                    }
                } label: {
                    HStack {
                        Image(systemName: "person.2.wave.2.fill")
                        Text("Jam erstellen")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                if let err = jam.errorMessage {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(PortColors.errorRed)
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 18)

            // 2. Per Code beitreten
            VStack(alignment: .leading, spacing: 12) {
                Text("Per Code beitreten")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 10) {
                    TextField("Jam-Code (z. B. jam_123456)", text: $joinCodeInput)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(.white)

                    Button {
                        let clean = joinCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !clean.isEmpty else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task { await jam.joinJam(jamId: clean, serverURL: serverURL) }
                    } label: {
                        Text("Beitreten")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 18)

            // 3. Öffentliche Jams
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Aktive Jams")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        Task { await jam.fetchActiveJams(serverURL: serverURL) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.75))
                    }
                }

                if jam.isLoadingJams && jam.activeJams.isEmpty {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if jam.activeJams.isEmpty {
                    Text("Aktuell laufen keine öffentlichen Jams.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                        .glassCard(cornerRadius: 14)
                } else {
                    ForEach(jam.activeJams) { item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.jamName ?? item.jamId)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Text("\(item.memberCount) \(item.memberCount == 1 ? "Gerät" : "Geräte") · \(item.mode == "master" ? "Nur Host" : "Alle steuern")")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.white.opacity(0.6))
                            }

                            Spacer()

                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                Task { await jam.joinJam(jamId: item.jamId, serverURL: serverURL) }
                            } label: {
                                Text("Beitreten")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .glassCard(cornerRadius: 14)
                    }
                }
            }
        }
    }

    // MARK: - Aktive Jam Session (ohne teure 30fps Blur-Animationen)

    private var activeSessionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sessionStatusCard
            JamNowPlayingCard(serverURL: serverURL)
            globalVolumeCard
            queueCard
            connectedDevicesCard
            nudgeCard
        }
    }

    private var sessionStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(jam.currentJamName ?? jam.currentJamId ?? "Jam Session")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    JamConnectionBadge()
                }

                Spacer()

                Button {
                    showLeaveConfirm = true
                } label: {
                    Text("Verlassen")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(PortColors.errorRed)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(PortColors.errorRed.opacity(0.14))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button {
                    if let code = jam.currentJamId {
                        UIPasteboard.general.string = code
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        copiedCode = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            copiedCode = false
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(jam.currentJamId ?? "")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        Image(systemName: copiedCode ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    showQRSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "qrcode")
                        Text("QR")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Spacer()

                if jam.isClockMaster {
                    Menu {
                        Button("Alle steuern") {
                            Task { await jam.setMode("democratic") }
                        }
                        Button("Nur Host steuert") {
                            Task { await jam.setMode("master") }
                        }
                    } label: {
                        Text(jam.jamMode == "master" ? "Nur Host" : "Alle steuern")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                } else {
                    Text(jam.jamMode == "master" ? "Nur Host" : "Alle steuern")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.65))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                }
            }

            if let err = jam.errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(PortColors.errorRed)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    private var globalVolumeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Raumlautstärke (Alle Geräte)", systemImage: jam.globalVolume <= 0.01 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int((jam.globalVolume * 100).rounded())) %")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.65))
            }

            Slider(
                value: Binding(
                    get: { jam.globalVolume },
                    set: { jam.setGlobalVolume($0) }
                ),
                in: 0.0...1.0
            )
            .tint(.white)
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    private var queueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Gemeinsame Warteschlange")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(jam.queueTracks.count)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.6))
            }

            if jam.queueTracks.isEmpty {
                Text("Starte einen Song oder eine Playlist in Home, Suche oder Bibliothek – die komplette Queue wird für alle synchronisiert.")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.55))
                    .padding(.vertical, 6)
            } else {
                ForEach(Array(jam.queueTracks.prefix(30).enumerated()), id: \.offset) { _, track in
                    let isCurrent = (track.id == jam.currentTrack?.id)
                    Button {
                        guard jam.canControlPlayback else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        jam.playTrackInJam(track, queue: jam.queueTracks)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isCurrent ? "waveform" : "music.note")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(isCurrent ? PortColors.successGreen : Color.white.opacity(0.5))
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.system(size: 14, weight: isCurrent ? .bold : .medium))
                                    .foregroundColor(isCurrent ? PortColors.successGreen : .white)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.white.opacity(0.6))
                                    .lineLimit(1)
                            }

                            Spacer()

                            if !track.duration.isEmpty && track.duration != "0:00" {
                                Text(track.duration)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.45))
                            }
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!jam.canControlPlayback)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    private var connectedDevicesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Verbundene Geräte")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(jam.members.count)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.6))
            }

            if jam.members.isEmpty {
                Text("Warte auf Verbindung...")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.55))
                    .padding(.vertical, 6)
            } else {
                ForEach(jam.members) { member in
                    let isHost = (jam.clockDeviceId == member.clientId)
                    HStack(spacing: 10) {
                        Circle()
                            .fill(PortColors.successGreen)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(member.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                if isHost {
                                    Text("Host")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.yellow)
                                        .clipShape(Capsule())
                                }
                            }

                            let nudgeText = member.nudgeMs.map { abs($0) >= 1 ? String(format: "Nudge %+.0f ms", $0) : "" } ?? ""
                            let rttText = member.rttMs > 0 ? String(format: "RTT %.1f ms", member.rttMs) : "Synchron"
                            Text([rttText, nudgeText].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.55))
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    private var nudgeCard: some View {
        DisclosureGroup("Audio-Feintuning & Sync-Info", isExpanded: $showTimingDetails) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Latenzabgleich (z. B. für Bluetooth)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.65))
                    Spacer()
                    Button("Reset") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        jam.resetNudge()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.8))
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        jam.applyNudge(deltaMs: -nudgeStepMs)
                    } label: {
                        Text("-\(Int(nudgeStepMs)) ms")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("\(jam.nudgeMs >= 0 ? "+" : "")\(Int(jam.nudgeMs.rounded())) ms")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        jam.applyNudge(deltaMs: nudgeStepMs)
                    } label: {
                        Text("+\(Int(nudgeStepMs)) ms")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button {
                        if let idx = stepOptions.firstIndex(of: nudgeStepMs) {
                            nudgeStepMs = stepOptions[(idx + 1) % stepOptions.count]
                        } else {
                            nudgeStepMs = 10
                        }
                    } label: {
                        Text("±\(Int(nudgeStepMs))")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }

                JamTelemetryFooter()
            }
            .padding(.top, 10)
        }
        .tint(.white)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.white)
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - QR Sheet

    private var qrCodeSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 20) {
                    if let code = jam.currentJamId, let qrImg = generateQRCode(from: code) {
                        Image(uiImage: qrImg)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }

                    Text(jam.currentJamId ?? "")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    Text("Teile diesen Code, damit Freunde auf dem iPhone oder im Browser direkt beitreten können.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .navigationTitle("Jam teilen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { showQRSheet = false }
                }
            }
        }
    }

    private func generateQRCode(from text: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Isolierte Subviews (damit Fortschritts-/RTT-Ticks niemals die gesamte View neu zeichnen)

private struct JamConnectionBadge: View {
    @ObservedObject private var jam = JamManager.shared
    @ObservedObject private var progress = JamProgressStore.shared

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(jam.connectionState == .connected ? PortColors.successGreen : Color.orange)
                .frame(width: 8, height: 8)
            Text(progress.minRttMs > 0
                 ? "\(jam.connectionState.displayTitle) · \(String(format: "%.0f ms", progress.minRttMs))"
                 : jam.connectionState.displayTitle)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.7))
        }
    }
}

private struct JamTelemetryFooter: View {
    @ObservedObject private var progress = JamProgressStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Clock Offset: \(String(format: "%+.1f ms", progress.clockOffsetMs)) · Min-RTT: \(String(format: "%.1f ms", progress.minRttMs))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.6))
            Text("Pure Probes: \(progress.pureProbeCount) (Verworfen: \(progress.impureProbeCount))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.45))
        }
    }
}

private struct JamNowPlayingCard: View {
    let serverURL: String
    @ObservedObject private var jam = JamManager.shared
    @ObservedObject private var progress = JamProgressStore.shared

    @State private var isDraggingSeek: Bool = false
    @State private var dragPosition: Double = 0.0

    private var displayedPos: Double {
        isDraggingSeek ? dragPosition : progress.currentPosition
    }

    private var totalDur: Double {
        let d = progress.duration > 0 ? progress.duration : (jam.currentTrack?.durationSeconds ?? 0)
        return max(d, displayedPos, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                coverThumbnail
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(jam.currentTrack?.title ?? "Kein Titel aktiv")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(jam.currentTrack?.artist ?? "Wähle einen Song aus Home, Suche oder Bibliothek")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.62))
                        .lineLimit(1)
                }

                Spacer()
            }

            if jam.currentTrack != nil {
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { displayedPos },
                            set: { val in
                                isDraggingSeek = true
                                dragPosition = val
                            }
                        ),
                        in: 0.0...totalDur,
                        onEditingChanged: { editing in
                            if !editing {
                                isDraggingSeek = false
                                jam.seek(to: dragPosition)
                            }
                        }
                    )
                    .tint(.white)
                    .disabled(!jam.canControlPlayback)

                    HStack {
                        Text(formatSec(displayedPos))
                        Spacer()
                        Text(formatSec(progress.duration > 0 ? progress.duration : (jam.currentTrack?.durationSeconds ?? 0)))
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.55))
                }
            }

            HStack(spacing: 24) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    jam.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(!jam.canControlPlayback)
                .opacity(jam.canControlPlayback ? 1.0 : 0.35)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    jam.togglePlayPause()
                } label: {
                    Image(systemName: jam.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(!jam.canControlPlayback)
                .opacity(jam.canControlPlayback ? 1.0 : 0.35)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    jam.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(!jam.canControlPlayback)
                .opacity(jam.canControlPlayback ? 1.0 : 0.35)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    jam.resyncClock()
                } label: {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    @ViewBuilder
    private var coverThumbnail: some View {
        if let rawCover = jam.currentTrack?.coverUrl,
           let url = resolveCoverURL(rawCover, serverURL: serverURL) {
            PortCachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.white.opacity(0.1)
            }
        } else {
            ZStack {
                Color.white.opacity(0.1)
                Image(systemName: "music.note")
                    .foregroundColor(Color.white.opacity(0.5))
            }
        }
    }

    private func formatSec(_ sec: Double) -> String {
        let total = max(0, Int(sec.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
