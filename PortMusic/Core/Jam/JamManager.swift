import Foundation
import Combine
import UIKit

@MainActor
public final class JamManager: ObservableObject {
    public static let shared = JamManager()

    // MARK: - BeatSync NTP Konstanten (Schlank ohne UI-Lag oder Datenspitzen)
    public static let maxNTPMeasurements: Int = 12
    public static let burstProbeCount: Int = 6
    public static let initialNTPIntervalMs: Double = 250.0
    public static let steadyNTPIntervalMs: Double = 4000.0
    public static let probeGapMs: Double = 25.0
    public static let probeGapToleranceMs: Double = 8.0
    public static let staleResponseTimeoutMs: Double = 10_000.0

    // MARK: - Low-Frequency Session State (keine Timer-Updates hierauf!)
    @Published public private(set) var isInJam: Bool = false
    @Published public private(set) var currentJamId: String? = nil
    @Published public private(set) var currentJamName: String? = nil
    @Published public private(set) var jamMode: String = "democratic"
    @Published public private(set) var isPublic: Bool = true
    @Published public private(set) var clockDeviceId: String? = nil
    @Published public private(set) var connectionState: JamConnectionState = .disconnected
    @Published public private(set) var activeJams: [ActiveJamDTO] = []
    @Published public private(set) var isLoadingJams: Bool = false
    @Published public private(set) var members: [JamWSClientInfo] = []
    @Published public private(set) var queueTracks: [Track] = []
    @Published public private(set) var currentTrack: Track? = nil
    @Published public private(set) var isPlaying: Bool = false
    @Published public var globalVolume: Double = 1.0
    @Published public private(set) var nudgeMs: Double = 0.0
    @Published public var errorMessage: String? = nil

    public let clientId: String
    public var displayName: String {
        SessionManager.shared.currentUser?.displayName
            ?? SessionManager.shared.currentUser?.username
            ?? UIDevice.current.name
    }

    public var isClockMaster: Bool {
        if let cid = clockDeviceId, cid == clientId {
            return true
        }
        return members.first(where: { $0.clientId == clientId })?.isAdmin ?? false
    }

    public var canControlPlayback: Bool {
        if jamMode != "master" { return true }
        return isClockMaster
    }

    // MARK: - Interne Clock & Socket State
    private var webSocketTask: URLSessionWebSocketTask? = nil
    private var wsSession: URLSession? = nil
    private var wsDelegateProxy: JamWebSocketDelegate? = nil
    private var activeServerURL: String = ""
    private var isIntentionalDisconnect: Bool = false
    private var reconnectAttempts: Int = 0
    private var reconnectWorkItem: DispatchWorkItem? = nil
    private var ntpTimerWorkItem: DispatchWorkItem? = nil
    private var volumeThrottleWorkItem: DispatchWorkItem? = nil
    private var pendingVolumeToSend: Double? = nil

    private let clockAnchorWallMs: Double
    private let clockAnchorUptimeMs: Double

    private var probeGroupCounter: UInt64 = 0
    private var pendingProbes: [String: Double] = [:]
    private var pendingFirstProbe: JamNTPMeasurement? = nil
    private var pendingFirstProbeGroupId: UInt64? = nil
    private var measurements: [JamNTPMeasurement] = []
    private var rawMinRttMs: Double = .infinity
    private var internalClockOffsetMs: Double = 0.0
    private var internalMinRttMs: Double = 0.0
    private var pureCount: Int = 0
    private var impureCount: Int = 0
    private var lastTelemetryPublishUptimeMs: Double = 0.0
    private var lastProbeSentUptimeMs: Double = 0.0
    private var lastLoadedPlaybackSignature: String? = nil

    private let nudgeStorageKey = "port_music_jam_nudge_ms"
    private let engine = JamAudioEngine.shared
    private let progressStore = JamProgressStore.shared

    private init() {
        self.clientId = "ios_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10)
        self.clockAnchorWallMs = Date().timeIntervalSince1970 * 1000.0
        self.clockAnchorUptimeMs = ProcessInfo.processInfo.systemUptime * 1000.0

        if UserDefaults.standard.object(forKey: nudgeStorageKey) != nil {
            let saved = UserDefaults.standard.double(forKey: nudgeStorageKey)
            if saved.isFinite {
                self.nudgeMs = saved
            }
        }

        setupAudioEngineCallbacks()
        setupAppLifecycleObservers()
    }

    private func setupAudioEngineCallbacks() {
        engine.serverTimeProvider = { [weak self] in
            self?.estimatedServerTimeMs() ?? (Date().timeIntervalSince1970 * 1000.0)
        }
        engine.onTrackEnded = { [weak self] finishedTrackId in
            Task { @MainActor [weak self] in
                self?.handleLocalTrackEnded(finishedTrackId: finishedTrackId)
            }
        }
        engine.onPlaybackStateChanged = { [weak self] playing, pos, dur, isMilestone in
            Task { @MainActor [weak self] in
                guard let self = self, self.isInJam else { return }
                let playingChanged = (self.isPlaying != playing)
                if playingChanged {
                    self.isPlaying = playing
                }
                self.progressStore.currentPosition = pos
                if dur > 0 {
                    self.progressStore.duration = dur
                }
                AudioPlayerManager.shared.applyJamExternalPlaybackState(
                    track: self.currentTrack,
                    isPlaying: playing,
                    currentTime: pos,
                    duration: dur > 0 ? dur : (self.currentTrack?.durationSeconds ?? 0),
                    queue: self.queueTracks,
                    shouldUpdateNowPlaying: isMilestone || playingChanged
                )
            }
        }
        engine.onAudioRouteChanged = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, self.isInJam, self.connectionState == .connected else { return }
                self.sendCodedProbePair()
            }
        }
    }

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isInJam else { return }
                if self.connectionState == .connected {
                    self.sendCodedProbePair()
                    self.requestSync()
                } else {
                    self.connectWebSocket()
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .portMusicDidReconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isInJam else { return }
                if self.connectionState != .connected {
                    self.connectWebSocket()
                }
            }
        }
    }

    // MARK: - Monotonic Epoch & NTP Server Estimate

    public func monotonicEpochNowMs() -> Double {
        let nowUptimeMs = ProcessInfo.processInfo.systemUptime * 1000.0
        return clockAnchorWallMs + (nowUptimeMs - clockAnchorUptimeMs)
    }

    public func estimatedServerTimeMs() -> Double {
        return monotonicEpochNowMs() + internalClockOffsetMs
    }

    // MARK: - REST API (/api/jams)

    private func cleanHTTPBase(_ serverURL: String) -> String {
        var base = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !base.hasPrefix("http://") && !base.hasPrefix("https://") {
            base = "http://" + base
        }
        return base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func authorizedRequest(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 10.0
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("PortMusic-iOS/1.0", forHTTPHeaderField: "User-Agent")
        if let tok = SessionManager.shared.currentToken, !tok.isEmpty {
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            req.setValue(tok, forHTTPHeaderField: "x-session-token")
        }
        if let body = body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return req
    }

    public func fetchActiveJams(serverURL: String) async {
        let base = cleanHTTPBase(serverURL)
        guard !base.isEmpty, let url = URL(string: "\(base)/api/jams") else { return }

        isLoadingJams = true
        defer { isLoadingJams = false }

        do {
            let (data, response) = try await URLSession.shared.data(for: authorizedRequest(url: url))
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
            let decoded = try JSONDecoder().decode(JamsListResponse.self, from: data)
            let filtered = decoded.jams.filter { $0.isPublic || $0.jamId == currentJamId }
            self.activeJams = filtered

            if let curId = currentJamId, let cur = decoded.jams.first(where: { $0.jamId == curId }) {
                self.clockDeviceId = cur.clockDeviceId
                self.jamMode = cur.mode
                if let name = cur.jamName, !name.isEmpty {
                    self.currentJamName = name
                }
            }
        } catch {
            print("[JamManager] fetchActiveJams error: \(error)")
        }
    }

    public func createJam(
        name: String? = nil,
        mode: String = "democratic",
        isPublic: Bool = true,
        serverURL: String
    ) async {
        let base = cleanHTTPBase(serverURL)
        guard !base.isEmpty, let url = URL(string: "\(base)/api/jams/create") else {
            self.errorMessage = "Ungültige Server-URL."
            return
        }

        let resolvedName = (name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? "Jam von \(displayName)"
        let payload = CreateJamRequest(
            jamName: resolvedName,
            mode: mode,
            isPublic: isPublic,
            clockDeviceId: clientId
        )

        do {
            let body = try JSONEncoder().encode(payload)
            let (data, response) = try await URLSession.shared.data(for: authorizedRequest(url: url, method: "POST", body: body))
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                self.errorMessage = "Jam konnte nicht erstellt werden."
                return
            }
            let created = try JSONDecoder().decode(CreateJamResponse.self, from: data)

            let handoffTrack = AudioPlayerManager.shared.currentTrack
            let handoffQueue = AudioPlayerManager.shared.queue

            enterSession(
                jamId: created.jamId,
                jamName: created.jamName,
                mode: created.mode,
                isPublic: created.isPublic,
                clockDeviceId: clientId,
                serverURL: base
            )

            await fetchActiveJams(serverURL: base)

            if let track = handoffTrack, !track.isLive {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard let self = self, self.isInJam, self.currentJamId == created.jamId else { return }
                    self.playTrackInJam(track, queue: handoffQueue.isEmpty ? [track] : handoffQueue)
                }
            }
        } catch {
            self.errorMessage = "Verbindungsfehler beim Erstellen des Jams."
            print("[JamManager] createJam error: \(error)")
        }
    }

    public func joinJam(jamId: String, serverURL: String) async {
        let cleanedId = jamId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedId.isEmpty else { return }

        let base = cleanHTTPBase(serverURL)
        guard !base.isEmpty else {
            self.errorMessage = "Keine Server-URL konfiguriert."
            return
        }

        if let existing = activeJams.first(where: { $0.jamId == cleanedId }) {
            enterSession(
                jamId: existing.jamId,
                jamName: existing.jamName ?? cleanedId,
                mode: existing.mode,
                isPublic: existing.isPublic,
                clockDeviceId: existing.clockDeviceId,
                serverURL: base
            )
        } else {
            enterSession(
                jamId: cleanedId,
                jamName: cleanedId,
                mode: "democratic",
                isPublic: true,
                clockDeviceId: nil,
                serverURL: base
            )
        }

        await fetchActiveJams(serverURL: base)
    }

    public func setMode(_ newMode: String) async {
        guard let jamId = currentJamId, !activeServerURL.isEmpty else { return }
        let encodedId = jamId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? jamId
        guard let url = URL(string: "\(activeServerURL)/api/jams/\(encodedId)/mode") else { return }
        guard let body = try? JSONSerialization.data(withJSONObject: ["mode": newMode]) else { return }

        do {
            let (_, response) = try await URLSession.shared.data(for: authorizedRequest(url: url, method: "PUT", body: body))
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                self.jamMode = newMode
            }
        } catch {
            print("[JamManager] setMode error: \(error)")
        }
    }

    public func leaveJam() {
        isIntentionalDisconnect = true
        stopNTPTimers()
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        volumeThrottleWorkItem?.cancel()
        volumeThrottleWorkItem = nil
        pendingVolumeToSend = nil

        if let jamId = currentJamId {
            sendJSON([
                "type": "LEAVE_ROOM",
                "room_id": jamId,
                "client_id": clientId
            ])

            if !activeServerURL.isEmpty, let url = URL(string: "\(activeServerURL)/api/jams/leave"),
               let body = try? JSONSerialization.data(withJSONObject: ["jamId": jamId]) {
                let req = authorizedRequest(url: url, method: "POST", body: body)
                Task.detached {
                    _ = try? await URLSession.shared.data(for: req)
                }
            }
        }

        closeWebSocketOnly()
        engine.stopAll()
        resetNTPState()
        progressStore.reset()

        self.isInJam = false
        self.currentJamId = nil
        self.currentJamName = nil
        self.clockDeviceId = nil
        self.members = []
        self.queueTracks = []
        self.currentTrack = nil
        self.isPlaying = false
        self.lastLoadedPlaybackSignature = nil
        self.connectionState = .disconnected
        self.errorMessage = nil

        AudioPlayerManager.shared.applyJamExited()

        if !activeServerURL.isEmpty {
            let srv = activeServerURL
            Task { await fetchActiveJams(serverURL: srv) }
        }
    }

    // MARK: - Session & WebSocket Lifecycle

    private func enterSession(
        jamId: String,
        jamName: String,
        mode: String,
        isPublic: Bool,
        clockDeviceId: String?,
        serverURL: String
    ) {
        AudioPlayerManager.shared.pauseAndPrepareForJam()
        errorMessage = nil
        isIntentionalDisconnect = false
        reconnectAttempts = 0
        lastLoadedPlaybackSignature = nil

        self.activeServerURL = serverURL
        self.currentJamId = jamId
        self.currentJamName = jamName
        self.jamMode = mode
        self.isPublic = isPublic
        self.clockDeviceId = clockDeviceId
        self.isInJam = true

        connectWebSocket()
    }

    private func buildWebSocketURL() -> URL? {
        guard let jamId = currentJamId, !activeServerURL.isEmpty else { return nil }
        var wsBase = activeServerURL
        if wsBase.hasPrefix("https://") {
            wsBase = "wss://" + wsBase.dropFirst("https://".count)
        } else if wsBase.hasPrefix("http://") {
            wsBase = "ws://" + wsBase.dropFirst("http://".count)
        } else {
            wsBase = "ws://" + wsBase
        }

        guard var comps = URLComponents(string: "\(wsBase)/ws/jam") else { return nil }
        comps.queryItems = [
            URLQueryItem(name: "room", value: jamId),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "name", value: displayName),
            URLQueryItem(name: "is_admin", value: "true")
        ]
        return comps.url
    }

    private func connectWebSocket() {
        guard isInJam, !isIntentionalDisconnect, let wsURL = buildWebSocketURL() else { return }

        closeWebSocketOnly()
        connectionState = reconnectAttempts > 0 ? .reconnecting : .connecting

        var request = URLRequest(url: wsURL)
        request.timeoutInterval = 10.0
        request.setValue("PortMusic-iOS/1.0", forHTTPHeaderField: "User-Agent")
        if let tok = SessionManager.shared.currentToken, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        let proxy = JamWebSocketDelegate(
            onOpen: { [weak self] openedTask in
                Task { @MainActor [weak self] in
                    guard let self = self, self.webSocketTask === openedTask, self.isInJam else { return }
                    self.connectionState = .connected
                    self.reconnectAttempts = 0
                    if let jamId = self.currentJamId {
                        self.sendJSON([
                            "type": "JOIN_ROOM",
                            "room_id": jamId,
                            "client_id": self.clientId,
                            "display_name": self.displayName,
                            "is_admin": true
                        ])
                    }
                    self.startNTPCalibration()
                }
            },
            onClose: { [weak self] closedTask in
                Task { @MainActor [weak self] in
                    guard let self = self, self.webSocketTask === closedTask else { return }
                    self.closeWebSocketOnly()
                    self.scheduleReconnect()
                }
            }
        )
        self.wsDelegateProxy = proxy
        let session = URLSession(configuration: config, delegate: proxy, delegateQueue: nil)
        let task = session.webSocketTask(with: request)
        self.wsSession = session
        self.webSocketTask = task
        task.resume()
        receiveLoop(for: task)
    }

    private func closeWebSocketOnly() {
        stopNTPTimers()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        wsSession?.invalidateAndCancel()
        wsSession = nil
        wsDelegateProxy = nil
    }

    private func scheduleReconnect() {
        guard isInJam, !isIntentionalDisconnect else { return }
        reconnectWorkItem?.cancel()
        connectionState = .reconnecting

        let baseDelay = min(pow(2.0, Double(reconnectAttempts)), 10.0)
        let jitter = Double.random(in: 0.0...0.4)
        reconnectAttempts += 1

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, self.isInJam, !self.isIntentionalDisconnect else { return }
                self.connectWebSocket()
            }
        }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay + jitter, execute: work)
    }

    private func receiveLoop(for task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self, self.webSocketTask === task else { return }

                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleIncomingText(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleIncomingText(text)
                        }
                    @unknown default:
                        break
                    }
                    self.receiveLoop(for: task)

                case .failure(let error):
                    print("[JamManager] WebSocket receive error: \(error)")
                    self.closeWebSocketOnly()
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func sendJSON(_ object: [String: Any]) {
        guard let task = webSocketTask,
              let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        task.send(.string(text)) { error in
            if let error = error {
                print("[JamManager] WS send error: \(error)")
            }
        }
    }

    // MARK: - Schlankes NTP (6 Probes Burst -> 4 s Steady, ohne UI-Flooding)

    private func resetNTPState() {
        pendingProbes.removeAll()
        pendingFirstProbe = nil
        pendingFirstProbeGroupId = nil
        measurements.removeAll()
        rawMinRttMs = .infinity
        internalClockOffsetMs = 0.0
        internalMinRttMs = 0.0
        pureCount = 0
        impureCount = 0
        lastTelemetryPublishUptimeMs = 0.0
        lastProbeSentUptimeMs = 0.0
    }

    private func stopNTPTimers() {
        ntpTimerWorkItem?.cancel()
        ntpTimerWorkItem = nil
    }

    public func resyncClock() {
        resetNTPState()
        progressStore.minRttMs = 0.0
        progressStore.clockOffsetMs = 0.0
        startNTPCalibration()
        requestSync()
    }

    private func startNTPCalibration() {
        stopNTPTimers()
        resetNTPState()
        sendCodedProbePair()
        scheduleNextNTPProbe()
    }

    private func scheduleNextNTPProbe() {
        guard isInJam, webSocketTask != nil else { return }
        let intervalMs = measurements.count < Self.burstProbeCount
            ? Self.initialNTPIntervalMs
            : Self.steadyNTPIntervalMs

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, self.isInJam, self.webSocketTask != nil else { return }
                self.sendCodedProbePair()
                self.scheduleNextNTPProbe()
            }
        }
        ntpTimerWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(intervalMs)), execute: work)
    }

    private func sendCodedProbePair() {
        guard webSocketTask != nil else { return }

        let nowUptimeMs = ProcessInfo.processInfo.systemUptime * 1000.0
        if lastProbeSentUptimeMs > 0.0,
           (nowUptimeMs - lastProbeSentUptimeMs) > Self.staleResponseTimeoutMs {
            print("[JamManager] NTP stale timeout (>10s), reconnecting...")
            lastProbeSentUptimeMs = 0.0
            closeWebSocketOnly()
            scheduleReconnect()
            return
        }

        lastProbeSentUptimeMs = nowUptimeMs
        probeGroupCounter &+= 1
        let groupId = probeGroupCounter
        let totalCompMs = max(0.0, engine.currentOutputLatencyMs() - nudgeMs)

        let t0First = monotonicEpochNowMs()
        pendingProbes["\(groupId)_0"] = t0First
        var msg0: [String: Any] = [
            "type": "NTP_REQUEST",
            "t0": t0First,
            "client_nudge_ms": nudgeMs,
            "probe_group_id": groupId,
            "probe_group_index": 0
        ]
        if rawMinRttMs.isFinite { msg0["client_rtt"] = rawMinRttMs }
        if totalCompMs > 0 { msg0["client_compensation_ms"] = totalCompMs }
        sendJSON(msg0)

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(Self.probeGapMs))) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, self.webSocketTask != nil else { return }
                let t0Second = self.monotonicEpochNowMs()
                self.pendingProbes["\(groupId)_1"] = t0Second
                var msg1: [String: Any] = [
                    "type": "NTP_REQUEST",
                    "t0": t0Second,
                    "client_nudge_ms": self.nudgeMs,
                    "probe_group_id": groupId,
                    "probe_group_index": 1
                ]
                if self.rawMinRttMs.isFinite { msg1["client_rtt"] = self.rawMinRttMs }
                if totalCompMs > 0 { msg1["client_compensation_ms"] = totalCompMs }
                self.sendJSON(msg1)
            }
        }
    }

    private func publishTelemetryIfDue(force: Bool = false) {
        let nowUptime = ProcessInfo.processInfo.systemUptime * 1000.0
        guard force || (nowUptime - lastTelemetryPublishUptimeMs) >= 2000.0 else { return }
        lastTelemetryPublishUptimeMs = nowUptime
        progressStore.minRttMs = internalMinRttMs
        progressStore.clockOffsetMs = internalClockOffsetMs
        progressStore.pureProbeCount = pureCount
        progressStore.impureProbeCount = impureCount
    }

    // MARK: - Incoming WS Handling

    private func handleIncomingText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "NTP_RESPONSE":
            lastProbeSentUptimeMs = 0.0
            let t3 = monotonicEpochNowMs()
            let groupIdNum = (json["probe_group_id"] as? NSNumber)?.uint64Value ?? 0
            let index = (json["probe_group_index"] as? NSNumber)?.intValue ?? 0
            let key = "\(groupIdNum)_\(index)"
            guard let t0 = pendingProbes.removeValue(forKey: key),
                  let t1 = (json["t1"] as? NSNumber)?.doubleValue,
                  let t2 = (json["t2"] as? NSNumber)?.doubleValue else {
                return
            }

            let offset = ((t1 - t0) + (t2 - t3)) / 2.0
            let rtt = (t3 - t0) - (t2 - t1)
            let measurement = JamNTPMeasurement(
                t0: t0, t1: t1, t2: t2, t3: t3,
                clockOffsetMs: offset,
                roundTripDelayMs: rtt
            )

            if measurements.isEmpty && rtt >= 0 {
                rawMinRttMs = rtt
                internalMinRttMs = rtt
                internalClockOffsetMs = offset
                publishTelemetryIfDue(force: true)
            }

            if index == 0 {
                pendingFirstProbe = measurement
                pendingFirstProbeGroupId = groupIdNum
                return
            }

            guard let first = pendingFirstProbe, pendingFirstProbeGroupId == groupIdNum else { return }
            pendingFirstProbe = nil
            pendingFirstProbeGroupId = nil

            let clientGap = measurement.t0 - first.t0
            let serverGap = measurement.t1 - first.t1
            let gapDrift = abs(serverGap - clientGap)
            guard gapDrift <= Self.probeGapToleranceMs else {
                impureCount += 1
                return
            }

            pureCount += 1
            let best = first.roundTripDelayMs <= measurement.roundTripDelayMs ? first : measurement
            measurements.append(best)
            if measurements.count > Self.maxNTPMeasurements {
                measurements.removeFirst()
            }

            var bestRtt = Double.infinity
            var bestOffset = internalClockOffsetMs
            for m in measurements where m.roundTripDelayMs >= 0 && m.roundTripDelayMs < bestRtt {
                bestRtt = m.roundTripDelayMs
                bestOffset = m.clockOffsetMs
            }
            if bestRtt.isFinite {
                rawMinRttMs = bestRtt
                internalMinRttMs = bestRtt
                internalClockOffsetMs = bestOffset
                publishTelemetryIfDue()
            }

        case "ROOM_STATE":
            if let modeStr = json["mode"] as? String, !modeStr.isEmpty {
                self.jamMode = modeStr
            }
            if let hostId = json["clock_device_id"] as? String, !hostId.isEmpty {
                self.clockDeviceId = hostId
            }
            if let clientsRaw = json["clients"],
               let cData = try? JSONSerialization.data(withJSONObject: clientsRaw),
               let decodedClients = try? JSONDecoder().decode([JamWSClientInfo].self, from: cData) {
                self.members = decodedClients
            }
            if let vol = (json["global_volume"] as? NSNumber)?.doubleValue {
                self.globalVolume = max(0.0, min(1.0, vol))
                engine.setGlobalVolume(self.globalVolume)
            }
            if let pbRaw = json["playback"],
               let pData = try? JSONSerialization.data(withJSONObject: pbRaw),
               let pb = try? JSONDecoder().decode(JamPlaybackState.self, from: pData) {
                applyRoomPlaybackState(pb)
            }

        case "QUEUE_UPDATED":
            if let qRaw = json["queue"],
               let qData = try? JSONSerialization.data(withJSONObject: qRaw),
               let qDecoded = try? JSONDecoder().decode([JamQueueTrack].self, from: qData) {
                self.queueTracks = qDecoded.map { $0.toTrack() }
                syncDisplayToPlayerManager(forceNowPlaying: false)
            }

        case "GLOBAL_VOLUME_CONFIG":
            if let vol = (json["volume"] as? NSNumber)?.doubleValue {
                self.globalVolume = max(0.0, min(1.0, vol))
                engine.setGlobalVolume(self.globalVolume)
            }

        case "CLIENT_JOINED":
            if let cRaw = json["client"],
               let cData = try? JSONSerialization.data(withJSONObject: cRaw),
               let client = try? JSONDecoder().decode(JamWSClientInfo.self, from: cData),
               !members.contains(where: { $0.clientId == client.clientId }) {
                members.append(client)
            }

        case "CLIENT_LEFT":
            if let cid = json["client_id"] as? String {
                members.removeAll { $0.clientId == cid }
            }

        case "LOAD_AUDIO_SOURCE":
            guard let trackId = json["track_id"] as? String else { return }
            let streamUrl = (json["stream_url"] as? String) ?? ""
            let title = (json["title"] as? String) ?? "Jam Track"
            let artist = (json["artist"] as? String) ?? "Unbekannt"
            let coverUrl = json["cover_url"] as? String
            let knownQueueTrack = queueTracks.first(where: { $0.id == trackId })

            let track = Track(
                id: trackId,
                title: title,
                artist: artist,
                album: knownQueueTrack?.album ?? "Jam",
                duration: knownQueueTrack?.duration ?? "0:00",
                durationSeconds: knownQueueTrack?.durationSeconds ?? 0,
                coverUrl: coverUrl ?? knownQueueTrack?.coverUrl,
                isLive: false,
                isExplicit: false,
                sourceUrl: streamUrl
            )
            self.errorMessage = nil
            self.currentTrack = track
            self.isPlaying = false
            self.progressStore.currentPosition = 0.0
            self.progressStore.duration = track.durationSeconds
            syncDisplayToPlayerManager(forceNowPlaying: true)

            let jamIdSnap = currentJamId
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let loadedDur = await self.engine.loadTrack(
                    trackId: trackId,
                    streamURLString: streamUrl,
                    serverURL: self.activeServerURL,
                    token: SessionManager.shared.currentToken
                )
                guard self.isInJam, self.currentJamId == jamIdSnap else { return }
                if let dur = loadedDur, dur > 0 {
                    let existingDur = self.currentTrack?.durationSeconds ?? 0
                    let resolvedDur = (existingDur > 10 && dur > existingDur * 1.7) ? existingDur : dur
                    self.progressStore.duration = resolvedDur
                    self.currentTrack = Track(
                        id: track.id,
                        title: track.title,
                        artist: track.artist,
                        album: track.album,
                        duration: Self.formatDuration(resolvedDur),
                        durationSeconds: resolvedDur,
                        coverUrl: track.coverUrl,
                        isLive: false,
                        isExplicit: false,
                        sourceUrl: track.sourceUrl
                    )
                    self.syncDisplayToPlayerManager(forceNowPlaying: true)
                }
                self.notifyAudioLoaded(trackId: trackId)
            }

        case "SCHEDULE_PLAY":
            guard let trackId = json["track_id"] as? String else { return }
            let execTime = (json["server_time_to_execute"] as? NSNumber)?.doubleValue ?? 0.0
            let pos = (json["track_position_seconds"] as? NSNumber)?.doubleValue ?? 0.0
            lastLoadedPlaybackSignature = "\(trackId)_\(execTime)_\(pos)"

            engine.schedulePlay(
                trackId: trackId,
                serverTimeToExecuteMs: execTime,
                positionSeconds: pos,
                estimatedServerTimeMs: estimatedServerTimeMs(),
                nudgeMs: nudgeMs
            )
            if !engine.hasTrackLoaded(trackId) && !engine.isTrackLoading(trackId) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.requestSync()
                    }
                }
            }

        case "SCHEDULE_PAUSE":
            let execTime = (json["server_time_to_execute"] as? NSNumber)?.doubleValue ?? 0.0
            let pos = (json["track_position_seconds"] as? NSNumber)?.doubleValue ?? 0.0
            lastLoadedPlaybackSignature = "paused_\(execTime)_\(pos)"
            engine.schedulePause(
                positionSeconds: pos,
                serverTimeToExecuteMs: execTime,
                estimatedServerTimeMs: estimatedServerTimeMs(),
                nudgeMs: nudgeMs
            )

        default:
            break
        }
    }

    private func applyRoomPlaybackState(_ pb: JamPlaybackState) {
        if let q = pb.queue, !q.isEmpty {
            self.queueTracks = q.map { $0.toTrack() }
        }

        guard let trackId = pb.trackId, !trackId.isEmpty else {
            syncDisplayToPlayerManager(forceNowPlaying: false)
            return
        }

        let streamUrl = pb.streamUrl ?? "/api/stream/\(trackId)"
        let title = pb.title ?? "Jam Audio"
        let artist = pb.artist ?? "Live Session"
        let matchedQueue = queueTracks.first(where: { $0.id == trackId })
        let track = Track(
            id: trackId,
            title: title,
            artist: artist,
            album: matchedQueue?.album ?? "Jam",
            duration: matchedQueue?.duration ?? "0:00",
            durationSeconds: matchedQueue?.durationSeconds ?? 0,
            coverUrl: pb.coverUrl ?? matchedQueue?.coverUrl,
            isLive: false,
            isExplicit: false,
            sourceUrl: streamUrl
        )

        let signature = "\(pb.status)_\(trackId)_\(pb.serverTimeToExecute)_\(pb.trackPositionSeconds)"
        if lastLoadedPlaybackSignature == signature && engine.hasTrackLoaded(trackId) {
            syncDisplayToPlayerManager(forceNowPlaying: false)
            return
        }
        lastLoadedPlaybackSignature = signature

        self.currentTrack = track
        if track.durationSeconds > 0 {
            self.progressStore.duration = track.durationSeconds
        }
        syncDisplayToPlayerManager(forceNowPlaying: true)

        let jamIdSnap = currentJamId
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let dur = await self.engine.loadTrack(
                trackId: trackId,
                streamURLString: streamUrl,
                serverURL: self.activeServerURL,
                token: SessionManager.shared.currentToken
            )
            guard self.isInJam,
                  self.currentJamId == jamIdSnap,
                  self.lastLoadedPlaybackSignature == signature else { return }
            if let dur = dur, dur > 0 {
                let existingDur = self.currentTrack?.durationSeconds ?? 0
                let resolvedDur = (existingDur > 10 && dur > existingDur * 1.7) ? existingDur : dur
                self.progressStore.duration = resolvedDur
                self.currentTrack = Track(
                    id: track.id,
                    title: track.title,
                    artist: track.artist,
                    album: track.album,
                    duration: Self.formatDuration(resolvedDur),
                    durationSeconds: resolvedDur,
                    coverUrl: track.coverUrl,
                    isLive: false,
                    isExplicit: false,
                    sourceUrl: track.sourceUrl
                )
            }
            if pb.status == "playing" && pb.serverTimeToExecute > 0 {
                self.engine.schedulePlay(
                    trackId: trackId,
                    serverTimeToExecuteMs: pb.serverTimeToExecute,
                    positionSeconds: pb.trackPositionSeconds,
                    estimatedServerTimeMs: self.estimatedServerTimeMs(),
                    nudgeMs: self.nudgeMs
                )
            } else {
                if self.engine.getIsPlaying() {
                    self.engine.schedulePause(
                        positionSeconds: pb.trackPositionSeconds,
                        serverTimeToExecuteMs: 0,
                        estimatedServerTimeMs: self.estimatedServerTimeMs(),
                        nudgeMs: self.nudgeMs
                    )
                }
                self.isPlaying = false
                self.progressStore.currentPosition = pb.trackPositionSeconds
                self.syncDisplayToPlayerManager(forceNowPlaying: true)
            }
        }
    }

    // MARK: - Playback & Queue Commands (Spotify-Like Synchronized Controls)

    public func playTrackInJam(_ track: Track, queue: [Track] = []) {
        guard isInJam, let jamId = currentJamId else { return }
        if !canControlPlayback {
            self.errorMessage = "Nur der Host kann im Host-Modus die Wiedergabe steuern."
            return
        }
        self.errorMessage = nil

        if !queue.isEmpty {
            syncQueue(queue)
        } else if !queueTracks.contains(where: { $0.id == track.id }) {
            var updated = queueTracks
            updated.insert(track, at: 0)
            syncQueue(updated)
        }

        let streamPath = buildJamStreamPath(for: track)

        sendJSON([
            "type": "LOAD_AUDIO_SOURCE",
            "room_id": jamId,
            "track_id": track.id,
            "stream_url": streamPath,
            "title": track.title,
            "artist": track.artist,
            "cover_url": track.coverUrl ?? ""
        ])
    }

    private func buildJamStreamPath(for track: Track) -> String {
        if let src = track.sourceUrl, !src.isEmpty {
            if src.hasPrefix("/api/files/audio/") || src.hasPrefix("/api/podcasts/stream") {
                return src
            }
            if track.album == "Podcast", (src.hasPrefix("http://") || src.hasPrefix("https://")) {
                var comps = URLComponents(string: "/api/podcasts/stream")
                comps?.queryItems = [URLQueryItem(name: "url", value: src)]
                return comps?.string ?? src
            }
        }

        let basePath: String
        if let src = track.sourceUrl, src.hasPrefix("/api/stream/") {
            basePath = src
        } else {
            let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
            let encoded = track.id.addingPercentEncoding(withAllowedCharacters: allowed) ?? track.id
            basePath = "/api/stream/\(encoded)"
        }

        guard var comps = URLComponents(string: basePath) else { return basePath }
        var items = comps.queryItems ?? []
        let existingNames = Set(items.map { $0.name.lowercased() })
        if !existingNames.contains("title") && !track.title.isEmpty {
            items.append(URLQueryItem(name: "title", value: track.title))
        }
        if !existingNames.contains("artist") && !track.artist.isEmpty {
            items.append(URLQueryItem(name: "artist", value: track.artist))
        }
        if !existingNames.contains("album"), let album = track.album, !album.isEmpty {
            items.append(URLQueryItem(name: "album", value: album))
        }
        if !existingNames.contains("cover"), let cover = track.coverUrl, !cover.isEmpty {
            items.append(URLQueryItem(name: "cover", value: cover))
        }
        if !existingNames.contains("duration"), track.durationSeconds > 0 {
            items.append(URLQueryItem(name: "duration", value: "\(Int(track.durationSeconds.rounded()))"))
        }
        comps.queryItems = items.isEmpty ? nil : items
        return comps.string ?? basePath
    }

    public func togglePlayPause() {
        guard isInJam else { return }
        if !canControlPlayback {
            self.errorMessage = "Nur der Host kann im Host-Modus die Wiedergabe steuern."
            return
        }
        let pos = engine.getIsPlaying() ? engine.currentPositionSeconds() : progressStore.currentPosition
        if isPlaying {
            requestPause(at: pos)
        } else if let cur = currentTrack {
            requestPlay(trackId: cur.id, at: pos)
        } else if let first = queueTracks.first {
            playTrackInJam(first, queue: queueTracks)
        }
    }

    public func requestPlay(trackId: String, at positionSeconds: Double) {
        guard isInJam, let jamId = currentJamId, canControlPlayback else { return }
        sendJSON([
            "type": "PLAY",
            "room_id": jamId,
            "track_id": trackId,
            "position_seconds": max(0.0, positionSeconds)
        ])
    }

    public func requestPause(at positionSeconds: Double) {
        guard isInJam, let jamId = currentJamId, canControlPlayback else { return }
        sendJSON([
            "type": "PAUSE",
            "room_id": jamId,
            "position_seconds": max(0.0, positionSeconds)
        ])
    }

    public func seek(to positionSeconds: Double) {
        guard isInJam, let jamId = currentJamId, currentTrack != nil else { return }
        if !canControlPlayback {
            self.errorMessage = "Nur der Host kann im Host-Modus spulen."
            return
        }
        let maxDur = progressStore.duration > 0 ? progressStore.duration : 3600.0
        let clamped = max(0.0, min(maxDur, positionSeconds))
        progressStore.currentPosition = clamped
        sendJSON([
            "type": "SEEK",
            "room_id": jamId,
            "position_seconds": clamped
        ])
    }

    public func nextTrack() {
        guard isInJam else { return }
        if !canControlPlayback {
            self.errorMessage = "Nur der Host kann im Host-Modus Titel wechseln."
            return
        }
        guard !queueTracks.isEmpty else { return }
        guard let cur = currentTrack, let idx = queueTracks.firstIndex(where: { $0.id == cur.id }) else {
            playTrackInJam(queueTracks[0], queue: queueTracks)
            return
        }
        if idx + 1 < queueTracks.count {
            playTrackInJam(queueTracks[idx + 1], queue: queueTracks)
        } else {
            playTrackInJam(queueTracks[0], queue: queueTracks)
        }
    }

    public func previousTrack() {
        guard isInJam else { return }
        if !canControlPlayback {
            self.errorMessage = "Nur der Host kann im Host-Modus Titel wechseln."
            return
        }
        if engine.currentPositionSeconds() > 3.0 {
            seek(to: 0.0)
            return
        }
        guard let cur = currentTrack, let idx = queueTracks.firstIndex(where: { $0.id == cur.id }) else {
            seek(to: 0.0)
            return
        }
        if idx > 0 {
            playTrackInJam(queueTracks[idx - 1], queue: queueTracks)
        } else {
            seek(to: 0.0)
        }
    }

    public func setGlobalVolume(_ volume: Double) {
        let clamped = max(0.0, min(1.0, volume))
        self.globalVolume = clamped
        engine.setGlobalVolume(clamped)
        guard isInJam, let jamId = currentJamId else { return }

        pendingVolumeToSend = clamped
        guard volumeThrottleWorkItem == nil else { return }

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.volumeThrottleWorkItem = nil
                guard let val = self.pendingVolumeToSend, self.isInJam else { return }
                self.pendingVolumeToSend = nil
                self.sendJSON([
                    "type": "SET_GLOBAL_VOLUME",
                    "room_id": jamId,
                    "volume": val
                ])
            }
        }
        volumeThrottleWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(60), execute: work)
    }

    public func applyNudge(deltaMs: Double) {
        let updated = nudgeMs + deltaMs
        setNudge(totalMs: updated, deltaMs: deltaMs)
    }

    public func resetNudge() {
        let delta = -nudgeMs
        setNudge(totalMs: 0.0, deltaMs: delta)
    }

    private func setNudge(totalMs: Double, deltaMs: Double) {
        self.nudgeMs = totalMs
        UserDefaults.standard.set(totalMs, forKey: nudgeStorageKey)

        if let jamId = currentJamId {
            sendJSON([
                "type": "NUDGE",
                "room_id": jamId,
                "client_id": clientId,
                "amount_ms": totalMs
            ])
        }

        if engine.getIsPlaying() && deltaMs != 0 {
            engine.applyLiveNudge(totalNudgeMs: totalMs, deltaMs: deltaMs)
        }
    }

    public func syncQueue(_ tracks: [Track]) {
        self.queueTracks = tracks
        guard isInJam, let jamId = currentJamId else { return }
        let serialized: [[String: Any]] = tracks.map { t in
            var dict: [String: Any] = [
                "id": t.id,
                "title": t.title,
                "artist": t.artist
            ]
            if let alb = t.album { dict["album"] = alb }
            if let cov = t.coverUrl { dict["cover"] = cov }
            dict["duration"] = t.duration
            if t.durationSeconds > 0 { dict["duration_seconds"] = Int(t.durationSeconds.rounded()) }
            dict["source_url"] = buildJamStreamPath(for: t)
            return dict
        }
        sendJSON([
            "type": "SYNC_QUEUE",
            "room_id": jamId,
            "queue": serialized
        ])
    }

    public func requestSync() {
        guard isInJam else { return }
        sendJSON(["type": "SYNC"])
    }

    private func notifyAudioLoaded(trackId: String) {
        guard let jamId = currentJamId else { return }
        sendJSON([
            "type": "AUDIO_SOURCE_LOADED",
            "room_id": jamId,
            "client_id": clientId,
            "track_id": trackId
        ])
    }

    private func handleLocalTrackEnded(finishedTrackId: String) {
        guard isInJam, canControlPlayback, currentTrack?.id == finishedTrackId else { return }
        if let idx = queueTracks.firstIndex(where: { $0.id == finishedTrackId }), idx + 1 < queueTracks.count {
            playTrackInJam(queueTracks[idx + 1], queue: queueTracks)
        }
    }

    private func syncDisplayToPlayerManager(forceNowPlaying: Bool) {
        let dur = progressStore.duration > 0 ? progressStore.duration : (currentTrack?.durationSeconds ?? 0)
        AudioPlayerManager.shared.applyJamExternalPlaybackState(
            track: currentTrack,
            isPlaying: isPlaying,
            currentTime: progressStore.currentPosition,
            duration: dur,
            queue: queueTracks,
            shouldUpdateNowPlaying: forceNowPlaying
        )
    }

    private static func formatDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

private final class JamWebSocketDelegate: NSObject, URLSessionWebSocketDelegate {
    private let onOpen: (URLSessionWebSocketTask) -> Void
    private let onClose: (URLSessionWebSocketTask) -> Void

    init(
        onOpen: @escaping (URLSessionWebSocketTask) -> Void,
        onClose: @escaping (URLSessionWebSocketTask) -> Void
    ) {
        self.onOpen = onOpen
        self.onClose = onClose
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        onOpen(webSocketTask)
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        onClose(webSocketTask)
    }
}
