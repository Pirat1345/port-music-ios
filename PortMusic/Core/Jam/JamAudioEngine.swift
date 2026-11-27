import Foundation
import AVFoundation
import CoreMedia

/// Progressive Streaming-Audio-Engine für Port Music Jam auf Basis von Hardware-AVPlayer:
/// - Streamt per HTTP Range-Requests (minimaler mobiler Datenverbrauch, zuverlässiger iOS-Start)
/// - Synchronisiert Start-Zeitpunkte mit Preroll + Server-Timeline-Anker
/// - Hält alle Geräte über sanfte, tonhöhenerhaltende Tempo-Anpassung (PLL 0.985x–1.015x) dauerhaft im Takt
@MainActor
public final class JamAudioEngine {
    public static let shared = JamAudioEngine()

    public static let maxTrustworthyOutputLatencyMs: Double = 100.0
    private static let lookaheadSeconds: Double = 0.05
    private static let preferredForwardBufferSec: TimeInterval = 8.0

    private var player: AVPlayer? = nil
    private var playerItem: AVPlayerItem? = nil
    private var timeObserverToken: Any? = nil
    private var itemStatusObserver: NSKeyValueObservation? = nil
    private var itemDurationObserver: NSKeyValueObservation? = nil
    private var itemRateObserver: NSKeyValueObservation? = nil

    private var currentTrackId: String? = nil
    private var loadingTrackId: String? = nil
    private var isItemReady: Bool = false
    private var currentDurationSeconds: Double = 0.0
    private var isPlayingState: Bool = false
    private var lastReportedPositionSeconds: Double = 0.0
    private var globalVolume: Double = 1.0

    // Server-Timeline-Anker für den kontinuierlichen Drift-Abgleich (PLL)
    private var anchorServerExecMs: Double = 0.0
    private var anchorPositionSeconds: Double = 0.0
    private var lastAnchorTrackId: String? = nil
    private var currentNudgeMs: Double = 0.0
    private var lastHardSeekUptimeMs: Double = 0.0

    private var loadGeneration: UInt64 = 0
    private var playCommandGeneration: UInt64 = 0
    private var readyContinuation: CheckedContinuation<Double?, Never>? = nil
    private var readyTimeoutWorkItem: DispatchWorkItem? = nil
    private var scheduledPlayWorkItem: DispatchWorkItem? = nil
    private var scheduledPauseWorkItem: DispatchWorkItem? = nil
    private var playWatchdogWorkItem: DispatchWorkItem? = nil
    private var lastPlaybackEmitUptimeMs: Double = 0.0

    private var pendingPlayCommand: (
        trackId: String,
        serverTimeToExecuteMs: Double,
        positionSeconds: Double,
        estimatedServerTimeMs: Double,
        nudgeMs: Double
    )? = nil

    public var onTrackEnded: ((String) -> Void)?
    public var onPlaybackStateChanged: ((Bool, Double, Double, Bool) -> Void)?
    public var onAudioRouteChanged: (() -> Void)?
    public var serverTimeProvider: (() -> Double)?

    private init() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onAudioRouteChanged?()
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo,
                  let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
                return
            }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if type == .ended {
                    self.configureAudioSession()
                    if self.isPlayingState {
                        self.player?.play()
                    }
                }
            }
        }
    }

    // MARK: - AudioSession & Output Latency

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("[JamAudioEngine] AudioSession error: \(error)")
        }
    }

    public func currentOutputLatencyMs() -> Double {
        let rawMs = AVAudioSession.sharedInstance().outputLatency * 1000.0
        if rawMs > Self.maxTrustworthyOutputLatencyMs || rawMs < 0 {
            return 0.0
        }
        return rawMs
    }

    public func setGlobalVolume(_ volume: Double) {
        let clamped = max(0.0, min(1.0, volume))
        self.globalVolume = clamped
        player?.volume = Float(clamped)
    }

    public func hasTrackLoaded(_ trackId: String) -> Bool {
        return currentTrackId == trackId && isItemReady && playerItem != nil && playerItem?.status == .readyToPlay
    }

    public func isTrackLoading(_ trackId: String) -> Bool {
        return loadingTrackId == trackId
    }

    public func currentPositionSeconds() -> Double {
        guard let item = playerItem, item.status == .readyToPlay else {
            return lastReportedPositionSeconds
        }
        let sec = item.currentTime().seconds
        if sec.isFinite && sec >= 0 {
            return currentDurationSeconds > 0 ? min(currentDurationSeconds, sec) : sec
        }
        return lastReportedPositionSeconds
    }

    public func currentDuration() -> Double {
        return currentDurationSeconds
    }

    public func getIsPlaying() -> Bool {
        return isPlayingState
    }

    // MARK: - Progressive Track Loading (HTTP Range Streaming + Offline Cache)

    public func loadTrack(
        trackId: String,
        streamURLString: String,
        serverURL: String,
        token: String?
    ) async -> Double? {
        if currentTrackId == trackId && isItemReady,
           let existing = playerItem,
           existing.status == .readyToPlay {
            let dur = existing.duration.seconds
            let resolved = (dur.isFinite && dur > 0) ? dur : currentDurationSeconds
            return resolved
        }

        loadGeneration &+= 1
        playCommandGeneration &+= 1
        let myGen = loadGeneration
        finishReadyContinuation(with: nil)

        cancelScheduledPlay()
        cancelScheduledPause()
        pendingPlayCommand = nil
        cleanupItemObservers()

        self.loadingTrackId = trackId
        self.currentTrackId = trackId
        self.isItemReady = false
        self.isPlayingState = false
        self.lastReportedPositionSeconds = 0.0
        self.currentDurationSeconds = 0.0
        self.anchorServerExecMs = 0.0
        self.anchorPositionSeconds = 0.0
        self.lastAnchorTrackId = nil

        configureAudioSession()

        let item: AVPlayerItem
        if let localOffline = OfflineDownloadManager.shared.localAudioFileURL(for: trackId) {
            item = AVPlayerItem(asset: AVURLAsset(url: localOffline))
        } else {
            guard let resolvedURL = buildIOSCompatibleStreamURL(
                trackId: trackId,
                rawStreamURL: streamURLString,
                serverURL: serverURL
            ) else {
                if myGen == loadGeneration {
                    loadingTrackId = nil
                }
                return nil
            }
            // User-Agent niemals manuell in AVURLAssetHTTPHeaderFieldsKey überschreiben:
            // CFNetwork nutzt automatisch nativen AppleCoreMedia-Agent, den der Backend-Stream benötigt.
            if resolvedURL.path.hasPrefix("/api/files/audio/"),
               let tok = token, !tok.isEmpty {
                let headers: [String: String] = [
                    "Authorization": "Bearer \(tok)",
                    "x-session-token": tok
                ]
                item = AVPlayerItem(asset: AVURLAsset(url: resolvedURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers]))
            } else {
                item = AVPlayerItem(url: resolvedURL)
            }
        }

        item.audioTimePitchAlgorithm = .timeDomain
        item.preferredForwardBufferDuration = Self.preferredForwardBufferSec
        self.playerItem = item

        if let existingPlayer = self.player {
            existingPlayer.pause()
            existingPlayer.automaticallyWaitsToMinimizeStalling = true
            existingPlayer.volume = Float(globalVolume)
            existingPlayer.replaceCurrentItem(with: item)
        } else {
            let newPlayer = AVPlayer(playerItem: item)
            newPlayer.automaticallyWaitsToMinimizeStalling = true
            newPlayer.volume = Float(globalVolume)
            self.player = newPlayer
            setupTimeObserver(for: newPlayer)
        }

        registerEndObservers(for: item)

        return await withCheckedContinuation { [weak self] continuation in
            guard let self = self, myGen == self.loadGeneration else {
                continuation.resume(returning: nil)
                return
            }

            self.readyContinuation = continuation

            let timeoutWork = DispatchWorkItem { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self = self, myGen == self.loadGeneration else { return }
                    if self.loadingTrackId == trackId {
                        self.loadingTrackId = nil
                    }
                    self.finishReadyContinuation(with: self.currentDurationSeconds > 0 ? self.currentDurationSeconds : nil)
                }
            }
            self.readyTimeoutWorkItem = timeoutWork
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0, execute: timeoutWork)

            self.itemDurationObserver = item.observe(\.duration, options: [.initial, .new]) { [weak self] observed, _ in
                Task { @MainActor [weak self] in
                    guard let self = self, myGen == self.loadGeneration else { return }
                    let d = observed.duration.seconds
                    if d.isFinite && d > 1.0 && (self.currentDurationSeconds <= 0 || d < self.currentDurationSeconds) {
                        self.currentDurationSeconds = d
                    }
                }
            }

            self.itemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
                Task { @MainActor [weak self] in
                    guard let self = self, myGen == self.loadGeneration else { return }
                    switch observed.status {
                    case .readyToPlay:
                        self.handleItemReadyCheck(observed, trackId: trackId, loadGen: myGen)
                    case .failed:
                        print("[JamAudioEngine] AVPlayerItem failed for \(trackId): \(String(describing: observed.error))")
                        self.loadingTrackId = nil
                        self.isItemReady = false
                        self.finishReadyContinuation(with: nil)
                    case .unknown:
                        break
                    @unknown default:
                        break
                    }
                }
            }
        }
    }

    private func handleItemReadyCheck(_ observed: AVPlayerItem, trackId: String, loadGen myGen: UInt64) {
        guard myGen == self.loadGeneration else { return }
        guard observed.status == .readyToPlay, !self.isItemReady else { return }

        // Sobald AVPlayerItem .readyToPlay meldet, sofort freigeben (ohne auf isPlaybackLikelyToKeepUp
        // im pausierten Zustand zu blockieren, da HTTP-Streams oft erst mit player.play() weiterbuffern).
        self.isItemReady = true
        self.loadingTrackId = nil
        let itemDur = observed.duration.seconds
        if itemDur.isFinite && itemDur > 0 && self.currentDurationSeconds <= 0 {
            self.currentDurationSeconds = itemDur
        }
        let finalDur = self.currentDurationSeconds > 0 ? self.currentDurationSeconds : nil
        self.finishReadyContinuation(with: finalDur)

        if let pending = self.pendingPlayCommand, pending.trackId == trackId {
            self.pendingPlayCommand = nil
            self.schedulePlay(
                trackId: pending.trackId,
                serverTimeToExecuteMs: pending.serverTimeToExecuteMs,
                positionSeconds: pending.positionSeconds,
                estimatedServerTimeMs: self.serverTimeProvider?() ?? pending.estimatedServerTimeMs,
                nudgeMs: pending.nudgeMs
            )
        }
    }

    private func finishReadyContinuation(with duration: Double?) {
        readyTimeoutWorkItem?.cancel()
        readyTimeoutWorkItem = nil
        if let cont = readyContinuation {
            readyContinuation = nil
            cont.resume(returning: duration)
        }
    }

    // MARK: - Sofortige optimistische lokale Steuerung (Null-Latenz-UI + Audio)

    public func playOptimisticLocal(trackId: String, at positionSeconds: Double) {
        guard currentTrackId == trackId else { return }
        cancelScheduledPause()
        isPlayingState = true
        let clamped = clampPosition(positionSeconds)
        lastReportedPositionSeconds = clamped

        if let player = player, let item = playerItem, item.status == .readyToPlay {
            configureAudioSession()
            player.automaticallyWaitsToMinimizeStalling = true
            player.volume = Float(globalVolume)
            let curPos = item.currentTime().seconds
            if !curPos.isFinite || abs(curPos - clamped) > 0.6 {
                let cm = CMTime(seconds: clamped, preferredTimescale: 600)
                let tol = CMTime(seconds: 0.1, preferredTimescale: 600)
                player.seek(to: cm, toleranceBefore: tol, toleranceAfter: tol) { [weak self, weak player] _ in
                    Task { @MainActor [weak self, weak player] in
                        guard let self = self, let player = player, self.isPlayingState, self.currentTrackId == trackId else { return }
                        player.play()
                    }
                }
            } else {
                player.play()
            }
        } else {
            pendingPlayCommand = (
                trackId: trackId,
                serverTimeToExecuteMs: 0,
                positionSeconds: clamped,
                estimatedServerTimeMs: serverTimeProvider?() ?? 0,
                nudgeMs: currentNudgeMs
            )
        }

        onPlaybackStateChanged?(true, clamped, currentDurationSeconds, true)
    }

    public func pauseOptimisticLocal(at positionSeconds: Double) {
        cancelScheduledPlay()
        cancelScheduledPause()
        pendingPlayCommand = nil
        isPlayingState = false
        let clamped = clampPosition(positionSeconds)
        lastReportedPositionSeconds = clamped
        player?.pause()
        onPlaybackStateChanged?(false, clamped, currentDurationSeconds, true)
    }

    public func seekOptimisticLocal(to positionSeconds: Double) {
        let clamped = clampPosition(positionSeconds)
        lastReportedPositionSeconds = clamped
        lastHardSeekUptimeMs = ProcessInfo.processInfo.systemUptime * 1000.0
        if let player = player, let item = playerItem, item.status == .readyToPlay {
            let cm = CMTime(seconds: clamped, preferredTimescale: 600)
            let tol = CMTime(seconds: 0.1, preferredTimescale: 600)
            player.seek(to: cm, toleranceBefore: tol, toleranceAfter: tol) { [weak self, weak player] _ in
                Task { @MainActor [weak self, weak player] in
                    guard let self = self, let player = player else { return }
                    if self.isPlayingState {
                        player.play()
                    }
                }
            }
        }
        onPlaybackStateChanged?(isPlayingState, clamped, currentDurationSeconds, true)
    }

    public func prepareSeekWhilePaused(trackId: String, to positionSeconds: Double) {
        guard currentTrackId == trackId, !isPlayingState else { return }
        let clamped = clampPosition(positionSeconds)
        lastReportedPositionSeconds = clamped
        if let player = player, let item = playerItem, item.status == .readyToPlay {
            let cm = CMTime(seconds: clamped, preferredTimescale: 600)
            let tol = CMTime(seconds: 0.1, preferredTimescale: 600)
            player.seek(to: cm, toleranceBefore: tol, toleranceAfter: tol)
        }
    }

    // MARK: - Zuverlässige zeitgesteuerte Synchronisation + Preroll + Watchdog

    public func schedulePlay(
        trackId: String,
        serverTimeToExecuteMs: Double,
        positionSeconds: Double,
        estimatedServerTimeMs: Double,
        nudgeMs: Double
    ) {
        cancelScheduledPause()
        cancelScheduledPlay()
        self.currentNudgeMs = nudgeMs

        if loadingTrackId == trackId && !hasTrackLoaded(trackId) {
            pendingPlayCommand = (
                trackId: trackId,
                serverTimeToExecuteMs: serverTimeToExecuteMs,
                positionSeconds: positionSeconds,
                estimatedServerTimeMs: estimatedServerTimeMs,
                nudgeMs: nudgeMs
            )
            self.isPlayingState = true
            self.lastReportedPositionSeconds = max(0.0, positionSeconds)
            onPlaybackStateChanged?(true, self.lastReportedPositionSeconds, currentDurationSeconds, true)
            return
        }

        guard let player = player, let item = playerItem, currentTrackId == trackId else {
            return
        }

        guard item.status == .readyToPlay else {
            pendingPlayCommand = (
                trackId: trackId,
                serverTimeToExecuteMs: serverTimeToExecuteMs,
                positionSeconds: positionSeconds,
                estimatedServerTimeMs: estimatedServerTimeMs,
                nudgeMs: nudgeMs
            )
            self.isPlayingState = true
            self.lastReportedPositionSeconds = max(0.0, positionSeconds)
            onPlaybackStateChanged?(true, self.lastReportedPositionSeconds, currentDurationSeconds, true)
            return
        }

        pendingPlayCommand = nil
        playCommandGeneration &+= 1
        let myPlayGen = playCommandGeneration

        configureAudioSession()
        player.automaticallyWaitsToMinimizeStalling = true
        player.volume = Float(globalVolume)

        let effectiveExecMs = serverTimeToExecuteMs > 0 ? serverTimeToExecuteMs : estimatedServerTimeMs
        self.anchorServerExecMs = effectiveExecMs
        self.anchorPositionSeconds = max(0.0, positionSeconds)
        self.lastAnchorTrackId = trackId

        let outputLatencyMs = currentOutputLatencyMs()
        let waitTimeMs = (effectiveExecMs - estimatedServerTimeMs) - outputLatencyMs + nudgeMs

        let clampedTargetPos: Double
        let startDelaySeconds: Double

        if waitTimeMs > (Self.lookaheadSeconds * 1000.0) && waitTimeMs < 5000.0 {
            clampedTargetPos = clampPosition(positionSeconds)
            startDelaySeconds = waitTimeMs / 1000.0
        } else {
            let overdueSec = waitTimeMs < 0 ? (-waitTimeMs / 1000.0) : 0.0
            startDelaySeconds = 0.0
            clampedTargetPos = clampPosition(positionSeconds + overdueSec)
        }

        self.lastReportedPositionSeconds = clampedTargetPos
        self.isPlayingState = true
        self.lastHardSeekUptimeMs = ProcessInfo.processInfo.systemUptime * 1000.0

        onPlaybackStateChanged?(true, clampedTargetPos, currentDurationSeconds, true)

        let curItemSec = item.currentTime().seconds
        let expectedAtExec = clampPosition(expectedServerPositionNow())
        let alreadyPlayingNearTarget = (player.timeControlStatus == .playing || player.rate > 0.05)
            && curItemSec.isFinite
            && abs(curItemSec - expectedAtExec) < 0.25
            && startDelaySeconds < 0.25

        if alreadyPlayingNearTarget {
            // Bereits optimistisch gestartet: kein hartes Pause/Seek-Stottern, PLL zieht nahtlos auf <25 ms ein
            self.schedulePlayWatchdog(trackId: trackId, playGen: myPlayGen)
            return
        }

        let needsSeek = !curItemSec.isFinite || abs(curItemSec - clampedTargetPos) > 0.35

        let startPlaybackBlock: () -> Void = { [weak self, weak player] in
            guard let self = self,
                  let player = player,
                  self.isPlayingState,
                  self.currentTrackId == trackId,
                  self.playCommandGeneration == myPlayGen else {
                return
            }

            if startDelaySeconds > 0.03 {
                player.pause()
                player.preroll(atRate: 1.0) { _ in }

                let fireAt = DispatchTime.now() + .milliseconds(Int((startDelaySeconds * 1000.0).rounded()))
                let startWork = DispatchWorkItem { [weak self, weak player] in
                    Task { @MainActor [weak self, weak player] in
                        guard let self = self,
                              let player = player,
                              self.isPlayingState,
                              self.currentTrackId == trackId,
                              self.playCommandGeneration == myPlayGen else {
                            return
                        }
                        player.play()
                        self.schedulePlayWatchdog(trackId: trackId, playGen: myPlayGen)
                    }
                }
                self.scheduledPlayWorkItem = startWork
                DispatchQueue.main.asyncAfter(deadline: fireAt, execute: startWork)
            } else {
                player.play()
                self.schedulePlayWatchdog(trackId: trackId, playGen: myPlayGen)
            }
        }

        if needsSeek {
            if startDelaySeconds > 0.03 {
                player.pause()
            }
            let targetCMTime = CMTime(seconds: clampedTargetPos, preferredTimescale: 600)
            let tolerance = CMTime(seconds: 0.08, preferredTimescale: 600)
            player.seek(to: targetCMTime, toleranceBefore: tolerance, toleranceAfter: tolerance) { _ in
                Task { @MainActor [weak self] in
                    guard let self = self, self.playCommandGeneration == myPlayGen else { return }
                    startPlaybackBlock()
                }
            }
        } else {
            startPlaybackBlock()
        }
    }

    private func schedulePlayWatchdog(trackId: String, playGen: UInt64) {
        playWatchdogWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self,
                      self.isPlayingState,
                      self.currentTrackId == trackId,
                      self.playCommandGeneration == playGen,
                      let player = self.player,
                      let item = self.playerItem,
                      item.status == .readyToPlay else {
                    return
                }
                // Sicherheitsnetz: Falls CoreAudio/AVPlayer nach Seek/Preroll bei rate == 0 stehen blieb, sofort anstoßen
                if player.timeControlStatus == .paused || player.rate == 0.0 {
                    self.configureAudioSession()
                    player.play()
                }
            }
        }
        playWatchdogWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(350), execute: work)
    }

    public func schedulePause(
        positionSeconds: Double,
        serverTimeToExecuteMs: Double,
        estimatedServerTimeMs: Double,
        nudgeMs: Double
    ) {
        cancelScheduledPause()
        cancelScheduledPlay()
        pendingPlayCommand = nil
        playCommandGeneration &+= 1
        self.currentNudgeMs = nudgeMs

        let outputLatencyMs = currentOutputLatencyMs()
        let waitTimeMs = serverTimeToExecuteMs > 0
            ? (serverTimeToExecuteMs - estimatedServerTimeMs) - outputLatencyMs + nudgeMs
            : 0.0

        if waitTimeMs > 25.0 && waitTimeMs < 5000.0 {
            let work = DispatchWorkItem { [weak self] in
                Task { @MainActor [weak self] in
                    self?.executePauseNow(positionSeconds: positionSeconds)
                }
            }
            scheduledPauseWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(waitTimeMs.rounded())), execute: work)
        } else {
            executePauseNow(positionSeconds: positionSeconds)
        }
    }

    private func executePauseNow(positionSeconds: Double) {
        scheduledPauseWorkItem = nil
        isPlayingState = false
        let clamped = clampPosition(positionSeconds)
        lastReportedPositionSeconds = clamped

        if let player = player {
            player.pause()
            if let item = playerItem, item.status == .readyToPlay {
                let curPos = item.currentTime().seconds
                if !curPos.isFinite || abs(curPos - clamped) > 0.35 {
                    let cm = CMTime(seconds: clamped, preferredTimescale: 600)
                    let tol = CMTime(seconds: 0.08, preferredTimescale: 600)
                    player.seek(to: cm, toleranceBefore: tol, toleranceAfter: tol)
                }
            }
        }

        onPlaybackStateChanged?(false, clamped, currentDurationSeconds, true)
    }

    public func applyLiveNudge(totalNudgeMs: Double, deltaMs: Double) {
        self.currentNudgeMs = totalNudgeMs
        guard isPlayingState, let player = player, playerItem?.status == .readyToPlay else { return }

        if abs(deltaMs) >= 40.0 {
            let expected = clampPosition(expectedServerPositionNow())
            let targetCM = CMTime(seconds: expected, preferredTimescale: 600)
            let tol = CMTime(seconds: 0.05, preferredTimescale: 600)
            player.seek(to: targetCM, toleranceBefore: tol, toleranceAfter: tol) { [weak self, weak player] _ in
                Task { @MainActor [weak self, weak player] in
                    guard let self = self, let player = player, self.isPlayingState else { return }
                    player.play()
                }
            }
        } else {
            performDriftCorrectionTick()
        }
    }

    // MARK: - Continuous PLL Drift Lock (Ohne Ruckeln oder Neu-Buffering)

    private func expectedServerPositionNow() -> Double {
        let serverNow = serverTimeProvider?() ?? (Date().timeIntervalSince1970 * 1000.0)
        let outputLatencyMs = currentOutputLatencyMs()
        let elapsedMs = (serverNow - anchorServerExecMs) - outputLatencyMs + currentNudgeMs
        return max(0.0, anchorPositionSeconds + (elapsedMs / 1000.0))
    }

    private func performDriftCorrectionTick() {
        guard isPlayingState,
              let player = player,
              let item = playerItem,
              item.status == .readyToPlay,
              currentTrackId == lastAnchorTrackId,
              anchorServerExecMs > 0 else {
            return
        }

        if player.timeControlStatus == .paused || player.rate == 0.0 {
            player.play()
            return
        }

        let actual = item.currentTime().seconds
        guard actual.isFinite else { return }

        let expected = expectedServerPositionNow()
        if currentDurationSeconds > 1.0 && expected >= currentDurationSeconds - 0.15 {
            return
        }

        let driftSec = actual - expected
        let absDrift = abs(driftSec)
        let nowUptime = ProcessInfo.processInfo.systemUptime * 1000.0

        if absDrift > 0.55 {
            if nowUptime - lastHardSeekUptimeMs < 2500.0 {
                return
            }
            lastHardSeekUptimeMs = nowUptime
            let target = clampPosition(expected)
            let cm = CMTime(seconds: target, preferredTimescale: 600)
            let tol = CMTime(seconds: 0.08, preferredTimescale: 600)
            player.seek(to: cm, toleranceBefore: tol, toleranceAfter: tol) { [weak self, weak player] _ in
                Task { @MainActor [weak self, weak player] in
                    guard let self = self, let player = player, self.isPlayingState else { return }
                    player.play()
                }
            }
        } else if absDrift > 0.025 {
            let targetRate: Float = driftSec > 0 ? 0.985 : 1.015
            if abs(player.rate - targetRate) > 0.002 {
                player.rate = targetRate
            }
        } else {
            if abs(player.rate - 1.0) > 0.002 {
                player.rate = 1.0
            }
        }
    }

    // MARK: - Observers & Lifecycle

    private func setupTimeObserver(for targetPlayer: AVPlayer) {
        if let tok = timeObserverToken {
            targetPlayer.removeTimeObserver(tok)
            timeObserverToken = nil
        }

        let interval = CMTime(seconds: 0.4, preferredTimescale: 600)
        timeObserverToken = targetPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let sec = time.seconds
                guard sec.isFinite, sec >= 0 else { return }
                self.lastReportedPositionSeconds = self.currentDurationSeconds > 0
                    ? min(self.currentDurationSeconds, sec)
                    : sec

                if self.isPlayingState {
                    self.performDriftCorrectionTick()
                }

                let nowUptime = ProcessInfo.processInfo.systemUptime * 1000.0
                if nowUptime - self.lastPlaybackEmitUptimeMs >= 400.0 {
                    self.lastPlaybackEmitUptimeMs = nowUptime
                    self.onPlaybackStateChanged?(self.isPlayingState, self.lastReportedPositionSeconds, self.currentDurationSeconds, false)
                }
            }
        }
    }

    private func registerEndObservers(for item: AVPlayerItem) {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleItemDidEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
    }

    @objc private func handleItemDidEnd() {
        Task { @MainActor [weak self] in
            guard let self = self, self.isPlayingState, let tid = self.currentTrackId else { return }
            self.isPlayingState = false
            self.lastReportedPositionSeconds = self.currentDurationSeconds
            self.onPlaybackStateChanged?(false, self.currentDurationSeconds, self.currentDurationSeconds, true)
            self.onTrackEnded?(tid)
        }
    }

    public func stopAll() {
        loadGeneration &+= 1
        playCommandGeneration &+= 1
        finishReadyContinuation(with: nil)
        cancelScheduledPlay()
        cancelScheduledPause()
        pendingPlayCommand = nil
        cleanupItemObservers()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        if let tok = timeObserverToken, let p = player {
            p.removeTimeObserver(tok)
            timeObserverToken = nil
        }
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil

        currentTrackId = nil
        loadingTrackId = nil
        isItemReady = false
        isPlayingState = false
        lastReportedPositionSeconds = 0.0
        currentDurationSeconds = 0.0
        anchorServerExecMs = 0.0
        anchorPositionSeconds = 0.0
        lastAnchorTrackId = nil
    }

    private func cancelScheduledPlay() {
        scheduledPlayWorkItem?.cancel()
        scheduledPlayWorkItem = nil
        playWatchdogWorkItem?.cancel()
        playWatchdogWorkItem = nil
    }

    private func cancelScheduledPause() {
        scheduledPauseWorkItem?.cancel()
        scheduledPauseWorkItem = nil
    }

    private func cleanupItemObservers() {
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        itemDurationObserver?.invalidate()
        itemDurationObserver = nil
        itemRateObserver?.invalidate()
        itemRateObserver = nil
    }

    private func clampPosition(_ sec: Double) -> Double {
        let low = max(0.0, sec)
        if currentDurationSeconds > 1.0 {
            return min(currentDurationSeconds, low)
        }
        return low
    }

    private func buildIOSCompatibleStreamURL(trackId: String, rawStreamURL: String, serverURL: String) -> URL? {
        var cleanServer = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanServer.hasPrefix("http://") && !cleanServer.hasPrefix("https://") {
            cleanServer = "http://" + cleanServer
        }
        cleanServer = cleanServer.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let resolvedString: String
        if rawStreamURL.hasPrefix("http://") || rawStreamURL.hasPrefix("https://") {
            resolvedString = rawStreamURL
        } else if rawStreamURL.hasPrefix("/") {
            resolvedString = cleanServer + rawStreamURL
        } else if !rawStreamURL.isEmpty {
            resolvedString = cleanServer + "/" + rawStreamURL
        } else {
            let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
            let encoded = trackId.addingPercentEncoding(withAllowedCharacters: allowed) ?? trackId
            resolvedString = "\(cleanServer)/api/stream/\(encoded)"
        }

        guard var comps = URLComponents(string: resolvedString) else { return nil }
        if comps.path.contains("/api/stream/") {
            if SessionManager.shared.isExpensiveConnection || SessionManager.shared.isConstrainedConnection {
                var items = comps.queryItems ?? []
                items.removeAll { $0.name.lowercased() == "quality" }
                items.append(URLQueryItem(name: "quality", value: "low"))
                comps.queryItems = items
            }
        }
        return comps.url
    }
}
