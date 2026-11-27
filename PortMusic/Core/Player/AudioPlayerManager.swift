import Foundation
import AVFoundation
import MediaPlayer
import Combine
import UIKit

@MainActor
public final class AudioPlayerProgress: ObservableObject {
    public static let shared = AudioPlayerProgress()

    @Published public var currentTime: Double = 0.0

    private init() {}
}

@MainActor
public final class AudioPlayerManager: ObservableObject {
    public static let shared = AudioPlayerManager()

    // MARK: - Reactive State (Non-High-Frequency)
    @Published public private(set) var currentTrack: Track? = nil
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var isBuffering: Bool = false
    @Published public private(set) var isPlayingOffline: Bool = false
    @Published public private(set) var duration: Double = 0.0
    @Published public private(set) var queue: [Track] = []
    @Published public private(set) var queueIndex: Int = 0
    @Published public private(set) var recentTracks: [Track] = []
    @Published public private(set) var pastTracks: [Track] = []

    @Published public var isShuffle: Bool = false
    @Published public var isRepeat: Bool = false

    // Entkoppelte Wiedergabeposition: AudioPlayerProgress publiziert separat,
    // damit nicht der gesamte SwiftUI-View-Tree (HomeView, MainTabView, TrackRows) 4x pro Sekunde invalidiert wird.
    public var currentTime: Double {
        get { AudioPlayerProgress.shared.currentTime }
        set { AudioPlayerProgress.shared.currentTime = newValue }
    }

    public private(set) var currentServerURL: String? = nil
    private var lastPreviousTapTime: Date? = nil
    private var isNavigatingBackward: Bool = false
    private var pendingSeekTime: Double? = nil
    private var activeQualityOverride: String? = nil
    private var didAttemptQualityFallbackForCurrentTrack: Bool = false
    private var consecutiveFailureSkips: Int = 0
    private var isAdvancingAfterFailure: Bool = false
    private var skipTimerWorkItem: DispatchWorkItem? = nil
    private let recentTracksStorageKey = "port_music_recent_tracks"

    private var configuredSkipTimeoutSeconds: Int {
        if UserDefaults.standard.object(forKey: "playback_skip_timeout") != nil {
            return max(0, UserDefaults.standard.integer(forKey: "playback_skip_timeout"))
        }
        return 10
    }

    // MARK: - Internal Player Properties
    private var avPlayer: AVPlayer? = nil
    private var timeObserverToken: Any? = nil
    private var itemStatusObserver: NSKeyValueObservation? = nil
    private var itemDurationObserver: NSKeyValueObservation? = nil
    private var itemBufferObserver: NSKeyValueObservation? = nil
    @Published public private(set) var nowPlayingArtwork: UIImage? = nil

    public func setVolume(_ volume: Float) {
        avPlayer?.volume = max(0.0, min(1.0, volume))
    }

    private let lastPlayedTrackKey = "port_music_last_played_track"
    private let lastPlayedTimeKey = "port_music_last_played_time"
    private let lastPlayedDurationKey = "port_music_last_played_duration"
    private let lastPlayedQueueKey = "port_music_last_played_queue"

    private init() {
        setupAudioSession()
        setupRemoteCommandCenter()
        loadPersistedRecentTracks()
        loadPersistedPlayerState()
    }

    // MARK: - Last Played State Persistence & Restoration
    public func loadPersistedPlayerState() {
        if self.currentTrack != nil { return }
        if let data = UserDefaults.standard.data(forKey: lastPlayedTrackKey),
           let track = try? JSONDecoder().decode(Track.self, from: data) {
            self.currentTrack = track
            let savedTime = UserDefaults.standard.double(forKey: lastPlayedTimeKey)
            let savedDur = UserDefaults.standard.double(forKey: lastPlayedDurationKey)
            let parsed = parseDurationSeconds(from: track)
            self.currentTime = max(0, savedTime)
            if parsed > 0 && savedDur > 0 && abs(savedDur - parsed * 2.0) < 25.0 {
                self.duration = parsed
            } else if parsed > 0 {
                self.duration = parsed
            } else {
                self.duration = savedDur > 0 ? savedDur : 0.0
            }

            if let qData = UserDefaults.standard.data(forKey: lastPlayedQueueKey),
               let q = try? JSONDecoder().decode([Track].self, from: qData) {
                self.queue = q
            } else {
                self.queue = [track]
            }
            self.isPlayingOffline = OfflineDownloadManager.shared.localAudioFileURL(for: track.id) != nil
            loadArtwork(from: track.coverUrl)
        }
    }

    public func persistPlayerState() {
        guard let track = currentTrack else { return }
        if let data = try? JSONEncoder().encode(track) {
            UserDefaults.standard.set(data, forKey: lastPlayedTrackKey)
        }
        UserDefaults.standard.set(self.currentTime, forKey: lastPlayedTimeKey)
        UserDefaults.standard.set(self.duration, forKey: lastPlayedDurationKey)
        if let qData = try? JSONEncoder().encode(self.queue) {
            UserDefaults.standard.set(qData, forKey: lastPlayedQueueKey)
        }
    }

    public func syncLastPlayedFromServerIfNeeded(serverURL: String, token: String?) async {
        if self.currentTrack != nil { return }
        let statsTracks = await MusicService.shared.fetchStats(serverURL: serverURL, token: token)
        if let first = statsTracks.first, self.currentTrack == nil {
            await MainActor.run {
                self.currentTrack = first
                self.duration = self.parseDurationSeconds(from: first)
                self.currentTime = 0
                self.queue = statsTracks
                self.persistPlayerState()
            }
        }
    }

    // MARK: - Local Recent Tracks Persistence
    private func loadPersistedRecentTracks() {
        guard let data = UserDefaults.standard.data(forKey: recentTracksStorageKey),
              let list = try? JSONDecoder().decode([Track].self, from: data) else {
            return
        }
        self.recentTracks = list
    }

    private func persistRecentTracks() {
        guard let data = try? JSONEncoder().encode(self.recentTracks) else { return }
        UserDefaults.standard.set(data, forKey: recentTracksStorageKey)
    }

    // MARK: - Audio Session Configuration
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("AudioPlayerManager: Audio session configuration error: \(error)")
        }
    }

    // MARK: - Duration String Parser Helper
    public func parseDurationSeconds(from track: Track) -> Double {
        let clean = track.duration.trimmingCharacters(in: .whitespacesAndNewlines)
        var parsedSec = 0.0
        let parts = clean.split(separator: ":").compactMap { Double($0) }
        if parts.count == 2 {
            parsedSec = parts[0] * 60.0 + parts[1]
        } else if parts.count == 3 {
            parsedSec = parts[0] * 3600.0 + parts[1] * 60.0 + parts[2]
        } else if let direct = Double(clean), direct > 0 {
            parsedSec = direct
        }

        let rawSec = track.durationSeconds
        // If rawSec was corrupted by previous doubling bug to ~2x of parsed string, prefer parsedSec
        if parsedSec > 0 && rawSec > 0 && abs(rawSec - parsedSec * 2.0) < 25.0 {
            return parsedSec
        }
        if rawSec > 0 {
            return rawSec
        }
        if parsedSec > 0 {
            return parsedSec
        }
        return 0.0
    }

    // MARK: - Duration Resolution Helper (Authoritative Metadata + CoreMedia AAC SBR Fix)
    public func resolveAuthoritativeDuration(knownTrack: Track?, audioDuration: Double) -> Double {
        let known = knownTrack != nil ? parseDurationSeconds(from: knownTrack!) : 0.0
        let validAudioDur = (!audioDuration.isNaN && audioDuration > 1.0) ? audioDuration : 0.0

        // WebKit CoreMedia AAC SBR doubling bug detection (matches frontend/src/context/player/utils.ts)
        let isDoubled = validAudioDur > 0 && known > 0 &&
            (abs(validAudioDur - known * 2.0) < 25.0 ||
             (validAudioDur > known * 1.7 && validAudioDur < known * 2.3))

        if isDoubled {
            return known > 0 ? known : round(validAudioDur / 2.0)
        } else if known > 10.0 {
            // Reale Metadaten-Dauer von Apple/Deezer ist stets die verbindliche Songdauer
            return known
        } else if validAudioDur > 0 {
            return validAudioDur
        }
        return known > 0 ? known : 0.0
    }

    // MARK: - Playback Control API
    private func resolveOfflineCandidate(
        requested: Track,
        contextQueue: [Track]
    ) -> (track: Track, queue: [Track])? {
        guard SessionManager.shared.isOfflineMode else {
            return (requested, contextQueue)
        }

        let downloader = OfflineDownloadManager.shared
        if !requested.isLive && downloader.localAudioFileURL(for: requested.id) != nil {
            return (requested, contextQueue)
        }

        // Offline: wenn gewuenschter Song nicht heruntergeladen ist, automatisch auf naechsten geladenen Song springen
        let candidatePool: [Track]
        if contextQueue.count > 1 {
            candidatePool = contextQueue
        } else if !self.queue.isEmpty {
            candidatePool = self.queue
        } else {
            candidatePool = downloader.allDownloadedTracks()
        }

        if let startIdx = candidatePool.firstIndex(where: { $0.id == requested.id }) {
            let after = candidatePool.indices.dropFirst(startIdx + 1).first {
                downloader.localAudioFileURL(for: candidatePool[$0].id) != nil
            }
            let wrapped = after ?? candidatePool.indices.first {
                downloader.localAudioFileURL(for: candidatePool[$0].id) != nil
            }
            if let matchIdx = wrapped {
                return (candidatePool[matchIdx], candidatePool)
            }
        } else if let firstInPool = candidatePool.first(where: {
            downloader.localAudioFileURL(for: $0.id) != nil
        }) {
            return (firstInPool, candidatePool)
        }

        let allOffline = downloader.allDownloadedTracks()
        if let fallback = allOffline.first {
            return (fallback, allOffline)
        }
        return nil
    }

    // MARK: - Jam Integration Bridge
    public func pauseAndPrepareForJam() {
        avPlayer?.pause()
        avPlayer?.replaceCurrentItem(with: nil)
        cleanupCurrentItem()
        self.isPlaying = false
        self.isBuffering = false
        self.isPlayingOffline = false
    }

    public func applyJamExternalPlaybackState(
        track: Track?,
        isPlaying: Bool,
        currentTime: Double,
        duration: Double,
        queue: [Track],
        shouldUpdateNowPlaying: Bool = false
    ) {
        let trackChanged = (self.currentTrack?.id != track?.id)
        let playingChanged = (self.isPlaying != isPlaying)
        let durChanged = (duration > 0 && abs(self.duration - duration) > 1.0)

        if let tr = track {
            self.currentTrack = tr
        }
        if !queue.isEmpty {
            self.queue = queue
            if let cur = track, let idx = queue.firstIndex(where: { $0.id == cur.id }) {
                self.queueIndex = idx
            }
        }
        if playingChanged {
            self.isPlaying = isPlaying
        }
        self.isBuffering = false
        self.isPlayingOffline = false
        self.currentTime = max(0.0, currentTime)
        if duration > 0 {
            self.duration = duration
        }

        if trackChanged, let tr = track {
            loadArtwork(from: tr.coverUrl)
        } else if shouldUpdateNowPlaying || playingChanged || durChanged {
            // Niemals auf periodischen Time-Observer-Ticks MPNowPlayingInfoCenter XPC auslösen!
            updateNowPlayingInfo()
        }
    }

    public func applyJamExited() {
        self.isPlaying = false
        self.isBuffering = false
        updateNowPlayingInfo()
    }

    public func play(track: Track, from contextQueue: [Track] = [], serverURL: String? = nil, startAt: Double? = nil) {
        startPlayback(
            track: track,
            from: contextQueue,
            serverURL: serverURL,
            startAt: startAt,
            qualityOverride: nil,
            isQualityRetry: false
        )
    }

    private func startPlayback(
        track: Track,
        from contextQueue: [Track],
        serverURL: String?,
        startAt: Double?,
        qualityOverride: String?,
        isQualityRetry: Bool
    ) {
        if let sUrl = serverURL, !sUrl.isEmpty {
            self.currentServerURL = sUrl
        }
        if JamManager.shared.isInJam {
            if track.isLive {
                JamManager.shared.leaveJam()
            } else {
                JamManager.shared.playTrackInJam(track, queue: contextQueue, startAt: startAt ?? 0.0)
                return
            }
        }
        skipTimerWorkItem?.cancel()
        skipTimerWorkItem = nil
        if !isQualityRetry {
            self.activeQualityOverride = nil
            self.didAttemptQualityFallbackForCurrentTrack = false
            if !self.isAdvancingAfterFailure {
                self.consecutiveFailureSkips = 0
            }
        } else {
            self.activeQualityOverride = qualityOverride
            self.didAttemptQualityFallbackForCurrentTrack = true
        }

        let effectiveServerURL = (serverURL != nil && !serverURL!.isEmpty) ? serverURL! : (self.currentServerURL ?? SessionManager.shared.serverURL ?? "")
        let token = SessionManager.shared.currentToken

        guard let resolvedOffline = resolveOfflineCandidate(requested: track, contextQueue: contextQueue) else {
            self.isPlayingOffline = false
            self.isBuffering = false
            self.isPlaying = false
            return
        }
        let track = resolvedOffline.track
        let contextQueue = resolvedOffline.queue

        if !isQualityRetry {
            // Track-Historie fuer Rueckwaerts-Springen fuehren (nur bei Vorwaerts-Wiedergabe)
            if !isNavigatingBackward, let current = self.currentTrack, current.id != track.id {
                if !self.pastTracks.contains(where: { $0.id == current.id }) {
                    self.pastTracks.append(current)
                    if self.pastTracks.count > 50 {
                        self.pastTracks.removeFirst()
                    }
                }
            }

            // Queue aktualisieren
            if contextQueue.count > 1 {
                self.queue = contextQueue
                if let idx = contextQueue.firstIndex(where: { $0.id == track.id }) {
                    self.queueIndex = idx
                } else {
                    self.queue.insert(track, at: 0)
                    self.queueIndex = 0
                }
            } else if contextQueue.count == 1 {
                // When a single track is passed, DO NOT wipe existing queue
                if self.queue.isEmpty {
                    self.queue = [track]
                    self.queueIndex = 0
                } else if let idx = self.queue.firstIndex(where: { $0.id == track.id }) {
                    self.queueIndex = idx
                } else {
                    self.queue.insert(track, at: self.queueIndex + 1)
                    self.queueIndex += 1
                }
            } else {
                if !self.queue.contains(where: { $0.id == track.id }) {
                    self.queue.append(track)
                    self.queueIndex = self.queue.count - 1
                } else if let idx = self.queue.firstIndex(where: { $0.id == track.id }) {
                    self.queueIndex = idx
                }
            }
        }

        self.currentTrack = track
        DebugLogStore.shared.log(
            tag: track.isLive ? "play:live" : "call:play",
            category: .stream,
            message: "\(track.title) (\(track.artist)) offline=\(OfflineDownloadManager.shared.localAudioFileURL(for: track.id) != nil) quality=\(qualityOverride ?? "default")"
        )
        let initialSeek = (startAt ?? 0.0) > 1.0 && !track.isLive ? startAt : nil
        self.pendingSeekTime = initialSeek
        self.currentTime = initialSeek ?? 0.0
        self.duration = track.isLive ? 0.0 : parseDurationSeconds(from: track)
        self.isBuffering = true

        // Background-Metadaten-Anreicherung falls Dauer unbekannt (0s) und online (niemals fuer Live-Radio)
        if !track.isLive && self.duration <= 0 && !SessionManager.shared.isOfflineMode {
            let searchQ = "\(track.title) \(track.artist)".trimmingCharacters(in: .whitespacesAndNewlines)
            if !searchQ.isEmpty {
                let trackId = track.id
                Task {
                    if let searchRes = await MusicService.shared.fetchDiscoverySearch(query: searchQ, serverURL: effectiveServerURL, token: token) {
                        if let matched = searchRes.tracks?.first, let dSecs = matched.durationSeconds, dSecs > 0 {
                            await MainActor.run {
                                if self.currentTrack?.id == trackId {
                                    let cleanDur = Double(dSecs)
                                    if self.duration <= 0 || (self.duration > cleanDur * 1.7 && self.duration < cleanDur * 2.3) {
                                        self.duration = cleanDur
                                        self.updateNowPlayingInfo()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Zuletzt gehoert aktualisieren
        if let existingIdx = self.recentTracks.firstIndex(where: { $0.id == track.id }) {
            self.recentTracks.remove(at: existingIdx)
        }
        self.recentTracks.insert(track, at: 0)
        if self.recentTracks.count > 50 {
            self.recentTracks.removeLast()
        }
        persistRecentTracks()

        // Background Playback Reporting to server (nur wenn online)
        if !SessionManager.shared.isOfflineMode {
            Task {
                await MusicService.shared.reportPlayback(track: track, serverURL: effectiveServerURL, token: token)
            }
        }

        // Hybrid-Wiedergabe: Bevorzuge lokale Offline-Datei, falls vorhanden (0 ms Latenz, kein Traffic)
        let playbackURL: URL
        if let localURL = OfflineDownloadManager.shared.localAudioFileURL(for: track.id) {
            playbackURL = localURL
            self.isPlayingOffline = true
        } else if SessionManager.shared.isOfflineMode {
            self.isPlayingOffline = false
            self.isBuffering = false
            self.isPlaying = false
            return
        } else if let streamURL = MusicService.shared.streamURL(for: track, serverURL: effectiveServerURL, qualityOverride: qualityOverride) {
            playbackURL = streamURL
            self.isPlayingOffline = false
        } else {
            self.isPlayingOffline = false
            self.isBuffering = false
            return
        }

        cleanupCurrentItem()

        let playerItem = AVPlayerItem(url: playbackURL)
        observePlayerItem(playerItem)

        if let existing = avPlayer {
            existing.replaceCurrentItem(with: playerItem)
        } else {
            let newPlayer = AVPlayer(playerItem: playerItem)
            newPlayer.automaticallyWaitsToMinimizeStalling = true
            self.avPlayer = newPlayer
            setupTimeObserver()
        }

        avPlayer?.play()
        self.isPlaying = true

        updateNowPlayingInfo()
        loadArtwork(from: track.coverUrl)

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFailToEnd),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        )

        armSkipTimeoutIfNeeded(for: track, item: playerItem)
    }

    public func mergeServerHistory(_ serverList: [Track]) {
        guard !serverList.isEmpty else { return }
        var merged: [Track] = []
        var seenIds = Set<String>()

        // 1. Nicht-synchronisierte lokale Tracks (in der aktuellen Session abgespielt) ganz oben behalten
        for local in recentTracks {
            if !serverList.contains(where: { $0.id == local.id }) {
                if !seenIds.contains(local.id) {
                    seenIds.insert(local.id)
                    merged.append(local)
                }
            }
        }

        // 2. Server-Verlauf (aktuelle Aktivitäten geräteübergreifend, neueste zuerst)
        for s in serverList {
            if !seenIds.contains(s.id) {
                seenIds.insert(s.id)
                merged.append(s)
            }
        }

        // 3. Verbleibende lokale Tracks beibehalten
        for local in recentTracks {
            if !seenIds.contains(local.id) {
                seenIds.insert(local.id)
                merged.append(local)
            }
        }

        if merged.count > 50 {
            merged = Array(merged.prefix(50))
        }
        self.recentTracks = merged
        persistRecentTracks()
    }

    public func togglePlayPause() {
        if JamManager.shared.isInJam {
            JamManager.shared.togglePlayPause()
            return
        }
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    public func resume() {
        if JamManager.shared.isInJam {
            if !JamManager.shared.isPlaying {
                JamManager.shared.togglePlayPause()
            }
            return
        }
        guard let player = avPlayer else {
            if let current = currentTrack {
                let startPos = self.currentTime
                let effUrl = self.currentServerURL ?? SessionManager.shared.serverURL ?? ""
                play(track: current, from: queue.isEmpty ? [current] : queue, serverURL: effUrl)
                if startPos > 0 {
                    seek(to: startPos)
                }
            }
            return
        }
        player.play()
        self.isPlaying = true
        updateNowPlayingInfo()
    }

    public func pause() {
        if JamManager.shared.isInJam {
            if JamManager.shared.isPlaying {
                JamManager.shared.togglePlayPause()
            }
            return
        }
        guard let player = avPlayer else { return }
        skipTimerWorkItem?.cancel()
        skipTimerWorkItem = nil
        self.isPlaying = false
        player.pause()
        if let track = currentTrack {
            PodcastProgressStore.shared.recordProgress(
                track: track,
                positionSeconds: currentTime,
                durationSeconds: duration,
                forcePersist: true
            )
        }
        updateNowPlayingInfo()
        persistPlayerState()
    }

    public func next(serverURL: String? = nil) {
        if JamManager.shared.isInJam {
            JamManager.shared.nextTrack()
            return
        }
        let activeURL = serverURL ?? currentServerURL ?? SessionManager.shared.serverURL ?? ""
        if queue.isEmpty {
            if let track = currentTrack {
                self.queue = [track]
                self.queueIndex = 0
                extendAutoplayQueueAndPlayNext(serverURL: activeURL)
            }
            return
        }

        if SessionManager.shared.isOfflineMode {
            let downloader = OfflineDownloadManager.shared
            let playableIndices = queue.indices.filter { downloader.localAudioFileURL(for: queue[$0].id) != nil }

            if isShuffle && playableIndices.count > 1 {
                let candidates = playableIndices.filter { $0 != queueIndex }
                if let pick = candidates.randomElement() {
                    self.queueIndex = pick
                    play(track: queue[pick], from: queue, serverURL: activeURL)
                    return
                }
            }

            if let nextIdx = playableIndices.first(where: { $0 > queueIndex }) {
                self.queueIndex = nextIdx
                play(track: queue[nextIdx], from: queue, serverURL: activeURL)
                return
            }

            // Weitere lokale Downloads an die Queue haengen, bevor gewrappt wird
            let offlineList = downloader.allDownloadedTracks()
            let existingIds = Set(queue.map { $0.id })
            let extraOffline = offlineList.filter { !existingIds.contains($0.id) }
            if let firstNew = extraOffline.first {
                self.queue.append(contentsOf: extraOffline)
                if let newIdx = self.queue.firstIndex(where: { $0.id == firstNew.id }) {
                    self.queueIndex = newIdx
                }
                play(track: firstNew, from: self.queue, serverURL: activeURL)
                return
            }

            if let firstPlayable = playableIndices.first {
                self.queueIndex = firstPlayable
                play(track: queue[firstPlayable], from: queue, serverURL: activeURL)
                return
            }

            if let first = offlineList.first {
                play(track: first, from: offlineList, serverURL: activeURL)
                return
            }

            self.isPlaying = false
            self.isBuffering = false
            return
        }

        var nextIndex = queueIndex + 1
        if isShuffle && queue.count > 1 {
            var randomIdx = Int.random(in: 0..<queue.count)
            while randomIdx == queueIndex && queue.count > 1 {
                randomIdx = Int.random(in: 0..<queue.count)
            }
            nextIndex = randomIdx
        }

        if nextIndex < queue.count {
            self.queueIndex = nextIndex
            let nextTrack = queue[nextIndex]
            play(track: nextTrack, from: queue, serverURL: activeURL)
        } else if isRepeat {
            let firstTrack = queue[0]
            self.queueIndex = 0
            play(track: firstTrack, from: queue, serverURL: activeURL)
        } else {
            let autoplayEnabled = UserDefaults.standard.object(forKey: "playback_autoplay_enabled") as? Bool ?? true
            if autoplayEnabled {
                extendAutoplayQueueAndPlayNext(serverURL: activeURL)
            } else {
                self.isPlaying = false
                self.isBuffering = false
            }
        }
    }

    private func extendAutoplayQueueAndPlayNext(serverURL: String) {
        Task { @MainActor in
            if SessionManager.shared.isOfflineMode {
                let offlineList = OfflineDownloadManager.shared.allDownloadedTracks()
                let existingIds = Set(self.queue.map { $0.id })
                let newOffline = offlineList.filter { !existingIds.contains($0.id) }
                if let firstNew = newOffline.first {
                    self.queue.append(contentsOf: newOffline)
                    self.queueIndex += 1
                    self.play(track: firstNew, from: self.queue, serverURL: serverURL)
                } else if let firstOffline = offlineList.first {
                    self.play(track: firstOffline, from: offlineList, serverURL: serverURL)
                }
                return
            }
            let token = SessionManager.shared.currentToken
            let existingIds = Set(self.queue.map { $0.id })

            // 1. Höchste Priorität: Ähnliche Titel / Discovery Recommendations zum aktuellen Song
            if let cur = self.currentTrack {
                let recs = await MusicService.shared.fetchRecommendations(
                    trackId: cur.id,
                    artist: cur.artist,
                    title: cur.title,
                    serverURL: serverURL,
                    token: token
                )
                let newRecs = recs.filter { !existingIds.contains($0.id) }
                if !newRecs.isEmpty {
                    self.queue.append(contentsOf: newRecs)
                    self.queueIndex += 1
                    let nextTrack = self.queue[self.queueIndex]
                    self.play(track: nextTrack, from: self.queue, serverURL: serverURL)
                    return
                }
            }

            // 2. Mittlere Priorität: Weitere Top-Tracks des Künstlers abrufen
            if let cur = self.currentTrack, !cur.artist.isEmpty && cur.artist != "Unbekannt" {
                if let artistData = await MusicService.shared.fetchArtist(name: cur.artist, serverURL: serverURL, token: token) {
                    let artistPool = artistData.topTracks.map { $0.toTrack() }
                    let newArtistTracks = artistPool.filter { !existingIds.contains($0.id) }
                    if !newArtistTracks.isEmpty {
                        self.queue.append(contentsOf: newArtistTracks)
                        self.queueIndex += 1
                        let nextTrack = self.queue[self.queueIndex]
                        self.play(track: nextTrack, from: self.queue, serverURL: serverURL)
                        return
                    }
                }
            }

            // 3. Fallback: Frische Home-Discovery-Tracks (Trending, Hits, For You, Radar)
            if let discovery = await MusicService.shared.fetchHomeDiscovery(serverURL: serverURL, token: token) {
                var freshTracks: [Track] = []
                if let trending = discovery.trendingEverywhere {
                    freshTracks.append(contentsOf: trending.map { $0.toTrack() })
                }
                if let hits = discovery.todaysTopHits {
                    freshTracks.append(contentsOf: hits.map { $0.toTrack() })
                }
                if let top100 = discovery.top100Global {
                    freshTracks.append(contentsOf: top100.map { $0.toTrack() })
                }
                if let picks = discovery.topPicks {
                    freshTracks.append(contentsOf: picks.map { $0.toTrack() })
                }

                let newUnique = freshTracks.filter { !existingIds.contains($0.id) }
                if !newUnique.isEmpty {
                    self.queue.append(contentsOf: newUnique)
                    self.queueIndex += 1
                    let nextTrack = self.queue[self.queueIndex]
                    self.play(track: nextTrack, from: self.queue, serverURL: serverURL)
                    return
                }
            }

            // 4. Absoluter Not-Fallback: Nur wenn wirklich alle Quellen erschöpft sind
            if !self.queue.isEmpty {
                self.queueIndex = 0
                self.play(track: self.queue[0], from: self.queue, serverURL: serverURL)
            }
        }
    }

    public func previous(serverURL: String? = nil) {
        if JamManager.shared.isInJam {
            JamManager.shared.previousTrack()
            return
        }
        let activeURL = serverURL ?? currentServerURL ?? SessionManager.shared.serverURL ?? ""
        let now = Date()
        let isQuickConsecutiveTap = (lastPreviousTapTime != nil && now.timeIntervalSince(lastPreviousTapTime!) < 2.0)
        lastPreviousTapTime = now

        if currentTime > 3.0 && !isQuickConsecutiveTap {
            seek(to: 0)
            return
        }

        if SessionManager.shared.isOfflineMode {
            let downloader = OfflineDownloadManager.shared
            var idx = queueIndex - 1
            while idx >= 0 && idx < queue.count {
                if downloader.localAudioFileURL(for: queue[idx].id) != nil {
                    self.queueIndex = idx
                    self.isNavigatingBackward = true
                    play(track: queue[idx], from: queue, serverURL: activeURL)
                    self.isNavigatingBackward = false
                    return
                }
                idx -= 1
            }

            if let prevPastIdx = pastTracks.lastIndex(where: { downloader.localAudioFileURL(for: $0.id) != nil }) {
                let prevTrack = pastTracks.remove(at: prevPastIdx)
                self.queue.insert(prevTrack, at: 0)
                self.queueIndex = 0
                self.isNavigatingBackward = true
                play(track: prevTrack, from: queue, serverURL: activeURL)
                self.isNavigatingBackward = false
                return
            }

            if let prevRecent = recentTracks.first(where: {
                $0.id != currentTrack?.id && downloader.localAudioFileURL(for: $0.id) != nil
            }) {
                self.queue.insert(prevRecent, at: 0)
                self.queueIndex = 0
                self.isNavigatingBackward = true
                play(track: prevRecent, from: queue, serverURL: activeURL)
                self.isNavigatingBackward = false
                return
            }

            seek(to: 0)
            return
        }

        let prevIndex = queueIndex - 1
        if prevIndex >= 0 && prevIndex < queue.count {
            self.queueIndex = prevIndex
            let prevTrack = queue[prevIndex]
            self.isNavigatingBackward = true
            play(track: prevTrack, from: queue, serverURL: activeURL)
            self.isNavigatingBackward = false
            return
        }

        if queue.count > 1 {
            seek(to: 0)
            return
        }

        if !pastTracks.isEmpty {
            let prevTrack = pastTracks.removeLast()
            self.queue.insert(prevTrack, at: 0)
            self.queueIndex = 0
            self.isNavigatingBackward = true
            play(track: prevTrack, from: queue, serverURL: activeURL)
            self.isNavigatingBackward = false
            return
        }

        if recentTracks.count > 1 {
            let prevTrack = recentTracks[1]
            self.queue.insert(prevTrack, at: 0)
            self.queueIndex = 0
            self.isNavigatingBackward = true
            play(track: prevTrack, from: queue, serverURL: activeURL)
            self.isNavigatingBackward = false
            return
        }

        seek(to: 0)
    }

    public func seek(to targetSeconds: Double) {
        if JamManager.shared.isInJam {
            JamManager.shared.seek(to: targetSeconds)
            return
        }
        let maxDur = duration > 1.0 ? duration : 3600.0
        let clamped = max(0.0, min(targetSeconds, maxDur))
        self.currentTime = clamped

        let time = CMTime(seconds: clamped, preferredTimescale: 600)
        let tolerance = CMTime(seconds: 0.25, preferredTimescale: 600)
        avPlayer?.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateNowPlayingInfo()
            }
        }
    }

    public func toggleShuffle() {
        isShuffle.toggle()
    }

    public func toggleRepeat() {
        isRepeat.toggle()
    }

    // MARK: - Queue Management
    public func playNext(track: Track) {
        if queue.isEmpty {
            let activeURL = currentServerURL ?? SessionManager.shared.serverURL ?? ""
            play(track: track, from: [track], serverURL: activeURL)
            return
        }
        let insertIndex = min(queueIndex + 1, queue.count)
        queue.insert(track, at: insertIndex)
        if JamManager.shared.isInJam {
            JamManager.shared.syncQueue(queue)
        }
    }

    public func playNext(tracks: [Track], serverURL: String? = nil) {
        guard !tracks.isEmpty else { return }
        if queue.isEmpty {
            playAll(tracks: tracks, shuffle: false, serverURL: serverURL)
            return
        }
        let insertIndex = min(queueIndex + 1, queue.count)
        queue.insert(contentsOf: tracks, at: insertIndex)
        if JamManager.shared.isInJam {
            JamManager.shared.syncQueue(queue)
        }
    }

    public func addToQueue(track: Track) {
        if queue.isEmpty {
            let activeURL = currentServerURL ?? SessionManager.shared.serverURL ?? ""
            play(track: track, from: [track], serverURL: activeURL)
            return
        }
        queue.append(track)
        if JamManager.shared.isInJam {
            JamManager.shared.syncQueue(queue)
        }
    }

    public func moveUpcomingQueueItem(fromOffsets: IndexSet, toOffset: Int) {
        let startIdx = queueIndex + 1
        guard startIdx < queue.count else { return }
        var upcoming = Array(queue[startIdx...])
        upcoming.move(fromOffsets: fromOffsets, toOffset: toOffset)
        queue.replaceSubrange(startIdx..<queue.count, with: upcoming)
        if JamManager.shared.isInJam {
            JamManager.shared.syncQueue(queue)
        }
    }

    public func removeUpcomingQueueItem(at queueArrayIndex: Int) {
        guard queueArrayIndex > queueIndex, queueArrayIndex < queue.count else { return }
        queue.remove(at: queueArrayIndex)
        if JamManager.shared.isInJam {
            JamManager.shared.syncQueue(queue)
        }
    }

    public func pruneQueueToDownloadedOnly() {
        let downloader = OfflineDownloadManager.shared
        let filtered = queue.filter { downloader.isDownloaded(trackId: $0.id) }
        if filtered.isEmpty {
            let allOffline = downloader.allDownloadedTracks()
            self.queue = allOffline
            if let cur = currentTrack, let idx = allOffline.firstIndex(where: { $0.id == cur.id }) {
                self.queueIndex = idx
            } else {
                self.queueIndex = 0
            }
            return
        }
        self.queue = filtered
        if let cur = currentTrack, let idx = filtered.firstIndex(where: { $0.id == cur.id }) {
            self.queueIndex = idx
        } else {
            self.queueIndex = 0
        }
    }

    public func playAll(tracks: [Track], shuffle: Bool = false, serverURL: String? = nil) {
        guard !tracks.isEmpty else { return }
        let activeURL = serverURL ?? currentServerURL ?? SessionManager.shared.serverURL ?? ""
        var targetQueue = tracks
        self.isShuffle = shuffle
        if shuffle && targetQueue.count > 1 {
            targetQueue.shuffle()
        }
        let first = targetQueue[0]
        if JamManager.shared.isInJam {
            if first.isLive {
                JamManager.shared.leaveJam()
            } else {
                JamManager.shared.playTrackInJam(first, queue: targetQueue)
                return
            }
        }
        play(track: first, from: targetQueue, serverURL: activeURL)
    }

    // MARK: - Player Observers
    private func observePlayerItem(_ item: AVPlayerItem) {
        itemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch observedItem.status {
                case .readyToPlay:
                    self.skipTimerWorkItem?.cancel()
                    self.skipTimerWorkItem = nil
                    self.consecutiveFailureSkips = 0
                    self.isBuffering = false
                    let dur = observedItem.duration.seconds
                    if self.currentTrack?.isLive != true {
                        let resolved = self.resolveAuthoritativeDuration(knownTrack: self.currentTrack, audioDuration: dur)
                        if resolved > 0 && (self.duration <= 0 || self.duration > resolved * 1.7) {
                            self.duration = resolved
                        }
                    }
                    if let seekTarget = self.pendingSeekTime {
                        self.pendingSeekTime = nil
                        self.seek(to: seekTarget)
                    }
                    self.updateNowPlayingInfo()
                case .failed:
                    self.skipTimerWorkItem?.cancel()
                    self.skipTimerWorkItem = nil
                    self.isBuffering = false
                    print("AudioPlayerManager: Item failed to play: \(String(describing: observedItem.error))")
                    guard self.isPlaying, let failedTrack = self.currentTrack else { return }
                    self.handlePlaybackFailure(failedTrack: failedTrack, error: observedItem.error)
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        itemDurationObserver = item.observe(\.duration, options: [.initial, .new]) { [weak self] observedItem, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let dur = observedItem.duration.seconds
                let resolved = self.resolveAuthoritativeDuration(knownTrack: self.currentTrack, audioDuration: dur)
                if resolved > 0 && (self.duration <= 0 || self.duration > resolved * 1.7) {
                    self.duration = resolved
                    self.updateNowPlayingInfo()
                }
            }
        }

        itemBufferObserver = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] observedItem, _ in
            Task { @MainActor [weak self] in
                self?.isBuffering = !observedItem.isPlaybackLikelyToKeepUp
            }
        }
    }

    private func setupTimeObserver() {
        if let token = timeObserverToken {
            avPlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = avPlayer?.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            let sec = time.seconds
            if !sec.isNaN {
                self.currentTime = sec
                if let track = self.currentTrack, self.isPlaying {
                    PodcastProgressStore.shared.recordProgress(
                        track: track,
                        positionSeconds: sec,
                        durationSeconds: self.duration
                    )
                }
                // Automatischer Übergang zum nächsten Track wenn das reale Songende erreicht ist (keine 3 Minuten Stille)
                if self.isPlaying && self.currentTrack?.isLive != true && self.duration > 1.0 && self.currentTime >= self.duration - 0.35 {
                    self.playerItemDidReachEnd()
                    return
                }
            }
        }
    }

    private func cleanupCurrentItem() {
        skipTimerWorkItem?.cancel()
        skipTimerWorkItem = nil
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        itemDurationObserver?.invalidate()
        itemDurationObserver = nil
        itemBufferObserver?.invalidate()
        itemBufferObserver = nil
    }

    private func armSkipTimeoutIfNeeded(for track: Track, item: AVPlayerItem) {
        skipTimerWorkItem?.cancel()
        skipTimerWorkItem = nil
        guard !isPlayingOffline, !track.isLive else { return }
        let skipSec = configuredSkipTimeoutSeconds
        guard skipSec > 0 else { return }

        let targetId = track.id
        let work = DispatchWorkItem { [weak self, weak item] in
            Task { @MainActor [weak self, weak item] in
                guard let self = self,
                      let item = item,
                      self.isPlaying,
                      self.currentTrack?.id == targetId else {
                    return
                }
                let playedSec = self.currentTime
                if item.status == .readyToPlay && playedSec > 0.5 && !self.isBuffering {
                    return
                }
                self.handlePlaybackFailure(failedTrack: track, error: item.error)
            }
        }
        skipTimerWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(skipSec), execute: work)
    }

    private func handlePlaybackFailure(failedTrack: Track, error: Error?) {
        // 1. Einmaliger AAC/MP4-Codec-Fallback (quality=low), falls High-Quality auf älterem Server WebM geliefert hat
        if !isPlayingOffline && !failedTrack.isLive && !SessionManager.shared.isOfflineMode && !didAttemptQualityFallbackForCurrentTrack {
            let resumePos = currentTime
            startPlayback(
                track: failedTrack,
                from: [],
                serverURL: currentServerURL,
                startAt: resumePos > 1.0 ? resumePos : nil,
                qualityOverride: "low",
                isQualityRetry: true
            )
            return
        }

        // 2. Bei aktiver Netzwerkverbindung nicht blind in den Offline-Modus wechseln
        if !isPlayingOffline && isConnectionFailureError(error) {
            SessionManager.shared.reportSuspectedConnectionFailure(error)
        }

        // 3. Benutzer-Einstellung "Defekte Songs überspringen" ("playback_skip_timeout") respektieren:
        // Wert 0 ("Aus") stoppt sauber am aktuellen Song, statt andere Titel durchzuskippen.
        guard configuredSkipTimeoutSeconds > 0 else {
            self.isPlaying = false
            self.isBuffering = false
            self.updateNowPlayingInfo()
            return
        }

        // 4. Endlos-Skip-Kaskade auf maximal 3 Versuche begrenzen
        guard consecutiveFailureSkips < 3 else {
            self.consecutiveFailureSkips = 0
            self.isPlaying = false
            self.isBuffering = false
            self.updateNowPlayingInfo()
            return
        }

        let downloader = OfflineDownloadManager.shared
        let hasOfflineNextInQueue = queue.contains(where: { $0.id != failedTrack.id && downloader.isDownloaded(trackId: $0.id) })
        if !SessionManager.shared.isOfflineMode || hasOfflineNextInQueue {
            consecutiveFailureSkips += 1
            isAdvancingAfterFailure = true
            next()
            isAdvancingAfterFailure = false
        } else {
            self.isPlaying = false
            self.isBuffering = false
            self.updateNowPlayingInfo()
        }
    }

    @objc private func playerItemDidReachEnd() {
        Task { @MainActor in
            guard self.isPlaying else {
                print("AudioPlayerManager: Item ended while paused, skipping ignored")
                return
            }
            if self.duration > 5.0 && self.currentTime < self.duration - 3.0 {
                // Timescale-Verdopplungs-Bug abfangen: Wenn AVPlayer den Song bei ca. der Hälfte der Spieldauer regulär beendet
                if self.currentTime > 30.0 && self.currentTime >= (self.duration * 0.42) && self.currentTime <= (self.duration * 0.58) {
                    print("AudioPlayerManager: fMP4-Timescale-Verdopplung bei EOF erkannt (\(self.currentTime)/\(self.duration)). Dauer korrigiert, springe zum nächsten Titel.")
                    self.duration = self.currentTime
                    if let track = self.currentTrack {
                PodcastProgressStore.shared.recordProgress(
                    track: track,
                    positionSeconds: self.duration,
                    durationSeconds: self.duration,
                    isCompleted: true,
                    forcePersist: true
                )
            }
            self.next()
                    return
                }
                print("AudioPlayerManager: Premature stream end at \(self.currentTime)/\(self.duration), skipping ignored")
                return
            }
            if let track = self.currentTrack {
                PodcastProgressStore.shared.recordProgress(
                    track: track,
                    positionSeconds: self.duration,
                    durationSeconds: self.duration,
                    isCompleted: true,
                    forcePersist: true
                )
            }
            self.next()
        }
    }

    @objc private func playerItemDidFailToEnd(_ notification: Notification) {
        Task { @MainActor in
            let failError = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            if !self.isPlayingOffline && self.isConnectionFailureError(failError) {
                SessionManager.shared.reportSuspectedConnectionFailure(failError)
            }
            guard self.isPlaying else {
                print("AudioPlayerManager: Stream failed while paused, skipping ignored")
                return
            }
            if self.duration > 5.0 && self.currentTime < self.duration - 3.0 {
                if self.currentTime > 30.0 && self.currentTime >= (self.duration * 0.42) && self.currentTime <= (self.duration * 0.58) {
                    print("AudioPlayerManager: fMP4-Timescale-Verdopplung bei Stream-Ende erkannt (\(self.currentTime)/\(self.duration)). Korrigiere und springe weiter.")
                    self.duration = self.currentTime
                    if let track = self.currentTrack {
                        PodcastProgressStore.shared.recordProgress(
                            track: track,
                            positionSeconds: self.duration,
                            durationSeconds: self.duration,
                            isCompleted: true,
                            forcePersist: true
                        )
                    }
                    self.next()
                    return
                }
                if SessionManager.shared.isOfflineMode && !self.isPlayingOffline && self.configuredSkipTimeoutSeconds > 0 {
                    print("AudioPlayerManager: Verbindung während Wiedergabe unterbrochen, wechsle auf nächsten Offline-Song.")
                    if let track = self.currentTrack {
                        PodcastProgressStore.shared.recordProgress(
                            track: track,
                            positionSeconds: self.duration,
                            durationSeconds: self.duration,
                            isCompleted: true,
                            forcePersist: true
                        )
                    }
                    self.isAdvancingAfterFailure = true
                    self.next()
                    self.isAdvancingAfterFailure = false
                    return
                }
                print("AudioPlayerManager: Premature stream failure at \(self.currentTime)/\(self.duration), skipping ignored")
                if self.configuredSkipTimeoutSeconds == 0 {
                    self.isPlaying = false
                    self.isBuffering = false
                    self.updateNowPlayingInfo()
                }
                return
            }
            if let track = self.currentTrack {
                PodcastProgressStore.shared.recordProgress(
                    track: track,
                    positionSeconds: self.duration,
                    durationSeconds: self.duration,
                    isCompleted: true,
                    forcePersist: true
                )
            }
            self.next()
        }
    }

    private func isConnectionFailureError(_ error: Error?) -> Bool {
        guard let nsErr = error as NSError? else { return false }
        if nsErr.domain == NSURLErrorDomain {
            let offlineCodes: Set<Int> = [
                NSURLErrorNotConnectedToInternet,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorTimedOut,
                NSURLErrorCannotConnectToHost,
                NSURLErrorCannotFindHost,
                NSURLErrorDNSLookupFailed,
                NSURLErrorDataNotAllowed,
                NSURLErrorInternationalRoamingOff
            ]
            return offlineCodes.contains(nsErr.code)
        }
        return false
    }

    // MARK: - Lock Screen & Control Center (MPNowPlayingInfoCenter)
    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resume()
            }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pause()
            }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.togglePlayPause()
            }
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.next()
            }
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.previous()
            }
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor [weak self] in
                self?.seek(to: posEvent.positionTime)
            }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if track.isLive {
            info[MPNowPlayingInfoPropertyIsLiveStream] = true
        }

        if let album = track.album, !album.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = album
        }

        if let image = nowPlayingArtwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(from urlString: String?) {
        let targetId = currentTrack?.id
        nowPlayingArtwork = nil

        // 1. Lokales Offline-Cover direkt von Flash laden (sofortiges Artwork ohne Netzwerk)
        if let tid = targetId,
           let localImage = OfflineDownloadManager.shared.localCoverImage(for: tid) {
            self.nowPlayingArtwork = localImage
            self.updateNowPlayingInfo()
            return
        }

        // 2. Falls Audiodatei lokal vorliegt, eingebettetes Artwork aus der M4A/MP3-Datei extrahieren
        if let tid = targetId, OfflineDownloadManager.shared.localAudioFileURL(for: tid) != nil {
            Task {
                if let embedded = await OfflineDownloadManager.shared.extractAndCacheArtwork(for: tid) {
                    await MainActor.run {
                        if self.currentTrack?.id == tid {
                            self.nowPlayingArtwork = embedded
                            self.updateNowPlayingInfo()
                        }
                    }
                    return
                }
            }
        }

        let resolvedURL = resolveCoverURL(urlString, serverURL: currentServerURL ?? SessionManager.shared.serverURL ?? "")
        guard let url = resolvedURL else {
            updateNowPlayingInfo()
            return
        }

        Task {
            if let image = await PortImageCache.shared.loadImage(for: url) {
                await MainActor.run {
                    if self.currentTrack?.id == targetId {
                        self.nowPlayingArtwork = image
                        self.updateNowPlayingInfo()
                    }
                }
            }
        }
    }
}
