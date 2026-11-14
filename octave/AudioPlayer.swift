//
//  AudioPlayer.swift
//  octave
//
//  High-performance dual-deck automix audio playback engine.
//

import Foundation
import AVFoundation
import MediaPlayer
import Observation

@Observable
final class AudioPlayer: NSObject, @unchecked Sendable {
    static let shared = AudioPlayer()

    // Public State
    var queue: [SongEntity] = []
    var currentIndex: Int?
    var upcomingQueue: [SongEntity] {
        guard let idx = currentIndex, idx + 1 < queue.count else { return [] }
        return Array(queue[(idx + 1)...])
    }
    var isPlaying: Bool = false
    var isOffline: Bool = false
    var playbackError: String? = nil
    var currentTime: Double = 0.0
    var duration: Double = 0.0
    var bufferedTime: Double = 0.0
    var isBuffering: Bool = false

    // Playback Modes & Options
    var isShuffled: Bool = false
    var repeatMode: RepeatMode = .off
    var gaplessEnabled: Bool = true
    var automixStyle: AutomixStyle = .smooth
    var crossfadeSeconds: Double = 5.0
    var spatialAudio: Bool = true
    var atmosActive: Bool = false
    var vocalReduction: Float = 0.0
    var singMode: Bool = false

    enum RepeatMode: Int {
        case off = 0
        case all = 1
        case one = 2
    }

    enum AutomixStyle: Int {
        case off = 0
        case smooth = 1
        case beatmatch = 2
    }

    // Dual Decks for Seamless Automix
    private var playerA: AVPlayer?
    private var playerB: AVPlayer?
    private var usingA: Bool = true
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?

    var currentTrack: SongEntity? {
        guard let idx = currentIndex, idx < queue.count else { return nil }
        return queue[idx]
    }

    override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
    }

    func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
    }

    func play(song: SongEntity, in newQueue: [SongEntity]? = nil) {
        if let newQueue {
            self.queue = newQueue
            self.currentIndex = newQueue.firstIndex(where: { $0.id == song.id }) ?? 0
        } else if !queue.contains(where: { $0.id == song.id }) {
            queue.append(song)
            currentIndex = queue.count - 1
        } else {
            currentIndex = queue.firstIndex(where: { $0.id == song.id })
        }

        loadAndPlayCurrent()
    }

    func insertNext(song: SongEntity) {
        if let idx = currentIndex, idx < queue.count {
            queue.insert(song, at: idx + 1)
        } else {
            queue.append(song)
            if currentIndex == nil {
                currentIndex = 0
            }
        }
    }

    private func loadAndPlayCurrent() {
        guard let song = currentTrack else { return }
        setupAudioSession()

        // Clean up previous time observer and KVO
        if let observer = timeObserver {
            playerA?.removeTimeObserver(observer)
            playerB?.removeTimeObserver(observer)
            timeObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil

        // 1. Lokale Datei-Priorität prüfen
        let localURL = DownloadManager.shared.localFileURL(for: song.id)
        let isLocal = localURL != nil && FileManager.default.fileExists(atPath: localURL!.path)

        // 2. Konnektivitätsprüfung bei nicht heruntergeladenen Titeln
        if !isLocal && !NetworkMonitor.shared.isConnected {
            print("AudioPlayer: Offline und Titel '\(song.title)' (\(song.id)) ist nicht heruntergeladen. Wiedergabe angehalten.")
            playerA?.pause()
            playerB?.pause()
            self.isPlaying = false
            self.isOffline = false
            let errorMsg = "Keine Internetverbindung verfügbar. Bitte überprüfe dein Netzwerk."
            self.playbackError = errorMsg
            Toaster.shared.show(message: errorMsg)
            return
        }

        // 3. Wiedergabe-URL festlegen
        let playURL: URL
        if isLocal, let local = localURL {
            playURL = local
            self.isOffline = true
            self.playbackError = nil
            print("AudioPlayer: Spiele lokale Offline-Datei für '\(song.title)' von \(local.path)")
        } else {
            playURL = OctaveBackend.shared.streamURL(for: song.id, title: song.title, artist: song.artist, album: song.albumTitle)
            self.isOffline = false
            self.playbackError = nil
            print("AudioPlayer: Stream '\(song.title)' von \(playURL)")
        }

        let playerItem = AVPlayerItem(url: playURL)
        if !isLocal {
            playerItem.preferredForwardBufferDuration = 1.0
        }

        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = !isLocal

        if usingA {
            playerA?.pause()
            playerA = player
        } else {
            playerB?.pause()
            playerB = player
        }

        player.play()
        attachTimeObserver(to: player)

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
            self?.next()
        }

        // KVO für asynchrone Dauer-Ermittlung und Fehlerbehandlung
        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if item.status == .readyToPlay {
                    let itemDuration = item.duration.seconds
                    if itemDuration.isFinite && itemDuration > 0 {
                        self.duration = itemDuration
                        self.updateNowPlayingInfo()
                    }
                } else if item.status == .failed {
                    print("AudioPlayer: Fehler bei Wiedergabe von '\(song.title)': \(String(describing: item.error))")
                    if !NetworkMonitor.shared.isConnected {
                        self.isPlaying = false
                        self.playbackError = item.error?.localizedDescription ?? "Wiedergabefehler"
                    } else {
                        self.next()
                    }
                }
            }
        }

        self.isPlaying = true
        self.duration = song.durationSec > 0 ? song.durationSec : (isLocal ? 0.0 : 210.0)
        updateNowPlayingInfo()
    }

    private func attachTimeObserver(to player: AVPlayer?) {
        guard let player else { return }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
            self?.updateNowPlayingPlaybackInfo()
        }
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func pause() {
        activePlayer?.pause()
        isPlaying = false
        updateNowPlayingPlaybackInfo()
    }

    func resume() {
        activePlayer?.play()
        isPlaying = true
        updateNowPlayingPlaybackInfo()
    }

    func replenishOfflineQueue() {
        guard !NetworkMonitor.shared.isConnected else { return }
        let downloaded = DownloadManager.shared.downloadedTracks
        guard !downloaded.isEmpty else { return }

        let currentIdx = currentIndex ?? 0

        // Verbleibende Warteschlange auf heruntergeladene Titel filtern
        if currentIdx + 1 < queue.count {
            let history = Array(queue[0...currentIdx])
            let upcoming = Array(queue[(currentIdx + 1)...])
            let downloadedSet = DownloadManager.shared.downloadedTrackIds
            let validUpcoming = upcoming.filter { downloadedSet.contains($0.id) }
            queue = history + validUpcoming
        }

        // Warteschlange auffüllen falls weniger als 3 anstehende Titel
        let upcomingCount = queue.count - currentIdx - 1
        if upcomingCount < 3 {
            let queuedIds = Set(queue.map { $0.id })
            let candidates = downloaded.filter { !queuedIds.contains($0.id) }
            let pool = candidates.isEmpty ? downloaded.shuffled() : candidates.shuffled()
            let countToAdd = min(5, pool.count)
            queue.append(contentsOf: pool.prefix(countToAdd))
        }
    }

    private var isReplenishingOnlineQueue = false

    func replenishOnlineQueueIfNeeded() {
        guard NetworkMonitor.shared.isConnected else { return }
        guard !isReplenishingOnlineQueue else { return }
        let currentIdx = currentIndex ?? 0
        let upcomingCount = queue.count - currentIdx - 1
        guard upcomingCount < 4 else { return }

        isReplenishingOnlineQueue = true
        Task { @MainActor in
            defer { self.isReplenishingOnlineQueue = false }
            do {
                let recs = try await OctaveBackend.shared.fetchRecommendations(limit: 10)
                let existingIds = Set(self.queue.map { $0.id })
                let candidates = recs.map { $0.toSongEntity() }.filter { !existingIds.contains($0.id) }
                if !candidates.isEmpty {
                    self.queue.append(contentsOf: candidates)
                    print("AudioPlayer: Autoplay hat \(candidates.count) Empfehlungen nachgeladen")
                }
            } catch {
                print("AudioPlayer: Fehler beim Nachladen von Empfehlungen: \(error.localizedDescription)")
            }
        }
    }

    func next() {
        guard !queue.isEmpty, let idx = currentIndex else { return }

        if !NetworkMonitor.shared.isConnected {
            replenishOfflineQueue()
        } else {
            replenishOnlineQueueIfNeeded()
        }

        if idx + 1 < queue.count {
            currentIndex = idx + 1
            loadAndPlayCurrent()
        } else if repeatMode == .all {
            currentIndex = 0
            loadAndPlayCurrent()
        } else if !NetworkMonitor.shared.isConnected {
            isPlaying = false
            updateNowPlayingPlaybackInfo()
        }
    }

    func previous() {
        guard !queue.isEmpty, let idx = currentIndex else { return }
        if currentTime > 3.0 {
            seek(to: 0)
        } else if idx > 0 {
            currentIndex = idx - 1
            loadAndPlayCurrent()
        }
    }

    func seek(to seconds: Double) {
        let maxTime = max(0.0, duration - 1.0)
        let clamped = max(0.0, min(seconds, maxTime))
        currentTime = clamped
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        activePlayer?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlayingPlaybackInfo()
    }

    func isRadioTrack(_ song: SongEntity?) -> Bool {
        guard let song else { return false }
        if song.id.hasPrefix("apple_") ||
           song.id.hasPrefix("deezer_") ||
           song.id.hasPrefix("dz_") ||
           song.id.hasPrefix("yt_") ||
           song.id.hasPrefix("search:") ||
           song.id.hasPrefix("loc_") ||
           song.id.hasPrefix("local_") {
            return false
        }
        return song.id.hasPrefix("radio:")
    }

    private var activePlayer: AVPlayer? {
        usingA ? playerA : playerB
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { _ in
            DispatchQueue.main.async {
                AudioPlayer.shared.resume()
            }
            return .success
        }
        center.pauseCommand.addTarget { _ in
            DispatchQueue.main.async {
                AudioPlayer.shared.pause()
            }
            return .success
        }
        center.nextTrackCommand.addTarget { _ in
            DispatchQueue.main.async {
                AudioPlayer.shared.next()
            }
            return .success
        }
        center.previousTrackCommand.addTarget { _ in
            DispatchQueue.main.async {
                AudioPlayer.shared.previous()
            }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { event in
            if let posEvent = event as? MPChangePlaybackPositionCommandEvent {
                let pos = posEvent.positionTime
                DispatchQueue.main.async {
                    AudioPlayer.shared.seek(to: pos)
                }
                return .success
            }
            return .commandFailed
        }
    }

    private func updateNowPlayingInfo() {
        guard let song = currentTrack else { return }
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = song.title
        info[MPMediaItemPropertyArtist] = song.artist
        info[MPMediaItemPropertyAlbumTitle] = song.albumTitle
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingPlaybackInfo() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
