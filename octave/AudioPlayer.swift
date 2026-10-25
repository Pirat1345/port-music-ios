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
    var isPlaying: Bool = false
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

    private func loadAndPlayCurrent() {
        guard let song = currentTrack else { return }
        setupAudioSession()

        // Clean up previous time observer
        if let observer = timeObserver {
            playerA?.removeTimeObserver(observer)
            playerB?.removeTimeObserver(observer)
            timeObserver = nil
        }

        let streamURL = OctaveBackend.shared.streamURL(for: song.id)
        print("AudioPlayer: Streaming '\(song.title)' from \(streamURL)")

        let playerItem = AVPlayerItem(url: streamURL)
        playerItem.preferredForwardBufferDuration = 1.0

        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true

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

        self.isPlaying = true
        self.duration = song.durationSec > 0 ? song.durationSec : 210.0
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

    func next() {
        guard !queue.isEmpty, let idx = currentIndex else { return }
        if idx + 1 < queue.count {
            currentIndex = idx + 1
            loadAndPlayCurrent()
        } else if repeatMode == .all {
            currentIndex = 0
            loadAndPlayCurrent()
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
        currentTime = seconds
        let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)
        activePlayer?.seek(to: cmTime)
    }

    private var activePlayer: AVPlayer? {
        usingA ? playerA : playerB
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let posEvent = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: posEvent.positionTime)
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
