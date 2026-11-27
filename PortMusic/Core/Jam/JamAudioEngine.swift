import Foundation
import AVFoundation
import Darwin

/// Hardware-gekoppelte Sample-genaue Audio-Engine für Port Music Jam auf Basis von
/// AVAudioEngine + AVAudioPlayerNode + AVAudioFile (spart RAM gegenüber Voll-Decode im Browser
/// und plant Startzeiten über AVAudioTime(hostTime:) direkt gegen den CoreAudio-HAL).
@MainActor
public final class JamAudioEngine {
    public static let shared = JamAudioEngine()

    public static let maxTrustworthyOutputLatencyMs: Double = 100.0
    private static let lookaheadMs: Double = 25.0
    private static let maxCachedFiles: Int = 4

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let mixerNode = AVAudioMixerNode()
    private var isEngineConfigured: Bool = false
    private var connectedAudioFormat: AVAudioFormat? = nil

    private var currentTrackId: String? = nil
    private var loadingTrackId: String? = nil
    private var activeAudioFile: AVAudioFile? = nil
    private var currentDurationSeconds: Double = 0.0
    private var isPlayingState: Bool = false
    private var playbackOffsetSeconds: Double = 0.0
    private var scheduledStartHostTicks: UInt64 = 0
    private var segmentGeneration: UInt64 = 0
    private var loadGeneration: UInt64 = 0
    private var scheduledPauseWorkItem: DispatchWorkItem? = nil
    private var progressTimer: Timer? = nil

    private var cachedFileOrder: [String] = []
    private var cachedFilesByTrackId: [String: URL] = [:]
    private var pendingPlayCommand: (trackId: String, serverTimeToExecuteMs: Double, positionSeconds: Double, estimatedServerTimeMs: Double, nudgeMs: Double)? = nil

    public var onTrackEnded: ((String) -> Void)?
    public var onPlaybackStateChanged: ((Bool, Double, Double) -> Void)?
    public var onAudioRouteChanged: (() -> Void)?

    private lazy var cacheDirectoryURL: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("JamAudioCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private lazy var timebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

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
                    self.ensureEngineRunning()
                }
            }
        }
    }

    // MARK: - Clock & Hardware Latency Helpers

    public func currentOutputLatencyMs() -> Double {
        let rawMs = AVAudioSession.sharedInstance().outputLatency * 1000.0
        if rawMs > Self.maxTrustworthyOutputLatencyMs || rawMs < 0 {
            return 0.0
        }
        return rawMs
    }

    private func nsToMachTicks(_ nanoseconds: Double) -> UInt64 {
        guard nanoseconds > 0 else { return 0 }
        let numer = Double(timebaseInfo.numer == 0 ? 1 : timebaseInfo.numer)
        let denom = Double(timebaseInfo.denom == 0 ? 1 : timebaseInfo.denom)
        return UInt64((nanoseconds * denom) / numer)
    }

    private func machTicksToSeconds(_ ticks: UInt64) -> Double {
        guard ticks > 0 else { return 0 }
        let numer = Double(timebaseInfo.numer == 0 ? 1 : timebaseInfo.numer)
        let denom = Double(timebaseInfo.denom == 0 ? 1 : timebaseInfo.denom)
        return (Double(ticks) * numer / denom) / 1_000_000_000.0
    }

    // MARK: - Engine Lifecycle

    private func configureEngineIfNeeded(format: AVAudioFormat?) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("[JamAudioEngine] AudioSession error: \(error)")
        }

        if !isEngineConfigured {
            engine.attach(playerNode)
            engine.attach(mixerNode)
            engine.connect(playerNode, to: mixerNode, format: format)
            engine.connect(mixerNode, to: engine.mainMixerNode, format: nil)
            connectedAudioFormat = format
            engine.prepare()
            isEngineConfigured = true
        } else if let fmt = format, fmt != connectedAudioFormat {
            playerNode.stop()
            engine.disconnectNodeOutput(playerNode)
            engine.connect(playerNode, to: mixerNode, format: fmt)
            connectedAudioFormat = fmt
        }

        ensureEngineRunning()
    }

    private func ensureEngineRunning() {
        if !isEngineConfigured {
            configureEngineIfNeeded(format: nil)
            return
        }
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("[JamAudioEngine] Engine start failed: \(error)")
            }
        }
    }

    public func setGlobalVolume(_ volume: Double) {
        let clamped = Float(max(0.0, min(1.0, volume)))
        mixerNode.outputVolume = clamped
    }

    // MARK: - Track Loading & Container Format Resolution

    public func hasTrackLoaded(_ trackId: String) -> Bool {
        return currentTrackId == trackId && activeAudioFile != nil
    }

    public func isTrackLoading(_ trackId: String) -> Bool {
        return loadingTrackId == trackId
    }

    public func loadTrack(
        trackId: String,
        streamURLString: String,
        serverURL: String,
        token: String?
    ) async -> Double? {
        loadGeneration &+= 1
        let myLoadGen = loadGeneration
        loadingTrackId = trackId

        // 1. Offline-Cache oder Jam-LRU-Cache zuerst prüfen (0 ms Start)
        if let localOffline = OfflineDownloadManager.shared.localAudioFileURL(for: trackId),
           let file = try? AVAudioFile(forReading: localOffline) {
            return finalizeLoadedFile(file: file, trackId: trackId, loadGen: myLoadGen)
        }

        if let cachedURL = cachedFilesByTrackId[trackId],
           FileManager.default.fileExists(atPath: cachedURL.path),
           let file = try? AVAudioFile(forReading: cachedURL) {
            return finalizeLoadedFile(file: file, trackId: trackId, loadGen: myLoadGen)
        }

        // 2. Kompatible Stream-URL bauen (iOS braucht AAC/M4A/MP3, niemals WebM/Opus)
        guard let downloadURL = buildIOSCompatibleStreamURL(
            trackId: trackId,
            rawStreamURL: streamURLString,
            serverURL: serverURL
        ) else {
            if myLoadGen == loadGeneration {
                loadingTrackId = nil
            }
            return nil
        }

        var request = URLRequest(url: downloadURL)
        request.timeoutInterval = 30.0
        request.setValue("PortMusic-iOS/1.0", forHTTPHeaderField: "User-Agent")
        if let tok = token, !tok.isEmpty {
            request.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            request.setValue(tok, forHTTPHeaderField: "x-session-token")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard myLoadGen == loadGeneration else { return nil }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), !data.isEmpty else {
                loadingTrackId = nil
                return nil
            }

            let contentType = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
            let ext = resolveAudioExtension(contentType: contentType, data: data)
            let safeName = trackId.replacingOccurrences(of: "[^a-zA-Z0-9._-]", with: "_", options: .regularExpression)
            let destURL = cacheDirectoryURL.appendingPathComponent("\(safeName).\(ext)")

            try? FileManager.default.removeItem(at: destURL)
            try data.write(to: destURL, options: [.atomic])
            recordCachedFile(trackId: trackId, url: destURL)

            let file = try AVAudioFile(forReading: destURL)
            return finalizeLoadedFile(file: file, trackId: trackId, loadGen: myLoadGen)
        } catch {
            if myLoadGen == loadGeneration {
                loadingTrackId = nil
            }
            print("[JamAudioEngine] Download/Open failed for \(trackId): \(error)")
            return nil
        }
    }

    private func finalizeLoadedFile(file: AVAudioFile, trackId: String, loadGen: UInt64) -> Double? {
        guard loadGen == loadGeneration else { return nil }

        let sampleRate = file.processingFormat.sampleRate
        let duration = sampleRate > 0 ? Double(file.length) / sampleRate : 0.0

        configureEngineIfNeeded(format: file.processingFormat)
        self.activeAudioFile = file
        self.currentTrackId = trackId
        self.loadingTrackId = nil
        self.currentDurationSeconds = duration
        self.playbackOffsetSeconds = 0.0

        if let pending = pendingPlayCommand, pending.trackId == trackId {
            self.pendingPlayCommand = nil
            schedulePlay(
                trackId: pending.trackId,
                serverTimeToExecuteMs: pending.serverTimeToExecuteMs,
                positionSeconds: pending.positionSeconds,
                estimatedServerTimeMs: pending.estimatedServerTimeMs,
                nudgeMs: pending.nudgeMs
            )
        }

        return duration
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
            if var items = comps.queryItems {
                items.removeAll { $0.name.lowercased() == "quality" }
                items.append(URLQueryItem(name: "quality", value: "low"))
                comps.queryItems = items
            } else {
                comps.queryItems = [URLQueryItem(name: "quality", value: "low")]
            }
        }
        return comps.url
    }

    private func resolveAudioExtension(contentType: String, data: Data) -> String {
        if contentType.contains("mpeg") || contentType.contains("mp3") {
            return "mp3"
        }
        if contentType.contains("wav") {
            return "wav"
        }
        if contentType.contains("flac") {
            return "flac"
        }
        if data.count >= 4 {
            let magic = [UInt8](data.prefix(4))
            if magic[0] == 0x49 && magic[1] == 0x44 && magic[2] == 0x33 { // ID3
                return "mp3"
            }
            if magic[0] == 0xFF && (magic[1] & 0xE0) == 0xE0 {
                return "mp3"
            }
        }
        return "m4a"
    }

    private func recordCachedFile(trackId: String, url: URL) {
        cachedFileOrder.removeAll { $0 == trackId }
        cachedFileOrder.append(trackId)
        cachedFilesByTrackId[trackId] = url

        while cachedFileOrder.count > Self.maxCachedFiles {
            let oldest = cachedFileOrder.removeFirst()
            if oldest != currentTrackId, let oldURL = cachedFilesByTrackId.removeValue(forKey: oldest) {
                try? FileManager.default.removeItem(at: oldURL)
            }
        }
    }

    // MARK: - Sample-Accurate Scheduled Playback

    public func schedulePlay(
        trackId: String,
        serverTimeToExecuteMs: Double,
        positionSeconds: Double,
        estimatedServerTimeMs: Double,
        nudgeMs: Double
    ) {
        cancelScheduledPause()

        if loadingTrackId == trackId && !hasTrackLoaded(trackId) {
            pendingPlayCommand = (
                trackId: trackId,
                serverTimeToExecuteMs: serverTimeToExecuteMs,
                positionSeconds: positionSeconds,
                estimatedServerTimeMs: estimatedServerTimeMs,
                nudgeMs: nudgeMs
            )
            return
        }

        guard let file = activeAudioFile, currentTrackId == trackId else {
            return
        }

        pendingPlayCommand = nil
        ensureEngineRunning()

        let outputLatencyMs = currentOutputLatencyMs()
        // Einheitliches Vorzeichen: negatives nudge ("-ms früher") verkürzt Wartezeit bzw. springt weiter vor
        let waitTimeMs = (serverTimeToExecuteMs - estimatedServerTimeMs) - outputLatencyMs + nudgeMs

        let nowTicks = mach_absolute_time()
        let targetHostTicks: UInt64
        let startPositionSeconds: Double

        if waitTimeMs > Self.lookaheadMs {
            targetHostTicks = nowTicks + nsToMachTicks(waitTimeMs * 1_000_000.0)
            startPositionSeconds = positionSeconds
        } else {
            let overdueSec = waitTimeMs < 0 ? (-waitTimeMs / 1000.0) : 0.0
            let lookaheadSec = Self.lookaheadMs / 1000.0
            targetHostTicks = nowTicks + nsToMachTicks(Self.lookaheadMs * 1_000_000.0)
            startPositionSeconds = positionSeconds + overdueSec + lookaheadSec
        }

        startSegment(file: file, trackId: trackId, atPositionSeconds: startPositionSeconds, hostTicks: targetHostTicks)
    }

    private func startSegment(file: AVAudioFile, trackId: String, atPositionSeconds positionSec: Double, hostTicks: UInt64) {
        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return }

        let totalFrames = AVAudioFramePosition(file.length)
        let clampedSec = max(0.0, min(currentDurationSeconds, positionSec))
        let startFrame = AVAudioFramePosition(clampedSec * sampleRate)

        guard startFrame < totalFrames else {
            stopNodeAndTimers(preserveOffset: currentDurationSeconds)
            onTrackEnded?(trackId)
            return
        }

        let remainingFrames = AVAudioFrameCount(totalFrames - startFrame)
        guard remainingFrames > 0 else { return }

        segmentGeneration &+= 1
        let myGen = segmentGeneration

        playerNode.stop()

        playerNode.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: remainingFrames,
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard myGen == self.segmentGeneration, self.isPlayingState, self.currentTrackId == trackId else {
                    return
                }
                self.isPlayingState = false
                self.playbackOffsetSeconds = self.currentDurationSeconds
                self.stopProgressTimer()
                self.onPlaybackStateChanged?(false, self.currentDurationSeconds, self.currentDurationSeconds)
                self.onTrackEnded?(trackId)
            }
        }

        let audioStartTime = AVAudioTime(hostTime: hostTicks)
        playerNode.play(at: audioStartTime)

        self.playbackOffsetSeconds = clampedSec
        self.scheduledStartHostTicks = hostTicks
        self.isPlayingState = true

        startProgressTimer()
        onPlaybackStateChanged?(true, clampedSec, currentDurationSeconds)
    }

    public func schedulePause(
        positionSeconds: Double,
        serverTimeToExecuteMs: Double,
        estimatedServerTimeMs: Double,
        nudgeMs: Double
    ) {
        cancelScheduledPause()
        pendingPlayCommand = nil

        let outputLatencyMs = currentOutputLatencyMs()
        let waitTimeMs = serverTimeToExecuteMs > 0
            ? (serverTimeToExecuteMs - estimatedServerTimeMs) - outputLatencyMs + nudgeMs
            : 0.0

        if waitTimeMs > 15.0 {
            let work = DispatchWorkItem { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.executePauseNow(positionSeconds: positionSeconds)
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
        stopNodeAndTimers(preserveOffset: positionSeconds)
        onPlaybackStateChanged?(false, playbackOffsetSeconds, currentDurationSeconds)
    }

    public func applyLiveNudge(deltaMs: Double) {
        guard isPlayingState, let file = activeAudioFile, let trackId = currentTrackId else { return }
        let curPos = currentPositionSeconds()
        let lookaheadSec = Self.lookaheadMs / 1000.0
        let adjustedPos = max(0.0, min(currentDurationSeconds, curPos - (deltaMs / 1000.0) + lookaheadSec))
        let targetTicks = mach_absolute_time() + nsToMachTicks(Self.lookaheadMs * 1_000_000.0)
        startSegment(file: file, trackId: trackId, atPositionSeconds: adjustedPos, hostTicks: targetTicks)
    }

    public func currentPositionSeconds() -> Double {
        guard isPlayingState else {
            return playbackOffsetSeconds
        }
        let nowTicks = mach_absolute_time()
        guard nowTicks > scheduledStartHostTicks else {
            return playbackOffsetSeconds
        }
        let elapsed = machTicksToSeconds(nowTicks - scheduledStartHostTicks)
        return min(currentDurationSeconds, playbackOffsetSeconds + elapsed)
    }

    public func currentDuration() -> Double {
        return currentDurationSeconds
    }

    public func getIsPlaying() -> Bool {
        return isPlayingState
    }

    public func stopAll() {
        cancelScheduledPause()
        pendingPlayCommand = nil
        loadGeneration &+= 1
        loadingTrackId = nil
        stopNodeAndTimers(preserveOffset: 0.0)
        activeAudioFile = nil
        currentTrackId = nil
        currentDurationSeconds = 0.0
        if engine.isRunning {
            engine.stop()
        }
    }

    private func cancelScheduledPause() {
        scheduledPauseWorkItem?.cancel()
        scheduledPauseWorkItem = nil
    }

    private func stopNodeAndTimers(preserveOffset: Double) {
        segmentGeneration &+= 1
        playerNode.stop()
        stopProgressTimer()
        isPlayingState = false
        playbackOffsetSeconds = preserveOffset
    }

    private func startProgressTimer() {
        stopProgressTimer()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isPlayingState else { return }
                let pos = self.currentPositionSeconds()
                self.onPlaybackStateChanged?(true, pos, self.currentDurationSeconds)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
