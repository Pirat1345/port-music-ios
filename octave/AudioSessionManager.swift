//
//  AudioSessionManager.swift
//  octave
//

import AVFoundation

final class AudioSessionManager {
    static let shared = AudioSessionManager()

    func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
            try session.setActive(true)
        } catch {
            print("AudioSession configuration failed: \(error)")
        }
    }
}
