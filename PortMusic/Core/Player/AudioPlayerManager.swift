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

    @Published public var isShuffle: Bool = false
    @Published public var isRepeat: Bool = false

    // MARK: - Internal Player Properties
    private var avPlayer: AVPlayer? = nil
    private var timeObserverToken: Any? = nil
    private var itemStatusObserver: NSKeyValueObservation? = nil
    private var itemBufferObserver: NSKeyValueObservation? = nil
    private var nowPlayingArtwork: UIImage? = nil

    private init() {
        setupAudioSession()
        setupRemoteCommandCenter()
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

    // MARK: - Playback Control API
    public func play(track: Track, from contextQueue: [Track] = [], serverURL: String) {
        // Queue aktualisieren gemaess Invariante 3 (kein isolierter 4-Song-Loop)
        if !contextQueue.isEmpty {
            self.queue = contextQueue
            if let idx = contextQueue.firstIndex(where: { $0.id == track.id }) {
                self.queueIndex = idx
            } else {
                self.queue.insert(track, at: 0)
                self.queueIndex = 0
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
        self.duration = max(track.durationSeconds, 1.0)
        self.isBuffering = true

        guard let streamURL = MusicService.shared.streamURL(for: track, serverURL: serverURL) else {
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
        }

        setupTimeObserver()

        avPlayer?.play()
        self.isPlaying = true

        updateNowPlayingInfo()
        loadArtwork(from: track.coverUrl)

        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    public func resume() {
        guard let player = avPlayer else { return }
        player.play()
        self.isPlaying = true
        updateNowPlayingInfo()
    }

    public func pause() {
        guard let player = avPlayer else { return }
        player.pause()
        self.isPlaying = false
        updateNowPlayingInfo()
    }

    public func next(serverURL: String) {
        guard !queue.isEmpty else { return }

        var nextIndex = queueIndex + 1
        if isShuffle && queue.count > 1 {
            var randomIdx = Int.random(in: 0..<queue.count)
            while randomIdx == queueIndex && queue.count > 1 {
                randomIdx = Int.random(in: 0..<queue.count)
            }
            nextIndex = randomIdx
        }

        if nextIndex < queue.count {
            let nextTrack = queue[nextIndex]
            play(track: nextTrack, from: queue, serverURL: serverURL)
        } else if isRepeat {
            let firstTrack = queue[0]
            play(track: firstTrack, from: queue, serverURL: serverURL)
        } else {
            // Autoplay: Ende erreicht
            pause()
            seek(to: 0)
        }
    }

    public func previous(serverURL: String) {
        guard !queue.isEmpty else { return }

        // Wenn schon mehr als 3 Sekunden abgespielt wurden, an den Anfang springen
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }

        let prevIndex = queueIndex - 1
        if prevIndex >= 0 && prevIndex < queue.count {
            let prevTrack = queue[prevIndex]
            play(track: prevTrack, from: queue, serverURL: serverURL)
        } else {
            seek(to: 0)
        }
    }

    public func seek(to targetSeconds: Double) {
        let clamped = max(0.0, min(targetSeconds, duration))
        self.currentTime = clamped

        let time = CMTime(seconds: clamped, preferredTimescale: 600)
        avPlayer?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
    }

    public func toggleShuffle() {
        isShuffle.toggle()
    }

    public func toggleRepeat() {
        isRepeat.toggle()
    }

    // MARK: - Player Observers
    private func observePlayerItem(_ item: AVPlayerItem) {
        itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if observedItem.status == .readyToPlay {
                    self.isBuffering = false
                    let dur = observedItem.duration.seconds
                    if !dur.isNaN && dur > 0 {
                        self.duration = dur
                    }
                    self.updateNowPlayingInfo()
                } else if observedItem.status == .failed {
                    self.isBuffering = false
                    print("AudioPlayerManager: Item failed to play: \(String(describing: observedItem.error))")
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
            }
        }
    }

    private func cleanupCurrentItem() {
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        itemBufferObserver?.invalidate()
        itemBufferObserver = nil
    }

    @objc private func playerItemDidReachEnd() {
        Task { @MainActor in
            if let serverURL = SessionManager.shared.serverURL {
                self.next(serverURL: serverURL)
            }
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
                if let serverURL = SessionManager.shared.serverURL {
                    self?.next(serverURL: serverURL)
                }
            }
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                if let serverURL = SessionManager.shared.serverURL {
                    self?.previous(serverURL: serverURL)
                }
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
        guard let urlString = urlString, let url = URL(string: urlString) else {
            updateNowPlayingInfo()
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.nowPlayingArtwork = image
                        self.updateNowPlayingInfo()
                    }
                }
            } catch {
                print("AudioPlayerManager: Artwork download error: \(error)")
            }
        }
    }
}
