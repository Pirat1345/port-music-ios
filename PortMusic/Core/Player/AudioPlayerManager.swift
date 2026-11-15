import Foundation
import AVFoundation
import MediaPlayer
import Combine
import UIKit

@MainActor
public final class AudioPlayerManager: ObservableObject {
    public static let shared = AudioPlayerManager()

    // MARK: - Reactive State
    @Published public private(set) var currentTrack: Track? = nil
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var isBuffering: Bool = false
    @Published public private(set) var currentTime: Double = 0.0
    @Published public private(set) var duration: Double = 0.0
    @Published public private(set) var queue: [Track] = []
    @Published public private(set) var queueIndex: Int = 0
    @Published public private(set) var recentTracks: [Track] = []
    @Published public private(set) var pastTracks: [Track] = []

    @Published public var isShuffle: Bool = false
    @Published public var isRepeat: Bool = false

    public private(set) var currentServerURL: String? = nil
    private var lastPreviousTapTime: Date? = nil
    private var isNavigatingBackward: Bool = false
    private let recentTracksStorageKey = "port_music_recent_tracks"

    // MARK: - Internal Player Properties
    private var avPlayer: AVPlayer? = nil
    private var timeObserverToken: Any? = nil
    private var itemStatusObserver: NSKeyValueObservation? = nil
    private var itemDurationObserver: NSKeyValueObservation? = nil
    private var itemBufferObserver: NSKeyValueObservation? = nil
    private var nowPlayingArtwork: UIImage? = nil
    private var periodicPersistCounter: Int = 0

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
            self.currentTime = max(0, savedTime)
            self.duration = savedDur > 0 ? savedDur : parseDurationSeconds(from: track)

            if let qData = UserDefaults.standard.data(forKey: lastPlayedQueueKey),
               let q = try? JSONDecoder().decode([Track].self, from: qData) {
                self.queue = q
            } else {
                self.queue = [track]
            }
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
    private func parseDurationSeconds(from track: Track) -> Double {
        if track.durationSeconds > 0 {
            return track.durationSeconds
        }
        let parts = track.duration.split(separator: ":").compactMap { Double($0) }
        if parts.count == 2 {
            return parts[0] * 60.0 + parts[1]
        } else if parts.count == 3 {
            return parts[0] * 3600.0 + parts[1] * 60.0 + parts[2]
        }
        return 210.0 // Standard fallback (~3:30)
    }

    // MARK: - Playback Control API
    public func play(track: Track, from contextQueue: [Track] = [], serverURL: String? = nil) {
        if let sUrl = serverURL, !sUrl.isEmpty {
            self.currentServerURL = sUrl
        }
        let effectiveServerURL = (serverURL != nil && !serverURL!.isEmpty) ? serverURL! : (self.currentServerURL ?? SessionManager.shared.serverURL ?? "")

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

        self.currentTrack = track
        self.currentTime = 0.0
        self.duration = parseDurationSeconds(from: track)
        self.isBuffering = true

        // Zuletzt gehoert aktualisieren
        if let existingIdx = self.recentTracks.firstIndex(where: { $0.id == track.id }) {
            self.recentTracks.remove(at: existingIdx)
        }
        self.recentTracks.insert(track, at: 0)
        if self.recentTracks.count > 50 {
            self.recentTracks.removeLast()
        }
        persistRecentTracks()

        // Background Playback Reporting to server
        let token = SessionManager.shared.currentToken
        Task {
            await MusicService.shared.reportPlayback(track: track, serverURL: effectiveServerURL, token: token)
        }

        guard let streamURL = MusicService.shared.streamURL(for: track, serverURL: effectiveServerURL) else {
            self.isBuffering = false
            return
        }

        cleanupCurrentItem()

        let playerItem = AVPlayerItem(url: streamURL)
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
    }

    public func mergeServerHistory(_ serverList: [Track]) {
        for t in serverList {
            if !recentTracks.contains(where: { $0.id == t.id }) {
                recentTracks.append(t)
            }
        }
        if recentTracks.count > 50 {
            recentTracks = Array(recentTracks.prefix(50))
        }
        persistRecentTracks()
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    public func resume() {
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
        guard let player = avPlayer else { return }
        player.pause()
        self.isPlaying = false
        updateNowPlayingInfo()
        persistPlayerState()
    }

    public func next(serverURL: String? = nil) {
        guard !queue.isEmpty else { return }
        let activeURL = serverURL ?? currentServerURL ?? SessionManager.shared.serverURL ?? ""

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
            extendAutoplayQueueAndPlayNext(serverURL: activeURL)
        }
    }

    private func extendAutoplayQueueAndPlayNext(serverURL: String) {
        Task { @MainActor in
            let token = SessionManager.shared.currentToken
            if let discovery = await MusicService.shared.fetchHomeDiscovery(serverURL: serverURL, token: token) {
                var freshTracks: [Track] = []
                if let trending = discovery.trendingEverywhere {
                    freshTracks.append(contentsOf: trending.map { $0.toTrack() })
                }
                if let hits = discovery.todaysTopHits {
                    freshTracks.append(contentsOf: hits.map { $0.toTrack() })
                }

                let existingIds = Set(self.queue.map { $0.id })
                let newUnique = freshTracks.filter { !existingIds.contains($0.id) }

                if !newUnique.isEmpty {
                    self.queue.append(contentsOf: newUnique)
                    let nextTrack = self.queue[self.queueIndex + 1]
                    self.queueIndex += 1
                    self.play(track: nextTrack, from: self.queue, serverURL: serverURL)
                    return
                }
            }

            if !self.queue.isEmpty {
                self.queueIndex = 0
                self.play(track: self.queue[0], from: self.queue, serverURL: serverURL)
            }
        }
    }

    public func previous(serverURL: String? = nil) {
        let activeURL = serverURL ?? currentServerURL ?? SessionManager.shared.serverURL ?? ""
        let now = Date()
        let isQuickConsecutiveTap = (lastPreviousTapTime != nil && now.timeIntervalSince(lastPreviousTapTime!) < 2.0)
        lastPreviousTapTime = now

        if currentTime > 3.0 && !isQuickConsecutiveTap {
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

        seek(to: 0)
    }

    public func seek(to targetSeconds: Double) {
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
    }

    public func addToQueue(track: Track) {
        if queue.isEmpty {
            let activeURL = currentServerURL ?? SessionManager.shared.serverURL ?? ""
            play(track: track, from: [track], serverURL: activeURL)
            return
        }
        queue.append(track)
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
        play(track: first, from: targetQueue, serverURL: activeURL)
    }

    // MARK: - Player Observers
    private func observePlayerItem(_ item: AVPlayerItem) {
        itemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch observedItem.status {
                case .readyToPlay:
                    self.isBuffering = false
                    let dur = observedItem.duration.seconds
                    if !dur.isNaN && dur > 1.0 {
                        self.duration = dur
                    }
                    self.updateNowPlayingInfo()
                case .failed:
                    self.isBuffering = false
                    print("AudioPlayerManager: Item failed to play: \(String(describing: observedItem.error))")
                    self.next()
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
                if !dur.isNaN && dur > 1.0 {
                    self.duration = dur
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
                self.periodicPersistCounter += 1
                if self.periodicPersistCounter >= 8 { // roughly every 2s
                    self.periodicPersistCounter = 0
                    self.persistPlayerState()
                }
            }
        }
    }

    private func cleanupCurrentItem() {
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        itemDurationObserver?.invalidate()
        itemDurationObserver = nil
        itemBufferObserver?.invalidate()
        itemBufferObserver = nil
    }

    @objc private func playerItemDidReachEnd() {
        Task { @MainActor in
            self.next()
        }
    }

    @objc private func playerItemDidFailToEnd() {
        Task { @MainActor in
            self.next()
        }
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

        if let album = track.album, !album.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = album
        }

        if let image = nowPlayingArtwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(from urlString: String?) {
        nowPlayingArtwork = nil
        let resolvedURL = resolveCoverURL(urlString, serverURL: currentServerURL ?? SessionManager.shared.serverURL ?? "")
        guard let url = resolvedURL else {
            updateNowPlayingInfo()
            return
        }

        Task {
            if let image = await PortImageCache.shared.loadImage(for: url) {
                await MainActor.run {
                    self.nowPlayingArtwork = image
                    self.updateNowPlayingInfo()
                }
            }
        }
    }
}
