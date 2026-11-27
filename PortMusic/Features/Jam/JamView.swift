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
    @State private var copiedCode: Bool = false

    private let stepOptions: [Double] = [1, 5, 10, 50]

    public init(serverURL: String) {
        self.serverURL = serverURL
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
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
        .task {
            await jam.fetchActiveJams(serverURL: serverURL)
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
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

    // MARK: - Lobby (Nicht im Jam)

    private var lobbyContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 1. Neuen Jam erstellen
            VStack(alignment: .leading, spacing: 14) {
                Text("Jam starten")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text("Höre gemeinsam mit Freunden in Echtzeit exakt synchronisiert über Server und Browser.")
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

                Toggle("Öffentlich anzeigen", isOn: $isPublicRoom)
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

                                Text("\(item.memberCount) \(item.memberCount == 1 ? "Gerät" : "Geräte") · \(item.mode == "master" ? "Nur Host" : "Demokratisch")")
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

    // MARK: - Aktive Jam Session

    private var activeSessionContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            sessionStatusCard
            nowPlayingJamCard
            globalVolumeCard
            nudgeCard
            timingVerificationCard
            connectedDevicesCard
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

                    HStack(spacing: 6) {
                        Circle()
                            .fill(jam.connectionState == .connected ? PortColors.successGreen : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(jam.minRttMs > 0
                             ? "\(jam.connectionState.displayTitle) · \(String(format: "%.1f ms", jam.minRttMs))"
                             : jam.connectionState.displayTitle)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.7))
                    }
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
                        Text("QR-Code")
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
                        Text(jam.jamMode == "master" ? "Nur Host" : "Demokratisch")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                } else {
                    Text(jam.jamMode == "master" ? "Nur Host" : "Demokratisch")
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

    private var nowPlayingJamCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                coverThumbnail
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(jam.currentTrack?.title ?? "Kein Titel aktiv")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(jam.currentTrack?.artist ?? "Wähle einen Song aus Bibliothek, Home oder Suche")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.62))
                        .lineLimit(1)
                }

                Spacer()
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
                    Label("Resync", systemImage: "arrow.triangle.2.circlepath")
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

    private var globalVolumeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Raumlautstärke")
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

    private var nudgeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Latenzabgleich (Nudge)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    jam.resetNudge()
                } label: {
                    Text("Reset")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    jam.applyNudge(deltaMs: -nudgeStepMs)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.2")
                        Text("-\(Int(nudgeStepMs)) ms")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text("\(jam.nudgeMs >= 0 ? "+" : "")\(Int(jam.nudgeMs.rounded())) ms")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(jam.nudgeMs < 0 ? "Früher" : (jam.nudgeMs > 0 ? "Später" : "Neutral"))
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.55))
                }

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    jam.applyNudge(deltaMs: nudgeStepMs)
                } label: {
                    HStack(spacing: 4) {
                        Text("+\(Int(nudgeStepMs)) ms")
                        Image(systemName: "chevron.right.2")
                    }
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
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    private var timingVerificationCard: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { _ in
            let serverMs = jam.estimatedServerTimeMs()
            let cycleMs = Int(serverMs.truncatingRemainder(dividingBy: 6000.0))
            let safeCycleMs = cycleMs < 0 ? cycleMs + 6000 : cycleMs
            let cycleSec = safeCycleMs / 1000
            let phase = safeCycleMs / 2000

            let phaseColor: Color = phase == 0 ? .red : (phase == 1 ? .green : .blue)
            let phaseName = phase == 0 ? "Rot" : (phase == 1 ? "Grün" : "Blau")

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Timing & Synchronisation")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Min-RTT Sync")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.6))
                }

                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(phaseColor)
                        .frame(width: 52, height: 52)
                        .overlay(
                            Text("\(cycleSec % 2)")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Farbzyklus: \(phaseName) (\(cycleSec % 2)s)")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)

                        Text("Offset: \(String(format: "%+.1f ms", jam.clockOffsetMs)) · Min-RTT: \(String(format: "%.1f ms", jam.minRttMs))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.7))

                        Text("Pure Probes: \(jam.pureProbeCount) (Verworfen: \(jam.impureProbeCount))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 18)
        }
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
                Text("Keine weiteren Geräte verbunden.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.55))
                    .padding(.vertical, 8)
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

                            let nudgeText = member.nudgeMs.map { String(format: "Nudge %+.0f ms", $0) } ?? ""
                            let rttText = member.rttMs > 0 ? String(format: "RTT %.1f ms", member.rttMs) : "Sync läuft"
                            Text([rttText, nudgeText].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.55))
                        }

                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - QR Code Sheet

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

                    Text("Teile diesen Code, damit andere Geräte in deinem Browser oder iPhone beitreten können.")
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
